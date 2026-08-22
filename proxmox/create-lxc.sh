#!/bin/sh
#
# Proxmox の LXC コンテナを作って ubuntu-setup を流し込む。
# PVE ホスト (ハイパーバイザ本体) 上で root として実行する。
#
#   ./create-lxc.sh <ctid> <hostname> <user> [オプション]
#
#   ./create-lxc.sh 200 gpu-dev igoshogi
#   ./create-lxc.sh 201 build   igoshogi --no-gpu --steps "locale packages dotfiles"
#   ./create-lxc.sh 202 tmp     igoshogi --dry-run
#
# VM 側の cloud-init (cloud-init/vendor-data.yaml) に相当するもの。
# LXC には cloud-init を渡す仕組みが無いので、pct create してから
# pct exec で clone と setup.sh を叩く形にしている。
#
# GPU について:
#   コンテナはホストとカーネルを共有するので、ホストに入れた1枚の GPU を
#   複数のコンテナから同時に使える (GeForce では vGPU が使えないため、
#   GPU を分け合う手段は事実上これだけ)。
#   ホストのカーネルモジュールとコンテナ内の userspace はバージョンが
#   一致していないと動かないので、ホストの版を検出してコンテナに渡す。
#   コンテナ側の導入は install-nvidia.sh が面倒を見る。
#
# ホスト側の前提:
#   - NVIDIA ドライバを .run で導入済み (nvidia-smi が通ること)
#   - vztmpl に Ubuntu のテンプレートがあること
#       pveam update && pveam available --section system | grep ubuntu
#       pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst
#
set -e

# ------------------------------------------------------------------ 既定値

REPO=https://github.com/ebifrier/ubuntu-setup
DEST=/opt/ubuntu-setup

TEMPLATE=
STORAGE=local-lvm
ROOTFS_SIZE=64
CORES=4
MEMORY=4096
SWAP=2048
BRIDGE=vmbr0
IP=dhcp
SSH_KEYS=/root/.ssh/authorized_keys
STEPS=
WITH_GPU=1
DRY_RUN=

# ------------------------------------------------------------------ 関数

log()  { echo "$@"; }
warn() { echo "$@" >&2; }
die()  { echo "$@" >&2; exit 1; }

usage() {
    warn "usage: $0 <ctid> <hostname> <user> [オプション]"
    warn ""
    warn "  --template <volid>   コンテナテンプレート (既定: local の最新 Ubuntu)"
    warn "  --storage <name>     rootfs の置き場 (既定: $STORAGE)"
    warn "  --rootfs-size <GB>   rootfs の大きさ (既定: $ROOTFS_SIZE)"
    warn "  --cores <N>          CPU コア数 (既定: $CORES)"
    warn "  --memory <MB>        メモリ (既定: $MEMORY)"
    warn "  --swap <MB>          swap (既定: $SWAP)"
    warn "  --bridge <name>      ネットワークブリッジ (既定: $BRIDGE)"
    warn "  --ip <spec>          dhcp または CIDR,gw=... (既定: $IP)"
    warn "  --ssh-keys <file>    root に入れる公開鍵 (既定: $SSH_KEYS)"
    warn "  --repo <url>         clone するリポジトリ (既定: $REPO)"
    warn "  --steps \"<step>...\"  setup.sh に渡すステップ (既定: 全部)"
    warn "  --no-gpu             GPU を渡さない"
    warn "  --dry-run            実行せずコマンドだけ出す"
}

# --dry-run のときは実行せずコマンドを表示する。
run() {
    if [ -n "$DRY_RUN" ]; then
        printf '+'
        for _a in "$@"; do printf ' %s' "$_a"; done
        printf '\n'
        return 0
    fi
    "$@"
}

# local に置いてある Ubuntu テンプレートのうち一番新しいものを選ぶ。
latest_ubuntu_template() {
    pvesm list local --content vztmpl 2>/dev/null |
        awk 'NR > 1 { print $1 }' |
        grep -i ubuntu |
        sort -V |
        tail -n 1
}

# /dev/nvidia-uvm などはドライバが一度触られるまで生えないので、先に作らせる。
ensure_nvidia_devices() {
    if [ -e /dev/nvidia-uvm ]; then
        return 0
    fi

    if command -v nvidia-modprobe >/dev/null 2>&1; then
        nvidia-modprobe -c 0 -u || true
    else
        modprobe nvidia-uvm 2>/dev/null || true
    fi

    [ -e /dev/nvidia-uvm ] ||
        die "/dev/nvidia-uvm を作れなかった。ホストのドライバ導入を確認する。"
}

