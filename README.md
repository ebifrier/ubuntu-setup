# ubuntu-setup
The setup file for ubuntu.

## 使い方

```sh
./setup.sh                # 全部 (locale -> packages -> dotfiles -> git -> docker -> nvidia -> mise -> claude -> rtk -> claude-config)
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
- 開発ツール: `global` (gtags) `python3-pip` `unzip` `htop` `jq` (`jq` は rtk のフックが使う)

### install-dotfiles.sh

`config/` 直下の隠しファイル (`.emacs` / `.emacs.d` / `.screenrc` / `.tmux.conf`) を
`$HOME` にそのまま配置し、`bin/ec` を `/usr/local/bin` に入れる。

`config/` のドットで始まるものは全部配るので、dotfile を足したいときは
`config/` に置くだけでよい (スクリプトの修正は要らない)。
`mise.toml` のような通常ファイルは対象外で、それぞれのスクリプトが配る。

※ `$HOME/.emacs.d` はスクリプト冒頭の `RECREATE` に入っていて毎回作り直すので、
ローカルの変更は消える。それ以外は上書きコピーなので `$HOME` の他のファイルは残る。

### install-git.sh

`git config --global` で `user.name` / `user.email` を設定する。

```sh
./install-git.sh                            # ebifrier <ebifrier@gmail.com>
./install-git.sh someone foo@example.com    # 名前とメールを指定
```

環境変数 `GIT_USER_NAME` / `GIT_USER_EMAIL` でも上書きできる。
別人の環境に配るときはここを変える。

### install-docker.sh

Docker Engine を公式 apt リポジトリ (download.docker.com) から入れる。
`docker compose` (plugin) と buildx も一緒に入る。
Ubuntu 同梱の `docker.io` / `docker-compose` / `podman-docker` は競合するので先に外す。

```sh
./install-docker.sh
```

実行ユーザーを `docker` グループに入れるので、再ログイン後は `sudo` 無しで使える
(すぐ試すなら `newgrp docker`)。

### install-nvidia.sh

GPU を渡した LXC コンテナの中に、NVIDIA ドライバの **userspace だけ**を入れる。

```sh
./install-nvidia.sh              # ホストのドライバ版に自動で合わせる
./install-nvidia.sh 580.82.07    # バージョン指定
```

コンテナはホストとカーネルを共有するので、カーネルモジュールはホスト側のものを
そのまま使う。ここで入れるのは `libcuda` / `nvidia-smi` などの userspace だけで、
インストーラは `--no-kernel-modules` で走らせる。

**ホストのモジュールとコンテナの userspace は版が完全に一致していないと動かない**
(`Failed to initialize NVML: Driver/library version mismatch`)。
版はスクリプトに焼かず、次の順で決める。

1. 引数
2. 環境変数 `NVIDIA_DRIVER_VERSION` (`proxmox/create-lxc.sh` が渡す)
3. `/proc/driver/nvidia/version` (ホストのモジュールがコンテナからも見える)

これで 4060 Ti のマシンと 5090 のマシンで同じスクリプトがそのまま通る。

`/dev/nvidia0` が無ければ何もせずに終わるので、VM や GPU 無しのマシンでも
`all` に入れっぱなしで害はない。

`docker` が入っていれば続けて `nvidia-container-toolkit` も入れて
`docker run --gpus all` を使えるようにする。このとき unprivileged な LXC では
`no-cgroups = true` を設定する (コンテナ内からホストの cgroup を触れないため。
これを外すと `nvidia-container-cli` が `operation not permitted` で落ちる)。

CUDA toolkit や PyTorch はプロジェクトごとに入れる前提で、ここでは扱わない。

**ホストのドライバを更新したら、コンテナ側も `./setup.sh nvidia` を流し直すこと。**

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

### install-rtk.sh

[rtk](https://github.com/rtk-ai/rtk) (Rust Token Killer) を公式インストーラで
`~/.local/bin/rtk` に入れる。`git status` のような bash コマンドの出力を
圧縮して Claude Code に渡し、トークン消費を減らすプロキシ。

```sh
./install-rtk.sh          # 最新版
./install-rtk.sh v0.28.2  # バージョン指定
```

Claude Code からは `settings.json` の `PreToolUse` フック
(`~/.claude/hooks/rtk-rewrite.sh`) が `git status` -> `rtk git status` のように
書き換える。フックの実体と登録は `install-claude-config.sh` が配置するので、
rtk 単体で入れただけでは有効にならない (逆も同じで、rtk が無いときフックは
警告を出して素通りする)。フックは `jq` に依存する (`install-packages.sh` で入る)。

削減量は `rtk gain` で見られる。

### install-claude-config.sh

`.claude/` 以下 (CLAUDE.md / settings.json / rules / skills / hooks / scripts) を
`$HOME/.claude` に配置する。セッション履歴・キャッシュ・認証情報は含めていない。

`settings.json` には rtk の `PreToolUse` フック (`hooks/rtk-rewrite.sh`) の登録も
入っているので、rtk 本体は `install-rtk.sh` で入れておく。

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

ユーザーを作り、`docker` / `sudo` グループに入れる。

```sh
./adduser.sh <user> [uid]
```

`uid` を省略すると `useradd` の自動割り当てに任せる (グループはユーザー名と同じものを作る)。

あわせて以下も設定する。

- `/root/.ssh/authorized_keys` を `~<user>/.ssh/` にコピー (無ければ飛ばす)
- `/etc/sudoers.d/<user>` を置いてパスワード無しの `sudo` を許可

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
cloud-init/           # Proxmox の vendor-data (VM 用)
proxmox/              # PVE ホスト上で叩くスクリプト (LXC 用)
```

