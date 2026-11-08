#!/bin/zsh
# Yoga lid watcher: screen off when the lid shuts, hibernate 5 minutes later, nothing when docked.
# To remove: sudo launchctl bootout system/local.lid-hibernate; sudo rm /Library/LaunchDaemons/local.lid-hibernate.plist /Library/Scripts/lid-hibernate.sh
set -e
# The older display-only watcher would fight this one.
launchctl bootout gui/$(id -u)/local.lid-display-off 2>/dev/null || true
rm -f ~/Library/LaunchAgents/local.lid-display-off.plist ~/Library/Scripts/lid-display-off.sh
sudo -v
sudo launchctl bootout system/local.lid-hibernate 2>/dev/null || true
sleep 1
sudo mkdir -p /Library/Scripts
sudo tee /Library/Scripts/lid-hibernate.sh >/dev/null <<'LIDEOF'
#!/bin/zsh
# Lid shut: screen off at once, hibernate DELAY seconds later. Docked: leave everything alone.
# disablesleep 1 stops macOS sleeping the moment the lid shuts; it is lifted only to hibernate.
DELAY=300

lid_shut() { ioreg -r -k AppleClamshellState -d 1 | grep -q '"AppleClamshellState" = Yes'; }
docked() {
  ioreg -p IOUSB -l | grep -q '"idVendor" = 6121' && return 0     # DisplayLink 0x17e9
  ioreg -r -c AppleDisplay -d 1 | grep -q '<class AppleDisplay,'  # the internal panel is AppleBacklightDisplay
}

pmset -a disablesleep 1
shut_at=0
while true; do
  if lid_shut && ! docked; then
    if (( shut_at == 0 )); then
      shut_at=$(date +%s)
      pmset displaysleepnow
    elif (( $(date +%s) - shut_at >= DELAY )); then
      pmset -a disablesleep 0
      pmset sleepnow
      sleep 15    # let the hibernate start; after resume the script carries on from here
      pmset -a disablesleep 1
      shut_at=0
    fi
  else
    shut_at=0
  fi
  sleep 2
done
LIDEOF
sudo chown root:wheel /Library/Scripts/lid-hibernate.sh
sudo chmod 755 /Library/Scripts/lid-hibernate.sh
sudo tee /Library/LaunchDaemons/local.lid-hibernate.plist >/dev/null <<'LIDEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>local.lid-hibernate</string>
<key>ProgramArguments</key><array><string>/bin/zsh</string><string>/Library/Scripts/lid-hibernate.sh</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
</dict></plist>
LIDEOF
sudo chown root:wheel /Library/LaunchDaemons/local.lid-hibernate.plist
sudo chmod 644 /Library/LaunchDaemons/local.lid-hibernate.plist
sudo pmset -a hibernatemode 25
sudo launchctl bootstrap system /Library/LaunchDaemons/local.lid-hibernate.plist
sleep 2
pmset -g | grep -E 'hibernatemode|SleepDisabled' || true
echo "Done. Close the lid to test."
