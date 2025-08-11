#!/bin/sh

if [ -d $HOME/.emacs.d ]; then
    rm -rf $HOME/.emacs.d
fi
cp -rf .emacs.d $HOME/
cp -f .emacs $HOME/
cp -f .screenrc $HOME

sudo cp -f bin/ec /usr/local/bin/
sudo chmod +x /usr/local/bin/ec
