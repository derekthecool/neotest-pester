# Guide to Running Pester Tests

## How to run a single test

```powershell
# Use a deprecated pester 4 using the -FullNameFilter
# [Describe block name].[It block name]
Invoke-Pester -FullNameFilter 'Format-Pairs.Function Format-Pairs exists'
# Use wildcard for describe block and full name for It block
Invoke-Pester -FullNameFilter '*Function Format-Pairs exists'
```

Do it again but with full output parsing

```powershell
Invoke-Pester -FullNameFilter '*Function Format-Pairs exists' -PassThru 6>$null | ForEach-Object Tests | Select-Object Result, ExpandedName | ConvertTo-Json

$T=Invoke-Pester -PassThru 6>$null; $T.tests | Sort-Object ExpandedName -Unique | Select-Object Result, ExpandedName | ConvertTo-Json
pwsh -NoProfile -Command '$T=Invoke-Pester -PassThru 6>$null; $T.tests | Sort-Object ExpandedName -Unique | Select-Object Result, ExpandedName | ConvertTo-Json -Compress'
```

## Parse Output Easily

The most easy way to parse output has to be using the `Invoke-Pester -PassThru` option.
This can then be filtered down and formatted as json.

Example full json output from the command:

```powershell
Invoke-Pester -PassThru | ConvertTo-Json -Depth 3 -Compress:$false
```

The output is so large I don't want to write it here.

Example with command that can extract all important information and export json

```powershell
# NOTE: 6>$null sends the verbose output of pester to the trash giving a clean output
Invoke-Pester -PassThru 6>$null | ForEach-Object Tests | Select-Object Result, ExpandedName | ConvertTo-Json
```

```json
[
  { "Result": "Passed", "ExpandedName": "Function Format-Pairs exists" },
  {
    "Result": "Passed",
    "ExpandedName": "Function Format-Pairs without reducing function creates an array of arrays"
  },
  {
    "Result": "Passed",
    "ExpandedName": "Function Format-Pairs with reducing function correctly calculates values"
  },
  { "Result": "Passed", "ExpandedName": "Reduce-Object exists" },
  {
    "Result": "Passed",
    "ExpandedName": "Reduce-Object with no provided script block or initial value sums values"
  },
  { "Result": "Failed", "ExpandedName": "Reduce-Object test failure" },
  { "Result": "Skipped", "ExpandedName": "Reduce-Object skipped test" }
]
```
