#!/bin/bash
# Try the fix without installing anything or rebooting.
# Stops PipeWire briefly (the codec can't be reconfigured while it's in use),
# applies the pin override through sysfs, then starts PipeWire again.
# The change is lost on reboot.
set -euo pipefail

HW=/sys/class/sound/hwC0D0

if ! grep -q "0x1e507036" "$HW/subsystem_id" 2>/dev/null; then
  echo "Codec 0 is not subsystem 0x1e507036 (Chuwi CoreBook X). Aborting."
  exit 1
fi

echo "Stopping PipeWire..."
systemctl --user stop wireplumber pipewire-pulse pipewire pipewire.socket pipewire-pulse.socket
trap 'systemctl --user start pipewire.socket pipewire-pulse.socket pipewire pipewire-pulse wireplumber' EXIT
sleep 1

echo "Applying pin override 0x1b -> 0x90170120 (needs sudo)..."
sudo sh -c "echo '0x1b 0x90170120' > $HW/user_pin_configs && echo 1 > $HW/reconfig"

echo "Playing left/right test..."
speaker-test -D plughw:0,0 -c 2 -t wav -l 1 >/dev/null 2>&1 || echo "speaker-test failed"

echo "Done. You should have heard 'Front Left' from the left speaker and 'Front Right' from the right."
echo "If so, run ./install.sh to make it permanent."
