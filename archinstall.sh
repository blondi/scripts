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
    [[ $chassis == "laptop" ]] && wifi_connect
    change_root_password
}

set_keyboard_layout()
{
    #localectl list-keymaps | grep be
    loadkeys be-latin1
}

wifi_connect()
{
    #WIFI
    #iwctl (through iwd.service)
    #[iwd] device list
    #[iwd] device [name|adatper] set-property Prowered on
    wifipass=
    ssid=
    iwctl station $net_interface scan
    iwctl station $net_interface get-networks
    echo -n "Enter SSID: " 
    read ssid
    echo -n "Enter WiFi passphrase: "
    read -s wifipass
    echo #escape for secret
    iwctl station $net_interface connect $ssid --passphrase $wifipass
    wifipass=
    ssid=
    ping -c3 www.archlinux.org
}

prepare_ssh()
{
    ipaddress=$( ip a l $net_interface | awk '/inet / {print $2}' | cut -d '/' -f1 )
    echo -e "Connect with ssh using : ssh root@$ipaddress"
}

#------------------------------------------------------------------------------------

continue_install()
{
    
    format_disks
    set_timezone
    mirrors_list
    install_main_packages
    generate_file_system_table
    archroot
    configure_pacman
    set_hostname
    set_locale
    set_console
    set_editor
    create_user
    change_root_password
    download_scripts
    collect_system_info
    install_packages
    enable_services
    initial_ram_disk_env
    systemdboot
    configure_zram
    switch_to_user
    install_yay
    auto_cpu_freq
    install_snapper
    install_rider
    custom_scripts
    #ending
}

format_disks()
{
    lsblk -f #identify disk to use
    echo -n "Enter disk name to use (not the partition): "
    read disk
    disk="/dev/$disk"

    #wiping all on disk
    wipefs -af $disk
    sgdisk --zap-all --clear $disk
    partprobe $disk

    #Overwrite existing data with zeros
    dd if=/dev/zero of=$disk oflag=direct bs=1M status=progress

    #use 512MiB if grub for ef00
    sgdisk -n 1:0:+1GiB -t 1:ef00 -c 1:ESP -n 2:0:0 -t 2:8309 -c 2:LUKS $disk
    partprobe $disk
    sgdisk -p $disk

    #adding a 'p' to nvme disk for partition reference
    [[ $disk =~ "nvme" ]] && disk="${disk}p"

    # formatting partitions
    #[EFI]
    mkfs.vfat -F 32 -n ARCH_BOOT ${disk}1

    #[LUKS BTRFS]
    cryptsetup -v -y --type luks2 luksFormat ${disk}2 --label ARCH_CONT
    cryptsetup open ${disk}2 root

    mkfs.btrfs -L ARCH_ROOT /dev/mapper/root
    mount /dev/mapper/root /mnt
    cd /mnt
    btrfs subvolume create @
    btrfs subvolume create @home
    btrfs subvolume create @.snapshots
    btrfs subvolume create @pkg
    btrfs subvolume create @log
    cd
    umount /mnt

    mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/mapper/root /mnt
    mkdir -p /mnt/{home,boot,.snapshots,var/cache/pacman/pkg,var/log}
    mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/mapper/root /mnt/home
    mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@.snapshots /dev/mapper/root /mnt/.snapshots
    mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@pkg /dev/mapper/root /mnt/var/cache/pacman/pkg
    mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@log /dev/mapper/root /mnt/var/log
    mount -o uid=0,gid=0,fmask=0077,dmask=0077 ${disk}1 /mnt/boot
}

set_timezone()
{
    #timedatectl list-timezones | grep Brussel
    timedatectl set-timezone Europe/Brussels
    timedatectl set-ntp true
    timedatectl status
}

mirrors_list()
{
    reflector --save /etc/pacman.d/mirrorlist --country Belgium,Germany --protocol https --latest 5 --sort rate --download-timeout 60
}

