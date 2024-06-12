discard """
    targets: "js"
"""
import i18n

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
const url1 = "http://localhost:8000/tests/data/lang"

bindTextDomain("character_traits", url1)
setTextDomain("character_traits")
assert true

const url2 = "http://localhost:8000/tests/data/tools/gettext"

# "bindTextDomain - load double domains":
bindTextDomain("meld", url2)
setTextDomain("meld")
assert true

