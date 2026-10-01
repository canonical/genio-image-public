#!/bin/bash
#
# Copyright (C) 2025, Canonical, All Rights Reserved.
#

set -e

function usage()
{
  echo "$@" >&2

  cat >&2 <<EOF

USAGE: $0 <server|desktop> <noble|resolute|devel> [ufs]

Where:
 - SERVER|DESKTOP chooses the server/desktop variant.
 - NOBLE|RESOLUTE|DEVEL chooses the Ubuntu release.
 - The optional UFS argument specifies to build a UFS image for the
   G1200 instead of a regular eMMC image.

EOF

  exit 1
}

variant="${1:-}"
release="${2:-}"
storagetype="${3:-emmc}"

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
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

case "$release" in
  "noble")
    image_definition="classic/noble/ubuntu-$variant-baoshan.yaml"
    ;;
  "resolute"|"devel")
    image_definition="classic/$release/ubuntu-$variant-generic.yaml"
    ;;
  *)
    usage "Release '$release' is not valid."
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
    usage "Storage type '$storagetype' is not valid."
    ;;
esac

outdir=$(mktemp -d -p "$PWD" "out.ubuntu-$variant.XXXXXX")

echo "Building $storagetype image with $sectorsize byte sectors."
echo "  - Output directory: ${outdir}"

sudo ubuntu-image -O "$outdir" --sector-size=$sectorsize classic "$image_definition"
sudo chown -R "$(id -u):$(id -g)" "$outdir"
img2simg "$outdir/ubuntu-$variant.img" "$outdir/ubuntu.img"
rm -f "$outdir/ubuntu-$variant.img"

