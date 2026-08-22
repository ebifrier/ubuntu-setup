#!/bin/sh
#
# rtk (Rust Token Killer) を公式インストーラで入れる。
# バイナリは ~/.local/bin/rtk に置かれる。
#
#   ./install-rtk.sh          # 最新版
#   ./install-rtk.sh v0.28.2  # バージョン指定
#
# Claude Code からは .claude/settings.json の PreToolUse フック
# (~/.claude/hooks/rtk-rewrite.sh) 経由で呼ばれる。フックの実体は
# install-claude-config.sh が配置し、動作には jq が要る。
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

# フックが rtk rewrite の入出力を組み立てるのに使う。
if ! command -v jq >/dev/null 2>&1; then
    note "jq が無いと Claude Code の rtk フックは何もしない。./setup.sh packages を流す。"
fi

note "rtk のフックは claude の再起動から有効。'rtk gain' で削減量を見られる。"
