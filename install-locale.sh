#!/bin/sh
#
# 日本語ロケール (ja_JP.UTF-8) を生成して既定にする。
#
#   ./install-locale.sh                # ja_JP.UTF-8
#   ./install-locale.sh en_US.UTF-8    # ロケール指定
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

LOCALE=${1:-ja_JP.UTF-8}

# cloud image には locales が入っていないことがある。
if ! command -v locale-gen >/dev/null 2>&1; then
    apt_install locales
fi

sudo locale-gen "$LOCALE"
sudo update-locale LANG="$LOCALE"

log "LANG=$LOCALE にした。"
note "LANG=$LOCALE の反映は次のログインから (今のシェルなら export LANG=$LOCALE)。"
