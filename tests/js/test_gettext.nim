discard """
    targets: "js"
"""
##[
```license

   Nim gettext-like module
   (c) Copyright 2024 shimoda
   (c) Copyright 2016 Parashurama

   See the file "LICENSE" (MIT)
```
]##
{.define: js.}
import ../../src/i18n


#[
const url1 = "http://localhost:8000/tests/data/lang"
const url2 = "http://localhost:8000/tests/data/tools/gettext"
]#


const data1 = """{"Language-Code": "fr",
                  "Domain": "character_traits",
                  "Plural-Forms": "nplurals=2; plural=n>1",
                  "lookup": {
                    "brilliant_mind": "esprit brillant",
                    "%u hour": ["un huere", "%u hueres"],
                    "dummy": 0
                  }, "dummy": 0}"""
const data2 = """{"Language-Code": "fr",
                  "Domain": "meld",
                  "Plural-Forms": "nplurals=2; plural=n>1",
                  "lookup": {
                    "brilliant_mind": "esprit m brillante",
                    "%u hour": ["%u huere", "%u huerese"],
                    "dummy": 0
                  }, "dummy": 0}"""




block:  ## "tr - translate with a current domain": {{{1
  proc wrap() {.gcsafe.} =
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", data1)
    bindTextDomain("meld", data2)
    setTextDomain("character_traits")

    let ans = tr"brilliant_mind"
    assert "esprit brillant" == $ans
    #cho("stormborn: ", tr"brilliant_mind")
  wrap()


block:  ## "dgettext - translate with an another domain": {{{1
  proc wrap() {.gcsafe.} =
    let ans = dgettext("meld", "brilliant_mind")
    assert "esprit m brillante" == $ans
    #cho("stormborn: ", dgettext("meld", "brilliant_mind"))
  wrap()


block:  ## "dngettext - translate with an another domain": {{{1
  proc wrap() {.gcsafe.} =
    let ans = ngettext("%u hour", "%u hours", 2)
    let exp = "2 huerese"
    if exp != ans:
        echo(exp, " != ", ans)
        assert exp == ans
  wrap()

