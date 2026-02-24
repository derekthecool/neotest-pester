local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

-- local T = MiniTest.new_set()
local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      -- Restart child process with custom 'init.lua' script
      child.restart({ "-u", "scripts/minimal_init.lua" })
      -- Load tested plugin
      child.lua([[M = require('neotest-pester')]])
    end,
    -- Stop once all test cases are finished
    post_once = child.stop,
  },
})

---@class neotest.Adapter
local plugin = require("neotest-pester")

T["interface.root.works"] = function()
  local current_dir = vim.fs.normalize(vim.fn.getcwd())
  local directories = {
    current_dir,
    vim.fs.normalize(vim.fs.joinpath(current_dir, "lua")),
  }
  for _, value in ipairs(directories) do
    eq(current_dir, plugin.root(value))
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
    "test",
    "samples",
    "DotFunctional",
    "Test",
    "DotFunctional.Functions.Tests.ps1"
  )
  local tree
  local pester_test_example_file =
    "/home/derek/neovim/neotest-pester/tests/samples/DotFunctional/Test/DotFunctional.Functions.Tests.ps1"

  local nio = require("nio")
  local task = nio.run(function()
    tree = plugin.discover_positions(pester_test_example_file)
  end)
  eq("function", tree)
end

T["interface.build_spec"] = function()
  eq("function", type(plugin.build_spec))
end

T["interface.results"] = function()
  eq("function", type(plugin.results))
end

-- Major problems running these async tests
-- T["nio.async_run"] = function()
--   local nio = require("nio")
--   local task = nio.run(function()
--     nio.sleep(10)
--     print("Hello world")
--     local first = nio.process.run({
--       cmd = "printf",
--       args = { "hello" },
--     })
--     local output = first.stdout.read()
--     print(output)
--     eq("hi", output)
--   end)
-- end

-- T["pester.version_check"] = function()
--   local pester_version_check =
--     "(Get-Module -ListAvailable Pester | Sort-Object Version | Select-Object -Last 1 | Select-Object -ExpandProperty Version | Out-String).Trim()"
--
--   local nio = require("nio")
--
--   local task = nio.run(function()
--     local pester_check =
--       [[-NoProfile -Command '(Get-Module -ListAvailable Pester | Sort-Object Version | Select-Object -Last 1 | Select-Object -ExpandProperty Version).ToString()']]
--     local result = nio.process.run({ cmd = "pwsh", args = pester_check })
--     local check = result.stdout.read()
--     print(check)
--     eq("5.7.2", output)
--     eq("hello", check)
--   end)
-- end

return T
