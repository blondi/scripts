#!/usr/bin/env bash

# Compatible with Arch and Fedora only.
#
# Script's arguments
# -i => update the system and install script dependencies (phase 1).
# -c => after the installation, configure the settings (gnome + GDM + extensions) and activate the extensions (phase 2).

update_gdm_resolution()
{
    echo "GNOME> Updating GDM resolution..."
    if ! [ -f ~/.config/monitors.xml ]
    then
        echo "=> file ~/.config/monitors.xml not found!"
        return 1
    fi

    sudo cp -f ~/.config/monitors.xml ~gdm/.config/monitors.xml
    sudo chown $(id -u gdm):$(id -g gdm) ~gdm/.config/monitors.xml
    sudo restorecon ~gdm/.config/monitors.xml
}

add_nas_bookmarks()
{
    echo "GNOME> Adding NAS bookmarks..."
    nas_location="/mnt/nas/"
    
    if [[ ! -d $nas_location || ! -n $( ls -A $nas_location ) ]]
    then
        echo "No links to NAS found!"
        return 1
    fi

    nas_sub_location=$( ls -A $nas_location )
    for folder in ${nas_sub_location[@]}
    do
        echo "file://$nas_location$folder nas-${folder##*/}" | sudo dd of=~/.config/gtk-3.0/bookmarks oflag=append conv=notrunc status=none
    done
}

install_extensions()
{
    echo "GNOME> Updating system and installing gnome tools..."
    case $( cat /etc/os-release | grep ^ID= | cut -d "=" -f2 ) in
        *"arch"*)
            sudo pacman -Syu
            sudo pacman -S --needed --noconfirm gnome-tweaks gnome-themes-extra meson ts-node gettext just glib2-devel
            ;;
        *"fedora"*)
            sudo dnf update -y
            sudo dnf install -y gnome-tweaks gnome-themes-extra meson
            ;;
        *)
            echo "Unsupported distro !"
            return 2
            ;;
    esac
	
    cd ~

    install_extension_weather
    install_extension_medial_control
    install_extension_blur_my_shell
    install_extension_app_indicators
    install_extension_gsconnect
    install_extension_gnome_shell_extensions
    install_extension_forge
    install_extension_window_title_is_back
}

install_extension_from_zip()
{
    #$1 == either url or zip file
    if [ -z $1 ] ; then return 1 ; fi

    cd ~
    archive_name="ext_archive.zip"
    if [[ $1 =~ "https" ]]
    then
        curl -sL -o $archive_name "$1"
    else
        mv $1 $archive_name
    fi

    gnome-extensions install $archive_name --force
    rm $archive_name
}

install_extension_weather()
{
    echo "=> Installing WeatherOrNot..."
    install_extension_from_zip "https://gitlab.gnome.org/somepaulo/weather-or-not/-/raw/main/weatherornot@somepaulo.github.io.shell-extension.zip?ref_type=heads"
}

install_extension_medial_control()
{
    echo "=> Installing Media Control..."
    install_extension_from_zip "https://github.com/sakithb/media-controls/releases/latest/download/mediacontrolscliffniff.github.com.shell-extension.zip"
}

install_extension_blur_my_shell()
{
    echo "=> Installing Blur My Shell..."
    install_extension_from_zip "https://github.com/aunetx/blur-my-shell/releases/latest/download/blur-my-shell@aunetx.shell-extension.zip"
}

install_extension_app_indicators()
{
    echo "=> Installing App Indicators..."
    install_extension_from_zip "https://github.com/ubuntu/gnome-shell-extension-appindicator/releases/latest/download/appindicatorsupport@rgcjonas.gmail.com.zip"
}

