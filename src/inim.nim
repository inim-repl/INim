# MIT License
# Copyright (c) 2018 Andrei Regiani
import os, osproc, rdstdin, strutils, terminal, times

const
    INimVersion = "0.2.4"
    indentSpaces = "    "
    indentTriggers = [",", "=", ":", "var", "let", "const", "type", "import", 
                      "object", "enum"] # endsWith
    
let
    uniquePrefix = epochTime().int
    bufferSource = getTempDir() & "inim_" & $uniquePrefix & ".nim"
    compileCmd = "nim compile --run --verbosity=0 --hints=off --path=./ " & bufferSource

var
    currentOutputLine = 0 # Last line shown from buffer's stdout
    validCode = "" # All statements compiled succesfully
    tempIndentCode = "" # Later append to `validCode` if whole block compiles well
    indentLevel = 0 # Current
    buffer: File

proc getNimVersion*(): string =
    let (output, status) = execCmdEx("nim --version")
    if status != 0:
        echo "inim: Program \"nim\" not found in PATH"
        quit(1)
    result = output.splitLines()[0]

proc getNimPath(): string =
    var which_cmd = "which nim" # POSIX
    when defined(Windows):
        which_cmd = "where nim" # Windows
    let (output, status) = execCmdEx(which_cmd)
    if status == 0:
        return " at " & output
    return "\n"

proc welcomeScreen() =
    stdout.setForegroundColor(fgCyan)
    stdout.writeLine "INim ", INimVersion
    stdout.write getNimVersion()
    stdout.write getNimPath()
    stdout.resetAttributes()
    stdout.flushFile()

proc cleanExit() {.noconv.} =
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

proc showError(output: string) =
    ## 'Discarded' errors will be handled to print its value and type.
    ## Other errors print only relevant message without file and line number info.
    ## e.g. "inim_1520787258.nim(2, 6) Error: undeclared identifier: 'foo'"
    let pos = output.find(")") + 2
    # "Error: expression 'foo' is of type 'int' and has to be discarded"
    var message = output[pos..^1].strip

    # Discarded error: shortcut to print values: >>> foo
    if message.endsWith("discarded"):
        # Remove text until we can split by single-quote: foo'int
        message = message.replace("Error: expression '")
        message = message.replace(" is of type '")
        message = message.replace("' and has to be discarded")
        let message_seq = message.split("'")
        let symbol_identifier = message_seq[0]  # foo
        let symbol_type = message_seq[1]  # int
        let shortcut = "echo " & symbol_identifier & ", \" : " & symbol_type & "\""

        buffer.writeLine(shortcut)
        buffer.flushFile()

        let (output, status) = execCmdEx(compileCmd)
        if status == 0:
            let lines = output.splitLines()
            stdout.setForegroundColor(fgCyan, true)
            echo lines[^2]  # ^1 is empty line, ^2 is last stdout
            stdout.resetAttributes()
            stdout.flushFile()
            currentOutputLine = len(lines)-1
        else:
            stdout.setForegroundColor(fgRed, true)
            echo output.splitLines()[0]
            stdout.resetAttributes()
            stdout.flushFile()

    # Display all other errors
    else:
        stdout.setForegroundColor(fgRed, true)
        echo message
        stdout.resetAttributes()
        stdout.flushFile()

proc init(preload: string = nil) =
    setControlCHook(cleanExit)

    buffer = open(bufferSource, fmWrite)
    if preload == nil:
        # First dummy compilation so next one is faster
        discard execCmdEx(compileCmd)
        return

    buffer.writeLine(preload)
    buffer.flushFile()
    # Check preloaded file compiles succesfully
    let (output, status) = execCmdEx(compileCmd)
    if status == 0:
        for line in preload.splitLines:
            validCode &= line & "\n"
        echo output
        currentOutputLine = len(output.splitLines)-1
    # Compilation error
    else:
        showError(output)
        cleanExit()

proc getPromptSymbol(): string =
    if indentLevel == 0:
        result = ">>> "
    else:
        result =  "... "
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
        var myline: string
        try:
            myline = readLineFromStdin(getPromptSymbol()).strip
        except IOError:
            return

        # Special commands
        if myline in ["exit", "quit()"]:
            cleanExit()

        # Empty line: exit indent level, otherwise do nothing
        if myline == "":
            if indentLevel > 0:
                indentLevel -= 1
            elif indentLevel == 0:
                continue

        # Write your line to buffer(temp) source code
        buffer.writeLine(indentSpaces.repeat(indentLevel) & myline)
        buffer.flushFile()

        # Check for indent
        if myline.hasIndentTrigger():
            indentLevel += 1

        # Don't run yet if still on indent
        if indentLevel != 0:
            # Skip indent for first line
            if myline.hasIndentTrigger():
                tempIndentCode &= indentSpaces.repeat(indentLevel-1) & myline & "\n"
            else:
                tempIndentCode &= indentSpaces.repeat(indentLevel) & myline & "\n"
            continue

        # Compile buffer
        let (output, status) = execCmdEx(compileCmd)

        # Succesful compilation, expression is valid
        if status == 0:
            if len(tempIndentCode) > 0:
                validCode &= tempIndentCode
            else:
                validCode &= myline & "\n"
            let lines = output.splitLines
            # Print only output you haven't seen
            stdout.setForegroundColor(fgCyan, true)
            for line in lines[currentOutputLine..^1]:
                if line.strip != "":
                    echo line
            currentOutputLine = len(lines)-1
            stdout.resetAttributes()
            stdout.flushFile()

        # Compilation error
        else:
            # Write back valid code to buffer
            buffer.close()
            buffer = open(bufferSource, fmWrite)
            buffer.write(validCode)
            buffer.flushFile()
            showError(output)
            indentLevel = 0

        # Clean up
        tempIndentCode = ""

when isMainModule:
    # Preload existing source code: inim example.nim
    if paramCount() > 0:
        let filePath = paramStr(paramCount())
        if not filePath.fileExists:
            echo "inim: cannot access '", filePath, "': No such file"
            quit(1)
        if not filePath.endsWith(".nim"):
            echo "inim: '", filePath, "' is not a Nim file"
            quit(1)
        let fileData = getFileData(filePath)
        init(fileData)
    else:
        init() # Clean init

    welcomeScreen()
    runForever()
