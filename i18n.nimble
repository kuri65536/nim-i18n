[Package]
name          : "i18n"
version       : "0.2.0"
author        : "Parashurama"
description   : "Bring a gettext-like internationalisation module to Nim"
license       : "MIT"

InstallDirs : "private"
InstallFiles : "i18n.nim"
bin: "i18n"

[Deps]
requires: "nim >= 0.19"