install_main_packages()
{
    #todo : include microcode for amd as well based on CPU detection
    pacstrap /mnt base base-devel linux linux-headers linux-firmware btrfs-progs cryptsetup lvm2 intel-ucode git vim
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

configure_pacman()
{
    insert_at=$(( $( grep -n "#Color" /etc/pacman.conf | cut -d ":" -f1 ) + 1 ))
    sed -i "$insert_at i ILoveCandy" /etc/pacman.conf #ILoveCandy
    sed -i '/#Color/s/^#//g' /etc/pacman.conf #Color

    #multilib
    insert_at=$(( $( grep -n "#\[multilib\]" /etc/pacman.conf | cut -d ":" -f1 ) + 1 ))
    sed -i '/#\[multilib\]/s/^#//g' /etc/pacman.conf #1st
    sed -i "$insert_at s/^#//g" /etc/pacman.conf #2nd
    pacman -Sy #to update multilib
}

set_hostname()
{
    hostname="arch"
    echo $hostname >> /etc/hostname
    echo -e "127.0.1.1\t $hostname.localdomain $hostname" >> /etc/hosts
}

set_locale()
{
    ln -sF /usr/share/zoneinfo/Europe/Brussels /etc/localtime
    hwclock --systohc
    sed -i '/#en_US.UTF-8/s/^#//g' /etc/locale.gen
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf
    locale-gen
}

set_console()
{
    echo "FONT=eurlatgr" >> /etc/vconsole.conf
    echo "KEYMAP=be-latin1" >> /etc/vconsole.conf
    echo "XKBLAYOUT=be" >> /etc/vconsole.conf
}

set_editor()
{
    echo "EDITOR=vim" >> /etc/environment
    echo "VISUAL=vim" >> /etc/environment
}

create_user()
{
    echo -n "New user name: "
    read user
    useradd -m -g users -G wheel -s /bin/bash $user
    passwd $user
    echo "$user ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/$user
}

change_root_password()
{
    passwd root
}

download_scripts()
{
    mkdir /home/blondi/scripts
    pacman -S git --needed --noconfirm
    git clone https://github.com/blondi/scripts /home/blondi/scripts
}

collect_system_info()
{
    echo "FAS> Collecting system info..."
    system_info=$( source /home/blondi/scripts/system_info.sh )
    cpu=$( echo -e "$system_info" | grep CPU | cut -d "=" -f2 )
    gpu=$( echo -e "$system_info" | grep GPU | cut -d "=" -f2 )
    de=$( echo -e "$system_info" | grep DE | cut -d "=" -f2 )
}

install_packages()
{
    packages="man-db man-pages efibootmgr networkmanager zram-generator acpid polkit reflector sudo openssh htop fastfetch bash-completion ttf-meslo-nerd firefox gnome github-cli code keepassxc evolution solaar lm_sensors steam"
    [[ $gpu == "nvidia" ]] && packages+=" nvidia-dkms nvidia-utils lib32-nvidia-utils egl-wayland"
    pacman -S --needed $packages --noconfirm
}

enable_services()
{
    systemctl enable NetworkManager #network
    systemctl enable reflector.timer
    systemctl enable fstrim.timer #optimization ssd
    systemctl enable acpid
    systemctl enable gdm #gnome_desktop_manager
    [[ ! -z $( ls /sys/class | grep bluetooth ) ]] && systemctl enable bluetooth
    #systemctl enable sshd
    #=> for wireless, use nmtui
}

initial_ram_disk_env()
{
    #=> todo: check for hyperland only: if nvidia, add also after btrfs nvidia nvidia_modeset nvidia_uvm nvidia_drm ???
    sed -i "/^MODULES=/ s/([^)]*)/(btrfs)/g" /etc/mkinitcpio.conf
    sed -i "/^BINARIES=/ s/([^)]*)/(\/usr\/bin\/btrfs)/g" /etc/mkinitcpio.conf
    sed -i "/^HOOKS=/ s/filesystems/encrypt lvm2 filesystems/g" /etc/mkinitcpio.conf
    mkinitcpio -p linux
}

systemdboot()
{
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
options cryptdevice=LABEL=ARCH_CONT:root root=/dev/mapper/root rootflags=subvol=@ rw rootfstype=btrfs
EOF

    cp /boot/loader/entries/arch.conf /boot/loader/entries/arch-fallback.conf
    sed -i "s/(linux)/(linux-fallback)/g" /boot/loader/entries/arch-fallback.conf
    sed -i "s/linux.img/linux-fallback.img/g" /boot/loader/entries/arch-fallback.conf

    bootctl list

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

    #rename EFI entry
    archboot=$( efibootmgr | grep Archlinux | cut -d " " -f1 | grep -o -E "[0-9]+" )
    bootpath=$( blkid | grep ARCH_BOOT | cut -d ":" -f1 )
    efibootmgr -b $archboot -B #delete current entry
    efibootmgr -c -d $([[ $bootpath =~ "nvme" ]] && echo ${bootpath::-2} || echo ${bootpath::-1}) -p ${bootpath:$(( ${#bootpath} - 1 ))} -L "Archlinux" -l "\EFI\BOOT\BOOTX64.EFI" --index 0
}

configure_zram()
{
    cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF
    systemctl enable systemd-zram-setup@zram0.service
}

switch_to_user()
{
    su blondi
}

install_yay()
{
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay.git ~/yay
    cd ~/yay
    makepkg -si
    cd
    rm -rf ~/yay
}

auto_cpu_freq()
{
    yay -S auto-cpufreq --noconfirm
    sudo systemctl enable auto-cpufreq.service
}

install_snapper()
{
    yay -S snapper btrfs-assistant --noconfirm
}

install_rider()
{
    yay -S rider --noconfirm
}

custom_scripts()
{
    source ~/scripts/git.sh
    source ~/scripts/monitors.sh
    source ~/scripts/nas.sh
    [[ $( hostnamectl | grep Chassis ) =~ "desktop" ]] && source ~/scripts/mount_game_drive.sh
}

ending()
{
    exit
    umount -R /mnt
    reboot
}

#------------------------------------------------------------------------------------------------

#################
# CONFIGURATION #
#################

configure()
{
    post_install_checks

    #TODO
    #check DE is gnome => execute gnome script install part
}

post_install_checks()
{
    systemctl --failed
    journalctl -p 3 -xb
}

configure_snapper()
{
    sudo snapper -c root create-config /
    sudo snapper -c root create --description "first snapshot"
}

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