# ホスト再起動後も /dev/nvidia* が揃うようにしておく。
# これが無いと、再起動のたびに GPU 付きコンテナが GPU を見失う。
install_host_unit() {
    _unit=/etc/systemd/system/nvidia-lxc-devices.service
    if [ -f "$_unit" ]; then
        return 0
    fi

    log "ホストに $_unit を置く (再起動後のデバイス生成用)..."
    if [ -n "$DRY_RUN" ]; then
        return 0
    fi

    cat > "$_unit" <<'UNIT'
[Unit]
Description=Create NVIDIA device nodes for LXC guests
After=local-fs.target
Before=pve-guests.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/nvidia-modprobe -c 0 -u

[Install]
WantedBy=multi-user.target
UNIT

    systemctl daemon-reload
    systemctl enable nvidia-lxc-devices.service
}

# コンテナに渡す NVIDIA のデバイスを並べる。
nvidia_device_list() {
    for _d in /dev/nvidia[0-9]* /dev/nvidiactl /dev/nvidia-uvm \
              /dev/nvidia-uvm-tools /dev/nvidia-modeset; do
        if [ -c "$_d" ]; then
            echo "$_d"
        fi
    done
}

# pct が dev0: 形式のデバイス渡しに対応しているか (PVE 8.2 以降)。
has_dev_passthrough() {
    pct set --help 2>&1 | grep -qF -- '-dev[n]'
}

# 旧 PVE 向け。/etc/pve/lxc/<ctid>.conf に lxc.* を直接書く。
append_legacy_device_config() {
    _conf=/etc/pve/lxc/$1.conf

    log "$_conf に lxc.cgroup2 / lxc.mount.entry を追記する..."
    if [ -n "$DRY_RUN" ]; then
        return 0
    fi

    nvidia_device_list | while read -r _d; do
        _maj=$(printf '%d' "0x$(stat -c '%t' "$_d")")
        _min=$(printf '%d' "0x$(stat -c '%T' "$_d")")
        echo "lxc.cgroup2.devices.allow: c $_maj:$_min rwm"
        echo "lxc.mount.entry: $_d ${_d#/} none bind,optional,create=file"
    done >> "$_conf"
}

# コンテナのネットワークが上がるまで待つ。
wait_for_network() {
    _n=0
    while [ "$_n" -lt 60 ]; do
        if pct exec "$1" -- getent hosts github.com >/dev/null 2>&1; then
            return 0
        fi
        _n=$((_n + 1))
        sleep 2
    done
    die "コンテナのネットワークが上がらなかった (pct exec $1 -- ip a で確認する)。"
}

# ------------------------------------------------------------------ 引数

[ $# -ge 3 ] || { usage; exit 1; }

CTID=$1
CT_HOSTNAME=$2
CT_USER=$3
shift 3

while [ $# -gt 0 ]; do
    case $1 in
        --template)    TEMPLATE=$2;    shift 2 ;;
        --storage)     STORAGE=$2;     shift 2 ;;
        --rootfs-size) ROOTFS_SIZE=$2; shift 2 ;;
        --cores)       CORES=$2;       shift 2 ;;
        --memory)      MEMORY=$2;      shift 2 ;;
        --swap)        SWAP=$2;        shift 2 ;;
        --bridge)      BRIDGE=$2;      shift 2 ;;
        --ip)          IP=$2;          shift 2 ;;
        --ssh-keys)    SSH_KEYS=$2;    shift 2 ;;
        --repo)        REPO=$2;        shift 2 ;;
        --steps)       STEPS=$2;       shift 2 ;;
        --no-gpu)      WITH_GPU=;      shift ;;
        --dry-run)     DRY_RUN=1;      shift ;;
        -h|--help)     usage; exit 0 ;;
        *)             warn "unknown option: $1"; usage; exit 1 ;;
    esac
done

# ------------------------------------------------------------------ 事前確認

[ "$(id -u)" -eq 0 ] || die "PVE ホスト上で root として実行する。"
command -v pct >/dev/null 2>&1 || die "pct が無い。PVE ホスト上で実行する。"

echo "$CTID" | grep -qE '^[0-9]+$' || die "ctid は数字で指定する: $CTID"
if pct status "$CTID" >/dev/null 2>&1; then
    die "ctid $CTID は既に使われている。"
fi

