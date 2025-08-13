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
    download_scripts
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

download_scripts()
{
    pacman -Sy git --needed --noconfirm
    git clone https://github.com/blondi/scripts /root/scripts
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
    archroot_part
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

archroot_part()
{
    #step into the system
    cp -r /root/scripts /mnt/root/scripts
    rm -rf /root/scripts
    arch-chroot /mnt /bin/bash "./root/scripts/archroot.sh"
    rm -rf 
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
