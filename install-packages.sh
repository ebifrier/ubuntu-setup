#!/bin/sh
#
# apt でよく使うパッケージを入れる。
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

# 基本セット
PACKAGES_BASE="tmux git curl wget build-essential ca-certificates"

# 開発ツール系 (global = GNU GLOBAL / gtags)
PACKAGES_DEV="global python3-pip unzip htop jq"

# 単語分割させたいので、ここは意図的にクォートしない。
# shellcheck disable=SC2086
apt_install $PACKAGES_BASE $PACKAGES_DEV
