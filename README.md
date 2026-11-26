# Chuwi CoreBook X (i9) — left speaker fix for Linux

On Linux, the **left speaker of the Chuwi CoreBook X (i9-13900HK)** is silent: everything plays from the right speaker only.
This repo has a two-file fix that turns the left speaker on, with correct stereo left/right, and keeps it working across reboots.

## Hardware this is for

| | |
|---|---|
| Laptop | CHUWI CoreBook X, Intel Core i9-13900HK |
| BIOS | DN525ERV103 |
| Audio codec | Realtek ALC269VC — vendor ID `0x10ec0269` |
| Codec subsystem ID | `0x1e507036` |
| Tested on | Ubuntu 26.04.1 LTS, kernel 7.0.0-44-generic, PipeWire 1.6.2 |

Check yours:

```bash
grep -E "^Codec|Vendor Id|Subsystem Id" /proc/asound/card*/codec#*
```

You should see `Realtek ALC269VC`, `0x10ec0269` and `0x1e507036`. The install script refuses to run otherwise.

## The cause

The codec has two outputs wired to the two internal speakers:

| Speaker | Codec pin | BIOS pin config | Result |
|---|---|---|---|
| Right | `0x14` | `0x90170110` — internal speaker | works |
| Left | `0x1b` | `0x411111f0` — **"not connected"** | never enabled |

The BIOS describes pin `0x1b` as unused, so the Linux HDA driver never turns it on, and the left speaker gets no signal.
On Windows the Realtek driver presumably knows better; on Linux we have to tell the driver ourselves.

## The fix

Override the pin config for `0x1b` so the driver sees it as a second internal speaker (`0x90170120`: fixed, internal, speaker, same group as the right one).
This uses the kernel's standard `hda-jack-retask` firmware patch mechanism. Two files:

**`/lib/firmware/hda-jack-retask.fw`**

```
[codec]
0x10ec0269 0x1e507036 0

[pincfg]
0x1b 0x90170120
```

**`/etc/modprobe.d/hda-jack-retask.conf`**

```
options snd-hda-intel patch=hda-jack-retask.fw
```

The kernel then names pin `0x1b` "Bass Speaker" in the mixer (`alsamixer`). That's just its naming guess for a second speaker pin. It plays the normal full-range left channel.

## Install

```bash
git clone https://github.com/federicoroldos/chuwi-corebook-x-i9-linux-left-speaker-fix.git
cd chuwi-corebook-x-i9-linux-left-speaker-fix
./install.sh      # asks for sudo, checks the codec, backs up existing files
sudo reboot
```

Or by hand:

```bash
sudo cp hda-jack-retask.fw /lib/firmware/
sudo cp hda-jack-retask.conf /etc/modprobe.d/
sudo reboot
```

### Try it first without installing (optional)

```bash
./test-live.sh
```

This stops PipeWire for a few seconds, applies the override through sysfs (`/sys/class/sound/hwC0D0/user_pin_configs` + `reconfig`), plays a left/right voice test, and starts PipeWire again. The override is lost on reboot.

## Check that it worked

After rebooting:

```bash
cat /sys/class/sound/hwC0D0/user_pin_configs
# 0x1b 0x90170120

speaker-test -c 2 -t wav -l 1
# "Front Left" from the left speaker, "Front Right" from the right
```

`/proc/asound/card0/codec#0` still shows `Pin Default 0x411111f0` for node `0x1b`. That's expected: it reports the BIOS value, and the override is applied on top of it in the driver.

## Uninstall

```bash
./uninstall.sh
sudo reboot
```

## Notes from debugging

- **Pin mapping:** pin `0x14`'s right channel drives the right speaker, and pin `0x1b`'s left channel drives the left speaker. `0x14`'s left channel and `0x1b`'s right channel aren't connected to anything. Both pins are fed by the same DAC (`0x03`), so volume control works for both together. The two speakers are wired with the same polarity (checked with an in-phase / inverted A/B test).
- **Why not `hda-verb`?** Turning the pin on with `hda-verb` works for a moment, but the codec power-saves (`power_save=1`) and forgets the setting once it suspends. The pin config override keeps working because the driver reapplies it.
- **The AWINIC amp in ACPI is a red herring.** The DSDT lists an AWINIC speaker amp (`AWDZ8680`) on I2C1, but that controller is disabled and no chip answers on any I2C bus. It looks like leftover template data, and the speakers don't need it.
- **Testing one channel at a time:** if you switch off a single channel with `amixer` (e.g. `amixer sset Speaker on,off`) while PipeWire is running, PipeWire marks the whole sink as muted and you hear nothing. Stop PipeWire and play to `plughw:0,0` directly for that kind of test.
- **Sound quality:** on the unit this was tested on, the right speaker sounds noticeably thinner than the left. Wiring and polarity were checked and are fine, so this looks like the speaker hardware itself, not something this fix can change.

## Proper upstream fix

The real fix would be a quirk in the kernel's Realtek driver (`sound/hda/codecs/realtek/alc269.c`, previously `sound/pci/hda/patch_realtek.c`) for subsystem `0x1e50:0x7036` that applies the `0x1b` pin config automatically. Until that exists, this override does the same job.

## License

MIT, see [LICENSE](LICENSE).
