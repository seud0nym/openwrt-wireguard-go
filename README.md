# openwrt-wireguard-go

![Latest Release Downloads](https://img.shields.io/github/downloads/seud0nym/openwrt-wireguard-go/latest/total)

A complete userspace implementation of WireGuard written in Golang for OpenWRT-based devices that do not have kernel support for WireGuard. If your device *does* have kernel support for WireGuard, then you should not be using this.

The implementation is optimised for minimum memory use. It should only consume around 20Mb of RAM for each WireGuard interface.

For more information on WireGuard, please see https://www.wireguard.com/.

## Pre-requisites

The device firmware **MUST** have kernel TUN support. You can verify whether your kernel has TUN configured with the following command:

```
zcat /proc/config.gz | grep CONFIG_TUN
```

If this command returns `CONFIG_TUN=y`, then you *can* use this implementation. If it returns `# CONFIG_TUN is not set`, you cannot.

## Installation

### Package Installation

An `opkg` repository is available for **arm-cortex-a9** architecture devices. 

#### opkg Configuration

Run the following commands to configure `opkg` correctly:

```
grep -qE 'arch\s*\barm_cortex-a9\b' /etc/opkg.conf || echo 'arch arm_cortex-a9 10' >> /etc/opkg.conf
grep -q '/openwrt-wireguard-go/' /etc/opkg/customfeeds.conf || echo 'src/gz wg_go https://raw.githubusercontent.com/seud0nym/openwrt-wireguard-go/master/repository/arm_cortex-a9/base' >> /etc/opkg/customfeeds.conf
```

To install or upgrade, run the following commands:

```
opkg update
opkg install wireguard-go
```

### Manual Installation

#### Devices with ARMv5/6/7 Processors

Run the following command to download and install the correct release for your device:
```
curl -skL https://raw.githubusercontent.com/seud0nym/openwrt-wireguard-go/master/install_arm.sh | sh -s --
```

The script will determine the correct version for your processor. This may mean, for example, that even though your device has an ARMv7 processor, the ARMv5 release may be selected, as some versions of the ARMv7 chip do not have a Floating Point Unit which will cause the ARMv7 release to core dump.

If `opkg` is configured correctly with an architecture of **arm-cortex-a9** specified in the `/etc/opkg.conf` file, then the latest release .ipk file will be downloaded and installed with the `opkg` command. Otherwise, the appropriate release tar file will be downloaded and extracted to the correct locations.

#### Manual download and execution of install script

If you are uncomfortable running the script without reviewing it first, simply download it and execute it manually:
```
curl -skLO https://raw.githubusercontent.com/seud0nym/openwrt-wireguard-go/master/install_arm.sh
chmod +x install_arm.sh
./install_arm.sh
```

### Building for other devices

This requires an installation of go ≥ 1.16.
```
git clone https://github.com/seud0nym/openwrt-wireguard-go.git
cd openwrt-wireguard-go
./build.sh [<ARCH> ...|all]
```

The `build.sh` script will by default build the release .tgz files for the ARM architecture. You can specify one or more valid [GOARCH](https://golang.org/doc/install/source#environment) architectures (separated by spaces) or `all` to build all releases.

To install the release on a device, execute:
```
tar -zxvf openwrt-wireguard-go_<ARCH>.tgz -C /
```

Please note that only the ARMv5 version has been tested.

## Usage 

Once installed, you can use the official OpenWRT guides at https://openwrt.org/docs/guide-user/services/vpn/wireguard/start to configure WireGuard as a [server](https://openwrt.org/docs/guide-user/services/vpn/wireguard/server) and/or a [client](https://openwrt.org/docs/guide-user/services/vpn/wireguard/client).

*However*, do **NOT** install the specified opkg packages (`wireguard` and `wireguard-tools`). If your device does not have kernel support for WireGuard, then the installation of the `wireguard` package will probably fail. The `wireguard-tools` package *may* work, but it is unnecessary as this project includes all the required files, and the `wireguard-tools` package will replace some or all of them, causing everything to break.

If your device *does* have kernel support for WireGuard, then you should not be using this. If you just need an implementation of the WireGuard [wg(8)](https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8) utility, then have a look at [wg-go](https://github.com/seud0nym/wg-go).

## Uninstalling

Remove any network configurations you have created, then:

### Package Installation

```
opkg remove wireguard-go
```

### Manually Installion

```
wg --uninstall
```

## Thanks

This project would not be possible without the official WireGuard cross-platform repositories:
- https://git.zx2c4.com/wireguard-go/about/
- https://github.com/WireGuard/wgctrl-go
