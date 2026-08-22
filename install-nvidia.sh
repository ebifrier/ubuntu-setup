#!/bin/sh
#
# LXC コンテナの中に NVIDIA ドライバの userspace だけを入れる。
#
#   ./install-nvidia.sh              # ホストのドライバ版に自動で合わせる
#   ./install-nvidia.sh 580.82.07    # バージョン指定
#
# コンテナはホストとカーネルを共有するので、カーネルモジュールはホスト側に
# 入っているものをそのまま使う。ここで入れるのは libcuda / nvidia-smi などの
# userspace だけで、インストーラは --no-kernel-modules で走らせる。
#
# ホストのモジュールとコンテナの userspace はバージョンが完全に一致していないと
# 動かない (Failed to initialize NVML: Driver/library version mismatch)。
# 版はスクリプトに焼かず、次の順で決める。
#
#   1. 引数
#   2. 環境変数 NVIDIA_DRIVER_VERSION  (proxmox/create-lxc.sh が渡す)
#   3. /proc/driver/nvidia/version     (ホストのモジュールが見えている)
#
# GPU が渡っていない環境 (VM / GPU 無しマシン) では何もせずに終わるので、
# setup.sh の all に入れっぱなしで問題ない。
#
# CUDA toolkit や PyTorch はプロジェクトごとに入れる前提で、ここでは扱わない。
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

DOWNLOAD_BASE=https://download.nvidia.com/XFree86/Linux-x86_64

# ------------------------------------------------------------------ 関数

# /proc/driver/nvidia/version からホストのモジュール版を拾う。
# 行の形は proprietary か open かで変わるので、位置ではなく
# 最初に出てくる x.y(.z) 形式の数字を版として拾う。
#
#   NVRM version: NVIDIA UNIX x86_64 Kernel Module  580.82.07  Tue ...
#   NVRM version: NVIDIA UNIX Open Kernel Module for x86_64  570.133.07  Release ...
#
host_driver_version() {
    [ -r /proc/driver/nvidia/version ] || return 0
    grep -m1 '^NVRM version:' /proc/driver/nvidia/version |
        grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' |
        head -n 1
}

# 今入っている userspace の版 (入っていなければ空)。
current_driver_version() {
    command -v nvidia-smi >/dev/null 2>&1 || return 0
    nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null |
        head -n 1 || true
}

# .run を取ってきて userspace だけ入れる。
install_driver() {
    _version=$1
    _run=NVIDIA-Linux-x86_64-$_version.run
    _work=$(mktemp -d)

    log "NVIDIA ドライバ $_version を取得する..."
    if ! curl -fL --retry 3 -o "$_work/$_run" "$DOWNLOAD_BASE/$_version/$_run"; then
        rm -rf "$_work"
        die "$DOWNLOAD_BASE/$_version/$_run を取得できなかった。バージョンを確認する。"
    fi
    chmod +x "$_work/$_run"

    # カーネルモジュールを作らせないフラグは版によって単複が違うので --help で見る。
    if sh "$_work/$_run" --help 2>/dev/null | grep -q -e '--no-kernel-modules'; then
        _no_kmod=--no-kernel-modules
    else
        _no_kmod=--no-kernel-module
    fi

    log "userspace のみを導入する ($_no_kmod)..."
    sudo sh "$_work/$_run" --silent "$_no_kmod" \
        --no-nouveau-check --no-x-check --no-nvidia-modprobe

    rm -rf "$_work"
}

# Docker から GPU を使うための toolkit。docker が無ければ何もしない。
install_container_toolkit() {
    command -v docker >/dev/null 2>&1 || return 0

    if ! command -v nvidia-ctk >/dev/null 2>&1; then
        log "nvidia-container-toolkit を入れる..."
        apt_install ca-certificates curl gnupg

        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey |
            sudo gpg --dearmor --yes -o /etc/apt/keyrings/nvidia-container-toolkit.gpg
        sudo chmod a+r /etc/apt/keyrings/nvidia-container-toolkit.gpg

        curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
            sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit.gpg] https://#g' |
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

        apt_update force
        apt_install nvidia-container-toolkit
    fi

    sudo nvidia-ctk runtime configure --runtime=docker

    # unprivileged な LXC の中からはホストの cgroup を触れないので、
    # toolkit 側に cgroup の面倒を見させない。これを外すと
    # nvidia-container-cli が "operation not permitted" で落ちる。
    if [ "$(systemd-detect-virt --container 2>/dev/null || echo none)" != none ]; then
        sudo nvidia-ctk config --in-place --set nvidia-container-cli.no-cgroups=true
        log "コンテナ内なので no-cgroups = true にした。"
    fi

    sudo systemctl restart docker
    note "docker から GPU を使うときは --gpus all を付ける (例: docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu24.04 nvidia-smi)。"
}

# ---------------------------------------------------------------- GPU の有無

# GPU が渡っていなければ黙って終わる。
if [ ! -e /dev/nvidia0 ]; then
    log "/dev/nvidia0 が無いので NVIDIA ドライバの導入は飛ばした。"
    exit 0
fi

# ------------------------------------------------------------ バージョン決定

HOST_VERSION=$(host_driver_version)
VERSION=${1:-${NVIDIA_DRIVER_VERSION:-$HOST_VERSION}}

[ -n "$VERSION" ] ||
    die "ドライバのバージョンが判らない。引数か NVIDIA_DRIVER_VERSION で渡す。"

# ホストのモジュール版が読めるなら食い違いを先に潰しておく。
if [ -n "$HOST_VERSION" ] && [ "$HOST_VERSION" != "$VERSION" ]; then
    die "指定は $VERSION だがホストのモジュールは $HOST_VERSION。一致させること。"
fi

# --------------------------------------------------------------- インストール

require_cmd curl

if [ "$(current_driver_version)" = "$VERSION" ]; then
    log "NVIDIA ドライバ $VERSION は既に入っている。"
else
    install_driver "$VERSION"
fi

install_container_toolkit

# --------------------------------------------------------------------- 確認

command -v nvidia-smi >/dev/null 2>&1 ||
    die "nvidia-smi が入らなかった。インストーラのログを確認する。"

nvidia-smi -L
log "NVIDIA ドライバ $VERSION を導入した。"

note "CUDA toolkit / PyTorch はプロジェクトごとに入れる (このスクリプトはドライバのみ)。"
note "ホストのドライバを更新したら、コンテナ側も ./setup.sh nvidia を流し直す。"
