when defined(withTools):
  # Include our imports to our embedded code if we have tools enabled
  import algorithm
  from strutils import join
  from os import getCurrentDir, getHomeDir, setCurrentDir, walkDir,
      absolutePath, lastPathPart
  from osproc import execCmd
else:
  import macros, algorithm

macro command(x: untyped): untyped =
  ## Procs annotated with the command pragma are patched up to allow
  ## for parenthesis-less calls to procs with no args
  when not defined(withTools):
    let msg = name(x)
    result = newStmtList(
      newNimNode(nnkCall).add(
        newNimNode(nnkDotExpr).add(
          newIdentNode("commands"),
          newIdentNode("add")
      ),
      newStrLitNode($msg)
    ),
      newNimNode(nnkCall).add(
        newNimNode(nnkDotExpr).add(
          newIdentNode("commands"),
          newIdentNode("add")
      ),
      newStrLitNode($msg & "()")
    ),
      x
    )
  else:
    result = x


proc ls*(dir: string = getCurrentDir()): seq[string] {.command.} =
  ## Print contents of a directory
  for kind, path in walkDir(dir):
    result.add(lastPathPart(path))
  result.sort()


proc cd*(dir: string = getHomeDir()): string {.command.} =
  ## Change dir
  try:
    setCurrentDir(dir)
  except OsError as e:
    return e.msg
  getCurrentDir()


proc pwd*(): string {.command.} =
  ## Print current path
  getCurrentDir()


proc call*(cmd: string) {.command.} =
  ## Execute a shell command
  discard execCmd(cmd)
