-- run interactively with
-- require('mini.test').setup()
-- lua MiniTest.run()
--
-- run from command line with this command
-- nvim --headless -c "lua require('mini.test').setup();MiniTest.run()"
-- or like this
-- nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua require('mini.test').setup();MiniTest.run()"

local T = MiniTest.new_set()

-- Make sure nio dependency is available - this is where plenary.nvim and luarocks testing do not work for me
T["has nio"] = function()
  -- This expectation will pass because function will *not* throw an error
  MiniTest.expect.no_error(function()
    require("nio")
  end)
end

return T
