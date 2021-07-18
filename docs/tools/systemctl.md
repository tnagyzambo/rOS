# systemctl

**systemctl** is probably the most robust and straightforward way to execute scripts or run software without user interaction on Linux.

This project uses **systemctl** to apply the real-time kernel on the first boot of the operating system on real hardware. The ssh server is also automatically started on every boot by a systemctl service.

---

### References

- [How to use systemctl](https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units)
- [How to write new services](https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files)
- [Service file manual](https://www.freedesktop.org/software/systemd/man/systemd.service.html)