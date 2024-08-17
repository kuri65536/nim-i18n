
This project is aimed at bringing an internationalisation module with
a gettext-like interface to Nim.


It supports easy debugging as well as optimized msgid lookup.
While it makes use of the encoding
module (and so libiconv.so on Linux), it does NOT use libintl.

It is developed on GNU/Linux debian, but should also work on Windows/OSX.

PR welcome for any issues.

Documentation can be built inside module with: nim doc -o:i18n.html i18n.nim

For more details on usage;
see [module documentation.](https://kuri65536.github.io/nim-i18n/i18n.html)


![workflow badge](https://github.com/kuri65536/nim-i18n/actions/workflows/nim2.yml/badge.svg)


License
----------
MIT, see [LICENSE](LICENSE)


