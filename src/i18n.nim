#
#  Nim gettext-like module
#  (c) Copyright 2024, 2019 shimoda
#  (c) Copyright 2016 Parashurama
#
#  See the file "LICENSE" (MIT)
#

## This module provides a gettext-like interface for internationalisation.
##
## Examples:
##
## .. code-block:: Nim
##
##  import i18n
##  # load current locale from env
##  setTextLocale()
##  # Locale can also be explicitely set.
##  setTextLocale("fr_FR.UTF-8")
##  # Locale can lifted from env, but encoding be manually set.
##  setTextLocale("", "UTF-8")
##
##  # bind a domain tag to a specific folder.
##  # see bindTextDomain documentation for details.
##  bindTextDomain("first_domain", "/path/to/catalogues")
##  bindTextDomain("second_domain", "/path/to/catalogues")
##  bindTextDomain("third_domain", "/other/path/to/catalogues")
##
##  # Set current text domain (set default for gettext and friends)
##  # also load catalogue first time it is set.
##  setTextDomain("first_domain")
##
##  # gettext lookup inside the current domain for msgid translation.
##  # ``tr`` is an alias for gettext.
##  echo tr"msgid to lookup in first_domain"
##  echo gettext"other msgid to lookup in first_domain"
##
##  # Set a new current domain (and load a new catalogue)
##  setTextDomain("second_domain")
##
##  echo tr"msgid to lookup in second_domain"
##
##  # d*gettext family allow to lookup into a different domain
##  # without changing the current domain.
##  echo dgettext("first_domain", "lookup in first_domain")
##
##  # n*gettext family is like gettext but allow a plural form
##  # depending on current locale and its integer argument.
##  echo ngettext("%i hour", "%i hours", 1)
##  echo ngettext("%i hour", "%i hours", 2)
##
##  # the *pgettext family allow for looking up
##  # a different context inside the same domain.
##  echo pgettext("context", "msgid")
##
##  # the various family function can also be combined
##  # for more complicated lookups. ex:
##
##  # lookup plural form for "context2" inside "third_domain".
##  dnpgettext("third_domain", "context2", "%i hour", "%i hours", 1)
##
##  # same thing but lookup inside current domain.
##  npgettext("context2", "%i hour", "%i hours", 2)
import algorithm
import tables

when not defined(js):
  import encodings
  from math import nextPowerOfTwo
  import os
  import strutils
  import streams
  import i18n/private/plural

else:
  import jsffi
  import strutils


type
    Hash = int

when not defined(js):
  type
    StringEntry {.pure final.} = object
        length: uint32
        offset: uint32

    TableEntry {.pure final.} = object
        key: StringEntry
        value: string

else:
  type
    StringEntry {.pure final.} = object
        length: uint32
        offset: uint32

    TableEntry {.pure final.} = object
        key: StringEntry
        value: string

type
    Catalogue = ref object
      when true:
        version: uint32

      when not defined(js):
        filepath: string
        domain: string
        charset: string
        use_decoder: bool
        decoder: EncodingConverter
        plurals: seq[State]
        plural_lookup: Table[string, seq[string]]
      else:
        lookup_db: JsAssoc[cstring, seq[cstring]]
        domain: cstring
        charset: cstring
        use_decoder: bool

      when true:
        num_plurals: int
        num_entries: int
        key_cache: string
        entries: seq[TableEntry]


type
    LineInfo = tuple[filename: string, line: int, column: int]


when defined(js):
  var CURRENT_CHARSET = "UTF-8"
  var CURRENT_LOCALE = "C"
  var CURRENTS_LANGS : seq[string] = @[]

  var db = newJsAssoc[cstring, Catalogue]()

  proc hasOwnProperty(x: JsAssoc, prop: cstring): bool
    {. importcpp: "#.hasOwnProperty(#)" .}

  proc json_parse(x: cstring): JsObject
    {. importcpp: "JSON.parse(#)" .}


const TABLE_MAXIMUM_LOAD = 0.5
const MSGCTXT_SEPARATOR = '\4'

#~when sizeof(StringEntry) != sizeof(uint32) * 2:
#~    {.fail:"StringEntry size != 8 bytes"}

