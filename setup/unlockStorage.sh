#!/bin/bash

# allow_only_root
if [ "0$UID" -ne 0 ]; then
    echo "Only root can run $(basename $0)"; exit 1
fi

DEV=$(findmnt -l | awk '{print $2}' | grep -oE 'sd[a-Z]')3

cryptsetup open /dev/$DEV encrypted
if [ ! -d "/home" ]; then
    mkdir /home
fi
mount /dev/mapper/encrypted /home
chown -R $USER:$USER /home/$USER

pkill -KILL -u $SUDO_USER