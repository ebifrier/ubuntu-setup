#!/bin/sh
#
# AWS CLI v2 を公式の zip インストーラで入れる。
# Ubuntu 同梱の awscli は v1 で版も古いので、こちらを使う。
#
#   ./install-awscli.sh           # 最新版
#   ./install-awscli.sh 2.27.54   # バージョン指定
#
# /usr/local/aws-cli に入り、/usr/local/bin/aws から辿れるようになる。
# 認証情報は入れたあとに `aws configure` を手で通す。
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

INSTALL_DIR=/usr/local/aws-cli
BIN_DIR=/usr/local/bin
VERSION=${1:-}

apt_install ca-certificates curl unzip

# zip の名前は awscli-exe-linux-<arch>[-<version>].zip。
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|aarch64) ;;
    arm64) ARCH=aarch64 ;;
    *) die "AWS CLI v2 が対応していない CPU: $ARCH" ;;
esac

if [ -n "$VERSION" ]; then
    URL="https://awscli.amazonaws.com/awscli-exe-linux-$ARCH-$VERSION.zip"
else
    URL="https://awscli.amazonaws.com/awscli-exe-linux-$ARCH.zip"
fi

# common.sh が EXIT に print_notes を張っているので、trap は使わずに片付ける。
WORK_DIR=$(mktemp -d)

curl -fsSL "$URL" -o "$WORK_DIR/awscliv2.zip"
unzip -q "$WORK_DIR/awscliv2.zip" -d "$WORK_DIR"

# 入れ直しのときは --update を付けないとインストーラが止まる。
if [ -d "$INSTALL_DIR" ]; then
    UPDATE=--update
else
    UPDATE=
fi

# shellcheck disable=SC2086  # UPDATE は空なら渡さない
sudo "$WORK_DIR/aws/install" --install-dir "$INSTALL_DIR" --bin-dir "$BIN_DIR" $UPDATE

rm -rf "$WORK_DIR"

aws --version

if [ ! -f "$HOME/.aws/credentials" ] && [ ! -f "$HOME/.aws/config" ]; then
    note "aws はまだ未設定。使う前に aws configure を通す。"
fi
