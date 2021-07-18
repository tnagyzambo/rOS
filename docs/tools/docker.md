# Docker

**Docker** provides a virtual environment to build and run applications. By expressing all the build dependencies and steps required to build your software in a `.Dockerfile`, your build process becomes completely automated and portable. Other developers can compile your software with a `docker build` command as opposed to manually installing all the dependencies and executing the build commands themselves. Docker containers can also be run with `docker run` to execute some process or provide some software service.

This project performs the following during `docker build`
- Setup kernel build tools
- Pull rpi kernel source
- Pull PREEMPT_RT kernel patch
- Patch rpi kernel source
- Configure kernel
- Compile kernel
- Setup packer-builder-arm build tools
- Pull packer-builder-arm source
- Compile packer-builder-arm
- Install Packer
- Install packer-builder-arm as Packer plugin
- Setup container for running Packer

During `docker run`
- Run Packer build to create a provisioned Ubuntu image

---

### References

- [Docker](https://www.docker.com/)
- [Good Intro](https://www.ibm.com/cloud/learn/docker)