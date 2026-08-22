# ubuntu-setup
The setup file for ubuntu.

## 使い方

```sh
./setup.sh                # 全部 (packages -> dotfiles -> claude -> claude-config)
./setup.sh packages       # apt パッケージだけ
./setup.sh dotfiles       # dotfiles の配置だけ
./setup.sh claude         # Claude Code だけ
./setup.sh claude-config  # .claude 設定の配置だけ
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

### install-claude-config.sh

`.claude/` 以下 (CLAUDE.md / settings.json / rules / skills / hooks / scripts) を
`$HOME/.claude` に配置する。セッション履歴・キャッシュ・認証情報は含めていない。

```sh
./install-claude-config.sh
```

プラグイン (joseki, claude-plugins-official) と context7 / playwright の MCP サーバーは
`settings.json` の `enabledPlugins` / `extraKnownMarketplaces` を見て
claude 起動時に自動で取得される。
context7 の API キーが要るときは `settings.json` の `env` に足す
(キー自体はリポジトリに置かないこと)。

### adduser.sh

```sh
./adduser.sh user id
```
