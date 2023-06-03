#!/bin/bash
# Linux Live Kit version 7 - Automated By Clément Safon (Cassiopee-Bureau-Mobile) - jun 2023

export PATH=.:./tools:../tools:/usr/sbin:/usr/bin:/sbin:/bin:/

CHANGEDIR=$(dirname $(readlink -f $0))
echo "Changing current directory to $CHANGEDIR"
cd $CHANGEDIR
CWD="$(pwd)"

. ./config || exit 1
. ./livekitlib || exit 1

# only root can continue, because only root can read all files from your system
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
# check for mksquashfs with xz compression
if [ "$(mksquashfs 2>&1 | grep "Xdict-size")" = "" ]; then
   echo "mksquashfs not found or doesn't support -comp xz, aborting, no changes made"
   echo "you may consider installing squashfs-tools package"
   exit 1
fi
# check if USB device exists
if [ ! -b "$USBDEV" ]; then
   echo "Device $USBDEV not found, aborting"
   exit 1
fi
# check if cryptsetup is installed
if [ "$(which cryptsetup)" = "" ]; then
   echo "cryptsetup not found, aborting, no changes made"
   echo "you may consider installing cryptsetup package"
   exit 1
fi
# check if mkfsofs is installed
MKISOFS=$(which mkisofs)
if [ "$MKISOFS" = "" ]; then
   MKISOFS=$(which genisoimage)
fi
if [ "$MKISOFS" = "" ]; then
   echo "Cannot find mkisofs or genisoimage, stop"
   exit 3
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

# Supprimer toutes les partitions existantes sur la clé USB
echo "Suppression des partitions existantes..."
sudo parted $USBDEV mklabel gpt

# Créer la première partition de taille (100MiB) en fat32
echo "Création de la première partition (100MiB) en fat32..."
sudo parted -a optimal $USBDEV mkpart primary fat32 0% 100MiB

# Créer la deuxième partition de taille (HOME_SIZE) en ext4
echo "Création de la deuxième partition ($HOME_SIZE) en ext4..."
sudo parted -a optimal $USBDEV mkpart primary ext4 100MiB ${HOME_SIZE}MiB

# Créer la troisième partition pour l'espace restant en ext4
echo "Création de la troisième partition en ext4..."
sudo parted -a optimal $USBDEV mkpart primary ext4 ${HOME_SIZE}MiB 100%

# Mettre à jour la table de partitions
sudo partprobe $USBDEV

# Formater les partitions
echo "Formatage de la première partition en FAT32..."
sudo mkfs.fat -F32 ${USBDEV}1

echo "Formatage de la deuxième partition en ext4..."
sudo mkfs.ext4 ${USBDEV}2

echo "Formatage de la troisième partition en ext4..."
sudo mkfs.ext4 ${USBDEV}3

echo "Terminé !"
echo "-----------------------------"

# create Luks partition
echo "Création de la partition chiffrée..."
cryptsetup luksFormat ${USBDEV}2
cryptsetup open ${USBDEV}2 encrypted
mkfs.ext4 /dev/mapper/encrypted
mkdir /mnt/encrypted
mount -t ext4 /dev/mapper/encrypted /mnt/encrypted

# Configure the tabs
#
# Unused :
# copy unlockStorage script
# cp $CWD/setup/unlockStorage.sh /etc/unlockStorage.sh
#
# on edite les crontab pour le root
CMD_CRONTAB_0="@reboot mkdir /home"
CMD_CRONTAB_1="@reboot mount /dev/mapper/encrypted /home"
CMD_CRONTAB_2="@reboot chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER"
crontab -l -u root > /a/temp_cron
cp /a/temp_cron /a/temp_cron.bak
echo -e "$CMD_CRONTAB_1" >> /a/temp_cron
echo -e "$CMD_CRONTAB_2" >> /a/temp_cron
crontab -u root /a/temp_cron

# on edite le cryptab
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
echo "Copying live kit to ${USBDEV}3..."
mkdir /mnt/sys_files
mount ${USBDEV}3 /mnt/sys_files
cp -r $LIVEKITDATA/$LIVEKITNAME /mnt/sys_files

# build the bootfiles in the USB device
echo "Building bootfiles in ${USBDEV}1..."
mkdir /mnt/boot
mount ${USBDEV}1 /mnt/boot
cd /mnt/sys_files/$LIVEKITNAME/boot
./bootinst.sh

# copy the bootfiles to the USB boot partition
echo "Copying bootfiles to ${USBDEV}1..."
cp -r /mnt/sys_files/EFI /mnt/boot

# Clean All
#
#
# unmount all the partitions
echo "Cleaning..."
umount /mnt/boot
umount /mnt/sys_files
umount /mnt/encrypted
rm -r /mnt/boot
rm -r /mnt/sys_files
rm -r /mnt/encrypted
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