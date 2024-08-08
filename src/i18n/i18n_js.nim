##[
Nim gettext-like module javascript backend
=====================================================

```License
  (c) Copyright 2024, 2019 shimoda

  See the file "LICENSE" (MIT)
```
]##
#[
when not defined(js) and not defined(nimsuggest):
  {.fatal: "Module i18n_js is to be used with the JavaScript backend.".}
]#
import jsconsole
import jsffi

import tables
import strutils

import i18n_header


type
  CallInfo = tuple[filename: string, line: int, column: int]


proc hasOwnProperty(x: JsAssoc, prop: cstring): bool
    {. importcpp: "#.hasOwnProperty(#)" .}

proc json_parse(x: cstring): JsObject
    {. importcpp: "JSON.parse(#)" .}

proc parseExpr*(x: string): int =
    result = 0


var
    catalogue_current {.threadvar.}: Catalogue
    catalogue_null {.threadvar.}: Catalogue
    db_var {.threadvar.}: JsAssoc[cstring, Catalogue]


proc get_null_catalogue(): Catalogue =
    if isNil(catalogue_null):
        catalogue_null = Catalogue(
            key_cache:"", domain:"default",
            # plural_lookup: [("",@[""])].toTable
        )
    return catalogue_null


proc set_current_catalogue_js*(src: Catalogue): Catalogue =
    if not isNil(src):
        catalogue_current = src
    elif isNil(catalogue_current):
        catalogue_current = get_null_catalogue()
    return catalogue_current


proc get_db(): JsAssoc[cstring, Catalogue] =
    if isNil(db_var):
        db_var = newJsAssoc[cstring, Catalogue]()
    return db_var


template getCurrentEncodingEx*(): untyped =
    "ascii"


template debug(msg: untyped, info: CallInfo): untyped =
    when not defined(release):
        let filepos {.gensym.} = cstring(info[0] & "(" & $info[1] & ") ")
        {.gcsafe.}:
            console.debug(filepos, msg)


proc equal*(self: tuple[length, offset: int],
            other: string; cache: string): bool =
    let offset = self.offset.int
    for i in 0..<self.length.int:
        if cache[offset + i] != other[i]:
            return false
    return true


proc lookup*(self: Catalogue; key: string): string =
    return $self.lookup_db[key]


proc parse_json(self: var Catalogue, json: cstring): bool =
    let data = try:
            echo("parse_json-parse   : ", json)
            var tmp: JsObject
            {.emit: "`tmp` = JSON.parse(`json`);".}
            tmp
        except JsSyntaxError:
            echo("parse_json-expected: ", json)
            return true
    for i in ["Language-Code", "Domain",
              "Plural-Forms",
              "lookup",
              ]:
        let j = cstring(i)
        if not data.hasOwnProperty(j):
            debug(cstring("`" & i & "` not defined in json"), instantiationInfo())
            return true
    self.charset = $data["Language-Code"].to(cstring)
    self.domain = $data["Domain"].to(cstring)
    self.lookup_db = data["lookup"].to(JsAssoc[cstring, JsObject])
    self.loaded = true


proc newCatalogue*(json: cstring, url = "") : Catalogue =
    new(result)
    if result.parse_json(json):
        return nil
    result.filepath = url


proc is_valid*(self: Catalogue): bool =  # {{{1
    if self.lookup_db != nil:
        return true
    return false


proc find_catalogue(localedir, domain: string; locales: seq[string]): string =
    result = ""


proc set_text_domain_impl*(domain: string; info: CallInfo) : Catalogue =
    if result == nil:
        result = DEFAULT_NULL_CATALOGUE


proc get_locale_properties*(): (string, string) =
    result = ("C", "ascii")


proc decode_impl*(catalogue: Catalogue; translation: string
                  ): string {.inline.}=
  when NimMajor > 1:
    result = translation
  else:
    shallowCopy result, translation


proc dgettext_impl*(catalogue: Catalogue;
                    msgid: string;
                    info: CallInfo): string {.inline.} =
    result = catalogue.lookup(msgid)
    if result == msgid:
        debug(cstring("Warning: translation not found! : '" & msgid &
              "' in domain '" & catalogue.domain & "'"), info)
        result = catalogue.decode_impl(msgid)


proc dngettext_impl*(catalogue: Catalogue,
                     msgid, msgid_plural: string, num: int,
                     info: CallInfo): string =
    ""


proc bindTextDomain*(data: cstring) =
    ##[parse a domain data from the JSON string.
    ]##
    var cat = newCatalogue(data)
    if isNil(cat):
        debug("can't parse json:" & data, instantiationInfo())
        return
    if not cat.is_valid():
        cat.lookup_db = nil
        return
    let key = cstring(cat.domain & "-" & cat.charset)
    let db = get_db()
    if db.hasOwnProperty(key):
        debug("override ", instantiationInfo())
    db[key] = cat
    debug(cstring("registered " & $key), instantiationInfo())


proc bindTextDomain*(domain: string; dir_path: string): void {.gcsafe.} =
    ##[load or parse the domain data.
    ]##
    if domain.len == 0:
        raise newException(ValueError, "Domain name has zero length.")
    if dir_path.len < 1:
        raise newException(ValueError, "path or datga has zero length.")

    proc starts_with(a, b: string): bool =
        if len(a) < len(b):         return false
        if a[0 .. len(b) - 1] != b: return false
        return true

    echo("bindTextDomain:", dir_path)
    if   starts_with(dir_path, "http:"):
        catalogue_from_url(domain, dir_path)
    elif starts_with(dir_path, "https:"):
        catalogue_from_url(domain, dir_path)
    else:
        bindTextDomain(cstring(dir_path))


# ECMA Specific
proc toLocalString*(n: int, unit: cstring
                    ): string {.importcpp: "(@).toLocalString(#)".}


