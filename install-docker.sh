#!/bin/sh
#
# Docker Engine を公式 apt リポジトリから入れる。
# docker compose (plugin) と buildx も一緒に入る。
# 実行ユーザーを docker グループに入れるので、sudo 無しで docker が使える。
#
#   ./install-docker.sh
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

# Ubuntu 同梱の docker.io / podman-docker とは競合するので外しておく。
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y "$pkg" >/dev/null 2>&1 || true
done

apt_install ca-certificates curl gnupg

# GPG 鍵
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
    sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# リポジトリ。Mint などの派生では UBUNTU_CODENAME を使う。
ARCH=$(dpkg --print-architecture)
# shellcheck disable=SC1091  # /etc/os-release は実行時のホストにしか無い
CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

apt_update force
apt_install docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker

# sudo 無しで使えるようにする (反映は次のログインから)
if ! id -nG "$(id -un)" | tr ' ' '\n' | grep -qx docker; then
    sudo usermod -aG docker "$(id -un)"
    log "$(id -un) を docker グループに追加した。"
    note "docker グループの反映は次のログインから (即試すなら newgrp docker)。"
fi

sudo docker --version
sudo docker compose version
