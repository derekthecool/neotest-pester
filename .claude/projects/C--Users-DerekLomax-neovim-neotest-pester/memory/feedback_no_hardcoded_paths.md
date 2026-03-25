---
name: No hardcoded Windows paths
description: Never use hardcoded Windows-style paths (C:/...) in tests or code — always use cross-platform path construction
type: feedback
---

Never hard-code Windows-style paths like `C:/code/MyModule.Tests.ps1` in tests or code.
Always use cross-platform path construction (e.g., `vim.fs.joinpath`, `vim.fn.tempname()`, relative paths).

**Why:** The project should work cross-platform and hardcoded drive letters are fragile.

**How to apply:** In tests, construct paths dynamically using `vim.fn.getcwd()`, `vim.fs.joinpath()`,
or simple relative paths like `"path/to/file"`. Use forward slashes with no drive letter for mock paths.
