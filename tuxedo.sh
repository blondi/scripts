#!/usr/bin/env bash

# Compatible with Arch and Fedora only.

echo "Installing tuxedo repo..."
case $( cat /etc/os-release | grep ^ID= | cut -d "=" -f2 ) in
    *"arch"*)
        yay -Syu
        yay -S tuxedo-control-center-bin tuxedo-drivers-dkms linux-headers
        ;;
    *"fedora"*)
        fedora_version=$( rpm -E %fedora )
        tuxedo_repo=$( cat <<EOF
[tuxedo]
name=tuxedo
baseurl=https://rpm.tuxedocomputers.com/fedora/$fedora_version/x86_64/base
enabled=1
gpgcheck=1
gpgkey=https://rpm.tuxedocomputers.com/fedora/$fedora_version/0x54840598.pub.asc
skip_if_unavailable=False
EOF
        )
        sudo dnf update -y
        echo -e "$tuxedo_repo" | sudo dd of=/etc/yum.repos.d/tuxedo.repo status=none
        sudo rpm --import $( cat /etc/yum.repos.d/tuxedo.repo | grep asc | cut -d '=' -f2 )
        sudo dnf install -y tuxedo-control-center
        ;;
    *)
        echo "Unsupported distro !"
        return 2
        ;;
esac
echo