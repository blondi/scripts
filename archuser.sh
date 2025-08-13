#!/usr/bin/env bash

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

install_yay
auto_cpu_freq
install_snapper
install_rider
custom_scripts
