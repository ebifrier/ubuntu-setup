#!/bin/sh
#
# git の global 設定 (user.name / user.email) を入れる。
# あわせて init.templateDir を設定し、Claude の Co-Authored-By を消す
# commit-msg フックを新しく clone / init するリポジトリに入れる。
#
#   install/install-git.sh                              # 既定値
#   install/install-git.sh ebifrier foo@example.com     # 名前とメールを指定
#
# 環境変数 GIT_USER_NAME / GIT_USER_EMAIL でも上書きできる。
#
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/lib/common.sh"

GIT_USER_NAME=${1:-${GIT_USER_NAME:-ebifrier}}
GIT_USER_EMAIL=${2:-${GIT_USER_EMAIL:-ebifrier@gmail.com}}

require_cmd git

git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"

# core.hooksPath だと各リポジトリの .git/hooks (husky など) が無効になるので、
# テンプレートで .git/hooks に配る。既存のリポジトリは中で `git init` すると入る。
TEMPLATE_DIR="$HOME/.config/git/template"
rm -rf "${TEMPLATE_DIR:?}"
mkdir -p "$(dirname "$TEMPLATE_DIR")"
cp -rf "$ROOT_DIR/config/git-template" "$TEMPLATE_DIR"
chmod +x "$TEMPLATE_DIR/hooks/"*
git config --global init.templateDir "$TEMPLATE_DIR"

log "git の global 設定を入れた: $GIT_USER_NAME <$GIT_USER_EMAIL>"
log "commit-msg フックのテンプレートを $TEMPLATE_DIR に配置した。"
