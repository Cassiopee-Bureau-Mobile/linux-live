# Linux Live Kit

Use this set of scripts to turn your existing preinstalled Linux
distribution into a Live Kit (formely known as Live CD) on an USB stick.
Make sure to extract and use it on a posix-compatible filesystem,
since it creates some (sym)links and such.

This version create a Live Linux on a USB stick with a crypted home directory. It allows you to keep your data in /home totally safe.

<h1>How to create a Live Linux</h1>

<h2>The build</h2>

- First of all **set up your Custom Linux**. To do so, I use a VM on Virtual Box to set up all the files and software you want to have on your linux. _You have a full installation guid for Debian [here](/DOC/Full_Debian_Installation.md)_

- Once you have your custom linux set up, you need to **create a Live Kit** from it. To do so, download the Linux Live Kit from this repo. You may not want to include the repo in your futur Live linux, so I recommend you to put it in a directory such as /a. _(Be warned, if you put it to /tmp, some distros may erase it on reboot.)_

_You can create a directory /a and put the Live Kit in it with the following commands :_

    sudo mkdir /a

    sudo wget https://github.com/Cassiopee-Bureau-Mobile/linux-live/archive/refs/heads/master.zip -P /a

    sudo unzip /a/master.zip -d /a

- Before you start building your Kit, edit the file ./config. Most importantly change the LIVEKITNAME variable and the size of your wanted home dir.

- If you want to enable persistente changes in your Live linux system (like adding new, software, or editing other files than thoses in your home directory), you need to set the PERSISTENT variable to 1.

- Make sure your kernel is in /vmlinuz or change the path in ./config. Your kernel must support squashfs. Your kernel must also support either aufs or overlayfs or both. AUFS is recommended for more flexibility, but if your distro does not support it, overlayfs will work too.

- Linux Live Kit comes with precompiled static binaries in ./initramfs directory. Those may be outdated but will work. You may replace them by your own statically linked binaries, if you know how to compile them.

- If you have tmpfs mounted on /tmp during building your Live Kit ISO, make sure you have enough RAM since LiveKit will store lots of data in /tmp. If you are low on RAM, make sure /tmp is a regular on-disk directory.

- When done connect the USB key to your VM. Run the ./build script to create your Live Secure USB stick

```
sudo /a/linux-live-master/build.sh /dev/sdX
```

_Tip: To find out the device of your USB key, you can use the command `sudo fdisk -l`._

- Once the build is complete (approximately 30 minutes), the USB key is ready. Safely remove it and boot a machine from it.

<h2>You can now start on your USB stick !</h2>

Notes:

- In the syslinux boot interface, you can customize the syslinux.cfg to have the choice between Persistent mode or Live mode. if you execute the classic Linux, you will have the exact linux you've build. You can have persistent changes using the right option, but this will never change the original Live linux you've build. _So be aware that your persistent changes will only be available with the Persistent changes mode in the boot interface._

## Other Configurations

During the build process, an error may occur _(like if the USB is disconnected during the execution)_.

In such cases, if your build is already done and there is a file named linux-data-3699 in your tmp folder, you don't need to rebuild. Instead, execute the following command directly:

```
sudo /a/linux-live-master/utils/install_without_build.sh /dev/sdX LIVEKITDATA LIVEKITNAME
```

This project was forked from Tomas M. <http://www.linux-live.org> and modified by Clément Safon
