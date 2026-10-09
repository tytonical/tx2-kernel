#!/bin/bash
# Build the TX2 NX ANPR kernel: tegra_defconfig + configs/tx2nx-anpr.config.
# Usage: scripts/build-kernel.sh <outdir>
# Needs ARCH and CROSS_COMPILE in the environment (source ~/tyton-1c/env.sh).
set -euo pipefail

TOP=$(cd "$(dirname "$0")/.." && pwd)
KSRC=$TOP/kernel/kernel-4.9
FRAG=$TOP/configs/tx2nx-anpr.config
OUT=$(realpath -m "${1:?usage: $0 <outdir>}")
DTS=_ddot_/_ddot_/_ddot_/_ddot_/_ddot_/_ddot_/hardware/nvidia/platform/t18x/lanai/kernel-dts
DTBS="tegra186-p3636-0001-p3509-0000-a01.dtb tegra186-p3636-0002-p3509-0000-a01.dtb"
# Objects that must come out of the build. Kconfig can report a driver as =y
# while a Makefile gate elsewhere silently skips it (EQOS behind
# NET_VENDOR_NVIDIA/PCI), so check the build output, not just .config.
REQUIRED_OBJS="
	drivers/net/ethernet/nvidia/eqos/built-in.o
	drivers/net/phy/libphy.o
	drivers/net/phy/realtek.o
	drivers/of/of_mdio.o
	drivers/extcon/extcon-core.o
	drivers/tty/serial/8250/8250_of.o
	drivers/tty/serial/serial-tegra.o
	drivers/gpu/nvgpu/nvgpu.ko
	drivers/video/tegra/host/built-in.o
	drivers/video/tegra/nvmap/built-in.o
	drivers/media/platform/tegra/camera/vi/built-in.o
	drivers/platform/tegra/rtcpu/built-in.o
	drivers/usb/host/xhci-tegra.o
	drivers/phy/tegra/built-in.o
	drivers/watchdog/tegra_wdt_t18x.o
	drivers/md/dm-verity.o
	drivers/i2c/busses/i2c-tegra.o
	drivers/i2c/i2c-dev.o
	net/ipv4/netfilter/ip_tables.ko
	net/ipv4/netfilter/iptable_filter.ko
	net/ipv6/netfilter/ip6table_filter.ko
	net/netfilter/xt_conntrack.ko
	drivers/mmc/host/sdhci-tegra.o
	drivers/thermal/userspace_alert.ko
	drivers/block/zram/zram.ko
	fs/ext4/built-in.o
	drivers/mfd/max77620.o
	drivers/regulator/max77620-regulator.o
	drivers/devfreq/devfreq.o
	drivers/ptp/built-in.o
	drivers/leds/leds-gpio.o
"

mkdir -p "$OUT"
# Merge onto the defconfig file, not an expanded .config: an expanded config
# carries library symbols (CRC7, etc.) that were only selected by drivers the
# fragment removes, and olddefconfig would keep them as explicit choices.
(cd "$KSRC" && ARCH=$ARCH scripts/kconfig/merge_config.sh -m -O "$OUT" \
	arch/arm64/configs/tegra_defconfig "$FRAG" >/dev/null)
make -C "$KSRC" O="$OUT" olddefconfig >/dev/null

# Fail if Kconfig overrode any fragment setting (dependency selected it back on,
# or a symbol name is wrong and silently ignored).
bad=0
while read -r line; do
	if [[ $line =~ ^#\ (CONFIG_[A-Za-z0-9_]+)\ is\ not\ set$ ]]; then
		sym=${BASH_REMATCH[1]}
		if grep -q "^$sym=[ym]" "$OUT/.config"; then
			echo "fragment: $sym still enabled" >&2; bad=1
		fi
	elif [[ $line =~ ^(CONFIG_[A-Za-z0-9_]+)=(.*)$ ]]; then
		if ! grep -qx "$line" "$OUT/.config"; then
			echo "fragment: ${BASH_REMATCH[1]} not set to ${BASH_REMATCH[2]}" >&2; bad=1
		fi
	fi
done < "$FRAG"
[ $bad -eq 0 ] || exit 1

make -C "$KSRC" O="$OUT" -j"$(nproc)" Image modules
for d in $DTBS; do
	make -C "$KSRC" O="$OUT" "$DTS/$d"
done

for o in $REQUIRED_OBJS; do
	if [ ! -e "$OUT/$o" ]; then
		echo "required object not built: $o" >&2; bad=1
	fi
done
[ $bad -eq 0 ] || exit 1
