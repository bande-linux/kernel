#!/bin/bash
# qemu-boot.sh <out dir>: run in debian:testing. Boots the built kernel in QEMU's arm64 virt
# machine (TCG, 16k pages) through UEFI with a one-line busybox initramfs, and passes when it
# reaches userspace. It catches kernels that don't boot; the Mac's own hardware isn't tested.
set -euo pipefail
out=$(realpath "$1")
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq --no-install-recommends qemu-system-arm qemu-efi-aarch64 busybox-static cpio > /dev/null
work=$(mktemp -d)
for deb in "$out"/linux-binary-*.deb; do dpkg-deb -x "$deb" "$work/x"; done
kernel=$(find "$work/x" -name 'vmlinuz*' | head -1)
[ -n "$kernel" ] || { echo "qemu-boot: no vmlinuz in the packages" >&2; exit 1; }

mkdir -p "$work/initrd/bin" "$work/initrd/proc"
cp /bin/busybox "$work/initrd/bin/"
cat > "$work/initrd/init" <<'EOF'
#!/bin/busybox sh
/bin/busybox mount -t proc proc /proc
echo "BANDE-BOOT-OK $(/bin/busybox uname -r) pagesize=$(/bin/busybox getconf PAGESIZE 2>/dev/null)"
/bin/busybox poweroff -f
EOF
chmod +x "$work/initrd/init"
(cd "$work/initrd" && find . | cpio -o -H newc --quiet | gzip) > "$work/initrd.gz"

timeout 1200 qemu-system-aarch64 -machine virt -cpu max -smp 2 -m 2048 -nographic -no-reboot \
    -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
    -kernel "$kernel" -initrd "$work/initrd.gz" -append "console=ttyAMA0 panic=-1" \
    < /dev/null 2>&1 | tee "$work/serial.log" | grep --line-buffered -E 'BANDE-BOOT-OK|Kernel panic|Linux version' || true
grep -q BANDE-BOOT-OK "$work/serial.log" || { echo "qemu-boot: the kernel didn't reach userspace" >&2; tail -40 "$work/serial.log" >&2; exit 1; }
echo "qemu-boot: passed"
