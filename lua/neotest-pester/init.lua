-- This plugin implements the neotest adapter interface:
-- https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/adapters/interface.lua

local config = require("neotest-pester.config")

---@type neotest.Adapter
local PesterNeotestAdapter = { name = "neotest-pester" }

---Find the project root directory by walking up to find .git.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function PesterNeotestAdapter.root(dir)
  if not dir then
    return nil
  end
  local found = vim.fs.find(".git", { path = dir, upward = true, type = "directory" })
  if #found > 0 then
    return vim.fs.dirname(found[1])
  end
  return dir
end

---Filter directories when searching for test files.
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function PesterNeotestAdapter.filter_dir(name, rel_path, root)
  if name == "bin" or name == "obj" then
    return false
  end
  return true
end

---Check if a file is a Pester test file.
---@async
---@param file_path string
---@return boolean
function PesterNeotestAdapter.is_test_file(file_path)
  return vim.endswith(file_path, ".Tests.ps1")
end

---Given a file path, parse all the tests within it using treesitter.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function PesterNeotestAdapter.discover_positions(file_path)
  local lib = require("neotest.lib")
  local pester_treesitter_query = [[
;; pester describe blocks
(command
  (command_name)@function_name (#match? @function_name "[Dd][Ee][Ss][Cc][Rr][Ii][Bb][Ee]")
  (command_elements
    (array_literal_expression
      (unary_expression
        (string_literal
          (verbatim_string_characters)@namespace.name
        )
      )
    )
  )
)@namespace.definition

;; pester it blocks
(command
  (command_name)@function_name (#match? @function_name "[Ii][tt]")
  (command_elements
    (array_literal_expression
      (unary_expression
        (string_literal
          (verbatim_string_characters)@test.name
        )
      )
    )
  )
)@test.definition
]]
  return lib.treesitter.parse_positions(file_path, pester_treesitter_query)
end

---Build the run specification for executing tests.
---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function PesterNeotestAdapter.build_spec(args)
  local nio = require("nio")
  local logger = require("neotest.logging")
  local spec_builder = require("neotest-pester.spec_builder")

  local tree = args.tree
  if not tree then
    return
  end

  local cfg = config.get_config()
  local position = tree:data()
  local results_path = nio.fn.tempname()

  local ps_script = spec_builder.build_script(position, results_path, cfg)
  logger.debug("neotest-pester: ps_script: ", ps_script)

  local run_spec = {
    command = { cfg.pwsh_path, "-NoProfile", "-Command", ps_script },
    context = {
      results_path = results_path,
      stop_stream = function() end,
    },
  }

  -- DAP debug strategy
  if args.strategy == "dap" then
    local script_file = nio.fn.tempname() .. ".ps1"
    local f = io.open(script_file, "w")
    if f then
      f:write(spec_builder.build_dap_script(position, results_path, cfg))
      f:close()
    end

    run_spec.strategy = vim.tbl_extend("force", {
      type = "ps1",
      name = "neotest-pester: debug",
      request = "launch",
      script = script_file,
    }, cfg.dap_settings or {})
  end

  return run_spec
end

---Parse test results from the JSON output file.
---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function PesterNeotestAdapter.results(spec, result, tree)
  local types = require("neotest.types")
  local logger = require("neotest.logging")
  local spec_builder = require("neotest-pester.spec_builder")

  logger.info("neotest-pester: waiting for test results")

  ---@type table<string, neotest.Result>
  local results = {}

  spec.context.stop_stream()

  -- Read structured JSON results from the dedicated temp file (not stdout).
  -- Uses io.open (synchronous) so this works regardless of async context.
  local results_path = spec.context.results_path
  local f = io.open(results_path, "r")
  if not f then
    logger.error("neotest-pester: No results file found at ", results_path)
    return {}
  end
  local data = f:read("*a")
  f:close()

  logger.info("neotest-pester: results file contents ", data)

  local ok, parsed = pcall(vim.json.decode, data, { luanil = { object = true } })

  if not ok or type(parsed) ~= "table" then
    logger.error("neotest-pester: Failed to parse results JSON from ", results_path)
    return {}
  end

  logger.info("neotest-pester: parsed json: ", parsed)

  for _, position in tree:iter() do
    if position.type == "test" or position.type == "namespace" then
      local parts = vim.split(position.id, "::")
      local tree_test_name = spec_builder.strip_quotes(parts[#parts])

      for _, test_result in pairs(parsed) do
        if tree_test_name == test_result.ExpandedName then
          logger.debug("neotest-pester: matched tree test name: ", tree_test_name)

          local status
          if test_result.Result == "Passed" then
            status = types.ResultStatus.passed
          elseif test_result.Result == "Failed" then
            status = types.ResultStatus.failed
          elseif test_result.Result == "Skipped" then
            status = types.ResultStatus.skipped
          end

          local err_msg = test_result.ErrorMessage
          results[position.id] = {
            status = status,
            short = err_msg or nil,
            errors = err_msg
                and { { message = err_msg, line = position.range and position.range[1] } }
              or nil,
            output = result.output,
          }
        end
      end
    end
  end

  logger.debug("neotest-pester: final results: ", results)

  return results
end

---Configure the adapter with user options.
---@param opts? neotest-pester.Config
---@return neotest.Adapter
function PesterNeotestAdapter.setup(opts)
  config.setup(opts)
  return PesterNeotestAdapter
end

setmetatable(PesterNeotestAdapter, {
  __call = function(_, opts)
    return PesterNeotestAdapter.setup(opts)
  end,
})

return PesterNeotestAdapter
