#!/bin/sh
#
# ユーザーを uid/gid 指定で作る。docker / sudo グループにも入れる。
#
#   ./adduser.sh <user> <uid>
#
# 他の環境にそのまま持っていけるよう、lib/common.sh には依存させない。
#
set -e

if [ $# -ne 2 ]; then
    echo "usage: $0 <user> <uid>" >&2
    exit 1
fi

NEW_USER=$1
NEW_ID=$2

sudo groupadd -g "$NEW_ID" "$NEW_USER"
sudo useradd -m -u "$NEW_ID" -g "$NEW_ID" -s /bin/bash "$NEW_USER"

# docker を入れていない環境でも止まらないようにする。
if getent group docker >/dev/null 2>&1; then
    sudo usermod -aG docker "$NEW_USER"
else
    echo "docker グループが無いので飛ばした (./setup.sh docker で入る)。"
fi
sudo usermod -aG sudo "$NEW_USER"

echo "$NEW_USER (uid=$NEW_ID) を作った。"
