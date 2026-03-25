local M = {}

---@class neotest-pester.DapSettings
---@field type? string DAP adapter type (e.g., "ps1"). Default: "ps1"
---@field request? string DAP request type. Default: "launch"

---@alias PesterSkipRemainingOnFailure "None"|"Run"|"Container"|"Block"
---@alias PesterCodeCoverageFormat "JaCoCo"|"CoverageGutters"|"Cobertura"
---@alias PesterTestResultFormat "NUnitXml"|"NUnit2.5"|"NUnit3"|"JUnitXml"
---@alias PesterErrorAction "Stop"|"Continue"
---@alias PesterVerbosity "None"|"Normal"|"Detailed"|"Diagnostic"
---@alias PesterStackTraceVerbosity "None"|"FirstLine"|"Filtered"|"Full"
---@alias PesterCIFormat "None"|"Auto"|"AzureDevops"|"GithubActions"
---@alias PesterCILogLevel "Error"|"Warning"
---@alias PesterRenderMode "Auto"|"Ansi"|"ConsoleColor"|"Plaintext"

---@class (exact) PesterConfiguration.Run
---@field Path? string[] Directories to be searched for tests, paths directly to test files, or combination of both. Default: {"."}
---@field ExcludePath? string[] Directories or files to be excluded from the run. Default: {}
---@field ScriptBlock? table[] ScriptBlocks containing tests to be executed. Default: {}
---@field Container? table[] ContainerInfo objects containing tests to be executed. Default: {}
---@field TestExtension? string Filter used to identify test files. Default: ".Tests.ps1"
---@field Exit? boolean Exit with non-zero exit code when the test run fails. Default: false
---@field Throw? boolean Throw an exception when test run fails. Default: false
---@field PassThru? boolean Return result object to the pipeline after finishing the test run. Default: false
---@field SkipRun? boolean Runs the discovery phase but skips run. Use it with PassThru to get object populated with all tests. Default: false
---@field SkipRemainingOnFailure? PesterSkipRemainingOnFailure Skips remaining tests after failure for selected scope. Default: "None"

---@class (exact) PesterConfiguration.Filter
---@field Tag? string[] Tags of Describe, Context or It to be run. Default: {}
---@field ExcludeTag? string[] Tags of Describe, Context or It to be excluded from the run. Default: {}
---@field Line? string[] Filter by file and scriptblock start line, useful to run parsed tests programmatically. Example: 'C:\tests\file1.Tests.ps1:37'. Default: {}
---@field ExcludeLine? string[] Exclude by file and scriptblock start line, takes precedence over Line. Default: {}
---@field FullName? string[] Full name of test with -like wildcards, joined by dot. Example: '*.describe Get-Item.test1'. Default: {}

---@class (exact) PesterConfiguration.CodeCoverage
---@field Enabled? boolean Enable CodeCoverage. Default: false
---@field OutputFormat? PesterCodeCoverageFormat Format to use for code coverage report. Default: "JaCoCo"
---@field OutputPath? string Path relative to the current directory where code coverage report is saved. Default: "coverage.xml"
---@field OutputEncoding? string Encoding of the output file. Default: "UTF8"
---@field Path? string[] Directories or files to be used for code coverage. By default the Path(s) from general settings are used, unless overridden here. Default: {}
---@field ExcludeTests? boolean Exclude tests from code coverage. This uses the TestFilter from general configuration. Default: true
---@field RecursePaths? boolean Will recurse through directories in the Path option. Default: true
---@field CoveragePercentTarget? number Target percent of code coverage that you want to achieve. Default: 75.0
---@field UseBreakpoints? boolean EXPERIMENTAL: When false, use Profiler based tracer to do CodeCoverage instead of using breakpoints. Default: true
---@field SingleHitBreakpoints? boolean Remove breakpoint when it is hit. Default: true

