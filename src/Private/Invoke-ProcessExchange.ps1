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
        [Threading.CancellationToken]$CancellationToken = [Threading.CancellationToken]::None
    )

    # CLR stream pumps support concurrent bounded I/O without requiring PowerShell runspaces.
    $definition = @'
using System;
using System.Diagnostics;
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

        public static string Run(ProcessStartInfo start, string inputText, int timeout, int inputMaximum,
            int outputMaximum, int errorMaximum, bool strict, CancellationToken cancellation)
        {
            byte[] input = null;
            byte[] output = null;
            byte[] error = null;
            Task write = null;
            Task<byte[]> stdout = null;
            Task<byte[]> stderr = null;
            bool started = false;
            using (Process process = new Process())
            using (CancellationTokenSource stop = new CancellationTokenSource())
            {
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
                    process.StartInfo = start;
                    Stopwatch timer = Stopwatch.StartNew();
                    try { started = process.Start(); }
                    catch { throw new ExchangeFailure("StartFailed"); }
                    if (!started) throw new ExchangeFailure("StartFailed");
                    stdout = ReadAsync(process.StandardOutput.BaseStream, outputMaximum,
                        "OutputLimitExceeded", stop.Token);
                    stderr = ReadAsync(process.StandardError.BaseStream, errorMaximum,
                        "ErrorLimitExceeded", stop.Token);
                    write = WriteAsync(process, input, stop.Token);
                    while (!process.HasExited || !write.IsCompleted || !stdout.IsCompleted || !stderr.IsCompleted)
                    {
                        CheckFailure(stdout, "ReadFailed");
                        CheckFailure(stderr, "ReadFailed");
                        CheckFailure(write, "WriteFailed");
                        if (cancellation.IsCancellationRequested) throw new ExchangeFailure("Cancelled");
                        if (timer.ElapsedMilliseconds >= timeout) throw new ExchangeFailure("TimedOut");
                        Thread.Sleep(10);
                    }
                    CheckFailure(stdout, "ReadFailed");
                    CheckFailure(stderr, "ReadFailed");
                    CheckFailure(write, "WriteFailed");
                    output = stdout.GetAwaiter().GetResult();
                    error = stderr.GetAwaiter().GetResult();
                    if (process.ExitCode != 0) throw new ExchangeFailure("ExitFailed");
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
                    stop.Cancel();
                    if (started) Kill(process, strict);
                    process.Dispose();
                    Observe(write);
                    Observe(stdout);
                    Observe(stderr);
                    if (input != null) Array.Clear(input, 0, input.Length);
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

    $exchangeType::Run(
        $StartInfo, $InputText, $TimeoutMilliseconds, $MaxInputBytes,
        $MaxOutputBytes, $MaxErrorBytes, $StrictProtocol.IsPresent, $CancellationToken
    )
}
