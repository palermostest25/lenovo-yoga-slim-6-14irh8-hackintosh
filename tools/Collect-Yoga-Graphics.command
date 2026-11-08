#!/bin/zsh
# Read-only diagnostics (v3, everything for the eDP keep work). Run by double-clicking this file on the Intel Yoga.
set -u
export LC_ALL=C
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
usb_dir="${0:A:h}"
if [[ "$(uname -m)" != x86_64 ]]; then
  echo 'Please run this file on the Intel Yoga after booting its installed macOS.'
  exit 1
fi
report="$usb_dir/Yoga-Diagnostics-$(date +%Y%m%d-%H%M%S).txt"
if ! : > "$report"; then
  echo 'Cannot write beside this script. Keep it on the writable USB and try again.'
  exit 1
fi
# Keep raw GPU data intact; remove lines containing common private identifiers.
redact() {
  /usr/bin/perl -ne 'print unless /serial|system-id|systemuuid|platformuuid|\bMLB\b|"ROM"|IOPlatformUUID|IOPlatformSerialNumber|password|token|bluetooth.*address|mac.address|local.host.name|computer.name|owner.name|\bSSID\b|\bBSSID\b|IODisplayEDID|([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}/i'
}
section() {
  local title="$1"; shift
  echo "Collecting: $title"
  {
    printf '\n\n========== %s ==========\n' "$title"
    "$@" 2>&1 | redact
    local result=${pipestatus[1]}
    printf '\n[command exit status: %s]\n' "$result"
  } >> "$report"
}
{
  echo 'YOGA GRAPHICS DIAGNOSTICS — read-only collection'
  date -u '+UTC: %Y-%m-%d %H:%M:%S'
  echo 'No settings changed; no sudo requested. Access-denied errors are retained.'
  echo 'Common private identifier lines and EDID are omitted. Review before public sharing.'
} >> "$report"
section 'macOS version' sw_vers
section 'QUICK SUMMARY (read this first)' /bin/zsh -c '
echo "Boot time: $(sysctl -n kern.boottime)"; echo "Uptime: $(uptime)"
echo "Boot args: $(sysctl -n kern.bootargs)"
echo "IntelAccelerator instances: $(ioreg -r -c IntelAccelerator -d 1 | grep -c IntelAccelerator)"
echo "AppleIntelFramebuffer instances: $(ioreg -r -c AppleIntelFramebuffer -d 1 | grep -c "<class AppleIntelFramebuffer")"
echo "IONDRVFramebuffer instances (boot screen only): $(ioreg -r -c IONDRVFramebuffer -d 1 | grep -c "<class IONDRVFramebuffer")"
for key in WEXEDPKeepReady WEXDisplay13BootReady N97NativeStartAllowed N97NativePreflight WEXFramebufferDonorRuntimeReady; do
 printf "%s: " "$key"; ioreg -l -w0 -p IOService | grep -m1 -o "\"$key\" = [^ ]*" || echo "(absent)"
