local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local T = new_set()

local builder = require("neotest-pester.spec_builder")

local function default_config()
  return { pwsh_path = "pwsh", pester_configuration = {} }
end

local function test_path(name)
  return vim.fs.joinpath(vim.fn.getcwd(), name or "MyModule.Tests.ps1")
end

local function test_results_path()
  return vim.fn.tempname() .. ".json"
end

-- ── strip_quotes ─────────────────────────────────────────────────────────────

T["strip_quotes.removes_single_quotes"] = function()
  eq("hello", builder.strip_quotes("'hello'"))
end

T["strip_quotes.removes_double_quotes"] = function()
  eq("hello", builder.strip_quotes('"hello"'))
end

T["strip_quotes.no_quotes_unchanged"] = function()
  eq("hello", builder.strip_quotes("hello"))
end

T["strip_quotes.mismatched_quotes_unchanged"] = function()
  eq("'hello\"", builder.strip_quotes("'hello\""))
end

-- ── extract_name_parts ───────────────────────────────────────────────────────

T["extract_name_parts.simple"] = function()
  local parts = builder.extract_name_parts("path::Describe::It")
  eq(2, #parts)
  eq("Describe", parts[1])
  eq("It", parts[2])
end

T["extract_name_parts.with_quotes"] = function()
  local parts = builder.extract_name_parts("path::'Describe'::'It name'")
  eq(2, #parts)
  eq("Describe", parts[1])
  eq("It name", parts[2])
end

T["extract_name_parts.nested"] = function()
  local parts = builder.extract_name_parts("path::Outer::Inner::Test")
  eq(3, #parts)
  eq("Outer", parts[1])
  eq("Inner", parts[2])
  eq("Test", parts[3])
end

-- ── build_pester_config: file position ───────────────────────────────────────

T["build_pester_config.file.has_path"] = function()
  local p = test_path()
  local pos = { type = "file", path = p, id = p }
  local cfg = builder.build_pester_config(pos, default_config())
  eq({ p }, cfg.Run.Path)
end

T["build_pester_config.file.has_passthru"] = function()
  local p = test_path()
  local pos = { type = "file", path = p, id = p }
  local cfg = builder.build_pester_config(pos, default_config())
  eq(true, cfg.Run.PassThru)
end

T["build_pester_config.file.no_filter"] = function()
  local p = test_path()
  local pos = { type = "file", path = p, id = p }
  local cfg = builder.build_pester_config(pos, default_config())
  eq(nil, cfg.Filter)
end

-- ── build_pester_config: namespace position ──────────────────────────────────

T["build_pester_config.namespace.has_wildcard_filter"] = function()
  local p = test_path()
  local pos = {
    type = "namespace",
    path = p,
    id = p .. "::Format-Pairs",
  }
  local cfg = builder.build_pester_config(pos, default_config())
  eq({ "Format-Pairs*" }, cfg.Filter.FullName)
end

T["build_pester_config.namespace.quoted_id"] = function()
  local p = test_path()
  local pos = {
    type = "namespace",
    path = p,
    id = p .. "::'Format-Pairs'",
  }
  local cfg = builder.build_pester_config(pos, default_config())
  eq({ "Format-Pairs*" }, cfg.Filter.FullName)
end

-- ── build_pester_config: test position ───────────────────────────────────────

T["build_pester_config.test.has_exact_filter"] = function()
  local p = test_path()
  local pos = {
    type = "test",
    path = p,
    id = p .. "::Format-Pairs::Function exists",
  }
  local cfg = builder.build_pester_config(pos, default_config())
  eq({ "Format-Pairs.Function exists" }, cfg.Filter.FullName)
end

T["build_pester_config.test.quoted_id"] = function()
  local p = test_path()
  local pos = {
    type = "test",
    path = p,
    id = p .. "::'Format-Pairs'::'Function exists'",
  }
  local cfg = builder.build_pester_config(pos, default_config())
  eq({ "Format-Pairs.Function exists" }, cfg.Filter.FullName)
end

T["build_pester_config.test.nested_describes"] = function()
  local p = test_path()
  local pos = {
    type = "test",
    path = p,
    id = p .. "::Outer::Inner::My test",
  }
  local cfg = builder.build_pester_config(pos, default_config())
  eq({ "Outer.Inner.My test" }, cfg.Filter.FullName)
end

-- ── build_pester_config: pester_configuration merging ────────────────────────

T["build_pester_config.merges_overrides"] = function()
  local p = test_path()
  local pos = { type = "file", path = p, id = p }
  local cfg_opts = { pwsh_path = "pwsh", pester_configuration = { Output = { Verbosity = "Diagnostic" } } }
  local cfg = builder.build_pester_config(pos, cfg_opts)
  eq("Diagnostic", cfg.Output.Verbosity)
end

T["build_pester_config.overrides_dont_clobber_run"] = function()
  local p = test_path()
  local pos = { type = "file", path = p, id = p }
  local cfg_opts = { pwsh_path = "pwsh", pester_configuration = { Output = { Verbosity = "Diagnostic" } } }
  local cfg = builder.build_pester_config(pos, cfg_opts)
  eq(true, cfg.Run.PassThru)
end

-- ── build_script: output format ──────────────────────────────────────────────

T["build_script.uses_convertfrom_json"] = function()
  local p = test_path()
  local pos = { type = "file", path = p, id = p }
  local script = builder.build_script(pos, test_results_path(), default_config())
  MiniTest.expect.no_error(function()
    assert(script:find("ConvertFrom%-Json"), "should use ConvertFrom-Json")
  end)
end

T["build_script.uses_new_pester_configuration"] = function()
  local p = test_path()
  local pos = { type = "file", path = p, id = p }
  local script = builder.build_script(pos, test_results_path(), default_config())
  MiniTest.expect.no_error(function()
    assert(script:find("New%-PesterConfiguration"), "should use New-PesterConfiguration")
  end)
end

T["build_script.writes_to_results_path"] = function()
  local p = test_path()
  local rp = test_results_path()
  local pos = { type = "file", path = p, id = p }
  local script = builder.build_script(pos, rp, default_config())
  MiniTest.expect.no_error(function()
    -- Escape the results path for Lua pattern matching
    local escaped_rp = rp:gsub("([%.%-%+%(%)%[%]%$%^%%])", "%%%1")
    assert(script:find("Set%-Content %-Path '" .. escaped_rp .. "'"), "should write to results path")
  end)
end

T["build_script.includes_error_message_field"] = function()
  local p = test_path()
  local pos = { type = "file", path = p, id = p }
  local script = builder.build_script(pos, test_results_path(), default_config())
  MiniTest.expect.no_error(function()
    assert(script:find("ErrorMessage"), "should include ErrorMessage field")
  end)
end

T["build_script.includes_result_and_expandedname"] = function()
  local p = test_path()
  local pos = { type = "file", path = p, id = p }
  local script = builder.build_script(pos, test_results_path(), default_config())
  MiniTest.expect.no_error(function()
    assert(script:find("Result"), "should include Result field")
    assert(script:find("ExpandedName"), "should include ExpandedName field")
  end)
end

-- ── build_dap_script ─────────────────────────────────────────────────────────

T["build_dap_script.is_multi_line"] = function()
  local p = test_path()
  local pos = { type = "file", path = p, id = p }
  local script = builder.build_dap_script(pos, test_results_path(), default_config())
  MiniTest.expect.no_error(function()
    assert(script:find("\n"), "DAP script should be multi-line")
  end)
end

T["build_dap_script.uses_new_pester_configuration"] = function()
  local p = test_path()
  local pos = { type = "file", path = p, id = p }
  local script = builder.build_dap_script(pos, test_results_path(), default_config())
  MiniTest.expect.no_error(function()
    assert(script:find("New%-PesterConfiguration"), "should use New-PesterConfiguration")
  end)
end

return T
