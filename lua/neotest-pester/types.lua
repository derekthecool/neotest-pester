---@class neotest-pester.TestCase
---@field DisplayName string
---@field FullyQualifiedName string
---@field LineNumber number
---@field CodeFilePath string

---@class neotest-pester.Client.RunResult
---@field pid string
---@field start_client async fun(): nil
---@field output_stream fun(): string[]
---@field result_stream async fun(): any
---@field result_future nio.control.Future
---@field stop fun()

---@class neotest-pester.Client
---@field project DotnetProjectInfo
---@field test_cases table<string, table<string, neotest-pester.TestCase>>
---@field discover_tests fun(self: neotest-pester.Client): table<string, table<string, neotest-pester.TestCase>>
---@field run_tests fun(self: neotest-pester.Client, ids: string|string[]): neotest-pester.Client.RunResult
---@field debug_tests fun(self: neotest-pester.Client, ids: string|string[]): neotest-pester.Client.RunResult
