#!/bin/sh
#
# ユーザーを作る。docker / sudo グループに入れ、root の authorized_keys と
# パスワード無しの sudo も設定する。
#
#   ./adduser.sh <user> [uid]
#
# uid を省略した場合は useradd の既定 (システムの自動割り当て) に任せる。
#
# 他の環境にそのまま持っていけるよう、lib/common.sh には依存させない。
#
set -e

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "usage: $0 <user> [uid]" >&2
    exit 1
fi

NEW_USER=$1
NEW_ID=$2

if [ -n "$NEW_ID" ]; then
    sudo groupadd -g "$NEW_ID" "$NEW_USER"
    sudo useradd -m -u "$NEW_ID" -g "$NEW_ID" -s /bin/bash "$NEW_USER"
else
    # -U でユーザー名と同じグループを一緒に作る。
    sudo useradd -m -U -s /bin/bash "$NEW_USER"
fi

# docker を入れていない環境でも止まらないようにする。
if getent group docker >/dev/null 2>&1; then
    sudo usermod -aG docker "$NEW_USER"
else
    echo "docker グループが無いので飛ばした (./setup.sh docker で入る)。"
fi
sudo usermod -aG sudo "$NEW_USER"

# root の authorized_keys をそのまま引き継ぐ (無ければ飛ばす)。
NEW_HOME=$(getent passwd "$NEW_USER" | cut -d: -f6)
if sudo test -f /root/.ssh/authorized_keys; then
    sudo install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "$NEW_HOME/.ssh"
    sudo install -m 600 -o "$NEW_USER" -g "$NEW_USER" \
        /root/.ssh/authorized_keys "$NEW_HOME/.ssh/authorized_keys"
else
    echo "/root/.ssh/authorized_keys が無いので ssh 鍵の設定は飛ばした。"
fi

# パスワード無しで sudo できるようにする。
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$NEW_USER" >/dev/null
sudo chmod 440 "/etc/sudoers.d/$NEW_USER"

echo "$NEW_USER (uid=$(id -u "$NEW_USER")) を作った。"
