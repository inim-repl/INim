import unittest

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
