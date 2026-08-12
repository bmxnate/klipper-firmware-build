# klipper-firmware-build

Pinned Klipper checkout + GitHub Actions workflow that builds `firmware.bin`
for each board config in `boards/`. Adding a new `boards/<name>.config` is
enough — the workflow discovers and builds them all via a matrix.

## Supported boards

| Board | Target | MCU | Comms | Bootloader | Boot GPIO | Config |
|---|---|---|---|---|---|---|
| BIGTREETECH SKR Mini E3 v3.0 | ARM MCU | STM32G0B1 | USB (PA11/PA12) | 8 KiB | — | `boards/skr-mini-e3-v3.0.config` |
| Sovol SV08 — mainboard | ARM MCU | STM32F103 (GD32) | USART1 (PA10/PA9) | 8 KiB Katapult | `PA1,PA3` (fan + LED) | `boards/sv08-host.config` |
| Sovol SV08 — toolhead | ARM MCU | STM32F103 (GD32) | USART1 (PA10/PA9) | 8 KiB Katapult | `PA6` (hotend fan) | `boards/sv08-toolhead.config` |

## How it works

- `klipper/` is a git submodule pinned to a specific upstream Klipper commit.
- `boards/*.config` are Klipper Kconfig defconfig snippets — one per target.
- `.github/workflows/build-firmware.yaml` discovers `boards/*.config`,
  builds a matrix, and for each board:
  1. Checks out the wrapper + submodule
  2. Installs `gcc-arm-none-eabi` + `kconfiglib`
  3. Copies the `.config`, runs `make olddefconfig && make`
  4. Uploads `firmware.bin` as an artifact named `klipper-<board>-<sha>`
- On `v*` tag pushes, the same `.bin` is also attached to a GitHub Release.
- The pinned Klipper SHA is embedded in every artifact name and in a
  `SOURCE_COMMIT.txt` file inside the artifact for provenance.

## Flashing — SKR Mini E3 v3.0

1. Download the artifact `klipper-skr-mini-e3-v3.0-<sha>` from the Actions run.
2. Copy `firmware.bin` to the root of a **FAT32 SD card**.
3. Insert into the **powered-off** board and power on. The STM32 bootloader
   flashes itself from the file (then deletes it).
4. Verify by USB: `ls /dev/serial/by-id/ | grep -i klipper`.

## Flashing — Sovol SV08 (mainboard + toolhead)

**⚠️ This is NOT an SD-card flash.** The SV08 MCUs are flashed **over USB
from the CB1 Linux host** via the Katapult bootloader. Both MCUs run the same
chip (STM32F103xe / GD32 clone, 8 KiB Katapult bootloader, USART1 serial) but
take **different `INITIAL_PINS`** — one `.bin` per board, matched pair.

### Prerequisites

- Katapult already flashed to both MCUs (see the
  [Rappetor/Sovol-SV08-Mainline](https://github.com/Rappetor/Sovol-SV08-Mainline) guide).
- `pyserial` installed on the CB1.

### Recommended — use the community script

The simplest path is to let the Rappetor repo's
`update_klipper_mcus_sv08.sh` script handle menuconfig + `make flash_usb`
for both boards interactively. Drop your Klipper source + the script on the
CB1 and run:

```bash
cd ~/klipper
./update_klipper_mcus_sv08.sh
# 1 → HOST MCU    (sets PA1,PA3 as initial pins)
# 2 → TOOLHEAD    (sets PA6 as initial pin)
```

### Manual — if you've built via this repo's Actions

To use the Actions-produced `.bin` from this repo instead of building on the
CB1, copy both artifacts to the CB1 and flash each with the correct serial:

```bash
# On the CB1, after `make menuconfig` once for the right board already done:
python3 klipper/scripts/flash_usb.py \
  -t 0x2000 \
  -d /dev/serial/by-id/usb-Katapult_stm32f103xe_<HOST_SERIAL> \
  ~/klipper-sv08-host-<sha>/firmware.bin

python3 klipper/scripts/flash_usb.py \
  -t 0x2000 \
  -d /dev/serial/by-id/usb-Katapult_stm32f103xe_<TOOLHEAD_SERIAL> \
  ~/klipper-sv08-toolhead-<sha>/firmware.bin
```

Identify which serial is which by **disconnecting the toolhead USB** and
running `ls /dev/serial/by-id/` — the serial that **disappears** is the
toolhead (`extra_mcu`); the one that stays is the host (`[mcu]`).

**⚠️ Don't swap `[mcu]` and `[extra_mcu]` serials in printer.cfg — the
hotend heater will turn on full blast.** Always use the static by-id serials,
never `ttyACM0`/`ttyACM1`.

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
  host process — it is *not* a flash target. `boards/sv08-host.config` and
  `boards/sv08-toolhead.config` target the motion-control MCUs, not the CB1.
- The SV08 main + toolhead MCUs are the same chip, but they require separate
  `.config` builds because `INITIAL_PINS` pins differ (host needs `PA1,PA3`
  for controller fan + status LED; toolhead needs `PA6` for hotend fan).
