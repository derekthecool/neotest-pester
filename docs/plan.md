# Plan: Individual Test Running, Better Output, and Config Options

## Status: COMPLETED

All items implemented and tested via TDD (`make test`: 33/35 pass, 2 pre-existing failures
unrelated to this work).

---

## Context

The neotest-pester adapter previously ran the entire Pester test suite every time, ignoring the
position selected in neotest's tree. The pwsh command was hardcoded, results only captured pass/fail
status (no error messages), and verbose Pester output was suppressed entirely. This work added:

1. **Selective test running** — filter to file, Describe block, or individual It block ✅
2. **Better output** — error messages/stack traces in results, verbose Pester output visible in the output panel ✅
3. **Config options** — configurable pwsh executable path, extra Invoke-Pester arguments ✅

---

## Files Changed

| File | Change |
|------|--------|
| `lua/neotest-pester/config.lua` | Added `pwsh_path` and `extra_args` fields; removed legacy dotnet fields |
| `lua/neotest-pester/spec_builder.lua` | **New** — pure function `build_script(position, results_path, config)` |
| `lua/neotest-pester/init.lua` | Rewrote `build_spec` and `results` |
| `tests/test_config.lua` | **New** — 5 tests for config defaults and overrides |
| `tests/test_spec_builder.lua` | **New** — 9 tests for script construction (file/namespace/test filtering, extra_args) |
| `tests/test_results_parsing.lua` | **New** — 7 tests for results parsing, error mapping, skipped/failed/passed status |

---

## Implementation Notes

### `spec_builder.lua` — PS script construction

Pure function. Takes neotest position data, a results temp file path, and config. Returns a
PowerShell script string.

- **File position**: `-Path 'file.Tests.ps1'` only, no filter
- **Namespace position**: `-Path ... -FullNameFilter 'DescribeName*'`
- **Test position**: `-Path ... -FullNameFilter 'DescribeName ItName'`
- Pester 5 `-FullNameFilter` uses space-joined path format
- Results written via `Set-Content` to a temp file; stdout carries verbose Pester output

### `build_spec` changes

- Uses `cfg.pwsh_path` instead of hardcoded `"pwsh"`
- Delegates script construction to `spec_builder.build_script`
- Removed the old `stream_path` / `lib.files.stream_lines` wiring (stdout streaming is now natural)

### `results` changes

- Reads from `spec.context.results_path` (dedicated temp file) instead of `result.output` (stdout)
- Uses `io.open` (synchronous) instead of `lib.files.read` (requires nio async context)
- Maps `ErrorMessage` → `short` and `errors[1].message` in neotest result table
- Removed fragile `data:match('%[{"[^%]]+%]')` regex (clean JSON from dedicated file)

---

## Key Decisions

- **`io.open` over `lib.files.read`**: `lib.files.read` uses `nio.uv` and requires an async
  coroutine. `io.open` is synchronous and works in both contexts, including synchronous tests.
- **Stdout = verbose output, temp file = structured results**: Clean separation. Neotest shows
  stdout in the output panel; structured JSON is parsed from the dedicated file.
- **Legacy config fields removed**: `sdk_path`, `build_opts`, `dap_settings`,
  `discovery_directory_filter`, `solution_selector`, `settings_selector` were dead code from the
  original dotnet fork, never read.

---

## Verification

```bash
make test   # 33/35 pass (2 pre-existing failures in interface.root.works and discover_positions)
```

Manual verification in Neovim:
1. Run full file → all tests run, verbose output visible in output panel
2. Run a Describe block → filters to that namespace only (`-FullNameFilter 'Name*'`)
3. Run a single It block → runs only that test (`-FullNameFilter 'Describe Name It Name'`)
4. Fail a test → error message appears in neotest floating window (`neotest.output.open()`)
5. Set `vim.g.neotest_pester = { extra_args = { "-Tag", "fast" } }` → only tagged tests run
6. Set `vim.g.neotest_pester = { pwsh_path = "powershell" }` → uses Windows PowerShell 5.1

---
---

# Plan: Configuration Overhaul, JSON Config Passing, DAP Debug, Test Fixes

## Status: IN PROGRESS

---

## Context

The adapter uses `vim.g.neotest_pester` global for config (fragile, non-standard). Single
test running has issues with FullNameFilter separator. No DAP debug support. Two unit tests
still fail (`interface.root.works`, `interface.discover_positions`). The `extra_args` approach
doesn't compose well with Pester 5's `New-PesterConfiguration`.

This work adds:

1. **Configuration overhaul** — `.setup()` function replacing global variables
2. **JSON-based config passing** — Lua tables → `vim.json.encode` → `ConvertFrom-Json -AsHashtable` → `New-PesterConfiguration`
3. **Fix single test running** — correct FullName filter separator (dot, not space)
4. **DAP debug support** — generate temp `.ps1` script, pass DAP strategy config
5. **Fix failing tests** — root() reliability on Windows, discover_positions async/path issues

---

## Phase 1: Configuration Overhaul

### Goal

Replace `vim.g.neotest_pester` global with a proper `.setup()` pattern.

### Changes

- **config.lua**: Store config as module-level state, not in `vim.g`
  - Add `M.setup(opts)` to merge user options into defaults
  - Add `M.reset()` for test isolation
  - Add `pester_configuration` table field (replaces `extra_args`)
  - Add `dap_settings` field for debug configuration
