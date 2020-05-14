import osproc, streams, os
import unittest

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

    inputStream.writeLine("1 + 1")
    inputStream.flush()
    var fresult = outputStream.readLine()
    require fresult == "2 == type int"

    inputStream.writeLine("""let a = "A"""")
    inputStream.writeLine("a")
    inputStream.flush()
    fresult = outputStream.readLine()
    require fresult == "A == type string"

    inputStream.writeLine("quit")
    inputStream.flush()
    assert outputStream.atEnd()

    process.close()
