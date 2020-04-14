# MIT License
# Copyright (c) 2018 Andrei Regiani

import os, osproc, rdstdin, strformat, strutils, terminal, times, strformat

type App = ref object
    nim: string
    srcFile: string
    showHeader: bool
    flags: string

var app: App

const
    INimVersion = "0.4.3"
    IndentSpaces = "    "
    # endsWith
    IndentTriggers = [
        ",", "=", ":", 
        "var", "let", "const", "type", "import",
        "object", "RootObj", "enum"
    ]
    # preloaded code into user's session
    EmbeddedCode = staticRead("inimpkg/embedded.nim") 

let
    uniquePrefix = epochTime().int
    bufferSource = getTempDir() & "inim_" & $uniquePrefix & ".nim"

proc compileCode(): auto =
    # PENDING https://github.com/nim-lang/Nim/issues/8312, remove redundant `--hint[source]=off`
    let compileCmd = [
        app.nim, "compile", "--run", "--verbosity=0", app.flags, 
        "--hints=off", "--hint[source]=off", "--path=./", bufferSource
    ].join(" ")
    result = execCmdEx(compileCmd)

var
    currentExpression = "" # Last stdin to evaluate
    currentOutputLine = 0  # Last line shown from buffer's stdout
    validCode = ""         # All statements compiled succesfully
    tempIndentCode = ""    # Later append to `validCode` if whole block compiles well
    indentLevel = 0        # Current
    previouslyIndented = false # Helper for showError(), indentLevel resets before showError()
    buffer: File

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
    stdout.setForegroundColor(fgYellow)
    when defined(posix):
        stdout.write "👑 " # Crashes on Windows: Unknown IO Error [IOError]
    stdout.writeLine "INim ", INimVersion
    stdout.setForegroundColor(fgCyan)
    stdout.write getNimVersion()
    stdout.write getNimPath()
    stdout.resetAttributes()
    stdout.flushFile()

proc cleanExit(exitCode = 0) =
    buffer.close()
    removeFile(bufferSource) # Temp .nim
    removeFile(bufferSource[0..^5]) # Temp binary, same filename just without ".nim"
    removeDir(getTempDir() & "nimcache")
    quit(exitCode)

proc controlCHook() {.noconv.} =
    cleanExit(1)

proc getFileData(path: string): string =
    try: path.readFile() except: ""

proc compilationSuccess(current_statement, output: string) =
    if len(tempIndentCode) > 0:
        validCode &= tempIndentCode
    else:
        validCode &= current_statement & "\n"

    # Print only output you haven't seen
    stdout.setForegroundColor(fgCyan, true)
    let lines = output.splitLines
    let new_lines = lines[currentOutputLine..^1]
    for index, line in new_lines:
        # Skip last empty line (otherwise blank line is displayed after command)
        if index+1 == len(new_lines) and line == "":
            continue
        echo line

    currentOutputLine = len(lines)-1
    stdout.resetAttributes()
    stdout.flushFile()

proc bufferRestoreValidCode() =
    if buffer != nil:
        buffer.close()
    buffer = open(bufferSource, fmWrite)
    buffer.writeLine(EmbeddedCode)
    buffer.write(validCode)
    buffer.flushFile()

