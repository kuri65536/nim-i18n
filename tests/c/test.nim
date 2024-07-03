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
  proc wrap() {.gcsafe.} =
    setTextLocale()
  wrap()


test "setTextLocale - with arg":
  proc wrap() {.gcsafe.} =
    setTextLocale("fr_FR.UTF-8")
  wrap()


test "bindTextDomain - load with nil":
  proc wrap() {.gcsafe.} =
    setTextLocale("fr_FR.UTF-8")
    expect(ValueError):
        bindTextDomain("character_trits", "")
  wrap()


test "bindTextDomain - load 1":
  proc wrap() {.gcsafe.} =
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    setTextDomain("character_traits")
  wrap()


test "bindTextDomain - load 2":
  proc wrap() {.gcsafe.} =
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("meld", path2())
    setTextDomain("meld")
  wrap()


test "bindTextDomain - load double domains":
  proc wrap() {.gcsafe.} =
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("meld")
  wrap()


test "setTextDomain - move to the second domain":
  proc wrap() {.gcsafe.} =
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("character_traits")
    setTextDomain("meld")
  wrap()


test "tr - translate with a current domain":
  proc wrap() {.gcsafe.} =
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("character_traits")

    let ans = tr"brilliant_mind"
    check("esprit brillant" == ans)
    #cho("stormborn: ", tr"brilliant_mind")
  wrap()


test "dgettext - translate with an another domain":
  proc wrap() {.gcsafe.} =
    setTextLocale("fr_FR.UTF-8")
    bindTextDomain("character_traits", path1())
    bindTextDomain("meld", path2())
    setTextDomain("character_traits")

    let ans = dgettext("meld", "brilliant_mind")
    check("esprit m brillante" == ans)
    #cho("stormborn: ", dgettext("meld", "brilliant_mind"))
  wrap()


