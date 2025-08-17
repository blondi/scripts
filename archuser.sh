#!/usr/bin/env bash

bold=$( tput bold )
reg=$( tput sgr0 )

#YAY
echo ${bold}INSTALLING YAY...${reg}
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git ~/yay
cd ~/yay
makepkg -si
cd
rm -rf ~/yay

#AUTO CPU FREQ
echo ${bold}INSTALLING AUTO CPUFREQ...${reg}
yay -S auto-cpufreq --noconfirm
sudo systemctl enable auto-cpufreq.service

#SNAPPER
echo ${bold}INSTALLING SNAPPER...${reg}
yay -S snapper btrfs-assistant --noconfirm

sudo snapper -c root create-config /
sudo snapper -c root create --description "first snapshot"

#RIDER
echo ${bold}INSTALLING RIDER...${reg}
yay -S rider --noconfirm

#CUSTOM SCRIPTS
echo ${bold}LAUNCHING CUSTOM SCRIPTS...${reg}
source ~/scripts/monitors.sh
[[ $( hostnamectl | grep Chassis ) =~ "desktop" ]] && source ~/scripts/mount_game_drive.sh
source ~/scripts/gnome.sh -i
source ~/scripts/git.sh
source ~/scripts/nas.sh
