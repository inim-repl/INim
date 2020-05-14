import osproc, streams, os
import unittest

proc getResponse(inStream, outStream: var Stream, lines: seq[string] = @[]): string =
  for line in lines:
    inStream.writeLine(line)
  inStream.flush()
  outStream.readLine()

suite "Interface Tests":

  test "Test Output":
    var process = startProcess(
      "bin/inim",
      workingDir = "",
      args = @["--rcFilePath=" & getCurrentDir() / "inim.ini", "--showHeader=false"],
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

    inputStream.writeLine("quit")
    inputStream.flush()
    assert outputStream.atEnd()

    process.close()
