#!/bin/sh
#
# GitHub CLI (gh) を公式 apt リポジトリから入れる。
# Ubuntu 同梱の gh は版が古いので、こちらを使う。
#
#   ./install-gh.sh
#
# 認証は入れたあとに `gh auth login` を手で通す。
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

apt_install ca-certificates curl

# GPG 鍵。配布されているのは armor ではなくバイナリの keyring なので、
# docker のように gpg --dearmor は通さずそのまま置く。
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
    sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
sudo chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

# リポジトリ。ディストリの版に依らず stable main の1本だけ。
ARCH=$(dpkg --print-architecture)
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

apt_update force
apt_install gh

gh --version

if ! gh auth status >/dev/null 2>&1; then
    note "gh はまだ未認証。使う前に gh auth login を通す。"
fi
