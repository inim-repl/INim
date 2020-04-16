when defined(posix):
  import posix

  template swapStdin*(body: untyped) =
    ## Swap stdout & stdin to temporary files and open proxy files to read/write to stdin
    ## injects:
    ##   inStream: file stdin is reading from with write access
    ##   outStream: file stdout is writing to with read access
    let
      old_stdin = dup(STDIN_FILENO.cint)
      old_stdout = dup(STDOUT_FILENO.cint)
      inFileName = "tests/test_stdin"
      outFileName = "tests/test_stdout"

    # Inject our filesso we can access them in `body`
    var
      inStream {.inject.} = open(inFileName, fmReadWrite)
      outStream {.inject.} = open(outFileName, fmReadWrite)

    # Remap stdin to `inFileName` and stdout to `outFileName`
    discard dup2(inStream.getFileHandle, STDIN_FILENO)
    discard dup2(outStream.getFileHandle, STDOUT_FILENO)

    # Close unecessary files
    inStream.close()
    outStream.close()

    inStream = open(inFileName, fmWrite)
    outStream = open(outFileName, fmRead)

    # Execute our code
    body

    outStream.close()
    inStream.close()
    # Restore stdin/stdout
    discard dup2(old_stdin, STDIN_FILENO)
    discard dup2(old_stdout, STDOUT_FILENO)

    # Clean up
    discard old_stdin.close()
    discard old_stdout.close()
    removeFile(inFileName)
    removeFile(outFileName)

else:
  echo "TODO: Windows tests sorry"
  quit(1)
