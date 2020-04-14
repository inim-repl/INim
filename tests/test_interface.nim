import terminal, posix, streams
import inim

let
  old_stdin = stdin.getFileHandle
  old_stdout = stdout.getFileHandle

stdin.close()
stdout.close()


var testInStream = open("tests/stdin", fmWrite)
testInStream.write("""let a = "A"\na""")
testInStream.close()
testInStream = open("tests/stdin", fmRead)

var testOutStream = open("tests/stdout", fmWrite)

dup2(stdin.getFilehandle, testInStream.getFileHandle)
dup2(stdout.getFilehandle, testOutStream.getFileHandle)


dup2(old_stdin, stdin.getFileHandle)
dup2(old_stdout, stdout.getFilehandle)
