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
import strutils

import i18n_header
import private/plural


type
  CallInfo = tuple[filename: string, line: int, column: int]


proc hasOwnProperty(x: JsAssoc, prop: cstring): bool
    {. importcpp: "#.hasOwnProperty(#)" .}


proc is_cstring(x: JsObject): bool =
    return jsTypeOf(x) == cstring("string")


proc is_array(x: JsObject): bool =
    if jsTypeOf(x) == cstring("string"):
        return false
    var tmp = false
    {.emit: "`tmp` = `x`.indexOf !== undefined;".}
    return tmp


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


proc lookup_plurals*(self: Catalogue, key: cstring): seq[cstring] =
    let fallback = @[key]
    if not self.loaded:
        echo("lookup-waiting...")
        return fallback
    if isNil(self.lookup_db):
        return fallback
    if not self.lookup_db.hasOwnProperty(key):
        return fallback
    let val = self.lookup_db[key]
    if jsTypeOf(val) == cstring("string"):
        return @[val.to(cstring)]
    result = @[]
    for i in val.to(seq[cstring]):
        result.add(i)


proc lookup*(self: Catalogue, key: cstring): string =
    let ret = self.lookup_plurals(key)
    if len(ret) < 1:
        return $key
    return $ret[0]


proc parse_plurals(src: JsObject): tuple[n: int, stats: seq[State]] =
    proc parse_oneterm(s: string): tuple[l, r: string] =
        let tmp = s.split("=")
        let (l, r) = (tmp[0], join(tmp[1..^1], "="))
        return (l.strip(), r)

    proc set_jsobj(s: var JsObject, l, r: string): void =
        if   l == "nplurals":
            s["nplurals"] = parseInt(r)
        elif l == "plural":
            s["plural"] = cstring(r)

    proc parse_jsobj(s: JsObject): JsObject =
        new(result)
        if s.hasOwnProperty("nplurals"):
            set_jsobj(result, "nplurals",
                      $s["nplurals"].to(cstring))

    proc parse_array(s: seq[JsObject]): JsObject =
        new(result)
        for i in s:
            if i.is_cstring():
                let (l, r) = parse_oneterm($i.to(cstring))
                set_jsobj(result, l, r)
            elif i.is_array():
                let (l, r) = ($i[0].to(cstring), $i[1].to(cstring))
                set_jsobj(result, l, r)
            else:
                if i.hasOwnProperty("nplurals"):
                    set_jsobj(result, "nplurals",
                              $i["nplurals"].to(cstring))
                if i.hasOwnProperty("plural"):
                    result["plural"] = i["plural"]

    proc parse_string(s: cstring): JsObject =
        new(result)
        let terms = ($s).split(";")
        for i in terms:
            let (l, r) = parse_oneterm(i)
            set_jsobj(result, l, r)

    let sobj = if   src.is_cstring():
                parse_string(src.to(cstring))
               elif src.is_array():
                parse_array(src.to(seq[JsObject]))
               else:
                parse_jsobj(src)
    let n = if sobj.hasOwnProperty("nplurals"): sobj["nplurals"].to(int)
            else:                               2
    let stats = plural.parseExpr($sobj["plural"].to(cstring))
    return (n, stats)


proc parse_json(self: var Catalogue, json: cstring): bool =
    let data = try:
            var tmp: JsObject
            {.emit: "`tmp` = JSON.parse(`json`);".}
            tmp
        except JsSyntaxError:
            echo("parse_json-exception: ", json)
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
    (self.num_plurals, self.plurals) = parse_plurals(data["Plural-Forms"])
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
                     msgid, msgid_plural: cstring, num: int,
                     info: CallInfo): cstring =
    let plurals = catalogue.lookup_plurals(msgid)
    if len(plurals) < 1:
        return msgid
    let idxev = catalogue.plurals.evaluate(num)
    let idx = if idxev >= catalogue.num_plurals: 0  # behave as c version
              elif idxev < 0:                    0
              else:                              idxev
    var ret = $(if idx < len(plurals): plurals[idx]
                else:                  plurals[0])
    ret = ret.replace("%d", $num)
    ret = ret.replace("%u", $num)
    return cstring(ret)


proc dngettext_impl*(catalogue: Catalogue,
                     msgid, msgid_plural: string, num: int,
                     info: CallInfo): string =
    return $dngettext_impl(catalogue,
                           cstring(msgid), cstring(msgid_plural), num,
                           info)


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
    if db.hasOwnProperty(key):
        debug("override ", instantiationInfo())
    db[key] = cat
    load_from_url(url,
        proc(src: cstring): void {.gcsafe.} =
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

    if   starts_with(dir_path, "http:"):
        catalogue_from_url(domain, dir_path)
    elif starts_with(dir_path, "https:"):
        catalogue_from_url(domain, dir_path)
    else:
        bindTextDomain(cstring(dir_path))


# ECMA Specific
proc toLocalString*(n: int, unit: cstring
                    ): string {.importcpp: "(@).toLocalString(#)".}


