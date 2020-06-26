## TODO: Split these up
## Maybe see if I can store a base state of the process before each tests runs and roll back after
import osproc, streams, os
import unittest

let
  testRcfilePath = getCurrentDir() / "inim.ini"
  testDirName = absolutePath("tests/test_dir")

proc getResponse(inStream, outStream: var Stream, lines: seq[string] = @[]): string =
  ## Write all lines in `lines` to inStream and read the result
  for line in lines:
    inStream.writeLine(line)
  inStream.flush()
  outStream.readLine()

suite "Interface Tests":

  setup:
    # Start our process and create links to our stdin/stdout
    var process = startProcess(
      "bin/inim",
      workingDir = "",
      args = @["--rcFilePath=" & testRcfilePath, "--showHeader=false", "--withTools"],
      options = {poDaemon}
    )

    var
      inputStream = process.inputStream
      outputStream = process.outputStream

  teardown:
    # Clean up after the process quits
    inputStream.writeLine("quit")
    inputStream.flush()
    process.close()


  test "Test Standard Syntax works":
    let defLines = @[
      """let a = "A"""",
      "a"
    ]
    require getResponse(inputStream, outputStream, defLines) == "A == type string"

    let typeLines = @[
      "type B = object",
      "c: string",
      "",
      "B"
    ]
    require getResponse(inputStream, outputStream, typeLines) == "B == type B"
    require getResponse(inputStream, outputStream, @["B.c"]) == "string == type string"

    let varLines = @[
      """var g = B(c: "C")""",
      "g"
    ]
    require getResponse(inputStream, outputStream, varLines) == """(c: "C") == type B"""

    # Make sure we're not creating more errors when we type in code that wouldn't compile normally
    let jankLines = @[
      """proc adderNoReturnNoType(a: float, b: float) = a + b""",
    ]
    require getResponse(inputStream, outputStream, jankLines) == """Error: expression 'a + b' is of type 'float' and has to be discarded"""

    inputStream.writeLine("quit")
    inputStream.flush()
    assert outputStream.atEnd()

  test "Test commands":
    # Test cd
    let chdirLines = @[
      """cd "tests/test_dir"""",
    ]
    require getResponse(inputStream, outputStream, chdirLines) == testDirName & " == type string"

    # Test ls
    let lsLines = @[
      """ls()""",
    ]
    require getResponse(inputStream, outputStream, lsLines) == """@["a1", "a2"] == type seq[string]"""

    # Test pwd
    let pwdLines = @[
      """pwd()""",
    ]
    require getResponse(inputStream, outputStream, pwdLines) == testDirName & " == type string"

    let callLines = @[
      """call "echo A"""",
    ]
    require getResponse(inputStream, outputStream, callLines) == "A"

  # Finally, delete our RCfile path
  if existsFile(testRcfilePath):
    removeFile(testRcfilePath)
