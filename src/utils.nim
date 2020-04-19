import os, times, osproc, strutils


proc compileAndRunFile(path: string): auto =
  ## Compiles and runs the code at `path`.
  let compileCmd = [
      "nim", "compile", "--run", "--verbosity=0",
      "--hints=off", "--hint[source]=off", "--path=./", path
  ].join(" ")
  execCmdEx(compileCmd)

proc getTempFile*(): string =
  ## returns a new psudo-unique temp nim file.
  let uniquePrefix = epochTime().int
  getTempDir() & "inim_" & $uniquePrefix & ".nim"


proc runCode*(code: string): tuple[output: TaintedString, exitCode: int] =
  ## Executes `code` as a nim file, returns output.
  let path = getTempFile()
  let buffer = path.open(fmWrite)
  buffer.write(code)
  buffer.flushFile()
  return compileAndRunFile(path)

