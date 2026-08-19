#!/bin/bash
# 回滚到 install.sh 备份下来的那一版
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="/Library/Input Methods/hallelujah.app"
BACKUP="$DIR/hallelujah-原版备份.app"

[ -d "$BACKUP" ] || { echo "找不到备份：$BACKUP"; exit 1; }

pkill -9 hallelujah 2>/dev/null || true
sudo rm -rf "$TARGET"
sudo cp -R "$BACKUP" "$TARGET"
sudo chown -R root:wheel "$TARGET"
sudo "$TARGET/Contents/MacOS/hallelujah" --install

echo "已回滚。"
