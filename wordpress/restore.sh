#!/bin/bash

###########################################################
# TITLE: Restore WordPress files and database
# DESCRIPTION: This script restores WordPress files and database from a backup
# AUTHOR: Julian Ortlieb
# DATE: 2025-01-18
###########################################################

# Ask the user for the backup directory with Whiptail. Prefill with /var/www/backup
backup_dir=$(whiptail --title "Restore WordPress" --inputbox "Enter the backup directory" 10 60 "/var/www/backup" 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Ask the user for the WordPress directory with Whiptail. Prefill with /var/www/html
wordpress_dir=$(whiptail --title "Restore WordPress" --inputbox "Enter the WordPress directory" 10 60 "/var/www/html" 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Ask the user for the backup file with Whiptail
backup_file=$(whiptail --title "Restore WordPress" --inputbox "Enter the backup file name" 10 60 "$(ls $backup_dir | grep wordpress_)" 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Extract the backup file
tar -xzf $backup_dir/$backup_file -C $backup_dir

# Check if the command was successful
if [ $? -eq 0 ]; then
  echo "Backup file has been extracted successfully"
else
  echo "An error occurred"
  exit
fi

# Restore the WordPress files
tar -xzf $backup_dir/wordpress_files_*.tar.gz -C $wordpress_dir

# Check if the command was successful
if [ $? -eq 0 ]; then
  echo "WordPress files have been restored successfully"
else
  echo "An error occurred"
  exit
fi

# Get the WordPress database user and password from wp-config.php. If the file does not exist, empty strings are returned
wp_config=$wordpress_dir/wp-config.php
db_user=$(grep DB_USER $wp_config | cut -d \' -f 4)
db_password=$(grep DB_PASSWORD $wp_config | cut -d \' -f 4)
db_name=$(grep DB_NAME $wp_config | cut -d \' -f 4)
db_host=$(grep DB_HOST $wp_config | cut -d \' -f 4)

# Ask the user for the database user with Whiptail. Prefill with the user from wp-config.php
db_user=$(whiptail --title "Restore WordPress" --inputbox "Enter the database user" 10 60 $db_user 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Ask the user for the database password with Whiptail. Prefill with the password from wp-config.php
db_password=$(whiptail --title "Restore WordPress" --passwordbox "Enter the database password" 10 60 $db_password 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Restore the WordPress database
mysql -u $db_user -p$db_password $db_name < $backup_dir/wordpress_db_*.sql

# Check if the command was successful
if [ $? -eq 0 ]; then
  echo "WordPress database has been restored successfully"
else
  echo "An error occurred"
  exit
fi

# Clean up extracted files
rm $backup_dir/wordpress_files_*.tar.gz $backup_dir/wordpress_db_*.sql

echo "Restore completed successfully"
