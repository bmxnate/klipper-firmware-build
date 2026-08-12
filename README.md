# klipper-firmware-build

Pinned Klipper checkout + GitHub Actions workflow that builds `firmware.bin`
for each board config in `boards/`. Adding a new `boards/<name>.config` is
enough — the workflow discovers and builds them all via a matrix.

## Supported boards

| Board | MCU | Comms | Bootloader | Config |
|---|---|---|---|---|
| BIGTREETECH SKR Mini E3 v3.0 | STM32G0B1 | USB (PA11/PA12) | 8 KiB | `boards/skr-mini-e3-v3.0.config` |
| Sovol SV08 motion board | STM32F103 (GD32) | USART1 (PA10/PA9) | 28 KiB | `boards/sv08-motion.config` |

## How it works

- `klipper/` is a git submodule pinned to a specific upstream Klipper commit.
- `boards/*.config` are Klipper Kconfig defconfig snippets — one per target board.
- `.github/workflows/build-firmware.yaml`:
  1. Lists `boards/*.config` and builds a matrix.
  2. For each board: checks out the wrapper + submodule, installs
     `gcc-arm-none-eabi` + `kconfiglib`, copies the `.config`, runs
     `make olddefconfig && make`, uploads `firmware.bin` as an artifact.
- The Klipper SHA from the submodule is embedded in the artifact name and a
  `SOURCE_COMMIT.txt` file inside the artifact, so every `firmware.bin` is
  traceable to one exact upstream commit.
- On `v*` tag pushes, the same `.bin` is also attached to a GitHub Release.

## Flashing

1. Download the artifact `klipper-<board>-<sha>` from the Actions run.
2. Copy `firmware.bin` (or the date-stamped `firmware-YYYYMMDD-<board>.bin`
   for SV08/SV06 — their bootloader refuses a filename matching the last
   flashed file) to the root of a FAT32 SD card.
3. Insert into the powered-off board and power on. The bootloader flashes
   itself from the file (then deletes it).
4. Verify: `lsusb` or `ls /dev/serial/by-id/ | grep -i klipper`.

## Adding a new board

1. Drop a `boards/<name>.config` (Kconfig symbols for that MCU/comms/bootloader).
2. Commit + push. The workflow auto-discovers it via `ls boards/*.config`.
3. Download the artifact named `klipper-<name>-<sha>`.

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

The Actions workflow re-runs for every board automatically.

## Notes

- The CB1 (Allwinner H616) on the SV08 is a Linux SBC running Klipper as a
  host process — it's *not* a flash target. `boards/sv08-motion.config`
  targets the motion-control MCU, not the CB1.
