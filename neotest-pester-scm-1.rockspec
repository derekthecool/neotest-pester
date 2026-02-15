rockspec_format = "3.0"
package = "neotest-pester"
version = "scm-1"

dependencies = {
  "lua >= 5.1",
  "neotest",
  "tree-sitter-fsharp",
  "tree-sitter-c_sharp",
  "tree-sitter-powershell",
}

test_dependencies = {
  "lua >= 5.1",
  "busted",
  "nlua",
}

source = {
  url = "git://github.com/derekthecool/neotest-pester",
}

build = {
  type = "builtin",
  copy_directories = {
    "scripts",
  },
}
