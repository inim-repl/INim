## TODO: Split these up
## Maybe see if I can store a base state of the process before each tests runs and roll back after
import osproc, streams, os
import unittest

let testRcfilePath = getCurrentDir() / "inim.ini"

proc getResponse(inStream, outStream: var Stream, lines: seq[string] = @[]): string =
  ## Write all lines in `lines` to inStream and read the result
  for line in lines:
    inStream.writeLine(line)
  inStream.flush()
  outStream.readLine()

suite "Interface Tests":


  test "Test Standard Syntax works":
    var process = startProcess(
      "bin/inim",
      workingDir = "",
      args = @["--rcFilePath=" & testRcfilePath, "--showHeader=false"],
      options = {poDaemon}
    )

    var
      inputStream = process.inputStream
      outputStream = process.outputStream

    let defLines = @[
      """let a = "A"""",
      "a"
    ]
    require getResponse(inputStream, outputStream, defLines) == "A == type string"

    let typeLines = @[
      "type B = object",
      "  c: string", # Have to add indents in manually for tests now
      "",
      "B"
    ]
    require getResponse(inputStream, outputStream, typeLines) == "B == type B"
    # This could be improved
    require getResponse(inputStream, outputStream, @["B.c"]) == "string == type string"

    let varLines = @[
      """var g = B(c: "C")""",
      "g"
    ]
    require getResponse(inputStream, outputStream, varLines) == """(c: "C") == type B"""


    let ifLines = @[
      """if true:""",
      """  echo "TRUE"""",
      """else:""",
      """  echo "FALSE"""",
      """""",
    ]
    require getResponse(inputStream, outputStream, ifLines) == """TRUE"""

    inputStream.writeLine("quit")
    inputStream.flush()
    assert outputStream.atEnd()

    process.close()

  if existsFile(testRcfilePath):
    removeFile(testRcfilePath)
