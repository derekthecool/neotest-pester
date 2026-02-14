local M = {}
M.check = function()
  vim.health.start("neotest-pester healthcheck")

  vim.health.info("checking for dependencies...")

  local has_nio, nio = pcall(require, "nio")
  if not has_nio then
    vim.health.error("nio is not installed. Please install nio to use neotest-pester.")
  else
    vim.health.ok("nio is installed.")
  end

  local has_neotest = pcall(require, "neotest")
  if not has_neotest then
    vim.health.error("neotest is not installed. Please install neotest to use neotest-pester.")
  else
    vim.health.ok("neotest is installed.")
  end

  vim.health.info("Checking neotest-pester configuration...")

  -- TODO: (Derek Lomax) Sat 14 Feb 2026 08:48:29 AM MST, check Powershell version, Neovim version, Pester version
end
return M
