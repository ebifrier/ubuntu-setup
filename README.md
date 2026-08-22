# ubuntu-setup
The setup file for ubuntu.

## 使い方

```sh
./setup.sh                # 全部 (packages -> dotfiles -> nvm -> claude -> claude-config)
./setup.sh packages       # apt パッケージだけ
./setup.sh dotfiles       # dotfiles の配置だけ
./setup.sh nvm            # nvm + Node.js だけ
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

### install-nvm.sh

nvm (Node Version Manager) を `~/.nvm` に入れて Node.js を入れる。
`.bashrc` に nvm の読み込みが追記される (インストーラが書かなかったときのみ本体で追記)。

```sh
./install-nvm.sh         # nvm + Node.js LTS
./install-nvm.sh 22      # nvm + Node.js 22 系
./install-nvm.sh none    # nvm だけ (Node は入れない)
```

入れた Node.js は `nvm alias default` で既定にするので、新しいシェルでそのまま使える。

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

## Proxmox で自動セットアップ (cloud-init)

`cloud-init/vendor-data.yaml` を Proxmox の snippet として置いておくと、
VM の初回起動時に自動でこのリポジトリを clone して `setup.sh` を実行する。
`git clone ... && ./setup.sh` を手で打つ必要がなくなる。

イメージには何も焼き込まないので、Ubuntu の更新に追従する手間はない。

### 準備 (PVE ホスト側で root として1回だけ)

Web UI の Datacenter → ノード名 → `>_ Shell`、または `ssh root@<PVEホスト>`。

```sh
# 1. local ストレージで snippets を使えるようにする
pvesm set local --content iso,vztmpl,backup,snippets

# 2. vendor-data を置く (このリポジトリの cloud-init/vendor-data.yaml の中身)
vi /var/lib/vz/snippets/ubuntu-setup.yaml

# 3. Ubuntu cloud image のテンプレートに紐付ける
qm set 9000 --cicustom "vendor=local:snippets/ubuntu-setup.yaml"

# 4. 確認
qm config 9000 | grep cicustom
```

`cicustom` はクローンに引き継がれるので、以降はテンプレートをクローンして
起動するだけ。GUI の「Clone → Start」でよい。

### なぜ vendor= なのか

`user=` にすると Proxmox が GUI の Cloud-Init タブから生成する user-data
(ユーザー / パスワード / SSH 鍵 / IP) を丸ごと置き換えてしまう。
`vendor=` は別枠なので GUI 側の設定をそのまま使える。
なお `cicustom` は GUI から設定できないので、この1行だけは CLI で打つ。

### 注意点

- `runcmd` は root で走るので `su - <ciuser>` に落としてから `setup.sh` を実行する。
  root のまま走らせると dotfiles / nvm / claude が `/root` に入る。
  ユーザーは `getent passwd 1000` で拾うので、GUI の Cloud-Init タブで
  User を設定しておくこと。
- このリポジトリが private だと HTTPS clone が失敗する。
  その場合は deploy key を `write_files` で置く。
- Claude Code の初回ログインだけは自動化できない (ブラウザ認証が必要)。
- クラスタ構成では `local:` はノードごとなので、VM が動く各ノードの
  `/var/lib/vz/snippets/` に置く。
- 進行確認は `cloud-init status --wait`、ログは `/var/log/cloud-init-output.log`。
