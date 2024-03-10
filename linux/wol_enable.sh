#!/bin/bash

###########################################################
# TITLE: Enable Wake on LAN on debian based systems
# DESCRIPTION: This script enables Wake on LAN on debian based systems
# AUTHOR: Julian Ortlieb
# DATE: 2022-03-10
###########################################################

# Check if the script is run as root
if [ "$EUID" -ne 0 ]
    then echo "Bitte als root ausführen"
    exit
fi

# Get possible interfaces and their IP addresses
while IFS= read -r line; do
    ip_address=$(ip -o -4 addr list $line | awk '{print $4}' | cut -d/ -f1)
    interfaces+=("$line" "$ip_address")
done < <(ip link show | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}')

# Ask the user for the interface to enable Wake on LAN with Whiptail
interface=$(whiptail --title "Wake on LAN" --menu "Wählen Sie die Schnittstelle aus, um Wake on LAN zu aktivieren" 15 60 4 "${interfaces[@]}" 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Enable Wake on LAN
ethtool -s $interface wol g

# Check if the command was successful
if [ $? -eq 0 ]; then
  echo "Wake on LAN has been enabled"
else
  echo "An error occurred"
fi

# Ask the user if the wol should be enabled permanently
if (whiptail --title "Wake on LAN" --yesno "Do you want to enable Wake on LAN permanently?" 10 60) then
  # Add the post up command to the etc interfaces.
  sed -i "/iface $interface inet static/a \ \ \ \ post-up ethtool -s $interface wol g" /etc/network/interfaces

  # Check if the command was successful
  if [ $? -eq 0 ]; then
    echo "Wake on LAN has been enabled permanently"
  else
    echo "An error occurred"
  fi
fi

# Exit the script
exit