#~          0  | magic number = 0x950412de                |
#~             |                                          |
#~          4  | file format revision = 0                 |
#~             |                                          |
#~          8  | number of strings                        |  == N
#~             |                                          |
#~         12  | offset of table with original strings    |  == O
#~             |                                          |
#~         16  | offset of table with translation strings |  == T
#~             |                                          |
#~         20  | size of hashing table                    |  == S
#~             |                                          |
#~         24  | offset of hashing table                  |  == H

when defined(js):
  let DEFAULT_NULL_CATALOGUE = Catalogue(
        key_cache:"", domain:"default",
        # plural_lookup: [("",@[""])].toTable
        )
  var
    CURRENT_CATALOGUE = DEFAULT_NULL_CATALOGUE
    CATALOGUE_REFS = initTable[string, Catalogue]()
    DOMAIN_REFS = initTable[string, string]()
else:
  var
    DOMAIN_REFS = initTable[string, string]()
    CATALOGUE_REFS = initTable[string, Catalogue]()
    #[
    CURRENT_DOMAIN_REF: string
    ]#
    CURRENT_CATALOGUE: Catalogue
    CURRENT_CHARSET = "UTF-8"
    CURRENT_LOCALE = "C"
    CURRENTS_LANGS : seq[string] = @[]
    DEFAULT_LOCALE_DIR = "/usr/share/locale"
    DEFAULT_NULL_CATALOGUE = Catalogue(filepath:"", entries: @[], key_cache:"", domain:"default", plural_lookup: [("",@[""])].toTable)

  let DEFAULT_PLURAL = parseExpr("(n != 1)")

#~proc isStatic(a: string{lit|`const`}): bool {.compileTime.}=
#~    result = true

#~proc isStatic(a: string): bool {.compileTime.}=
#~    result = false

proc `==`(self, other: Catalogue): bool =
    result = cast[BiggestInt](self) == cast[BiggestInt](other)

template `??`(a, b: string): string =
    if a.len != 0: a else: b


when defined(js):
  discard
elif NimMajor == 0 and NimMinor == 19:
  proc c_memchr(cstr: pointer, c: char, n: csize): pointer {.
       importc: "memchr", header: "<string.h>" .}
else:
  proc c_memchr(cstr: pointer, c: char, n: csize_t): pointer {.
       importc: "memchr", header: "<string.h>" .}


when NimMajor < 2:
  proc addr_offset(tail, head: pointer): ByteAddress {.inline.} =
      result = cast[ByteAddress](tail) -% cast[ByteAddress](head)

else:
  proc addr_offset(tail, head: pointer): int {.inline.} =
      result = cast[int](tail) -% cast[int](head)


proc `!&`(h: Hash, val: int): Hash {.inline.} =
      ## mixes a hash value `h` with `val` to produce a new hash value. This is
      ## only needed if you need to implement a hash proc for a new datatype.
      result = h +% val
      result = result +% result shl 10
      result = result xor (result shr 6)

proc `!$`(h: Hash): Hash {.inline.} =
      ## finishes the computation of the hash value. This is
      ## only needed if you need to implement a hash proc for a new datatype.
      result = h +% h shl 3
      result = result xor (result shr 11)
      result = result +% result shl 15


when false:
 proc get(self: StringEntry; cache: string): string =
  when NimMajor < 2:
    shallowCopy(result, cache[self.offset.int..<self.offset.int+self.length.int])
  else:
    ## @todo v2.0 shallowCOpy in nim 2.0 or later
    result = cache[self.offset.int..<self.offset.int+self.length.int]


proc equal(self: StringEntry; other: string; cache: string): bool =
  when not defined(js):
    if self.length.int == other.len:
        return equalMem(cache[self.offset.int].unsafeAddr, other[0].unsafeAddr, other.len)
    return false
  else:
    let offset = self.offset.int
    for i in 0..<self.length.int:
        if cache[offset + i] != other[i]:
            return false
    return true

proc hash(self: StringEntry; cache: string): Hash =
  ## efficient hashing of StringEntry
  let start = self.offset.int
  let endp = (self.offset + self.length).int
  var h: Hash = 0
  for i in start..<endp:
    h = h !& ord(cache[i])
  result = !$h

proc hash(x: string): Hash =
  ## efficient hashing of strings
  var h: Hash = 0
  for i in 0..x.len-1:
    h = h !& ord(x[i])
  result = !$h

