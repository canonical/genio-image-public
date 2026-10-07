# mediatek-genio-npu

MediaTek Genio NPU runtime as a Snap package.

This Snap provides the runtime libraries, firmware assets, and wrapper launcher required to run NPU-accelerated AI workloads on supported MediaTek Genio platforms.

## Upstream Source

This path was forked from:

  git://git.launchpad.net/~baoshan-team/baoshan/+git/mediatek-genio-npu

## What this Snap provides

- NPU runtime libraries for multiple NeuroPilot generations.
- Firmware and hardware-specific configuration for supported Genio SoCs.
- A wrapper binary that auto-detects platform model and exports required runtime environment variables.
- A `content` slot (`mediatek-npu-2404`) that other snaps can consume.

## Supported platforms

This package currently includes runtime data for:

- MediaTek Genio 510 / 700 (`mt8188`)
- MediaTek Genio 520 / 720 (`mt8189`)
- MediaTek Genio 1200 (`mt8195`)

## How to consume this Snap from your app Snap

Use this pattern when your own Snap needs MediaTek Genio NPU runtime support.

### 1) Add required plugs and app wiring in your `snapcraft.yaml`

```yaml
name: your-app
base: core24

...

plugs:
  mediatek-npu-2404:
    interface: content
    content: mediatek-npu-2404
    target: $SNAP/mediatek-npu-2404
  mediatek-accel:
    interface: mediatek-accel
    units: [apu]
  hardware-observe:
    interface: hardware-observe

apps:
  mediatek-genio-llm-demo:
    command-chain:
      - bin/launcher
    command: path-to-your-application
    plugs:
      # Shared runtime libraries for NPU inference
      - mediatek-npu-2404
      # Access to the NPU accelerator device
      - mediatek-accel
      # Required by launcher to detect NPU hardware model
      - hardware-observe
      # Grants access to /dev/dma_heap/system required by NPU driver
      - opengl

parts:
  your-application-part:
    ...

  launcher:
    plugin: dump
    source: .
    organize:
      launcher: bin/launcher
```

### 2) Add a launcher script in your app Snap

Create `launcher` (used by `command-chain`) and verify required interfaces before running your application.

```bash
#!/bin/sh

if ! snapctl is-connected mediatek-npu-2404; then
  echo "ERROR: the mediatek-npu-2404 interface is not connected."
  echo "  Please install and connect the mediatek-genio-npu snap."
  echo ""
  echo "Run:"
  echo "  sudo snap install mediatek-genio-npu"
  echo "  sudo snap connect ${SNAP_INSTANCE_NAME}:mediatek-npu-2404 mediatek-genio-npu:mediatek-npu-2404"
  exit 1
fi

if ! snapctl is-connected mediatek-accel; then
  echo "ERROR: the mediatek-accel interface is not connected."
  echo "  This interface provides access to the MediaTek Genio NPU accelerator."
  echo ""
  echo "Run:"
  echo "  sudo snap connect ${SNAP_INSTANCE_NAME}:mediatek-accel"
  exit 1
fi

if ! snapctl is-connected opengl; then
  echo "ERROR: the opengl interface is not connected."
  echo "  This interface grants access to /dev/dma_heap/system required by the NPU driver."
  echo ""
  echo "Run:"
  echo "  sudo snap connect ${SNAP_INSTANCE_NAME}:opengl"
  exit 1
fi

if ! snapctl is-connected hardware-observe; then
  echo "ERROR: the hardware-observe interface is not connected."
  echo "  This interface is required to detect the NPU hardware model."
  echo ""
  echo "Run:"
  echo "  sudo snap connect ${SNAP_INSTANCE_NAME}:hardware-observe"
  exit 1
fi

exec "${SNAP}/mediatek-npu-2404/bin/mediatek-genio-npu-wrapper" "$@"
```

## Runtime behavior

The included wrapper detects the underlying Genio platform and sets these environment variables before starting your app:

- `NEUROPILOT_NHW_PATH`
- `LD_LIBRARY_PATH`
- `PATH`

This allows a single app Snap to run across multiple supported Genio models without manually selecting runtime paths.

## Known limitations

- `mllm_llava` (NP_VER=8, bundled since `mtk-neuropilot-prebuilts` commit `98ce26b7`) fails to
  start with `error while loading shared libraries: libopencv_imgcodecs.so.409: cannot open
  shared object file`. The binary links against OpenCV 4.9 (`.so.409`), but
  `mtk-neuropilot-prebuilts` does not bundle any OpenCV libraries, and Ubuntu Noble's apt
  archive only provides OpenCV 4.6.0 (`libopencv-core406t64`, a different, incompatible
  SONAME).

## Troubleshooting

If your app cannot start on NPU, check:

- `snap connections <your-app-snap>` to confirm all interfaces are connected.
- `snap logs <your-app-snap>` for launcher error output.
- Device compatibility with one of the supported platforms listed above.
