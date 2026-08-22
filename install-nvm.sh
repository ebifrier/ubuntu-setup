#!/bin/sh
#
# nvm (Node Version Manager) を入れて Node.js を入れる。
# nvm 本体は ~/.nvm に置かれ、.bashrc から読み込まれる。
#
#   ./install-nvm.sh         # nvm + Node.js LTS
#   ./install-nvm.sh 22      # nvm + Node.js 22 系
#   ./install-nvm.sh none    # nvm だけ (Node は入れない)
#
set -e

NVM_VERSION=v0.40.7
NODE_VERSION=${1:-lts}

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export NVM_DIR

if ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
    echo "curl か git が無い。先に ./install-packages.sh を実行する。" >&2
    exit 1
fi

curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash

# インストーラが profile を書けなかったときの保険 (未設定のときだけ追記)
if ! grep -q 'NVM_DIR' "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<'BASHRC'

# ubuntu-setup: nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
BASHRC
    echo "~/.bashrc に nvm の設定を追記した。"
fi

# このスクリプトの中で nvm を使えるようにする
. "$NVM_DIR/nvm.sh"

case "$NODE_VERSION" in
    none)
        echo "Node.js は入れない。'nvm install --lts' で後から入れられる。"
        ;;
    lts)
        nvm install --lts
        nvm alias default 'lts/*'
        ;;
    *)
        nvm install "$NODE_VERSION"
        nvm alias default "$NODE_VERSION"
        ;;
esac

nvm --version
if [ "$NODE_VERSION" != "none" ]; then
    node --version
    npm --version
fi

echo
echo "新しいシェルを開くと nvm / node が使える。"
