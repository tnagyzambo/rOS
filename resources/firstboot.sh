#!/bin/bash

# Apply real-time patch
# This must be done on the physical hardware
dpkg -i /rt-deb/*.deb

# Delete default user
userdel -r ubuntu

# Deregister firstboot service and clean up
systemctl disable firstboot.service
rm -rf /etc/systemd/system/firstboot.service
rm -f /firstboot.sh
rm -rf /rt-deb
reboot