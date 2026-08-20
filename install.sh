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

# 注意：这里刻意不调用 --deactivate。声明了输入模式之后，TISDisableInputSource
# 会把输入法从系统的启用列表（AppleEnabledInputSources）里摘掉，而 --install 里的
# TISEnableInputSource 加不回来——API 返回成功，列表却始终没有它。结果就是重装完
# 输入法从菜单里消失，只能去「系统设置 › 键盘 › 输入法」手动重新添加一次。
# 覆盖安装本身不需要先注销。

echo "==> 停止正在运行的输入法"
pkill -9 hallelujah 2>/dev/null || true

echo "==> 安装"
sudo rm -rf "$TARGET"
sudo cp -R "$APP" "$TARGET"
# 让 HIToolbox 丢掉缓存的输入源信息，再重新注册
killall -HUP cfprefsd 2>/dev/null || true
"$TARGET/Contents/MacOS/hallelujah" --install

# 系统常常在 rm/cp 还没做完时就把输入法重新拉起来，那样跑的仍是旧映像
# （表现为改动"没生效"）。文件都就位后再杀一次，下次启动才会加载新二进制。
sleep 1
pkill -9 hallelujah 2>/dev/null || true

echo ""
echo "完成。在 系统设置 › 键盘 › 输入法 里选择 hallelujah，敲几个字母试试。"
echo "若无反应，注销重登录一次（或移除后重新添加输入法）。"
[ -d "$BACKUP" ] && echo "回滚：bash \"$DIR/rollback.sh\""
