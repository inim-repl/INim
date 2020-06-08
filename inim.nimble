# Package

version       = "0.5.0"
author        = "Andrei Regiani"
description   = "Interactive Nim Shell / REPL / Playground"
license       = "MIT"
srcDir        = "src"
bin           = @["inim"]

# Dependencies

requires "nim >= 1.0.0"
requires "cligen >= 1.0.0"
requires "noise"

task test, "Run all tests":
  exec "mkdir -p bin"
  exec "nim c -d:NoColor -d:prompt_no_history --out:bin/inim src/inim.nim"
  exec "nim c -r -d:prompt_no_history tests/test.nim"
  exec "nim c -r -d:prompt_no_history --listFullPaths:on tests/test_commands.nim"
  exec "nim c -r -d:prompt_no_history tests/test_interface.nim"
