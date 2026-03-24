# CLAUDE.md

## Commands

```bash
# Run all tests
make test

# Install/update dependencies (clones into deps/)
make deps/mini.nvim

# Format Lua files
stylua lua/ tests/

# Lint Lua files
luacheck lua/ tests/
```

Tests run via `mini.nvim`'s MiniTest framework inside headless Neovim. The `deps/` directory is gitignored and populated by `make`.

To run a single test file: add `-e 'MiniTest.run_file("tests/your_test.lua")'` instead of `MiniTest.run()` in the make invocation.

## Architecture

This is a [neotest](https://github.com/nvim-neotest/neotest) adapter for the PowerShell Pester testing framework.

### Neotest Adapter Interface (`lua/neotest-pester/init.lua`)

The main file implements the neotest adapter contract with these required functions:

- **`root(dir)`** — finds project root by walking up to find `.git`
- **`is_test_file(path)`** — returns true for `*.Tests.ps1` files
- **`filter_dir(name)`** — excludes `bin/` and `obj/` from discovery
- **`discover_positions(file_path)`** — uses treesitter to parse PowerShell and build a test tree of `Describe` (namespaces) and `It` (tests) blocks
- **`build_spec(args)`** — constructs the neotest `RunSpec` with the PowerShell command to execute
- **`results(spec, result, tree)`** — parses JSON output from Pester and maps it to neotest result format

### Test Discovery

Treesitter queries (embedded in `init.lua`) match PowerShell `Describe` and `It` blocks case-insensitively. The parser language is `powershell`. Test IDs are constructed as `{file_path}::{describe_name}::{it_name}`.

### Test Execution

`build_spec` generates a `pwsh -NoProfile -Command` invocation that:
1. Runs `Invoke-Pester -PassThru` with output redirected to suppress noise
2. Extracts results as JSON via `ConvertTo-Json -Compress`

`results()` reads the JSON output, normalizes test names, and maps pass/fail/skip to neotest status values.

### Other Modules

- **`config.lua`** — default config schema; options include `dap_settings`, `timeout_ms`, `sdk_path`
- **`utilities.lua`** — `stream_queue` (async producer/consumer) and `ResultAccumulator` (collects process output into temp files for neotest)
- **`health.lua`** — `:checkhealth neotest-pester` implementation
- **`dotnet_utils.lua`**, **`client.lua`**, **`pester/`** — legacy modules from an earlier architecture that used `pester.console.dll` and F# scripting. These are largely unused by the current direct `pwsh` approach in `init.lua`.

### Async

The plugin uses [nvim-nio](https://github.com/nvim-neotest/nvim-nio) for async operations. All async functions must run inside an `nio.run()` coroutine context.

### Code Style

- 2-space indent, 100 column width, Unix line endings (see `stylua.toml`)
- Annotations use EmmyLua (`---@param`, `---@return`, `---@class`) style