proc get_empty_bucket(self: Catalogue; key: StringEntry; value: string): int =
    let mask  = self.entries.len - 1
    var index = hash(key, self.key_cache) and mask
    let endp  = index # if index returns to initial value; unable to insert value
    var step = 1

    while self.entries[index].value != "":
        index = (index + step) and mask # linear probing
        inc(step)
        if index == endp:
            return -1

    return index;

proc insert(self: Catalogue; key: StringEntry; value: string) =
    let index = self.get_empty_bucket(key, value)
    if index == -1:
        quit("failure to insert key!")
    else:
      block:
        self.entries[index].key = key
      when NimMajor < 2:
        shallowCopy self.entries[index].value, value
      else:
        ## @todo v2.0 shallowCopy in nim 2.0 or laters.
        self.entries[index].value = value


proc get_bucket(self: Catalogue; key: string): int =
    let mask  = self.entries.len - 1
    var index = hash(key) and mask
    let endp  = index # if index returns to initial value; unable to insert value
    var step = 1

    if self.entries.len == 0:
        return -1

    while self.entries[index].value == "" or not self.entries[index].key.equal(key, self.key_cache):
        index = (index + step) and mask # linear probing
        inc(step)
        if index == endp:
            return -1

    return index;

proc lookup(self: Catalogue; key: string): string =
  when not defined(js):
    let index = self.get_bucket(key)
    if index != -1:
      when NimMajor < 2:
        shallowCopy result, self.entries[index].value
      else:
        ## @todo v2.0 shallowCopy in nim 2.0 or laters.
        result = self.entries[index].value
  else:
    return $self.lookup_db[key]


when not defined(js):
  proc read_string_table(f: FileStream; table_size: int; entries_size: var int; entries_offset: var int):seq[StringEntry] =

    result = newSeq[StringEntry](table_size)
    let readbytes = result.len * sizeof(StringEntry)
    doAssert( f.readData(result[0].addr, readbytes) == readbytes, "IOError: unable to read StringTable")

    entries_size = 0
    entries_offset = result[0].offset.int

    for i in 0..<table_size:
        entries_size += result[i].length.int + 1 # NULL byte
        result[i].offset -= entries_offset.uint32

    entries_size -= 1 # don't count terminal NULL byte



  proc newCatalogue(domain: string; filename: string) : Catalogue =
    new(result)
