#!/usr/bin/env bash

###############
# PREPARATION #
###############

#[CONSOLE]
#KEYBOARD LAYOUT
#localectl list-keymaps | grep be
loadkeys be-latin1

#FONT SIZE
#location /sys/share/kbd/consolefonts/
setfont ter-v24n

#[INTERNET CONNECTION]
#LAN
#ip link

#WIFI
#iwctl (through iwd.service)
#[iwd] device list
#[iwd] device [name|adatper] set-property Prowered on
#[iwd] station name scan
#[iwd] station name get-networks
#[iwd] station name [connect|connect-hidden] SSID
wifipass=
ssid=
read -p "Enter SSID: " ssid
read -p "Enter WiFi passphrase: " -s wifipass
iwctl --passphrase $wifipass station name connect $ssid
wifipass=
ssid=

ping -c www.archlinux.org

#[SSH]
systemctl start sshd
#root passwd
passwd

#[SYSTEM CLOCK]
timedatectl set-timezone Europe/Brussels
timedatectl set-ntp true
#timedatectl list-timezones | grep Brussel
timedatectl status

#[SHOW IP FOR SSH]
ip a #get ip and log in into the other computer

#-------------------------------------------------------

#################
# CONFIGURATION #
#################

#ssh root@ip_address

#[DISKS]
lsblk -f #identify disk to use
read -p "Enter disk name to use (/dev/[disk_name]): " disk

#wiping all on disk
wipefs -af $disk
sgdisk --zap-all --clear $disk
partprobe $disk

#Overwrite existing data with random values
dd if=/dev/zero of=/$disk oflag=direct bs=4096 status=progress

#use 512MiB if grub for ef00
sgdisk -n 1:0:+1GiB -t 1:ef00 -c 1:ESP -n 2:0:0 -t 2:8309 -c 2:LUKS $disk
partprobe $disk
sgdisk -p $disk

# formatting partitions
#[LUKS]
cryptsetup --type luks2 -v -y luksFormat ${disk}p2
cryptsetup open ${disk}p2 root
mkfs.vfat -F32 ${disk}p1 #(p1)
mkfs.btrfs /dev/mapper/root

mount /dev/mapper/root /mnt
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @.snapshots
btrfs subvolume create @pkg
btrfs subvolume create @log
cd
unmount /mnt

mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/mapper/root /mnt
mkdir -p /mnt/{home,boot,.snapshots,var/cache/pacman/pkg,var/log}
mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/mapper/root /mnt/home
mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@.snapshots /dev/mapper/root /mnt/.snapshots
mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@pkg /dev/mapper/root /mnt/var/cache/pacman/pkg
mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@log /dev/mapper/root /mnt/var/log
mount ${disk}p1 /mnt/boot

#[MIRROR LIST]
reflector -c Belgium --latest 5 --sort rate --save /etc/pacman.d/mirrorlist

#[PACKAGES]
pacstrap /mnt base base-devel linux linux-headers linux-firmware btrfs-progs cryptsetup lvm2 intel-ucode git neovim

#[FSTAB]
genfstab -U -p /mnt >> /mnt/etc/fstab

#[STEP INTO SYSTEM]
arch-chroot /mnt /bin/bash

#------------------------------------------------------------------------------------------------------------

######################
# POST-CONFIGURATION #
######################

#[PACMAN]
#/etc/pacman.conf
#ILoveCandy
#Color
#[multilib]

#[DEPENDENCIES]
pacman -S sudo networkmanager openssh iptables-nft ipset firewalld acpid polkit reflector man-db man-pages zram-generator bash-completion htop ttf-meslo-nerd  terminus-font firefox gnome gnome-tweaks gnome-shell-extensions
#NVIDIA, add: nvidia-dkms nvidia-utils lib32-nvidia-utils egl-wayland

#[HOSTNAME]
echo "arch" >> /etc/hostname
#/etc/hosts
#replace hostname with new hostname on localdomain
#127.0.0.1 localhost
#::1 localhost
#127.0.1.1 <hostname>.localdomain <hostname>

#[LOCALE]
ln -sF /usr/share/zoneinfo/Europe/Brussels /etc/localtime
hwclock --systohc
nvim /etc/locale.gen #=> uncomment en_US.UTF-8
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
locale-gen

#[KEYBOARD]
#/etc/vconsole.conf
echo "FONT=ter-v22n" >> /etc/vconsole.conf
echo "KEYMAP=be-latin1" >> /etc/vconsole.conf
echo "XKBLAYOUT=be" >> /etc/vconsole.conf

#[EDITOR]
echo "EDITOR=nvim" >> /etc/environment
echo "VISUAL=nvim" >> /etc/environment

#[ROOTUSER]
passwd

#[USER]
useradd -m -g users -G wheel -s /bin/bash blondi
passwd blondi
echo "blondi ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/blondi

#[SERVICES]
systemctl enable NetworkManager #network
#systemctl enable bluetooth
#systemctl enable sshd
#systemctl enable firewalld
#systemctl enable reflector.timer
systemctl enable fstrim.timer #optimization ssd
systemctl enable acpid
systemctl enable gdm
#=> for wireless, use nmtui

#[MKINITCPIO]
vim /etc/mkinitcpio.conf
MODULES=(btrfs)
#=> for hyperland only: if nvidia, add also after btrfs nvidia nvidia_modeset nvidia_uvm nvidia_drm ???
BINARIES=(/usr/bin/btrfs)
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)
#+ move keyboard before autodetect
mkinitcpio -p linux

#[SYSTEMD-BOOT]
bootctl --esp-path=/boot install
cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
console-mode max
editor yes
EOF

blkid -s UUID -o value ${disk}p2
touch /boot/loader/entries/arch.conf
#insert
#title Arch Linux (linux)
#linux /vmlinuz-linux
#initrd /initramfs-linux.img
#options cryptdevice=PARTUUID=[PARUUID]:root root=/dev/mapper/root rootflags=subvol=@ rw rootfstype=btrfs

cp /boot/loader/entries/arch.conf /boot/loader/entries/arch-fallback.conf
#insert
#title Arch Linux (linux-fallback)
#initrd /initramfs-linux-fallback.img

bootctl list

#[SYSTEMD-BOOT UPDATE]
sudo mkdir /etc/pacman.d/hooks
#create /etc/pacman.d/hooks/100-systemd-boot.hook
#[Trigger]
#Type = Package
#Operation = Upgrade
#Target = systemd
#
#[Action]
#Description = Updating systemd-boot
#When = PostTransaction
#Exec = /usr/bin/bootctl update


exit
umount -R /mnt

reboot
#------------------------------------------------------------------------------------------------


#[CHECKS AFTER INSTALL]
systemctl --failed
journalctl -p 3 -xb

#[ZRAM]
#create /etc/systemd/zram-generator.conf
#[zram0]
#zram-size = min(ram / 2, 8192)
#compression-algorithm = zstd
sudo systemctl daemon-reload
sudo systemctl enable systemd-zram-setup@zram0.service
sudo systemctl start systemd-zram-setup@zram0.service
zramctl
lsblk #should see zram there
#check with zramctl

#[YAY]
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

#[AUTO CPU FREQ]
yay -S auto-cpufreq
sudo systemctl enable --now auto-cpufreq.service

#[TIMESHIFT]
yay -S timeshift timeshift-autosnap
sudo timeshift --create --comments "[message]" --tags D

#[ENV for HYPRLAND config]
#env = LIBVA_DRIVER_NAME,nvidia
#env = __GLX_VENDOR_LIBRARY_NAME,nvidia
