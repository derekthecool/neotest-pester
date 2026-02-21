-- This plugin must implement the neotest interface: https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/adapters/interface.lua

---@return neotest.Adapter
local function create_adapter()
  -- local dotnet_utils = require("neotest-pester.dotnet_utils")
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

  ---Parse the file using treesitter and your queries
  ---@param content string
  ---@param file_path string
  ---@return table[]
  local function parse_with_treesitter(content, file_path)
    local lib = require("neotest.lib")
    local logger = require("neotest.logging")
    local nodes = {}

    -- Get treesitter parser
    local ok, parser = pcall(vim.treesitter.get_string_parser, content, "powershell")
    if not ok or not parser then
      logger.error("Failed to get treesitter parser for powershell")
      return nodes
    end

    -- Parse the content
    local tree = parser:parse()[1]
    if not tree then
      logger.error("Failed to parse file with treesitter")
      return nodes
    end

    local root = tree:root()

    -- Load your query
    local query_string = require("neotest-pester.queries.powershell")
    local ok, query = pcall(vim.treesitter.query.parse, "powershell", query_string)
    if not ok then
      logger.error("Failed to parse treesitter query: " .. tostring(query))
      return nodes
    end

    -- Iterate through all matches
    for pattern, match, metadata in query:iter_matches(root, content, 0, -1) do
      local node_info = {
        nodes = {},
        type = nil,
        name = nil,
        range = nil,
      }

      -- Process captures for this match
      for id, node in pairs(match) do
        local capture_name = query.captures[id]

        if capture_name == "namespace.definition" or capture_name == "test.definition" then
          -- This is the definition node itself - get its range
          node_info.range = { node:range() }
          node_info.type = capture_name == "namespace.definition" and "namespace" or "test"
        elseif capture_name == "namespace.name" then
          node_info.name = vim.treesitter.get_node_text(node, content)
          node_info.type = "namespace"
        elseif capture_name == "test.name" then
          node_info.name = vim.treesitter.get_node_text(node, content)
          node_info.type = "test"
        elseif capture_name == "function_name" then
          -- We might not need this, but we'll store it just in case
          node_info.function_name = vim.treesitter.get_node_text(node, content)
        end
      end

      -- Only add if we have both name and type
      if node_info.name and node_info.type then
        local range = node_info.range or { 0, 0, 0, 0 }
        table.insert(nodes, {
          name = node_info.name,
          type = node_info.type,
          path = file_path,
          -- Convert treesitter 0-based ranges to neotest expected format
          range = {
            range[1], -- start line (0-based)
            range[2], -- start col
            range[3], -- end line (0-based)
            range[4], -- end col
          },
        })
      end
    end

    return nodes
  end

  ---Build the test tree structure
  ---@param nodes table[]
  ---@param file_path string
  ---@return neotest.Tree
  local function build_test_tree(nodes, file_path)
    local types = require("neotest.types")

    -- Create file node
    local sep = package.config:sub(1, 1)
    local path_parts = vim.split(file_path, sep, { plain = true })
    local file_name = path_parts[#path_parts]

    -- Find the last line of the file for range
    local content = require("neotest.lib").files.read(file_path)
    local last_line = #vim.split(content, "\n")

    local file_node = {
      type = "file",
      path = file_path,
      name = file_name,
      range = { 0, 0, last_line, 0 },
    }

    -- Build parent-child relationships
    -- For now, we'll keep it simple: all tests are direct children of the file
    -- In a more advanced version, you'd handle Describe/Context nesting
    local structure = { { node = file_node, parent = nil } }

    for i, node in ipairs(nodes) do
      -- Generate a unique ID for the node
      local node_id = string.format("%s::%s:%d", file_path, node.name, i)

      local position = {
        id = node_id,
        type = node.type,
        path = file_path,
        name = node.name,
        range = node.range,
      }

      table.insert(structure, {
        node = position,
        parent = file_node,
      })
    end

    -- Create the tree
    return types.Tree.from_list(structure, function(position)
      return position.id or (position.path .. "::" .. (position.name or ""))
    end)
  end

  -- NOTE: Required for implementing neotest interface
  ---Given a file path, parse all the tests within it.
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
    -- local normalized_query = lib.treesitter.normalise_query("powershell", pester_treesitter_query)
    return lib.treesitter.parse_positions(file_path, pester_treesitter_query)
  end

  ---Count how many test nodes we have (excluding namespaces)
  ---@param nodes table[]
  ---@return integer
  local function count_test_nodes(nodes)
    local count = 0
    for _, node in ipairs(nodes) do
      if node.type == "test" then
        count = count + 1
      end
    end
    return count
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
