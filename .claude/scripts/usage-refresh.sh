#!/usr/bin/env bash
# claude.ai の /api/oauth/usage からモデル別の週次使用率を取得してキャッシュする。
#
# statusline.sh からバックグラウンドで呼ばれる想定（単独実行も可）。
# statusline は最短 300ms 間隔で実行されるため、ここを同期的に呼んではいけない。
#
# 注意: /api/oauth/usage は Claude Code が内部利用している非公開エンドポイント。
#       レスポンス形状やトークンの持ち方が変わると黙って動かなくなる（その場合は "—" 表示）。
# 依存: jq, curl
set -uo pipefail

CACHE_DIR="$HOME/.claude/cache"
CACHE="$CACHE_DIR/model-usage.json"
LOCK="$CACHE_DIR/model-usage.lock"
CREDS="$HOME/.claude/.credentials.json"
API="https://api.anthropic.com/api/oauth/usage"

command -v jq >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0
mkdir -p "$CACHE_DIR" || exit 0

now=$(date +%s)

# 二重起動防止。noclobber でロックをアトミックに取り、5分以上前の残骸は捨てる。
if ! (set -o noclobber; : >"$LOCK") 2>/dev/null; then
  lock_mtime=$(stat -c %Y "$LOCK" 2>/dev/null || echo "$now")
  if ((now - lock_mtime > 300)); then
    rm -f "$LOCK"
  fi
  exit 0
fi
trap 'rm -f "$LOCK"' EXIT

[[ -r "$CREDS" ]] || exit 0

# キー名の変更に耐えるよう accessToken を再帰探索で取り出す
TOKEN=$(jq -r '[.. | objects | .accessToken? // empty] | first // empty' "$CREDS" 2>/dev/null)
[[ -n "$TOKEN" ]] || exit 0

RESP=$(curl -fsS --max-time 8 "$API" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" 2>/dev/null) || exit 0

# limits[] のうち「モデル別の週次枠」だけを抜き出して保存する。
# percent は 0〜100（five_hour.utilization の 0〜1 とは単位が違う）。
printf '%s' "$RESP" | jq -c --argjson now "$now" '
  {
    fetched_at: $now,
    models: [
      (.limits // [])[]
      | select(.kind == "weekly_scoped")
      | select((.scope.model.display_name // "") != "")
      | {
          name: .scope.model.display_name,
          percent: .percent,
          resets_at: .resets_at,
        }
    ],
  }
' >"$CACHE.tmp" 2>/dev/null || { rm -f "$CACHE.tmp"; exit 0; }

mv -f "$CACHE.tmp" "$CACHE"
