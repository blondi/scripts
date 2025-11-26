#!/usr/bin/env bash

bold=$( tput bold )
reg=$( tput sgr0 )

#YAY
notify_user "INSTALLING YAY..."
sudo pacman -S --needed git base-devel --noconfirm
git clone https://aur.archlinux.org/yay.git ~/yay
cd ~/yay
makepkg -si --noconfirm
cd
rm -rf ~/yay

#Installing YAY packages
notify_user "INSTALLING YAY PACKAGES..."
yay -S snapper btrfs-assistant auto-cpufreq --noconfirm

notify_user "ENABLING AUTO CPUFREQ..."
sudo systemctl enable auto-cpufreq.service

notify_user "INITIATING SNAPPER..."
sudo snapper -c root create-config /
sudo snapper -c root create --description "Initialization"

#CUSTOM SCRIPTS
notify_user "LAUNCHING CUSTOM SCRIPTS..."
notify_user "SETTING MONITOR RESOLUTION..."
source ~/scripts/monitors.sh

notify_user "ADDING GAME DRIVE..."
[[ $( hostnamectl | grep Chassis ) =~ "desktop" ]] && source ~/scripts/mount_game_drive.sh

notify_user "CONFIGURING GIT..."
source ~/scripts/git.sh

notify_user "CONFIGURING NAS..."
source ~/scripts/nas.sh

notify_user()
{
    echo ${bold}$1${reg}
}