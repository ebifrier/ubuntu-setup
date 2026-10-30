#!/bin/sh
#
# config/ の隠しファイル (.tmux.conf) を $HOME にそのまま配置する。
#
# config/ 直下のドットで始まるものは全部配るので、dotfile を足したいときは
# config/ に置くだけでよい (通常ファイルは対象外)。
#
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/lib/common.sh"

CONFIG_DIR="$ROOT_DIR/config"

for _src in "$CONFIG_DIR"/.[!.]*; do
    [ -e "$_src" ] || continue
    cp -af "$_src" "$HOME/"
    log "$HOME/$(basename "$_src") を配置した。"
done
