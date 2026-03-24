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