proc showError(output: string) =
    # Determine whether last expression was to import a module
    var importStatement = false
    try:
        if currentExpression[0..6] == "import ":
            importStatement = true
    except IndexError:
        discard

    #### Runtime errors:
    if output.contains("Error: unhandled exception:"):
        stdout.setForegroundColor(fgRed, true)
        # Display only the relevant lines of the stack trace
        let lines = output.splitLines()

        if not importStatement:
            echo lines[^3]
        else:
            for line in lines[len(lines)-5 .. len(lines)-3]:
                echo line

        stdout.resetAttributes()
        stdout.flushFile()
        return

    #### Compilation errors:
    # Prints only relevant message without file and line number info.
    # e.g. "inim_1520787258.nim(2, 6) Error: undeclared identifier: 'foo'"
    # Becomes: "Error: undeclared identifier: 'foo'"
    let pos = output.find(")") + 2
    var message = output[pos..^1].strip

    # Discard shortcut conditions
    let
        a = currentExpression != ""
        b = importStatement == false
        c = previouslyIndented == false
        d = message.endsWith("discarded")

    # Discarded shortcut, print values: nim> myvar
    if a and b and c and d:
        # Following lines grabs the type from the discarded expression:
        # Remove text bloat to result into: e.g. foo'int
        message = message.multiReplace({
            "Error: expression '": "",
            " is of type '": "",
            "' and has to be discarded": ""
        })
        # Make split char to be a semicolon instead of a single-quote,
        # To avoid char type conflict having single-quotes
        message[message.rfind("'")] = ';' # last single-quote
        let message_seq = message.split(";") # expression;type, e.g 'a';char
        let typeExpression = message_seq[1]                 # type, e.g. char

        let shortcut = when defined(Windows):
            fmt"""
            stdout.write $({currentExpression})
            stdout.write "  : "
            stdout.write "{typeExpression}"
            echo ""
            """.unindent()
        else: # Posix: colorize type to yellow
            fmt"""
            stdout.write $({currentExpression})
            stdout.write "\e[33m" # Yellow
            stdout.write "  : "
            stdout.write "{typeExpression}"
            echo "\e[39m" # Reset color
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
        stdout.setForegroundColor(fgRed, true)
        echo if importStatement:
            output.strip() # Full message
        else:
            message # Shortened message
        stdout.resetAttributes()
        stdout.flushFile()
        previouslyIndented = false

proc init(preload = "") =
    setControlCHook(controlCHook)
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
        # Imports display more of the stack trace in case of errors, instead of one liners error
        currentExpression = "import " # Pretend it was an import for showError()
        showError(output)
        cleanExit(1)

proc getPromptSymbol(): string =
    if indentLevel == 0:
        result = "nim> "
        previouslyIndented = false
    else:
        result = ".... "
    # Auto-indent (multi-level)
    result &= IndentSpaces.repeat(indentLevel)

proc hasIndentTrigger*(line: string): bool =
    if line.len == 0:
        return
    for trigger in IndentTriggers:
        if line.strip().endsWith(trigger):
            result = true

proc doRepl() =
    # Read line
    try:
        currentExpression = readLineFromStdin(getPromptSymbol()).strip
    except IOError:
        bufferRestoreValidCode()
        indentLevel = 0
        tempIndentCode = ""
        return

    # Special commands
    if currentExpression in ["exit", "exit()", "quit", "quit()"]:
        cleanExit()

    # Empty line: exit indent level, otherwise do nothing
    if currentExpression == "":
        if indentLevel > 0:
            indentLevel -= 1
        elif indentLevel == 0:
            return

    # Write your line to buffer(temp) source code
    buffer.writeLine(IndentSpaces.repeat(indentLevel) & currentExpression)
    buffer.flushFile()

    # Check for indent and trigger it
    if currentExpression.hasIndentTrigger():
        indentLevel += 1
        previouslyIndented = true

    # Don't run yet if still on indent
    if indentLevel != 0:
        # Skip indent for first line
        let n = if currentExpression.hasIndentTrigger(): 1 else: 0
        tempIndentCode &= IndentSpaces.repeat(indentLevel-n) &
            currentExpression & "\n"
        return

    # Compile buffer
    let (output, status) = compileCode()

    # Succesful compilation, expression is valid
    if status == 0:
        compilationSuccess(currentExpression, output)
    # Maybe trying to echo value?
    elif "has to be discarded" in output and indentLevel == 0: #
        bufferRestoreValidCode()

        # Save the current expression as an echo
        currentExpression = fmt"echo $({currentExpression})"
        buffer.writeLine(currentExpression)
        buffer.flushFile()

        let (echo_output, echo_status) = compileCode()
        if echo_status == 0:
            compilationSuccess(currentExpression, echo_output)
        else:
            # Show any errors in echoing the statement
            indentLevel = 0
            showError(echo_output)
        # Roll back to not include the temporary echo line
        bufferRestoreValidCode()
    # Compilation error
    else:
        # Write back valid code to buffer
        bufferRestoreValidCode()
        indentLevel = 0
        showError(output)

    # Clean up
    tempIndentCode = ""

proc initApp*(nim, srcFile: string, showHeader: bool, flags = "") =
    ## Initialize the ``app` variable.
    app = App(
        nim: nim,
        srcFile: srcFile,
        showHeader: showHeader,
        flags: flags
    )

proc main(nim = "nim", srcFile = "", showHeader = true, flags: seq[string] = @[]) =
    ## inim interpreter

    initApp(nim, srcFile, showHeader)
    if flags.len > 0:
        app.flags = " -d:" & join(@flags, " -d:")

    if app.showHeader: welcomeScreen()

    if srcFile.len > 0:
        doAssert(srcFile.fileExists, "cannot access " & srcFile)
        doAssert(srcFile.splitFile.ext == ".nim")
        let fileData = getFileData(srcFile)
        init(fileData) # Preload code into init
    else:
        init() # Clean init
    
    while true:
        doRepl()

when isMainModule:
    import cligen
    dispatch(main, short = {"flags": 'd'}, help = {
            "nim": "path to nim compiler",
            "srcFile": "nim script to preload/run",
            "showHeader": "show program info startup",
            "flags": "nim flags to pass to the compiler"
        })
