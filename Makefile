test: deps/mini.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# # Run test from file at `$FILE` environment variable
# test_file: deps/mini.nvim
# 	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

# Download 'mini.nvim' to use its 'mini.test' testing module
deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/nvim-mini/mini.nvim deps/mini.nvim
	git clone --filter=blob:none https://github.com/nvim-neotest/nvim-nio deps/nvim-nio
	git clone --filter=blob:none https://github.com/nvim-neotest/neotest deps/neotest
  git clone --filter=blob:none https://github.com/nvim-neotest/nvim-nio deps/nvim-nio
  git clone --filter=blob:none https://github.com/nvim-lua/plenary.nvim deps/plenary.nvim
  git clone --filter=blob:none https://github.com/antoinemadec/FixCursorHold.nvim deps/FixCursorHold.nvim
  git clone --filter=blob:none https://github.com/nvim-treesitter/nvim-treesitter deps/nvim-treesitter
