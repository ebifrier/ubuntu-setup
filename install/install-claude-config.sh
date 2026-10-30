#!/bin/sh
#
# .claude 以下の設定と agent-skills を $HOME/.claude に配置する。
# claude 本体は install-claude.sh で入れておくこと。
#
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/lib/common.sh"

SRC="$ROOT_DIR/.claude"
DEST="$HOME/.claude"

require_cmd jq

# 全ステップ実行中は .bashrc の PATH がまだ反映されていないことがある。
PATH="$HOME/.local/bin:$PATH"
export PATH
HAS_CLAUDE=
command -v claude >/dev/null 2>&1 && HAS_CLAUDE=1

mkdir -p "$DEST"

# joseki プラグインは廃止した。中身の一部は agent-skills/ と .claude/skills/ に移してある。
# settings.json をマージする前に、claude 側の登録とキャッシュを外しておく。
if [ -n "$HAS_CLAUDE" ]; then
    if claude plugin list --json 2>/dev/null |
        jq -e 'any(.[]; .id == "joseki@joseki" and .scope == "user")' >/dev/null; then
        claude plugin uninstall joseki@joseki --scope user
    fi
    if claude plugin marketplace list --json 2>/dev/null |
        jq -e 'any(.[]; .name == "joseki")' >/dev/null; then
        claude plugin marketplace remove joseki
    fi
fi

# 設定ファイル。セッション履歴やキャッシュは持ち込まない。
cp -f "$SRC/CLAUDE.md" "$SRC/RTK.md" "$DEST/"

# settings.json は claude 側でも書き足される (autoMode, modelSettings など) ので、
# 既存のものにリポジトリ側を重ねる。キーが被ればリポジトリ側が勝つ。
# 配列は要素ごとではなく丸ごと置き換わる。
# 重ねるだけでは消えないので、廃止した joseki の登録はここで消す。
if [ -f "$DEST/settings.json" ]; then
    _tmp="$DEST/settings.json.tmp"
    jq -s '.[0] * .[1]
        | del(.enabledPlugins["joseki@joseki"], .extraKnownMarketplaces.joseki)' \
        "$DEST/settings.json" "$SRC/settings.json" >"$_tmp" ||
        { rm -f "$_tmp"; die "$DEST/settings.json をマージできなかった。"; }
    mv -f "$_tmp" "$DEST/settings.json"
else
    cp -f "$SRC/settings.json" "$DEST/"
fi
for d in rules scripts; do
    # DEST が空でも / を消しに行かないように :? を噛ませる。
    rm -rf "${DEST:?}/$d"
    cp -rf "$SRC/$d" "$DEST/"
done

# skills/synced は claude.ai のアカウントから同期されるスキルなので残し、
# それ以外を入れ替える。agent-skills/ は Codex と共通、.claude/skills/ は Claude 専用。
mkdir -p "$DEST/skills"
find "${DEST:?}/skills" -mindepth 1 -maxdepth 1 ! -name synced -exec rm -rf {} +
cp -rf "$ROOT_DIR/agent-skills/." "$DEST/skills/"
cp -rf "$SRC/skills/." "$DEST/skills/"
chmod +x "$DEST/scripts/"*.sh

# context7 MCP は以前 joseki が持っていたので、ユーザースコープで登録する。
if [ -n "$HAS_CLAUDE" ]; then
    claude mcp get context7 >/dev/null 2>&1 ||
        claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp
else
    note "claude が無いので context7 MCP を登録していない。install-claude.sh のあとで claude-config をもう一度実行する。"
fi

# プラグイン (claude-plugins-official) は settings.json の
# enabledPlugins / extraKnownMarketplaces を見て claude 起動時に自動で入る。
log "$DEST に設定を配置した。claude を起動するとプラグインが取得される。"
