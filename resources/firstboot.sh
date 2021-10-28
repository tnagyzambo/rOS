#!/bin/bash

# Apply real-time patch
# This must be done on the physical hardware
dpkg -i /rt-deb/*.deb

# Delete default user
userdel -r ubuntu

# Set hostname
hostnamectl set-hostname DEFAULT_HOSTNAME

# Start influxdb service
service influxdb start

# Start influxd process and send to background
influxd &

# Wait for influxd to start
sleep 15s

# Inital setup of influx
# REFERENCE: https://docs.influxdata.com/influxdb/v2.0/reference/cli/influx/setup/#flags
export CREDENTIALS_FILE="/rocketDATA/influx/credentials.toml"
export INFLUX_USER=$(grep -oP '(?<=user = ")([^\s]+)(?<!")' ${CREDENTIALS_FILE})
export INFLUX_PASSWORD=$(grep -oP '(?<=password = ")([^\s]+)(?<!")' ${CREDENTIALS_FILE})
export INFLUX_ORG=$(grep -oP '(?<=org = ")([^\s]+)(?<!")' ${CREDENTIALS_FILE})
export INFLUX_BUCKET=$(grep -oP '(?<=bucket = ")([^\s]+)(?<!")' ${CREDENTIALS_FILE})
export INFLUX_RETENTION=$(grep -oP '(?<=retention = ")([^\s]+)(?<!")' ${CREDENTIALS_FILE})
influx setup -u ${INFLUX_USER} -p ${INFLUX_PASSWORD} -o ${INFLUX_ORG} -b ${INFLUX_BUCKET} -r ${INFLUX_RETENTION} -f

# Regex match for ros user's API token and set as enviroment variable for use with ROS
# Add as enviroment variable for all shells
# I could not figure out how to do this with sed alone, the regex capabilites of sed are limited
export INFLUX_TOKEN=$(influx auth list | grep -oP "([^\s]*)(?=\s+\b${INFLUX_USER}(?![^\s])\b)")
sed -i -E "s/$(grep -oP '(token = [^\s]+")' ${CREDENTIALS_FILE})/token = \"${INFLUX_TOKEN}\"/" ${CREDENTIALS_FILE}

# Deregister firstboot service and clean up
systemctl disable firstboot.service
rm -rf /etc/systemd/system/firstboot.service
rm -f /firstboot.sh
rm -rf /rt-deb
reboot