done
echo "--- Displays"; system_profiler SPDisplaysDataType | grep -E "Chipset|VRAM|Metal|Resolution|Display Type|Main Display|Online|Connection Type|Internal"
'
section 'Every display mode macOS offers (CoreGraphics, incl. HiDPI)' /bin/zsh -c 'f="'"$usb_dir"'/list-display-modes.js"; [[ -f "$f" ]] && /usr/bin/osascript -l JavaScript "$f" || echo "list-display-modes.js missing beside the script"'
section 'Power and display-sleep settings' /bin/zsh -c 'pmset -g; echo; pmset -g assertions; echo; pmset -g custom'
section 'Recent sleep, wake and display power events' /bin/zsh -c 'pmset -g log | grep -Ei "sleep|wake|display|dark" | tail -300'
section 'Kernel and architecture' uname -a
section 'CPU identity and capabilities' sysctl machdep.cpu hw.memsize hw.physicalcpu hw.logicalcpu kern.osversion kern.bootargs
section 'Graphics and displays' system_profiler SPDisplaysDataType -detailLevel full
section 'PCI hardware' system_profiler SPPCIDataType -detailLevel full
section 'Loaded kernel extensions' kmutil showloaded
section 'Legacy loaded-extension listing' kextstat
section 'Boot arguments and SIP from NVRAM' /bin/zsh -c 'nvram -p | grep -Ei "^(boot-args|csr-active-config|opencore-version|opencore-build)[[:space:]]"'
section 'SIP status' csrutil status
section 'Authenticated root status' csrutil authenticated-root status
section 'IGPU complete subtree (raw binary properties retained)' ioreg -l -w0 -r -n IGPU
section 'GFX0 complete subtree' ioreg -l -w0 -r -n GFX0
section 'GFX2 complete subtree' ioreg -l -w0 -r -n GFX2
section 'All WEX, N97 and GPU property lines' /bin/zsh -c 'ioreg -l -w0 -p IOService | grep -Ei "N97|WEX|WhateverXe|TGL|IntelAccelerator|framebuffer-|AAPL,ig|device-id|vendor-id|revision-id|model|IONameMatched|IOPCIPrimaryMatch"'
section 'eDP keep, panel link, DPCD and fault records' /bin/zsh -c 'ioreg -l -w0 -p IOService | grep -E "\"(WEXEDPKeep[A-Za-z]*|WEXPanel[A-Za-z]*|WEXDisplay13(Training|Empty|Boot|TC)[A-Za-z0-9]*|WhateverXeDPCD[A-Za-z]*|N97FB[A-Za-z]*|[A-Za-z0-9]*(Fault|LinkConfig)[A-Za-z0-9]*|TGL(EDP|Backlight|Panel)[A-Za-z0-9]*)\" ="'
section 'Backlight and display parameters' /bin/zsh -c 'ioreg -l -w0 -r -c AppleBacklightDisplay; ioreg -l -w0 -r -c IODisplayParameters 2>/dev/null | head -400; ioreg -l -w0 -r -n PNLF'
for class in IntelAccelerator AppleIntelTGLGraphics AppleIntelTGLGraphicsFramebuffer IONDRVFramebuffer IOFramebuffer IODisplayConnect AppleBacklightDisplay IOAccelerator AppleIntelFramebuffer AppleIntelFramebufferController AppleGraphicsDevicePolicy AGDPClientControl; do
  section "IORegistry class $class" ioreg -l -w0 -r -c "$class"