---@class (exact) PesterConfiguration.TestResult
---@field Enabled? boolean Enable TestResult. Default: false
---@field OutputFormat? PesterTestResultFormat Format to use for test result report. Default: "NUnitXml"
---@field OutputPath? string Path relative to the current directory where test result report is saved. Default: "testResults.xml"
---@field OutputEncoding? string Encoding of the output file. Default: "UTF8"
---@field TestSuiteName? string Set the name assigned to the root 'test-suite' element. Default: "Pester"

---@class (exact) PesterConfiguration.Should
---@field ErrorAction? PesterErrorAction Controls if Should throws on error. Use 'Stop' to throw on error, or 'Continue' to fail at the end of the test. Default: "Stop"

---@class (exact) PesterConfiguration.Debug
---@field ShowFullErrors? boolean Show full errors including Pester internal stack. This property is deprecated, and if set to true it will override Output.StackTraceVerbosity to 'Full'. Default: false
---@field WriteDebugMessages? boolean Write Debug messages to screen. Default: false
---@field WriteDebugMessagesFrom? string[] Write Debug messages from a given source, WriteDebugMessages must be set to true for this to work. Supports like wildcards. Default: {"Discovery","Skip","Mock","CodeCoverage"}
---@field ShowNavigationMarkers? boolean Write paths after every block and test, for easy navigation in VSCode. Default: false
---@field ReturnRawResultObject? boolean Returns unfiltered result object, this is for development only. Default: false

---@class (exact) PesterConfiguration.Output
---@field Verbosity? PesterVerbosity The verbosity of output. Default: "Normal"
---@field StackTraceVerbosity? PesterStackTraceVerbosity The verbosity of stacktrace output. Default: "Filtered"
---@field CIFormat? PesterCIFormat The CI format of error output in build logs. Default: "Auto"
---@field CILogLevel? PesterCILogLevel The CI log level in build logs. Default: "Error"
---@field RenderMode? PesterRenderMode The mode used to render console output. Default: "Auto"

---@class (exact) PesterConfiguration.TestDrive
---@field Enabled? boolean Enable TestDrive. Default: true

---@class (exact) PesterConfiguration.TestRegistry
---@field Enabled? boolean Enable TestRegistry. Default: true

---@class (exact) PesterConfiguration
---@field Run? PesterConfiguration.Run Run configuration options
---@field Filter? PesterConfiguration.Filter Filter configuration options
---@field CodeCoverage? PesterConfiguration.CodeCoverage Code coverage configuration options
---@field TestResult? PesterConfiguration.TestResult Test result output configuration options
---@field Should? PesterConfiguration.Should Should assertion configuration options
---@field Debug? PesterConfiguration.Debug Debug configuration options
---@field Output? PesterConfiguration.Output Output configuration options
---@field TestDrive? PesterConfiguration.TestDrive TestDrive configuration options
---@field TestRegistry? PesterConfiguration.TestRegistry TestRegistry configuration options

---@class (exact) neotest-pester.Config
---@field pwsh_path? string Path to pwsh executable. Default: "pwsh"
---@field pester_configuration? PesterConfiguration PesterConfiguration overrides (merged into generated config)
---@field timeout_ms? number Milliseconds to wait before timing out. Default: 150000
---@field dap_settings? neotest-pester.DapSettings DAP debug configuration

---@type neotest-pester.Config
local default_config = {
  timeout_ms = 5 * 30 * 1000,
  pwsh_path = "pwsh",
  pester_configuration = {},
  dap_settings = {},
}

---@type neotest-pester.Config
local _config = vim.deepcopy(default_config)

---Configure neotest-pester with user options.
---Resets to defaults first, then merges opts on top.
---@param opts? neotest-pester.Config
function M.setup(opts)
  _config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})
end

---@return neotest-pester.Config
function M.get_config()
  return _config
end

---Reset config to defaults (useful for test isolation).
function M.reset()
  _config = vim.deepcopy(default_config)
end

return M
