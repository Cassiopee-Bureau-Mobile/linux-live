#!/bin/bash

export PATH=.:./tools:../tools:/usr/sbin:/usr/bin:/sbin:/bin:/

# allow_only_root
if [ "0$UID" -ne 0 ]; then
    echo "Only root can run $(basename $0)"; exit 1
fi

if [ ! $1 ]; then
    echo "Usage: $0 <user>"
    exit 1
fi
USER=$1

#chek if $USER is a real user
if [ ! $(getent passwd $USER) ]; then
    echo "User $USER does not exist"
    exit 1
fi

#
# This script is used to encrypt the home directory of the live system.
#

apt install cryptsetup -y

HOME_DEV=$(findmnt -l | grep home | awk '{print $2}')

#make a backup of the home directory
if [ ! -d "/a" ]; then
    mkdir /a
fi
mkdir /a/data
cp -r /home/$USER /a/data

#unmount the home directory
umount /home

#remove the mount of the home directory on fstab
sed -i '/home/s/^/# /' filename

#encrypt the partition
cryptsetup luksFormat $HOME_DEV

#open the encrypted partition
cryptsetup open $HOME_DEV encrypted

#format the partition
mkfs.ext4 /dev/mapper/encrypted

#mount the partition
if [ ! -d "/home" ]; then
    mkdir /home
fi
mount /dev/mapper/encrypted /home

#copy the backup to the encrypted partition
cp -r /a/data/$USER /home

chown -R $USER:$USER /home/$USER