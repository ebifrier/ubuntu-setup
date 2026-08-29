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
wsl:install-wsl.sh:WSL の設定 (/etc/wsl.conf と VS Code 用マウント。WSL のみ)
locale:install-locale.sh:ja_JP.UTF-8 ロケールと Asia/Tokyo タイムゾーン
packages:install-packages.sh:apt パッケージ
dotfiles:install-dotfiles.sh:dotfiles の配置
git:install-git.sh:git の global 設定 (user.name / user.email)
gh:install-gh.sh:GitHub CLI (gh)
awscli:install-awscli.sh:AWS CLI v2
docker:install-docker.sh:Docker Engine
nvidia:install-nvidia.sh:NVIDIA ドライバ (GPU 付き LXC のみ)
mise:install-mise.sh:mise + Node.js / pnpm
claude:install-claude.sh:Claude Code
rtk:install-rtk.sh:rtk (Claude Code のトークン削減プロキシ)
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
        [ -n "$name" ] || continue
        echo "$name"
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
