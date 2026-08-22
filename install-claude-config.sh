#!/bin/sh
#
# .claude 以下の設定を $HOME/.claude に配置する。
# claude 本体は install-claude.sh で入れておくこと。
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

SRC="$SCRIPT_DIR/.claude"
DEST="$HOME/.claude"

mkdir -p "$DEST"

# 設定ファイル。セッション履歴やキャッシュは持ち込まない。
cp -f "$SRC/CLAUDE.md" "$SRC/RTK.md" "$SRC/settings.json" "$DEST/"
for d in rules skills hooks scripts; do
    rm -rf "$DEST/$d"
    cp -rf "$SRC/$d" "$DEST/"
done
chmod +x "$DEST/scripts/"*.sh "$DEST/hooks/"*.sh

# プラグイン (joseki など) と MCP サーバーは settings.json の
# enabledPlugins / extraKnownMarketplaces を見て claude 起動時に自動で入る。
log "$DEST に設定を配置した。claude を起動するとプラグインが取得される。"
