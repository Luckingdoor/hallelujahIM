#!/bin/bash
# 用 build-standalone.sh 的产物打出可双击安装的 .pkg，不需要 Xcode。
#
#   bash package/build-package-noxcode.bash
#
# 产物：./dist/hallelujah-horizontal-<版本>.pkg
set -e

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

Version=$(date "+%Y%m%d%H%M%S")
GitHash=$(git rev-parse --short HEAD 2>/dev/null || echo nogit)

bash build-standalone.sh

STAGE=/tmp/hallelujah-pkg
rm -rf "$STAGE"
mkdir -p "$STAGE/root"
cp -R "$ROOT/build/hallelujah.app" "$STAGE/root/"

# postinstall-action：none 不打扰用户，logout 会提示注销（输入法切换更干净）
POSTINSTALL_ACTION="${PKG_POSTINSTALL_ACTION:-none}"
sed "s/__POSTINSTALL_ACTION__/${POSTINSTALL_ACTION}/" "$ROOT/package/PackageInfo" > "$STAGE/PackageInfo"

mkdir -p "$ROOT/dist"
PKG="$ROOT/dist/hallelujah-horizontal-${Version}-${GitHash}.pkg"

pkgbuild \
    --info "$STAGE/PackageInfo" \
    --root "$STAGE/root" \
    --identifier "github.dongyuwei.inputmethod.hallelujahInputMethod" \
    --version "${Version}" \
    --install-location "/Library/Input Methods" \
    --scripts "$ROOT/package/scripts" \
    "$PKG"

echo ""
echo "==> done: $PKG"
