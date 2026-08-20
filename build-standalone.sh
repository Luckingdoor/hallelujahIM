#!/bin/bash
# 不依赖 Xcode 的自包含构建：clang 直接编译全部源码（src + 3 个 pod 源码），
# 资源全部取自本仓库，因此不需要事先装过 hallelujah。
# 只需要 Command Line Tools（xcode-select --install）。
#
#   bash build-standalone.sh          # 产物在 ./build/hallelujah.app
set -e

SRC="$(cd "$(dirname "$0")" && pwd)"
OUT="$SRC/build"

rm -rf "$OUT"
mkdir -p "$OUT/inc"

# 只为 <MDCDamerauLevenshtein/xxx.h> 这种 framework-style import 造一层目录，
# 其余 pod 用 -I 指向源码原位，避免同一头文件经两条路径包含造成重定义。
mkdir -p "$OUT/inc/MDCDamerauLevenshtein"
find "$SRC/Pods/MDCDamerauLevenshtein" -name "*.h" -exec cp {} "$OUT/inc/MDCDamerauLevenshtein/" \;

INCS=(-I"$OUT/inc" -I"$SRC/src" -I"$SRC/Pods/FMDB/src/fmdb")
while IFS= read -r -d '' d; do INCS+=(-I"$d"); done < <(find "$SRC/Pods/GCDWebServer/GCDWebServer" -type d -print0)
while IFS= read -r -d '' d; do INCS+=(-I"$d"); done < <(find "$SRC/Pods/MDCDamerauLevenshtein/MDCDamerauLevenshtein" -type d -print0)

APP="$OUT/hallelujah.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/en.lproj" "$APP/Contents/Resources/web"

SOURCES=("$SRC"/src/*.m "$SRC"/src/*.mm)
while IFS= read -r -d '' f; do SOURCES+=("$f"); done < <(find "$SRC/Pods/FMDB/src" -name '*.m' -print0)
while IFS= read -r -d '' f; do SOURCES+=("$f"); done < <(find "$SRC/Pods/GCDWebServer/GCDWebServer" -name '*.m' -print0)
while IFS= read -r -d '' f; do SOURCES+=("$f"); done < <(find "$SRC/Pods/MDCDamerauLevenshtein" -name '*.m' -print0)

ARCH="$(uname -m)"
echo "==> compiling ${#SOURCES[@]} files for $ARCH"
clang -arch "$ARCH" \
  -isysroot "$(xcrun --show-sdk-path)" \
  -mmacosx-version-min=11.0 \
  -fobjc-arc -fmodules -fcxx-modules \
  "${INCS[@]}" \
  -Wno-everything \
  -DGCDWEBSERVER_LOGGING_HEADER='"GCDWebServerPrivate.h"' \
  -framework Cocoa -framework AppKit -framework Foundation \
  -framework InputMethodKit -framework Carbon -framework JavaScriptCore \
  -framework SystemConfiguration -framework CoreServices \
  -lsqlite3 -lz -lc++ \
  "${SOURCES[@]}" \
  -o "$APP/Contents/MacOS/hallelujah"

echo "==> assembling bundle"
# Info.plist 里 $(PRODUCT_BUNDLE_IDENTIFIER) 本由 Xcode 展开，这里手动替换
sed 's/\$(PRODUCT_BUNDLE_IDENTIFIER)/github.dongyuwei.inputmethod.hallelujahInputMethod/' \
  "$SRC/Info.plist" > "$APP/Contents/Info.plist"
# 翻译窗已移除：去掉 main nib，否则系统仍会加载出一个 alpha=0 的常驻面板
/usr/libexec/PlistBuddy -c "Delete :NSMainNibFile" "$APP/Contents/Info.plist" 2>/dev/null || true
# 每次构建换一个 CFBundleVersion。TIS 按 bundle 版本缓存输入源信息，版本不变
# 就不会重新解析 Info.plist——改了 tsInputModeListKey / 图标声明也不会生效，
# 看起来就像「装了但没反应」。
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(date +%Y%m%d%H%M%S)" "$APP/Contents/Info.plist"

R="$APP/Contents/Resources"
cp "$SRC/dictionary/cedict.json" \
   "$SRC/dictionary/phonex_encoded_words.json" \
   "$SRC/dictionary/pinyin_data.sqlite3" \
   "$SRC/dictionary/words_with_frequency_and_translation_and_ipa.sqlite3" "$R/"
cp "$SRC/src/phonex.js" "$R/"
cp "$SRC/him.icns" "$SRC/him.png" "$SRC/himTemplate.tiff" "$SRC/himGlyph@2x.pdf" "$R/"
cp "$SRC"/web/* "$R/web/"
cp "$SRC/en.lproj/InfoPlist.strings" "$R/en.lproj/"

# 偏好设置菜单：有完整 Xcode 就现编 xib，只有 Command Line Tools 就用仓库里预编译的
if xcrun --find ibtool >/dev/null 2>&1; then
    xcrun ibtool --compile "$R/PreferencesMenu.nib" "$SRC/PreferencesMenu.xib" >/dev/null
else
    cp "$SRC/prebuilt/PreferencesMenu.nib" "$R/PreferencesMenu.nib"
fi

printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> ad-hoc signing"
codesign --force --deep -s - "$APP"

echo "==> done: $APP"
