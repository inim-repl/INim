import os, strutils
switch("path", "src/")

task test, "Run tests":
  for component, path in walkDir("tests"):
    if component == pcFile:
      let fname = path.splitPath.tail
      if fname.startswith("test") and fname.endswith(".nim"):
        exec "nim c -r tests/" & fname
