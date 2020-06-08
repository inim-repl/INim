import algorithm
from strutils import join
from os import getCurrentDir, getHomeDir, setCurrentDir, walkDir, absolutePath, lastPathPart
from osproc import execCmd

proc ls*(dir: string = getCurrentDir()): seq[string] =
  ## Print contents of a directory
  for kind, path in walkDir(dir):
    result.add(lastPathPart(path))
  result.sort()


proc cd*(dir: string = getHomeDir()): string =
  ## Change dir
  try:
    setCurrentDir(dir)
  except OsError as e:
    return e.msg
  getCurrentDir()


proc pwd*(): string =
  ## Print current path
  getCurrentDir()


proc call*(cmd: string) =
  ## Execute a shell command
  discard execCmd(cmd)
