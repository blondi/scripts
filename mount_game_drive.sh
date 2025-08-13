#!/usr/bin/env bash

echo "MGD> Mounting games drive..."
sudo mkdir /mnt/games
fstab="LABEL=Games /mnt/games ext4 nosuid,nodev,nofail,x-gvfs-show,x-gvfs-name=Games 0 0\n"
echo -e "$fstab" | sudo dd of=/etc/fstab oflag=append conv=notrunc status=none
echo