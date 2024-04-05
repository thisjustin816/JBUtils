Describe 'Integration Tests' {
    BeforeAll {
        . $PSScriptRoot/Export-Screenshot.ps1
    }

    It 'should create a screenshot in the default location' {
        $outfile = Export-Screenshot
        $outfile.FullName | Should -Exist
        $outfile.Length | Should -BeGreaterThan 1000
        Remove-Item -Path $outfile -Force -ErrorAction SilentlyContinue
    }

    It 'should create a screenshot and save it to the specified location' {
        $outfile = "$TestDrive/screenshot.bmp"
        Export-Screenshot -OutFile $outfile
        $outfile | Should -Exist
        ( Get-Item -Path $outfile ).Length | Should -BeGreaterThan 1000
        Remove-Item -Path $outfile -Force -ErrorAction SilentlyContinue
    }
}