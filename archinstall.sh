#!/usr/bin/env bash

# Automatization script for arch linux install sequences.
# Use "-i" to install packages and extensions.
# Use "-c" to configure arch linux after the install part of this script.

# computer type
chassis=$( hostnamectl chassis )
net_interface=$( ls /sys/class/net | grep -v "lo" )
bold=$( tput bold )
reg=$( tput sgr0 )

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
    #KEYBOARD
    #localectl list-keymaps | grep be
    notify_user "SETTING UP KEYBOARS..."
    loadkeys be-latin1

    if [[ $chassis == "laptop" ]]
    then
        #WIFI
        notify_user "SETTING UP WIFI..."
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
    fi

    #PASSWORD ROOT
    notify_user "CHANGING ROOT PASSWORD..."
    passwd root

    #GET SCRIPTS
    notify_user "GETTING SCRIPTS..."
    pacman -Sy git --needed --noconfirm
    git clone https://github.com/blondi/scripts /root/scripts

    #SSH
    notify_user "SSH CONFIG..."
    ipaddress=$( ip a l $net_interface | awk '/inet / {print $2}' | cut -d '/' -f1 )
    echo -e "Connect with ssh using : ssh root@$ipaddress"
}

#------------------------------------------------------------------------------------

install()
{
    notify_user "DRIVE CONFIGURATION..."
    lsblk -f #identify disk to use
    echo -n "Enter disk name to use (not the partition): "
    read disk
    disk="/dev/$disk"

    notify_user "WIPING DRIVE $disk..."
    #wiping all on disk
    wipefs -af $disk
    sgdisk --zap-all --clear $disk
    partprobe $disk
    #Overwrite existing data with zeros
    dd if=/dev/zero of=$disk oflag=direct bs=1M status=progress

    notify_user "PARTITIONING DRIVE..."
    #use 512MiB if grub for ef00
    sgdisk -n 1:0:+1GiB -t 1:ef00 -c 1:ESP -n 2:0:0 -t 2:8309 -c 2:LUKS $disk
    partprobe $disk
    sgdisk -p $disk

    #adding a 'p' to nvme disk for partition reference
    [[ $disk =~ "nvme" ]] && disk="${disk}p"

    # formatting partitions
    #[EFI]
    mkfs.vfat -F 32 -n Archboot ${disk}1

    #[LUKS BTRFS]
    notify_user "SETTING UP ENCRYPTION..."
    cryptsetup -v -y --type luks2 luksFormat ${disk}2 --label Archlinux
    notify_user "OPENING ENCRYPTED DRIVE..."
    cryptsetup open ${disk}2 root

    mkfs.btrfs -L Archroot /dev/mapper/root

    #[BTRFS SUB VOLUMES]
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

    #TIMEZONE
    #timedatectl list-timezones | grep Brussel
    notify_user "SETTING UP TIMEZONE..."
    timedatectl set-timezone Europe/Brussels
    timedatectl set-ntp true
    timedatectl status

    #MIRRORS
    notify_user "SETTING UP PACMAN MIRRORS..."
    reflector --save /etc/pacman.d/mirrorlist --country Belgium,Germany --protocol https --latest 5 --sort rate --download-timeout 60

    #PACKAGES
    #todo : include microcode for amd as well based on CPU detection
    notify_user "INSTALLING BASE PACKAGES..."
    pacstrap /mnt base base-devel linux linux-headers linux-firmware btrfs-progs cryptsetup lvm2 intel-ucode git vim

    #FILE SYSTEM TABLE
    notify_user "GENERATING FILE SYSTEM TABLE..."
    genfstab -U -p /mnt >> /mnt/etc/fstab

    #step into the system
    cp -r /root/scripts /mnt/root/scripts
    notify_user "ARCH-CHROOTING..."
    arch-chroot /mnt /bin/bash "./root/scripts/archroot.sh"

    notify_user "ENDING SCRIPT..."
    rm -rf /root/scripts
    rm -rf /mnt/root/scripts
    umount -R /mnt
    echo Your computer will now reboot...
    read
}

post_install()
{
    #CHECKS
    systemctl --failed
    journalctl -p 3 -xb
    read

    #GNOME install
    notify_user "CONFIGURING GNOME ECOSYSTEM..."
    source ~/scripts/gnome.sh -c
}

notify_user()
{
    echo ${bold}$1${reg}
}

#------------------------------------------------------------------------

clear
echo "###############################"
echo "# ARCHLINUX automation script #"
echo "###############################"
if ! [[ "$1" =~ ^(-i|-r|-c)$ ]]
then
    echo "Mode not detected!"
    echo "Use "-i" to install, "-r" for gnome specific install and "-c" to configure after the install parts."
    exit 2
elif [[ $1 == "-i" ]]
then
    if [[ ! -z $2 && $2 == '-ssh' ]]
    then
        [[ -d  /root/scripts ]] && install || init_install
        exit 1
    fi
    init_install
    install
elif [[ $1 == "-c" ]]
then
    post_install
fi
