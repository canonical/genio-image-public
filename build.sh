#!/bin/bash
#
# Copyright (C) 2025, Canonical, All Rights Reserved.
#

set -e

function usage()
{
  echo "$@" >&2

  cat >&2 <<EOF

USAGE: $0 <server|desktop> [ufs]

Where:
 - SERVER|DESKTOP chooses the server/desktop variant.
 - The optional UFS argument specifies to build a UFS image for the
   G1200 instead of a regular eMMC image.

EOF

  exit 1
}

variant="${1:-}"
storagetype="${2:-emmc}"

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  usage "Incorrect number of arguments supplied."
fi

if [ "$(which img2simg >/dev/null)" ] ; then
  cat >&2 <<EOF
The img2simg tool is not installed. It can be added by installing the
android-sdk-libsparse-utils package.
EOF
  exit 1
fi

case "$variant" in
  "server"|"desktop")
    echo "Building for $variant..."
    ;;
  *)
    usage "Variant '$variant' is not valid."
    ;;
esac

case "$storagetype" in
  "emmc")
    sectorsize=512
    ;;
  "ufs")
    sectorsize=4096
    ;;
  *)
    usage "Storage type '$2' is not valid."
    ;;
esac

outdir=$(mktemp -d -p "$PWD" "out.ubuntu-$variant.XXXXXX")

echo "Building $storagetype image with $sectorsize byte sectors."
echo "  - Output directory: ${outdir}"

sudo ubuntu-image -O "$outdir" --sector-size=$sectorsize classic "ubuntu-$variant-baoshan.yaml"
sudo chown -R "$(id -u):$(id -g)" "$outdir"
img2simg "$outdir/ubuntu-$variant.img" "$outdir/ubuntu.img"
rm -f "$outdir/ubuntu-$variant.img"

