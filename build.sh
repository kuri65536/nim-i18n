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
    mv -f testresults.html html
}


function doc() {
    nim doc --outdir:html src/i18n.nim
    cd html; ln -sf i18n.html index.html
}


case "x$1" in
xdoc)
    doc
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
