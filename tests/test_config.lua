local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local T = new_set()

local config = require("neotest-pester.config")

T["config.defaults.timeout_ms"] = function()
  eq(150000, config.get_config().timeout_ms)
end

T["config.defaults.pwsh_path"] = function()
  eq("pwsh", config.get_config().pwsh_path)
end

T["config.defaults.extra_args"] = function()
  eq({}, config.get_config().extra_args)
end

T["config.override.pwsh_path"] = function()
  vim.g.neotest_pester = { pwsh_path = "/usr/bin/pwsh" }
  eq("/usr/bin/pwsh", config.get_config().pwsh_path)
  vim.g.neotest_pester = nil
end

T["config.override.extra_args"] = function()
  vim.g.neotest_pester = { extra_args = { "-Tag", "fast" } }
  local cfg = config.get_config()
  eq(2, #cfg.extra_args)
  eq("-Tag", cfg.extra_args[1])
  eq("fast", cfg.extra_args[2])
  vim.g.neotest_pester = nil
end

return T
