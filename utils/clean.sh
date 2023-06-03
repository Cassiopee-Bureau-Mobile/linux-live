#!/bin/bash


# Clean All

# clean crontab
touch tmp && crontab -u root tmp
rm tmp
# clean crypttab
echo "# <target name> <source device>       <key file>      <options>" > tmp && cat tmp > /etc/crypttab
rm tmp

# unmount all the partitions
echo "Cleaning..."
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
rm /a/temp_cron
rm /a/temp_cron.bak
# reset the cryptab
rm /a/temp_crypttab.bak