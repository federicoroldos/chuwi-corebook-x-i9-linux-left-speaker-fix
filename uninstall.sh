#!/bin/bash
# Removes the left-speaker pin override.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

rm -fv /lib/firmware/hda-jack-retask.fw /etc/modprobe.d/hda-jack-retask.conf
echo
echo "Removed. Reboot to go back to the stock (right speaker only) behaviour."
