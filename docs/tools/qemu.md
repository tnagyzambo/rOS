# QEMU

**QEMU** is a technology that you will encounter if you dive into the details of how **Docker** and **Packer** work. Most likely you will not need to interact with it directly, but it is helpful to have a general idea of what it is and how it works.

**QEMU** lets you create a virtual machine environment, for example, it allows an `x86` machine to run `arm` software. Keep in mind that not all things are possible in this environment. Kernel upgrades cannot be done in a **QEMU** environment, which is the reason that this project uses a first boot script to install the real-time kernel.

---

### References

- [QEMU](https://www.qemu.org/)
- [arm Docker Containers on x86 Machines](https://www.stereolabs.com/docs/docker/building-arm-container-on-x86/)