# neotest-pester

[Neotest](https://github.com/nvim-neotest/neotest) adapter for the PowerShell [Pester](https://pester.dev/) testing framework.

## Requirements

- Neovim 0.9+
- PowerShell 7.4+ (pwsh) or Windows PowerShell 5.1
- Pester 5.7+
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with the `powershell` parser installed
- [nvim-nio](https://github.com/nvim-neotest/nvim-nio)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "DerekLomax/neotest-pester",
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-pester").setup(),
      },
    })
  end,
}
```

Make sure the PowerShell treesitter parser is installed:

```vim
:TSInstall powershell
```

## Configuration

Pass options to `.setup()` to override defaults:

```lua
require("neotest").setup({
  adapters = {
    require("neotest-pester").setup({
      -- Path to pwsh executable (default: "pwsh")
      pwsh_path = "pwsh",

      -- PesterConfiguration overrides (merged into generated config)
      -- These map directly to Pester 5's New-PesterConfiguration fields.
      -- See: https://pester.dev/docs/usage/configuration
      pester_configuration = {
        Output = { Verbosity = "Detailed" },
        Filter = { Tag = { "Unit" } },
      },

      -- DAP debug settings (for running tests with :lua require("neotest").run.run({strategy = "dap"}))
      dap_settings = {
        type = "ps1",       -- DAP adapter type
        request = "launch", -- DAP request type
      },

      -- Timeout in milliseconds (default: 150000)
      timeout_ms = 150000,
    }),
  },
})
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `pwsh_path` | `string` | `"pwsh"` | Path to PowerShell executable. Use `"powershell"` for Windows PowerShell 5.1. |
| `pester_configuration` | `table` | `{}` | PesterConfiguration overrides merged into the generated config. Maps to `New-PesterConfiguration` fields. |
| `dap_settings` | `table` | `{}` | DAP configuration for debug test runs. Merged into the default strategy config. |
| `timeout_ms` | `number` | `150000` | Milliseconds before timing out a test run. |

## Usage

Run tests using neotest commands:

```lua
-- Run the nearest test
require("neotest").run.run()

-- Run all tests in file
require("neotest").run.run(vim.fn.expand("%"))

-- Debug the nearest test (requires a PowerShell DAP adapter like powershell.nvim)
require("neotest").run.run({ strategy = "dap" })
```

## How It Works

The adapter uses treesitter to parse `Describe` and `It` blocks from `*.Tests.ps1` files. Test execution builds a `PesterConfiguration` object as a Lua table, serializes it to JSON, and passes it to PowerShell via `ConvertFrom-Json -AsHashtable` and `New-PesterConfiguration`. Results are written to a temp file as JSON and parsed back into neotest's result format.

## Testing

Tests use [mini.test](https://github.com/nvim-mini/mini.nvim/blob/main/TESTING.md) and run in headless Neovim:

```bash
make deps/mini.nvim  # clone test dependencies (first time only)
make test            # run all tests
```
