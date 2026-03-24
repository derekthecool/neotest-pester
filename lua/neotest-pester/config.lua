local M = {}

---@class neotest-pester.DapSettings
---@field type? string DAP adapter type (e.g., "ps1"). Default: "ps1"
---@field request? string DAP request type. Default: "launch"

---@class neotest-pester.Config
---@field pwsh_path? string Path to pwsh executable. Default: "pwsh"
---@field pester_configuration? table PesterConfiguration overrides (merged into generated config)
---@field timeout_ms? number Milliseconds to wait before timing out. Default: 150000
---@field dap_settings? neotest-pester.DapSettings DAP debug configuration

---@type neotest-pester.Config
local default_config = {
  timeout_ms = 5 * 30 * 1000,
  pwsh_path = "pwsh",
  pester_configuration = {},
  dap_settings = {},
}

---@type neotest-pester.Config
local _config = vim.deepcopy(default_config)

---Configure neotest-pester with user options.
---Resets to defaults first, then merges opts on top.
---@param opts? neotest-pester.Config
function M.setup(opts)
  _config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})
end

---@return neotest-pester.Config
function M.get_config()
  return _config
end

---Reset config to defaults (useful for test isolation).
function M.reset()
  _config = vim.deepcopy(default_config)
end

return M
