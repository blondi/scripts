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
    set_timezone
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
    read "ssid?Enter SSID: "
    read -s "wifipass?Enter WiFi passphrase: "
    iwctl station $net_interface connect $ssid --passphrase $wifipass
    wifipass=
    ssid=
    ping -c3 www.archlinux.org
}

set_timezone()
{
    #timedatectl list-timezones | grep Brussel
    timedatectl set-timezone Europe/Brussels
    timedatectl set-ntp true
    timedatectl status
}

continue_install()
{
    format_disks
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
    ending
    #reboot_machine
}

prepare_ssh()
{
    ipaddress=$( ip a l $net_interface | awk '/inet / {print $2}' | cut -d '/' -f1 )
    echo -e "Connect with ssh using : ssh root@$ipaddress"
}

format_disks()
{
    lsblk -f #identify disk to use
    read "disk?Enter disk name to use (not the partition): "
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

mirrors_list()
{
    reflector --save /etc/pacman.d/mirrorlist --country Belgium,Germany --protocol https --latest 5 --sort rate --download-timeout 60
}

install_main_packages()
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
    echo "EDITOR=nvim" >> /etc/environment
    echo "VISUAL=nvim" >> /etc/environment
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
    mkdir /root/scripts
    pacman -S git --needed --noconfirm
    git clone https://github.com/blondi/scripts /root/scripts
}

collect_system_info()
{
    echo "FAS> Collecting system info..."
    system_info=$( source ~/scripts/system_info.sh )
    cpu=$( echo -e "$system_info" | grep CPU | cut -d "=" -f2 )
    gpu=$( echo -e "$system_info" | grep GPU | cut -d "=" -f2 )
    de=$( echo -e "$system_info" | grep DE | cut -d "=" -f2 )
}

install_packages()
{
    packages="sudo networkmanager openssh firewalld acpid polkit reflector man-db man-pages zram-generator bash-completion htop ttf-meslo-nerd firefox fastfetch gnome"
    [[ $gpu == "nvidia" ]] && packages+=" nvidia-dkms nvidia-utils lib32-nvidia-utils egl-wayland"
    pacman -S --needed $packages
}

enable_services()
{
    systemctl enable NetworkManager #network
    systemctl enable firewalld
    systemctl enable reflector.timer
    systemctl enable fstrim.timer #optimization ssd
    systemctl enable acpid
    systemctl enable gdm #gnome_desktop_manager
    #systemctl enable bluetooth
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
timeout 3
console-mode max
editor yes
EOF

    cat > /boot/loader/entries/arch.conf <<EOF
title Arch Linux (linux)
linux /vmlinuz-linux
initrd /initramfs-linux.img
initrd /intel-ucode.img
options cryptdevice=LABEL=ARCH_CONT root=LABEL=ARCH_CONT rootflags=subvol=@ rw rootfstype=btrfs
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

ending()
{
    exit
    umount -R /mnt
    reboot
}

#------------------------------------------------------------------------------------------------

#[ENV for HYPRLAND config]
#env = LIBVA_DRIVER_NAME,nvidia
#env = __GLX_VENDOR_LIBRARY_NAME,nvidia


#################
# CONFIGURATION #
#################

configure()
{
    post_install_checks
    install_yay
    auto_cpu_freq
    install_timeshift
}

post_install_checks()
{
    systemctl --failed
    journalctl -p 3 -xb
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
    sudo systemctl enable --now auto-cpufreq.service
}

install_timeshift()
{
    yay -S timeshift timeshift-autosnap
    sudo timeshift --create --comments "First backup" --tags D
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