#~    echo("loading catalogue: '", domain, "' in file: ", filename)
    var f = newFileStream(filename, fmRead)
    if f == nil:
        raise newException(IOError, "Catalogue file '$#' not found for domain '$#'!".format(filename, domain))

    # read magic
    if f.readInt32().uint32 != 0x950412de'u32:
        raise newException(IOError, "Invalid catalogue file '$#' for domain '$#'!".format(filename, domain))

    result.domain = domain
    result.filepath = filename
    result.version = f.readInt32().uint32
    result.num_entries = f.readInt32().uint32.int
    let key_table_offset = f.readInt32().uint32.int
    let val_table_offset = f.readInt32().uint32.int

    # Set position at beginning of key string table
    f.setPosition(key_table_offset)
    var key_entries_size, key_entries_offset = 0
    let key_entries = read_string_table(f, result.num_entries.int, key_entries_size,
                                        key_entries_offset)
    result.key_cache = newString(key_entries_size) # don't count last NULL byte

    f.setPosition(key_entries_offset)
    doAssert(f.readData(result.key_cache[0].addr, key_entries_size) == key_entries_size)

    # Set position at beginning of value string table
    f.setPosition(val_table_offset)
    var value_entries_size, value_entries_offset = 0
    let value_entries = read_string_table(f, result.num_entries.int, value_entries_size,
                                          value_entries_offset)
    var value_cache = newString(value_entries_size) # don't count last NULL byte

    f.setPosition(value_entries_offset)
    doAssert(f.readData(value_cache[0].addr, value_entries_size) == value_entries_size)


    # first entry is MO file metadata
    var voffset = value_entries[0].offset.int
    var vlength = value_entries[0].length.int
    let metadata = value_cache[voffset ..< voffset + vlength]

    # find charset
    let cpos = metadata.find("charset=") + 8 # len of "charset="
    if cpos != -1:
        result.charset = metadata[cpos..<metadata.find({';','\L'}, start=cpos)]
    else:
        result.charset = "ascii"

    # find num plurals
    let ppos = metadata.find("nplurals=", start=cpos) + 9 # len of "nplurals="
    if ppos != -1:
        result.num_plurals = parseInt(metadata[ppos..<metadata.find({';','\L'}, start=ppos)])
    else:
        result.num_plurals = 2

    # find plural expression
    let spos = metadata.find("plural=", start=ppos) + 7 # len of "plural="
    if spos != -1:
        result.plurals = parseExpr(metadata[spos..<metadata.find({';','\L'}, start=spos)])
    else:
        result.plurals = DEFAULT_PLURAL

    # Initialize charset converter if needed to convert to current locale encoding.
    if result.charset != CURRENT_CHARSET : # Catalogue charset different from current charset
        if not (CURRENT_CHARSET == "utf-8" and result.charset == "ascii"): # Special case since ascii is UTF-8 compatible
            result.use_decoder = true
            result.decoder = open(CURRENT_CHARSET, result.charset)

    # Initialize plural table
    result.plural_lookup = initTable[string, seq[string]]()

    # Create table and Initialize entries
    let capacity = nextPowerOfTwo((result.num_entries.float*(1.0/TABLE_MAXIMUM_LOAD)).int)
    result.entries = newSeq[TableEntry](capacity)

    # Add entries in Catalogue, skip first entry (Metadata)
    for i in 1..<result.num_entries.int:
        var koffset = key_entries[i].offset.int
        let (klen1, klen2) = block:
                                let tmp = key_entries[i].length
                                when NimMajor >= 2: (csize_t(tmp), uint32(tmp))
                                else:               (csize(tmp), uint32(tmp))
        var voffset = value_entries[i].offset.int
        var vlength = value_entries[i].length.int

        # looks for NULL byte in key
        var null_byte = c_memchr(result.key_cache[koffset].addr, '\0', klen1)
        if null_byte != nil: # key has plural
          let (key, val) = block:
            let ksplit = addr_offset(null_byte, result.key_cache[0].addr)
            let plural_msg = result.key_cache[koffset..<ksplit]
#~            let plural_msg = result.key_cache[ksplit + 1..<koffset+klength]
            var plurals = newSeq[string](result.num_plurals)

            # look for NULL byte in value
            let remaining1 = block:
                                let tmp = vlength + 1
                                when NimMajor >= 2: tmp.csize_t
                                else:               tmp.csize
            var remaining = vlength
            var index = 0
            while true:
                var null_byte = c_memchr(value_cache[voffset].addr, '\0', remaining1)
                if null_byte == nil or remaining <= 0:
                    break
                let vsplit = addr_offset(null_byte, value_cache[0].addr)

                if index <= plurals.high : # if msgid has more plurals than declared, ignore.
                  when NimMajor < 2:
                    shallowCopy plurals[index], value_cache[voffset..<vsplit]
                  else:
                    ## @todo v2.0 shallowCopy in nim 2.0 or laters.
                    plurals[index] = value_cache[voffset..<vsplit]
                remaining -= vsplit - voffset + 1
                voffset = vsplit + 1
                index += 1

            (plural_msg, plurals)

          when NimMajor < 2:
            let (plural_msg, plurals) = (key, val)
            shallowCopy result.plural_lookup[plural_msg], plurals
          else:
            ## @todo v2.0 shallowCopy in nim 2.0 or laters.
            result.plural_lookup[key] = val

        else: # key has no plural, simple result
            result.insert( StringEntry(offset: koffset.uint32, length: klen2),
                          value_cache[voffset..<voffset+vlength])
    f.close()

else:
  proc newCatalogue(json: cstring) : Catalogue =
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


  proc is_valid(self: Catalogue): bool =  # {{{1
    if self.lookup_db != nil:
        return true
    return false




# Helpers for gettext functions

proc makeDiscardable[T](a: T): T {.discardable, inline.} = a

template debug(message: untyped; info: LineInfo): untyped =
    when not defined(release):
        let filepos {.gensym.} = info[0] & "(" & $info[1] & ") "
        echo(filepos, message)

