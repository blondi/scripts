#!/usr/bin/env bash

nas_ip_address=
nas_username=
nas_password=
nas_folders=("home" "share")
nas_credentials_location="/etc/.nas-cred"

declare -A naslocations

read -p "NAS> Enter ip address: " nas_ip_address
read -p "NAS> Enter username: " nas_username
read -p "NAS> Enter password: " -s nas_password
echo
echo "NAS> $nas_username will be connected to the NAS!"

echo "NAS> Configuring NAS..."
for i in ${nas_folders[@]}
do
    naslocations[$i]="/mnt/nas/$i"
done

nascred="username="$nas_username"\npassword="$nas_password"\ndomain=WORKGROUP"
nas_username=
nas_password=

echo -e "$nascred" | sudo dd of=$nas_credentials_location status=none

fstab=
for i in ${!naslocations[@]}
do
    sudo mkdir -p ${naslocations[$i]}
    fstab+="//$nas_ip_address/$i  ${naslocations[$i]}  cifs    credentials=$nas_credentials_location,uid=1000,gid=1000    0 0\n"
    echo "NAS> Access to \"$i\" (${naslocations[$i]}) has been created."
done

echo -e "$fstab" | sudo dd of=/etc/fstab oflag=append conv=notrunc status=none

sudo systemctl daemon-reload
sudo mount -a
echo