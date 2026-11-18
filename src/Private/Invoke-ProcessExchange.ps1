<#
.SYNOPSIS
Internal: Exchanges redirected process streams without exposing native failures.
#>
function Invoke-ProcessExchange {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)][Diagnostics.ProcessStartInfo]$StartInfo,
        [Parameter(Mandatory)][AllowEmptyString()][String]$InputText,
        [Int32]$TimeoutMilliseconds = 30000,
        [Int32]$MaxInputBytes = [Int32]::MaxValue,
        [Int32]$MaxOutputBytes = [Int32]::MaxValue,
        [Int32]$MaxErrorBytes = [Int32]::MaxValue,
        [Switch]$StrictProtocol,
        [Switch]$Streaming,
        [Threading.CancellationToken]$CancellationToken = [Threading.CancellationToken]::None
    )

    # CLR stream pumps support concurrent bounded I/O without requiring PowerShell runspaces.
    $definition = @'
using System;
using System.Diagnostics;
using System.Collections.Concurrent;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace JBUtils.ProcessProtocol
{
    public sealed class ExchangeFailure : Exception
    {
        public ExchangeFailure(string category) : base(category) { }
    }

    public static class Exchange
    {
        private static async Task<byte[]> ReadAsync(Stream stream, int maximum, string category,
            CancellationToken cancellation)
        {
            byte[] buffer = new byte[4096];
            using (MemoryStream captured = new MemoryStream())
            {
                try
                {
                    int count;
                    while ((count = await stream.ReadAsync(buffer, 0, buffer.Length, cancellation)
                        .ConfigureAwait(false)) != 0)
                    {
                        if (count > maximum - captured.Length) throw new ExchangeFailure(category);
                        captured.Write(buffer, 0, count);
                    }
                    return captured.ToArray();
                }
                finally
                {
                    Array.Clear(buffer, 0, buffer.Length);
                    if (captured.Capacity > 0)
                        Array.Clear(captured.GetBuffer(), 0, (int)captured.Length);
                }
            }
        }

        private static async Task WriteAsync(Process process, byte[] input, CancellationToken cancellation)
        {
            try
            {
                if (input.Length != 0)
                {
                    await process.StandardInput.BaseStream.WriteAsync(input, 0, input.Length, cancellation)
                        .ConfigureAwait(false);
                    await process.StandardInput.BaseStream.FlushAsync(cancellation).ConfigureAwait(false);
                }
            }
            finally { process.StandardInput.Close(); }
        }

        private static void CheckFailure(Task task, string fallback)
        {
            if (!task.IsFaulted) return;
            foreach (Exception failure in task.Exception.Flatten().InnerExceptions)
                if (failure is ExchangeFailure) throw failure;
            throw new ExchangeFailure(fallback);
        }

        private static void Kill(Process process, bool tree)
        {
            try
            {
                if (process.HasExited) return;
                var killTree = typeof(Process).GetMethod("Kill", new Type[] { typeof(bool) });
                if (tree && killTree != null) killTree.Invoke(process, new object[] { true });
                else process.Kill();
                process.WaitForExit(2000);
            }
            catch { }
        }

        private static void Observe(Task task)
        {
            if (task == null) return;
            task.ContinueWith(t => { var observed = t.Exception; },
                TaskContinuationOptions.OnlyOnFaulted);
        }

        internal sealed class Session : IDisposable
        {
            internal readonly Process Process = new Process();
            internal readonly CancellationTokenSource Stop = new CancellationTokenSource();
            internal readonly Stopwatch Timer = new Stopwatch();
            internal Task Write;
            private byte[] input;
            private readonly bool tree;
            private bool started;
            private bool disposed;

            internal Session(ProcessStartInfo start, string inputText, int inputMaximum, bool strict,
                CancellationToken cancellation)
            {
                tree = strict;
                try
                {
                    Encoding encoding = strict ? new UTF8Encoding(false, true) : Encoding.UTF8;
                    try
                    {
                        if (encoding.GetByteCount(inputText) > inputMaximum)
                            throw new ExchangeFailure("InputLimitExceeded");
                        input = encoding.GetBytes(inputText);
                    }
                    catch (EncoderFallbackException) { throw new ExchangeFailure("InvalidInputEncoding"); }
                    if (cancellation.IsCancellationRequested) throw new ExchangeFailure("Cancelled");
                    start.UseShellExecute = false;
                    start.CreateNoWindow = true;
                    start.RedirectStandardInput = true;
                    start.RedirectStandardOutput = true;
                    start.RedirectStandardError = true;
                    Process.StartInfo = start;
                    Timer.Start();
                    try { started = Process.Start(); }
                    catch { throw new ExchangeFailure("StartFailed"); }
                    if (!started) throw new ExchangeFailure("StartFailed");
                }
                catch { Dispose(); throw; }
            }

            internal void StartInput() { Write = WriteAsync(Process, input, Stop.Token); }

            public void Dispose()
            {
                if (disposed) return;
                disposed = true;
                Stop.Cancel();
                if (started) Kill(Process, tree);
                Process.Dispose();
                Observe(Write);
                if (input != null) Array.Clear(input, 0, input.Length);
                Stop.Dispose();
            }
        }

        public sealed class RunningExchange : IDisposable
        {
            private readonly Session session;
            private readonly CancellationToken cancellation;
            private readonly BlockingCollection<string> chunks = new BlockingCollection<string>(32);
            private readonly Task stdout;
            private readonly Task stderr;
            private bool disposed;

            internal RunningExchange(Session session, CancellationToken cancellation)
            {
                this.session = session;
                this.cancellation = cancellation;
                stdout = Task.Run(() => PumpAsync(session.Process.StandardOutput.BaseStream));
                stderr = Task.Run(() => PumpAsync(session.Process.StandardError.BaseStream));
                session.StartInput();
            }

            private async Task PumpAsync(Stream stream)
            {
                char[] buffer = new char[2048];
                using (StreamReader reader = new StreamReader(stream, new UTF8Encoding(false), false, 4096))
                {
                    try
                    {
                        int count;
                        while ((count = await reader.ReadAsync(buffer, 0, buffer.Length)
                            .ConfigureAwait(false)) != 0)
                            chunks.Add(new string(buffer, 0, count), session.Stop.Token);
                    }
                    finally { Array.Clear(buffer, 0, buffer.Length); }
                }
            }

            public bool TryRead(out string chunk)
            {
                Check();
                return chunks.TryTake(out chunk);
            }

            public bool IsCompleted
            {
                get
                {
                    Check();
                    return session.Process.HasExited && session.Write.IsCompleted && stdout.IsCompleted &&
                        stderr.IsCompleted && chunks.Count == 0;
                }
            }

            private void Check()
            {
                if (cancellation.IsCancellationRequested) throw new ExchangeFailure("Cancelled");
                CheckFailure(stdout, "ReadFailed");
                CheckFailure(stderr, "ReadFailed");
                CheckFailure(session.Write, "WriteFailed");
            }

            public int Complete()
            {
                if (!IsCompleted) throw new ExchangeFailure("ExchangeIncomplete");
                return session.Process.ExitCode;
            }

            public void Dispose()
            {
                if (disposed) return;
                disposed = true;
                session.Dispose();
                Observe(stdout);
                Observe(stderr);
                string chunk;
                while (chunks.TryTake(out chunk)) { }
                Task.WhenAll(stdout, stderr).ContinueWith(t => {
                    var observed = t.Exception;
                    chunks.Dispose();
                });
            }
        }

        public static RunningExchange StartStreaming(ProcessStartInfo start, string inputText,
            int inputMaximum, CancellationToken cancellation)
        {
            Session session = new Session(start, inputText, inputMaximum, true, cancellation);
            try { return new RunningExchange(session, cancellation); }
            catch { session.Dispose(); throw; }
        }

        public static string Run(ProcessStartInfo start, string inputText, int timeout, int inputMaximum,
            int outputMaximum, int errorMaximum, bool strict, CancellationToken cancellation)
        {
            byte[] output = null;
            byte[] error = null;
            Task<byte[]> stdout = null;
            Task<byte[]> stderr = null;
            using (Session session = new Session(start, inputText, inputMaximum, strict, cancellation))
            {
                try
                {
                    stdout = ReadAsync(session.Process.StandardOutput.BaseStream, outputMaximum,
                        "OutputLimitExceeded", session.Stop.Token);
                    stderr = ReadAsync(session.Process.StandardError.BaseStream, errorMaximum,
                        "ErrorLimitExceeded", session.Stop.Token);
                    session.StartInput();
                    while (!session.Process.HasExited || !session.Write.IsCompleted ||
                        !stdout.IsCompleted || !stderr.IsCompleted)
                    {
                        CheckFailure(stdout, "ReadFailed");
                        CheckFailure(stderr, "ReadFailed");
                        CheckFailure(session.Write, "WriteFailed");
                        if (cancellation.IsCancellationRequested) throw new ExchangeFailure("Cancelled");
                        if (session.Timer.ElapsedMilliseconds >= timeout) throw new ExchangeFailure("TimedOut");
                        Thread.Sleep(10);
                    }
                    CheckFailure(stdout, "ReadFailed");
                    CheckFailure(stderr, "ReadFailed");
                    CheckFailure(session.Write, "WriteFailed");
                    output = stdout.GetAwaiter().GetResult();
                    error = stderr.GetAwaiter().GetResult();
                    if (session.Process.ExitCode != 0) throw new ExchangeFailure("ExitFailed");
                    if (strict && error.Length != 0) throw new ExchangeFailure("UnexpectedErrorOutput");
                    if (strict)
                    {
                        try { return new UTF8Encoding(false, true).GetString(output); }
                        catch (DecoderFallbackException) { throw new ExchangeFailure("InvalidOutputEncoding"); }
                    }
                    using (StreamReader reader = new StreamReader(new MemoryStream(output),
                        new UTF8Encoding(false), true)) return reader.ReadToEnd();
                }
                catch (ExchangeFailure) { throw; }
                catch { throw new ExchangeFailure("ExchangeFailed"); }
                finally
                {
                    session.Dispose();
                    Observe(stdout);
                    Observe(stderr);
                    if (output != null) Array.Clear(output, 0, output.Length);
                    if (error != null) Array.Clear(error, 0, error.Length);
                }
            }
        }
    }
}
'@
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $identity = [BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($definition)))
    }
    finally { $hasher.Dispose() }
    $namespace = ('JBUtils.ProcessProtocol.V' + $identity.Replace('-', ''))
    $typeName = ($namespace + '.Exchange')
    $exchangeType = $typeName -as [Type]
    if (-not $exchangeType) {
        $definition = $definition.Replace('namespace JBUtils.ProcessProtocol', ('namespace ' + $namespace))
        Add-Type -TypeDefinition $definition -ErrorAction Stop
        $exchangeType = $typeName -as [Type]
    }

    if ($Streaming) {
        $exchange = $null
        try {
            $exchange = $exchangeType::StartStreaming($StartInfo, $InputText, $MaxInputBytes, $CancellationToken)
            while (-not $exchange.IsCompleted) {
                $chunk = $null
                while ($exchange.TryRead([ref]$chunk)) { $chunk }
                Start-Sleep -Milliseconds 10
            }
            $exitCode = $exchange.Complete()
            if ($exitCode -ne 0) { throw "ExitCode:$exitCode" }
        }
        finally {
            if ($exchange) { $exchange.Dispose() }
        }
    }
    else {
        $exchangeType::Run(
            $StartInfo, $InputText, $TimeoutMilliseconds, $MaxInputBytes,
            $MaxOutputBytes, $MaxErrorBytes, $StrictProtocol.IsPresent, $CancellationToken
        )
    }
}
