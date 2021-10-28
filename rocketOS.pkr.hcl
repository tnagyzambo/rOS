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
    default = "rocketOS"
}

variable "influx_release" {
    type    = string
    default = "influxdb2-2.0.7-arm64.deb"
}

source "arm" "ubuntu" {
    file_urls = ["http://cdimage.ubuntu.com/releases/20.04.2/release/ubuntu-20.04.2-preinstalled-server-arm64+raspi.img.xz"]
    file_checksum_url = "http://cdimage.ubuntu.com/releases/20.04.2/release/SHA256SUMS"
    file_checksum_type = "sha256"
    file_target_extension = "xz"
    file_unarchive_cmd = ["xz", "--decompress", "$ARCHIVE_PATH"]
    image_build_method = "resize"
    image_path = "rocketOS-20.04.img"
    image_size = "6G"
    image_type = "dos"
    image_partitions {
        name = "boot"
        type = "c"
        start_sector = "2048"
        filesystem = "fat"
        size = "0"
        mountpoint = "/boot/firmware"
    }
    image_partitions {
        name = "root"
        type = "83"
        start_sector = "526336"
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
            # Fix hostname issue
            "sudo echo -e '127.0.0.1       localhost localhost.localdomain ubuntu\n$(cat input)' > /etc/hosts",
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
            # Relpace default hostname with desired hostname in firstboot script
            "sed -i 's/DEFAULT_HOSTNAME/${var.hostname}/g' /firstboot.sh",
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
            "sudo echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu focal main' | tee /etc/apt/sources.list.d/ros2.list > /dev/null",
            "sudo DEBIAN_FRONTEND=noninteractive apt-get update",
            "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy ros-galactic-ros-base",
            "sudo echo 'source /opt/ros/galactic/setup.bash' >> /home/ros/.bashrc",
            # rocketDATA
            "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy wget",
            "sudo wget https://dl.influxdata.com/influxdb/releases/${var.influx_release}",
            "sudo dpkg -i ${var.influx_release}",
            "sudo rm ${var.influx_release}",
            "sudo mkdir /rocketDATA",
            "sudo mkdir /rocketDATA/influx",
            "sudo chown -R ${var.user}:sudo /rocketDATA",
        ]
        pause_before = "30s"
    }
    provisioner "file" {
        # Pull influx credentials file
        source = "/build/resources/influx/credentials.toml"
        destination = "/rocketDATA/influx/"
        pause_before = "5s"
    }
    provisioner "file" {
        # Pull influx config file
        source = "/build/resources/influx/config.toml"
        destination = "/rocketDATA/influx/"
        pause_before = "5s"
    }
}
