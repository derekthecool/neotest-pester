local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local T = new_set()

local builder = require("neotest-pester.spec_builder")

local function default_config()
  return { pwsh_path = "pwsh", extra_args = {} }
end

-- ── file position ────────────────────────────────────────────────────────────

T["build_script.file.contains_path_arg"] = function()
  local pos = { type = "file", path = "C:/code/MyModule.Tests.ps1", id = "C:/code/MyModule.Tests.ps1" }
  local script = builder.build_script(pos, "C:/tmp/results.json", default_config())
  MiniTest.expect.no_error(function()
    assert(script:find("-Path 'C:/code/MyModule.Tests.ps1'"), "expected -Path arg in script")
  end)
end

T["build_script.file.no_fullname_filter"] = function()
  local pos = { type = "file", path = "C:/code/MyModule.Tests.ps1", id = "C:/code/MyModule.Tests.ps1" }
  local script = builder.build_script(pos, "C:/tmp/results.json", default_config())
  MiniTest.expect.no_error(function()
    assert(not script:find("-FullNameFilter"), "file position should not have -FullNameFilter")
  end)
end

T["build_script.file.writes_to_results_path"] = function()
  local pos = { type = "file", path = "C:/code/MyModule.Tests.ps1", id = "C:/code/MyModule.Tests.ps1" }
  local script = builder.build_script(pos, "C:/tmp/results.json", default_config())
  MiniTest.expect.no_error(function()
    assert(script:find("Set%-Content %-Path 'C:/tmp/results%.json'"), "expected Set-Content with results path")
  end)
end

-- ── namespace (Describe) position ────────────────────────────────────────────

T["build_script.namespace.has_wildcard_filter"] = function()
  local pos = {
    type = "namespace",
    path = "C:/code/MyModule.Tests.ps1",
    id = "C:/code/MyModule.Tests.ps1::'Format-Pairs'::'unused'",
  }
  local script = builder.build_script(pos, "C:/tmp/results.json", default_config())
  MiniTest.expect.no_error(function()
    assert(
      script:find("-FullNameFilter 'Format%-Pairs%*'"),
      "namespace position should have wildcard FullNameFilter, got: " .. script
    )
  end)
end

-- ── test (It) position ───────────────────────────────────────────────────────

T["build_script.test.has_exact_filter"] = function()
  local pos = {
    type = "test",
    path = "C:/code/MyModule.Tests.ps1",
    id = "C:/code/MyModule.Tests.ps1::'Format-Pairs'::'Function exists'",
  }
  local script = builder.build_script(pos, "C:/tmp/results.json", default_config())
  MiniTest.expect.no_error(function()
    assert(
      script:find("-FullNameFilter 'Format%-Pairs Function exists'"),
      "test position should have exact FullNameFilter, got: " .. script
    )
  end)
end

-- ── extra_args ───────────────────────────────────────────────────────────────

T["build_script.extra_args.appended_before_passthru"] = function()
  local pos = { type = "file", path = "C:/code/MyModule.Tests.ps1", id = "C:/code/MyModule.Tests.ps1" }
  local cfg = { pwsh_path = "pwsh", extra_args = { "-Tag", "fast" } }
  local script = builder.build_script(pos, "C:/tmp/results.json", cfg)
  MiniTest.expect.no_error(function()
    assert(script:find("%-Tag fast"), "extra_args should appear in script, got: " .. script)
  end)
  MiniTest.expect.no_error(function()
    -- -PassThru must come after extra_args
    local tag_pos = script:find("%-Tag fast")
    local pt_pos = script:find("%-PassThru")
    assert(tag_pos < pt_pos, "-PassThru should appear after extra_args")
  end)
end

T["build_script.extra_args.empty_no_extra_spaces"] = function()
  local pos = { type = "file", path = "C:/code/Test.Tests.ps1", id = "C:/code/Test.Tests.ps1" }
  local script = builder.build_script(pos, "C:/tmp/r.json", default_config())
  MiniTest.expect.no_error(function()
    -- Should not have consecutive spaces from an empty extra_args
    assert(not script:find("  "), "script should not have consecutive spaces, got: " .. script)
  end)
end

-- ── output fields ────────────────────────────────────────────────────────────

T["build_script.output.includes_error_message_field"] = function()
  local pos = { type = "file", path = "C:/code/Test.Tests.ps1", id = "C:/code/Test.Tests.ps1" }
  local script = builder.build_script(pos, "C:/tmp/r.json", default_config())
  MiniTest.expect.no_error(function()
    assert(script:find("ErrorMessage"), "script should select ErrorMessage field")
  end)
end

T["build_script.output.includes_result_and_expandedname"] = function()
  local pos = { type = "file", path = "C:/code/Test.Tests.ps1", id = "C:/code/Test.Tests.ps1" }
  local script = builder.build_script(pos, "C:/tmp/r.json", default_config())
  MiniTest.expect.no_error(function()
    assert(script:find("Result"), "script should select Result field")
    assert(script:find("ExpandedName"), "script should select ExpandedName field")
  end)
end

return T
