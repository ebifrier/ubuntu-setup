#!/bin/sh
#
# dotfiles (.emacs / .emacs.d / .screenrc / .tmux.conf) を $HOME に配置し、
# bin/ec を /usr/local/bin に入れる。
#
# ※ $HOME/.emacs.d は毎回作り直すので、ローカルの変更は消える。
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

if [ -d "$HOME/.emacs.d" ]; then
    rm -rf "$HOME/.emacs.d"
fi
cp -rf "$SCRIPT_DIR/.emacs.d" "$HOME/"
cp -f "$SCRIPT_DIR/.emacs" "$HOME/"
cp -f "$SCRIPT_DIR/.screenrc" "$HOME/"
cp -f "$SCRIPT_DIR/.tmux.conf" "$HOME/"

sudo cp -f "$SCRIPT_DIR/bin/ec" /usr/local/bin/
sudo chmod +x /usr/local/bin/ec

log "$HOME に dotfiles を配置した。"