## Proxmox で自動セットアップ — VM (cloud-init)

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


## Proxmox で自動セットアップ — LXC (create-lxc.sh)

`proxmox/create-lxc.sh` を **PVE ホスト上で root として**叩くと、LXC コンテナを
作って `ubuntu-setup` を流し込むところまで一気にやる。

```sh
./create-lxc.sh 200 gpu-dev igoshogi --with-gpu   # GPU を渡す
./create-lxc.sh 201 build   igoshogi              # GPU 無し (既定)
./create-lxc.sh 202 tmp     igoshogi --dry-run    # コマンドを出すだけ
./create-lxc.sh -h                                # オプション一覧
```

やること:

1. `pct create`（unprivileged / `nesting=1,keyctl=1`）
2. `pct start` → ネットワークが上がるまで待つ
3. `pct exec` で clone → `adduser.sh` → `setup.sh`（ドライバ版を渡す）

`--with-gpu` を付けたときは、これに加えて:

- ホストの NVIDIA ドライバ版を `nvidia-smi` で検出
- `nvidia-modprobe -c 0 -u` で `/dev/nvidia-uvm` を生やす
- `/dev/nvidia*` をコンテナに渡す

**LXC には cloud-init が無い。** VM 側で使っている `cicustom` は `pct` には
存在しないので、`pct create` してから `pct exec` で叩く形にしてある。

### LXC と VM の使い分け

分かれ目は Docker ではなく **GPU を分け合うかどうか**。

| | GPU の渡り方 | 同時共有 | 条件 |
|---|---|---|---|
| VM | PCIe passthrough (VFIO) | 不可。1台が占有しホストからも消える | どの GPU でも可 |
| VM | vGPU / SR-IOV | 可 | 要ライセンス。**GeForce は不可** |
| LXC | `/dev/nvidia*` を bind mount | **可。複数コンテナから同時に使える** | ホストと版を揃える |

コンテナはホストとカーネルを共有するので、ホストに入れた1枚のドライバを
何個のコンテナからでも同時に見られる。GeForce では vGPU が使えないため、
**GPU を複数ゲストで分け合う手段は事実上 LXC だけ**になる。

- **LXC** — GPU を共有したい / オーバーヘッドを削りたい。必要なら中で Docker も動かす
- **VM** — 隔離を効かせたい / 別カーネルが要る / GPU を1台に丸ごと占有させたい

Docker は LXC の中でも動く（`nesting=1,keyctl=1` + `nvidia-container-toolkit`）。
Proxmox 公式は VM を勧めているが、動かないという話ではない。

### 準備 (PVE ホスト側で1回だけ)

**1. コンテナテンプレート**

```sh
pveam update
pveam available --section system | grep ubuntu
pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst
```

`--template` を省略すると `local` にある一番新しい Ubuntu を自動で選ぶ。

**2. NVIDIA ドライバ (GPU を使う場合)**

コンテナ側と版を揃える必要があるので、apt ではなく `.run` で入れる。

```sh
apt install -y pve-headers-$(uname -r) build-essential

VER=580.82.07
curl -fLO https://download.nvidia.com/XFree86/Linux-x86_64/$VER/NVIDIA-Linux-x86_64-$VER.run
sh NVIDIA-Linux-x86_64-$VER.run --silent

nvidia-smi
```

`create-lxc.sh` は初回に `/etc/systemd/system/nvidia-lxc-devices.service` を置いて
有効化する。ホスト再起動後に `/dev/nvidia-uvm` を作り直すためのもので、これが無いと
再起動のたびに GPU 付きコンテナが GPU を見失う。

### 注意点

- **ホストとコンテナのドライバ版は完全一致が必須。** ホスト側を更新したら、
  各コンテナで `./setup.sh nvidia` を流し直す。
- `dev0:` 形式のデバイス渡しは PVE 8.2 以降。それより古い場合は
  `/etc/pve/lxc/<ctid>.conf` に `lxc.cgroup2.devices.allow` /
  `lxc.mount.entry` を直接書く方へ自動で落ちる。
- unprivileged コンテナなので `mode=0666` でデバイスを渡している。
  これが無いとコンテナ内の一般ユーザーからデバイスを開けない。
- Docker から GPU を使うときは `--gpus all` を付ける。
  `docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu24.04 nvidia-smi`
- CUDA toolkit / PyTorch はプロジェクトごとに入れる。`setup.sh` はドライバまで。
- `docker` グループと `LANG` の反映は次のログインから。
- Claude Code の初回ログインだけは自動化できない (ブラウザ認証が必要)。
