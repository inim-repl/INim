import inim

doAssert(getNimVersion()[0..2] == "Nim")

doAssert(triggerIndentation("var") == true)
doAssert(triggerIndentation("var x:int") == false)
doAssert(triggerIndentation("var x:int = 10") == false)
doAssert(triggerIndentation("let") == true)
doAssert(triggerIndentation("const") == true)
doAssert(triggerIndentation("if foo == 1: ") == true)
doAssert(triggerIndentation("proc fooBar(a, b: string): int = ") == true)
doAssert(triggerIndentation("for i in 0..10:") == true)
doAssert(triggerIndentation("for i in 0..10") == false)