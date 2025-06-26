#!/usr/bin/env bash

desktop=$( cat <<EOF
<monitors version="2">
  <configuration>
    <layoutmode>logical</layoutmode>
    <logicalmonitor>
      <x>0</x>
      <y>0</y>
      <scale>1</scale>
      <primary>yes</primary>
      <monitor>
        <monitorspec>
          <connector>DP-1</connector>
          <vendor>GSM</vendor>
          <product>LG ULTRAWIDE</product>
          <serial>0x00013038</serial>
        </monitorspec>
        <mode>
          <width>3440</width>
          <height>1440</height>
          <rate>75.050</rate>
        </mode>
      </monitor>
    </logicalmonitor>
  </configuration>
</monitors>
EOF
)

laptop=$( cat <<EOF
<monitors version="2">
  <configuration>
    <layoutmode>logical</layoutmode>
    <logicalmonitor>
      <x>0</x>
      <y>0</y>
      <scale>1</scale>
      <primary>yes</primary>
      <monitor>
        <monitorspec>
          <connector>eDP-1</connector>
          <vendor>BOE</vendor>
          <product>0x0aca</product>
          <serial>0x00000000</serial>
        </monitorspec>
        <mode>
          <width>2560</width>
          <height>1600</height>
          <rate>90.003</rate>
        </mode>
      </monitor>
    </logicalmonitor>
  </configuration>
</monitors>
EOF
)

echo "MON> Updating monitor settings..."
chassis=$( hostnamectl chassis )
my_mon_settings=$( if [[ $chassis == "desktop" ]] ; then echo -e "$desktop" ; elif [[ $chassis == "laptop" ]] ; then echo -e "$laptop" ; fi )
echo -e "$my_mon_settings" | sudo dd of=~/.config/monitors.xml status=none