done
section 'ACPI device tree' ioreg -l -w0 -p IOACPIPlane
section 'PCI device tree' ioreg -l -w0 -r -c IOPCIDevice
section 'Graphics package receipts' /bin/zsh -c 'pkgutil --pkgs | grep -Ei "WhateverXe|TGL|AMFIPass|Lilu" | while IFS= read -r pkg; do pkgutil --pkg-info "$pkg"; pkgutil --files "$pkg"; done'
section 'Installed graphics kext metadata and binary hashes' /bin/zsh -c '
for base in /Library/Extensions /System/Library/Extensions; do
 for bundle in "$base"/*(N); do
  case "${bundle:t}" in *TGL*|*WhateverXe*|*AMFIPass*|Lilu.kext|WhateverGreen.kext|NootedGreen.kext)
   echo "--- $bundle"; plutil -p "$bundle/Contents/Info.plist"
   for binary in "$bundle"/Contents/MacOS/*(N); do shasum -a 256 "$binary"; done ;;
  esac
 done
done'
config="$usb_dir/EFI/OC/config.plist"
if [[ -f "$config" ]]; then
  section 'USB config checksum' shasum -a 256 "$config"
  for key in ACPI Booter Kernel DeviceProperties UEFI Misc.Security; do
    section "USB config: $key (SMBIOS identifiers excluded)" plutil -extract "$key" xml1 -o - "$config"
  done
  section 'USB OpenCore binary hash' shasum -a 256 "$usb_dir/EFI/OC/OpenCore.efi"
  for bundle in "$usb_dir"/EFI/OC/Kexts/*(N); do
    section "USB kext: ${bundle:t}" plutil -p "$bundle/Contents/Info.plist"
    for binary in "$bundle"/Contents/MacOS/*(N); do
      section "USB binary hash: ${bundle:t}/${binary:t}" shasum -a 256 "$binary"
    done
  done
  for aml in "$usb_dir"/EFI/OC/ACPI/*.aml(N); do
    section "USB ACPI binary (base64): ${aml:t}" base64 -i "$aml"
  done
fi
section 'Bluetooth: controller, kexts and USB device' /bin/zsh -c 'system_profiler SPBluetoothDataType; echo; kmutil showloaded 2>/dev/null | grep -i -E "blue|IntelBT|BlueTool"; echo; ioreg -l -w0 -r -c IOBluetoothHostController | head -200; echo; system_profiler SPUSBHostDataType 2>/dev/null || system_profiler SPUSBDataType; echo; ioreg -p IOUSB -w0 | head -120'
section 'Bluetooth log, this boot' /bin/zsh -c '/usr/bin/log show --last boot --style compact --predicate '\''process == "bluetoothd" OR (process == "kernel" AND (sender CONTAINS[c] "Bluetooth" OR sender CONTAINS[c] "IntelBT" OR sender CONTAINS[c] "BlueTool" OR eventMessage CONTAINS[c] "IntelBluetooth"))'\'' | tail -c 6000000'
section 'WhateverXe / Lilu log lines, this boot' /usr/bin/log show --last boot --style compact --predicate 'eventMessage CONTAINS "WhateverXe" OR eventMessage CONTAINS "eDP keep" OR sender == "Lilu"'
section 'Graphics, display policy, backlight and audio kernel log, this boot' /bin/zsh -c '/usr/bin/log show --last boot --style compact --info --predicate '\''(process == "kernel" AND (sender BEGINSWITH "AppleIntelTGL" OR sender == "AppleGraphicsDevicePolicy" OR sender == "AGDCBacklightControl" OR sender == "IOGraphicsFamily" OR sender == "IOAcceleratorFamily2" OR sender CONTAINS "Backlight" OR sender CONTAINS "AppleHDA" OR sender == "Lilu" OR sender == "WhateverXe" OR sender == "AppleIntelTGLCompat" OR eventMessage CONTAINS "WhateverXe" OR eventMessage CONTAINS "eDP keep" OR eventMessage CONTAINS "Darwin Kernel Version" OR eventMessage CONTAINS[c] "panic"))'\'' | tail -c 25000000'
section 'WindowServer display messages, this boot' /bin/zsh -c '/usr/bin/log show --last boot --style compact --predicate '\''process == "WindowServer" AND (subsystem == "com.apple.CoreDisplay" OR subsystem == "com.apple.SkyLight")'\'' | grep -v "No plane indices" | tail -c 8000000'
section 'Graphics kernel log, previous boots in the last 3 hours' /bin/zsh -c '/usr/bin/log show --last 3h --style compact --info --predicate '\''(process == "kernel" AND (sender BEGINSWITH "AppleIntelTGL" OR sender == "AppleGraphicsDevicePolicy" OR sender == "AGDCBacklightControl" OR sender == "IOGraphicsFamily" OR sender == "IOAcceleratorFamily2" OR sender CONTAINS "Backlight" OR sender CONTAINS "AppleHDA" OR sender == "Lilu" OR sender == "WhateverXe" OR sender == "AppleIntelTGLCompat" OR eventMessage CONTAINS "WhateverXe" OR eventMessage CONTAINS "eDP keep" OR eventMessage CONTAINS "Darwin Kernel Version" OR eventMessage CONTAINS[c] "panic"))'\'' | tail -c 25000000'
section 'Available Lilu/WEX debug dump files' /bin/zsh -c '
for dump in /var/log/*lilu*(N) /var/log/*Lilu*(N) /var/log/*WhateverXe*(N); do
 echo "--- ${dump:t}"; tail -c 2097152 "$dump"
done'
section 'Kernel panic reports (newest 5, last 7 days)' /bin/zsh -c '
files=(/Library/Logs/DiagnosticReports/{*.panic,Kernel*.ips,Retired/*.panic}(N.mh-168))
(( $#files )) || { echo "No panic report from the last 7 days."; exit 0; }
for f in ${(f)"$(ls -t -- $files | head -5)"}; do
 echo "--- $f"; head -c 262144 "$f"; echo
done'
section 'WindowServer and loginwindow crash reports (newest 4, last 7 days)' /bin/zsh -c '
files=(/Library/Logs/DiagnosticReports/{WindowServer*,loginwindow*,Retired/WindowServer*}(N.mh-168) ~/Library/Logs/DiagnosticReports/{WindowServer*,loginwindow*}(N.mh-168))
(( $#files )) || { echo "None in the last 7 days."; exit 0; }
for f in ${(f)"$(ls -t -- $files | head -4)"}; do
 echo "--- $f"; head -c 200000 "$f"; echo
done'
{
  echo '\n========== COLLECTION COMPLETE =========='
  echo 'No EFI, NVRAM, SIP, kernel collection or installed graphics files were modified.'
  echo 'If a section reports denied access or no output, that is diagnostic evidence, not a collection failure.'
} >> "$report"
sync
echo "DONE. Send this file back to the chat:"
echo "$report"
