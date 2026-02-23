@{
  RootModule        = 'DotFunctional.psm1'
  ModuleVersion     = '0.1.0'
  GUID              = '2cfbaa2f-a382-44de-8350-2d9619befb8d'
  Author            = 'Derek Lomax'
  Description       = 'Functional library for an easier time with map, filter, reduce, zip etc.'
  PrivateData       = @{
    PSData = @{
      Tags = @('dots')
    }
  }
  VariablesToExport = ''
  CmdletsToExport   = @()
  AliasesToExport   = @(
    'Zip'
    'Reduce'
    'Sum'
  )
  FunctionsToExport = @(
    'Format-Pairs'
    'Reduce-Object'
  )
}
