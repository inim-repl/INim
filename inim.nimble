# Package

version       = "0.5.0"
author        = "Andrei Regiani"
description   = "Interactive Nim Shell / REPL / Playground"
license       = "MIT"
srcDir        = "src"
bin           = @["inim"]

# Dependencies

#requires "nim >= 1.0.0" # can we remove this to imply it should work with all versions?
requires "cligen >= 1.0.0"
requires "noise"

task test, "Run all tests":
  exec "mkdir -p bin"
  exec "nim c -d:NoColor -d:prompt_no_history --out:bin/inim src/inim.nim"
  exec "nim c -r -d:prompt_no_history tests/test.nim"
  # Recompile with tty checks
  exec "nim c -d:NoColor -d:NOTTYCHECK -d:prompt_no_history --out:bin/inim src/inim.nim"
  exec "nim c -r -d:withTools -d:prompt_no_history tests/test_commands.nim"
  exec "nim c -r -d:prompt_no_history tests/test_interface.nim"
