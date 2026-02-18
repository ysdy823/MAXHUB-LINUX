# MAXHUB Wireless Dongle — Linux Installer

Installs Wine 11.x+ and configures the MAXHUB WT13 wireless screen sharing dongle (VID:1FF7 PID:0F52) to work on Ubuntu Linux.

## Why?

The MAXHUB dongle ships with Windows-only software (`MAXHUB.exe`). Ubuntu's default Wine 9.0 doesn't work because its UDEV bus thread doesn't start — Wine never sees the USB HID device. Wine 11.2+ from WineHQ has a working UDEV bus that properly enumerates hidraw devices.

## What it does

- Adds WineHQ PPA and installs Wine 11.x+ (winehq-devel)
- Installs udev rules for dongle permissions (hidraw + USB)
- Copies `MAXHUB.exe` from USB drive (if mounted)
- Initializes a Wine prefix
- Creates a desktop launcher and shell script

## Quick start

```bash
sudo bash maxhub-linux-install.sh
```

## Requirements

- Ubuntu 22.04 or 24.04 (amd64)
- Internet connection (for Wine installation)
- MAXHUB dongle USB drive mounted (or copy `MAXHUB.exe` manually)

## After installation

Launch from the application menu ("MAXHUB Dongle") or run:

```bash
/opt/maxhub-dongle/maxhub-dongle.sh
```

## Tested on

- Ubuntu 24.04 LTS with Wine 11.2
