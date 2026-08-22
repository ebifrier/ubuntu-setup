# ubuntu-setup
The setup file for ubuntu.

## 使い方

```sh
./setup.sh             # 全部 (packages -> dotfiles -> claude)
./setup.sh packages    # apt パッケージだけ
./setup.sh dotfiles    # dotfiles の配置だけ
./setup.sh claude      # Claude Code だけ
```

### install-packages.sh

apt で以下を入れる。

- 基本: `screen` `tmux` `emacs-nox` `git` `curl` `wget` `build-essential` `ca-certificates`
- 開発ツール: `global` (gtags) `python3-pip` `unzip` `htop`

### dotfiles

`.emacs` / `.emacs.d` / `.screenrc` / `.tmux.conf` を `$HOME` に配置し、
`bin/ec` を `/usr/local/bin` に入れる。
※ `$HOME/.emacs.d` は毎回作り直すので、ローカルの変更は消える。

### install-claude.sh

Claude Code を公式のネイティブインストーラで入れる。
バイナリは `~/.local/share/claude/` に置かれ、`~/.local/bin/claude` から起動する
(`~/.local/bin` への PATH を `.bashrc` に追記する)。ネイティブ版は自動更新される。

```sh
./install-claude.sh           # latest チャンネル
./install-claude.sh stable    # stable チャンネル (約1週間遅れ)
./install-claude.sh 2.1.89    # バージョン指定
```

初回はログインが必要なので `claude` を起動してブラウザの指示に従う。

### adduser.sh

```sh
./adduser.sh user id
```
