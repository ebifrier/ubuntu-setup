#!/bin/sh
#
# rtk (Rust Token Killer) を公式インストーラで入れる。
# バイナリは ~/.local/bin/rtk に置かれる。
#
#   ./install-rtk.sh          # 最新版
#   ./install-rtk.sh v0.28.2  # バージョン指定
#
# Claude Code からは .claude/settings.json の PreToolUse フック
# (rtk 本体の `rtk hook claude`) 経由で呼ばれる。登録は
# install-claude-config.sh が配置する settings.json に入っている。
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

INSTALL_URL="https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
LOCAL_BIN="$HOME/.local/bin"
VERSION=${1:-}

require_cmd curl

# インストーラは RTK_INSTALL_DIR / RTK_VERSION を見る。
# 版を指定しないときは GitHub の latest を取りに行く。
curl -fsSL "$INSTALL_URL" |
    RTK_INSTALL_DIR="$LOCAL_BIN" RTK_VERSION="$VERSION" sh

# ~/.local/bin を PATH に通す (lib/common.sh)
ensure_local_bin

"$LOCAL_BIN/rtk" --version

note "rtk のフックは claude の再起動から有効。'rtk gain' で削減量を見られる。"
