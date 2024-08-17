#! /bin/bash
function build() {
    nimble build
}


function test() {
    make -C tests/data build
    make -C tests/data serve-start
    testament "$1" pattern 'tests/**/*.nim'
    testament html
    make -C tests/data serve-stop
    mkdir -p html
    mv -f testresults.html html
}


function doc() {
    mkdir -p html
    (cat README.md; echo; echo '.. title:: The i18n module for nim') > tmp.md
    sed -i "s#$1/##" tmp.md
    # convert relative link in raedme.md
    sed -i "s#\](LICENSE)#]($1/tree/main/LICENSE)#" tmp.md
    # nim 2.0.4 does not support markdown image, convert it.
    url=https://github.com/kuri65536/nim-i18n/actions/workflows/nim2.yml
    sed -i "s#^!\[workflow.*#.. figure:: $url/badge.svg#" tmp.md
    nim md2html -o:html/index.html tmp.md
    opts="--index:on --outdir:html --git.url:$1 --git.commit:main"
    nim doc $opts src/i18n.nim
    nim doc $opts src/i18n/i18n_header.nim
    nim doc $opts src/i18n/private/plural.nim
    nim buildindex -o:html/theindex.html html
}


case "x$1" in
xdoc)
    doc $2
    ;;
xtestjs)
    test --targets:"js"
    ;;
xtestc)
    test --targets:"c"
    ;;
xtest)
    test --targets:"c js"
    ;;
*)
    build
    ;;
esac
