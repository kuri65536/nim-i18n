discard """
    targets: "js"
"""
##[
```license

   Nim gettext-like module
   (c) Copyright 2024 shimoda

   See the file "LICENSE" (MIT)
```
]##
{.define: js.}
import strutils

import ../../src/i18n/i18n_js
import ../../src/i18n/private/plural

const data1 = """{"Language-Code": "fr",
              "Domain": "character_traits",
              "Plural-Forms": "test",
              "lookup": {
                "brilliant_mind": "esprit brillant",
                "%u hour": ["un huere", "%u hueres"],
                "dummy": 0
              }, "dummy": 0}"""

var f_error = block:  ## {{{1
  proc wrap(): bool {.gcsafe.} =
    let src = data1.replace("test", "nplurals=2; plural=n>1")
    let cat = newCatalogue(cstring(src), "")
    assert cat.num_plurals == 2
    assert cat.plurals.evaluate(1) == 0
    assert cat.plurals.evaluate(2) == 1
    assert cat.plurals.evaluate(3) == 1
    assert cat.plurals.evaluate(4) == 1
    assert cat.plurals.evaluate(100) == 1
  wrap()

assert not f_error

