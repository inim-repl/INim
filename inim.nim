# MIT License
# Copyright (c) 2018 Andrei Regiani

import os, osproc, strformat, strutils, terminal, sequtils,
       times, strformat, parsecfg, sugar
import noise
from sequtils import filterIt

# Lists available builtin commands
var commands*: seq[string] = @[]

include inimpkg/commands

type App = ref object
  nim: string
  srcFile: string
  showHeader: bool
  flags: string
  rcFile: string
  showColor: bool
  showTypes: bool
  noAutoIndent: bool
  editor: string
  prompt: string
  withTools: bool

var
  app: App
  config: Config
  indentSpaces = "  "

const
  NimblePkgVersion {.strdefine.} = ""
  # endsWith
  IndentTriggers = [
      ",", "=", ":",
      "var", "let", "const", "type", "import",
      "object", "RootObj", "enum"
  ]
  # preloaded code into user's session
  EmbeddedCode = staticRead("inimpkg/embedded.nim")

let
  ConfigDir = getConfigDir() / "inim"
  RcFilePath = ConfigDir / "inim.ini"

proc getOrSetSectionKeyValue(dict: var Config, section, key,
    default: string): string =
  ## Get a value or set default for that key
  ## This is for when users have older versions of the config where they may be missing keys
  result = dict.getSectionValue(section, key)
  if result == "":
    #Option not present, we should set instead of erroring
    dict.setSectionKey(section, key, default)
    result = default

proc loadRCFileConfig(path: string): Config =
  # Perform any config migrations here
  result = loadConfig(path)
  result.writeConfig(path)

proc createRcFile(path: string): Config =
  ## Create a new rc file with default sections populated
  result = newConfig()
  result.setSectionKey("History", "persistent", "True")
  result.setSectionKey("Style", "prompt", "nim> ")
  result.setSectionKey("Style", "showTypes", "True")
  result.setSectionKey("Style", "showColor", "True")
  result.setSectionKey("Features", "withTools", "False")
  result.writeConfig(path)

let
  uniquePrefix = epochTime().int
  bufferSource = getTempDir() / "inim_" & $uniquePrefix & ".nim"
  validCodeSource = getTempDir() / "inimvc_" & $uniquePrefix & ".nim"
  tmpHistory = getTempDir() / "inim_history_" & $uniquePrefix & ".nim"

proc compileCode(): auto =
  # PENDING https://github.com/nim-lang/Nim/issues/8312,
  # remove redundant `--hint[source]=off`
  let compileCmd = [
      app.nim, "compile", "--run", "--verbosity=0", app.flags,
      "--hints=off", "--path=./", bufferSource
  ].join(" ")
  result = execCmdEx(compileCmd)

proc getPromptSymbol(): Styler

var
  currentExpression = ""     # Last stdin to evaluate
  currentOutputLine = 0      # Last line shown from buffer's stdout
  validCode = ""             # All statements compiled succesfully
  tempIndentCode = ""        # Later append to `validCode` if block compiles
  indentLevel = 0            # Current
  previouslyIndented = false # IndentLevel resets before showError()
  sessionNoAutoIndent = false
  buffer: File
  noiser = Noise.init()
  historyFile: string

template outputFg(color: ForegroundColor, bright: bool = false,
    body: untyped): untyped =
  ## Sets the foreground color for any writes to stdout
  ## in body and resets afterwards
  if app.showColor:
    stdout.setForegroundColor(color, bright)
  body

  if app.showColor:
    stdout.resetAttributes()
  stdout.flushFile()


proc getNimVersion*(): string =
  let (output, status) = execCmdEx(fmt"{app.nim} --version")
  doAssert status == 0, fmt"make sure {app.nim} is in PATH"
  result = output.splitLines()[0]


