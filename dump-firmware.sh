#!/bin/bash
set -ex
if [[ "$#" -lt 2 ]]; then
    echo "Incorrect parameters" >&2
    exit 1
fi
filename="$1"
firmware="$2"
sector_size="${3:-512}"

if [ -z "$filename" ] || ! [ -f "$filename" ]; then
    echo "$filename does not exists" >&2
    exit 1
fi

lodev=$(losetup --find --show --partscan --read-only --sector-size "$sector_size" "$filename")
if [ -z "$lodev" ]; then
    exit 1
fi
partprobe "$lodev"
fwpart=$(blkid --match-token PARTLABEL="firmware" --output device --list-one ${lodev}*)
dd if=$fwpart of="$firmware" bs=4k
losetup --detach "$lodev"