proc find_catalogue(localedir, domain: string; locales: seq[string]): string =
  when not defined(js):
    let domain_file = "LC_MESSAGES" & DirSep & domain & ".mo"
    result = ""

    for lang in locales:
        result.setLen(0)
        result.add(localedir)
        result.add(DirSep)
        result.add(lang)
        result.add(DirSep)
        result.add(domain_file)

        let is_exist = when NimMajor < 2: existsFile(result)
                       else:              fileExists(result)
        if is_exist:
            return # return catalogue path
    result = ""
  else:
    result = ""


proc set_text_domain_impl(domain: string; info: LineInfo) : Catalogue =
  when true:
    result = CATALOGUE_REFS.getOrDefault(domain)

  when not defined(js):
    if result == nil: # domain not found in list of loaded catalogues.
        let localedir = DOMAIN_REFS.getOrDefault(domain) # try lookup domain in registered domains.
        let file_path = find_catalogue(localedir ?? DEFAULT_LOCALE_DIR, domain, CURRENTS_LANGS)
        if file_path == "": # catalogue file not found!
            when not defined(release):
                debug("warning: TextDomain '$#' was not found for locale '$#'.".format(domain, $CURRENTS_LANGS) &
                      " (use 'bindTextDomain' to add a folder in the search path)", info)
            result = DEFAULT_NULL_CATALOGUE
        else:
            result = newCatalogue(domain, file_path)
            CATALOGUE_REFS[domain] = result
  else:
    if result == nil:
        result = DEFAULT_NULL_CATALOGUE


when not defined(js):
  proc get_locale_properties(): (string, string) =
    var locales: seq[string] = @[]
    var codesets: seq[string] = @[]
    for e in ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"]:
        let evar = getEnv(e)
        let id = evar.rfind('.')
        if id != -1: # locale has codeset.
            locales.add evar[0..<id]
            codesets.add evar[id+1..^1]
        elif evar.len != 0:
            locales.add evar

    result[0] = if locales.len != 0: locales[0] else: "C"
    result[1] = if codesets.len != 0: codesets[0] else: getCurrentEncoding()


proc decode_impl(catalogue: Catalogue; translation: string): string {.inline.}=
  when not defined(js):
    if catalogue.use_decoder:
      when NimMajor < 2:
        shallowCopy result, catalogue.decoder.convert(translation)
      else:
        ## @todo v2.0 shallowCopy in nim 2.0 or laters.
        result = catalogue.decoder.convert(translation)
    else:
      when NimMajor < 2:
        shallowCopy result, translation
      else:
        ## @todo v2.0 shallowCopy in nim 2.0 or laters.
        result = translation
  else:
    shallowCopy result, translation


proc dgettext_impl( catalogue: Catalogue;
                    msgid: string;
                    info: LineInfo): string {.inline.} =
  when NimMajor < 2:
    shallowCopy result, catalogue.lookup(msgid)
  else:
    ## @todo v2.0 shallowCopy in nim 2.0 or laters.
    result = catalogue.lookup(msgid)
  block:
    if result == "":
      block:
        debug("Warning: translation not found! : " &
              "'$#' in domain '$#'".format(msgid, catalogue.domain), info)
      when NimMajor < 2:
        shallowCopy result, catalogue.decode_impl(msgid)
      else:
        ## @todo v2.0 shallowCopy in nim 2.0 or laters.
        result = catalogue.decode_impl(msgid)


when not defined(js):
  proc dngettext_impl(catalogue: Catalogue;
                    msgid, msgid_plural: string;
                    num: int;
                    info: LineInfo): string =
    let plurals = catalogue.plural_lookup.getOrDefault(msgid)
    if plurals == []:
        debug("Warning: translation not found! : " &
              "'$#/$#' in domain '$#'".format(msgid, msgid_plural, catalogue.domain), info)
        if num == 1:
          when NimMajor < 2:
            shallowCopy result, msgid
          else:
            ## @todo v2.0 shallowCopy in nim 2.0 or laters.
            result = msgid
        else:
          when NimMajor < 2:
            shallowCopy result, msgid_plural
          else:
            ## @todo v2.0 shallowCopy in nim 2.0 or laters.
            result = msgid_plural
    else:
      let a = block:
        var index = catalogue.plurals.evaluate(num)
        if index >= catalogue.num_plurals:
            index = 0
        let pl = plurals[index] ?? plurals[0]
        pl
      let pl = a
      when NimMajor < 2:
        shallowCopy result, catalogue.decode_impl(pl)
      else:
        ## @todo v2.0 shallowCopy in nim 2.0 or laters.
        result = catalogue.decode_impl(pl)
