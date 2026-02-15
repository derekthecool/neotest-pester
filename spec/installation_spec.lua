describe("Test environment", function()
  -- before_each(function()
  --   -- Run time path is not getting loaded automatically, so modify it before each test
  --   print("Attempting to add to neovim runtime path with current plugin location")
  --   local path_to_plugin = debug.getinfo(1).source:match("@(.*[/\\]lua[/\\])"):gsub('"', "")
  --   print(
  --     string.format(
  --       "Attempting to add: %s to neovim runtimepath because plenary tests fail without this",
  --       path_to_plugin
  --     )
  --   )
  --   vim.cmd("set runtimepath+=" .. path_to_plugin)
  -- end)

  it("Test can access vim namespace", function()
    assert(vim, "Cannot access vim namespace")
    assert.are.same(vim.trim("  a "), "a")
  end)
  it("Test can access neotest dependency", function()
    assert(require("neotest"), "neotest")
  end)
  it("Test can access module in lua/neotest-pester", function()
    assert(require("neotest-pester"), "Could not access main module")
  end)
end)
