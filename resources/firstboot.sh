#!/bin/bash

# Apply real-time patch
# This must be done on the physical hardware
dpkg -i /rt-deb/*.deb
rm -rf /rt-deb
flash-kernel --force 5.15.45-rt46-v8-raspi

# Delete default user
userdel -r ubuntu

# Set hostname
hostnamectl set-hostname DEFAULT_HOSTNAME

# Replace old 'hostname' file
rm /etc/hostname
echo 'HOSTNAME' >> /etc/hostname

# Append new hostname to first line of 'hosts' file
# Result should be '127.0.0.1 localhost HOSTNAME'
sed -i '1!b;s/$/\ HOSTNAME/g' /etc/hosts

# Setup i2c
sudo modprobe i2c-dev
sudo echo 'i2c-dev' >> /etc/modules

# Start apache server
a2ensite rctrl.conf
service apache2 start

# Start influxdb service
service influxdb start

# Start influxd process and send to background
influxd &

# Wait for influxd to start
sleep 15s

# Inital setup of influx
# REFERENCE: https://docs.influxdata.com/influxdb/v2.0/reference/cli/influx/setup/#flags
# Path to ${CREDENTIALS_FILE} is inserted into this script when buildling the OS image
export CREDENTIALS_FILE="/home/USERNAME/rdata/influx/credentials.toml"
export INFLUX_USER=$(grep -oP '(?<=user = ")([^\s]+)(?<!")' ${CREDENTIALS_FILE})
export INFLUX_PASSWORD=$(grep -oP '(?<=password = ")([^\s]+)(?<!")' ${CREDENTIALS_FILE})
export INFLUX_ORG=$(grep -oP '(?<=org = ")([^\s]+)(?<!")' ${CREDENTIALS_FILE})
export INFLUX_BUCKET=$(grep -oP '(?<=bucket = ")([^\s]+)(?<!")' ${CREDENTIALS_FILE})
export INFLUX_RETENTION=$(grep -oP '(?<=retention = ")([^\s]+)(?<!")' ${CREDENTIALS_FILE})
influx setup -u ${INFLUX_USER} -p ${INFLUX_PASSWORD} -o ${INFLUX_ORG} -b ${INFLUX_BUCKET} -r ${INFLUX_RETENTION} -f

# Regex match for ros user's API token and set as enviroment variable for use with ROS
export INFLUX_TOKEN=$(influx auth list | grep -oP "([^\s]*)(?=\s+\b${INFLUX_USER}(?![^\s])\b)")
sed -i -E "s/$(grep -oP '(token = [^\s]+")' ${CREDENTIALS_FILE})/token = \"${INFLUX_TOKEN}\"/" ${CREDENTIALS_FILE}

# Deregister firstboot service and clean up
systemctl disable firstboot.service
rm -rf /etc/systemd/system/firstboot.service
rm -f /firstboot.sh
reboot