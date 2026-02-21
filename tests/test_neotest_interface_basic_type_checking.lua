local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local T = MiniTest.new_set()

--[[
-- neotest interface: https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/adapters/interface.lua
local neotest = {}

---@class neotest.Adapter
---@field name string
neotest.Adapter = {}

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function neotest.Adapter.root(dir) end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function neotest.Adapter.filter_dir(name, rel_path, root) end

---@async
---@param file_path string
---@return boolean
function neotest.Adapter.is_test_file(file_path) end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function neotest.Adapter.discover_positions(file_path) end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function neotest.Adapter.build_spec(args) end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function neotest.Adapter.results(spec, result, tree) end
]]

---@class neotest.Adapter
local plugin = require("neotest-pester")

T["interface.main"] = function()
  eq("table", type(plugin))
end

T["interface.name"] = function()
  eq("neotest-pester", plugin.name)
end

T["interface.root"] = function()
  eq("function", type(plugin.root))
end

T["interface.filter_dir"] = function()
  eq("function", type(plugin.filter_dir))
end

T["interface.discover_positions"] = function()
  eq("function", type(plugin.discover_positions))
end

T["interface.build_spec"] = function()
  eq("function", type(plugin.build_spec))
end

T["interface.results"] = function()
  eq("function", type(plugin.results))
end

return T
