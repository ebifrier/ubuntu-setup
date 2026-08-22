#!/bin/sh
#
# git の global 設定 (user.name / user.email) を入れる。
#
#   ./install-git.sh                              # 既定値
#   ./install-git.sh ebifrier foo@example.com     # 名前とメールを指定
#
# 環境変数 GIT_USER_NAME / GIT_USER_EMAIL でも上書きできる。
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

GIT_USER_NAME=${1:-${GIT_USER_NAME:-ebifrier}}
GIT_USER_EMAIL=${2:-${GIT_USER_EMAIL:-ebifrier@gmail.com}}

require_cmd git

git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"

log "git の global 設定を入れた: $GIT_USER_NAME <$GIT_USER_EMAIL>"
