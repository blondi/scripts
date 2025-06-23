#!/usr/bin/env bash

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
dependencies="dconf dconf-editor git gh make typescript gettext just libgtop2-devel glib2-devel lm_sensors sass"
terminal="zsh"
apps="keepassxc codium evolution solaar"
fonts="droidsansmono-nerd-fonts"
games="steam lutris discord"
themes="tela-icon-theme"

install()
{
    collect_system_info
	install_dependencies
    source ~/scripts/monitors.sh
    [[ $chassis == "desktop" ]] && source ~/scripts/mount_game_drive.sh
    source ~/scripts/git.sh
    source ~/scripts/nas.sh
    install_packages
    [[ $chassis == "laptop" ]] && source ~/scripts/tuxedo.sh
    update_firmware
    [[ $de == "gnome" ]] && source ~/scripts/gnome-config.sh -i
    reboot_machine
}

configure()
{
    collect_system_info
    install_graphic_driver
    hardware_acceleration
    update_mulimedia_codec
    optimizations
    get_wallpaper
    [[ $de == "gnome" ]] && source ~/scripts/gnome.sh -c
    reboot_machine
}
main_menu()
{
    if [ $FEDORA_POST_INSTALL -eq 0 ]
    then
        install
    elif [ $FEDORA_POST_INSTALL -eq 1 ]
    then
        configure
    elif [ $FEDORA_POST_INSTALL -eq 2 ]
    then
        echo "The script is finished, nothing else to do..."
        exit 1
    else
        echo "SCRIPT SEQUENCE NOT KNOWN... exiting !"
        exit 1
    fi
}

collect_system_info()
{
    echo "FAS> Collecting system info..."
    system_info=$( source ~/scripts/system_info.sh)
    cpu=$( echo -e $system_info | grep CPU)
    gpu=$( echo -e $system_info | grep GPU)
    de=$( echo -e $system_info | grep DE)
}

install_dependencies()
{
    echo "FAS> Installing dependencies..."
    sudo dnf update -y
    sudo dnf install -y $dependencies
}

install_packages()
{
    # remove pyCharm repo
    echo "FAS> Removing PyCharm repo..."
    sudo rm /etc/yum.repos.d/_copr\:copr.fedorainfracloud.org\:phracek\:PyCharm.repo
    # rpm fusions
    echo "FAS> Installing rpm fusions repo..."
    sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    # upgrade
    echo "FAS> Updating system and installing packages..."
    sudo dnf check-update -y
    sudo dnf group upgrade -y core
    sudo dnf update -y
    sudo dnf install -y $terminal $apps $games $fonts $themes
    # flatpak
    echo "FAS> Installing flatpak..."
    sudo dnf install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
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