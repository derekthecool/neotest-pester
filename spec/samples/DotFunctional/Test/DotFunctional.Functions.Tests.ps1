BeforeAll {
    Import-Module $PSScriptRoot/../*.psd1 -Force
}

Describe 'Format-Pairs' {
    It 'Function Format-Pairs exists' {
        Get-Command Format-Pairs | Should -Be -Not $null
    }

    It 'Function Format-Pairs without reducing function creates an array of arrays' { 
        $array = @(1, 2, 3, 4, 5, 6)
        $array | Format-Pairs | Should -Be @(@(1, 2), @(2, 3), @(3, 4), @(4, 5), @(5, 6))
    }

    It 'Function Format-Pairs with reducing function correctly calculates values' { 
        $array = @(1, 2, 3, 4, 5, 6)
        $array | Format-Pairs -Operation { $args[0] + $args[1] } | Should -Be @(3, 5, 7, 9, 11)
    }
}

Describe 'Reduce-Object' {
    It 'Reduce-Object exists' {
        Get-Command Reduce-Object | Should -Be -Not $null
    }

    It 'Reduce-Object with no provided script block or initial value sums values' {
        1 .. 10 | Reduce-Object | Should -Be 55
    }

    It 'Reduce-Object test failure' {
        1 .. 10 | Reduce-Object | Should -Be 999
    }

    It 'Reduce-Object skipped test' -Skip {
        1 .. 10 | Reduce-Object | Should -Be 999
    }
}
