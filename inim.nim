import os, osproc, strutils, terminal, times, typetraits

const
    INimVersion = "0.1"
    indentationSpaces = "    "
    bufferDefaultImports = "import typetraits"

let
    randomSuffix = epochTime().int
    bufferFilename = "inim_" & $randomSuffix
    bufferSource = bufferFilename & ".nim"
    compileCmd = "nim compile --run --verbosity=0 --hints=off " & bufferSource

var
    currentOutputLine = 0  # last shown buffer's stdout line
    validCode = ""  # buffer without exceptions
    indentationLevel = 0
    buffer: File

proc getNimVersion(): string =
    let (output, status) = execCmdEx("nim --version")
    if status != 0:
        echo "Nim compiler not found in your path"
        quit 1
    result = output.splitLines()[0]

proc getNimPath(): string =
    let (output, status) = execCmdEx("which nim")
    if status != 0:
        echo "Nim compiler not found in your path"
        quit 1
    result = output

proc welcomeScreen() =
    echo "INim ", INimVersion
    echo getNimVersion()
    echo getNimPath()

proc cleanExit() {.noconv.} =
    buffer.close()
    removeFile(bufferFilename)  # binary
    removeFile(bufferSource)  # source code
    quit 0

proc init() =
    setControlCHook(cleanExit)
    buffer = open(bufferSource, fmWrite)
    buffer.writeLine(bufferDefaultImports)
    discard execCmdEx(compileCmd)  # first dummy compilation so next is fast

proc echoInputSymbol() =
    stdout.setForegroundColor(fgCyan)
    if indentationLevel == 0:
        stdout.write(">>> ")
    else:
        stdout.write("... ")
    stdout.resetAttributes()
    # auto-indentation
    stdout.write(indentationSpaces.repeat(indentationLevel))

proc runForever() =
    while true:
        echoInputSymbol()
        var myline = readLine(stdin)
        # empty line, do nothing
        if myline.strip == "":
            if indentationLevel > 0:
                indentationLevel -= 1
            if indentationLevel == 0:
                buffer.write("\n")
                continue
        else:
            # check for indentation
            if strip(myline)[^1] in ['=', ':']:
                # is a multiline statement
                indentationLevel += 1
                continue
            if indentationLevel != 0:
                continue
            # shortcut to print value and type
            if len(myline.split) == 1:
                myline = "echo " & myline & ", " & "\" :\"" & ", " & myline & ".type.name"
        # write your line to buffer source code
        buffer.writeLine(indentationSpaces.repeat(indentationLevel) & myline)
        buffer.flushFile()
        # compile buffer
        let (output, status) = execCmdEx(compileCmd)
        # error happened in your single statement
        if status != 0:
            indentationLevel = 0
            echo output  # show error
            # write back valid code
            buffer.close()
            buffer = open(bufferSource, fmWrite)
            buffer.write(validCode)
            buffer.flushFile()
            continue
        # valid statement
        else:
            validCode &= myline & "\n"
            let lines = output.splitLines
            # print only output you haven't seen
            for line in lines[currentOutputLine..^1]:
                if line.strip != "":
                    echo line
            currentOutputLine = len(lines)-1

when isMainModule:
    init()
    welcomeScreen()
    runForever()