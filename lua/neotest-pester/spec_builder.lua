local M = {}

---Strip surrounding single or double quotes if present.
---@param s string
---@return string
function M.strip_quotes(s)
  if #s >= 2 then
    local first, last = s:sub(1, 1), s:sub(-1)
    if (first == "'" and last == "'") or (first == '"' and last == '"') then
      return s:sub(2, -2)
    end
  end
  return s
end

---Extract name parts from a position ID, stripping the file path prefix.
---Position IDs look like: "file_path::Describe::It name"
---Names may be wrapped in single quotes from treesitter capture.
---@param position_id string
---@return string[] name parts without the file path
function M.extract_name_parts(position_id)
  local parts = vim.split(position_id, "::")
  local names = {}
  for i = 2, #parts do
    names[#names + 1] = M.strip_quotes(parts[i])
  end
  return names
end

---Build a PesterConfiguration table for the given position.
---@param position table neotest position data (type, path, id)
---@param config neotest-pester.Config
---@return table PesterConfiguration as a Lua table
function M.build_pester_config(position, config)
  local pester_cfg = {
    Run = {
      Path = { position.path },
      PassThru = true,
    },
    Output = {
      Verbosity = "Detailed",
    },
  }

  if position.type == "test" then
    local names = M.extract_name_parts(position.id)
    if #names >= 1 then
      pester_cfg.Filter = { FullName = { table.concat(names, ".") } }
    end
  elseif position.type == "namespace" then
    local names = M.extract_name_parts(position.id)
    if #names >= 1 then
      pester_cfg.Filter = { FullName = { table.concat(names, ".") .. "*" } }
    end
  end

  -- Merge user's pester_configuration overrides
  if config.pester_configuration and next(config.pester_configuration) then
    pester_cfg = vim.tbl_deep_extend("force", pester_cfg, config.pester_configuration)
  end

  return pester_cfg
end

---Build the PowerShell script for running Pester tests.
---Writes JSON results to results_path; stdout carries Pester's verbose output.
---@param position table neotest position data (type, path, id)
---@param results_path string path to write ConvertTo-Json output to
---@param config neotest-pester.Config
---@return string PowerShell script suitable for passing to pwsh -Command
function M.build_script(position, results_path, config)
  local pester_cfg = M.build_pester_config(position, config)
  local json = vim.json.encode(pester_cfg)
  -- Escape single quotes for PowerShell single-quoted string
  local escaped_json = json:gsub("'", "''")

  return string.format(
    "$cfg = '%s' | ConvertFrom-Json -AsHashtable; "
      .. "$T = Invoke-Pester -Configuration (New-PesterConfiguration -Hashtable $cfg); "
      .. "$T.Tests | Select-Object Result, ExpandedName, "
      .. "@{N='ErrorMessage';E={if ($_.ErrorRecord) { $_.ErrorRecord.Exception.Message } else { $null }}} | "
      .. "ConvertTo-Json -Compress | Set-Content -Path '%s'",
    escaped_json,
    results_path
  )
end

---Build a multi-line PowerShell script for DAP debugging.
---Same logic as build_script but formatted as a .ps1 file.
---@param position table neotest position data
---@param results_path string path to write results JSON
---@param config neotest-pester.Config
---@return string PowerShell script content
function M.build_dap_script(position, results_path, config)
  local pester_cfg = M.build_pester_config(position, config)
  local json = vim.json.encode(pester_cfg)
  local escaped_json = json:gsub("'", "''")

  return table.concat({
    string.format("$cfg = '%s' | ConvertFrom-Json -AsHashtable", escaped_json),
    "$pesterConfig = New-PesterConfiguration -Hashtable $cfg",
    "$T = Invoke-Pester -Configuration $pesterConfig",
    "$T.Tests | Select-Object Result, ExpandedName, "
      .. "@{N='ErrorMessage';E={if ($_.ErrorRecord) { $_.ErrorRecord.Exception.Message } else { $null }}} | "
      .. string.format("ConvertTo-Json -Compress | Set-Content -Path '%s'", results_path),
  }, "\n")
end

return M
