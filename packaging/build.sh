#!/bin/sh
# Build qmlkonsole in Docker and install it into ~/.local.
#   ./build.sh          build and install
#   ./build.sh --image  rebuild the image
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$HERE")
IMG=qmlkonsole-build

if [ "${1:-}" = "--image" ] || ! docker image inspect $IMG >/dev/null 2>&1; then
    docker build -t $IMG "$HERE"
fi

docker run --rm -u "$(id -u):$(id -g)" -e LANG=C.UTF-8 -v "$ROOT:/src" -w /src $IMG sh -ec '
    cmake -Wno-dev -S . -B packaging/build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF >/dev/null
    cmake --build packaging/build -j"$(nproc)"'

BIN=$HOME/.local/bin/qmlkonsole
install -Dm755 "$HERE/build/bin/qmlkonsole" "$BIN.new" && mv -f "$BIN.new" "$BIN"

# A .desktop file with the same name overrides the system one (launchers and favourites keep working)
DESK=$HOME/.local/share/applications/org.kde.qmlkonsole.desktop
sed "s|^Exec=qmlkonsole|Exec=$BIN|; s|^Exec=/usr/bin/qmlkonsole|Exec=$BIN|" \
    /usr/share/applications/org.kde.qmlkonsole.desktop > "$DESK"
kbuildsycoca6 >/dev/null 2>&1 || true
echo "Installed: $BIN"
