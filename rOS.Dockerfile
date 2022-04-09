# Build arguments
ARG RPI_VERSION

###########################################################################
#                             Patch kernel                                #
###########################################################################

# REFERENCE: https://www.get-edi.io/Real-Time-Linux-on-the-Raspberry-Pi/
# REFERENCE: https://www.instructables.com/64bit-RT-Kernel-Compilation-for-Raspberry-Pi-4B-/
# REFERENCE: https://www.raspberrypi.org/documentation/linux/kernel/building.md#choosing_sources
FROM ubuntu:20.04 AS base
USER root

# Get git and wget for pulling sources
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -qy git \
                                                       wget

# Get rpi 5.4.y kernel, the .y subversion can be seen in the commit history of the
# Makefile in the repo
# At the time of writing it is 5.4.83
RUN git clone --depth=1 --branch=rpi-5.4.y https://github.com/raspberrypi/linux

# Get RT_PREEMPT and patch the kernel
# You have to match the patch version to the rpi kernel version, there will be a range of
# versions that will successfully patch, take the highest revision
# At the time of writing it is 5.4.93-rt51 applied to kernel 5.4.83
ENV RT_VERSION=5.4.93-rt51
RUN wget http://cdn.kernel.org/pub/linux/kernel/projects/rt/5.4/older/patch-${RT_VERSION}.patch.gz
RUN gunzip patch-${RT_VERSION}.patch.gz

WORKDIR /linux
RUN patch -p1 < ../patch-${RT_VERSION}.patch

# Setup cross-compile build tools
ENV ARCH=arm64
ENV TRIPLE=aarch64-linux-gnu
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -qy make \
                                                       gcc-${TRIPLE} \
                                                       build-essential \
                                                       rsync \
                                                       bc \
                                                       kmod \
                                                       cpio \
                                                       flex \
                                                       cpio \
                                                       libncurses5-dev \
                                                       bison \
                                                       libssl-dev
RUN dpkg --add-architecture ${ARCH}
RUN export $(dpkg-architecture -a ${ARCH}) && export CROSS_COMPILE=${TRIPLE}-

###########################################################################
#                           Configure kernel                              #
###########################################################################

# Initialize .config file for rpi target
#
# REFERENCE: https://www.raspberrypi.org/documentation/linux/kernel/building.md#choosing_sources
FROM base AS rpi-4
WORKDIR /linux
RUN make ARCH=${ARCH} CROSS_COMPILE=${TRIPLE}- bcm2711_defconfig

FROM base AS rpi-3
WORKDIR /linux
RUN make ARCH=${ARCH} CROSS_COMPILE=${TRIPLE}- bcmrpi3_defconfig

# Setup RT and compile kernel 
FROM rpi-${RPI_VERSION} AS config
WORKDIR /linux

# Create .config file
RUN make ARCH=${ARCH} CROSS_COMPILE=${TRIPLE}- oldconfig

# Set RT_PREEMPT kernel settings
RUN    ./scripts/config -d CONFIG_PREEMPT \
    && ./scripts/config -e CONFIG_PREEMPT_RT \
    && ./scripts/config -d CONFIG_NO_HZ_IDLE \
    && ./scripts/config -e CONFIG_NO_HZ_FULL \
    && ./scripts/config -d CONFIG_HZ_250 \
    && ./scripts/config -e CONFIG_HZ_1000 \
    && ./scripts/config -d CONFIG_AUFS_FS

###########################################################################
#                           Compile kernel                                #
###########################################################################

FROM config AS compile
WORKDIR /linux

