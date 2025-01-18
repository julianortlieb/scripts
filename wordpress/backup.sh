#!/bin/bash

###########################################################
# TITLE: Backup WordPress files and database
# DESCRIPTION: This script backs up WordPress files and database
# AUTHOR: Julian Ortlieb
# DATE: 2025-01-18
###########################################################

# Ask the user for the WordPress directory with Whiptail. Prefill with /var/www/html
wordpress_dir=$(whiptail --title "Backup WordPress" --inputbox "Enter the WordPress directory" 10 60 "/var/www/html" 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Ask the user for the backup directory with Whiptail. Prefill with /var/www/backup
backup_dir=$(whiptail --title "Backup WordPress" --inputbox "Enter the backup directory" 10 60 "/var/www/backup" 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Get the WordPress database user and password from wp-config.php
wp_config=$wordpress_dir/wp-config.php
db_user=$(grep DB_USER $wp_config | cut -d \' -f 4)
db_password=$(grep DB_PASSWORD $wp_config | cut -d \' -f 4)
db_name=$(grep DB_NAME $wp_config | cut -d \' -f 4)
db_host=$(grep DB_HOST $wp_config | cut -d \' -f 4)

# Ask the user for the database user with Whiptail. Prefill with the user from wp-config.php
db_user=$(whiptail --title "Backup WordPress" --inputbox "Enter the database user" 10 60 $db_user 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Ask the user for the database password with Whiptail. Prefill with the password from wp-config.php
db_password=$(whiptail --title "Backup WordPress" --passwordbox "Enter the database password" 10 60 $db_password 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Get all databases
databases=$(mysql -u $db_user -p$db_password -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)")

# Ask the user for the WordPress database with Whiptail. Prefill with the database from wp-config.php
wordpress_db=$(whiptail --title "Backup WordPress" --menu "Select the WordPress database" 15 60 4 10 "${databases[@]}" 3>&1 1>&2 2>&3)

# Check if the user has canceled the dialog
if [ $? -eq 1 ]; then
  echo "User canceled the dialog"
  exit
fi

# Ask the user if ready to backup with Whiptail and abort if not
if (whiptail --title "Backup WordPress" --yesno "Ready to backup WordPress in folder $wordpress_dir and database $wordpress_db ?" 10 60) then
  echo "Starting backup"
else
  echo "Backup aborted"
  exit
fi

#---------------------------------------------------------
# Backup WordPress files and database
#---------------------------------------------------------

# Create the backup directory if it does not exist
if [ ! -d $backup_dir ]; then
  mkdir -p $backup_dir
fi

# Backup the WordPress files
tar -czf $backup_dir/wordpress_files_$(date +%Y%m%d).tar.gz $wordpress_dir

# Check if the command was successful
if [ $? -eq 0 ]; then
  echo "WordPress files have been backed up successfully"
else
  echo "An error occurred"
fi

# Backup the WordPress database
mysqldump -u $db_user -p$db_password $wordpress_db > $backup_dir/wordpress_db_$(date +%Y%m%d).sql

# Check if the command was successful
if [ $? -eq 0 ]; then
  echo "WordPress database has been backed up successfully"
else
  echo "An error occurred"
fi

# Tar both files
tar -czf $backup_dir/wordpress_$(date +%Y%m%d).tar.gz $backup_dir/wordpress_files_$(date +%Y%m%d).tar.gz $backup_dir/wordpress_db_$(date +%Y%m%d).sql

# Remove the individual files
rm $backup_dir/wordpress_files_$(date +%Y%m%d).tar.gz $backup_dir/wordpress_db_$(date +%Y%m%d).sql

# Check if the backup directory is empty
if [ "$(ls -A $backup_dir)" ]; then
  echo "Backup completed successfully"
else
  echo "Backup failed"
fi