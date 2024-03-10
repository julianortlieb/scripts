#!/bin/bash

###########################################################
# TITLE: Enable Wake on LAN on debian based systems
# DESCRIPTION: This script enables Wake on LAN on debian based systems
# AUTHOR: Julian Ortlieb
# DATE: 2022-03-10
###########################################################

# Check if the script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Get possible interfaces
interfaces=$(ip link show | grep -oP '^\d+:\s+\K[^:]+')

# Ask the user for the interface to enable Wake on LAN with Whiptail
interface=$(whiptail --title "Wake on LAN" --menu "Select the interface to enable Wake on LAN" 15 60 4 "${interfaces[@]}" 3>&1 1>&2 2>&3)

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
  # Add the command to the rc.local file
  echo "ethtool -s $interface wol g" >> /etc/rc.local
  # Check if the command was successful
  if [ $? -eq 0 ]; then
    echo "Wake on LAN has been enabled permanently"
  else
    echo "An error occurred"
  fi
fi

# Exit the script
exit