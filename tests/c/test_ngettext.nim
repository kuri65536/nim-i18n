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


block:  # "dngettext - ":
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("character_traits")

    let ans = dngettext("meld", "%u hour", "%u hours", 2)
    assert "2 heures" == ans
    #cho("meld: ", ans)


block:  # "ngettext - ":
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("meld")

    let ans = ngettext("%u hour", "%u hours", 2)
    assert "2 heures" == ans
    #cho("meld: ", ngettext("%u hour", "%u hours", 2))


