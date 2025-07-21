#!/bin/bash
set -euo pipefail

if ! command -v yq &> /dev/null; then
    echo "yq could not be found, skipping the hook..."
    exit 0
fi

WORKDIR="add-snaps-to-manifest-work"
IMAGE_FILE="$1.img"
MANIFEST_FILE="$1.manifest"

cleanup() {
    echo "--> Running cleanup..."
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
ROOT_PART=$(sudo lsblk -l -p -o NAME,PARTLABEL -n "$lodev" | awk '$2=="writable" { print $1 }')

if [ -z "$ROOT_PART" ]; then
    echo "::error::Could not find root partition with label 'writable'"
    exit 1
fi

echo "    Root partition found: $ROOT_PART"

sudo mount "$ROOT_PART" "$WORKDIR/mntimg"
echo "Partitions mounted successfully."

YAMLPATH="$WORKDIR/mntimg/var/lib/snapd/seed/seed.yaml"
if [ -f "$YAMLPATH" ]; then
    sudo yq e '.snaps[] | ["snap:" + .name, .channel, (((.file | split("_"))[1] | split("."))[0])] | @tsv' "$YAMLPATH" | sudo tee -a "$MANIFEST_FILE"
else
    echo "::warning::seed.yaml not found at $YAMLPATH"
fi

echo "Updated $MANIFEST_FILE successfully."
