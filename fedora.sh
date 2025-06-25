#!/usr/bin/env bash

# TODO: add nerd font

# Automatization script for fedora post install sequences.
# Use "-i" to install packages and extensions.
# Use "-c" to configure fedora after the install part of this script.

# computer type
chassis=$( hostnamectl chassis )

# system detecion
system_info=
cpu=
gpu=
de=

# packages
nvidia_drivers="akmod-nvidia"
dependencies="dconf dconf-editor git gh make typescript gettext just libgtop2-devel glib2-devel lm_sensors sass meson"
terminal="zsh"
apps="keepassxc code evolution solaar"
games="steam lutris discord"

install()
{
    collect_system_info
    configure_repos
    install_dependencies
    update_firmware
    source ~/scripts/monitors.sh
    [[ $chassis == "desktop" ]] && source ~/scripts/mount_game_drive.sh
    source ~/scripts/git.sh
    source ~/scripts/nas.sh
    install_packages
    [[ $de == "gnome" ]] && source ~/scripts/gnome.sh -i
    reboot_machine
}

configure()
{
    collect_system_info
    install_graphic_driver
    hardware_acceleration
    update_mulimedia_codec
    optimizations
    [[ $chassis == "laptop" ]] && source ~/scripts/tuxedo.sh
    get_wallpaper
    get_icons
    get_font
    [[ $de == "gnome" ]] && source ~/scripts/gnome.sh -c
    reboot_machine
}

collect_system_info()
{
    echo "FAS> Collecting system info..."
    system_info=$( source ~/scripts/system_info.sh)
    cpu=$( echo -e "$system_info" | grep CPU | cut -d "=" -f2 )
    gpu=$( echo -e "$system_info" | grep GPU | cut -d "=" -f2 )
    de=$( echo -e "$system_info" | grep DE | cut -d "=" -f2 )
}

configure_repos()
{
    # remove pyCharm repo
    echo "FAS> Removing PyCharm repo..."
    sudo rm /etc/yum.repos.d/_copr\:copr.fedorainfracloud.org\:phracek\:PyCharm.repo
    # rpm fusions
    echo "FAS> Installing rpm fusions repo..."
    sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    # vs code
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
    # upgrade
    echo "FAS> Updating system..."
    sudo dnf check-update -y
    sudo dnf group upgrade -y core
    # flatpack
    # flatpak
    echo "FAS> Installing flatpak repo..."
    sudo dnf install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

install_dependencies()
{
    echo "FAS> Installing dependencies..."
    sudo dnf update -y
    sudo dnf install -y $dependencies
}

install_packages()
{
    sudo dnf install -y $terminal $apps $games
    flatpak install -y flathub com.spotify.Client
}

update_firmware()
{
    echo "FAS> Updating devices firmware..."
    sudo fwupdmgr refresh --force
    sudo fwupdmgr get-devices
    sudo fwupdmgr get-updates
    sudo fwupdmgr update
}

reboot_machine()
{
    if [[ $1 == "-c" && $gpu == "nvidia" ]]
	then
        echo "FAS> Waiting for kernel module to be build with nvidia (~10-15min)..."
        while [ -z $( modinfo -F version nvidia 2> /dev/null ) ]
        do
            sleep 5s
        done
        drmenabled=$( sudo cat /sys/module/nvidia_drm/parameters/modeset )
        if [ $drmenabled == "N" ] ; then sudo grubby --update-kernel=ALL --args="nvidia-drm.modeset=1" ; fi
    fi
    sudo systemctl reboot
}

install_graphic_driver()
{
    echo "FAS> Installing graphic driver..."
    if [ $gpu == "nvidia" ] ; then sudo dnf install -y $nvidia_drivers ; fi
}

hardware_acceleration()
{
    echo "FAS> Configuring hardware acceleration..."
    sudo dnf install -y ffmpeg-libs libva libva-utils
    case $cpu in
        "intel")
            sudo dnf swap -y libva-intel-media-driver intel-media-driver --allowerasing
            ;;
        "amd")
            sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
            sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
            sudo dnf swap -y mesa-va-drivers.i686 mesa-va-drivers-freeworld.i686
            sudo dnf swap -y mesa-vdpau-drivers.i686 mesa-vdpau-drivers-freeworld.i686
            ;;
        *)
            ;;
    esac
}

update_mulimedia_codec()
{
    echo "FAS> Updating multimedia codecs..."
    sudo dnf group upgrade -y multimedia 
    sudo dnf swap -y 'ffmpeg-free' 'ffmpeg' --allowerasing
    sudo dnf upgrade -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
    sudo dnf group install -y sound-and-video
}

optimizations()
{
    echo "FAS> Launching miscellaneous optimizations..."
    sudo rm -f /usr/lib64/firefox/browser/defaults/preferences/firefox-redhat-default-prefs.js
    sudo hostnamectl set-hostname "fedora"
}

get_wallpaper()
{
    echo "FAS> Downloading wallpaper..."
    sudo curl -sL -o /usr/share/backgrounds/astronaut.png https://raw.githubusercontent.com/orangci/walls/main/astronaut.png
}

get_icons()
{
    echo "FAS> Installing icons pack..."
    cd ~
    git clone https://github.com/vinceliuice/Tela-icon-theme.git
    cd ./Tela-icon-theme
    ./install.sh grey
    cd ..
    rm -rf ./Tela-icon-theme
}

get_font()
{
    cd ~
    mkdir -p ~/.local/share/fonts/meslo
    sudo curl -sL -o font.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip
    unzip font.zip -d ~/.local/share/fonts/meslo/
    rm font.zip
    fc-cache -v
}

clear
echo "############################"
echo "# FEDORA automation script #"
echo "############################"
if ! [[ "$1" =~ ^(-i|-c)$ ]]
then
    echo "Mode not detected!"
    echo "Use "-i" to install, "-c" to configure after the install part."
    exit 2
elif [[ $1 == "-i" ]]
then
    install
elif [[ $1 == "-c" ]]
then
    configure
fi
