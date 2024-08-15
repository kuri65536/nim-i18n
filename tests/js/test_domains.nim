discard """
    targets: "js"
"""
import ../../src/i18n

## "setTextLocale - no-args":
setTextLocale()

## "setTextLocale - with arg":
setTextLocale("fr_FR.UTF-8")

## "bindTextDomain - load with nil":
try:
    bindTextDomain("character_trits", "")
except ValueError:
    assert true

## "bindTextDomain - load":
const url1 = "http://127.0.0.1:8123/character_traits.json?lang=fr"

bindTextDomain("character_traits", url1)
setTextDomain("character_traits")
setTextDomain("character_traits")

## "bindTextDomain - load":
const url2 = "http://127.0.0.1:8123/meld.json?lang=fr"

## "bindTextDomain - load double domains":
bindTextDomain("meld", url2)
setTextDomain("meld")


## translation
var f_error = block:
  proc wrap(): bool {.gcsafe.} =
    let ans = tr"brilliant_mind"
    #const exp = "esprit brillant"
    const exp = "esprit m brillante"
    if exp != $ans:
        echo(exp, "(exp) != (ans)", ans); return true
  wrap()

assert not f_error

