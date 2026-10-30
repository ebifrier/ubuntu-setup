# ubuntu-setup
The setup file for ubuntu.

## 使い方

```sh
./setup.sh                # 全部 (wsl -> locale -> packages -> dotfiles -> git -> gh -> awscli -> docker -> nvidia -> mise -> claude -> rtk -> codex -> codex-config -> claude-config)
./setup.sh docker         # 特定のステップだけ
./setup.sh docker mise    # 複数指定も可 (指定した順に実行)
./setup.sh -h             # ステップ一覧
```

ステップの定義は `setup.sh` 冒頭の `STEPS` 1箇所にまとまっている
(名前 / スクリプト / 説明)。ステップを足すときはここに1行足して
`install/install-<名前>.sh` を置く。`all` の実行順もこの並び。

「次のログインから有効」のような注意書きは各スクリプトが `note` で登録し、
`setup.sh` の最後に「セットアップ後のメモ」としてまとめて出る。

### install-wsl.sh

WSL2 の Ubuntu 向けの設定。`/etc/wsl.conf` で Windows 側のドライブと `PATH` を
持ち込まないようにし、それでも必要になる VS Code の拡張ディレクトリだけを
`/etc/fstab` で read-only マウントして通す。

```sh
install/install-wsl.sh              # Windows ユーザー名は自動で拾う
install/install-wsl.sh igoshogi     # 拾えないときは手で渡す
```

WSL でなければ何もせずに終わるので、`all` に入れっぱなしで害はない。
Windows ユーザー名は 引数 → 環境変数 `WIN_USER` → `cmd.exe /c echo %USERNAME%`
→ `/mnt/c/Users` の走査 の順で決める (interop を切ったあとは `cmd.exe` が
使えないので、後ろ2つで拾う)。

`/etc/wsl.conf` に書くのは次の4つ。

```ini
[automount]
enabled = false
mountFsTab = true

[interop]
enabled = false
appendWindowsPath = false
```

- `automount.enabled = false` — `/mnt/c` などの自動マウントをやめる。DrvFs 越しの
  ファイルアクセスは遅くパーミッションも Linux のものではないので、作業ファイルは
  Linux 側の ext4 に置く
- `automount.mountFsTab = true` — 自動マウントは切っても `/etc/fstab` は読ませる。
  下の VS Code 用のマウントはこれで効く
- `interop.enabled = false` — Linux から Windows の `.exe` を起動する仕組みを切る
- `interop.appendWindowsPath = false` — `PATH` に Windows 側のパスを継ぎ足さない。
  `python` や `node` が Windows 側のものに解決される事故が無くなり、パス探索も速くなる

ファイルは丸ごと上書きせずこの4キーだけを差し替えるので、Ubuntu 既定の
`[boot] systemd=true` のような他の設定は残る。`wsl.conf` / `fstab` とも、
書き換える前の中身は初回だけ `.bak` に退避する。

**VS Code の「Connect to WSL」**: WSL 拡張はサーバー起動スクリプト
(`wslServer.sh`) を Windows 側の拡張ディレクトリから読むので、automount を
無効にしたままでは接続できない。そのディレクトリだけを `/etc/fstab` に書いて通す。

```
# >>> ubuntu-setup: vscode-extensions >>>
C:\Users\<Windowsユーザー>\.vscode\extensions /mnt/c/Users/<Windowsユーザー>/.vscode/extensions drvfs ro,uid=1000,gid=1000 0 0
# <<< ubuntu-setup: vscode-extensions <<<
```

- バージョン付きの `ms-vscode-remote.remote-wsl-<ver>` ではなく親の `extensions` を
  指すので、拡張が更新されても修正は要らない
- `uid` / `gid` は実行ユーザーのもの (`id -u` / `id -g`)、ユーザー名に空白があれば
  fstab の区切りと衝突しないよう `\040` に逃がす
- マーカー行で囲んだブロックなので、何度流しても重複せず、ユーザー名を変えて
  流し直せばその行だけ差し替わる

