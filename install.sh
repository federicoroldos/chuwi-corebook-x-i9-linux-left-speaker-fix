#!/bin/bash
# Installs the left-speaker pin override for the Chuwi CoreBook X (i9-13900HK, ALC269VC).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FW=/lib/firmware/hda-jack-retask.fw
CONF=/etc/modprobe.d/hda-jack-retask.conf

if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

# Make sure this is the right codec before touching anything.
codec=$(grep -l "Subsystem Id: 0x1e507036" /proc/asound/card*/codec#* 2>/dev/null | head -n1 || true)
if [[ -z "$codec" ]] || ! grep -q "Vendor Id: 0x10ec0269" "$codec"; then
  echo "No Realtek ALC269 (0x10ec0269) with subsystem 0x1e507036 found."
  echo "This fix is only for the Chuwi CoreBook X i9. Aborting."
  exit 1
fi
codec_num=${codec##*#}
if [[ "$codec_num" != "0" ]]; then
  echo "Note: codec is #$codec_num, not #0. Adjusting the firmware file to match."
fi

# Back up anything that's already there and isn't ours.
for f in "$FW" "$CONF"; do
  if [[ -e "$f" ]] && ! cmp -s "$f" "$HERE/$(basename "$f")"; then
    cp -v "$f" "$f.bak.$(date +%Y%m%d%H%M%S)"
  fi
done

sed "s/^0x10ec0269 0x1e507036 0$/0x10ec0269 0x1e507036 $codec_num/" "$HERE/hda-jack-retask.fw" > "$FW"
install -m 0644 "$HERE/hda-jack-retask.conf" "$CONF"
chmod 0644 "$FW"

echo
echo "Installed:"
echo "  $FW"
echo "  $CONF"
echo
echo "Reboot to apply. After reboot, check with:"
echo "  cat /sys/class/sound/hwC0D${codec_num}/user_pin_configs   # should print: 0x1b 0x90170120"
