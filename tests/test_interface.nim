import sugar, os, sequtils, strutils
import ansiparse
import utils
include inim

# Init
initApp("nim", "", false)
init()

let prompt = getPromptSymbol()
noiser.setPrompt(prompt)

# Read our test scenarios line by line
# We ignore tests with blank expected values, as these are usually var declarations
let testFilePath = "tests/stdin"

var expected: seq[string] = @[]
var counter = 0
# Run our input through the app like it was stdin
swapStdin:
  var previousOutput: string
  for line in readFile(testFilePath).splitLines:
    # Split our file by a ';' delimiter, where split[0] is the text to run
    # and split[1] is the expected output
    let
      splitVal = line.split(";")
    var testLine = splitVal[0]

    # Strip the line end. This helps with `Error:` messages
    testLine.stripLineEnd

    # Write our line to "stdin" and flush the content
    inStream.writeLine(testLine)
    inStream.flushFile()

    # Run a line of the repl
    doRepl()
    if splitVal.len > 1 and splitVal[1].len > 0:
      var
        outputLine = outStream.readLine()

      # Skip past UnusedImport errors, these are not important
      while outputLine.contains("UnusedImport"):
          outputLine = outStream.readLine()

      # Strip ANSI colouring from the string, making it comparable
      var parsedLine = parseAnsi(outputLine).filter(it => it.kind == String)

      # If we have a value, test it
      if parsedLine.len > 0:
        previousOutput = parsedLine[0].str
        try:
          stderr.writeLine("Checking " & splitVal[1] & " == " & parsedLine[0].str & " for input \"" & testLine & "\"")
          stderr.flushFile
          doAssert splitVal[1] == parsedLine[0].str
        except AssertionError:
          # If we do hit an error, write out our stdout
          outStream.setFilePos(0)
          stderr.write(outStream.readAll())
          raise
        counter.inc
echo "Ran checks on " & $counter & " scenarios"
