#!/bin/bash
# 安装本仓库构建出的输入法。先跑 build-standalone.sh 生成 build/hallelujah.app。
# 若系统里已有 hallelujah，会先备份到 ./hallelujah-原版备份.app，可用 rollback.sh 回滚。
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/build/hallelujah.app"
TARGET="/Library/Input Methods/hallelujah.app"
BACKUP="$DIR/hallelujah-原版备份.app"

[ -d "$APP" ] || { echo "构建产物不存在：$APP"; echo "先执行：bash build-standalone.sh"; exit 1; }

if [ -d "$TARGET" ] && [ ! -d "$BACKUP" ]; then
    echo "==> 备份已装版本到 $BACKUP"
    sudo cp -R "$TARGET" "$BACKUP"
    sudo chown -R "$(id -u):$(id -g)" "$BACKUP"
fi

echo "==> 停止正在运行的输入法"
pkill -9 hallelujah 2>/dev/null || true

echo "==> 安装"
sudo rm -rf "$TARGET"
sudo cp -R "$APP" "$TARGET"
sudo "$TARGET/Contents/MacOS/hallelujah" --install

# 系统常常在 rm/cp 还没做完时就把输入法重新拉起来，那样跑的仍是旧映像
# （表现为改动"没生效"）。文件都就位后再杀一次，下次启动才会加载新二进制。
sleep 1
pkill -9 hallelujah 2>/dev/null || true

echo ""
echo "完成。在 系统设置 › 键盘 › 输入法 里选择 hallelujah，敲几个字母试试。"
echo "若无反应，注销重登录一次（或移除后重新添加输入法）。"
[ -d "$BACKUP" ] && echo "回滚：bash \"$DIR/rollback.sh\""
