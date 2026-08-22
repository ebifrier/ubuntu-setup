#!/bin/sh
#
# config/ の隠しファイル (.emacs / .emacs.d / .screenrc / .tmux.conf) を
# $HOME にそのまま配置し、bin/ec を /usr/local/bin に入れる。
#
# config/ 直下のドットで始まるものは全部配るので、dotfile を足したいときは
# config/ に置くだけでよい (mise.toml のような通常ファイルは対象外)。
#
# ※ RECREATE のディレクトリは毎回作り直すので、ローカルの変更は消える。
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

CONFIG_DIR="$SCRIPT_DIR/config"

# 中途半端に混ざると困るので、毎回消してから入れ直すもの。
RECREATE=".emacs.d"

for _dir in $RECREATE; do
    rm -rf "$HOME/$_dir"
done

for _src in "$CONFIG_DIR"/.[!.]*; do
    [ -e "$_src" ] || continue
    cp -af "$_src" "$HOME/"
    log "$HOME/$(basename "$_src") を配置した。"
done

sudo cp -f "$SCRIPT_DIR/bin/ec" /usr/local/bin/
sudo chmod +x /usr/local/bin/ec
