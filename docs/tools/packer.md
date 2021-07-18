# Packer

**Packer** is a provisioning tool that you create pre-configured images of operating systems that have your required software pre-installed. By defining a `.pck.hcl` file and running `packer build` your operating system is started in a virtual environment and all the steps required to configure your system, install your software and copy over any files you need are performed. An image is then created ready for deployment on your hardware.

**Packer** cannot normally build for `arm` architectures, it needs to be extended with the plugin **packer-builder-arm**. This allows you to cross-build your images from `x86` or `amd64` host computers. **packer-builder-arm** relies on **QEMU** to do this.

This project performs the following during `packer build`
- Pulls base Ubuntu Server 20.04 image
- Configures SD card partitions
- Copies over real-time kernel
- Copies over first boot setup scripts
- Fixes a set of issues likely resulting from the Packer virtual environment running inside a Docker virtual environment (not relevant for the final product)
- Configures user accounts
- Installs and configures SSH server
- Configures network
- Installs real-time diagnostic tools
- Configures CPU settings for better performance

---

### Resources

- [Packer](https://www.packer.io/)
- [packer-builder-arm](https://github.com/mkaczanowski/packer-builder-arm)