describe("Test test detection", function()
  -- increase nio.test timeout
  vim.env.PLENARY_TEST_TIMEOUT = 80000
  -- add test_discovery script and treesitter parsers installed with luarocks
  vim.opt.runtimepath:append(vim.fn.getcwd())
  vim.opt.runtimepath:append(vim.fn.expand("~/.luarocks/lib/lua/5.1/"))

  local nio = require("nio")
  ---@type neotest.Adapter
  local plugin
  local powershell_module_path = vim.fn.getcwd() .. "/spec/samples/DotFunctional"

  lazy_setup(function()
    require("neotest").setup({
      adapters = { require("neotest-pester") },
      log_level = 0,
    })
    plugin = require("neotest-pester")

    -- `root` is an async function. Use `nio.create` to be able to
    -- run it in synchronous context as lazy_setup is not async
    local root = nio.create(plugin.root, 1)
    root(powershell_module_path)
  end)

  nio.tests.it("detect tests in ps1 file", function()
    local test_file = powershell_module_path .. "/Test/DotFunctional.Functions.Tests.ps1"
    local positions = plugin.discover_positions(test_file)

    local tests = {}

    assert.is_not_nil(positions)

    for _, position in positions:iter() do
      if position.type == "test" then
        tests[#tests + 1] = position.name
      end
    end

    local expected_tests = {
      "Function Format-Pairs exists",
      "Function Format-Pairs without reducing function creates an array of arrays",
      "Function Format-Pairs with reducing function correctly calculates values",
      "Reduce-Object exists",
      "Reduce-Object with no provided script block or initial value sums values",
    }

    table.sort(expected_tests)
    table.sort(tests)

    assert.are_same(expected_tests, tests)
  end)

  -- nio.tests.it("filter non test directory", function()
  --   assert.is_false(plugin.filter_dir("bin", "/src/CSharpTest/bin", powershell_module_path))
  -- end)
  --
  -- nio.tests.it("not filter test directory", function()
  --   assert.is_truthy(plugin.filter_dir("CSharpTest", "/src/CSharpTest", powershell_module_path))
  -- end)
end)
