local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local config = require("neotest-pester.config")

local T = new_set({
  hooks = {
    post_case = function()
      config.reset()
    end,
  },
})

T["config.defaults.timeout_ms"] = function()
  eq(150000, config.get_config().timeout_ms)
end

T["config.defaults.pwsh_path"] = function()
  eq("pwsh", config.get_config().pwsh_path)
end

T["config.defaults.pester_configuration"] = function()
  eq({}, config.get_config().pester_configuration)
end

T["config.defaults.dap_settings"] = function()
  eq({}, config.get_config().dap_settings)
end

T["config.setup.pwsh_path"] = function()
  config.setup({ pwsh_path = "/usr/bin/pwsh" })
  eq("/usr/bin/pwsh", config.get_config().pwsh_path)
end

T["config.setup.pester_configuration"] = function()
  config.setup({ pester_configuration = { Output = { Verbosity = "Diagnostic" } } })
  eq("Diagnostic", config.get_config().pester_configuration.Output.Verbosity)
end

T["config.setup.dap_settings"] = function()
  config.setup({ dap_settings = { type = "ps1", request = "attach" } })
  eq("ps1", config.get_config().dap_settings.type)
  eq("attach", config.get_config().dap_settings.request)
end

T["config.setup.preserves_defaults"] = function()
  config.setup({ pwsh_path = "powershell" })
  eq(150000, config.get_config().timeout_ms)
end

T["config.reset.restores_defaults"] = function()
  config.setup({ pwsh_path = "custom", timeout_ms = 999 })
  config.reset()
  eq("pwsh", config.get_config().pwsh_path)
  eq(150000, config.get_config().timeout_ms)
end

return T
