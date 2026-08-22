#!/bin/sh
#
# 日本語ロケール (ja_JP.UTF-8) を生成して既定にする。
#
#   ./install-locale.sh                # ja_JP.UTF-8
#   ./install-locale.sh en_US.UTF-8    # ロケール指定
#
set -e

LOCALE=${1:-ja_JP.UTF-8}

export DEBIAN_FRONTEND=noninteractive

# cloud image には locales が入っていないことがある。
if ! command -v locale-gen >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y locales
fi

sudo locale-gen "$LOCALE"
sudo update-locale LANG="$LOCALE"

echo
echo "LANG=$LOCALE にした。反映は次のログインから (今のシェルなら export LANG=$LOCALE)。"
