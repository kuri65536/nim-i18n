discard """
    targets: "js"
"""
import ../../src/i18n

# "setTextLocale - no-args":
setTextLocale()
assert true

# "setTextLocale - with arg":
setTextLocale("fr_FR.UTF-8")
assert true

# "bindTextDomain - load with nil":
try:
    bindTextDomain("character_trits", "")
except ValueError:
    assert true

# "bindTextDomain - load":
const url1 = "http://127.0.0.1:8123/character_traits.json?lang=fr"

bindTextDomain("character_traits", url1)
setTextDomain("character_traits")
setTextDomain("character_traits")
assert true

# "bindTextDomain - load":
const url2 = "http://127.0.0.1:8123/meld.json?lang=fr"

# "bindTextDomain - load double domains":
bindTextDomain("meld", url2)
setTextDomain("meld")
assert true


block:
  proc wrap() {.gcsafe.} =
    let ans = tr"brilliant_mind"
    #const exp = "esprit brillant"
    const exp = "esprit m brillante"
    if exp != $ans:
        echo(exp & "(exp) != (ans)" & $ans)
        assert false
  wrap()


