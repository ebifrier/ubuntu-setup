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

# Linux 版のサンドボックスは bubblewrap (bwrap) で切る。
# Ubuntu 24.04 以降は AppArmor が非特権の user namespace を止めているので、
# apparmor パッケージ同梱の bwrap 用プロファイルを読み込み直して bwrap にだけ許す
# (bwrap を後から入れた場合、読み込み直さないとプロファイルが効いていない)。
# AppArmor の無い環境 (WSL や LXC など) では飛ばす。
apt_install bubblewrap

BWRAP_PROFILE=/etc/apparmor.d/bwrap-userns-restrict
if [ -f "$BWRAP_PROFILE" ] && command -v apparmor_parser >/dev/null 2>&1; then
    sudo apparmor_parser -r "$BWRAP_PROFILE" ||
        warn "$BWRAP_PROFILE の読み込みに失敗した。codex のサンドボックスが動かないかもしれない。"
fi

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
