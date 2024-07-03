#! /bin/bash
function build() {
    nimble build
}


function test() {
    make -C tests/data build
    testament pattern 'tests/**/*.nim'
    testament html
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
xtest)
    test
    ;;
*)
    build
    ;;
esac
