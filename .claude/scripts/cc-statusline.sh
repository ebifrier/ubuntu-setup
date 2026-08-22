#!/usr/bin/env bash
# Claude Code statusline wrapper
# - ccusage statusline (model / today / 5h block / burn / context %)
# - + 1週間の合計コスト
# - + 5時間ブロックの経過時間 %
set -uo pipefail

INPUT=$(cat)

CCUSAGE_BIN="${CCUSAGE_BIN:-ccusage}"
CACHE_DIR="${HOME}/.cache/ccusage-statusline"
WEEK_CACHE="${CACHE_DIR}/week.json"
BLOCK_CACHE="${CACHE_DIR}/block.json"
WEEK_TTL=300
BLOCK_TTL=60

mkdir -p "$CACHE_DIR"

is_fresh() {
  local f=$1 ttl=$2 mtime now
  [[ -s "$f" ]] || return 1
  mtime=$(stat -c %Y "$f" 2>/dev/null) || return 1
  now=$(date +%s)
  (( now - mtime < ttl ))
}

refresh_cache() {
  local f=$1; shift
  local out
  if out=$("$CCUSAGE_BIN" "$@" 2>/dev/null) && [[ -n "$out" ]]; then
    printf '%s' "$out" > "${f}.tmp" && mv "${f}.tmp" "$f"
  fi
}

is_fresh "$WEEK_CACHE" "$WEEK_TTL"   || refresh_cache "$WEEK_CACHE" weekly --json --offline
is_fresh "$BLOCK_CACHE" "$BLOCK_TTL" || refresh_cache "$BLOCK_CACHE" blocks --active --json --offline

WEEK_COST=$(jq -r '
  (.weekly // []) | if length == 0 then "0.00"
  else (last.totalCost // 0) | (. * 100 | floor) / 100 | tostring
  end
' "$WEEK_CACHE" 2>/dev/null)
[[ -z "${WEEK_COST:-}" ]] && WEEK_COST="?"

BLOCK_PCT=$(jq -r '
  ((.blocks // []) | map(select(.isActive == true)))[0] as $b |
  if $b == null or ($b.startTime // null) == null then "—"
  else
    ($b.startTime | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) as $start |
    ((now - $start) / 180 | floor) as $pct |
    ((if $pct < 0 then 0 elif $pct > 100 then 100 else $pct end) | tostring) + "%"
  end
' "$BLOCK_CACHE" 2>/dev/null)
[[ -z "${BLOCK_PCT:-}" ]] && BLOCK_PCT="—"

MAIN=$(printf '%s' "$INPUT" | "$CCUSAGE_BIN" statusline --offline 2>/dev/null)
[[ -z "${MAIN:-}" ]] && MAIN="🤖 (ccusage init…)"

printf '%s | ⏱ %s of 5h | 📅 $%s week\n' "$MAIN" "$BLOCK_PCT" "$WEEK_COST"
