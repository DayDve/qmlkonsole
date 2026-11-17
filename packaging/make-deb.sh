#!/bin/sh
# Build the qmlkonsole-mobile .deb (run inside the packaging/Dockerfile image, from the repository root):
#   packaging/make-deb.sh [VERSION]   -> packaging/out/qmlkonsole-mobile_<version>_<arch>.deb
# Installs into /usr and replaces the distribution's qmlkonsole package.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
NAME=qmlkonsole-mobile
UPSTREAM=qmlkonsole
DESC=$(git -C "$ROOT" describe --tags 2>/dev/null || echo v0)
VERSION=${1:-$(echo "$DESC" | sed -E 's/^v//; s/^([0-9.]+)-([0-9]+)-g([0-9a-f]+)$/\1+mobile\2.g\3/; s/^([0-9.]+)$/\1+mobile0/')}
ARCH=$(dpkg --print-architecture)
OUT=$ROOT/packaging/out
PKG=$OUT/pkg
BUILD=$OUT/build
rm -rf "$PKG" "$BUILD"
mkdir -p "$PKG/DEBIAN"

cmake -Wno-dev -S "$ROOT" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
cmake --build "$BUILD" -j"$(nproc)"
DESTDIR=$PKG cmake --install "$BUILD" >/dev/null

# Strip, then work out the shared library dependencies
find "$PKG" -type f \( -perm -u+x -o -name '*.so*' \) -exec sh -c \
    'file -b "$1" | grep -q ELF && strip --strip-unneeded "$1"' _ {} \;
mkdir -p "$OUT/debian"
printf 'Source: %s\n\nPackage: %s\nArchitecture: %s\n' $NAME $NAME "$ARCH" > "$OUT/debian/control"
LIBS=$(cd "$OUT" && find pkg -type f -exec sh -c 'file -b "$1" | grep -q ELF' _ {} \; -print |
       xargs dpkg-shlibdeps -O --ignore-missing-info 2>/dev/null | sed 's/^shlibs:Depends=//')
rm -rf "$OUT/debian"
[ -n "$LIBS" ] || { echo "dpkg-shlibdeps found no dependencies"; exit 1; }

SIZE=$(du -sk "$PKG" | cut -f1)
cat > "$PKG/DEBIAN/control" <<EOD
Package: $NAME
Version: $VERSION
Architecture: $ARCH
Maintainer: DayDve <daydve@smbit.pro>
Installed-Size: $SIZE
Depends: $LIBS, qml6-module-org-kde-kirigami, qml6-module-org-kde-kirigamiaddons-formcard, qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-layouts
Provides: $UPSTREAM
Conflicts: $UPSTREAM
Replaces: $UPSTREAM
Section: kde
Priority: optional
Homepage: https://github.com/DayDve/qmlkonsole
Description: terminal for Plasma Mobile, with fixes
 QMLKonsole from KDE with fixes from the mobile branch of this fork
 (the Configure button of the saved commands dialog opens the settings).
EOD

dpkg-deb --root-owner-group -Zxz --build "$PKG" "$OUT/${NAME}_${VERSION}_$ARCH.deb"
dpkg-deb -I "$OUT/${NAME}_${VERSION}_$ARCH.deb" | sed -n '/Package/,$p'
