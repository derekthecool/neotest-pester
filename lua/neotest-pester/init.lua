-- This plugin must implement the neotest interface: https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/adapters/interface.lua

---@return neotest.Adapter
local function create_adapter()
  local dotnet_utils = require("neotest-pester.dotnet_utils")
  local config = require("neotest-pester.config").get_config()

  --- TODO: (Derek Lomax) Sat 14 Feb 2026 11:10:37 PM MST, get DAP working
  --- @type dap.Configuration
  local dap_settings = vim.tbl_extend("force", {
    type = "netcoredbg",
    name = "netcoredbg - attach",
    request = "attach",
    env = {
      DOTNET_ENVIRONMENT = "Development",
    },
    justMyCode = false,
  }, config.dap_settings or {})

  ---@package
  ---@type neotest.Adapter
  ---@diagnostic disable-next-line: missing-fields
  local PesterNeotestAdapter = { name = "neotest-pester" }

  -- NOTE: Required for implementing neotest interface
  ---Find the project root directory given a current directory to work from.
  ---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
  ---@async
  ---@param dir string @Directory to treat as cwd
  ---@return string | nil @Absolute root dir of test suite
  function PesterNeotestAdapter.root(dir)
    -- Powershell does not really have the idea of a project root
    -- perhaps a .psd1 file, but it's not safe to assume there even is a module
    local lib = require("neotest.lib")
    return lib.files.match_root_pattern(".git")(dir) or dir
  end

  -- NOTE: Required for implementing neotest interface
  ---Filter directories when searching for test files
  ---@async
  ---@param name string Name of directory
  ---@param rel_path string Path to directory, relative to root
  ---@param root string Root directory of project
  ---@return boolean
  function PesterNeotestAdapter.filter_dir(name, rel_path, root)
    local logger = require("neotest.logging")
    logger.trace("neotest-pester: filtering dir", name, rel_path, root)

    if name == "bin" or name == "obj" then
      return false
    end

    return true
  end

  -- NOTE: Required for implementing neotest interface
  ---@async
  ---@param file_path string
  ---@return boolean
  function PesterNeotestAdapter.is_test_file(file_path)
    local logger = require("neotest.logging")
    local client_discovery = require("neotest-pester.client")
    logger.debug("neotest-pester: checking if file is test file: " .. file_path)
    local isPowershellFile = (vim.endswith(file_path, ".Tests.ps1"))

    if not isPowershellFile then
      return false
    end

    -- -- local client = client_discovery.get_client_for_project(project, solution)
    -- local client = TestClient:new(project, client)
    --
    -- if not client then
    --   logger.debug(
    --     "neotest-pester: marking file as non-test file since no client was found: " .. file_path
    --   )
    --   return false
    -- end
    --
    -- local tests_in_file = client:discover_tests_for_path(file_path)
    --
    -- if not tests_in_file or next(tests_in_file) == nil then
    --   logger.debug(
    --     string.format(
    --       "neotest-pester: marking file as non-test file since no tests was found in file %s",
    --       file_path
    --     )
    --   )
    --   return false
    -- end

    return true
  end

  local function get_match_type(captured_nodes)
    if captured_nodes["test.name"] then
      return "test"
    end
    if captured_nodes["namespace.name"] then
      return "namespace"
    end
  end

  local function build_structure(positions, namespaces, opts)
    local lib = require("neotest.lib")

    ---@type neotest.Position
    local parent = table.remove(positions, 1)
    if not parent then
      return nil
    end
    parent.id = parent.type == "file" and parent.path or opts.position_id(parent, namespaces)
    local current_level = { parent }
    local child_namespaces = vim.list_extend({}, namespaces)
    if
      parent.type == "namespace"
      or parent.type == "parameterized"
      or (opts.nested_tests and parent.type == "test")
    then
      child_namespaces[#child_namespaces + 1] = parent
    end
    if not parent.range then
      return current_level
    end
    while true do
      local next_pos = positions[1]
      if not next_pos or (next_pos.range and not lib.positions.contains(parent, next_pos)) then
        -- Don't preserve empty namespaces
        if #current_level == 1 and parent.type == "namespace" then
          return nil
        end
        if opts.require_namespaces and parent.type == "test" and #namespaces == 0 then
          return nil
        end
        return current_level
      end

      if parent.type == "parameterized" then
        local pos = table.remove(positions, 1)
        current_level[#current_level + 1] = pos
      else
        local sub_tree = build_structure(positions, child_namespaces, opts)
        if opts.nested_tests or parent.type ~= "test" then
          current_level[#current_level + 1] = sub_tree
        end
      end
    end
  end

  ---@param source string
  ---@param captured_nodes any
  ---@param tests_in_file table<string, neotest-pester.TestCase>
  ---@param path string
  ---@return nil | neotest.Position | neotest.Position[]
  local function build_position(source, captured_nodes, tests_in_file, path)
    local match_type = get_match_type(captured_nodes)
    if match_type then
      local definition = captured_nodes[match_type .. ".definition"]

      ---@type neotest.Position[]
      local positions = {}

      if match_type == "test" then
        for id, test in pairs(tests_in_file) do
          if
            definition:start() <= test.LineNumber - 1 and test.LineNumber - 1 <= definition:end_()
          then
            table.insert(positions, {
              id = id,
              type = match_type,
              path = path,
              name = test.DisplayName,
              range = { definition:range() },
            })
            tests_in_file[id] = nil
          end
        end
      else
        local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
        table.insert(positions, {
          type = match_type,
          path = path,
          name = string.gsub(name, "``", ""),
          range = { definition:range() },
        })
      end

      if #positions > 1 then
        local pos = positions[1]
        table.insert(positions, 1, {
          type = "parameterized",
          path = pos.path,
          -- remove parameterized part of test name
          name = pos.name:gsub("<.*>", ""):gsub("%(.*%)", ""),
          range = pos.range,
        })
      end

      return positions
    end
  end

  --- Some adapters do not provide the file which the test is defined in.
  --- In those cases we nest the test cases under the solution file.
  ---@param project DotnetProjectInfo
  -- local function get_top_level_tests(project)
  --   local types = require("neotest.types")
  --   local logger = require("neotest.logging")
  --   local client_discovery = require("neotest-pester.client")
  --
  --   if not project then
  --     return {}
  --   end
  --
  --   local client = client_discovery.get_client_for_project(project, solution)
  --
  --   if not client then
  --     logger.debug(
  --       "neotest-pester: not discovering top-level tests due to no client for project: "
  --         .. vim.inspect(project)
  --     )
  --   end
  --
  --   local tests_in_file = (client and client:discover_tests()) or {}
  --   local tests_in_project = tests_in_file[project.proj_file]
  --   logger.debug(string.format("neotest-pester: top-level tests in file: %s", project.proj_file))
  --
  --   if not tests_in_project or next(tests_in_project) == nil then
  --     return
  --   end
  --
  --   local n = vim.tbl_count(tests_in_project)
  --
  --   local nodes = {
  --     {
  --       type = "file",
  --       path = project.proj_file,
  --       name = vim.fs.basename(project.proj_file),
  --       range = { 0, 0, n + 1, -1 },
  --     },
  --   }
  --
  --   local i = 0
  --
  --   -- add tests which does not have a matching tree-sitter node.
  --   for id, test in pairs(tests_in_project) do
  --     nodes[#nodes + 1] = {
  --       id = id,
  --       type = "test",
  --       path = test.CodeFilePath,
  --       name = test.DisplayName,
  --       range = { i, 0, i + 1, -1 },
  --     }
  --     i = i + 1
  --   end
  --
  --   if #nodes <= 1 then
  --     return {}
  --   end
  --
  --   local structure = assert(build_structure(nodes, {}, {
  --     nested_tests = false,
  --     require_namespaces = false,
  --     position_id = function(position, parents)
  --       return position.id
  --         or vim
  --           .iter({
  --             position.path,
  --             vim.tbl_map(function(pos)
  --               return pos.name
  --             end, parents),
  --             position.name,
  --           })
  --           :flatten()
  --           :join("::")
  --     end,
  --   }))
  --
  --   return types.Tree.from_list(structure, function(pos)
  --     return pos.id
  --   end)
  -- end

  -- NOTE: Required for implementing neotest interface
  ---Given a file path, parse all the tests within it.
  ---@async
  ---@param file_path string Absolute file path
  ---@return neotest.Tree | nil
  function PesterNeotestAdapter.discover_positions(file_path)
    local nio = require("nio")
    local lib = require("neotest.lib")
    local types = require("neotest.types")
    local logger = require("neotest.logging")
    local client_discovery = require("neotest-pester.client")

    if not file_path:match("%.Tests%.ps1$") then
      logger.verbose(string.format("not a test file: %s", file_path))
      return nil
    end

    logger.info(string.format("neotest-pester: scanning %s for tests...", file_path))

    local tree
    local content = lib.files.read(file_path)
    tests_in_file = nio.fn.deepcopy(tests_in_file)
    local lang_tree =
      vim.treesitter.get_string_parser(content, "powershell", { injections = { [filetype] = "" } })

    local root = lang_tree:parse(false)[1]:root()

    local query =
      lib.treesitter.normalise_query("powershell", require("neotest-pester.queries.powershell"))

    local sep = lib.files.sep
    local path_elems = vim.split(file_path, sep, { plain = true })
    local nodes = {
      {
        type = "file",
        path = file_path,
        name = path_elems[#path_elems],
        range = { root:range() },
      },
    }
    for _, match in query:iter_matches(root, content, nil, nil, { all = false }) do
      local captured_nodes = {}
      for i, capture in ipairs(query.captures) do
        captured_nodes[capture] = match[i]
      end
      local res = build_position(content, captured_nodes, tests_in_file, file_path)
      if res then
        for _, pos in ipairs(res) do
          nodes[#nodes + 1] = pos
        end
      end
    end

    -- add tests which does not have a matching tree-sitter node.
    for id, test in pairs(tests_in_file) do
      local line = test.LineNumber or 0
      nodes[#nodes + 1] = {
        id = id,
        type = "test",
        path = file_path,
        name = test.DisplayName,
        range = { line - 1, 0, line - 1, -1 },
      }
    end

    -- for _, node in ipairs(nodes) do
    --   node.project = project
    -- end

    if #nodes <= 1 then
      logger.debug(string.format("no tests found in path: %s", file_path))
      return {}
    end

    local structure = assert(build_structure(nodes, {}, {
      nested_tests = false,
      require_namespaces = false,
      position_id = function(position, parents)
        return position.id
          or vim
            .iter({
              position.path,
              vim.tbl_map(function(pos)
                return pos.name
              end, parents),
              position.name,
            })
            :flatten()
            :join("::")
      end,
    }))

    tree = types.Tree.from_list(structure, function(pos)
      return pos.id
    end)

    logger.info(string.format("neotest-pester: done scanning %s for tests", file_path))

    return tree
  end

  -- NOTE: Required for implementing neotest interface
  ---@param args neotest.RunArgs
  ---@return nil | neotest.RunSpec | neotest.RunSpec[]
  function PesterNeotestAdapter.build_spec(args)
    local nio = require("nio")
    local lib = require("neotest.lib")
    local logger = require("neotest.logging")
    local utilities = require("neotest-pester.utilities")
    local client_discovery = require("neotest-pester.client")

    local projects = {}

    local tree = args.tree
    if not tree then
      return
    end

    for _, position in tree:iter() do
      if position.type == "test" then
        logger.debug(position)
        local client = client_discovery.get_client_for_project(position.project, solution)
        if client then
          local tests = projects[client] or {}
          projects[client] = vim.list_extend(tests, { position.id })
        else
          vim.notify_once(
            string.format(
              "neotest-pester: could not find adapter client for test '%s' in project '%s'",
              position.name,
              vim.inspect(position.project)
            ),
            vim.log.levels.ERROR
          )
        end
      end
    end

    local stream_path = nio.fn.tempname()
    lib.files.write(stream_path, "")
    local stream = utilities.stream_queue()

    return {
      context = {
        client_id_map = projects,
        solution = solution,
        results = {},
        write_stream = stream.write,
      },
      stream = function()
        return function()
          local new_results = stream.get()

          logger.info("neotest-pester: received streamed test results in adapter spec")
          logger.debug(new_results)

          return { [new_results.id] = new_results.result }
        end
      end,
      strategy = (args.strategy == "dap" and require("neotest-pester.strategies.pester_debugger")(
        dap_settings
      )) or require("neotest-pester.strategies.pester"),
    }
  end

  -- NOTE: Required for implementing neotest interface
  ---@async
  ---@param spec neotest.RunSpec
  ---@param result neotest.StrategyResult
  ---@param tree neotest.Tree
  ---@return table<string, neotest.Result>
  function PesterNeotestAdapter.results(spec, result, tree)
    local types = require("neotest.types")
    local logger = require("neotest.logging")

    logger.info("neotest-pester: waiting for test results")
    logger.debug(spec)
    logger.debug(result)
    ---@type table<string, neotest.Result>
    local results = spec.context.results or {}

    if not results then
      for _, id in ipairs(vim.tbl_values(spec.context.projects_id_map)) do
        results[id] = {
          status = types.ResultStatus.skipped,
          output = spec.context.result_path,
          errors = {
            { message = result.output },
            { message = "failed to read result file" },
          },
        }
      end
      return results
    end

    logger.debug(results)

    return results
  end

  return PesterNeotestAdapter
end

local PesterNeotestAdapter = create_adapter()

---@param opts neotest-pester.Config
local function apply_user_settings(_, opts)
  vim.g.neotest_pester = vim.tbl_deep_extend("force", vim.g.neotest_pester or {}, opts or {})
  return create_adapter()
end

setmetatable(PesterNeotestAdapter, {
  __call = apply_user_settings,
})

return PesterNeotestAdapter
