##[
Nim gettext-like module
=====================================================

```License
  (c) Copyright 2024 shimoda
  (c) Copyright 2016 Parashurama

  See the file "LICENSE" (MIT)
```
]##
import options
import tables

import private/plural

when not defined(js):
  import encodings

else:
  import jsffi
  type
    EncodingConverter* = object
      discard


type
    StringEntry* {.pure final.} = object
        length*: uint32
        offset*: uint32

    TableEntry* {.pure final.} = object
        key*: StringEntry
        value*: string

    Catalogue* = ref object
        version*: uint32

        filepath*: string
        domain*: string
        charset*: string
        use_decoder*: bool
        decoder*: EncodingConverter
        plurals*: seq[State]
        plural_lookup*: Table[string, seq[string]]

        num_plurals*: int
        num_entries*: int
        key_cache*: string
        entries*: seq[TableEntry]

        when defined(js):
            loaded*: bool
            wasted*: bool
            lookup_db*: JsAssoc[cstring, JsObject]

const
    fallback_locale* = "C"
var
    CURRENT_LOCALE_var {.threadvar.}: Option[string]
    CURRENTS_LANGS_var {.threadvar.}: Option[seq[string]]


proc set_current_langs*(src = ""): seq[string] =
    ##[ - src == nil ... initialize a list
        - src == ""  ... get the list
        - src != ""  ... add to the list
    ]##
    if isNone(CURRENTS_LANGS_var) or src == "nil":
        var tmp: seq[string]
        CURRENTS_LANGS_var = some(tmp)

    if len(src) > 0:
        CURRENTS_LANGS_var.get().add(src)
    return CURRENTS_LANGS_var.get()


proc set_current_locale*(src = ""): string =
    if src != "":
        CURRENT_LOCALE_var = some(src)
    elif CURRENT_LOCALE_var.isNone():
        CURRENT_LOCALE_var = some(fallback_locale)
    return CURRENT_LOCALE_var.get()