マウント先のディレクトリもスクリプトが作る。automount がまだ生きている間は
`/mnt/c` に drvfs が被っていて、その下に `mkdir` しても Windows 側に作られるだけで
マウント先にはならないので、再帰しない bind mount で下地の `/mnt` を覗いて作る。

反映は PowerShell で `wsl --shutdown` してから入り直したときから
(「セットアップ後のメモ」にも出る)。接続は Windows 側の VS Code から張る
— interop を切っているので、WSL の中から `code .` で開く使い方はできない。

### install-locale.sh

`ja_JP.UTF-8` を生成して `LANG` の既定にする
(`locale-gen` が無ければ `locales` パッケージを入れてから実行する)。

```sh
install/install-locale.sh                # ja_JP.UTF-8
install/install-locale.sh en_US.UTF-8    # ロケール指定
```

反映は次のログインから。今のシェルで使うなら `export LANG=ja_JP.UTF-8`。

### install-packages.sh

apt で以下を入れる。

- 基本: `tmux` `git` `curl` `wget` `build-essential` `ca-certificates`
- 開発ツール: `global` (gtags) `python3-pip` `unzip` `htop` `jq` (`jq` は statusline のスクリプトが使う)

### install-dotfiles.sh

`config/` 直下の隠しファイル (`.tmux.conf`) を `$HOME` にそのまま配置する。

`config/` のドットで始まるものは全部配るので、dotfile を足したいときは
`config/` に置くだけでよい (スクリプトの修正は要らない)。
`mise.toml` のような通常ファイルは対象外で、それぞれのスクリプトが配る。

上書きコピーなので `$HOME` の他のファイルは残る。

### install-git.sh

`git config --global` で `user.name` / `user.email` を設定する。

```sh
install/install-git.sh                            # ebifrier <ebifrier@gmail.com>
install/install-git.sh someone foo@example.com    # 名前とメールを指定
```

環境変数 `GIT_USER_NAME` / `GIT_USER_EMAIL` でも上書きできる。
別人の環境に配るときはここを変える。

あわせて `init.templateDir` を `~/.config/git/template` (中身は `config/git-template/`)
に向け、Claude の `Co-Authored-By: ... <noreply@anthropic.com>` と
`Generated with [Claude Code]` の行を消す `commit-msg` フックを配る。
`settings.json` の `attribution` を空にしていても、モデルが自分で書くことがあるため。

`core.hooksPath` と違って各リポジトリの `.git/hooks` (husky など) は生きたままだが、
入るのは新しく clone / init したリポジトリだけ。既存のリポジトリはその中で
`git init` を打つと (既存ファイルを壊さずに) フックがコピーされる。

### install-gh.sh

GitHub CLI (`gh`) を公式 apt リポジトリ (cli.github.com) から入れる。
Ubuntu 同梱の `gh` は版が古いので使わない。

```sh
install/install-gh.sh
```

認証はしないので、使う前に `gh auth login` を手で通す
(未認証なら「セットアップ後のメモ」に出る)。

### install-awscli.sh

AWS CLI v2 を公式の zip インストーラ (awscli.amazonaws.com) から入れる。
Ubuntu 同梱の `awscli` は v1 で版も古いので使わない。

```sh
install/install-awscli.sh           # 最新版
install/install-awscli.sh 2.27.54   # バージョン指定
```

`/usr/local/aws-cli` に入り、`/usr/local/bin/aws` から辿れる。
既に入っていれば `--update` で入れ直す。

認証情報は設定しないので、使う前に `aws configure` を手で通す
(`~/.aws` が無ければ「セットアップ後のメモ」に出る)。

### install-docker.sh

Docker Engine を公式 apt リポジトリ (download.docker.com) から入れる。
`docker compose` (plugin) と buildx も一緒に入る。
Ubuntu 同梱の `docker.io` / `docker-compose` / `podman-docker` は競合するので先に外す。

```sh
install/install-docker.sh
```

実行ユーザーを `docker` グループに入れるので、再ログイン後は `sudo` 無しで使える
(すぐ試すなら `newgrp docker`)。

### install-nvidia.sh

