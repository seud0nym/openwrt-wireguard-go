# openwrt-userspace-wireguard

A complete userspace implementation of Wireguard for OpenWRT-based devices that do not have kernel support for Wireguard.

## Pre-requisites
The device firmware **MUST** have kernel TUN support. You can verify whether your kernel was TUN configured with the following command:
```
zcat /proc/config.gz | grep CONFIG_TUN
```

If this command returns `CONFIG_TUN=y`, then you *can* use this implementation. If it returns `# CONFIG_TUN is not set`, you cannot.
