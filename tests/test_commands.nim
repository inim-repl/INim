import os, strutils
import unittest
import ../src/inimpkg/commands

let
  testDirName = absolutePath("tests/test_dir")
  testDir = getCurrentDir()

suite "Commands Tests":

  setup:
    setCurrentDir(testDir)

  test "Test ls command with args":
    require ls("tests/test_dir") == @["a1", "a2"]

  test "Test ls command with no args":
    setCurrentDir("tests/test_dir")
    require ls() == @["a1", "a2"]

  test "Test cd command with no args defaults to home dir":
    discard cd()
    require getCurrentDir() == getHomeDir().strip(leading = false, chars = {DirSep})

  test "Test cd command with args sets new dir":
    require cd("tests/test_dir") == testDirName

  test "Test pwd returns current dir":
    setCurrentDir("tests/test_dir")
    require pwd() == testDirName
