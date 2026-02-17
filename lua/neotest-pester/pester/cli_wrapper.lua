local nio = require("nio")
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local dotnet_utils = require("neotest-pester.dotnet_utils")

local M = {}

function M.get_pester_path()
  local config = require("neotest-pester.config").get_config()
  local path_to_search = config.sdk_path

  if not path_to_search then
    local process = vim.system({ "dotnet", "--info" })

    local default_sdk_path
    if vim.fn.has("win32") then
      default_sdk_path = "C:/Program Files/dotnet/sdk/"
    else
      default_sdk_path = "/usr/local/share/dotnet/sdk/"
    end

    local obj = process:wait()

    local out = obj.stdout
    local info = dotnet_utils.parse_dotnet_info(out or "")
    if info.sdk_path then
      path_to_search = info.sdk_path
      logger.info(string.format("neotest-pester: detected sdk path: %s", path_to_search))
    else
      path_to_search = default_sdk_path
      local log_string = string.format(
        "neotest-pester: failed to detect sdk path. falling back to %s",
        path_to_search
      )
      logger.info(log_string)
      nio.scheduler()
      vim.notify_once(log_string)
    end
  end

  return vim.fs.find("pester.console.dll", { upward = false, type = "file", path = path_to_search })[1]
end

local function get_script(script_name)
  local script_paths = vim.api.nvim_get_runtime_file(vim.fs.joinpath("scripts", script_name), true)
  logger.debug("neotest-pester: possible scripts:")
  logger.debug(script_paths)
  for _, path in ipairs(script_paths) do
    if path:match("neotest%-pester") ~= nil then
      return path
    end
  end
end

---@param project DotnetProjectInfo
---@return { execute: fun(content: string), stop: fun() }
function M.create_test_runner(project)
  local test_discovery_script = get_script("run_tests.fsx")
  nio.scheduler()
  local testhost_dll = M.get_pester_path()

  logger.debug("neotest-pester: found discovery script: " .. test_discovery_script)
  logger.debug("neotest-pester: found testhost dll: " .. testhost_dll)

  local pester_command = { "dotnet", "fsi", test_discovery_script, testhost_dll }

  logger.info("neotest-pester: starting pester console with for " .. project.dll_file .. " with:")
  logger.info(pester_command)

  local process = vim.system(pester_command, {
    detach = false,
    stdin = true,
    stdout = function(err, data)
      if data then
        logger.trace("neotest-pester: " .. data)
      end
      if err then
        logger.trace("neotest-pester " .. err)
      end
    end,
  }, function(obj)
    vim.schedule(function()
      vim.notify_once("neotest-pester: pester process exited unexpectedly.", vim.log.levels.ERROR)
    end)
    logger.warn("neotest-pester: pester process died :(")
    logger.warn(obj.code)
    logger.warn(obj.signal)
    logger.warn(obj.stdout)
    logger.warn(obj.stderr)
  end)

  nio.scheduler()
  local cleanup_autocmd_id = vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("neotest_pester_server_shutdown", { clear = false }),
    desc = "Shutdown dotnet pester client process on Neovim exit",
    callback = function()
      process:kill(vim.uv.constants.SIGKILL)
    end,
  })

  logger.info(string.format("neotest-pester: spawned pester process with pid: %s", process.pid))

  return {
    execute = function(content)
      process:write(content .. "\n")
    end,
    stop = function()
      process:kill(vim.uv.constants.SIGKILL)
      nio.scheduler()
      vim.api.nvim_del_autocmd(cleanup_autocmd_id)
    end,
  }
end

---Repeatly tries to read content. Repeats until the file is non-empty or operation times out.
---@param file_path string
---@param max_wait integer maximal time to wait for the file to populated in milliseconds.
---@return boolean
function M.spin_lock_wait_file(file_path, max_wait)
  local sleep_time = 25 -- scan every 25 ms
  local tries = 1
  local file_exists = false

  while not file_exists and tries * sleep_time < max_wait do
    if lib.files.exists(file_path) then
      file_exists = true
    else
      tries = tries + 1
      nio.sleep(sleep_time)
    end
  end

  if not file_exists then
    logger.warn(string.format("neotest-pester: timed out reading content of file %s", file_path))
  end

  return file_exists
end

return M