else:
  proc dngettext_impl(catalogue: Catalogue;
                    msgid, msgid_plural: string;
                    num: int;
                    info: LineInfo): string =
    ""


# gettext functions

template dngettext*(domain: string;
                    msgid, msgid_plural: string;
                    num: int): string =
    ## Same as **ngettext**, but specified ``domain`` is used for lookup.
    let catalogue {.gensym.} = set_text_domain_impl(domain, instantiationInfo())
    dngettext_impl(catalogue, msgid, msgid_plural, num, instantiationInfo())

template dgettext*(domain: string; msgid: string): string =
    ## Same as **gettext**, but specified ``domain`` is used for lookup.
    let catalogue {.gensym.} = set_text_domain_impl(domain, instantiationInfo())
    dgettext_impl(catalogue, msgid, instantiationInfo())


template ngettext*(msgid, msgid_plural: string; num: int): string =
    ## Same as **gettext**, but choose the appropriate plural form, which depends on ``num``
    ## and the language of the message catalog where the translation was found.
    ## If translation is not found ``msgid`` or ``msgid_plural`` is returned depending on ``num``.
    when not defined(release):
        if CURRENT_CATALOGUE == DEFAULT_NULL_CATALOGUE:
            debug("warning: TextDomain is not set. " &
                  "(use 'setTextDomain' to bind a valid TextDomain as default)",
                  instantiationInfo())
    dngettext_impl(CURRENT_CATALOGUE, msgid, msgid_plural, num, instantiationInfo())

template gettext*(msgid: string): string =
    ## Attempt to translate a ``msgid`` into the user's native language (as set by **setTextLocale**),
    ## by looking up the translation in a message catalog. (loaded according to the current text domain and locale.)
    ## If translation is not found ``msgid`` is returned.
    when not defined(release):
        if CURRENT_CATALOGUE == DEFAULT_NULL_CATALOGUE:
            debug("warning: TextDomain is not set. " &
                  "(use 'setTextDomain' to bind a valid TextDomain as default)",
                  instantiationInfo())
#~    when msgid.isStatic:
#~        const hashval = hash(msgid)
#~        echo("string literal ready to hash at compile time!: ", hashval)
    dgettext_impl(CURRENT_CATALOGUE, msgid, instantiationInfo())

template tr*(msgid: string): string =
    ## Alias for **gettext**. usage: tr"msgid"
    # Temporary fix for https://github.com/nim-lang/Nim/issues/4128
    when not defined(release):
        if CURRENT_CATALOGUE == DEFAULT_NULL_CATALOGUE:
            debug("warning: TextDomain is not set. " &
                  "(use 'setTextDomain' to bind a valid TextDomain as default)",
                  instantiationInfo())
#~    when msgid.isStatic:
#~        const hashval = hash(msgid)
#~        echo("string literal ready to hash at compile time!: ", hashval)
    dgettext_impl(CURRENT_CATALOGUE, msgid, instantiationInfo())


template pgettext*(msgctxt, msgid: string): string =
    ## Same as **gettext**, but ``msgctxt`` is used to suply a specific context
    ## for ``msgid`` lookup inside current domain.
    gettext(msgctxt & MSGCTXT_SEPARATOR & msgid)

template npgettext*(msgctxt, msgid, msgid_plural: string; num: int): string =
    ## Same as **ngettext**, but ``msgctxt`` is used to suply a specific context
    ## for ``msgid`` lookup inside current domain.
    ngettext(msgctxt & MSGCTXT_SEPARATOR & msgid, msgid_plural, num)

template dpgettext*(domain, msgctxt, msgid: string): string =
    ## Same as **dgettext**, but ``msgctxt`` is used to suply a specific context
    ## for ``msgid`` lookup inside specified ``domain``.
    dgettext(domain, msgctxt & MSGCTXT_SEPARATOR & msgid)

template dnpgettext*(domain, msgctxt, msgid, msgid_plural: string; num: int): string =
    ## Same as **dngettext**, but ``msgctxt`` is used to suply a specific context
    ## for ``msgid`` lookup inside specified ``domain``.
    dngettext(domain, msgctxt & MSGCTXT_SEPARATOR & msgid, msgid_plural, num)

