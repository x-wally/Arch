#!/bin/bash

read -p "Enter keymap name (es: it): " KEYMAP_NAME
read -p "Enter country code (es: IT): " COUNTRY
read -p "Enter device name (es: wlan0): " DEVICE_NAME
read -p "Enter adapter name (es: phy0): " ADAPTER_NAME
read -p "Enter station name (es: wlan0): " STATION_NAME
read -p "Enter WiFi name (es: HomeWifi123): " WIFI_NAME
read -p "Enter WiFi password (es: HomePass123): " WIFI_PASS
read -p "Enter disk name (es: nvme0n1): " DISK_NAME
PART_NAME_1="/dev/${DISK_NAME}1"
PART_NAME_2="/dev/${DISK_NAME}2"
PART_NAME_3="/dev/${DISK_NAME}3"
read -p "Enter font name (es: drdos8x16): " FONT_NAME
read -p "Enter locale name (es: it_IT.UTF-8): " LOCALE_NAME
read -p "Enter hostname (es: arch): " HOSTNAME
read -p "Enter username (es: user): " USERNAME
read -p "Enter user password (es: pass): " USER_PASS
read -p "Enter root password (es: root): " ROOT_PASS
read -p "Enter timezone (es: Europe/Rome): " TIMEZONE

#########################################

## LIST KEYMAPS
ls /usr/share/kbd/keymaps/**/*.map.gz | grep it
# or
localectl list-keymaps | grep it

## LOAD KEYMAP
loadkeys ${KEYMAP_NAME}

#########################################

## LIST CONSOLE FONTS
ls /usr/share/kbd/consolefonts

## SET CONSOLE FONT
setfont = ${FONT_NAME}

#########################################

## CHECK ARCHITECHTURE
cat /sys/firmware/efi/fw_platform_size

## CHECK BOOT MODE
ls /sys/firmware/efi/efivars
# something: UEFI, nothing: BIOS

#########################################

## NETWORK HW INFO
ip a
ip link

## UNBLOCK WIFI CARD
rfkill unblock wlan

## LIST WIFI DEVICES
device list

## TURN ON DEVICES
device ${DEVICE_NAME} set-property Powered on

## TURN ON ADAPTERS
adapter ${ADAPTER_NAME} set-property Powered on

## SCAN NETWORKS
station ${STATION_NAME} scan

## LIST AVAILABLE NETWORKS
# station ${STATION_NAME} get-networks

## CONNECT TO NETWORK
station ${STATION_NAME} connect ${WIFI_NAME}

*insert* ${WIFI_PASS} 
*exit iwctl*

## CHECK INTERNET CONNECTION
ping -c 5 archlinux.org

#########################################

## SET TIME AND DATE
timedatectl set-ntp true
timedatectl set-timezone ${TIMEZONE}

#########################################

## BACKUP MIRRORLIST
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

## POPULATE MIRRORLIST
reflector --download-timeout 60 --country ${COUNTRY} --age 12 --sort rate --save /etc/pacman.d/mirrorlist

#########################################

## LIST PARTITIONS
lsblk

## MAKE PARTITIONS
# gdisk /dev/${disk-name}

## EXAMPLE 3 PARTITIONS
# n *enter* *enter*
# +${size1}M
# n *enter* *enter*
# +${size2}G
# n *enter* *enter* 
# +${size3}G

## EXAMPLE 
# (/dev/nvme0n1p1) 512M : EFI
# (/dev/nvme0n1p4) 100G : ROOT
# (/dev/nvme0n1p5)   3G : SWAP

#########################################

lsblk

### FORMAT PARTITIONS

## ESP or EFI or BOOT partition
# format first (/dev/nvme0n1p1) to FAT 32
mkfs.fat -F32 ${PART_NAME_1}

## ROOT partition
# format second (/dev/nvme0n1p4) to btrfs
mkfs.btrfs ${PART_NAME_2}

## SWAP partition
# format third (/dev/nvme0n1p5) to swap
mkswap ${PART_NAME_3}
# swapon third partition
swapon ${PART_NAME_3}

#########################################

# mount second (/dev/nvme0n1p4) in /mnt
mount ${PART_NAME_2} /mnt

# make @ subvolume (/mnt/@)
btrfs subvolume create /mnt/@
# make @home subvolume (/mnt/@home)
btrfs subvolume create /mnt/@home
# make @snapshots subvolume (/mnt/@snapshots)
btrfs subvolume create /mnt/@snapshots
# make @var_log subvolume (/mnt/@var_log)
btrfs subvolume create /mnt/@var_log

# un-mount root
umount /mnt

#########################################

## mount EFI Partition in /mnt/boot
# mount /dev/nvme0n1p1 in /mnt/boot
mount /dev/${PART_NAME_1} /mnt/boot

## mount @ subvolume in /mnt
mount -o noatime,compress=zstd,space_cache=v2,subvol=@ ${PART_NAME_2} /mnt

# make directories for the mountpoints
mkdir -p /mnt/{boot,home,.snapshots,var/log}

