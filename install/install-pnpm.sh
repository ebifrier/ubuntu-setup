#!/bin/sh
#
# pnpm を入れて、Node.js も pnpm に管理させる (pnpm runtime)。
# 以前の mise / nvm の代わり。
#
#   install/install-pnpm.sh        # pnpm + Node.js (LTS)
#   install/install-pnpm.sh none   # pnpm 本体だけ (Node.js は入れない)
#
# 流し直すと pnpm と Node.js が最新 (Node.js は LTS) に上がる。
#
set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/lib/common.sh"

MODE=${1:-all}
export PNPM_HOME="$HOME/.local/share/pnpm"
PNPM_BIN="$PNPM_HOME/bin/pnpm"

require_cmd curl

# .bashrc は下の ensure_bashrc_block で管理するので、公式インストーラ
# (pnpm setup) には書かせない。
curl -fsSL https://get.pnpm.io/install.sh | PNPM_NO_MODIFY_PATH=1 sh -

# mise / nvm で入れていた頃の設定を片付ける。
# 先に消しておくと、下で足すブロックの前に空行が溜まらない。
remove_bashrc_block mise
remove_bashrc_block nvm
remove_legacy_bashrc_block nvm

# pnpm 本体も、pnpm runtime で入れた node もここに入る。
# PATH に直接通すので、非対話シェル (ssh <host> <cmd> や cron) からも使える。
ensure_bashrc_block pnpm <<'BLOCK'
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
    *":$PNPM_HOME/bin:"*) ;;
    *) PATH="$PNPM_HOME/bin:$PATH" ;;
esac
export PATH
BLOCK

# pnpm runtime set -g は global bin が PATH に無いと止まるので、この場でも通す。
PATH="$PNPM_HOME/bin:$PATH"

"$PNPM_BIN" --version

if [ "$MODE" = "none" ]; then
    log "Node.js は入れない。'pnpm runtime set node lts -g' で後から入れられる。"
else
    "$PNPM_BIN" runtime set node lts -g
    "$PNPM_HOME/bin/node" --version
fi

note "新しいシェルを開くと pnpm / node が使える。npm / npx は入らないので、npx の代わりに pnpm dlx を使う。"
if [ -x "$HOME/.local/bin/mise" ]; then
    # 表示するだけの文言なので ~ が展開されなくてよい。
    # shellcheck disable=SC2088
    note "~/.local/bin/mise が残っている。pnpm に移ったので 'mise implode --config' で本体・入れたツール・設定をまとめて消してよい。"
fi
if [ -d "$HOME/.nvm" ]; then
    # shellcheck disable=SC2088
    note "~/.nvm が残っている。pnpm に移ったので rm -rf ~/.nvm と、~/.bashrc の NVM_DIR の行 (nvm 公式インストーラが書いたもの) を消してよい。"
fi
