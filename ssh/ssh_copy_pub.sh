#!/bin/bash

###########################################################
# TITLE: Copy SSH public key to a remote server
# DESCRIPTION: This script copies the SSH public key to a remote server
# AUTHOR: Julian Ortlieb
# DATE: 2022-03-10
###########################################################

# List all public keys
public_keys=$(ls ~/.ssh/*.pub)

# Ask the user for the public key to copy with Whiptail
public_key=$(whiptail --title "Copy SSH public key" --menu "Select the public key to copy" 15 60 4 "${public_keys[@]}" 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Ask the user for the remote server with Whiptail
remote_server=$(whiptail --title "Copy SSH public key" --inputbox "Enter the remote server" 10 60 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Ask the user for the remote user with Whiptail
remote_user=$(whiptail --title "Copy SSH public key" --inputbox "Enter the remote user" 10 60 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Copy the public key to the remote server
ssh-copy-id -i $public_key $remote_user@$remote_server

# Check if the command was successful
if [ $? -eq 0 ]; then
  echo "The public key has been copied to the remote server"
else
  echo "An error occurred"
fi