# mount @home subvolume in /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home ${PART_NAME_2} /mnt/home
# mount @snapshots subvolume in /mnt/.subvolume
mount -o noatime,compress=zstd,space_cache=v2,subvol=@snapshots ${PART_NAME_2} /mnt/.snapshots
# mount @var_log subvolume in /mnt/var/log
mount -o noatime,compress=zstd,space_cache=v2,subvol=@var_log ${PART_NAME_2} /mnt/var/log

lsblk

#########################################

## install the system and other packages
pacstrap /mnt base base-devel linux linux-firmware sudo vim nano ntfs-3g networkmanager 
# vesa amd-ucode

#########################################

## generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

## check fstab file
# cat /mnt/etc/fstab

#########################################

## enter into the system
arch-chroot /mnt

#########################################

## set timezone
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime

## syncronize hw clock with sw clock
hwclock --systohc

#########################################

## UNCOMMENT LOCALES
nano /etc/locale.gen
*un-comment* ${locale-name} UTF-8

## GENERATE LOCALES
locale-gen

echo "LANG=${LOCALE_NAME}" >> /etc/locale.gen

#########################################

## edit vconsole
echo "KEYMAP=${keymap-name}" >> /etc/vconsole.conf

## edit hostame
echo "${hostname}" >> /etc/hostname

## edit hosts
echo -e "127.0.0.1 \t localhost\n" >> /etc/hosts
echo -e "::1 \t localhost\n" >> /etc/hosts
echo -e "127.0.1.1 \t ${hostname}.localdomain \t ${hostname}\n" >> /etc/hosts

#########################################

## make root password
passwd 
*insert* ${root-pass}
*insert* ${root-pass}

## install packages
pacman -S grub efibootmgr os-prober networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools git reflector snapper bluez bluez-utils cups hplip xdg-utils xdg-usr-dirs alsa-utils pulseaudio pulseaudio-bluetooth inetutils base-devel linux-headers

#########################################

## add btrfs module
nano /etc/mkinitcpio.conf
*change* " MODULES() " *to* " MODULES(btrfs) "

## mkinitcpio
mkinitcpio -P linux

#########################################

## install grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

## enable os prober
nano /etc/default/grub
*uncomment* GRUB_DISABLE_OS_PROBER=false

## grub make configuration file 
grub-mkconfig -o /boot/grub/grub.cfg

#########################################

## enable services
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups

#########################################

## add user
useradd -mG wheel ${username}
passwd ${username}
*insert* ${user-pass}
*insert* ${user-pass}

## let wheel users use sudo
EDITOR=nano visudo
*un-comment* %wheel ALL=(ALL) ALL

#########################################

## install package 
pacman -S bash-completion

## exit, unmount all partitions, and reboot 
exit
umount -a
reboot now

#########################################

## connect to wifi
nmtui
*connect to wifi*

## install package 
pacman -S terminus-font 

## sent console font
setfont = ${font-name} 

#########################################

## use snapper to remake /.snapshots subvolume
sudo umount /.snapshots
sudo rm -r /.snapshots
sudo snapper -c root create-config /
sudo btrfs subvolume delete /.snapshots
sudo mkdir /.snapshots
sudo mount -a
## give /.snapshots permissions
sudo chmod a+rx /.snapshots
sudo chown :${username} /.snapshots

## add username to allowed users
sudo nano /etc/snapper/configs/root
*change* ALLOW_USERS="" *to* ALLOW_USERS="${username}" 
## change timeline lits 
*change* [...] *to* :
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"

## enable snappee services
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer

#########################################

## clone yay git repo
git clone https://aur.archlinux.org/yay
cd yay/
chmod -R a+w .
## install yay
makepkg -si PKGBUILD

## install packages
yay -S snap-pac-grub snapper-gui
[Diffs to show?] N
[Import?] Y

#########################################

## install amd driver packages
pacman -S xf86-video-amdgpu xf86-video-ati mesa vulkan-radeon amd-ucode amdvlk

## install GNOME desktop environment
# pacman -S xorg xorg-server gnome-tweaks gdm
## install KDE desktop environment
pacman -S plasma plasma-wayland-session sddm

## install other packages
pacman -S firefox rsync

#########################################

## enable gdm (GNOME & KDE)
sudo systemctl enable gdm
## enable sddm (doesn't work with GNOME)
# sudo systemctl enable sddm

#########################################

## add hook for boot backup
sudo mkdir /etc/pacman.d/hooks
sudo nano /etc/pacman.d/hooks/50-bootbackup.hook
*insert*:
-----------------------------------------------------------
[Trigger]
Operation = Upgrade
Operation = Install 
Operation = Remove
Type = Path
Target = boot/*

[Action]
Depends = rsync
Description = Backing up /boot ...
When = PreTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
-----------------------------------------------------------

#########################################

## add video resolution to grub configuration file
sudo nano /etc/default/grub 
*change* : "GRUB_CMDLINE_LINUX_DEFAULT=loglevel=3 quiet"
*to* "GRUB_CMDLINE_LINUX_DEFAULT=loglevel=3 quiet video=1366x768"

## update grub configuration file
sudo grub-mkconfig -o /boot/grub/grub.cfg
