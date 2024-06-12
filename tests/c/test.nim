#
#  Nim gettext-like module
#  (c) Copyright 2024 shimoda
#  (c) Copyright 2016 Parashurama
#
#  See the file "LICENSE" (MIT)
#
import os
import unittest

import ../../src/i18n


proc path1(): string =
    result = joinPath(getAppDir(), "../data/lang")
proc path2(): string =
    result = joinPath(getAppDir(), "../data/tools/gettext")


test "setTextLocale - no-args":
    setTextLocale()


test "setTextLocale - with arg":
    setTextLocale("fr_FR.UTF-8")


test "bindTextDomain - load with nil":
    setTextLocale("fr_FR.UTF-8")
    expect(ValueError):
        bindTextDomain("character_trits", "")


test "bindTextDomain - load 1":
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    setTextDomain("character_traits")


test "bindTextDomain - load 2":
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("meld", path2())
    setTextDomain("meld")


test "bindTextDomain - load double domains":
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("meld")


test "setTextDomain - move to the second domain":
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("character_traits")
    setTextDomain("meld")


test "tr - translate with a current domain":
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("character_traits")

    let ans = tr"brilliant_mind"
    check("esprit brillant" == ans)
    #cho("stormborn: ", tr"brilliant_mind")


test "dgettext - translate with an another domain":
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("character_traits")

    let ans = dgettext("meld", "brilliant_mind")
    check("esprit m brillante" == ans)
    #cho("stormborn: ", dgettext("meld", "brilliant_mind"))


