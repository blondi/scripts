#!/usr/bin/env bash

# Automatization script for arch linux install sequences.
# Use "-i" to install packages and extensions.
# Use "-c" to configure arch linux after the install part of this script.

# computer type
chassis=$( hostnamectl chassis )
net_interface=$( ls /sys/class/net | grep -v "lo" )

# system detecion
system_info=
cpu=
gpu=
de=

################
# INSTALLATION #
################

init_install()
{
    set_keyboard_layout
    set_font_size
    [[ $chassis == "laptop" ]] && wifi_connect
    change_root_password
    #download_scripts
    set_timezone
}

continue_install()
{
    format_disks
    mirrors_list
    install_packages
    generate_file_system_table
    archroot
    #collect_system_info
    #reboot_machine
}

set_keyboard_layout()
{
    #localectl list-keymaps | grep be
    loadkeys be-latin1
}

set_font_size()
{
    #location /sys/share/kbd/consolefonts/
    setfont ter-v24n
}

collect_system_info()
{
    echo "FAS> Collecting system info..."
    system_info=$( source ~/scripts/system_info.sh)
    cpu=$( echo -e "$system_info" | grep CPU | cut -d "=" -f2 )
    gpu=$( echo -e "$system_info" | grep GPU | cut -d "=" -f2 )
    de=$( echo -e "$system_info" | grep DE | cut -d "=" -f2 )
}

wifi_connect()
{
    #WIFI
    #iwctl (through iwd.service)
    #[iwd] device list
    #[iwd] device [name|adatper] set-property Prowered on
    #[iwd] station name scan
    #[iwd] station name get-networks
    #[iwd] station name [connect|connect-hidden] SSID
    wifipass=
    ssid=
    iwctl station $net_interface scan
    iwctl station $net_interface get-networks
    read -p "Enter SSID: " ssid
    read -p "Enter WiFi passphrase: " -s wifipass
    iwctl --passphrase $wifipass station $net_interface connect $ssid
    wifipass=
    ssid=
    ping -c3 www.archlinux.org
}

download_scripts()
{
    mkdir /root/scripts
    pacman -Sy git --needed --noconfirm
    git clone https://github.com/blondi/scripts /root/scripts
}

set_timezone()
{
    #timedatectl list-timezones | grep Brussel
    timedatectl set-timezone Europe/Brussels
    timedatectl set-ntp true
    timedatectl status
}

prepare_ssh()
{
    ipaddress=$( ip a l $net_interface | awk '/inet / {print $2}' | cut -d '/' -f1 )
    echo -e "Connect with ssh using : ssh root@$ipaddress"
}

format_disks()
{
    lsblk -f #identify disk to use
    echo -n "Enter disk name to use (/dev/[disk_name]): "
    read disk

    #wiping all on disk
    wipefs -af $disk
    sgdisk --zap-all --clear $disk
    partprobe $disk

    #Overwrite existing data with zeros
    dd if=/dev/zero of=/$disk oflag=direct bs=1M status=progress

    #use 512MiB if grub for ef00
    sgdisk -n 1:0:+1GiB -t 1:ef00 -c 1:ESP -n 2:0:0 -t 2:8309 -c 2:LUKS $disk
    partprobe $disk
    sgdisk -p $disk

    #adding a 'p' to nvme disk for partition reference
    [[ $disk =~ "nvme" ]] && disk="${disk}p"

    # formatting partitions
    #[EFI]
    mkfs.vfat -F32 ${disk}1

    #[LUKS BTRFS]
    cryptsetup --type luks2 -v -y luksFormat ${disk}2
    cryptsetup open ${disk}2 root

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
    mount ${disk}1 /mnt/boot
}

mirrors_list()
{
    reflector --save /etc/pacman.d/mirrorlist --country Belgium,Germany --protocol https --latest 5 --sort rate
}

install_packages()
{
    #todo : include microcode for amd as well based on CPU detection
    pacstrap /mnt base base-devel linux linux-headers linux-firmware btrfs-progs cryptsetup lvm2 intel-ucode git neovim
}

generate_file_system_table()
{
    genfstab -U -p /mnt >> /mnt/etc/fstab
}

archroot()
{
    #step into the system
    arch-chroot /mnt /bin/bash
}

#################
# CONFIGURATION #
#################

configure()
{
    configure_pacman
}

configure_pacman()
{
    insert_at=$(( $( grep -n "#Color" /etc/pacman.conf | cut -d ":" -f1 ) + 1 ))
    sed "$insert_at i ILoveCandy" /etc/pacman.conf #ILoveCandy
    sed -i '/#Color/s/^#//g' /etc/pacman.conf #Color

    #multilib
    insert_at=$(( $( grep -n "#\[multilib\]" /etc/pacman.conf | cut -d ":" -f1 ) + 1 ))
    sed -i '/#\[multilib\]/s/^#//g' /etc/pacman.conf #first_line
    sed "$insert_at s/^#//g" /etc/pacman.conf #second_line
}

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

blkid -s UUID -o value ${disk}2
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
#create /etc/pacman.d/hooks/95-systemd-boot.hook
#[Trigger]
#Type = Package
#Operation = Upgrade
#Target = systemd
#
#[Action]
#Description = Updating systemd-boot...
#When = PostTransaction
#Exec = /usr/bin/systemctl restart systemd-boot-update.service


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

clear
echo "###############################"
echo "# ARCHLINUX automation script #"
echo "###############################"
if ! [[ "$1" =~ ^(-i|-c)$ ]]
then
    echo "Mode not detected!"
    echo "Use "-i" to install, "-c" to configure after the install part."
    exit 2
elif [[ $1 == "-i" ]]
then
    if [ ! -z $2 ]
    then
        if [[ $2 == '-ssh' ]]
        then
            init_install
            prepare_ssh
            exit 1
        elif [[ $2 == '-r' ]]
        then
            continue_install
            exit 1
        fi
    fi
    init_install
    continue_install
elif [[ $1 == "-c" ]]
then
    configure
fi