proc getNimPath(): string =
  # TODO: use `which` PENDING https://github.com/nim-lang/Nim/issues/8311
  let whichCmd = when defined(Windows):
        fmt"where {app.nim}"
    else:
        fmt"which {app.nim}"
  let (output, status) = execCmdEx(which_cmd)
  if status == 0:
    return " at " & output
  return "\n"


proc welcomeScreen() =
  outputFg(fgYellow, false):
    when defined(posix):
      stdout.write "👑 " # Crashes on Windows: Unknown IO Error [IOError]
    stdout.writeLine "INim ", NimblePkgVersion
    if app.showColor:
      stdout.setForegroundColor(fgCyan)
    stdout.write getNimVersion()
    stdout.write getNimPath()


proc cleanExit(exitCode = 0) =
  buffer.close()
  removeFile(bufferSource) # Temp .nim
  removeFile(bufferSource[0..^5]) # Temp binary, same filename without ".nim"
  removeFile(tmpHistory)
  removeDir(getTempDir() / "nimcache")
  config.writeConfig(app.rcFile)
  when promptHistory:
    # Save our history
    discard noiser.historySave(historyFile)
  quit(exitCode)

proc getFileData(path: string): string =
  try: path.readFile() except: ""

proc compilationSuccess(current_statement, output: string, commit = true) =
  ## Add our line to valid code
  ## If we don't commit, roll back validCode if we've entered an echo
  if len(tempIndentCode) > 0:
    validCode &= tempIndentCode
  else:
    validCode &= current_statement & "\n"

  # Print only output you haven't seen
  outputFg(fgCyan, true):
    let lines = output.splitLines
    let new_lines = lines[currentOutputLine..^1]
    for index, line in new_lines:
      # Skip last empty line (otherwise blank line is displayed after command)
      if index+1 == len(new_lines) and line == "":
        continue
      echo line

  # Roll back our valid code to not include the echo
  if current_statement.contains("echo") and not commit:
    let newOffset = current_statement.len + 1
    validCode = validCode[0 ..< ^newOffset]
  else:
    # Or commit the line
    currentOutputLine = len(lines)-1

proc bufferRestoreValidCode() =
  if buffer != nil:
    buffer.close()
  buffer = open(bufferSource, fmWrite)
  buffer.writeLine(EmbeddedCode)
  buffer.write(validCode)
  buffer.flushFile()