- **init.lua**: Add `.setup(opts)` that delegates to config module
  - `__call` metamethod delegates to `.setup()` for backward compat
  - Returns the adapter for chaining in neotest setup

### User API

```lua
-- Option 1: Explicit setup
require("neotest-pester").setup({ pwsh_path = "/usr/bin/pwsh" })

-- Option 2: In neotest setup (via __call or .setup)
require("neotest").setup({
  adapters = {
    require("neotest-pester").setup({
      pwsh_path = "powershell",
      pester_configuration = {
        Output = { Verbosity = "Diagnostic" },
        Filter = { Tag = { "fast" } },
      },
    })
  }
})
```

## Phase 2: JSON-Based Config Passing

### Goal

Pass Pester configuration from Lua to PowerShell via JSON (`ConvertFrom-Json`).

### Changes

- **spec_builder.lua**: Rewrite to build PesterConfiguration as a Lua table
  - `build_pester_config()` constructs config table (testable independently)
  - `build_script()` encodes to JSON and generates pwsh command
  - Uses `New-PesterConfiguration -Hashtable` for Pester 5+
  - User's `pester_configuration` overrides are deep-merged

### PowerShell Command Pattern

```powershell
$cfg = '<json>' | ConvertFrom-Json -AsHashtable
$T = Invoke-Pester -Configuration (New-PesterConfiguration -Hashtable $cfg)
$T.Tests | Select-Object Result, ExpandedName, @{N='ErrorMessage';E={...}} |
  ConvertTo-Json -Compress | Set-Content -Path '<results_path>'
```

### Requirements

- PowerShell 7+ (pwsh) for `ConvertFrom-Json -AsHashtable`
- Pester 5+ for `New-PesterConfiguration`

## Phase 3: Fix Single Test Running

### Problem

Position ID parsing and FullNameFilter construction don't match Pester's naming.

### Root Cause

- Pester's full test name uses dot (`.`) separator between containers
- Old code used space separator which doesn't match

### Changes

- `strip_quotes()` utility handles both quoted and unquoted names in position IDs
- `extract_name_parts()` parses ID into name components
- FullName filter joins name parts with `.` (matching Pester convention)
- Handles nested Describe blocks correctly

### Examples

| Position Type | ID | Filter |
|---|---|---|
| file | `path` | (none) |
| namespace | `path::Describe` | `Describe*` |
| test | `path::Describe::It name` | `Describe.It name` |
| nested test | `path::Outer::Inner::It` | `Outer.Inner.It` |

## Phase 4: DAP Debug Support

### Goal

Enable debugging Pester tests via nvim-dap.

### Changes

- **init.lua**: In `build_spec`, detect `args.strategy == "dap"`
  - Generate a `.ps1` temp script with the Pester invocation
  - Return DAP strategy config pointing to the script
  - Merge user's `dap_settings` from config
- **spec_builder.lua**: Add `build_dap_script()` for multi-line script format

### Configuration

```lua
require("neotest-pester").setup({
  dap_settings = {
    type = "ps1",  -- DAP adapter name
    request = "launch",
  }
})
```

### How It Works

1. User runs `:lua require("neotest").run.run({strategy = "dap"})`
2. Adapter writes Pester invocation to a temp `.ps1` file
3. DAP adapter launches pwsh with the script, enabling breakpoints
4. Results are still written to the JSON temp file for neotest to parse

## Phase 5: Fix Tests

### Failing Tests

1. **`interface.root.works`**: `lib.files.match_root_pattern` unreliable on Windows
   - Fix: Use `vim.fs.find` with `upward = true` in `root()` function
2. **`interface.discover_positions`**: Hardcoded Linux path, broken async handling
   - Fix: Use relative path, skip if powershell parser not installed

### Test Updates

- **test_config.lua**: Use `.setup()` / `.reset()` instead of `vim.g.neotest_pester`
- **test_spec_builder.lua**: Test `build_pester_config` table structure + `build_script` output patterns
- **test_results_parsing.lua**: Verify `strip_quotes` handles both quoted/unquoted IDs

## Phase 6: Clean Up

- Remove dead code from `init.lua` (unused helpers: `build_position`, `parse_with_treesitter`,
  `build_test_tree`, `count_test_nodes`, commented-out `get_top_level_tests`)
- Remove `create_adapter()` wrapper (config now read at call time)
- Simplify `is_test_file` (remove commented-out client discovery code)

---

## Files Changed

| File | Change |
|------|--------|
| `lua/neotest-pester/config.lua` | Replaced `vim.g` with module-level state; added `setup()`, `reset()`, `pester_configuration`, `dap_settings` |
| `lua/neotest-pester/spec_builder.lua` | Rewritten — PesterConfiguration via JSON, `build_pester_config`, `build_dap_script`, `strip_quotes`, `extract_name_parts` |
| `lua/neotest-pester/init.lua` | Added `.setup()`, fixed `root()`, fixed `results()` quote handling, added DAP strategy, removed dead code |
| `tests/test_config.lua` | Updated for `.setup()` API with `reset()` hooks |
| `tests/test_spec_builder.lua` | Rewritten for JSON-based output and `build_pester_config` structure |
| `tests/test_neotest-pester_core_functionality.lua` | Fixed root test, discover_positions path and async handling |
