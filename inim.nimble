# Package

version       = "0.4.5"
author        = "Andrei Regiani"
description   = "Interactive Nim Shell / REPL / Playground"
license       = "MIT"
srcDir        = "src"
bin           = @["inim"]

# Dependencies

requires "nim >= 1.0.0"
requires "cligen >= 0.9.15"
requires "noise"
requires "jester"

task test, "Run tests":
  exec "nim c -r -d:prompt_no_history tests/test.nim"
