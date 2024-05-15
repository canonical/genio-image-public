#!/bin/bash
set -e
if [[ "$#" -ne 2 ]]; then
    echo "Incorrect parameters" >&2
    exit 1
fi
filename="$1"
firmware="$2"

if [ -z "$filename" ] || ! [ -f "$filename" ]; then
    echo "$filename does not exists" >&2
    exit 1
fi

lodev=$(losetup --find --show --partscan --read-only "$filename")
if [ -z "$lodev" ]; then
    return 1
fi
fwpart=$(blkid ${lodev}* | grep -F 'PARTLABEL="firmware"' | cut -d: -f1)
dd if=$fwpart of="$firmware" bs=4k
losetup -d "$lodev"
