# MIT License
# Copyright (c) 2018 Andrei Regiani

import os, osproc, rdstdin, strformat, strutils, terminal, times, strformat

type App = ref object
    nim: string
    srcFile: string
    showHeader: bool

var app:App

const
    INimVersion = "0.4.0"
    indentSpaces = "    "
    indentTriggers = [",", "=", ":", "var", "let", "const", "type", "import", 
                      "object", "enum"] # endsWith
    embeddedCode = staticRead("embedded.nim") # preloaded code into user's session
    
let
    uniquePrefix = epochTime().int
    bufferSource = getTempDir() & "inim_" & $uniquePrefix & ".nim"

proc compileCode():auto =
    # PENDING https://github.com/nim-lang/Nim/issues/8312, remove redundant `--hint[source]=off`
    let compileCmd = fmt"{app.nim} compile --run --verbosity=0 --hints=off --hint[source]=off --path=./ {bufferSource}"
    result = execCmdEx(compileCmd)

var
    currentExpression: string # Last stdin to evaluate
    currentOutputLine = 0 # Last line shown from buffer's stdout
    validCode = "" # All statements compiled succesfully
    tempIndentCode = "" # Later append to `validCode` if whole block compiles well
    indentLevel = 0 # Current
    previouslyIndented = false # Helper for showError(), indentLevel resets before showError()
    buffer: File

proc getNimVersion*(): string =
    let (output, status) = execCmdEx(fmt"{app.nim} --version")
    doAssert status == 0, fmt"make sure {app.nim} is in PATH"
    result = output.splitLines()[0]

proc getNimPath(): string =
    # TODO: use `which` PENDING https://github.com/nim-lang/Nim/issues/8311
    when defined(Windows):
        let which_cmd = fmt"where {app.nim}"
    else:
        let which_cmd = fmt"which {app.nim}"
    let (output, status) = execCmdEx(which_cmd)
    if status == 0:
        return " at " & output
    return "\n"

proc welcomeScreen() =
    stdout.setForegroundColor(fgYellow)
    stdout.writeLine "👑 INim ", INimVersion
    stdout.setForegroundColor(fgCyan)
    stdout.write getNimVersion()
    stdout.write getNimPath()
    stdout.resetAttributes()
    stdout.flushFile()

proc cleanExit() =
    buffer.close()
    removeFile(bufferSource) # Temp .nim
    removeFile(bufferSource[0..^5]) # Temp binary, same filename just without ".nim"
    removeDir(getTempDir() & "nimcache")
    quit(0)

proc getFileData(path: string): string =
    try:
        result = path.readFile()
    except:
        result = nil

proc compilationSuccess(current_statement, output: string) =
    if len(tempIndentCode) > 0:
        validCode &= tempIndentCode
    else:
        validCode &= current_statement & "\n"
    let lines = output.splitLines
    
    # Print only output you haven't seen
    stdout.setForegroundColor(fgCyan, true)
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
    buffer.writeLine(embeddedCode)
    buffer.write(validCode)
    buffer.flushFile()

proc showError(output: string) =
    # Runtime errors:
    if output.contains("Error: unhandled exception:"):
        stdout.setForegroundColor(fgRed, true)
        # Display only the relevant lines of the stack trace
        let lines = output.splitLines()
        for line in lines[len(lines)-5 .. len(lines)-3]:
            echo line
        stdout.resetAttributes()
        stdout.flushFile()
        return

    # Compilation errors:

    # Prints only relevant message without file and line number info.
    # e.g. "inim_1520787258.nim(2, 6) Error: undeclared identifier: 'foo'"
    # Becomes: "Error: undeclared identifier: 'foo'"
    let pos = output.find(")") + 2
    var message = output[pos..^1].strip

    # Discarded error: shortcut to print values: inim> myvar
    if previouslyIndented == false and message.endsWith("discarded"):
        # Following lines grabs the type from the discarded expression:
        # Remove text bloat to result into: e.g. foo'int
        message = message.replace("Error: expression '")
        message = message.replace(" is of type '")
        message = message.replace("' and has to be discarded")
        # Make split char to be a semicolon instead of a single-quote,
        # To avoid char type conflict having single-quotes
        message[message.rfind("'")] = ';' # last single-quote
        let message_seq = message.split(";") # expression;type, e.g 'a';char
        let typeExpression = message_seq[1] # type, e.g. char

        let shortcut = fmt"""
        stdout.write $({currentExpression})
        stdout.setForegroundColor(fgYellow)
        stdout.write "  : "
        stdout.write "{typeExpression}"
        stdout.resetAttributes()
        stdout.writeLine ""
        """.replace("        ", "")

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
        echo message
        stdout.resetAttributes()
        stdout.flushFile()
        previouslyIndented = false

proc init(preload: string = nil) =
    bufferRestoreValidCode()

    if preload == nil:
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
        showError(output)
        return

proc getPromptSymbol(): string =
    if indentLevel == 0:
        result = "nim> "
        previouslyIndented = false
    else:
        result =  ".... "
    # Auto-indent (multi-level)
    result &= indentSpaces.repeat(indentLevel)

proc hasIndentTrigger*(line: string): bool =
    if line.len > 0:
        for trigger in indentTriggers:
            if line.strip().endsWith(trigger):
                result = true

proc runForever() =
    while true:
        # Read line
        try:
            currentExpression = readLineFromStdin(getPromptSymbol()).strip
        except IOError:
            bufferRestoreValidCode()
            indentLevel = 0
            tempIndentCode = ""
            continue

        # Special commands
        if currentExpression in ["exit", "exit()", "quit", "quit()"]:
            cleanExit()

        # Empty line: exit indent level, otherwise do nothing
        if currentExpression == "":
            if indentLevel > 0:
                indentLevel -= 1
            elif indentLevel == 0:
                continue

        # Write your line to buffer(temp) source code
        buffer.writeLine(indentSpaces.repeat(indentLevel) & currentExpression)
        buffer.flushFile()

        # Check for indent and trigger it
        if currentExpression.hasIndentTrigger():
            indentLevel += 1
            previouslyIndented = true

        # Don't run yet if still on indent
        if indentLevel != 0:
            # Skip indent for first line
            if currentExpression.hasIndentTrigger():
                tempIndentCode &= indentSpaces.repeat(indentLevel-1) & currentExpression & "\n"
            else:
                tempIndentCode &= indentSpaces.repeat(indentLevel) & currentExpression & "\n"
            continue

        # Compile buffer
        let (output, status) = compileCode()

        # Succesful compilation, expression is valid
        if status == 0:
            compilationSuccess(currentExpression, output)

        # Compilation error
        else:
            # Write back valid code to buffer
            bufferRestoreValidCode()
            indentLevel = 0
            showError(output)

        # Clean up
        tempIndentCode = ""

proc main(nim = "nim", srcFile = "", showHeader = true) =
    ## inim interpreter
    app.new()
    app.nim=nim
    app.srcFile=srcFile
    app.showHeader=showHeader

    if app.showHeader: welcomeScreen()

    if srcFile.len > 0:
        doAssert(srcFile.fileExists, "cannot access " & srcFile)
        doAssert(srcFile.splitFile.ext == ".nim")
        let fileData = getFileData(srcFile)
        init(fileData) # Preload code
    else:
        init() # Clean init
    
    runForever()

when isMainModule:
    import cligen
    dispatch(main, help = {
            "nim": "path to nim compiler",
            "srcFile": "nim script to preload/run",
            "showHeader": "show program info startup",
        })
