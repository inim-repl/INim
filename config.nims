task develop, "Run with hotcode reloading for development":
  switch("path", "src/")
  exec "nim c -f -d:DEBUG --hotcodereloading:on src/inim.nim"
  exec "src/inim"


task make, "Durr":
  switch("path", "src/")
  exec "nim c -r -f -d:DEBUG src/inim.nim"
