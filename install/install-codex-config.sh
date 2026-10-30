#!/bin/sh
#
# $USER の Codex 開発用設定・RTK の共通指示・agent-skills を配置する。
# codex / rtk 本体は install-codex.sh / install-rtk.sh で入れておくこと。
#
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/lib/common.sh"

require_cmd getent
[ -n "${USER:-}" ] || die 'USER が未設定。設定先のユーザーを指定する。'
USER_HOME=$(getent passwd "$USER" | cut -d: -f6)
case "$USER_HOME" in
    /*) ;;
    *) die "$USER のホームディレクトリを取得できなかった。" ;;
esac

CODEX_DIR=${CODEX_HOME:-$USER_HOME/.codex}
case "$CODEX_DIR" in
    /*) ;;
    *) die 'CODEX_HOME は絶対パスで指定する。' ;;
esac

# 全ステップ実行中は .bashrc の PATH がまだ反映されていないことがある。
PATH="$USER_HOME/.local/bin:$PATH"
export PATH
require_cmd rtk

# Ubuntu のシステム Python を使い、pyenv 等で入れた Python との混在を避ける。
if ! /usr/bin/python3 -c 'import tomlkit' >/dev/null 2>&1; then
    apt_install python3 python3-tomlkit
fi

/usr/bin/python3 "$ROOT_DIR/lib/codex-config.py" "$CODEX_DIR" "$USER_HOME"

# Claude と共通の skill を Codex のユーザースキル置き場に入れる。
# 利用者が自分で置いた skill は残し、リポジトリにある名前のものだけ入れ替える。
SKILLS_DIR="$USER_HOME/.agents/skills"
mkdir -p "$SKILLS_DIR"
for _skill in "$ROOT_DIR"/agent-skills/*/; do
    _name=$(basename "$_skill")
    rm -rf "${SKILLS_DIR:?}/$_name"
    cp -rf "$_skill" "$SKILLS_DIR/$_name"
done

# Codex 用は AGENTS.md + RTK.md。Claude 用フックには触れない。
# RTK のグローバル初期化にも同じユーザーと CODEX_HOME を渡す。
HOME="$USER_HOME" CODEX_HOME="$CODEX_DIR" rtk init --codex --global

# override があると AGENTS.md は読まれないため、そちらにも参照を追加する。
OVERRIDE="$CODEX_DIR/AGENTS.override.md"
if [ -s "$OVERRIDE" ] && ! grep -qxF "@$CODEX_DIR/RTK.md" "$OVERRIDE"; then
    [ -e "$OVERRIDE.bak" ] || cp -p "$OVERRIDE" "$OVERRIDE.bak"
    printf '\n@%s/RTK.md\n' "$CODEX_DIR" >> "$OVERRIDE"
fi

log "$CODEX_DIR に Codex の開発用設定を配置した。"
note "Codex の設定と RTK の共通指示は次回の Codex 起動から有効。'rtk gain' で削減量を見られる。"
