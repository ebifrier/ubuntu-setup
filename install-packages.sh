#!/bin/sh
#
# apt でよく使うパッケージを入れる。
#
set -e

# 基本セット
PACKAGES_BASE="screen tmux emacs-nox git curl wget build-essential ca-certificates"

# 開発ツール系 (global = GNU GLOBAL / gtags)
PACKAGES_DEV="global python3-pip unzip htop"

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y $PACKAGES_BASE $PACKAGES_DEV
