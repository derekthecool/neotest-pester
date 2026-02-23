Get-ChildItem $PSScriptRoot/Source -Recurse -Filter '*.ps1' | ForEach-Object {
    Write-Verbose "In $PSScriptRoot, sourcing file $_"
    . $_.FullName
}
