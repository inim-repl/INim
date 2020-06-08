# Package

version       = "0.5.0"
author        = "Andrei Regiani"
description   = "Interactive Nim Shell / REPL / Playground"
license       = "MIT"
srcDir        = "src"
bin           = @["inim"]

# Dependencies

requires "nim >= 1.0.0"
requires "cligen >= 0.9.15"
# TODO: Swap back to the default nimble package after https://github.com/jangko/nim-noise/pull/9 is merged
# requires "noise"
requires "https://github.com/Tangdongle/nim-noise"


task test, "Run all tests":
  exec "mkdir -p bin"
  exec "nim c -d:NoColor -d:prompt_no_history --out:bin/inim src/inim.nim"
  exec "nim c -r -d:prompt_no_history tests/test.nim"
  exec "nim c -r -d:prompt_no_history tests/test_interface.nim"
