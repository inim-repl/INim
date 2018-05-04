import os, osproc, rdstdin, strutils, terminal, times

const
    INimVersion = "0.2.2"
    indentationTriggers = ["=", ":", "var", "let", "const", "import"]  # endsWith
    indentationSpaces = "    "
    bufferDefaultImports = "import typetraits"  # @TODO: shortcut to display type and value

let
    uniquePrefix = epochTime().int
    bufferSource = getTempDir() & "inim_" & $uniquePrefix & ".nim"
    compileCmd = "nim compile --run --verbosity=0 --hints=off --path=./ " & bufferSource

var
    currentOutputLine = 0  # Last line shown from buffer's stdout
    validCode = ""  # All statements compiled succesfully
    tempIndentCode = ""  # Later append to `validCode` if whole block compiles well
    indentationLevel = 0  # Current
    buffer: File

proc getNimVersion*(): string =
    let (output, status) = execCmdEx("nim --version")
    if status != 0:
        echo "inim: Program \"nim\" not found in PATH"
        quit(1)
    result = output.splitLines()[0]

proc getNimPath(): string =
    var which_cmd = "which nim"  # POSIX
    when defined(Windows):
        which_cmd = "where nim"  # Windows
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
    removeFile(bufferSource)  # Temp .nim
    removeFile(bufferSource[0..^5])  # Temp binary, same filename just without ".nim"
    removeDir(getTempDir() & "nimcache")
    quit(0)

proc getFileData(path: string): string =
    try:
        result = path.readFile()
    except:
        result = nil

proc showError(output: string) =
    # Print only error message, without file and line number
    # e.g. "inim_1520787258.nim(2, 6) Error: undeclared identifier: 'foo'"
    # echo "Error: undeclared identifier: 'foo'"
    stdout.setForegroundColor(fgRed, true)
    let pos = output.find(")") + 2
    echo output[pos..^1].strip
    stdout.resetAttributes()
    stdout.flushFile()

proc init(preload: string = nil) =
    setControlCHook(cleanExit)

    buffer = open(bufferSource, fmWrite)
    buffer.writeLine(bufferDefaultImports)
    if preload == nil:
        discard execCmdEx(compileCmd)  # First dummy compilation so next one is faster
        return

    buffer.writeLine(preload)
    buffer.flushFile()
    let (output, status) = execCmdEx(compileCmd)  # Check preloaded file compiles succesfully
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
    if indentationLevel == 0:
        result = ">>> "
    else:
        result =  "... "
    # Auto-indentation (multi-level)
    result &= indentationSpaces.repeat(indentationLevel)

proc hasIndentationTrigger*(line: string): bool =
    if line.len > 0:
        for trigger in indentationTriggers:
            if line.strip().endsWith(trigger):
                result = true

proc runForever() =
    while true:
        let myline = readLineFromStdin(getPromptSymbol()).strip

        # Special commands
        if myline in ["exit", "quit()"]:
            cleanExit()

        # Empty line: leave indentation level otherwise do nothing
        if myline == "":
            if indentationLevel > 0:
                indentationLevel -= 1
            elif indentationLevel == 0:
                continue

        # Write your line to buffer(temp) source code
        buffer.writeLine(indentationSpaces.repeat(indentationLevel) & myline)
        buffer.flushFile()

        # Check for indentation
        if myline.hasIndentationTrigger():
            indentationLevel += 1

        # Don't run yet if still on indentation
        if indentationLevel != 0:
            # Skip indentation for first line
            if myline.hasIndentationTrigger():
                tempIndentCode &= indentationSpaces.repeat(indentationLevel-1) & myline & "\n"
            else:
                tempIndentCode &= indentationSpaces.repeat(indentationLevel) & myline & "\n"
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
            indentationLevel = 0
            showError(output)
            # Write back valid code to buffer
            buffer.close()
            buffer = open(bufferSource, fmWrite)
            buffer.writeLine(bufferDefaultImports)
            buffer.write(validCode)
            buffer.flushFile()

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
        init()  # Clean init

    welcomeScreen()
    runForever()
