#!/bin/sh
#
# ubuntu 環境のセットアップ。
#
#   ./setup.sh                # 全部 (STEPS の順に実行)
#   ./setup.sh docker         # 特定のステップだけ
#   ./setup.sh docker mise    # 複数指定も可 (指定した順に実行)
#   ./setup.sh -h             # ステップ一覧
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

# ステップの定義。all の実行順もこの並び。
# 名前:スクリプト:説明
STEPS='
locale:install-locale.sh:ja_JP.UTF-8 ロケール
packages:install-packages.sh:apt パッケージ
dotfiles:install-dotfiles.sh:dotfiles の配置
docker:install-docker.sh:Docker Engine
mise:install-mise.sh:mise + Node.js / pnpm
claude:install-claude.sh:Claude Code
claude-config:install-claude-config.sh:.claude 設定の配置
'

usage() {
    warn "usage: $0 [all|<step>...]"
    warn ""
    warn "  all             全部を上から順に実行 (既定)"
    echo "$STEPS" | while IFS=: read -r name script desc; do
        [ -n "$name" ] || continue
        printf '  %-15s %s\n' "$name" "$desc" >&2
    done
}

# ステップ名からスクリプト名を引く。無ければ空を返す。
step_script() {
    echo "$STEPS" | while IFS=: read -r name script desc; do
        [ "$name" = "$1" ] || continue
        echo "$script"
        break
    done
}

run_step() {
    _script=$(step_script "$1")
    [ -n "$_script" ] || { warn "unknown step: $1"; usage; exit 1; }
    "$SCRIPT_DIR/$_script" </dev/null
}

run_all() {
    _names=$(echo "$STEPS" | while IFS=: read -r name script desc; do
        [ -n "$name" ] && echo "$name"
    done)
    for _name in $_names; do
        run_step "$_name"
    done
}

case "${1:-all}" in
    -h|--help|help)
        usage
        exit 0
        ;;
    all)
        [ $# -le 1 ] || { warn "all と個別ステップは同時に指定できない"; exit 1; }
        run_all
        ;;
    *)
        for _arg in "$@"; do
            run_step "$_arg"
        done
        ;;
esac
