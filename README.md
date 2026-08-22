# ubuntu-setup
The setup file for ubuntu.

## 使い方

```sh
./setup.sh                # 全部 (locale -> packages -> dotfiles -> docker -> mise -> claude -> claude-config)
./setup.sh docker         # 特定のステップだけ
./setup.sh docker mise    # 複数指定も可 (指定した順に実行)
./setup.sh -h             # ステップ一覧
```

ステップの定義は `setup.sh` 冒頭の `STEPS` 1箇所にまとまっている
(名前 / スクリプト / 説明)。ステップを足すときはここに1行足して
`install-<名前>.sh` を置く。`all` の実行順もこの並び。

「次のログインから有効」のような注意書きは各スクリプトが `note` で登録し、
`setup.sh` の最後に「セットアップ後のメモ」としてまとめて出る。

### install-locale.sh

`ja_JP.UTF-8` を生成して `LANG` の既定にする
(`locale-gen` が無ければ `locales` パッケージを入れてから実行する)。

```sh
./install-locale.sh                # ja_JP.UTF-8
./install-locale.sh en_US.UTF-8    # ロケール指定
```

反映は次のログインから。今のシェルで使うなら `export LANG=ja_JP.UTF-8`。

### install-packages.sh

apt で以下を入れる。

- 基本: `screen` `tmux` `emacs-nox` `git` `curl` `wget` `build-essential` `ca-certificates`
- 開発ツール: `global` (gtags) `python3-pip` `unzip` `htop`

### install-dotfiles.sh

`config/` 直下の隠しファイル (`.emacs` / `.emacs.d` / `.screenrc` / `.tmux.conf`) を
`$HOME` にそのまま配置し、`bin/ec` を `/usr/local/bin` に入れる。

`config/` のドットで始まるものは全部配るので、dotfile を足したいときは
`config/` に置くだけでよい (スクリプトの修正は要らない)。
`mise.toml` のような通常ファイルは対象外で、それぞれのスクリプトが配る。

※ `$HOME/.emacs.d` はスクリプト冒頭の `RECREATE` に入っていて毎回作り直すので、
ローカルの変更は消える。それ以外は上書きコピーなので `$HOME` の他のファイルは残る。

### install-docker.sh

Docker Engine を公式 apt リポジトリ (download.docker.com) から入れる。
`docker compose` (plugin) と buildx も一緒に入る。
Ubuntu 同梱の `docker.io` / `docker-compose` / `podman-docker` は競合するので先に外す。

```sh
./install-docker.sh
```

実行ユーザーを `docker` グループに入れるので、再ログイン後は `sudo` 無しで使える
(すぐ試すなら `newgrp docker`)。

### install-mise.sh

[mise](https://mise.jdx.dev/) を `~/.local/bin/mise` に入れて、Node.js / pnpm などの
ランタイムをまとめて管理する。nvm + `npm -g pnpm` の置き換え。
入れるものは `config/mise.toml` (配置先は `~/.config/mise/config.toml`) で決まる。

```sh
./install-mise.sh        # mise + config/mise.toml のツール一式
./install-mise.sh none   # mise 本体だけ (ツールは入れない)
```

```toml
[tools]
node = "lts"
pnpm = "latest"
```

Python や Go を足したくなったら `mise use -g python@3.12` を叩くか、
上の `[tools]` に1行足して `./setup.sh mise` を流し直す。

`.bashrc` には shims (`~/.local/share/mise/shims`) への PATH を通す。
shims にしておくと `ssh <host> <cmd>` や cron のような非対話シェルからも
`node` / `pnpm` が使える。

nvm から乗り換えた場合、`~/.nvm` と nvm 公式インストーラが `.bashrc` に書いた
`NVM_DIR` の行は自前で消す (このリポジトリが書いたブロックは自動で消える)。

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

### lib/common.sh

各スクリプトから読み込む共通処理。単体では実行しない。

```sh
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"
```

- `log` / `warn` / `die` — メッセージ出力。`die` は終了コード 1 で止まる
- `note <文言>` — 「次のログインから有効」のような後で読ませたい注意書きを溜める。
  `setup.sh` の最後 (単体実行ならそのスクリプトの最後) にまとめて出る。同じ文言は1回だけ
- `require_cmd <コマンド>...` — 無ければ `install-packages.sh` を案内して止まる
- `apt_install <パッケージ>...` — `apt-get update` は1プロセスにつき1回だけ走る。
  リポジトリを足した直後など、明示的に更新したいときは `apt_update force`

`.bashrc` への追記は `ensure_bashrc_block <名前>` に集約してある。
中身を標準入力で渡すと、マーカー行で囲んだブロックとして書き込む。

```sh
# >>> ubuntu-setup: mise >>>
export PATH="$HOME/.local/share/mise/shims:$PATH"
# <<< ubuntu-setup: mise <<<
```

- 何度流しても重複しない (中身が同じなら何もしないので、ブロックの順序も変わらない)
- 中身を変えて流し直すと、そのブロックだけ差し替わる
- `remove_bashrc_block <名前>` で消せる (mise が nvm / pnpm のブロックを片付けるのに使っている)
- マーカーが無かった頃の `# ubuntu-setup: <名前>` 形式は `remove_legacy_bashrc_block` が移行用に消す

### adduser.sh

ユーザーを uid/gid 指定で作り、`docker` / `sudo` グループに入れる。

```sh
./adduser.sh <user> <uid>
```

他の環境に単体で持っていけるよう、`lib/common.sh` には依存させていない。

## ディレクトリ構成

```
setup.sh              # 入口。ステップの定義 (STEPS) もここ
install-*.sh          # ステップごとの本体
lib/common.sh         # 共通処理 (メッセージ / apt / .bashrc)
bin/                  # $PATH に入れるスクリプト (ec)
config/               # 配置するもの
  .emacs .emacs.d .screenrc .tmux.conf   # -> $HOME
  mise.toml                              # -> ~/.config/mise/config.toml
.claude/              # -> ~/.claude (このリポジトリ自身の設定も兼ねる)
cloud-init/           # Proxmox の vendor-data
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
  root のまま走らせると dotfiles / mise / claude が `/root` に入る。
  ユーザーは `getent passwd 1000` で拾うので、GUI の Cloud-Init タブで
  User を設定しておくこと。
- このリポジトリが private だと HTTPS clone が失敗する。
  その場合は deploy key を `write_files` で置く。
- Claude Code の初回ログインだけは自動化できない (ブラウザ認証が必要)。
- `docker` グループと `LANG` の変更は次のログインから効く。cloud-init 直後の
  セッションでは反映されていないので、一度ログインし直すこと。
- クラスタ構成では `local:` はノードごとなので、VM が動く各ノードの
  `/var/lib/vz/snippets/` に置く。
- 進行確認は `cloud-init status --wait`、ログは `/var/log/cloud-init-output.log`。
