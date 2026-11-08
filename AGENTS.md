# AGENTS.md

Guidance for AI agents working on this repo. Read `README.md` first.

## What this is

OpenCore EFI for one Lenovo Yoga Slim 6 14IRH8 (i7-13700H, Iris Xe `8086:A7A0`, 1920x1200 OLED eDP 1.4b), macOS Tahoe 26.7.2,
with a patched WhateverXe (`whateverxe/patches`, on top of upstream 0.7.0 `d0b7fb6`).

## Rules

1. **Never retrain the internal panel.** It fails channel EQ at every rate and pattern; only the firmware-trained link works
   (`-wex-edp-keep`, `-wex-edp-softsleep`). Don't spend test boots on link-rate, TPS or bpc changes.
2. **Never commit private identifiers.** PlatformInfo serial, MLB, SystemUUID and ROM stay placeholders. Check the repo before every commit.
3. **One change per test boot.** Every test costs the owner a reboot and a USB swap. Give an honest X/10 that a change works.
4. **Validate every config change** with `ocvalidate` from OpenCore 1.0.x, and back up the owner's working EFI first.
5. **Donor-dependent hooks.** Patches 0003 and 0011 check the exact offsets and prologues in `AppleIntelTGLGraphicsFramebuffer` 16.0.0 from WhateverXe Graphics 0.4.0
   (`hwRegsNeedUpdate +0x4F044`, `prepareToExitWake +0x25062`, `prepareToEnterWake +0x25A4E`, `disableDisplay(bool) +0x68900`, `setDPPowerState +0x1D8BC`).
   With a different Graphics package these hooks install nothing; re-derive them before updating.
6. Keep OpenCore `UEFI > Output > Resolution = Max`: the keep decision needs the firmware at native 1920x1200.
7. Don't ship Apple driver binaries; the WhateverXe Graphics pkg installs them in macOS.

## Debugging

- A black boot still leaves a kernel log. Boot a working EFI and run `tools/Collect-Yoga-Graphics.command`; it includes the previous 3 hours.
- Look for `eDP keep:` and `eDP soft sleep` lines, and the `WEXEDPKeepFirst` / `WEXEDPKeep` / `WEXEDPSoftSleep*` registry records.
- `Phase 2 of link training failed` means something made the driver retrain the panel. Find out why the keep decision refused (the reasons bitmask in `kern_display13_edp_keep.hpp`).
- Bluetooth: `ReadLocalVersionInformation failed: STATUS 408` / `HCI initialization failed` means the AX211 isn't answering; check the kext versions (2.5.3+) before the USB map.

## Open work

1. Full system sleep (S3 resume does a complete mode set). `tools/Install-Lid-Hibernate.command` works around it: screen off on lid close, then `hibernatemode 25`.
2. Hibernate wake restarts once before booting (`HibernateMode = None`). `Auto` is untested, and it isn't confirmed that the session is restored.
3. AirDrop and Continuity are not possible with the Intel CNVi Wi-Fi/Bluetooth.
4. Thunderbolt: no macOS driver loads for the built-in controllers (`8086:A73E`, `A76D`).