template setTextDomain*(domain: string) : bool =
    ## Sets the current message domain used by **gettext**, **ngettext**, **pgettext**,
    ## **npgettext** functions. Returns ``false`` if catalogue associated with
    ## ``domain`` could not be found.
    let catalogue {.gensym.} = set_text_domain_impl(domain, instantiationInfo())
    if catalogue != nil: # if catalogue was found
        CURRENT_CATALOGUE = catalogue
        makeDiscardable(true)
    else:
        makeDiscardable(false)

proc getTextDomain*() : string =
    ## Returns the current message domain used by **gettext**, **ngettext**, **pgettext**,
    ## **npgettext** functions.
    result = $CURRENT_CATALOGUE.domain


when defined(js):
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
  when true:
    ## Sets the base folder to look for catalogues associated with ``domain``.
    ## ``dir_path`` must be an absolute path.
    ## Catalogues search path is in the form:
    ## $(``DIR_PATH``)/$(``TEXT_LOCALE``)/LC_MESSAGES/$(``domain``).mo
    if domain.len == 0:
        raise newException(ValueError, "Domain name has zero length.")

  when not defined(js):
    if dir_path.len == 0 or not isAbsolute(dir_path):
        raise newException(ValueError, "'dir_path' argument " &
                "must be an absolute path; was '" & (dir_path ?? "nil") & "'")

    DOMAIN_REFS[domain] = dir_path

proc setTextLocale*(locale="", codeset="") =
    ## Sets text locale used for message translation. ``locale`` must be a valid expression in the form:
    ## **language** [_**territory**][. **codeset**] (**@modifier** is not currently used!)
    ##
    ## If called without argument or with an empty string, locale is lifted from calling environnement.
    ##
    ## Beware: **setTextLocale** is not related to posix **setLocale** and so must be set separately.
    var locale_expr, codeset_expr: string

    if locale.len == 0:
      when not defined(js):
        # load user current locale.
        (locale_expr, codeset_expr) = get_locale_properties()
      else:
        (locale_expr, codeset_expr) = ("C", "ascii")


    else:
        # use user specified locale.
        let sid = locale.rfind('.')
        let rid = locale.find('@')
        if sid != -1: # user locale has codeset.
            if rid != -1: # has codeset & modifier
                if sid < rid: # ll_CC.codeset@modifier
                    locale_expr = locale[0..<sid]
                    codeset_expr = locale[sid+1..<rid]
                else: # ll_CC@modifier.codeset
                    locale_expr = locale[0..<rid]
                    codeset_expr = locale[rid+1..^1]
            else: # ll_CC.codeset
                locale_expr = locale[0..<sid]
                codeset_expr = locale[sid+1..^1]

        else: # query user codeset.
            # user locale has modifier (discard modifier)
            if rid != -1:  # ll_CC@modifier
                locale_expr = locale[0..<rid]
            else:
                locale_expr = locale
            when not defined(js):
              codeset_expr = getCurrentEncoding()
            else:
              codeset_expr = "ascii"

    CURRENT_LOCALE = locale_expr
    CURRENT_CHARSET = if codeset.len == 0: codeset_expr else: codeset

    var territory, lang: string
    let pos = locale_expr.find('_')
    if pos != -1:
        lang = locale_expr[0..<pos]
        territory = locale_expr[pos..^1]
    else:
        lang = locale_expr
        territory = ""

    CURRENTS_LANGS.setLen(0)

    var localename = lang
    CURRENTS_LANGS.add(localename) # ll
    if territory.len != 0:
        localename.add(territory)
        CURRENTS_LANGS.add(localename) # ll_CC
    if codeset_expr.len != 0:
        localename.add('.')
        localename.add(codeset_expr)
        CURRENTS_LANGS.add(localename) # ll_CC.codeset

    CURRENTS_LANGS.reverse()

proc getTextLocale*(): string =
    ## Returns current text locale used for message translation.
    result = CURRENT_LOCALE & '.' & CURRENT_CHARSET


when defined(js):
  # ECMA Specific {{{1
  proc toLocalString*(n: int, unit: cstring
                      ): string {.importcpp: "(@).toLocalString(#)".}