if [ -z "$TEMPLATE" ]; then
    TEMPLATE=$(latest_ubuntu_template)
    [ -n "$TEMPLATE" ] || die "local に Ubuntu テンプレートが無い。pveam download local <template> で入れる。"
    log "テンプレート: $TEMPLATE"
fi

DRIVER_VERSION=
if [ -n "$WITH_GPU" ]; then
    command -v nvidia-smi >/dev/null 2>&1 ||
        die "nvidia-smi が無い。ホストにドライバを入れるか --no-gpu を付ける。"

    DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader |
        head -n 1)
    [ -n "$DRIVER_VERSION" ] || die "ホストのドライバ版を取得できなかった。"

    log "ホストの NVIDIA ドライバ: $DRIVER_VERSION"
    ensure_nvidia_devices
    install_host_unit
fi

# ------------------------------------------------------------------ 作成

set -- create "$CTID" "$TEMPLATE" \
    --hostname "$CT_HOSTNAME" \
    --unprivileged 1 \
    --features nesting=1,keyctl=1 \
    --cores "$CORES" \
    --memory "$MEMORY" \
    --swap "$SWAP" \
    --rootfs "$STORAGE:$ROOTFS_SIZE" \
    --net0 "name=eth0,bridge=$BRIDGE,ip=$IP" \
    --onboot 1

if [ -r "$SSH_KEYS" ]; then
    set -- "$@" --ssh-public-keys "$SSH_KEYS"
else
    warn "$SSH_KEYS が読めないので ssh 鍵は設定しない。"
fi

# PVE 8.2 以降なら dev0: で渡せる。mode=0666 にしないと
# unprivileged コンテナ内の一般ユーザーからデバイスを開けない。
USE_DEV_PASSTHROUGH=
if [ -n "$WITH_GPU" ] && has_dev_passthrough; then
    USE_DEV_PASSTHROUGH=1
    _i=0
    for _dev in $(nvidia_device_list); do
        set -- "$@" "--dev$_i" "$_dev,mode=0666"
        _i=$((_i + 1))
    done
fi

log "コンテナ $CTID ($CT_HOSTNAME) を作る..."
run pct "$@"

if [ -n "$WITH_GPU" ] && [ -z "$USE_DEV_PASSTHROUGH" ]; then
    append_legacy_device_config "$CTID"
fi

log "コンテナ $CTID を起動する..."
run pct start "$CTID"

if [ -n "$DRY_RUN" ]; then
    log "+ (ネットワーク待ち)"
else
    wait_for_network "$CTID"
fi

# ------------------------------------------------------------ プロビジョニング

PROVISION=$(mktemp)
trap 'rm -f "$PROVISION"' EXIT

cat > "$PROVISION" <<EOF
#!/bin/sh
#
# create-lxc.sh がコンテナ内で走らせる。
#
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git sudo ca-certificates curl

if [ -d "$DEST/.git" ]; then
    git -C "$DEST" pull --ff-only
else
    git clone --depth 1 "$REPO" "$DEST"
fi

if ! id -u "$CT_USER" >/dev/null 2>&1; then
    "$DEST/adduser.sh" "$CT_USER"
fi

# GPU のデバイスファイルを触れるようにしておく。
for g in video render; do
    if getent group "\$g" >/dev/null 2>&1; then
        usermod -aG "\$g" "$CT_USER"
    fi
done

chown -R "$CT_USER:$CT_USER" "$DEST"

su - "$CT_USER" -c "NVIDIA_DRIVER_VERSION='$DRIVER_VERSION' '$DEST/setup.sh' $STEPS"
EOF

log "コンテナ内で clone と setup.sh を実行する..."
if [ -n "$DRY_RUN" ]; then
    log "+ pct push $CTID <provision.sh> /root/provision.sh --perms 755"
    log "+ pct exec $CTID -- /root/provision.sh"
    log ""
    log "--- provision.sh ---"
    cat "$PROVISION"
else
    pct push "$CTID" "$PROVISION" /root/provision.sh --perms 755
    pct exec "$CTID" -- /root/provision.sh
fi

# ------------------------------------------------------------------ 完了

log ""
log "コンテナ $CTID ($CT_HOSTNAME) の準備ができた。"
log "  入る:     pct enter $CTID"
log "  ssh:      ssh $CT_USER@<ip>   (pct exec $CTID -- ip -4 addr show eth0)"
if [ -n "$WITH_GPU" ]; then
    log "  GPU 確認: pct exec $CTID -- nvidia-smi"
fi
log ""
log "docker グループと LANG の反映は次のログインから。"
log "claude は初回のみ手動ログインが必要。"