GPU を渡した LXC コンテナの中に、NVIDIA ドライバの **userspace だけ**を入れる。

```sh
install/install-nvidia.sh              # ホストのドライバ版に自動で合わせる
install/install-nvidia.sh 580.82.07    # バージョン指定
```

コンテナはホストとカーネルを共有するので、カーネルモジュールはホスト側のものを
そのまま使う。ここで入れるのは `libcuda` / `nvidia-smi` などの userspace だけで、
インストーラは `--no-kernel-modules` で走らせる。

**ホストのモジュールとコンテナの userspace は版が完全に一致していないと動かない**
(`Failed to initialize NVML: Driver/library version mismatch`)。
版はスクリプトに焼かず、次の順で決める。

1. 引数
2. 環境変数 `NVIDIA_DRIVER_VERSION`
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
install/install-mise.sh        # mise + config/mise.toml のツール一式
install/install-mise.sh none   # mise 本体だけ (ツールは入れない)
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
install/install-claude.sh           # latest チャンネル
install/install-claude.sh stable    # stable チャンネル (約1週間遅れ)
install/install-claude.sh 2.1.89    # バージョン指定
```

初回はログインが必要なので `claude` を起動してブラウザの指示に従う。

### install-rtk.sh

[rtk](https://github.com/rtk-ai/rtk) (Rust Token Killer) を公式インストーラで
`~/.local/bin/rtk` に入れる。`git status` のような bash コマンドの出力を
圧縮して Claude Code / Codex に渡し、トークン消費を減らすプロキシ。

```sh
install/install-rtk.sh          # 最新版
install/install-rtk.sh v0.28.2  # バージョン指定
```

Claude Code からは `settings.json` の `PreToolUse` フック (`rtk hook claude`)
が `git status` -> `rtk git status` のように書き換える。フックは rtk 本体の
サブコマンドで、登録は `install-claude-config.sh` が配置する `settings.json`
に入っているので、rtk 単体で入れただけでは有効にならない。

Codex では `install-codex-config.sh` が `rtk init --codex --global` を実行して
`AGENTS.md` / `RTK.md` を配置する。コマンドに `rtk` を付けるよう共通指示で
指定する方式で、Claude のようなフックによる強制的な書き換えではない。

削減量は `rtk gain` で見られる。

### install-codex.sh

[Codex CLI](https://github.com/openai/codex) (OpenAI) を公式インストーラで
`~/.local/bin/codex` に入れる。本体は `~/.codex/packages/standalone/` に置かれ、
`~/.local/bin/codex` はそこへのリンク。

```sh
install/install-codex.sh            # 最新版
install/install-codex.sh 0.150.1    # バージョン指定
```

インストーラは `~/.local/bin` が `PATH` に無いと `.bashrc` に自前のブロックを
足すので、先に `ensure_local_bin` で通してから走らせている
(`.bashrc` の PATH はこのリポジトリの `local-bin` ブロックに一本化する)。

Linux 版のサンドボックスは bubblewrap を使うので、`bubblewrap` を apt で入れ、
`/etc/apparmor.d/bwrap-userns-restrict` を `apparmor_parser -r` で読み込み直す。
Ubuntu 24.04 以降は AppArmor が非特権の user namespace を制限しており、
このプロファイルが効いていないと bwrap が失敗する。プロファイルか
`apparmor_parser` が無い環境 (WSL や LXC など) ではこの手順は飛ばす。

初回はログインが必要なので `codex` を起動してブラウザの指示に従う。

### install-codex-config.sh

`$USER` のアカウント情報 (`getent passwd "$USER"`) からホームディレクトリを
取得して、`<ホーム>/.codex/config.toml` を生成・更新する。
ユーザー名や `/home` は固定しない。`CODEX_HOME` が設定されている場合は
その絶対パスを設定先に使う。通常の開発ユーザーで実行する。

```sh
./setup.sh codex-config
# 本体から入れる場合
./setup.sh rtk codex codex-config
```

設定内容は次のとおり。

- `sandbox_mode = "workspace-write"`: 作業ディレクトリ内の書き込みを許可
- `approval_policy = "on-request"`: サンドボックス外の操作を承認の対象にする
- `approvals_reviewer = "auto_review"`: 対象の承認を自動レビューに回し、手動確認を減らす (Approve for me)
- `sandbox_workspace_write.network_access = true`: 外部ネットワークへの接続を許可
- `sandbox_workspace_write.writable_roots`: 対象ユーザーの `.local` と `.cache` を追加
- `mcp_servers.context7`: context7 MCP を `npx -y @upstash/context7-mcp` で起動する
  (`env` など自分で足したキーは残す)

既存のモデル・MCP・プラグイン設定やコメントは保持し、上記の管理対象キーだけを
更新する。既存の `writable_roots` も残し、追加パスは重複させない。
変更前の設定は初回だけ `config.toml.bak` に退避する。
TOML の処理には apt の `python3-tomlkit` を使い、無い場合は自動で入れる。
不正な TOML は書き換えずに停止する。

RTK 本体は先に `install-rtk.sh` で入れておく。
`rtk init --codex --global` で同じ設定先に共通指示を配置し、既存の `AGENTS.md`
に指示を追加する。反映は次回の Codex 起動から。
空でない `AGENTS.override.md` がある場合は、初回の内容を `.bak` に残して
そちらにも RTK の参照を追加する。

`agent-skills/` の skill を `<ホーム>/.agents/skills` (Codex のユーザースキル置き場) に
コピーする。自分で置いた skill は残し、リポジトリにある名前のものだけ入れ替える。
管理ポリシーで制限されている権限はこの設定では拡張できない。
自動レビューは対応する Codex で利用できる。sudo のパスワード認証は別途必要なので、
依存パッケージの導入時は通常のターミナルで実行する。

### install-claude-config.sh

`.claude/` 以下 (CLAUDE.md / settings.json / rules / skills / scripts) と
`agent-skills/` を `$HOME/.claude` に配置する。セッション履歴・キャッシュ・認証情報は含めていない。
`skills/synced` (claude.ai のアカウントから同期されるスキル) は消さずに残す。
`settings.json` は既存のものにリポジトリ側を重ねてマージする
(キーが被ればリポジトリ側が勝ち、配列は丸ごと置き換わる)。

`settings.json` には rtk の `PreToolUse` フック (`rtk hook claude`) の登録も
入っているので、rtk 本体は `install-rtk.sh` で入れておく。

もう一つの `PreToolUse` フック (`scripts/no-coauthor.sh`) は、`Co-Authored-By:` を
含む `git commit` を止めて Claude に付け直させる (`git commit -F` でファイルから
渡されたものは見えないので、`install-git.sh` の `commit-msg` フックと併用する)。

```sh
install/install-claude-config.sh
```

プラグイン (claude-plugins-official) は `settings.json` の
`enabledPlugins` / `extraKnownMarketplaces` を見て claude 起動時に自動で取得される。
context7 MCP は `claude mcp add --scope user` で登録する (登録済みなら何もしない)。
context7 の API キーが要るときは `settings.json` の `env` に足す
(キー自体はリポジトリに置かないこと)。

以前使っていた joseki プラグインは廃止した。必要な skill は `agent-skills/` と
`.claude/skills/` に移してある。このスクリプトは joseki が残っていれば
アンインストールし、マーケットプレイスの登録と `settings.json` の項目も消す。

### lib/common.sh

各スクリプトから読み込む共通処理。単体では実行しない。

```sh
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/lib/common.sh"
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
install/install-*.sh  # ステップごとの本体
lib/common.sh         # 共通処理 (メッセージ / apt / .bashrc)
config/               # 配置するもの
  .tmux.conf                             # -> $HOME
  mise.toml                              # -> ~/.config/mise/config.toml
.claude/              # -> ~/.claude (このリポジトリ自身の設定も兼ねる)
  skills/                                # Claude 専用の skill (codex-review)
agent-skills/         # Claude / Codex 共通の skill -> ~/.claude/skills, ~/.agents/skills
```
