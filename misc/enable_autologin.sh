#!/bin/bash

###########################################################
# TITLE: Enable autologin
# DESCRIPTION: This script enables autologin for tty
# AUTHOR: Julian Ortlieb
# DATE: 2025-01-22
###########################################################

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Ask if this is a proxmox lxc container with Whiptail
if (whiptail --title "Enable autologin" --yesno "Is this a Proxmox LXC container?" 10 60) then
    # Check if the user has canceled the dialog
    if [ $? -eq 1 ]; then
    echo "User canceled the dialog"
    exit
    fi
else
    echo "This is not a Proxmox LXC container"
    exit
fi


# Get user list from /etc/passwd
users=$(cut -d: -f1 /etc/passwd)

# Get the user list in a two dimensional array. The first column is the username and the second column is the username for Whiptail
user_list=($(for user in ${users[@]}; do echo "$user" "$user"; done))

# Ask the user for the user with Whiptail
user=$(whiptail --title "Enable autologin" --menu "Choose the user" 20 60 10 "${user_list[@]}" 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

mkdir -p /etc/systemd/system/container-getty@.service.d

# Create the autologin service
cat <<EOF > /etc/systemd/system/container-getty@.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $user --noclear --keep-baud tty%I 115200,38400,9600 \$TERM
EOF

# Check if the command was successful
if [ $? -eq 0 ]; then
  echo "Autologin has been enabled successfully"
else
  echo "An error occurred"
  exit
fi