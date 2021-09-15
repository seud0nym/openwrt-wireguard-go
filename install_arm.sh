!#/bin/sh

echo "Checking CPU..."
if ! uname -m | grep -qE '^armv[5678]'; then
    echo "Sorry - Pre-built releases only exist for ARM processors (armv5, armv6, and armv7)"
    exit 2;;
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
curl -kL https://github.com/seud0nym/openwrt-wireguard-go/releases/latest/download/openwrt-wireguard-go_${ARCH}.tgz | tar -xzvf - -C /
