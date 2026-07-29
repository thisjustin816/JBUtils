Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Stop-ProcessTree.ps1
    }

    BeforeEach {
        # One process, parented to something no test asks about, so no id resolves a child and the
        # recursion terminates immediately. That isolates which ids reach Get-Process.
        Mock Get-CimInstance { [PSCustomObject]@{ ProcessId = $PID; ParentProcessId = 1 } }
        Mock Get-Process { [PSCustomObject]@{ Id = $Id } }
        Mock Stop-Process { }
        Mock Wait-Process { }
    }

    It 'should look up each requested process on its own' {
        # Regression: this resolved the whole -ProcessId array on every pass, so the first id killed
        # every requested process. Later ids were then already dead, Win32_Process reported no
        # children for them, and their descendants were orphaned instead of stopped.
        Stop-ProcessTree -ProcessId 424242, 434343

        Should -Invoke Get-Process -Exactly 2
        Should -Invoke Get-Process -Exactly 1 -ParameterFilter {
            $Id.Count -eq 1 -and $Id[0] -eq 424242
        }
        Should -Invoke Get-Process -Exactly 1 -ParameterFilter {
            $Id.Count -eq 1 -and $Id[0] -eq 434343
        }
    }

    It 'should stop a process it resolved' {
        Stop-ProcessTree -ProcessId 424242

        Should -Invoke Stop-Process -Exactly 1
    }

    It 'should stop nothing when the process is already gone' {
        Mock Get-Process { }

        Stop-ProcessTree -ProcessId 424242

        Should -Invoke Stop-Process -Exactly 0
    }

    It 'should stop a child before its parent' {
        # 424242 has one child, 999999. The child is stopped through the recursive call, so both ids
        # reach Get-Process even though only the parent was requested.
        Mock Get-CimInstance {
            @(
                [PSCustomObject]@{ ProcessId = 999999; ParentProcessId = 424242 }
                [PSCustomObject]@{ ProcessId = $PID; ParentProcessId = 1 }
            )
        }

        Stop-ProcessTree -ProcessId 424242

        Should -Invoke Get-Process -Exactly 1 -ParameterFilter { $Id[0] -eq 999999 }
        Should -Invoke Get-Process -Exactly 1 -ParameterFilter { $Id[0] -eq 424242 }
    }

    It 'should not stop the current process or its parent' {
        # The guard that keeps a tree walk from killing the shell running it.
        Mock Get-CimInstance {
            @(
                [PSCustomObject]@{ ProcessId = $PID; ParentProcessId = 424242 }
                [PSCustomObject]@{ ProcessId = 999999; ParentProcessId = 424242 }
            )
        }

        Stop-ProcessTree -ProcessId 424242

        Should -Invoke Get-Process -Exactly 0 -ParameterFilter { $Id[0] -eq $PID }
    }
}
