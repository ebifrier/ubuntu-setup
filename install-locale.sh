#!/bin/sh
#
# 日本語ロケール (ja_JP.UTF-8) を生成して既定にし、タイムゾーンを設定する。
#
#   ./install-locale.sh                          # ja_JP.UTF-8 / Asia/Tokyo
#   ./install-locale.sh en_US.UTF-8 Asia/Tokyo   # ロケールとタイムゾーンを指定
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

LOCALE=${1:-ja_JP.UTF-8}
TIMEZONE=${2:-Asia/Tokyo}

# cloud image には locales が入っていないことがある。
if ! command -v locale-gen >/dev/null 2>&1; then
    apt_install locales
fi

sudo locale-gen "$LOCALE"
sudo update-locale LANG="$LOCALE"

log "LANG=$LOCALE にした。"

# タイムゾーン。LXC コンテナでは timedatectl が使えないことがあるので
# /etc/localtime と /etc/timezone を直接書く。
if [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
    apt_install tzdata
fi
[ -f "/usr/share/zoneinfo/$TIMEZONE" ] || die "タイムゾーンが見つからない: $TIMEZONE"

if [ "$(cat /etc/timezone 2>/dev/null)" = "$TIMEZONE" ]; then
    log "タイムゾーンは既に $TIMEZONE。"
else
    sudo ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    echo "$TIMEZONE" | sudo tee /etc/timezone >/dev/null
    log "タイムゾーンを $TIMEZONE にした。"
fi

note "LANG=$LOCALE の反映は次のログインから (今のシェルなら export LANG=$LOCALE)。"
