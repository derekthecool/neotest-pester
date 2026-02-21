local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality
local nio = require("nio")

local T = MiniTest.new_set()

---@class neotest.Adapter
local plugin = require("neotest-pester")

T["interface.root.works"] = function()
  local directories = {
    "/home/tester/powershell",
    "blah-blah-blah",
    "powershell/is/awesome",
  }
  for _, value in ipairs(directories) do
    eq(vim.fn.getcwd(), plugin.root(value))
  end
end

T["interface.root.return nil if passed nil"] = function()
  eq(nil, plugin.root())
end

T["interface.filter_dir.works"] = function()
  local directories = {
    "/home/tester/powershell",
    "blah-blah-blah",
    "powershell/is/awesome",
  }
  for _, value in ipairs(directories) do
    eq(true, plugin.filter_dir(value, "", plugin.root(value)))
  end
end

T["interface.discover_positions"] = function()
  local pester_test_example_file = vim.fs.joinpath(
    vim.fn.getcwd(),
    "spec",
    "samples",
    "DotFunctional",
    "Test",
    "DotFunctional.Functions.Tests.ps1"
  )
  local tree
  local task = nio.run(function()
    tree = plugin.discover_positions(pester_test_example_file)
  end)
  -- eq("function", pester_test_example_file)
  eq("function", tree)
end

T["interface.build_spec"] = function()
  eq("function", type(plugin.build_spec))
end

T["interface.results"] = function()
  eq("function", type(plugin.results))
end

return T
