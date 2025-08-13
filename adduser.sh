#!/bin/sh

if [ $# -le 2 ]; then
    echo "$0 user id"
    exit 1
fi

NEW_USER=$1
NEW_ID=$2

sudo groupadd -g $NEW_ID $NEW_USER
sudo useradd -m -u $NEW_ID -g $NEW_ID -s /bin/bash $NEW_USER
sudo usermod -aG docker $NEW_USER
sudo usermod -aG sudo $NEW_USER
