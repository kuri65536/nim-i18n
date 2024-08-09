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
import jscore
import jsffi
import strutils

import i18n_header


type
  CallInfo = tuple[filename: string, line: int, column: int]


proc hasOwnProperty(x: JsAssoc, prop: cstring): bool
    {. importcpp: "#.hasOwnProperty(#)" .}


proc load_from_url(url: cstring, cb_succeed: proc(src: cstring): void,
                                 cb_failed: proc(): void) =
    ##[for synchronus contents loading,
        this function use old `XMLHttpRequest`.
        therefore `fetch` can't be used.

        need to progress async prcedure to load and use tables.
    ]##
    {.emit: """if (typeof process === "object") {
                    var XMLHttpRequest = require("xmlhttprequest").XMLHttpRequest;
                    req = new XMLHttpRequest();
               } else {
                    req = new XMLHttpRequest();
               }
               req.open("GET", `url`, false);
               req.onreadystatechange = () => {
                    if (req.readyState != 4) {
                         ;
                    } else if (Math.floor(`req`.status / 100) == 2) {
                        `cb_succeed`(req.responseText);
                    } else {
                        `cb_failed`();
                    }
                };
                req.send();
                console.log(req);
            """.}
    ## - above, can't be used now by javascript's single thread...
    #[
    {.emit: """var prm1 = fetch(`url`);
               console.log("fetch(js):" + `url`);
               prm1.then((response) => {
                    var prm2 = response.text();
                    console.log(prm2);
                    prm2.then((src) => {
                        console.log("fetch-cb(js):" + src);
                        `cb_succeed`(src);
                    }, () => {
                        `cb_failed`();
                    });
               }, () => {
                    console.log("fetch-fl(js):" + `url`);
                    `cb_failed`();
               });
    """.}
    ]#


proc wait_for_load(self: Catalogue): bool =
    if self.wasted:
        return true
    return not self.loaded


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
    "UTF-8"


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
    if not self.loaded:
        echo("lookup-waiting...")
        if wait_for_load(self):
            echo("lookup-waiting-timeout or wasted")
            return key
    let tmp = cstring(key)
    if isNil(self.lookup_db):
        return key
    if not self.lookup_db.hasOwnProperty(tmp):
        return key
    let ret = self.lookup_db[tmp]
    if jsTypeOf(ret) == cstring("string"):
        return $ret.to(cstring)
    return $ret[0].to(cstring)


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


proc find_catalogue(domain: string, locales: seq[string]): Catalogue =
    let db = get_db()
    for lang in locales:
        let tmp = cstring(domain & "-" & lang)
        if db.hasOwnProperty(tmp):
            return db[tmp]
    return nil


proc set_text_domain_impl*(domain: string; info: CallInfo) : Catalogue =
    let cat = find_catalogue(domain, set_current_langs())
    if isNil(cat):
        debug(cstring("can't set domain to " & domain & $set_current_langs()),
                      instantiationInfo())
        return get_null_catalogue()
    return set_current_catalogue_js(cat)


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


proc lang_from_url(url: cstring): cstring =
    let tmp = ($url).split("?")
    let (path, qry) = (tmp[0], tmp[1])
    for i in path.split("/"):
        if len(i) != 2: continue
        return cstring(i)
    for i in qry.split("&"):
        let l_and_r = i.split("=")
        if len(l_and_r) < 2: continue
        let (l, r) = (l_and_r[0], l_and_r[1])
        if l != "lang": continue
        return cstring(r)
    return cstring(fallback_locale)


proc catalogue_from_url(domain: string, url: cstring) =
    let lang = lang_from_url(url)
    var cat = Catalogue(loaded: false, wasted: false)
    let db = get_db()
    let key = cstring(domain & "-") & lang
    echo("catalogue_from_url:", key)
    if db.hasOwnProperty(key):
        debug("override ", instantiationInfo())
    db[key] = cat
    load_from_url(url,
        proc(src: cstring): void {.gcsafe.} =
            echo("catalogue_from_url(cb):", src)
            if cat.parse_json(src):
                cat.loaded = true
                cat.wasted = true
                debug(cstring("error after fetch " & $url), instantiationInfo())
                discard jsDelete(db[key])
                let key2 = cstring(cat.domain & "-" & cat.charset)
                db[key2] = cat
            else:
                cat.loaded = true
                debug("loaded", instantiationInfo())
        , proc(): void {.gcsafe.} =
            cat.loaded = true
            cat.wasted = true
            debug(cstring("failed to fetch " & $url), instantiationInfo())
            discard jsDelete(db[key])
        )
    ## @todo unblocking load


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


