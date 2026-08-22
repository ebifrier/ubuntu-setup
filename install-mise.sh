#!/bin/sh
#
# mise (旧 rtx) を入れて、Node.js / pnpm などのランタイムをまとめて管理する。
# nvm + npm -g pnpm の代わり。入れるものは config/mise.toml で決まる。
#
#   ./install-mise.sh        # mise + config/mise.toml のツール一式
#   ./install-mise.sh none   # mise 本体だけ (ツールは入れない)
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

MODE=${1:-all}
MISE_BIN="$HOME/.local/bin/mise"
MISE_CONFIG_DIR="$HOME/.config/mise"

require_cmd curl

curl -fsSL https://mise.run | MISE_INSTALL_PATH="$MISE_BIN" sh

# ~/.local/bin (mise 本体) と shims (node / pnpm) を PATH に通す。
# shims にしておくと非対話シェル (ssh <host> <cmd> や cron) からも使える。
ensure_local_bin
ensure_bashrc_block mise <<'BLOCK'
export PATH="$HOME/.local/share/mise/shims:$PATH"
BLOCK

# nvm / pnpm を個別に入れていた頃の設定を片付ける。
remove_bashrc_block nvm
remove_bashrc_block pnpm
remove_legacy_bashrc_block nvm
remove_legacy_bashrc_block pnpm

mkdir -p "$MISE_CONFIG_DIR"
cp -f "$SCRIPT_DIR/config/mise.toml" "$MISE_CONFIG_DIR/config.toml"

"$MISE_BIN" --version

if [ "$MODE" = "none" ]; then
    log "ツールは入れない。'mise install' で後から入れられる。"
else
    "$MISE_BIN" install
    "$MISE_BIN" ls
fi

note "新しいシェルを開くと mise / node / pnpm が使える。"
if [ -d "$HOME/.nvm" ]; then
    note "~/.nvm が残っている。mise に移ったので rm -rf ~/.nvm と、~/.bashrc の NVM_DIR の行 (nvm 公式インストーラが書いたもの) を消してよい。"
fi
