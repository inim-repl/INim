import os, osproc, strutils, terminal, times

const
    INimVersion = "0.1.0"
    indentationTriggers = ["=", ":", "var", "let", "const"]  # endsWith
    indentationSpaces = "    "
    bufferDefaultImports = "import typetraits"  # @TODO: shortcut to display type and value

let
    randomSuffix = epochTime().int
    bufferFilename = "inim_" & $randomSuffix
    bufferSource = bufferFilename & ".nim"
    compileCmd = "nim compile --run --verbosity=0 --hints=off " & bufferSource

var
    currentOutputLine = 0  # Last line shown from buffer's stdout
    validCode = ""  # All statements compiled succesfully
    tempIndentCode = ""  # Later append to `validCode` if whole block compiles well
    indentationLevel = 0  # Current
    buffer: File

proc getNimVersion(): string =
    let (output, status) = execCmdEx("nim --version")
    if status != 0:
        echo "inim: Program \"nim\" not found in PATH"
        quit(1)
    result = output.splitLines()[0]

proc getNimPath(): string =
    let (output, status) = execCmdEx("which nim")
    if status != 0:
        echo "inim: Program \"nim\" not found in PATH"
        quit(1)
    result = output

proc welcomeScreen() =
    stdout.writeLine "INim ", INimVersion
    stdout.writeLine getNimVersion()
    stdout.write getNimPath()

proc cleanExit() {.noconv.} =
    buffer.close()
    removeFile(bufferFilename)  # Binary
    removeFile(bufferSource)  # Source
    quit(0)

proc init() =
    setControlCHook(cleanExit)
    buffer = open(bufferSource, fmWrite)
    buffer.writeLine(bufferDefaultImports)
    discard execCmdEx(compileCmd)  # First dummy compilation so next one is faster

proc echoInputSymbol() =
    stdout.setForegroundColor(fgCyan)
    if indentationLevel == 0:
        stdout.write(">>> ")
    else:
        stdout.write("... ")
    stdout.resetAttributes()
    # Auto-indentation
    stdout.write(indentationSpaces.repeat(indentationLevel))

proc showError(output: string) =
    # Print only error message, without file and line number
    # e.g. "inim_1520787258.nim(2, 6) Error: undeclared identifier: 'foo'"
    # echo "Error: undeclared identifier: 'foo'"
    let pos = output.find(")") + 2
    echo output[pos..^1].strip

proc endsWithIndentation(line: string): bool =
    if line.len > 0:
        for trigger in indentationTriggers:
            if line.strip().endsWith(trigger):
                result = true

proc runForever() =
    while true:
        echoInputSymbol()
        var myline = readLine(stdin).strip

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
        if myline.endsWithIndentation:
            indentationLevel += 1

        # Don't run yet if still on indentation
        if indentationLevel != 0:
            # Skip indentation for first line
            if myline.endsWithIndentation:
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
            for line in lines[currentOutputLine..^1]:
                if line.strip != "":
                    echo line
            currentOutputLine = len(lines)-1

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
    init()
    welcomeScreen()
    runForever()
