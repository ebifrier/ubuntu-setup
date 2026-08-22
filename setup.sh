#!/bin/sh
#
# ubuntu 環境のセットアップ。
#
#   ./setup.sh                # 全部 (packages -> dotfiles -> nvm -> claude -> claude-config)
#   ./setup.sh dotfiles       # dotfiles の配置だけ
#   ./setup.sh packages       # apt パッケージだけ
#   ./setup.sh nvm            # nvm + Node.js だけ
#   ./setup.sh claude         # Claude Code だけ
#   ./setup.sh claude-config  # .claude 設定の配置だけ
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

install_dotfiles() {
    if [ -d "$HOME/.emacs.d" ]; then
        rm -rf "$HOME/.emacs.d"
    fi
    cp -rf "$SCRIPT_DIR/.emacs.d" "$HOME/"
    cp -f "$SCRIPT_DIR/.emacs" "$HOME/"
    cp -f "$SCRIPT_DIR/.screenrc" "$HOME/"
    cp -f "$SCRIPT_DIR/.tmux.conf" "$HOME/"

    sudo cp -f "$SCRIPT_DIR/bin/ec" /usr/local/bin/
    sudo chmod +x /usr/local/bin/ec
}

case "${1:-all}" in
    all)
        "$SCRIPT_DIR/install-packages.sh"
        install_dotfiles
        "$SCRIPT_DIR/install-nvm.sh"
        "$SCRIPT_DIR/install-claude.sh"
        "$SCRIPT_DIR/install-claude-config.sh"
        ;;
    dotfiles)
        install_dotfiles
        ;;
    packages)
        "$SCRIPT_DIR/install-packages.sh"
        ;;
    nvm)
        "$SCRIPT_DIR/install-nvm.sh"
        ;;
    claude)
        "$SCRIPT_DIR/install-claude.sh"
        ;;
    claude-config)
        "$SCRIPT_DIR/install-claude-config.sh"
        ;;
    *)
        echo "usage: $0 [all|dotfiles|packages|nvm|claude|claude-config]" >&2
        exit 1
        ;;
esac
