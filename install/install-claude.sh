#!/bin/sh
#
# Claude Code を公式のネイティブインストーラで入れる。
# バイナリは ~/.local/share/claude/ に置かれ、~/.local/bin/claude から起動する。
# ネイティブ版はバックグラウンドで自動更新される。
#
#   install/install-claude.sh           # latest チャンネル
#   install/install-claude.sh stable    # stable チャンネル (約1週間遅れ)
#   install/install-claude.sh 2.1.89    # バージョン指定
#
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/lib/common.sh"

CHANNEL=${1:-latest}
LOCAL_BIN="$HOME/.local/bin"

require_cmd curl

curl -fsSL https://claude.ai/install.sh | bash -s "$CHANNEL"

# ~/.local/bin を PATH に通す (lib/common.sh)
ensure_local_bin

"$LOCAL_BIN/claude" --version

note "claude の初回はログインが必要。'claude' を起動してブラウザの指示に従う。"
