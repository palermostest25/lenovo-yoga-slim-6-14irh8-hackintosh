# Lenovo Yoga Slim 6 (14IRH8, i7-13700H): macOS Tahoe with the internal OLED working

OpenCore EFI for a Lenovo Yoga Slim 6 with an i7-13700H and Iris Xe graphics (`8086:A7A0`), running macOS Tahoe 26.7.2.
The graphics run through [WhateverXe](https://github.com/b00t0x/WhateverXe) + [WhateverXe Graphics](https://github.com/b00t0x/WhateverXe-Graphics) 0.4.0,
with the patches in [`whateverxe/patches`](whateverxe/patches).

> Lenovo sells the i7-13700H version as the **Yoga Slim 6 14IRH8**. It has a 14" 1920x1200 OLED panel.

## Status

| Feature | Status |
| --- | --- |
| Metal acceleration (Iris Xe) | Works |
| Internal 1920x1200 OLED | Works |
| Scaled resolutions ("Larger Text" / "More Space") | Work |
| Brightness slider | Works (AuxDim) |
| Display sleep | Works |
| Lid close | Screen off, then hibernates 5 minutes later; nothing when docked (section 6) |
| External USB-C / HDMI monitor | Works |
| Bluetooth | Works (Intel AX211). Continuity features are limited |
| AirDrop | **Not supported**: the Intel Wi-Fi driver has no AWDL |
| Hibernation (`hibernatemode 25`) | Works: open apps and windows come back as you left them, with the screen working. See Known issues for the restart on wake |
| Full system sleep | **Not supported**: the panel goes dark on resume. The lid watcher turns it off |
| Thunderbolt | **Not working**: no macOS driver loads for the built-in controllers. USB-C still does USB and screens |

## What changes from stock, and why

"Stock" is the EFI this started from, with the official WhateverXe **0.7.0** release. Six things differ.

### 1. WhateverXe: patched build instead of the official 0.7.0

`EFI/OC/Kexts/WhateverXe.kext` is upstream 0.7.0 (`d0b7fb6`) plus the 11 patches in [`whateverxe/patches`](whateverxe/patches):

| Patches | Author | Why |
| --- | --- | --- |
| 0001 | Thatisjigen (via nickk19) | Lets WhateverXe take over the internal panel from the firmware (the eDP port is still in "mode 0" at handover). |
| 0002 | nickk19 | The VBT picks the panel by its EDID (`panel_type 0xFF`). Without this, WhateverXe doesn't see the panel at all. |
| 0003 | nickk19 | **The main fix: `-wex-edp-keep`.** This OLED never completes link training under macOS: it fails at 5.4 Gbps and at 2.7 Gbps, with every training pattern. The firmware has already trained the link, so WhateverXe keeps that link instead of retraining. It also makes macOS see the panel as the firmware runs it (2 lanes, 2.7 Gbps, 8-bit colour). |
| 0004 | Thatisjigen | Screen buffer sizes that don't end on a memory page (for example 2880x1800). Without it, some scaled modes fail. |
| 0005–0009 | retropineaple, Thatisjigen | Display memory timings (watermarks) for scaled modes. |
| 0010 | this repo | Scaled resolutions keep the link: a scaled mode changes only the pipe's source size, which Apple's driver reprograms itself. Without it, changing resolution turns the screen black. |
| 0011 | this repo | **`-wex-edp-softsleep`**: display sleep and lid close keep the link too. The OLED is switched off and on over its AUX channel (DPCD `0x720`), because it has no backlight pin. Without it, the screen stays black after display sleep. |

Both new switches are opt-in boot arguments; without them, the build behaves like upstream plus 0001–0009.

### 2. Add AuxDim.kext (brightness)

[AuxDim](https://github.com/nickk19/AuxDim) 0.1.0 by nickk19, loaded after WhateverXe, with `-auxdimctl`.
This OLED is dimmed over the AUX channel (Intel nits interface, DPCD `0x354`), not with a PWM backlight, so macOS's slider does nothing without it.
It needs an SSDT-PNLF, which this EFI already had.

### 3. Boot arguments

```
debug=0x100 keepsyms=1 -allow3d -disablegfxfirmware -igfxdvmt -vi2c-force-polling ctrsmt=full -wex-edp-keep -auxdimctl -wex-edp-softsleep
```

| Change | Why |
| --- | --- |
| added `-wex-edp-keep` | Keep the firmware-trained panel link (patch 0003) |
| added `-wex-edp-softsleep` | Keep it through display sleep and lid close (patch 0011) |
| added `-auxdimctl` | Turn on AuxDim brightness control |
| removed `-v` | Verbose boot no longer needed |

### 4. Custom USB map (UTBMap.kext)

Built with USBToolBox in Windows. `UTBMap.kext` is enabled and `UTBDefault.kext` is disabled; `USBToolBox.kext` stays.
The generic map left Bluetooth unusable. This map has 8 ports:

| Controller | Ports | What |
| --- | --- | --- |
| XHCI (`8086:51ED`) | HS01 + SS01 (ports 1, 13) | USB-A |
| XHCI | HS03, HS04 (ports 7, 8) | USB 2 half of both USB-C ports |
| XHCI | port 4 (internal) | Webcam |
| XHCI | port 10 (internal) | Intel Bluetooth `8087:0033` |
| TXHC (`8086:A71E`) | ports 2, 4 | USB 3 half of both USB-C ports |

Re-map it if your board differs. In Windows, disable the **Parsec Virtual USB Adapter** in Device Manager while USBToolBox runs, or USBToolBox fails.

### 5. Bluetooth kexts for Tahoe

| Kext | Stock | Now | Why |
| --- | --- | --- | --- |
| IntelBluetoothFirmware, IntelBTPatcher | lshbluesky 2.5.0 | [lshbluesky 2.5.3](https://github.com/lshbluesky/IntelBluetoothFirmware/releases/tag/v2.5.3) | With 2.5.0 the AX211 never answered (`ReadLocalVersionInformation failed: STATUS 408`, `HCI initialization failed`). 2.5.1+ has updated AX211 firmware and is reported working on Tahoe 26.7.2 |
| BlueToolFixup | unofficial 2.7.3 | [acidanthera 2.7.2](https://github.com/acidanthera/BrcmPatchRAM/releases/tag/2.7.2) | Official release, the version used in working Tahoe setups |

The NVRAM keys `bluetoothExternalDongleFailed = 00` and `bluetoothInternalControllerInfo = 14 zero bytes` were already set, and stay set.

### 6. Hibernation and the lid watcher

In the EFI, `Misc > Boot > HibernateMode` changes from `None` to `Auto`, to try to stop a restart on wake (not confirmed yet).
The rest is in macOS.

Full system sleep leaves this panel dark, so the lid can't use it. [`tools/Install-Lid-Hibernate.command`](tools/Install-Lid-Hibernate.command) installs a small background script instead:

| Lid shut and... | What happens |
| --- | --- |
| Not docked | Screen off straight away, hibernate 5 minutes later |
| Docked (DisplayLink dock or external screen) | Nothing: screens stay on, laptop stays awake |
| Opened within the 5 minutes | Hibernate cancelled |

It sets `hibernatemode 25` and `disablesleep 1`, because macOS otherwise sleeps the moment the lid shuts, and lifts `disablesleep` only to hibernate.
To change the delay, edit `DELAY=300` in `/Library/Scripts/lid-hibernate.sh` and reboot.

Everything else (SMBIOS `MacBookPro16,2`, other kexts, ACPI, quirks) is unchanged.

## Setup

1. Fill in **PlatformInfo → Generic** in `EFI/OC/config.plist`. In this repo the serial, MLB, UUID and ROM are placeholders.
   Keep `SystemProductName = MacBookPro16,2`. Generate values with `macserial -m MacBookPro16,2 -n 1` (or GenSMBIOS), use `uuidgen` for the UUID, and use the Ethernet or Wi-Fi MAC address for the ROM.
2. OpenCore `UEFI > Output > Resolution` must stay **`Max`**, so the firmware leaves the panel at native 1920x1200.
3. Copy `EFI/` to the USB stick or the internal disk's EFI partition.
4. In macOS, install **WhateverXe Graphics 0.4.0** (the pkg), then reboot. The keep patch checks the exact Apple driver from that package. With another version it switches itself off, and the internal panel stays dark.
5. Run `tools/Install-Lid-Hibernate.command` once (section 6). It starts by itself at every boot.
6. Optional: HiDPI ("looks like 1280x800" etc.) with [one-key-hidpi](https://github.com/xzhih/one-key-hidpi) or [BetterDisplay](https://github.com/waydabber/BetterDisplay).

## Known issues

- **AirDrop** doesn't work, and Handoff and Universal Clipboard are unreliable. The Intel Wi-Fi driver has no AWDL, and Intel Bluetooth is only partly Continuity-compatible. The Wi-Fi is the chipset-integrated CNVi type (`8086:51F1`), so a Broadcom card isn't an option. Use [LocalSend](https://localsend.org) for file transfer.
- **Bluetooth** may drop out now and then; others report this with Intel Bluetooth on Tahoe. Toggle it off and on, or reboot.
- **Full system sleep (S3)**: the panel stays dark on resume. The lid watcher keeps it off with `disablesleep 1`.
- **Waking from hibernation** goes through the OpenCore menu. With `HibernateMode = None` it restarted once, then resumed on the second try. This EFI now has `Auto` to try to stop that, which isn't confirmed yet. If it makes waking worse, set it back to `None`.
- **Docked with the lid shut**, the lid watcher leaves the internal OLED alone, because `pmset` can only turn off every screen at once.
- **Thunderbolt docks** don't work. A DisplayLink USB-C dock works plugged straight into the laptop, but not through a Thunderbolt dock.
- **A real change of the panel timing** (not a scaled mode) is not kept and goes dark. macOS normally only offers scaled modes for this panel.
- `SimpleHDA.kext` is enabled. On another WhateverXe machine it crashed when a DisplayPort screen connected. If you see `AppleHDAHDMI_DPDriver` panics, disable it.

## Diagnostics

`tools/Collect-Yoga-Graphics.command` (with `list-display-modes.js` next to it) is read-only. Run it from the USB stick.
It writes one report with the graphics state, every display mode, the keep and soft-sleep records, Bluetooth, the logs of this boot and of boots in the last 3 hours, and crash reports.
It filters out serial numbers, UUIDs and MAC addresses.

## Rebuilding WhateverXe

```bash
git clone https://github.com/b00t0x/WhateverXe.git && cd WhateverXe
git checkout d0b7fb6
git am /path/to/this/repo/whateverxe/patches/*.patch
python3 tools/build.py --release --output build/RELEASE
```

You need `Lilu.kext` and `MacKernelSDK` in the checkout (see WhateverXe's README).
This repo's binary: `WhateverXe` SHA256 `35c4d4a7dfa3005cf1cbc901661b780d6ee1f6fa80cb5bd6592a8545b1310322`.

## Credits

- [b00t0x](https://github.com/b00t0x): WhateverXe, WhateverXe Graphics, AMFIPass Mod
- [nickk19](https://github.com/nickk19): `-wex-edp-keep` ([WhateverXe #43](https://github.com/b00t0x/WhateverXe/issues/43)) and AuxDim
- [Thatisjigen](https://github.com/Thatisjigen) and retropineaple: eDP handoff, aperture and scaled-mode watermarks ([#38](https://github.com/b00t0x/WhateverXe/issues/38))
- [KenzoPortela](https://github.com/KenzoPortela): the Tiger Lake soft-sleep approach ([#37](https://github.com/b00t0x/WhateverXe/issues/37)) adapted in patch 0011
- [lshbluesky](https://github.com/lshbluesky/IntelBluetoothFirmware): IntelBluetoothFirmware / IntelBTPatcher for Tahoe
- acidanthera (OpenCore, Lilu, VirtualSMC, AppleALC, BlueToolFixup), OpenIntelWireless, VoodooI2C, USBToolBox, YogaSMC and the other kext authors
- WhateverXe and AuxDim are BSD-licensed; see their repositories
