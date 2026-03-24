local M = {}

---Build the PowerShell script for running Pester tests.
---Writes JSON results to results_path; stdout carries Pester's verbose output.
---@param position table neotest position data (type, path, id)
---@param results_path string path to write ConvertTo-Json output to
---@param config neotest-pester.Config
---@return string PowerShell script suitable for passing to pwsh -Command
function M.build_script(position, results_path, config)
  local pos_type = position.type
  local file_path = position.path

  -- Build -Path argument (always scope to the specific file)
  local invoke_args = { string.format("-Path '%s'", file_path) }

  -- Build -FullNameFilter based on position granularity
  if pos_type == "test" then
    local parts = vim.split(position.id, "::")
    -- names are stored with surrounding single-quotes in the ID, strip them
    local describe_name = parts[2]:sub(2, #parts[2] - 1)
    local it_name = parts[3]:sub(2, #parts[3] - 1)
    table.insert(invoke_args, string.format("-FullNameFilter '%s %s'", describe_name, it_name))
  elseif pos_type == "namespace" then
    local parts = vim.split(position.id, "::")
    local describe_name = parts[2]:sub(2, #parts[2] - 1)
    table.insert(invoke_args, string.format("-FullNameFilter '%s*'", describe_name))
  end

  -- Append extra_args from config
  for _, arg in ipairs(config.extra_args or {}) do
    table.insert(invoke_args, arg)
  end

  table.insert(invoke_args, "-PassThru")

  local invoke_str = table.concat(invoke_args, " ")

  return string.format(
    "$T = Invoke-Pester %s; "
      .. "$T.Tests | Select-Object Result, ExpandedName, "
      .. "@{N='ErrorMessage';E={if ($_.ErrorRecord) { $_.ErrorRecord.Exception.Message } else { $null }}} | "
      .. "ConvertTo-Json -Compress | Set-Content -Path '%s'",
    invoke_str,
    results_path
  )
end

return M