proc showError(output: string, reraised: bool = false) =
  # Determine whether last expression was to import a module
  var importStatement = false
  if currentExpression.len > 7 and currentExpression[0..6] == "import ":
    importStatement = true

  #### Reraised errors. These get reraised if the statement being echoed with a type fails
  if reraised:
    outputFg(fgRed, true):
      if output.contains("Error"):
        echo output[output.find("Error") .. ^2]
      else:
        echo output
    return

  #### Runtime errors:
  if output.contains("Error: unhandled exception:"):
    var lines = output.splitLines().filterIt(not it.isEmptyOrWhitespace)
    # Print out any runtime echo messages before printing the error
    for runtimeEchoLine in lines[0 ..< lines.len - 5]:
      echo runtimeEchoLine
    outputFg(fgRed, true):
      # Display only the relevant lines of the stack trace

      if not importStatement:
         echo lines[^3]
      else:
        for line in lines[len(lines) - 5 ..< len(lines) - 1]:
          echo line
    return

  #### Compilation errors:
  # Prints only relevant message without file and line number info.
  # e.g. "inim_1520787258.nim(2, 6) Error: undeclared identifier: 'foo'"
  # Becomes: "Error: undeclared identifier: 'foo'"
  let pos = output.find(")") + 2
  var message = output[pos..^1].strip

  # Discard shortcut conditions
  let
    hasCurrentExpression = currentExpression != ""
    noImportStatement = importStatement == false
    notPreviousIndented = previouslyIndented == false
    isHasToBe = message.contains("and has to be")
    isDiscardShortcut = hasCurrentExpression and noImportStatement and notPreviousIndented and isHasToBe

  # Discarded shortcut, print values: nim> myvar
  if isDiscardShortcut:
    # Following lines grabs the type from the discarded expression:
    # Remove text bloat to result into: e.g. foo'int
    message = message.multiReplace({
        "Error: expression '": "",
        " is of type '": "",
        "' and has to be used": "",
        "' and has to be discarded": "",
        "' and has to be used (or discarded)": ""
    })
    # Make split char to be a semicolon instead of a single-quote,
    # To avoid char type conflict having single-quotes
    message[message.rfind("'")] = ';' # last single-quote
    let message_seq = message.split(";") # expression;type, e.g 'a';char
    let typeExpression = message_seq[1] # type, e.g. char
                                        # Ignore this colour change
    let shortcut = when defined(Windows):
            fmt"""
            stdout.write $({currentExpression})
            stdout.write "  : "
            stdout.write "{typeExpression}"
            echo ""
            """.unindent()
        else: # Posix: colorize type to yellow
          if app.showColor:
            fmt"""
            stdout.write $({currentExpression})
            stdout.write "\e[33m" # Yellow
            stdout.write "  : "
            stdout.write "{typeExpression}"
            echo "\e[39m" # Reset color
            """.unindent()
          else:
            fmt"""
            stdout.write $({currentExpression})
            stdout.write "  : "
            stdout.write "{typeExpression}"
            """.unindent()

    buffer.writeLine(shortcut)
    buffer.flushFile()

    let (output, status) = compileCode()
    if status == 0:
      compilationSuccess(shortcut, output)
    else:
      bufferRestoreValidCode()
      showError(output) # Recursion

    # Display all other errors
  else:
    outputFg(fgRed, true):
      echo if importStatement:
              output.strip() # Full message
          else:
              message # Shortened message
    previouslyIndented = false

proc getPromptSymbol(): Styler =
  var prompt = ""
  if indentLevel == 0:
    prompt = app.prompt
    previouslyIndented = false
  else:
    prompt = ".... "
  # Auto-indent (multi-level)
  result = Styler.init(prompt)

proc init(preload = "") =
  bufferRestoreValidCode()

  if preload == "":
    # First dummy compilation so next one is faster for the user
    discard compileCode()
    return

  buffer.writeLine(preload)
  buffer.flushFile()

  # Check preloaded file compiles succesfully
  let (output, status) = compileCode()
  if status == 0:
    compilationSuccess(preload, output)

  # Compilation error
  else:
    bufferRestoreValidCode()
    # Imports display more of the stack trace in case of errors,
    # instead of one-liners error
    currentExpression = "import " # Pretend it was an import for showError()
    showError(output)

proc hasIndentTrigger*(line: string): bool =
  if line.len == 0:
    return
  for trigger in IndentTriggers:
    if line.strip().endsWith(trigger):
      result = true

