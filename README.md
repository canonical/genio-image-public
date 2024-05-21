# genio-image

[![Build Ubuntu (Genio)](https://github.com/canonical/genio-image/actions/workflows/build.yml/badge.svg)](https://github.com/canonical/genio-image/actions/workflows/build.yml)

# Building Images


## Prerequisite
```
$ snap install ubuntu-image
```

## Build emmc image for G510/G700/G1200
```
# To build desktop image
$ sudo ubuntu-image classic ubuntu-desktop-baoshan.yaml

# To build server image
$ sudo ubuntu-image classic ubuntu-server-baoshan.yaml
```
And you will find your images in 
## Build UFS image for G1200
```
# To build desktop image
$ sudo ubuntu-image classic --sector-size=4096 ubuntu-desktop-baoshan.yaml

# To build server image
$ sudo ubuntu-image classic --sector-size=4096 ubuntu-server-baoshan.yaml
```

# Dump firmware
```
# ./dump-firmware.sh "<raw image>" "<output firmware.vfat>" "[sector size]"
./dump-firmware.sh out/ubuntu.img firmware.vfat 4096
```