# Compile and package kernel
RUN make -j $(nproc) KBUILD_IMAGE=arch/arm64/boot/Image ARCH=${ARCH} CROSS_COMPILE=${TRIPLE}- LOCALVERSION=-raspi KDEB_PKGVERSION=$(make kernelversion)-1 deb-pkg 
RUN mkdir /rt-deb
RUN mv /*.deb /rt-deb/

# If you want to extract and manually patch the kernel from this stage
# these are the commands you need:
# Pull packaged .deb files to host machine with:
# docker cp <container-name>:/rt-deb .
# Send to rpi:
# scp rt-deb/* <user>@<ip-address>:/tmp
# On rpi:
# sudo dpkg -i ~/tmp/*.deb
# sudo reboot

###########################################################################
#                           Get emulator                                  #
###########################################################################

# This and the next section is derived from the docker use case found in
#
# REFERENCE: https://github.com/mkaczanowski/packer-builder-arm
#
# Not clear on exactly how this works but it brings in some Qemu dependencies
# to allow cross-architecture builds
#
# REFERENCE: https://hub.docker.com/r/tonistiigi/binfmt
FROM tonistiigi/binfmt:qemu-v5.0.1 AS binfmt

###########################################################################
#                           Setup up Packer                               #
###########################################################################

# This section gets Packer and compiles a Packer plugin called packer-builder-arm
# The later steps of the docker build can then pull in these dependencies in a clean way without having to pull
# in the build dependencies of the plugin
#
# At the time of writing I could not figure out how to include packer-builder-arm as a required plugin
# in the .pkr.hcl file. This is a new feature and should be transitioned to as soon as possible
#
# REFERENCE: https://github.com/mkaczanowski/packer-builder-arm
# REFERENCE: https://linuxhit.com/build-a-raspberry-pi-image-packer-packer-builder-arm/
FROM golang:1.16-buster AS builder

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends ca-certificates \
                                                                               git \
                                                                               unzip \
                                                                               upx-ucl \
                                                                               wget

# Compile packer-builder-arm
WORKDIR /build                                                 
RUN git clone --depth=1 --branch=master https://github.com/mkaczanowski/packer-builder-arm.git .
RUN go mod download
RUN go build -o packer-builder-arm

# Get Packer
ENV PACKER_VERSION 1.7.2
RUN wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip -q -O /tmp/packer.zip
RUN unzip /tmp/packer.zip -d /bin
RUN rm /tmp/packer.zip

# Compress with UPX
RUN upx-ucl /build/packer-builder-arm /bin/packer

###########################################################################
#                               Packer section                            #
###########################################################################

# This section uses Packer to generate a ubuntu image that we can flash directly to an SD card
#
# REFERENCE: https://linuxhit.com/build-a-raspberry-pi-image-packer-packer-builder-arm/
FROM compile AS pack

# Get Packer
ENV PACKER_VERSION=1.7.2
RUN DEBIAN_FRONTEND=noninteractive apt-get install -qy --no-install-recommends ca-certificates \
                                                                               dosfstools \
                                                                               gdisk \
                                                                               kpartx \
                                                                               parted \
                                                                               libarchive-tools \
                                                                               sudo \
                                                                               xz-utils \
                                                                               psmisc \
                                                                               qemu-utils

WORKDIR /build

# Bring in entrypoint script from local machine
# Make sure script is executable with chmod -x
COPY resources/entrypoint.sh /entrypoint.sh
RUN chmod +x ../entrypoint.sh

# Pull in packer and built plugin
COPY --from=builder /build/packer-builder-arm /bin/packer /bin/

# Pull in emulation dependancies
COPY --from=binfmt /usr/bin/ /usr/bin

# Set entrypoint in to container
ENTRYPOINT ["/entrypoint.sh", "build", "/rOS.pkr.hcl"]

###########################################################################
#                               Instructions                              #
###########################################################################

# To build:
# docker build . -f rocketOS.Dockerfile -t rocketos --build-arg RPI_VERSION=4
# -f rocketOS.Dockerfile                * Specify to build this Docker file
# --build-arg RPI_VERSION=4             * Which RPI to build image for (3 or 4) UNTESTED!!!

# To run:
# docker run --rm --privileged -v /dev:/dev -v ${PWD}:/build -v ${PWD}:/rocketOS.pkr.hcl -i rocketos:latest
# --rm                                  * Remove the container if it exists
# --privileged                          * This container needs elevated privledges to run
# -v /dev:/dev                          * Bind mount host OS device volume (needed for /dev/loop to mount virtual devices)
# -v ${PWD}:/build                      * Bind mount the current working directory to the container
# -v ${PWD}:/rocketOS.pkr.hcl           * Bind mount the packer definition at runtime
# -i                                    * Allow interactive run
# build file.pkr.hcl                    * OPTIONAL: append to run command to overide entrypoint arguments

# To run overiding the entrypoint (run container without task to allow inspection):
# docker run -i --entrypoint=/bin/bash rocketos:latest
# -i                                    * Allow interactive run
# --entrypoint=/bin/bash                * Start a bash session as entrypoint