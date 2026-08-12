# klipper-firmware-build

Pinned Klipper checkout + GitHub Actions workflow that builds a `firmware.bin`
for the **BIGTREETECH SKR Mini E3 v3.0** (STM32G0B1, 8 KiB bootloader, USB).

## How it works

- `klipper/` is a git submodule pinned to a specific upstream Klipper commit.
- `.github/workflows/build-firmware.yaml` runs on every push (and on manual dispatch):
  1. Checks out the wrapper + submodule.
  2. Installs `gcc-arm-none-eabi` + `kconfiglib`.
  3. Copies `skr-mini-e3-v3.0.config` → `klipper/.config` and runs `make olddefconfig`.
  4. Runs `make` — produces `klipper/out/klipper.bin`.
  5. Uploads the `.bin` (named `firmware.bin` + with Klipper SHA in the name) as an artifact.
- On `v*` tag pushes, the same `.bin` is attached to a GitHub Release.

## Flashing

1. Download the artifact `klipper-skr-mini-e3-v3.0-<sha>` from the Actions run.
2. Copy `firmware.bin` to the root of a FAT32 SD card.
3. Insert into the powered-off SKR Mini E3 v3.0 and power on.
4. The board's bootloader flashes itself from `firmware.bin` (then deletes it).
5. Verify: `lsusb` should show a Klipper USB CDC device, or `ls /dev/serial/by-id/ | grep -i klipper`.

## Printer config

The Klipper *printer* (host-side) config for the SKR Mini E3 v3.0 lives in
`klipper/config/generic-bigtreetech-skr-mini-e3-v3.0.cfg` — use it as the
starting point for the `[mcu]` section of your `printer.cfg` (just fix the
`serial:` line to your actual `/dev/serial/by-id/usb-Klipper_...` path).

## Updating the pinned Klipper SHA

```sh
cd klipper
git fetch origin
git checkout <new-sha-or-tag>
cd ..
git add klipper
git commit -m "klipper: bump to <sha>"
git push
```

The Actions workflow re-runs automatically and produces a fresh `firmware.bin`.