install_extension_gsconnect()
{
    echo "=> Installing GSConnect..."
    gs_release=$( echo $( curl -sL https://github.com/GSConnect/gnome-shell-extension-gsconnect/releases/latest/ ) | sed -e 's/.*<title>//' -e 's/<\/title>.*//' | grep -o 'v[0-9]\{2,3\}' )
    install_extension_from_zip "https://github.com/GSConnect/gnome-shell-extension-gsconnect/releases/download/$gs_release/gsconnect@andyholmes.github.io.$gs_release.zip"
}

install_extension_forge()
{
    echo "=> Installing Forge..."
    git clone https://github.com/forge-ext/forge
    cd ./forge
    make install
    cd ..
    rm -rf ./forge
}

install_extension_window_title_is_back()
{
    git clone https://github.com/fthx/window-title-is-back
    cd ./window-title-is-back
    zip -r window-title-is-back@fthx.zip .
    gnome-extensions install window-title-is-back@fthx.zip --force
    cd ..
    rm -rf ./window-title-is-back
}

install_extension_gnome_shell_extensions()
{
    echo "=> Installing Gnome Shell Extensions..."
    gnome_shell_extensions=(
        "auto-move-windows@gnome-shell-extensions.gcampax.github.com.shell-extension.zip"
        "drive-menu@gnome-shell-extensions.gcampax.github.com.shell-extension.zip"
        "native-window-placement@gnome-shell-extensions.gcampax.github.com.shell-extension.zip"
    )

    gnome_version=$( gnome-shell --version | cut -d " " -f3 )
    extensions=gnome-shell-extensions-$gnome_version
    archive=$extensions.zip

    cd ~

    if curl --head -silent --fail https://gitlab.gnome.org/GNOME/gnome-shell-extensions/-/archive/$gnome_version/$archive > /dev/null;
    then
        curl -sL -o $archive "https://gitlab.gnome.org/GNOME/gnome-shell-extensions/-/archive/$gnome_version/$archive"
    else
        gnome_version=$( echo -e $gnome_version | cut -d "." -f1 )
        extensions=gnome-shell-extensions-gnome-$gnome_version
        archive=$extenions.zip
        if curl --head --silent --fail https://gitlab.gnome.org/GNOME/gnome-shell-extensions/-/archive/gnome-$gnome_version/$archive > /dev/null;
        then
            curl -sL -o $archive "https://gitlab.gnome.org/GNOME/gnome-shell-extensions/-/archive/gnome-$gnome_version/$archive"
        fi
    fi
    
    unzip -q $archive

    cd $extensions*
    ./export-zips.sh
    cd zip-files

    for i in ${gnome_shell_extensions[@]}
    do
        echo "=> Installing" $( echo $i | sed -r 's/(^|-)([a-z])/ \U\2/g' | cut -d "@" -f1 )"..."
        gnome-extensions install $i --force
    done
    
    cd ~
    rm -rf ./$extensions*
    rm $archive
}

get_wallpaper()
{
    echo "GNOME> Downloading wallpaper..."
    sudo curl -sL -o /usr/share/backgrounds/retro-futuristic-7.jpg https://cdn.prod.website-files.com/631e594043d13c32e2c927d9/6603aac1bb303f899b6a5e45_retro-futuristic-7.jpg
}

get_icons()
{
    echo "GNOME> Installing icons pack..."
    cd ~
    git clone https://github.com/vinceliuice/Tela-icon-theme.git
    cd ./Tela-icon-theme
    ./install.sh ubuntu
    cd ..
    rm -rf ./Tela-icon-theme
}

apply_settings()
{
    echo "GNOME> Applying settings..."

    weatherlocation="[<(uint32 2, <('Ottignies', '', false, [(0.88429474975634159, 0.079744969689317949)], @a(dd) [])>)>]"
    
    # base
    if [ -f /usr/share/backgrounds/retro-futuristic-7.jpg ]
    then
        dconf write /org/gnome/desktop/background/picture-uri "'file:///usr/share/backgrounds/retro-futuristic-7.jpg'"
        dconf write /org/gnome/desktop/background/picture-uri-dark "'file:///usr/share/backgrounds/retro-futuristic-7.jpg'"
    fi
    dconf write /org/gnome/desktop/input-sources/sources [('xkb', 'be'), ('xkb', 'us')]
    dconf write /org/gnome/desktop/interface/accent-color "'orange'"
    dconf write /org/gnome/desktop/interface/clock-format "'24h'"
    dconf write /org/gnome/desktop/interface/clock-show-weekday true
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
    dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"
    dconf write /org/gnome/desktop/interface/icon-theme "'Tela-ubuntu'"
    dconf write /org/gnome/desktop/interface/show-battery-percentage true
    dconf write /org/gnome/desktop/peripherals/mouse/accel-profile "'flat'"
    dconf write /org/gnome/desktop/peripherals/mouse/speed 0.0
    dconf write /org/gnome/desktop/session/idle-delay "uint32 300"
    dconf write /org/gnome/desktop/wm/preferences/num-workspaces 3
    dconf write /org/gnome/mutter/dynamic-workspaces false
    dconf write /org/gnome/settings-daemon/plugins/media-keys.custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/name "'Terminal'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/command "'ptyxis'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/binding "'<Ctrl><Alt>t'"
    dconf write /org/gnome/settings-daemon/plugins/power/ambient-enabled true
    dconf write /org/gnome/settings-daemon/plugins/power/power-button-action "'suspend'"
    dconf write /org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type "'nothing'"
    dconf write /org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-timeout 1800
    dconf write /org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-type "'suspend'"
    dconf write /org/gnome/shell/favorite-apps "['org.gnome.Ptyxis.desktop', 'org.gnome.Nautilus.desktop', 'org.mozilla.firefox.desktop', 'org.gnome.Evolution.desktop', 'org.gnome.Calendar.desktop', 'org.gnome.TextEditor.desktop', 'codium.desktop', 'org.gnome.Calculator.desktop', 'com.spotify.Client.desktop', 'steam.desktop', 'net.lutris.Lutris.desktop', 'discord.desktop', 'org.gnome.Boxes.desktop', 'org.keepassxc.KeePassXC.desktop', 'org.gnome.Software.desktop', 'org.gnome.Settings.desktop']"
    dconf write /org/gnome/shell/weather/locations "$weatherlocation"
    dconf write /org/gnome/system/locale/region "'fr_BE.UTF-8'"
    dconf write /org/gnome/Weather/locations "$weatherlocation"
    dconf write /system/locale/region "'fr_BE.UTF-8'"

    # weather
    dconf write /org/gnome/shell/extensions/weatherornot/position "'clock-right-centered'"

    # media control
    dconf write /org/gnome/shell/extensions/mediacontrols/show-control-icons-seek-backward false
    dconf write /org/gnome/shell/extensions/mediacontrols/show-control-icons-seek-forward false
    dconf write /org/gnome/shell/extensions/mediacontrols/show-player-icon false
    dconf write /org/gnome/shell/extensions/mediacontrols/extension-index "uint32 1"
    dconf write /org/gnome/shell/extensions/mediacontrols/labels-order "['ARTIST', '-', 'TITLE']"
    dconf write /org/gnome/shell/extensions/mediacontrols/label-width "uint32 250"
    dconf write /org/gnome/shell/extensions/mediacontrols/elements-order "['ICON', 'CONTROLS', 'LABEL']"
    
    # blur-my-shell
    dconf write /org/gnome/shell/extensions/blur-my-shell/panel/blur true
    dconf write /org/gnome/shell/extensions/blur-my-shell/panel/static-blur true
    dconf write /org/gnome/shell/extensions/blur-my-shell/panel/pipeline "'pipeline_default'"
    dconf write /org/gnome/shell/extensions/blur-my-shell/panel/force-light-text false
    dconf write /org/gnome/shell/extensions/blur-my-shell/panel/override-background true
    dconf write /org/gnome/shell/extensions/blur-my-shell/panel/style-panel 3
    dconf write /org/gnome/shell/extensions/blur-my-shell/panel/override-background-dynamically true
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-panel/blur-original-panel false
    dconf write /org/gnome/shell/extensions/blur-my-shell/overview/blur true
    dconf write /org/gnome/shell/extensions/blur-my-shell/overview/pipeline "'pipeline_default'"
    dconf write /org/gnome/shell/extensions/blur-my-shell/appfolder/blur true
    dconf write /org/gnome/shell/extensions/blur-my-shell/overview/style-components 1
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/blur false
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/static-blur false
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/sigma 25
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/brightness 0.75
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/override-background true
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/style-dash-to-dock 0
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/unblur-in-overview true
    dconf write /org/gnome/shell/extensions/blur-my-shell/applications/blur false
    dconf write /org/gnome/shell/extensions/blur-my-shell/lockscreen/blur false
    dconf write /org/gnome/shell/extensions/blur-my-shell/screenshot/blur false
    dconf write /org/gnome/shell/extensions/blur-my-shell/window-list/blur false
    dconf write /org/gnome/shell/extensions/blur-my-shell/coverflow-alt-tab/blur false

    #forge
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-focus-down "['<Super>j']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-focus-left "['<Super>h']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-focus-right "['<Super>l']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-focus-up "['<Super>k']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-gap-size-decrease "['<Control><Super>minus']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-gap-size-increase "['<Control><Super>plus']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-move-down "['<Shift><Super>j']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-move-left "['<Shift><Super>h']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-move-right "['<Shift><Super>l']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-move-up "['<Shift><Super>k']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-resize-bottom-decrease "['<Shift><Control><Super>i']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-resize-bottom-increase "['<Control><Super>u']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-resize-left-decrease "['<Shift><Control><Super>o']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-resize-left-increase "['<Control><Super>y']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-resize-right-decrease "['<Shift><Control><Super>y']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-resize-right-increase "['<Control><Super>o']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-resize-top-decrease "['<Shift><Control><Super>u']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/con-split-horizontal "['<Super>z']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/con-split-layout-toggle "['<Super>g']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/con-split-vertical "['<Super>v']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/con-stacked-layout-toggle "['<Shift><Super>s']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/con-tabbed-layout-toggle "['<Shift><Super>t']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/con-tabbed-showtab-decoration-toggle "['<Control><Alt>y']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/focus-border-toggle "['<Super>x']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-resize-top-increase "['<Control><Super>i']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-snap-center "['<Control><Alt>c']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-snap-one-third-left "['<Control><Alt>d']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-snap-one-third-right "['<Control><Alt>g']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-snap-two-third-left "['<Control><Alt>e']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-snap-two-third-right "['<Control><Alt>t']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-swap-down "['<Control><Super>j']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-swap-last-active "['<Super>Return']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-swap-left "['<Control><Super>h']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-swap-right "['<Control><Super>l']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-swap-up "['<Control><Super>k']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-toggle-always-float "['<Shift><Super>c']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/window-toggle-float "['<Super>c']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/workspace-active-tile-toggle "['<Shift><Super>w']"
    dconf write /org/gnome/shell/extensions/forge/keybindings/prefs-tiling-toggle "['<Super>w']"

    #window title is back
    dconf write /org/gnome/shell/extensions/window-title-is-back/fixed-width false
    dconf write /org/gnome/shell/extensions/window-title-is-back/show-title false
}

enable_gnome_extensions()
{
    echo "GNOME> Enabling extensions..."
    extensions=(
        "weatherornot@somepaulo.github.io"
        "mediacontrols@cliffniff.github.com"
        "drive-menu@gnome-shell-extensions.gcampax.github.com"
        "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
        "native-window-placement@gnome-shell-extensions.gcampax.github.com"
        "appindicatorsupport@rgcjonas.gmail.com"
        "gsconnect@andyholmes.github.io"
        "blur-my-shell@aunetx"
        "forge@jmmaranan.com"
        "window-title-is-back@fthx"
    )

    for i in ${extensions[@]}
    do
        echo "=> Enabling" $( echo $i | sed -r 's/(^|-)([a-z])/ \U\2/g' | cut -d "@" -f1 )"..."
        gnome-extensions enable $i
        sleep 1s # avoid unexpected behaviours if extenisons are not proprely load while working on the next.
    done
    echo
}

install_gnome_requirements()
{
    install_extensions
}

configure_gnome()
{
    update_gdm_resolution
    add_nas_bookmarks
    get_wallpaper
    get_icons
    apply_settings
    enable_gnome_extensions
}

if [ -z $1 ]
then
    echo "Parameter required!"
    echo
    return 2
elif [[ $1 == "-i" ]]
then
    install_gnome_requirements
elif [[ $1 == "-c" ]]
then
    configure_gnome
else
    echo "Parameter unknown!"
    return 2
fi
