#!/usr/bin/env bash
# Claude Code statusline
# 表示: モデル / コンテキスト % / 5時間使用率 % / 7日使用率 % / セッションコスト
#
# コンテキスト・5h・7d は公式 JSON フィールド。
# ただし Fable 選択中の Usage(7d) は、全体週次枠ではなく Fable 専用の週次枠
# (weekly_scoped) を表示する。この値は公式 JSON に含まれないため、
# usage-refresh.sh が作るキャッシュから読む (取得は非同期。詳細は同スクリプト)。
# 依存: jq
set -uo pipefail

input=$(cat)

# jq で必要なフィールドを TSV 一発取得 (フィールド欠落時はフォールバック値)
IFS=$'\t' read -r MODEL CTX FIVEH FIVEH_RESET SEVEND SEVEND_RESET COST API_MS LINES_ADD LINES_DEL <<EOF
$(printf '%s' "$input" | jq -r '[
  (.model.display_name                       // "Claude"),
  (.context_window.used_percentage           // 0),
  (.rate_limits.five_hour.used_percentage    // "—"),
  (.rate_limits.five_hour.resets_at          // 0),
  (.rate_limits.seven_day.used_percentage    // "—"),
  (.rate_limits.seven_day.resets_at          // 0),
  (.cost.total_cost_usd                      // 0),
  (.cost.total_api_duration_ms               // 0),
  (.cost.total_lines_added                   // 0),
  (.cost.total_lines_removed                 // 0)
] | @tsv' 2>/dev/null)
EOF

now=$(date +%s)

# 5h / 7d リセットまでの残り時間 (分 / 時間)
fmt_left() {
  local target=$1 unit=$2
  if [[ -z "$target" || "$target" == "0" ]]; then
    printf -- "—"
    return
  fi
  if (( target <= now )); then
    printf "0%s" "$unit"
    return
  fi
  case "$unit" in
    m) printf "%dm" $(( (target - now + 59) / 60 )) ;;
    h) printf "%dh" $(( (target - now + 3599) / 3600 )) ;;
  esac
}
LEFT5H=$(fmt_left "$FIVEH_RESET"  m)
LEFT7D=$(fmt_left "$SEVEND_RESET" h)

# Fable 専用の週次枠 (公式 JSON に無いので自前キャッシュ経由)
USAGE_CACHE="$HOME/.claude/cache/model-usage.json"
USAGE_TTL=180
USAGE_REFRESH="$HOME/.claude/scripts/usage-refresh.sh"

# キャッシュが無い / 古いときだけバックグラウンドで更新する。
# statusline は最短 300ms 間隔で走るので、ここで待ってはいけない。
if [[ -x "$USAGE_REFRESH" ]]; then
  cache_mtime=$(stat -c %Y "$USAGE_CACHE" 2>/dev/null || echo 0)
  if ((now - cache_mtime > USAGE_TTL)); then
    (setsid "$USAGE_REFRESH" >/dev/null 2>&1 </dev/null &) 2>/dev/null ||
      ("$USAGE_REFRESH" >/dev/null 2>&1 </dev/null &)
  fi
fi

# Fable 選択中は Usage(7d) を Fable 専用の週次枠 (weekly_scoped) に差し替える。
# 同じ週次同士なのでラベルは 7d のまま。キャッシュ欠落時は従来の全体週次枠へフォールバック。
if [[ "${MODEL,,}" == *fable* && -f "$USAGE_CACHE" ]]; then
  IFS=$'\t' read -r FABLE_PCT FABLE_RESET <<EOF
$(jq -r '
    [ (.models // [])[] | select((.name | ascii_downcase) == "fable") | select(.percent != null) ]
    | first // empty
    | [ (.percent | floor), (.resets_at // "") ] | @tsv
  ' "$USAGE_CACHE" 2>/dev/null)
EOF
  if [[ -n "${FABLE_PCT:-}" ]]; then
    SEVEND=$FABLE_PCT
    fable_reset_epoch=$(date -d "$FABLE_RESET" +%s 2>/dev/null || echo 0)
    LEFT7D=$(fmt_left "$fable_reset_epoch" h)
  fi
fi

# 表示整形
COST_FMT=$(awk -v c="${COST:-0}"     'BEGIN{ printf "%.2f", c }')
API_FMT=$(awk  -v m="${API_MS:-0}"   'BEGIN{ printf "%.1f", m/1000 }')

# % 値の整形 (整数化, "—" はそのまま)
fmt_pct() {
  local v=$1
  [[ "$v" == "—" || -z "$v" ]] && { printf -- "—"; return; }
  awk -v v="$v" 'BEGIN{ printf "%d%%", v }'
}
CTX_FMT=$(fmt_pct "$CTX")
FIVEH_FMT=$(fmt_pct "$FIVEH")
SEVEND_FMT=$(fmt_pct "$SEVEND")

printf '%s | Context: %s | Usage(5h): %s | Usage(7d): %s (%s) | Cost: %s$\n' \
  "${MODEL:-Claude}" "$CTX_FMT" "$FIVEH_FMT" \
  "$SEVEND_FMT" "$LEFT7D" "$COST_FMT"
