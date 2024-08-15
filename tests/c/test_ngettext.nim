#
#  Nim gettext-like module
#  (c) Copyright 2024 shimoda
#  (c) Copyright 2016 Parashurama
#
#  See the file "LICENSE" (MIT)
#
import os

import ../../src/i18n


proc path1(): string =
    result = joinPath(getAppDir(), "../data/lang")
proc path2(): string =
    result = joinPath(getAppDir(), "../data/tools/gettext")


proc test_dngettext(): bool {.gcsafe.} =
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("character_traits")

    let ans = dngettext("meld", "%u hour", "%u hours", 2)
    let exp = "2 heurese"
    if exp != ans:
        echo(exp, "(exp) != (ans)", ans); return false
    #cho("meld: ", ans)
    return true


proc test_ngettext(): bool {.gcsafe.} =
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("character_traits")

    let ans = ngettext("%u hour", "%u hours", 2)
    let exp = "2 hueres"
    if exp != ans:
        echo(exp, "(exp) != (ans)", ans); return false
    #cho("meld: ", ngettext("%u hour", "%u hours", 2))
    return true



var f_ok = true
f_ok = test_dngettext() and f_ok
f_ok = test_ngettext() and f_ok
assert f_ok

