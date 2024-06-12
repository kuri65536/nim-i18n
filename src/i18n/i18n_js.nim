##[
Nim gettext-like module javascript backend
=====================================================

```License
  (c) Copyright 2024, 2019 shimoda

  See the file "LICENSE" (MIT)
```
]##
when not defined(js) and not defined(nimsuggest):
  {.fatal: "Module i18n_js is to be used with the JavaScript backend.".}


import jsffi
import tables


type
  StringEntry* {.pure final.} = object
    length*: uint32
    offset*: uint32

  TableEntry* {.pure final.} = object
    key*: StringEntry
    value*: string

  CallInfo = tuple[filename: string, line: int, column: int]

  EncodingConverter* = object
    discard

  State* = object
    discard

  Catalogue* = ref object
    filepath*: cstring
    lookup_db*: JsAssoc[cstring, seq[cstring]]
    domain*: cstring
    charset: cstring
    use_decoder: bool

    plural_lookup*: Table[string, seq[string]]
    key_cache*: string
    entries*: seq[TableEntry]


proc hasOwnProperty(x: JsAssoc, prop: cstring): bool
    {. importcpp: "#.hasOwnProperty(#)" .}

proc json_parse(x: cstring): JsObject
    {. importcpp: "JSON.parse(#)" .}

proc parseExpr*(x: string): int =
    result = 0


let
    DEFAULT_NULL_CATALOGUE* = Catalogue(
        key_cache:"", domain:"default",
        # plural_lookup: [("",@[""])].toTable
        )
var
    db = newJsAssoc[cstring, Catalogue]()
    CURRENT_CATALOGUE* = DEFAULT_NULL_CATALOGUE
    CATALOGUE_REFS* = initTable[string, Catalogue]()
    DOMAIN_REFS = initTable[string, string]()


template getCurrentEncodingEx*(): untyped =
    "ascii"


template debug(msg: untyped, i: CallInfo): untyped =
    when not defined(release):
        {.emit: "console.debug(`i` + `msg`);".}


proc lookup*(self: Catalogue; key: string): string =
    return $self.lookup_db[key]


proc newCatalogue*(json: cstring) : Catalogue =
    new(result)
    try:
        var data = json_parse(json)
        result.lookup_db = data.to(JsAssoc[cstring, seq[cstring]])
        result.charset = data[""]["Language-Code"].to(cstring)
        result.domain = data[""]["Domain"].to(cstring)
        discard jsDelete(result.lookup_db[""])
    except:
        return result
    # TODO(shimoda): result.filepath = $(path)


proc is_valid*(self: Catalogue): bool =  # {{{1
    if self.lookup_db != nil:
        return true
    return false


proc find_catalogue(localedir, domain: string; locales: seq[string]): string =
    result = ""


proc set_text_domain_impl(domain: string; info: CallInfo) : Catalogue =
    if result == nil:
        result = DEFAULT_NULL_CATALOGUE


proc get_locale_properties*(): (string, string) =
    result = ("C", "ascii")

 
proc decode_impl*(catalogue: Catalogue; translation: string): string {.inline.}=
    shallowCopy result, translation


proc dngettext_impl*(catalogue: Catalogue,
                     msgid, msgid_plural: string, num: int,
                     info: CallInfo): string =
    ""


proc bindTextDomain*(data: cstring) =
    var cat = newCatalogue(data)
    if not cat.is_valid():
        cat.lookup_db = nil
        return
    var key: cstring = cat.domain & "-" & cat.charset
    if db.hasOwnProperty(key):
        discard
        # debug("override ", instantiationInfo())
    db[key] = cat
    debug("registered " & $key, instantiationInfo())


proc bindTextDomain*(domain: string; dir_path: string) =
    if domain.len == 0:
        raise newException(ValueError, "Domain name has zero length.")


# ECMA Specific
proc toLocalString*(n: int, unit: cstring
                    ): string {.importcpp: "(@).toLocalString(#)".}


