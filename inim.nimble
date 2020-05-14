# Package

version       = "0.4.7"
author        = "Andrei Regiani"
description   = "Interactive Nim Shell / REPL / Playground"
license       = "MIT"
srcDir        = "src"
bin           = @["inim"]

# Dependencies

requires "nim >= 1.0.0"
requires "cligen >= 0.9.15"
requires "noise"


task test, "Run all tests":
  exec "mkdir -p bin"
  exec "nim c -d:NoColours -d:prompt_no_history --out:bin/inim src/inim.nim"
  exec "nim c -r -d:prompt_no_history tests/test.nim"
  exec "nim c -r -d:prompt_no_history tests/test_interface.nim"
