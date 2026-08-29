#!/bin/sh
#
# Codex CLI (OpenAI) を公式インストーラで入れる。
# バイナリは ~/.codex/packages/standalone/ に置かれ、
# ~/.local/bin/codex から起動する。
#
#   ./install-codex.sh            # 最新版
#   ./install-codex.sh 0.150.1    # バージョン指定
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

INSTALL_URL="https://releases.openai.com/codex/install.sh"
LOCAL_BIN="$HOME/.local/bin"
RELEASE=${1:-latest}

require_cmd curl

# ~/.local/bin を PATH に通す (lib/common.sh)。
# 先にこのプロセスの PATH にも入れておくと、公式インストーラが
# 自前の PATH ブロックを .bashrc に足さずに済む。
ensure_local_bin
case ":$PATH:" in
    *":$LOCAL_BIN:"*) ;;
    *) PATH="$LOCAL_BIN:$PATH"; export PATH ;;
esac

# インストーラは CODEX_INSTALL_DIR / CODEX_RELEASE を見る。
# CODEX_NON_INTERACTIVE で「今すぐ起動するか」の問い合わせを止める
# (/dev/tty を直接読むので、リダイレクトだけでは黙らせられない)。
curl -fsSL "$INSTALL_URL" |
    CODEX_INSTALL_DIR="$LOCAL_BIN" \
    CODEX_RELEASE="$RELEASE" \
    CODEX_NON_INTERACTIVE=1 sh

"$LOCAL_BIN/codex" --version

note "codex の初回はログインが必要。'codex' を起動してブラウザの指示に従う。"
