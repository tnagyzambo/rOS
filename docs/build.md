# Build instructions

### 1. Install Docker

- [macOS](https://docs.docker.com/docker-for-mac/install/)
- [Windows](https://docs.docker.com/docker-for-windows/install/)
- [Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

Windows users will have to install [WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10) first.

### 2. Open a terminal in the repository root

Run the following:

`docker build . -f rocketOS.Dockerfile -t rocketos --build-arg RPI_VERSION=4` 

`docker run --rm --privileged -v /dev:/dev -v ${PWD}:/build -v ${PWD}:/rocketOS.pkr.hcl -i rocketos:latest`

### 3. Flash an SD card 

Using the [Raspberry Pi Imager](https://www.raspberrypi.org/software/), flash an SD card with the created `.img` file.

### 4. SSH into your RPI

The default login command is:

`ssh user@10.0.0.130`

The default password is:

`pwd`

Note that it will take a couple minutes for you to be able to log in to the Raspberry Pi on the first boot while the OS is performing some final configurations.

## Configuration

Configurations can be made to the compilation of the real-time kernel during the build step. NOTE: THIS IS UNTESTED.

`RPI_VERSION=3`

Configurations can be made to your rocketOS image during the `docker run` step. By adding the extra arguments below you can override the default values defined in the `.pkr.hcl` file.

`-e PKR_VAR_user=`

`-e PKR_VAR_password=`

`-e PKR_VAR_hostname=`

## Debugging the Docker Container

The Docker container can be started and left running until `exit` with the command:

`docker run -i --entrypoint=/bin/bash rocketOS:latest`