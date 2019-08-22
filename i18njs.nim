#
#  Nim gettext-like module
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

when defined(js):
  import strutils
  # import encodings
  import algorithm
  # import streams

  type
    Hash = int

    #[
    StringEntry {.pure final.} = object
        length: uint32
        offset: uint32

    TableEntry {.pure final.} = object
        key: StringEntry
        value: string
    ]#

    Catalogue = ref object
        version: uint32
        filepath: string
        domain: string
        charset: string
        use_decoder: bool
        # decoder: EncodingConverter
        # plurals: seq[State]
        # plural_lookup: Table[string, seq[string]]
        num_plurals: int
        num_entries: int
        # entries: seq[TableEntry]
        key_cache: string

    LineInfo = tuple[filename: string, line: int, column: int]

  var CURRENT_CATALOGUE: Catalogue
  var CURRENT_CHARSET = "UTF-8"
  var CURRENT_LOCALE = "C"
  var CURRENTS_LANGS : seq[string] = @[]

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
  # let DEFAULT_NULL_CATALOGUE = Catalogue(filepath:"", entries: @[], key_cache:"", domain:"default", plural_lookup: [("",@[""])].toTable)
  let DEFAULT_NULL_CATALOGUE = Catalogue(
        filepath:"", key_cache:"", domain:"default",
        # plural_lookup: [("",@[""])].toTable
        )

  # let DEFAULT_PLURAL = parseExpr("(n != 1)")

#~proc isStatic(a: string{lit|`const`}): bool {.compileTime.}=
#~    result = true

#~proc isStatic(a: string): bool {.compileTime.}=
#~    result = false

when defined(js):
  proc `==`(self, other: Catalogue): bool =
    result = cast[BiggestInt](self) == cast[BiggestInt](other)

  template `??`(a, b: string): string =
    if a.len != 0: a else: b


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


  #[
  proc newCatalogue(domain: string; filename: string) : Catalogue =
    new(result)
    ]#

  proc makeDiscardable[T](a: T): T {.discardable, inline.} = a

  template debug(message: string; info: LineInfo): void =
    when not defined(release):
        let filepos {.gensym.} = info[0] & "(" & $info[1] & ") "
        echo(filepos, message)

  proc dgettext_impl( catalogue: Catalogue;
                    msgid: string;
                    info: LineInfo): string {.inline.} =
    ""

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
    #[
    let catalogue {.gensym.} = set_text_domain_impl(domain, instantiationInfo())
    if not catalogue.isNil: # if catalogue was found
        CURRENT_CATALOGUE = catalogue
        makeDiscardable(true)
    else:
        makeDiscardable(false)
    ]#
    makeDiscardable(false)

  proc getTextDomain*() : string =
    ## Returns the current message domain used by **gettext**, **ngettext**, **pgettext**,
    ## **npgettext** functions.
    result = CURRENT_CATALOGUE.domain

  proc bindTextDomain*(domain: string; dir_path: string) =
    ## Sets the base folder to look for catalogues associated with ``domain``.
    ## ``dir_path`` must be an absolute path.
    ## Catalogues search path is in the form:
    ## $(``DIR_PATH``)/$(``TEXT_LOCALE``)/LC_MESSAGES/$(``domain``).mo
    if domain.len == 0:
        raise newException(ValueError, "Domain name has zero length.")

    #[
    if dir_path.len == 0 or not isAbsolute(dir_path):
        raise newException(ValueError, "'dir_path' argument " &
                "must be an absolute path; was '" & (dir_path ?? "nil") & "'")

    DOMAIN_REFS[domain] = dir_path
    ]#

  proc setTextLocale*(locale="", codeset="") =
    ## Sets text locale used for message translation. ``locale`` must be a valid expression in the form:
    ## **language** [_**territory**][. **codeset**] (**@modifier** is not currently used!)
    ##
    ## If called without argument or with an empty string, locale is lifted from calling environnement.
    ##
    ## Beware: **setTextLocale** is not related to posix **setLocale** and so must be set separately.
    var locale_expr, codeset_expr: string

    if locale.len == 0:
        # load user current locale.
        (locale_expr, codeset_expr) = ("C", "ascii")
        #[
        (locale_expr, codeset_expr) = get_locale_properties()
        ]#

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
            codeset_expr = "ascii"
            #[
            codeset_expr = getCurrentEncoding()
            ]#

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


  # ECMA Specific {{{1
  proc toLocalString*(n: int, unit: cstring
                      ): string {.importcpp: "(@).toLocalString(#)".}


proc main() =
#~    setTextLocale("fr_FR.UTF-8")
    setTextLocale()
#~    bindTextDomain("character_trits", nil)

    bindTextDomain("character_traits", "/home/mo/Prgms/Nimrod/Raonoke/lang")
    bindTextDomain("meld", "/home/mo/Prgms/Nimrod/Raonoke/tools/gettext")
    setTextDomain("character_traits")

#~    echo("stormborn: ", tr"brilliant_mind")
#~    echo("stormborn: ", tr"brilliant_mind")
#~    echo("stormborn: ", dgettext("meld", "brilliant_mind"))

#~    echo("stormborn: ", dngettext("character_traits", "brilliant_mind", "brilliant_mind", 3))

#~    echo("meld: ", dngettext("meld", "%i hour", "%i hours", 2))

    setTextDomain("meld")
    echo("meld: ", ngettext("%i hour", "%i hours", 2))

when isMainModule:
    main()
