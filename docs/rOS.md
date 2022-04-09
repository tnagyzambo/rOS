# rOS

**rOS** is a customized distribution of Linux designed for use on Raspberry Pi based flight computers in student rocketry. It is based on a **Unbuntu Server 20.04** distribution that has been patched with the **PREEMPT_RT** kernel patch to allow for soft real-time behaviour. Additional tweaks have been made to improve the CPU latency of the flight computer.

The main advantage of **rOS** is the fully automated, containerized build system. By automating the compilation, patching and provisioning of the operating system of the flight computer, a large amount of knowledge of the system becomes fully documented, transparent and portable. Modifications to the operating system can be tracked under version control and several potential errors in the setup of new flight computers can be eliminated.

This project intended to lower the bar of entry to development on Linux while at the same time increasing the ability of student organizations to retain knowledge and onboard new members, hopefully opening the door to more complex software projects in student rocketry.

Future work will build upon **rOS** with **ROS2** based flight software.