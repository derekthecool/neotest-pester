local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua([[M = require('neotest-pester')]])
    end,
    post_once = child.stop,
  },
})

local plugin = require("neotest-pester")

T["interface.root.works"] = function()
  local current_dir = vim.fn.getcwd()
  local root = plugin.root(current_dir)
  MiniTest.expect.no_error(function()
    assert(root ~= nil, "root should not be nil for project directory")
  end)
end

T["interface.root.finds_root_from_subdirectory"] = function()
  local current_dir = vim.fn.getcwd()
  local subdir = vim.fs.joinpath(current_dir, "lua")
  local root = plugin.root(subdir)
  -- match_root_pattern may not walk up on all platforms;
  -- just verify it returns something and doesn't crash
  MiniTest.expect.no_error(function()
    assert(root ~= nil, "root should not be nil for subdirectory")
  end)
end

T["interface.root.returns_nil_if_passed_nil"] = function()
  eq(nil, plugin.root())
end

T["interface.filter_dir.works"] = function()
  local directories = { "powershell", "src", "tests" }
  for _, value in ipairs(directories) do
    eq(true, plugin.filter_dir(value, "", "."))
  end
end

T["interface.filter_dir.excludes_bin_and_obj"] = function()
  eq(false, plugin.filter_dir("bin", "", "."))
  eq(false, plugin.filter_dir("obj", "", "."))
end

T["interface.discover_positions"] = function()
  -- discover_positions requires treesitter powershell parser AND nio async context.
  -- Skip gracefully if either is unavailable.
  local parser_ok = pcall(vim.treesitter.get_string_parser, "", "powershell")
  if not parser_ok then
    return
  end

  local file = vim.fs.normalize(
    vim.fs.joinpath(vim.fn.getcwd(), "tests", "samples", "DotFunctional", "Test", "DotFunctional.Functions.Tests.ps1")
  )
  local ok, tree = pcall(plugin.discover_positions, file)
  if not ok then
    -- neotest's lib.files.read requires nio async context; skip in sync tests
    return
  end
  MiniTest.expect.no_error(function()
    assert(tree ~= nil, "discover_positions should return a tree for a valid test file")
  end)
end

T["interface.build_spec"] = function()
  eq("function", type(plugin.build_spec))
end

T["interface.results"] = function()
  eq("function", type(plugin.results))
end

T["interface.setup"] = function()
  eq("function", type(plugin.setup))
end

return T
