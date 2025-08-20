#!/usr/bin/env bash

bold=$( tput bold )
reg=$( tput sgr0 )

#PACMAN
echo ${bold}SETTING UP PACMAN...${reg}
insert_at=$(( $( grep -n "#Color" /etc/pacman.conf | cut -d ":" -f1 ) + 1 ))
sed -i "$insert_at i ILoveCandy" /etc/pacman.conf #ILoveCandy
sed -i '/#Color/s/^#//g' /etc/pacman.conf #Color

#multilib
insert_at=$(( $( grep -n "#\[multilib\]" /etc/pacman.conf | cut -d ":" -f1 ) + 1 ))
sed -i '/#\[multilib\]/s/^#//g' /etc/pacman.conf #1st
sed -i "$insert_at s/^#//g" /etc/pacman.conf #2nd
pacman -Sy #to update multilib

#HOSTNAME
echo ${bold}SETTING UP HOSTNAME...${reg}
hostname="arch"
echo $hostname >> /etc/hostname
echo -e "127.0.1.1\t $hostname.localdomain $hostname" >> /etc/hosts

#LOCALE
echo ${bold}SETTING UP LOCALE...${reg}
ln -sF /usr/share/zoneinfo/Europe/Brussels /etc/localtime
hwclock --systohc
sed -i '/#en_US.UTF-8/s/^#//g' /etc/locale.gen
sed -i '/#fr_BE.UTF-8/s/^#//g' /etc/locale.gen
cat > /etc/locale.conf <<EOF
LANG=en_US.UTF-8
LC_ADDRESS=fr_BE.UTF-8
LC_IDENTIFICATION=fr_BE.UTF-8
LC_MEASUREMENT=fr_BE.UTF-8
LC_MONETARY=fr_BE.UTF-8
LC_NAME=fr_BE.UTF-8
LC_NUMERIC=fr_BE.UTF-8
LC_PAPER=fr_BE.UTF-8
LC_TELEPHONE=fr_BE.UTF-8
LC_TIME=fr_BE.UTF-8
EOF

locale-gen

#CONSOLE
echo ${bold}SETTING UP CONSOLE...${reg}
echo "FONT=eurlatgr" >> /etc/vconsole.conf
echo "KEYMAP=be-latin1" >> /etc/vconsole.conf
echo "XKBLAYOUT=be" >> /etc/vconsole.conf

#EDITOR
echo ${bold}SETTING UP EDITOR...${reg}
echo "EDITOR=vim" >> /etc/environment
echo "VISUAL=vim" >> /etc/environment

#USER
echo ${bold}CREATING USER...${reg}
echo -n "New user name: "
read user
useradd -m -g users -G wheel -s /bin/bash $user
passwd $user
echo "$user ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/$user

#PASSWORD ROOT
echo ${bold}CHANGING ROOT PASSWORD...${reg}
passwd root

#SCRIPTS
echo ${bold}MOVING SCRIPTS...${reg}
cp -r /root/scripts /home/blondi/

#SYS INFO
echo ${bold}COLLECTING INFO...${reg}
system_info=$( source /home/blondi/scripts/system_info.sh )
cpu=$( echo -e "$system_info" | grep CPU | cut -d "=" -f2 )
gpu=$( echo -e "$system_info" | grep GPU | cut -d "=" -f2 )
de=$( echo -e "$system_info" | grep DE | cut -d "=" -f2 )

#PACKAGES
echo ${bold}INSTALLING PACKAGES...${reg}
packages="man-db man-pages efibootmgr networkmanager network-manager-applet zram-generator acpid polkit reflector sudo openssh htop fastfetch bash-completion ttf-meslo-nerd firefox gnome pipewire-jack lib32-pipewire-jack code keepassxc evolution solaar lm_sensors steam"
[[ $gpu == "nvidia" ]] && packages+=" nvidia-dkms nvidia-utils lib32-nvidia-utils egl-wayland"
pacman -S --needed $packages --noconfirm

#SERVICES
echo ${bold}ENABLING SERVICES...${reg}
systemctl enable NetworkManager #network
systemctl enable reflector.timer
systemctl enable fstrim.timer #optimization ssd
systemctl enable acpid
systemctl enable gdm #gnome_desktop_manager
[[ ! -z $( ls /sys/class | grep bluetooth ) ]] && systemctl enable bluetooth
#systemctl enable sshd
#=> for wireless, use nmtui

#INIT RAM DISK
#=> todo: check for hyperland only: if nvidia, add also after btrfs nvidia nvidia_modeset nvidia_uvm nvidia_drm ???
echo ${bold}INIT RAM DISK...${reg}
sed -i "/^MODULES=/ s/([^)]*)/(btrfs)/g" /etc/mkinitcpio.conf
sed -i "/^BINARIES=/ s/([^)]*)/(\/usr\/bin\/btrfs)/g" /etc/mkinitcpio.conf
sed -i "/^HOOKS=/ s/filesystems/encrypt lvm2 filesystems/g" /etc/mkinitcpio.conf
mkinitcpio -p linux

#SYSTEMD BOOT
echo ${bold}SETTING UP SYSTEMD BOOT...${reg}
bootctl --esp-path=/boot install
cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 5
console-mode max
editor yes
EOF

cat > /boot/loader/entries/arch.conf <<EOF
title Arch Linux (linux)
linux /vmlinuz-linux
initrd /initramfs-linux.img
initrd /intel-ucode.img
options cryptdevice=LABEL=Archlinux:root root=/dev/mapper/root rootflags=subvol=@ rw rootfstype=btrfs
EOF

cp /boot/loader/entries/arch.conf /boot/loader/entries/arch-fallback.conf
sed -i "s/(linux)/(linux-fallback)/g" /boot/loader/entries/arch-fallback.conf
sed -i "s/linux.img/linux-fallback.img/g" /boot/loader/entries/arch-fallback.conf

bootctl list
mkdir /home/blondi/scripts

#update hook
sudo mkdir /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/95-systemd-boot.hook <<EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot...
When = PostTransaction
Exec = /usr/bin/systemctl restart systemd-boot-update.service
EOF

echo ${bold}RENAMING EFI...${reg}
#rename EFI entry
archboot=$( efibootmgr | grep Archlinux | cut -d " " -f1 | grep -o -E "[0-9]+" )
bootpath=$( blkid | grep Archboot | cut -d ":" -f1 )
efibootmgr -b $archboot -B #delete current entry
efibootmgr -c -d $([[ $bootpath =~ "nvme" ]] && echo ${bootpath::-2} || echo ${bootpath::-1}) -p ${bootpath:$(( ${#bootpath} - 1 ))} -L "Archlinux" -l "\EFI\BOOT\BOOTX64.EFI" --index 0

#ZRAM
echo ${bold}SETTING UP ZRAM...${reg}
cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF
systemctl enable systemd-zram-setup@zram0.service

#SWITCH USER
echo ${bold}SWITCHING TO USER...${reg}
chown -R blondi:wheel /home/blondi/scripts/
sudo -S -u blondi -i /bin/bash -c 'source /home/blondi/scripts/archuser.sh'
