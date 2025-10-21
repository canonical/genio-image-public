#!/bin/bash
set -euo pipefail

WORKDIR="grub-install"
IMAGE_FILE="$1.img"

cleanup() {
    echo "--> Running cleanup..."
    if mountpoint -q "$WORKDIR/mntimg/sys" 2>/dev/null; then sudo umount "$WORKDIR/mntimg/sys"; fi
    if mountpoint -q "$WORKDIR/mntimg/proc" 2>/dev/null; then sudo umount "$WORKDIR/mntimg/proc"; fi
    if mountpoint -q "$WORKDIR/mntimg/dev" 2>/dev/null; then sudo umount "$WORKDIR/mntimg/dev"; fi
    
    if mountpoint -q "$WORKDIR/mntimg/boot/efi" 2>/dev/null; then
        sudo umount "$WORKDIR/mntimg/boot/efi"
    fi
    if mountpoint -q "$WORKDIR/mntimg" 2>/dev/null; then
        sudo umount "$WORKDIR/mntimg"
    fi
    
    if [ -n "${lodev:-}" ] && [ -b "$lodev" ]; then
        sudo losetup -d "$lodev"
    fi
    
    sudo rm -rf "$WORKDIR"
}
trap cleanup EXIT INT TERM

if [ ! -f "$IMAGE_FILE" ]; then
    echo "Image file not found: $IMAGE_FILE"
    exit 1
fi

mkdir -p "$WORKDIR/mntimg"
lodev=""

SECTOR_SIZE="${SECTOR_SIZE:-512}"
echo "--> Using sector size: $SECTOR_SIZE bytes (from environment or default)"

lodev=$(sudo losetup --sector-size "$SECTOR_SIZE" -f -P --show "$IMAGE_FILE")
if [ -z "$lodev" ]; then
    echo "::error::Failed to get a loop device."
    exit 1
fi

echo "Loop device created: $lodev"

sudo udevadm settle

sudo lsblk -p -o NAME,PARTLABEL,LABEL,FSTYPE,SIZE "$lodev"

echo "--> Finding partitions by label..."
BOOT_PART=$(sudo lsblk -l -p -o NAME,PARTLABEL -n "$lodev" | awk '$2=="ubuntu-boot" { print $1 }')
ROOT_PART=$(sudo lsblk -l -p -o NAME,PARTLABEL -n "$lodev" | awk '$2=="writable" { print $1 }')

if [ -z "$BOOT_PART" ]; then
    echo "::error::Could not find boot partition with label 'ubuntu-boot'"
    exit 1
fi

if [ -z "$ROOT_PART" ]; then
    echo "::error::Could not find root partition with label 'writable'"
    exit 1
fi

echo "    Boot partition found: $BOOT_PART"
echo "    Root partition found: $ROOT_PART"

sudo mount "$ROOT_PART" "$WORKDIR/mntimg"
echo "Root partition mounted."

sudo mkdir -p "$WORKDIR/mntimg/boot/efi"

sudo mount "$BOOT_PART" "$WORKDIR/mntimg/boot/efi"
echo "Partitions mounted successfully."

echo "--> Setting up chroot environment..."
sudo mount --bind /dev "$WORKDIR/mntimg/dev"
sudo mount --bind /proc "$WORKDIR/mntimg/proc"
sudo mount --bind /sys "$WORKDIR/mntimg/sys"

echo "--> Running grub-install inside chroot..."
sudo chroot "$WORKDIR/mntimg" grub-install \
    --target=arm64-efi \
    --efi-directory=/boot/efi \
    --boot-directory=/boot \
    --uefi-secure-boot \
    --no-nvram

echo "grub-install ran successfully."
