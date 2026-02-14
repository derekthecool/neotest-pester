# we disable the `all` command because some external tool might run it automatically
.SUFFIXES:

all:

# runs all the test files.
test:
	luarocks test --local

# performs a lint check and fixes issue if possible, following the config in `stylua.toml`.
lint:
	stylua .
