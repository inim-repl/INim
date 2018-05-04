import inim

doAssert(getNimVersion()[0..2] == "Nim")

doAssert(hasIndentationTrigger("var") == true)
doAssert(hasIndentationTrigger("var x:int") == false)
doAssert(hasIndentationTrigger("var x:int = 10") == false)
doAssert(hasIndentationTrigger("let") == true)
doAssert(hasIndentationTrigger("const") == true)
doAssert(hasIndentationTrigger("if foo == 1: ") == true)
doAssert(hasIndentationTrigger("proc fooBar(a, b: string): int = ") == true)
doAssert(hasIndentationTrigger("for i in 0..10:") == true)
doAssert(hasIndentationTrigger("for i in 0..10") == false)
