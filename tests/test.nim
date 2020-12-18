import unittest, osproc, strutils

import inim

suite "INim Test Suite":

  setup:
    initApp("nim", "", true)

  teardown:
    discard

  test "Get Nim Version":
    check:
      getNimVersion()[0..2] == "Nim"

  test "Indent triggers":
    check:
      hasIndentTrigger("var") == true
      hasIndentTrigger("var x:int") == false
      hasIndentTrigger("var x:int = 10") == false
      hasIndentTrigger("let") == true
      hasIndentTrigger("const") == true
      hasIndentTrigger("if foo == 1: ") == true
      hasIndentTrigger("proc fooBar(a, b: string): int = ") == true
      hasIndentTrigger("for i in 0..10:") == true
      hasIndentTrigger("for i in 0..10") == false
      hasIndentTrigger("import os, osproc,") == true
      hasIndentTrigger("import os, osproc, ") == true
      hasIndentTrigger("type") == true
      hasIndentTrigger("CallbackAction* = enum ") == true
      hasIndentTrigger("Response* = ref object ") == true
      hasIndentTrigger("var s = \"\"\"") == true

  test "Executes piped code from file":
    check execCmdEx("cat tests/test_piping_file.nim | bin/inim").output.strip() == """4
@[1, 5, 4]"""

  test "Executes piped code from echo":
    check execCmdEx("echo \"2+2\" | bin/inim").output.strip() == "4"

  test "Executes piped code with echo at end of block":
    check execCmdEx("cat tests/test_piping_with_end_echo.nim | bin/inim").output.strip() == """TestVar"""

  test "Verify flags with '--' prefix work":
    check execCmdEx("""echo 'import threadpool; echo "SUCCESS"' | bin/inim --flag=--threads:on""").output.strip() == "SUCCESS"

