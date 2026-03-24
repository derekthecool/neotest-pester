local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local T = new_set()

local plugin = require("neotest-pester")

-- Helpers ────────────────────────────────────────────────────────────────────

local function test_file_path()
  return vim.fs.joinpath(vim.fn.getcwd(), "tests", "samples", "file.Tests.ps1")
end

local function write_results_file(data)
  local path = vim.fn.tempname() .. ".json"
  vim.fn.writefile({ data }, path)
  return path
end

---Build a minimal mock tree that iterates over the provided positions
local function mock_tree(positions)
  local i = 0
  return {
    iter = function()
      return function()
        i = i + 1
        if positions[i] then
          return i, positions[i]
        end
      end
    end,
  }
end

local function make_spec(results_path)
  return {
    context = {
      results_path = results_path,
      stop_stream = function() end,
    },
  }
end

local function make_result(output_path)
  return { output = output_path or vim.fn.tempname() }
end

-- ── passed test ──────────────────────────────────────────────────────────────

T["results.passed_test_maps_to_passed_status"] = function()
  local json = '[{"Result":"Passed","ExpandedName":"My test","ErrorMessage":null}]'
  local results_path = write_results_file(json)
  local fp = test_file_path()

  local pos = {
    type = "test",
    id = fp .. "::'MyDescribe'::'My test'",
    range = { 5, 0, 7, 0 },
  }
  local results = plugin.results(make_spec(results_path), make_result(), mock_tree({ pos }))
  eq("passed", results[pos.id].status)
end

-- ── failed test with error message ──────────────────────────────────────────

T["results.failed_test_maps_to_failed_status"] = function()
  local json = '[{"Result":"Failed","ExpandedName":"Broken test","ErrorMessage":"Expected 1 but got 2"}]'
  local results_path = write_results_file(json)
  local fp = test_file_path()

  local pos = {
    type = "test",
    id = fp .. "::'MyDescribe'::'Broken test'",
    range = { 10, 0, 12, 0 },
  }
  local results = plugin.results(make_spec(results_path), make_result(), mock_tree({ pos }))
  eq("failed", results[pos.id].status)
end

T["results.failed_test_includes_error_message"] = function()
  local json = '[{"Result":"Failed","ExpandedName":"Broken test","ErrorMessage":"Expected 1 but got 2"}]'
  local results_path = write_results_file(json)
  local fp = test_file_path()

  local pos = {
    type = "test",
    id = fp .. "::'MyDescribe'::'Broken test'",
    range = { 10, 0, 12, 0 },
  }
  local results = plugin.results(make_spec(results_path), make_result(), mock_tree({ pos }))
  eq("Expected 1 but got 2", results[pos.id].short)
end

T["results.failed_test_includes_errors_array"] = function()
  local json = '[{"Result":"Failed","ExpandedName":"Broken test","ErrorMessage":"Expected 1 but got 2"}]'
  local results_path = write_results_file(json)
  local fp = test_file_path()

  local pos = {
    type = "test",
    id = fp .. "::'MyDescribe'::'Broken test'",
    range = { 10, 0, 12, 0 },
  }
  local results = plugin.results(make_spec(results_path), make_result(), mock_tree({ pos }))
  local errs = results[pos.id].errors
  eq(1, #errs)
  eq("Expected 1 but got 2", errs[1].message)
end

-- ── skipped test ─────────────────────────────────────────────────────────────

T["results.skipped_test_maps_to_skipped_status"] = function()
  local json = '[{"Result":"Skipped","ExpandedName":"Skipped test","ErrorMessage":null}]'
  local results_path = write_results_file(json)
  local fp = test_file_path()

  local pos = {
    type = "test",
    id = fp .. "::'MyDescribe'::'Skipped test'",
    range = { 15, 0, 17, 0 },
  }
  local results = plugin.results(make_spec(results_path), make_result(), mock_tree({ pos }))
  eq("skipped", results[pos.id].status)
end

-- ── no error message on passed test ─────────────────────────────────────────

T["results.passed_test_has_no_error_message"] = function()
  local json = '[{"Result":"Passed","ExpandedName":"Good test","ErrorMessage":null}]'
  local results_path = write_results_file(json)
  local fp = test_file_path()

  local pos = {
    type = "test",
    id = fp .. "::'MyDescribe'::'Good test'",
    range = { 1, 0, 3, 0 },
  }
  local results = plugin.results(make_spec(results_path), make_result(), mock_tree({ pos }))
  eq(nil, results[pos.id].short)
  eq(nil, results[pos.id].errors)
end

-- ── missing results file ─────────────────────────────────────────────────────

T["results.missing_results_file_returns_empty"] = function()
  local nonexistent = vim.fs.joinpath(vim.fn.tempname(), "nonexistent", "results.json")
  local spec = make_spec(nonexistent)
  local results = plugin.results(spec, make_result(), mock_tree({}))
  eq("table", type(results))
  eq(0, #vim.tbl_keys(results))
end

return T
