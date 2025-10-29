# Introuduction

This tutorial will guide the reader through the steps required to create a
bespoke Ubuntu Core image, customised with a selection of snaps, and then
install it on a Mediatek Genio EVK.

# Requirements

In addition to having a basic understanding of Linux and running commands from
the terminal, this tutorial has the following requirements.

For the host system used to build the image:  

- [Ubuntu 24.04 LTS](https://releases.ubuntu.com/24.04/) or later installed
- Internet connectivity
- 10GB of free storage space
- snapcraft (See [here](#install-snapcraft))
- ubuntu-image (See [here](#install-ubuntu-image))
- genio-tools (See [here](#install-genio-tools))
- img2simg (See [here](#install-android-sdk-libsparse-utils))

The target device:  

- Genio (350, 510, 700, 1200) EVK
- 12V power supply for the target device
- USB download cable for target device
- Optional USB console cable (See [here](#optional-console-cable))
- Ethernet network connectivity

## Optional Console Cable

The console cable is optional; it is not required to have a console cable
for flashing the device with `genio-image`, but it helps to debug any
potential boot issues when the console is visible.

Genio EVK devices will present a standard USB/serial port when the console
port is connected to a host by USB. This will usually be `/dev/ttyUSB0` or
similar. The default serial rate is 926100/8N1.

Any serial tool (`tio`, `minicom`, etc) can be used to access the console. The
authors recommend `tio`, which can be installed either using *snap* or *apt*:

```bash
$ sudo snap install tio # for snap
$ sudo apt install tio  # for apt
```

To access the console using `tio`, a command similar to below will be used:

```bash
$ tio -b 926100 /dev/ttyUSB0
```

To exit `tio` press `Ctrl-T` then press `q`.

The serial terminal can remain connected during flashing; this will have no
impact on the flash operation.

# Definitions

- model

   A JSON file which describes the Ubuntu Core image properties and
   the default snaps to load into the image

- model-assertion

   The JSON model is signed with a private key to produce a
   *model-assertion* file (extension: `.model`). A signed model assertion
   guarantees that only the key holder can publish an updated model assertion
   or image on snapcraft and to devices installed from their images.

# Step 1: Ubuntu One Developer Identifier

A [Ubuntu One account](https://snapcraft.io/account) with an associated SSH
public key is required to produce the Ubuntu Core image. Each Ubuntu One
account has a unique *developer identifier* associated with it. Ubuntu Core
images are built and associated with that *developer identifier*.

The following steps will assist in retrieving the *developer identifier* and
storing it for later use.

## Create A Ubuntu One Account

If you already have an account and it has a SSH public key registered then
feel free to skip this step.

Follow [Use Ubuntu One for
SSH](https://documentation.ubuntu.com/core/how-to-guides/manage-ubuntu-core/use-ubuntu-one-ssh)
for detailed instructions on how to create an account and register an SSH key.

## Accept Snapcraft Terms And Conditions

Navigate to [snapcraft.io](https://snapcraft.io/login) and log in. It is not
possible to use *snapcraft* without first accepting the _Terms And
Conditions_. Read and accept these before continuing.

## Install Snapcraft

Snapcraft can be installed by running:

```bash
$ sudo snap install snapcraft --classic
```

**NOTE:** Snapcraft requires classic confinement in order to have the complex
access it needs to craft snaps. 

## Snapcraft Credentials

The developer identifier can be retrieved with the
[`snapcraft`](https://snapcraft.io/docs/snapcraft-overview) command. The
`snapcraft` tool is also used to build and publish snaps.

The commands below will use `snapcraft` to export *Snapcraft Store* login
authentication credentials to a file and then load them into an environment
variable.

```bash
# Save the credentials to a file for later use.
$ snapcraft export-login credentials.txt

# Load the credentials into the environment.
$ export SNAPCRAFT_STORE_CREDENTIALS=$(cat credentials.txt)
```

**NOTE:** If the *snapcraft* command has not been associated with an account
then a login prompt will appear. Enter the email address and credentials used
for the *Ubuntu One* account and `snapcraft` will log into that account.

## Retrieve Your Developer Account ID

With authentication configured, the `snapcraft whoami` command will now
display the developer identifier for the associated account:

```bash
$ snapcraft whoami
email: <email-address>
username: <username>
id: xSfWKGdLoQBoQx88
permissions: package_access, package_manage, package_metrics, 
package_push, package_register, package_release, package_update
channels: no restrictions
expires: 2024-04-17T10:25:13.675Z 
```

In the output above, the example *id* is `xSfWKGdLoQBoQx88`. This document
will use that sample ID in worked examples; remember to substitute a real
ID where necessary.

# Step 2: Create The Model Assertion

At the heart of custom Ubuntu Core image creation is the _model assertion_. An
assertion is a signed recipe which describes the components that make up a
complete image. An assertion is produced from a JSON model by signing it with
a key bound to the publisher's *Ubuntu One* account.

The model contains:

* Identification information, such as the developer-id and model name.
* Which [essential snaps](
  https://documentation.ubuntu.com/core/explanation/core-elements/snaps-in-ubuntu-core)
  make up the device system.
* Other required or optional snaps that implement the device application
  functionality.

See below for details on how to download and modify a model file and to
customize the selection of snaps.

## Download A Model File

The quickest way to create a new model assertion is to edit a model that
already exists. Reference models for every supported Ubuntu Core device can be
found in the [canonical/models](https://github.com/canonical/models) GitHub
repository. Specifically, a _genio_ model can be found in the
[devices/mediatek/genio](https://github.com/canonical/models/tree/master/devices/mediatek/genio)
subdirectory.

This tutorial will modify the reference model for a [Mediatek Genio
EVK](https://raw.githubusercontent.com/canonical/models/refs/heads/master/devices/mediatek/genio/ubuntu-core-22-genio-arm64.json).

Download and save the file locally with the following `wget` command. The
example command below will call the file `my-model.json`.

```bash
$ wget -O my-model.json \
  https://raw.githubusercontent.com/canonical/models/refs/heads/master/\
devices/mediatek/genio/ubuntu-core-22-genio-arm64.json
```

## Edit The Model File

The downloaded `my-model.json` file can be edited in any text editor.

```bash
$ gnome-text-editor my-model.json
```

The following fields in `my-model.json` *must* be changed:

### Identifiers: "authority-id" and "brand-id"

```
"authority-id": "canonical",
"brand-id": "canonical",
```

These properties define the authority responsible for the image. Change both
instances of the string "canonical" to the developer id previously retrieved
with the `snapcraft whoami` command.

Doing this will link the image to a *Ubuntu One* account and ensure that only
people logged into that account can push image updates to devices using the
model. 

### Timestamp

```
   "timestamp": "2025-08-19T11:18:21+00:00",
```

This needs to be provided at the end of the process; the tutorial will revisit
timestamps [later](#update-the-timestamp).

### Snaps

```json
    "snaps": [
      {
        "default-channel": "22/stable",
        "id": "7TAD6GcCXwugAvC6c96rEU6NxPrqhuD4",
        "name": "mediatek-genio",
        "type": "gadget"
      },
      {
        "default-channel": "22/stable",
        "id": "xFMGLRAkDsbHq5JyD7pilRTPRyDDDu28",
        "name": "mediatek-genio-kernel",
        "type": "kernel"
      },
      {
        "default-channel": "latest/stable",
        "id": "amcUKQILKXHHTlmSa7NMdnXSx02dNeeT",
        "name": "core22",
        "type": "base"
      },
      {
        "default-channel": "latest/stable",
        "id": "PMrrV4ml8uWuEUDBT8dSGnKUYbevVhc4",
        "name": "snapd",
        "type": "snapd"
      }
    ]
```

This section lists the snaps to be included in the image. *mediatek-genio*,
*mediatek-genio-kernel*, *core22* and *snapd* are the four snaps
required for a functioning Ubuntu Core image on Genio devices.

[*console-conf*](https://documentation.ubuntu.com/core/how-to-guides/image-creation/add-console-conf)
is the interactive setup utility that is used to configure network and the
default user when the device is first booted. Packages needed to run
*console-conf* are included in the *core22* snap. If building a *core24*
image then the following entry is also needed in the `snaps` section:

```json
      {
        "name": "console-conf",
        "type": "app",
        "default-channel": "24/stable",
        "id": "ASctKBEHzVt3f1pbZLoekCvcigRjtuqw"
      },
```

**NOTE:** Ubuntu Core 24 is not currently supported on Genio devices. When it
is, *console-conf* is not mandatory, but for the purposes of this tutorial
it is required to allow configuring the network and default user after
flashing a produced image to test it.

Additional snaps are included using the same schema, with each snap requiring
the following fields:

- `name`: simply the snap name.
- `type`: the [type of snap](
   https://documentation.ubuntu.com/core/explanation/core-elements/snaps-in-ubuntu-core.md#types-of-snap).
   This is `app` for standard application snaps.
- `default-channel`: the [channel](https://snapcraft.io/docs/channels) to
  install the snap from.
- `id`: a unique snap identifier associated with every published snap. This is
  `snap-id` in the output from `snap info <snap-name>`.

The `snap-id` for each snap can be found in the output of the `snap info
<snap-name>` command.

Snaps do not have dependencies, but they do require the presence of the [base
snap](https://snapcraft.io/docs/base-snaps) they were built on. The example
above includes the *core22* base snap.

### Complete Model Example

The full `my-model.json` file should now contain the following:

```json
{
  "type": "model",
  "authority-id": "xSfWKGdLoQBoQx88",
  "revision": "1",
  "series": "16",
  "brand-id": "xSfWKGdLoQBoQx88",
  "model": "mediatek-genio",
  "architecture": "arm64",
  "base": "core22",
  "grade": "signed",
  "timestamp": "2022-12-14T11:40:45+00:00",
  "snaps": [
    {
      "default-channel": "22/stable",
      "id": "7TAD6GcCXwugAvC6c96rEU6NxPrqhuD4",
      "name": "mediatek-genio",
      "type": "gadget"
    },
    {
      "default-channel": "22/stable",
      "id": "xFMGLRAkDsbHq5JyD7pilRTPRyDDDu28",
      "name": "mediatek-genio-kernel",
      "type": "kernel"
    },
    {
      "default-channel": "latest/stable",
      "id": "amcUKQILKXHHTlmSa7NMdnXSx02dNeeT",
      "name": "core22",
      "type": "base"
    },
    {
      "default-channel": "latest/stable",
      "id": "PMrrV4ml8uWuEUDBT8dSGnKUYbevVhc4",
      "name": "snapd",
      "type": "snapd"
    }
  ]
}
```

This is the minimum viable model file required to create a Ubuntu Core 22
image for a Genio device.

# Step 3: Sign The Model Assertion

After a model has been created or modified, it must be signed with a GPG key
to become a _model assertion_. This ensures the model cannot be altered
without the key and also links the created image to both the signed version of
the model and the Ubuntu One account belonging to the *developer identifier*
set in the JSON model.

## Create A Key

First make sure there are no keys already associated with the *Snapocraft*
account by running the `snapcraft list-keys` command; if a key exists it can
be resued, or a new one created:

```bash
$ snapcraft list-keys
No keys have been registered. 
See 'snapcraft register-key --help' to register a key.
```

Now use `snapcraft` to create a key called *my-model-key* (the name is
arbitrary):

```bash
$ snapcraft create-key my-model-key
Passphrase: <passphrase>
Confirm passphrase: <passphrase>
```

**WARNING:** There are no requirements enforced on the passphrase. Choose a
sufficiently strong passhprase that is not reused elsewhere for maximum
security in a production environment.

**WARNING:** The produced `my-model-key` is required to sign the model and
produce a model assertion in the future. The private key file should be stored
and backed up securely when the security of the resulting image and the
ability to push updates to it is important.

**TIP:** Rather than creating a key for every device, the same key is typically
used across all models or model families.

## Register The Key

The new key must be uploaded and registered with a *Ubuntu One* account. The
`snapcraft register-key` command will assist with this:

```bash
$ snapcraft register-key my-model-key
Enter your Ubuntu One e-mail address and password.
If you do not have an Ubuntu One account,
you can create one at https://snapcraft.io/account
Email: <Ubuntu-SSO-email-address>
Password: <Ubuntu-SSO-password>

Registering key ...
Done. The key "my-model-key" (<key fingerprint>) may be used 
to sign your assertions.
```

Re-authentication is *required*, regardless of whether `snapcraft` had
previously authenticated or not. This is a security measure. The passphrase
for the key is also required to unlock the key prior to registration,

When the process is complete, the `snapcraft list-keys` command will now list
the registered key:

```bash
$ snapcraft list-keys
    Name          SHA3-384 fingerprint
*   my-model-key  <key fingerprint>
```

## Update The Timestamp

The timestamp in the model assertion must be set to a time and date _after_
the creation of our key. Edit `my-model.json` to update the timestamp with the
current time.

```
    "timestamp": "2025-08-14T08:03:54+00:00",
```

This is a UTC-formatted time and date value which denotes the assertion's
creation time. It needs to be replaced with the current time and  date, which
can be generated with the following command:

```bash
$ date -Iseconds --utc
2025-08-19T11:18:21+00:00
```

## Sign The Model

A model assertion is created by feeding the JSON file into the `snap sign`
command with the recently-created key name and capturing the output in the
corresponding model file:

```bash
$ snap sign -k my-model-key my-model.json > my-model.model
```

The key passphrase is again required to unlock the private signing key.

The resultant `my-model.model` file contains the signed model assertion and
can now be used to build the image.

If a _gpg: signing failed_ error is observed while signing the model assertion
from a non-desktop session, such as over SSH, run `export GPG_TTY=$(tty)`
first.

# Step 4: Build the image

The [ubuntu-image](https://github.com/canonical/ubuntu-image) tool is used to
produce a bootable image from a signed [model
assertion](https://documentation.ubuntu.com/core/tutorials/build-your-first-image/create-a-model).

## Install ubuntu-image

First, install the `ubuntu-image` command from its snap:

```bash
$ sudo snap install ubuntu-image --classic --edge
```

## Build The Ubuntu Core Image

It is finally time to turn all the hard work above into a Ubuntu Core image
that can be flashed onto a Genio device.

The `ubuntu-image` command requires three arguments;

- `snap`
   To request a snap-based Ubuntu Core image
- `--allow-snapd-kernel-mismatch`
   To ignore a difference in the versions of snapd
- `<filename>`
   The filename of a signed signed model assertion describing the
   contents of the produced image (`my-model.model` in this case)

```bash
$ ubuntu-image snap --allow-snapd-kernel-mismatch my-model.model 
[0] prepare_image
WARNING: proceeding to download snaps ignoring validations, 
this default will change in the future. 
For now use --validation=enforce for validations to be taken 
into account, pass instead --validation=ignore to preserve 
current behavior going forward
WARNING: the kernel for the specified UC20+ model does not 
carry assertion max formats information, assuming possibly 
incorrectly the kernel revision can use the same formats 
as snapd
WARNING: snapd 2.68+ is not compatible with a kernel 
containing snapd prior to 2.68
[1] load_gadget_yaml
[2] set_artifact_names
[3] populate_rootfs_contents
[4] generate_disk_info
[5] calculate_rootfs_size
[6] populate_bootfs_contents
[7] populate_prepare_partitions
[8] make_disk
[9] generate_snap_manifest
Build successful
```

The warnings can safely be ignored; the `--allow-snapd-kernel-mismatch`
parameter is what allows them to be emitted at warning level instead of
failing outright.

This process usually completes in a few minutes, depending on the speed of the
Internet connection. A file called `pc.img` will be produced in the current
directory. This is the *Ubuntu Core* bootable image.

TIP: The *console-conf* user-interface that configures the network and system user
when a device first boots has migrated to an optional snap in Ubuntu Core 24
and later. This is covered in [Create a model
assertion](https://documentation.ubuntu.com/core/tutorials/build-your-first-image/create-a-model),
but `ubuntu-image` can add `console-conf` at image build time with an
additional `--snap console-conf` argument. For more details on these changes,
see [console-conf for device
onboarding](https://documentation.ubuntu.com/core/how-to-guides/image-creation/add-console-conf).

# Step 5: Flash The Image

## Install genio-tools

The [*genio-tools*](https://snapcraft.io/genio-tools) package is requied to
flash MediaTek genio devices. It can be installed with:

```bash
$ sudo snap install genio-tools --devmode
```

Installing the snap with strict confinement prevents `genio-board` from
accessing the device nodes it needs to. This will not prevent flashing the
device, but it does prevent automated flashing and rebooting of G350, G510 and
G700 devices. Installing the *genio-tools* snap with `--devmode` confinement
allows the `genio-board` command to function if it is needed.

Snap confinement means that additional post-installation steps are required.
The snapcraft [*genio-tools*](https://snapcraft.io/genio-tools) page
explains the steps. The command below will perform all the post-install
configuration:

```bash
$ eval "$(snap run genio-tools.udev-script)"
```

## Install android-sdk-libsparse-utils

The Ubuntu images produced by the `ubuntu-image` command are full images which
must be converted to sparse images for `genio-flash` to work with. Install the
Android SDK utils to get access to `img2simg`:

```bash
$ sudo apt install android-sdk-libsparse-utils
```

## Download Boot Firmware

Genio EVK boards require additional boot firmware in order to start the Ubuntu
image.

Navigate to the Ubuntu firmware
[download](https://ubuntu.com/download/mediatek-genio) page for Genio and
select the *EVK boot firmware* download to match your EVK board. The boot
firmware is tailored to the specific EVK model, and the correct one must be
provided.

For the purpose of this tutorial, it is assumed that the boot firmware is
`ubuntu-boot-firmware-genio-1200-evk-v24.1-ubuntu1.tar.gz`. Adapt these
instructions for different boards if necessary.

```bash
$ wget https://download.mediatek.com/iot/download/ubuntu/boot-firmware/v24.1/\
ubuntu-boot-firmware-genio-1200-evk-v24.1-ubuntu1.tar.gz
```

## Unpack Boot Firmware

```bash
$ BOOT_FW_DIR="g1200-bootfw"
$ BOOT_FW_TAR="ubuntu-boot-firmware-genio-1200-xvk-v24.1-ubuntu1.tar.gz"
$ mkdir "${BOOT_FW_DIR}"
$ tar --strip-components=1 -C "${BOOT_FW_DIR} -xvf "${BOOT_FW_TAR}"
```

## Convert the image to a sparse image.

The produced `pc.img` file is a full image, but the `genio-flash` tool
requires a sparse image. The `img2simg` tool will do this.

```
$ img2simg pc.img "${BOOT_FW_DIR}/ubuntu.img" && \
    rm -f pc.img
```

The `genio-flash` tool requires the disk image to appear in the same directory
as the [unpacked](#unpack-boot-fiwmare) boot firmware. The command above will
create the `ubuntu.img` file co-located with the boot firmware files, laid out
as `genio-flash` requires.

If this step is omitted then the user will receive a strange error about
sector sizes being incorrect during the flash operation.

## Fetch genio-flash Metadata

A metadata file is also required to instruct `genio-flash` how to actually
flash the image onto the device. These instructions have built the eMMC image,
so the eMMC control file is required. It can be downloaded from the
[canonical/genio-image](https://www.github.com/canonical/genio-image) GitHub
repository:

```bash
$ wget -O ${BOOT_FW_DIR}/ubuntu.json \
  https://raw.githubusercontent.com/canonical/genio-image/refs/heads/main/metadata/noble/emmc/ubuntu.json
```

Note how the metadata file is tied to the Ubuntu release series
(Noble, in this case). If building a different series the JSON file for that
series will be required.

If building a UFS image for a G1200 then the UFS *ubuntu.json* file is
required from the same repository.

## Flash The Image

It is time to actually flash the image on the device. Ensure that the
programming cable is connected to the device and the host. Note that G1200
devices cannot auto-flash and require user intervention to enter download
mode.

The MediaTek [Getting
Started](https://mediatek.gitlab.io/genio/doc/ubuntu/get-started.html) page
contains detailed instructions for flashing the boards, including which
buttons to press to enable download mode.

The [Flash the system
image](https://documentation.ubuntu.com/core/how-to-guides/deploy-an-image/install-on-mediatek/index.html#flash-the-system-image)
section of the Ubuntu Core for Genio documentation also describes the flashing
process.

Change into the directory containing the image and boot firmware then flash
it:

```bash
$ cd "${BOOT_FW_DIR}"
$ genio-flash -e ethaddr="02:00:00:12:34:56"
```

**NOTE:** The ethaddr (MAC address) `02:00:00:12:34:56` is just an example. Be
sure to select a valid MAC address that is not already in use on the local
network.

# Step 6: Boot the image

At the completion of [the previous step](#flash-the-image), the
Genio board will automatically reboot. Ubuntu Core will start.

Follow the instructions on the [Boot Ubuntu Core For The First
Time](https://documentation.ubuntu.com/core/how-to-guides/deploy-an-image/install-on-mediatek/index.html#boot-ubuntu-core-for-the-first-time)
page to configure the device and begin using it.

