# Package

skipDirs      = @["tests"]
version       = "0.6.2"
author        = "Andrei Regiani"
description   = "Interactive Nim Shell / REPL / Playground"
license       = "MIT"
installDirs   = @["inimpkg"]
installExt    = @["nim"]
bin           = @["inim"]

# Dependencies

requires "cligen >= 1.5.22"

requires "noise >= 0.1.4"

task test, "Run all tests":
  exec "mkdir -p bin"
  exec "nim c -d:NoColor -d:prompt_no_history --out:bin/inim inim.nim"
  exec "nim c -r -d:prompt_no_history tests/test.nim"
  # Recompile with tty checks
  exec "nim c -d:NoColor -d:NOTTYCHECK -d:prompt_no_history --out:bin/inim inim.nim"
  exec "nim c -r -d:withTools -d:prompt_no_history tests/test_commands.nim"
  exec "nim c -r -d:prompt_no_history tests/test_interface.nim"
