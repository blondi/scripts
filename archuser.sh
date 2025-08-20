#!/usr/bin/env bash

bold=$( tput bold )
reg=$( tput sgr0 )

#YAY
echo ${bold}INSTALLING YAY...${reg}
sudo pacman -S --needed git base-devel --noconfirm
git clone https://aur.archlinux.org/yay.git ~/yay
cd ~/yay
makepkg -si --noconfirm
cd
rm -rf ~/yay

#Installing YAY packages
echo ${bold}INSTALLING YAY PACKAGES...${reg}
yay -S snapper btrfs-assistant auto-cpufreq rider --noconfirm

echo ${bold}ENABLING AUTO CPUFREQ...${reg}
sudo systemctl enable auto-cpufreq.service

echo ${bold}INITIATING SNAPPER...${reg}
sudo snapper -c root create-config /
sudo snapper -c root create --description "first snapshot"

#CUSTOM SCRIPTS
echo ${bold}LAUNCHING CUSTOM SCRIPTS...${reg}
source ~/scripts/monitors.sh
[[ $( hostnamectl | grep Chassis ) =~ "desktop" ]] && source ~/scripts/mount_game_drive.sh
source ~/scripts/git.sh
source ~/scripts/nas.sh
source ~/scripts/gnome.sh -i