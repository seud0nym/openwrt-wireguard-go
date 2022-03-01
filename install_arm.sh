#!/bin/sh

echo "Checking TUN..."
if ! zcat /proc/config.gz | grep -q '^CONFIG_TUN=y$'; then
    zcat /proc/config.gz | grep -q '^CONFIG_TUN'
    echo "Sorry - TUN must be configured in the kernel"
    exit 2
fi

echo "Checking opkg configuration..."
grep -qE 'arch\s*\barm_cortex-a9\b' /etc/opkg.conf
if [ $? -eq 0 ]; then
    echo " -> Found architecture arm_cortex-a9 in /etc/opkg.conf"
    echo "Downloading and installing latest openwrt-wireguard-go_arm_cortex-a9.ipk from Github..."
    RESPONSE_CODE=$(curl -kLsI -o /dev/null -w '%{http_code}' https://github.com/seud0nym/openwrt-wireguard-go/releases/latest/download/openwrt-wireguard-go_arm_cortex-a9.ipk)
    if [ "$RESPONSE_CODE" = "200" ]; then
        curl -kL https://github.com/seud0nym/openwrt-wireguard-go/releases/latest/download/openwrt-wireguard-go_arm_cortex-a9.ipk -o/tmp/openwrt-wireguard-go_arm_cortex-a9.ipk
        opkg install /tmp/openwrt-wireguard-go_arm_cortex-a9.ipk
    else
        echo "Oh oh! An unexpected error occurred - Download request returned $RESPONSE_CODE"
    fi
else
    echo "Checking CPU..."
    if ! uname -m | grep -qE '^armv[5678]'; then
        echo "Sorry - Pre-built releases only exist for ARM processors (armv5, armv6, and armv7)"
        exit 2
    fi

    echo "Checking FPU..."
    GO_ARM_7_FPUS="\bvfpv3\b|\bvfpv3-fp16\b|\bvfpv3-d16\b|\bvfpv3-d16-fp16\b|\bneon\b|\bneon-vfpv3\b|\bneon-fp16\b|\bvfpv4\b|\bvfpv4-d16\b|\bneon-vfpv4\b|\bfpv5-d16\b|\bfp-armv8\b|\bneon-fp-armv8\b|crypto-neon-fp-armv8\b"
    GO_ARM_6_FPUS="\bvfp\b|\bvfpv2\b"
    ARCH="armv5"
    for FEATURE in $(cat /proc/cpuinfo | grep -m 1 '^Features' | cut -d: -f2); do
        if echo "$FEATURE" | grep -qE "$GO_ARM_7_FPUS"; then
            ARCH="armv7"
            break
        elif echo "$FEATURE" | grep -qE "$GO_ARM_6_FPUS"; then
            ARCH="armv6"
            break
        fi
    done
    unset GO_ARM_7_FPUS
    unset GO_ARM_6_FPUS

    echo " -> Selected architecture '$ARCH' based on FPU availability"
    echo "Downloading and installing latest openwrt-wireguard-go_${ARCH}.tgz from Github..."
    RESPONSE_CODE=$(curl -kLsI -o /dev/null -w '%{http_code}' https://github.com/seud0nym/openwrt-wireguard-go/releases/latest/download/openwrt-wireguard-go_${ARCH}.tgz)
    if [ "$RESPONSE_CODE" = "200" ]; then
        curl -kL https://github.com/seud0nym/openwrt-wireguard-go/releases/latest/download/openwrt-wireguard-go_${ARCH}.tgz | tar -xzvf - -C /
        sysctl -e -p /etc/sysctl.d/99-wireguard.conf
    else
        echo "Oh oh! An unexpected error occurred - Download request returned $RESPONSE_CODE"
    fi
fi
