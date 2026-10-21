#!/usr/bin/env bash
# PreToolUse (Bash) フック。Co-Authored-By 付きの git commit を止めて付け直させる。
#
# attribution を空にしてもモデルが自分でトレーラーを書くことがあるため。
# -F でファイルから渡されたメッセージはここでは見えないので、
# git 側の commit-msg フック (install-git.sh が入れる) でも消している。
# 依存: jq
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

cmd=$(jq -r '.tool_input.command // ""')
if grep -q 'git' <<<"$cmd" && grep -q 'commit' <<<"$cmd" \
    && grep -qi 'co-authored-by:' <<<"$cmd"; then
    echo "コミットメッセージに Co-Authored-By トレーラーを付けないこと。削除して再実行する。" >&2
    exit 2
fi
exit 0
