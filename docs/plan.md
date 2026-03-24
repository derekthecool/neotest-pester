# Plan: Individual Test Running, Better Output, and Config Options

## Context

The neotest-pester adapter currently runs the entire Pester test suite every time, ignoring the
position selected in neotest's tree. The pwsh command is hardcoded, results only capture pass/fail
status (no error messages), and verbose Pester output is suppressed entirely. This plan adds:

1. **Selective test running** — filter to file, Describe block, or individual It block
2. **Better output** — error messages/stack traces in results, verbose Pester output visible in the output panel
3. **Config options** — configurable pwsh executable path, extra Invoke-Pester arguments

---

## Files to Modify

- `lua/neotest-pester/config.lua` — add new config fields
- `lua/neotest-pester/init.lua` — update `build_spec` and `results`

---

## Implementation

### 1. `config.lua` — Add new fields

```lua
---@class neotest-pester.Config
---@field pwsh_path? string  path to pwsh executable, e.g. "pwsh", "powershell", or a full path. Default: "pwsh"
---@field extra_args? string[]  extra arguments passed directly to Invoke-Pester
---@field timeout_ms? number

local default_config = {
  timeout_ms = 5 * 30 * 1000,
  pwsh_path = "pwsh",
  extra_args = {},
}
```

Remove unused legacy fields (`sdk_path`, `build_opts`, `dap_settings`, `discovery_directory_filter`,
`solution_selector`, `settings_selector`) from the type annotation — they belong to the old dotnet
architecture and are never read.

### 2. `init.lua` — Rewrite `build_spec`

**Goals:**
- Build a dynamic PowerShell script (not a hardcoded string split by spaces)
- Filter by file path, Describe block, or It block based on `args.tree` position type
- Write JSON results to a temp file (not stdout), so stdout carries Pester's verbose output
- Include `ErrorMessage` in the JSON for failed tests
- Support `config.pwsh_path` and `config.extra_args`

**Position ID format** (from treesitter discovery):
`"/path/file.Tests.ps1::'DescribeName'::'ItName'"`

Names have surrounding single-quotes in the ID that must be stripped.

**Pester 5 `-FullNameFilter`:** Filters by full test path — Describe and It names joined with a
space. Example: `"Format-Pairs Function Format-Pairs exists"`.

**New `build_spec` logic:**

```lua
local position = tree:data()
local pos_type = position.type
local file_path = position.path

local path_arg = string.format("-Path '%s'", file_path)

local filter_arg = ""
if pos_type == "test" then
  local parts = vim.split(position.id, "::")
  local describe_name = parts[2]:sub(2, #parts[2] - 1)  -- strip surrounding quotes
  local it_name = parts[3]:sub(2, #parts[3] - 1)
  filter_arg = string.format("-FullNameFilter '%s %s'", describe_name, it_name)
elseif pos_type == "namespace" then
  local parts = vim.split(position.id, "::")
  local describe_name = parts[2]:sub(2, #parts[2] - 1)
  filter_arg = string.format("-FullNameFilter '%s*'", describe_name)
end

local extra_args_str = table.concat(config.extra_args or {}, " ")
local results_path = nio.fn.tempname()

local ps_script = string.format(
  "$T = Invoke-Pester %s %s -PassThru %s; " ..
  "$T.Tests | Select-Object Result, ExpandedName, " ..
  "@{N='ErrorMessage';E={if ($_.ErrorRecord) { $_.ErrorRecord.Exception.Message } else { $null }}} | " ..
  "ConvertTo-Json -Compress | Set-Content -Path '%s'",
  path_arg, filter_arg, extra_args_str, results_path
)

return {
  command = { config.pwsh_path or "pwsh", "-NoProfile", "-Command", ps_script },
  context = { results_path = results_path, stop_stream = stop_stream },
}
```

The `stream` key and `stream_path` wiring are removed — neotest captures process stdout
automatically, which now carries Pester's verbose output.

### 3. `init.lua` — Update `results()`

**Goals:**
- Read JSON from `spec.context.results_path` (temp file) instead of `result.output` (stdout)
- Map `ErrorMessage` to neotest's `short` and `errors` fields

```lua
local success, data = pcall(lib.files.read, spec.context.results_path)
local ok, parsed = pcall(vim.json.decode, data, { luanil = { object = true } })

-- In the result loop:
results[position.id] = {
  status = finalTestResult,
  short = test_result.ErrorMessage or nil,
  errors = test_result.ErrorMessage
    and {{ message = test_result.ErrorMessage, line = position.range and position.range[1] }}
    or nil,
  output = result.output,  -- raw stdout (verbose Pester output)
}
```

Remove the fragile `data:match('%[{"[^%]]+%]')` pattern — no longer needed since results come from
a dedicated file written by `Set-Content`.

---

## Key Decisions

- **Stdout = verbose output, temp file = structured results.** Neotest displays stdout in the output
  panel automatically; structured data is parsed from the dedicated file.
- **`-FullNameFilter` uses Pester 5 space-joined path format.**
  - Single test: `"DescribeName ItName"`
  - Namespace: `"DescribeName*"`
- **Remove legacy config fields** from the type annotation — dead code from the dotnet fork.

---

## Verification

1. Run `make test` — existing mini.nvim tests should still pass
2. Open a `.Tests.ps1` file in Neovim with neotest configured
3. Run the full file → all tests run, verbose output visible in the output panel
4. Run a single Describe block → filters to that namespace only
5. Run a single It block → runs only that test
6. Fail a test → error message appears in the neotest floating window (`neotest.output.open()`)
7. Set `extra_args = { "-Tag", "fast" }` in config → only tagged tests run
8. Set `pwsh_path = "/usr/bin/pwsh"` → uses the specified executable
