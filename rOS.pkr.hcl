variable "user" {
    type    = string
    default = "user"
}

variable "password" {
    type    = string
    default = "pwd"
}

variable "hostname" {
    type    = string
    default = "rOS"
}

variable "ros2_release" {
    type    = string
    default = "humble"
}

variable "influx_release" {
    type    = string
    default = "2.2.0"
}

variable "influx_cl_release" {
    type    = string
    default = "2.3.0"
}

source "arm" "ubuntu" {
    file_urls = ["http://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04-preinstalled-server-arm64+raspi.img.xz"]
    file_checksum_url = "http://cdimage.ubuntu.com/releases/22.04/release/SHA256SUMS"
    file_checksum_type = "sha256"
    file_target_extension = "xz"
    file_unarchive_cmd = ["xz", "--decompress", "$ARCHIVE_PATH"]
    image_build_method = "resize"
    image_path = "rOS-22.04.img"
    image_size = "6G"
    image_type = "dos"
    image_partitions {
        name = "boot"
        type = "c"
        start_sector = "8192"
        filesystem = "vfat"
        size = "256M"
        mountpoint = "/boot"
      }
    image_partitions {
        name = "root"
        type = "83"
        start_sector = "532480"
        filesystem = "ext4"
        size = "0"
        mountpoint = "/"
      }
    image_chroot_env = ["PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"]
    qemu_binary_source_path = "/usr/bin/qemu-aarch64-static"
    qemu_binary_destination_path = "/usr/bin/qemu-aarch64-static"
}

build {
    sources = ["source.arm.ubuntu"]
    provisioner "file" {
        # Pull in patched kernel from docker container
        source = "/rt-deb"
        destination = "/rt-deb"
        pause_before = "5s"
    }
    provisioner "file" {
        # Pull in firstboot service file from local build directory (bind mounted to docker container)
        source = "/build/resources/firstboot.service"
        destination = "/etc/systemd/system/firstboot.service"
        pause_before = "5s"
    }
    provisioner "file" {
        # Pull in firstboot script file from local build directory (bind mounted to docker container)
        source = "/build/resources/firstboot.sh"
        destination = "/"
        pause_before = "5s"
    }
    provisioner "shell" {
        inline = [
            # Fix some weird permision issue regarding /dev/null
            "rm /dev/null",
            "mknod /dev/null c 1 3",
            "chmod 666 /dev/null",
            # Fix apt-get not being able to find sources
            "sudo mv /etc/resolv.conf /etc/resolv.conf.bk",
            "sudo echo 'nameserver 8.8.8.8' > /etc/resolv.conf",
            # Create user
            "sudo su -c 'useradd ${var.user} -s /bin/bash -m -g sudo'",
            "echo ${var.user}:${var.password} | sudo chpasswd",
            # Actually provision the system
            "sudo DEBIAN_FRONTEND=noninteractive apt-get update",
            "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy openssh-server rt-tests cpufrequtils",
            # Configure DCHP client 
            "sudo echo 'auto eth0' >> /etc/network/interfaces",
            "sudo echo 'iface eth0 inet DHCP' >> /etc/network/interfaces",
            # Start SSH server on boot
            "sudo systemctl enable ssh",
            # Replace user name and hostname with desired hostname in firstboot script
            "sed -i 's/HOSTNAME/${var.hostname}/g' /firstboot.sh",
            "sed -i 's/USERNAME/${var.user}/g' /firstboot.sh",
            # Setup firstboot service
            "sudo chmod +x /firstboot.sh",
            "sudo systemctl enable firstboot.service",
            # CPU performance settings to improve latency
            # https://chenna.me/blog/2020/02/23/how-to-setup-preempt-rt-on-ubuntu-18-04/
            "sudo systemctl enable cpufrequtils",
            "sudo systemctl disable ondemand",
            "sudo echo 'GOVERNOR=performance' > /etc/default/cpufrequtils",
            # ROS2
            "sudo DEBIAN_FRONTEND=noninteractive apt-get update",
            "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy curl gnupg",
            "sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key  -o /usr/share/keyrings/ros-archive-keyring.gpg",
            "sudo echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main' | tee /etc/apt/sources.list.d/ros2.list > /dev/null",
            "sudo DEBIAN_FRONTEND=noninteractive apt-get update",
            "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy ros-${var.ros2_release}-ros-base",
            "sudo echo 'source /opt/ros/${var.ros2_release}/setup.bash' >> /home/${var.user}/.bashrc",
            # rosbridge
            "sudo DEBIAN_FRONTEND=noninteractive apt-get update",
            "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy ros-${var.ros2_release}-rosbridge-suite",
            # rCTRL
            "sudo DEBIAN_FRONTEND=noninteractive apt-get update",
            "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy apache2",
            "sudo rm -R /var/www/html",
            "sudo rm /etc/apache2/sites-available/000-default.conf",
            "sudo mkdir /var/www/rctrl",
            "sudo chown -R ${var.user} /var/www/rctrl",
            # rDATA
            "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy wget",
            "sudo wget https://dl.influxdata.com/influxdb/releases/influxdb2-${var.influx_release}-arm64.deb",
            "sudo dpkg -i influxdb2-${var.influx_release}-arm64.deb",
            "sudo rm influxdb2-${var.influx_release}-arm64.deb",
            "sudo wget https://dl.influxdata.com/influxdb/releases/influxdb2-client-${var.influx_cl_release}-linux-arm64.tar.gz",
            "sudo tar xvzf influxdb2-client-${var.influx_cl_release}-linux-arm64.tar.gz",
            "sudo cp influxdb2-client-${var.influx_cl_release}-linux-arm64/influx /usr/local/bin/",
            "sudo rm influxdb2-client-${var.influx_cl_release}-linux-arm64.tar.gz",
            "sudo rm -r influxdb2-client-${var.influx_cl_release}-linux-arm64",
            "sudo mkdir /home/${var.user}/rdata",
            "sudo mkdir /home/${var.user}/rdata/influx",
            # rGPIO
            "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy gpiod",
            "sudo usermod -G dialout ${var.user}",
            # rI2C
            "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy i2c-tools",
        ]
        pause_before = "30s"
    }
    provisioner "file" {
        # Pull apache config file
        source = "/build/resources/apache/rctrl.conf"
        destination = "/etc/apache2/sites-available/rctrl.conf"
        pause_before = "5s"
    }
    provisioner "file" {
        # Pull influx credentials file
        source = "/build/resources/influx/credentials.toml"
        destination = "/home/${var.user}/rdata/influx/"
        pause_before = "5s"
    }
    provisioner "file" {
        # Pull influx config file
        source = "/build/resources/influx/config.toml"
        destination = "/home/${var.user}/rdata/influx/"
        pause_before = "5s"
    }
    provisioner "shell" {
        inline = [
             "sudo chown -R ${var.user} /home/${var.user}",
        ]
        pause_before = "5s"
    }
}
