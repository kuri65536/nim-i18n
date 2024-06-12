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


var f_ok = true

block:  # "dngettext - ":
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("character_traits")

    let ans = dngettext("meld", "%u hour", "%u hours", 2)
    if "2 heurese" != ans:
        echo("2 heurese != " & ans)
        f_ok = false
    #cho("meld: ", ans)


block:  # "ngettext - ":
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("character_traits")

    let ans = ngettext("%u hour", "%u hours", 2)
    if "2 hueres" != ans:
        f_ok = false
        echo("2 hueres != " & ans)
    #cho("meld: ", ngettext("%u hour", "%u hours", 2))

assert f_ok

