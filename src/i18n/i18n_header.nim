##[
Nim gettext-like module
=====================================================

```License
  (c) Copyright 2024 shimoda
  (c) Copyright 2016 Parashurama

  See the file "LICENSE" (MIT)
```
]##
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
            lookup_db*: JsAssoc[cstring, JsObject]