proc doRepl() =
  # Read line
  if indentLevel > 0:
    noiser.preloadBuffer(indentSpaces.repeat(indentLevel))
  let ok = noiser.readLine()
  if not ok:
    case noiser.getKeyType():
    of ktCtrlC:
      bufferRestoreValidCode()
      indentLevel = 0
      tempIndentCode = ""
      return
    of ktCtrlD:
      echo "\nQuitting INim: Goodbye!"
      cleanExit()
    of ktCtrlX:
      if app.editor != "":
        var vc = open(validCodeSource, fmWrite)
        vc.write(validCode)
        vc.close()
        # Spawn our editor as a process
        var pid = startProcess(app.editor, args = @[validCodeSource],
            options = {poParentStreams, poUsePath})
        # Wait for the user to finish editing
        discard pid.waitForExit()
        pid.close()
        # Read back the full code into our valid code buffer
        validCode = readFile(validCodeSource)
        bufferRestoreValidCode()
      else:
        echo "No $EDITOR set in ENV"
      return
    else:
      return

  currentExpression = noiser.getLine

  # Special commands
  if currentExpression in ["exit", "exit()", "quit", "quit()"]:
    cleanExit()
  elif currentExpression in ["help", "help()"]:
    outputFg(fgCyan, true):
      var helpString = """
iNim - Interactive Nim Shell - By AndreiRegiani

Available Commands:
Quit - exit, exit(), quit, quit(), ctrl+d
Help - help, help()"""
      if app.withTools:
        helpString.add("""ls(dir = .) - Print contents of dir
cd(dir = ~/) - Change current directory
pwd() - Print current directory
call(cmd) - Execute command cmd in current shell
""")
      echo helpString
    return
  elif currentExpression in commands:
    if app.withTools:
      if not currentExpression.endsWith("()"):
        currentExpression.add("()")
    else:
      discard

  # Empty line: exit indent level, otherwise do nothing
  if currentExpression.strip() == "" or currentExpression.startsWith("else"):
    if indentLevel > 0:
      indentLevel -= 1
    elif indentLevel == 0:
      return

  # Write your line to buffer(temp) source code
  buffer.writeLine(indentSpaces.repeat(indentLevel) & currentExpression)
  buffer.flushFile()

  # Check for indent and trigger it
  if currentExpression.hasIndentTrigger():
    # Already indented once skipping
    if not sessionNoAutoIndent or not previouslyIndented:
      indentLevel += 1
      previouslyIndented = true

  # Don't run yet if still on indent
  if indentLevel != 0:
    # Skip indent for first line
    let n = if currentExpression.hasIndentTrigger(): 1 else: 0
    tempIndentCode &= currentExpression & "\n"
    when promptHistory:
      # Add in indents to our history
      if tempIndentCode.len > 0:
        noiser.historyAdd(currentExpression)
    return

  # Compile buffer
  let (output, status) = compileCode()

  when promptHistory:
    if currentExpression.strip().len > 0:
      noiser.historyAdd(currentExpression)

  # Succesful compilation, expression is valid
  if status == 0:
    compilationSuccess(currentExpression, output)
    if "echo" in currentExpression:
      # Roll back echoes
      bufferRestoreValidCode()
  # Maybe trying to echo value?
  elif "has to be used" in output or "has to be discarded" in output and
      indentLevel == 0: #
    bufferRestoreValidCode()

    # Save the current expression as an echo
    currentExpression = if app.showTypes:
        fmt"""echo $({currentExpression}) & " == " & "type " & $(type({currentExpression}))"""
      else:
        fmt"""echo $({currentExpression})"""
    buffer.writeLine(currentExpression)
    buffer.flushFile()

    # Don't run yet if still on indent
    if indentLevel != 0:
      # Skip indent for first line
      let n = if currentExpression.hasIndentTrigger(): 1 else: 0
      tempIndentCode &= currentExpression & "\n"
      when promptHistory:
        # Add in indents to our history
        if currentExpression.len > 0:
          noiser.historyAdd(
            currentExpression
          )

    let (echo_output, echo_status) = compileCode()
    if echo_status == 0:
      compilationSuccess(currentExpression, echo_output)
    else:
      # Show any errors in echoing the statement
      indentLevel = 0
      if app.showTypes:
        # If we show types and this has errored again,
        # reraise the original error message
        showError(output, reraised = true)
      else:
        showError(echo_output)
      # Roll back to not include the temporary echo line
      bufferRestoreValidCode()

    # Roll back to not include the temporary echo line
    bufferRestoreValidCode()
  else:
    # Write back valid code to buffer
    bufferRestoreValidCode()
    indentLevel = 0
    showError(output)

  # Clean up
  tempIndentCode = ""

proc initApp*(nim, srcFile: string, showHeader: bool, flags = "",
    rcFilePath = RcFilePath, showColor = true, noAutoIndent = false) =
  ## Initialize the ``app` variable.
  app = App(
      nim: nim,
      srcFile: srcFile,
      showHeader: showHeader,
      flags: flags,
      rcFile: rcFilePath,
      showColor: showColor,
      noAutoIndent: noAutoIndent,
      withTools: false
  )


