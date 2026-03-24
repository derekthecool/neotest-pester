local M = {}

---@class neotest-pester.Config
---@field pwsh_path? string path to pwsh executable, e.g. "pwsh", "powershell", or a full path. Default: "pwsh"
---@field extra_args? string[] extra arguments passed directly to Invoke-Pester
---@field timeout_ms? number milliseconds to wait before timing out connection with test runner

---@type neotest-pester.Config
local default_config = {
  timeout_ms = 5 * 30 * 1000,
  pwsh_path = "pwsh",
  extra_args = {},
}

---@return neotest-pester.Config
function M.get_config()
  return vim.tbl_deep_extend("force", default_config, vim.g.neotest_pester or {})
end

return M
