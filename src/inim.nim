import inimpkg/logic
import noise

proc main(nim = "nim", srcFile = "", showHeader = true,
      flags: seq[string] = @[], createRcFile = false,
      rcFilePath: string = RcFilePath, showTypes: bool = false,
      showColor: bool = true, noAutoIndent: bool = false
      ) =
  initMain(nim, srcFile, showHeader, flags, createRcFile, rcFilePath, showTypes, showColor, noAutoIndent)
  while true:
    let prompt = getPromptSymbol()
    noiser.setPrompt(prompt)

    doRepl()

when isMainModule:
  import cligen
  dispatch(main, short = {"flags": 'd'}, help = {
          "nim": "Path to nim compiler",
          "srcFile": "Nim script to preload/run",
          "showHeader": "Show program info startup",
          "flags": "Nim flags to pass to the compiler",
          "createRcFile": "Force create inimrc file. Overrides current file",
          "rcFilePath": "Change location of the inimrc file to use",
          "showTypes": "Show var types when printing var without echo",
          "showColor": "Color displayed text",
          "noAutoIndent": "Disable automatic indentation"
    })