proc runCodeAndExit() =
  ## When we're reading from piped data, we just want to execute the code
  ## and echo the output

  let codeToRun = stdin.readAll().strip()
  let codeEndsInEcho = codeToRun.split({';', '\r', '\n'})[^1].strip().startsWith("echo")

  if codeEndsInEcho:
    # If the code ends in an echo, just
    buffer.write(codeToRun)
  elif "import" in codeToRun:
    # If we have imports in our code to run, we need to split them up and place them outside our block
    let
      importLines = codeToRun.split({';', '\r', '\n'}).filter(proc (
        code: string): bool =
        code.find("import") != -1 and code.strip() != ""
      ).join(";")
      nonImportLines = codeToRun.split({';', '\r', '\n'}).filter(proc (
        code: string): bool =
        code.find("import") == -1 and code.strip() != ""
      ).join(";")

    let strToWrite = """$#
let tmpVal = block:
  $#
echo tmpVal
  """ % [importLines, nonImportLines]
    buffer.write(strToWrite)
  else:
    # If we have no imports, we should just run our code
    buffer.write("""let tmpVal = block:
  $#
echo tmpVal
  """ % codeToRun
    )
  buffer.flushFile
  let (echo_output, echo_status) = compileCode()
  echo echo_output.strip()

proc main(nim = "nim", srcFile = "", showHeader = true,
          flags: seq[string] = @[], createRcFile = false,
          rcFilePath: string = RcFilePath, showTypes: bool = false,
          showColor: bool = true, noAutoIndent: bool = false,
          withTools: bool = false) =
  ## inim interpreter

  initApp(nim, srcFile, showHeader)

  if flags.len > 0:
    app.flags = flags.map(f => (
        block:
          if f.startsWith("--"):
            return f
          return fmt"-d:{f}"
      )
    ).join(" ")

  discard existsorCreateDir(ConfigDir)
  let shouldCreateRc = not existsorCreateDir(rcFilePath.splitPath.head) or
      not fileExists(rcFilePath) or createRcFile
  config = if shouldCreateRc: createRcFile(rcFilePath)
           else: loadRCFileConfig(rcFilePath)

  if app.showHeader and isatty(stdin): welcomeScreen()

  if withTools or config.getOrSetSectionKeyValue("Features", "withTools",
      "False") == "True":
    app.flags.add(" -d:withTools")
    app.withTools = true

  assert not isNil config
  when promptHistory:
    # When prompt history is enabled, we want to load history
    historyFile = if config.getOrSetSectionKeyValue("History", "persistent",
        "True") == "True":
                    ConfigDir / "history.nim"
                  else: tmpHistory
    discard noiser.historyLoad(historyFile)

  # Force show types
  if showTypes or config.getOrSetSectionKeyValue("Style", "showTypes",
      "True") == "True":
    app.showTypes = true

  app.prompt = config.getOrSetSectionKeyValue("Style", "prompt", "nim> ")

  # Force show color
  if not showColor or defined(NoColor) or config.getOrSetSectionKeyValue(
      "Style", "showColor", "True") == "False":
    app.showColor = false

  if noAutoIndent:
    # Still trigger indents but do not actually output any spaces,
    # useful when sending text to a terminal
    indentSpaces = ""
    sessionNoAutoIndent = noAutoIndent

  app.editor = getEnv("EDITOR")

  if srcFile.len > 0:
    doAssert(srcFile.fileExists, "cannot access " & srcFile)
    doAssert(srcFile.splitFile.ext == ".nim")
    let fileData = getFileData(srcFile)
    init(fileData) # Preload code into init
  else:
    init() # Clean init

  when not defined(NOTTYCHECK):
    if not isatty(stdin):
      runCodeAndExit()
      cleanExit()

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
          "noAutoIndent": "Disable automatic indentation",
          "withTools": "Load handy tools"
    })
