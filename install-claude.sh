#!/bin/sh
#
# Claude Code を公式のネイティブインストーラで入れる。
# バイナリは ~/.local/share/claude/ に置かれ、~/.local/bin/claude から起動する。
# ネイティブ版はバックグラウンドで自動更新される。
#
#   ./install-claude.sh           # latest チャンネル
#   ./install-claude.sh stable    # stable チャンネル (約1週間遅れ)
#   ./install-claude.sh 2.1.89    # バージョン指定
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

CHANNEL=${1:-latest}
LOCAL_BIN="$HOME/.local/bin"

if ! command -v curl >/dev/null 2>&1; then
    echo "curl が無い。先に ./install-packages.sh を実行する。" >&2
    exit 1
fi

curl -fsSL https://claude.ai/install.sh | bash -s "$CHANNEL"

# ~/.local/bin を PATH に通す (lib/common.sh)
ensure_local_bin

"$LOCAL_BIN/claude" --version

echo
echo "初回はログインが必要。'claude' を起動してブラウザの指示に従う。"
