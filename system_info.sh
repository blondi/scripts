#!/usr/bin/env bash

# collect CPU, GPU and DE from the current system.

env=
cpu=
gpu=

# CPU
cpuinfo=$( cat /proc/cpuinfo | grep vendor_id | uniq )
case ${cpuinfo##* } in
    *"Intel"*)
        cpu="intel"
        ;;
    *"AMD"*)
        cpu="amd"
        ;;
    *)
        cpu="unknown"
        ;;
esac

# GPU
lspciinfo=$( lspci | grep -E "VGA|3D" )
case $lspciinfo in
    *"NVIDIA"*)
        gpu="nvidia"
        ;;
    *"ATI"* | *"AMD"*)
        gpu="amd"
        ;;
    *)
        gpu="unknown"
        ;;
esac

# DE
case $XDG_CURRENT_DESKTOP in
    "GNOME")
        env="gnome"
        ;;
    *)
        env="unknown"
        ;;
esac

echo -e "CPU=$cpu\nGPU=$gpu\nDE=$env"
