#!/bin/bash
# Linux Live Kit version 7 - Automated By Clément Safon (Cassiopee-Bureau-Mobile) - jun 2023

export PATH=.:./tools:../tools:/usr/sbin:/usr/bin:/sbin:/bin:/

. ../config || exit 1
. ../livekitlib || exit 1
. ./clean.sh || exit 1

# only root can continue
allow_only_root

# get USB device name in $1
if [ "$1" = "" ]; then
   echo "Usage: $0 <device>"
   echo "Example: $0 /dev/sdb"
   exit 1
fi
USBDEV="$1"

# get LIVEKITDATA in $2
if [ "$2" = "" ]; then
   echo "Usage: $0 <device> <livekitdata>"
   echo "Example: $0 /dev/sdb /tmp/linux-data-3599"
   exit 1
fi
LIVEKITDATA="$2"

# get LIVEKITNAME in $3
if [ "$3" = "" ]; then
   echo "Usage: $0 <device> <livekitdata> <livekitname>"
   echo "Example: $0 /dev/sdb /tmp/linux-data-3599 linux"
   exit 1
fi
LIVEKITNAME="$3"

# check if $LIVEKITNAME folder exists
if [ ! -d "$LIVEKITDATA/$LIVEKITNAME" ]; then
   echo "Directory $LIVEKITDATA/$LIVEKITNAME not found, aborting"
   exit 1
fi


# Check the requirements
#
# check if cryptsetup is installed
if [ "$(which cryptsetup)" = "" ]; then
   echo "cryptsetup not found, aborting, no changes made"
   echo "you may consider installing cryptsetup package"
   exit 1
fi

# select the syslinux file base on $PERSISTENT
if [ $PERSISTENT -eq "0" ]; then
   cp utils/syslinux_live.cfg bootfiles/syslinux.cfg
else
   cp utils/syslinux_persistent.cfg bootfiles/syslinux.cfg
fi

# Prepare the USB device to update the tabs
#
# format USB device
echo "-----------------------------"
echo "Formatting $USBDEV..."

if [ "$(findmnt -l | grep $USBDEV)" != "" ]; then
   echo "Umouting all partitons for $USBDEV..."
   umount $USBDEV*
fi

# erase all partitions 
echo "Suppression des partitions existantes..."
sudo parted $USBDEV mklabel gpt

# create boot partition (FAT32-100MiB)
echo "Création de la première partition (100MiB) en fat32..."
sudo parted -a optimal $USBDEV mkpart primary fat32 0% 100MiB

# create home partition (ext4-HOME_SIZEMiB)
echo "Création de la deuxième partition ($HOME_SIZE) en ext4..."
sudo parted -a optimal $USBDEV mkpart primary ext4 100MiB $((HOME_SIZE+100))MiB

# create system files partition (ext4-100%)
echo "Création de la troisième partition en ext4..."
sudo parted -a optimal $USBDEV mkpart primary ext4 $((HOME_SIZE+100))MiB 100%

# update the partition table
sudo partprobe $USBDEV

# format partitions
echo "Formatage de la première partition en FAT32..."
sudo mkfs.fat -F32 ${USBDEV}1

echo "Formatage de la deuxième partition en ext4..."
sudo mkfs.ext4 ${USBDEV}2

echo "Formatage de la troisième partition en ext4..."
sudo mkfs.ext4 ${USBDEV}3

echo "Terminé !"
echo -e "-----------------------------\n\n"

# create Luks partition on the second partition
echo "Création de la partition chiffrée..."
cryptsetup luksFormat ${USBDEV}2
cryptsetup open ${USBDEV}2 encrypted
mkfs.ext4 /dev/mapper/encrypted
# check if the directory exists
if [ ! -d "/mnt/encrypted" ]; then
   mkdir /mnt/encrypted
fi
mount -t ext4 /dev/mapper/encrypted /mnt/encrypted

# Configure the tabs
#
# Unused :
# copy unlockStorage script
# cp $CWD/setup/unlockStorage.sh /etc/unlockStorage.sh
#
# rewrite crontab for root to mount the encrypted partition at boot
echo "Configuration des crontab et crypttab..."
CMD_CRONTAB_1="@reboot mount /dev/mapper/encrypted /home && chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER"
crontab -l -u root > /a/temp_cron
cp /a/temp_cron /a/temp_cron.bak
echo "$CMD_CRONTAB_1" >> /a/temp_cron
crontab -u root /a/temp_cron

# rewrite crypttab to unlock the encrypted partition at boot
USB_UUID=$(ls -l /dev/disk/by-uuid/ | grep $( echo ${USBDEV}2 | sed 's/\/dev\///' ) | awk '{print $9}')
CMD_CRYPTAB_1="encrypted UUID=$USB_UUID none"
cp /etc/crypttab /a/temp_crypttab.bak
echo -e "$CMD_CRYPTAB_1" >> /etc/crypttab


# Export build and install bootfiles
# 
#
# copy home directory to the encrypted partition
echo "Copie du répertoire home vers la partition chiffrée..."
cp -r /home/$SUDO_USER /mnt/encrypted

# copy live kit to the USB device
echo "Copie du live kit vers ${USBDEV}3..."
# check if the directory exists
if [ ! -d /mnt/sys_files ]; then
   mkdir /mnt/sys_files
fi
mount ${USBDEV}3 /mnt/sys_files
cp -r $LIVEKITDATA/$LIVEKITNAME /mnt/sys_files

# build the bootfiles in the USB device
echo "Construction des fichiers de boot dans ${USBDEV}1..."
# check if the directory exists
if [ ! -d /mnt/boot ]; then
   mkdir /mnt/boot
fi
mount ${USBDEV}1 /mnt/boot
cd /mnt/sys_files/$LIVEKITNAME/boot
./bootinst.sh

# copy the bootfiles to the USB boot partition
echo "Copie des fichiers de boot dans ${USBDEV}1..."
cp -r /mnt/sys_files/EFI /mnt/boot

# Clean All
#
#
# unmount all the partitions
sleep 5

echo "Nettoyage..."
while [ $? -ne 0 ]; do
   sleep 1
   umount /mnt/boot && rm -r /mnt/boot
done
while [ $? -ne 0 ]; do
   sleep 1
   umount /mnt/sys_files && rm -r /mnt/sys_files
done
while [ $? -ne 0 ]; do
   sleep 1
   umount /mnt/encrypted && rm -r /mnt/encrypted
done
# close cryptsetup encrypted partition
cryptsetup close encrypted
# reset the tabs configurations
crontab -u root /a/temp_cron.bak
rm /a/temp_cron
rm /a/temp_cron.bak
# reset the cryptab
cp /a/temp_crypttab.bak /etc/crypttab 
rm /a/temp_crypttab.bak

echo "Terminé !"
echo "-----------------------------"
echo ""
echo "Le système est prêt à être utilisé."
echo "Ejectez la clé USB et démarrez votre ordinateur dessus."