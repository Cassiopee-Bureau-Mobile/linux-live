#!/bin/bash

DEV=$(findmnt -l | awk '{print $2}' | grep -oE 'sd[a-Z]')3

cryptsetup open /dev/$DEV encrypted
mkdir /mnt/encrypted
mount /dev/mapper/encrypted /mnt/encrypted

pkill -KILL -u $SUDO_USER