# MAXHUB Wireless Dongle — Linux Installer

[![Linux](https://img.shields.io/badge/Linux-any_64--bit_distro-FCC624?logo=linux&logoColor=black)](https://kernel.org)
[![Wine 11.2](https://img.shields.io/badge/Wine-11.2_portable-722F37?logo=wine&logoColor=white)](https://www.winehq.org/)
[![Download ~70MB](https://img.shields.io/badge/Download-~70MB-brightgreen)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

One-command installer for the **MAXHUB WT13** wireless screen sharing dongle on Linux.

Downloads a portable Wine build (~70MB) — **no Docker, no system packages modified**.

<div dir="rtl">

## עברית

### מה זה?
סקריפט התקנה שמאפשר להשתמש בדונגל **MAXHUB WT13** לשיתוף מסך אלחוטי על לינוקס.

### למה צריך את זה?
הדונגל של MAXHUB מגיע עם תוכנה לווינדוס בלבד (MAXHUB.exe).
Wine רגיל (גרסה 9.0 ומטה) לא עובד — ה-UDEV bus שלו לא נטען, ו-Wine לא רואה את ההתקן.

הסקריפט הזה מוריד **Wine 11.2 portable** (~70MB) — בלי Docker, בלי לגעת בחבילות שלכם.

### דרישות
- לינוקס 64 ביט (אובונטו, דביאן, פדורה, Arch, openSUSE, CentOS ועוד)
- חיבור לאינטרנט
- דונגל MAXHUB מחובר ב-USB (או העתקה ידנית של MAXHUB.exe)

### התקנה

</div>

```bash
git clone https://github.com/ysdy823/MAXHUB-LINUX.git
cd MAXHUB-LINUX
sudo bash maxhub-linux-install.sh
```

<div dir="rtl">

זמן התקנה משוער: **~30 שניות**

### עדכון גרסה

אם כבר התקנתם בעבר:

</div>

```bash
cd ~/MAXHUB-LINUX && git pull && sudo bash maxhub-linux-install.sh
```

<div dir="rtl">

### איך זה עובד?

```
  המחשב שלכם
 ┌──────────────────────────────────┐
 │                                  │
 │  USB Dongle ──► Wine 11.2        │
 │                 (portable)       │
 │                 MAXHUB.exe       │
 │  Desktop    ◄── X11 window       │
 │                                  │
 └──────────────────────────────────┘
```

Wine רץ ישירות — בלי Docker, בלי קונטיינרים. כמו Steam/Proton.

### מה הסקריפט עושה?

| שלב | פעולה | זמן צפוי | נוגע בחבילות שלכם? |
|:---:|-------|:---------:|:-------------------:|
| 1 | מוריד Wine 11.2 portable (~70MB) | ~10 שנ' | לא |
| 2 | יוצר udev rule להרשאות הדונגל | ~1 שנ' | לא |
| 3 | מעתיק MAXHUB.exe מכונן USB | ~1 שנ' | לא |
| 4 | יוצר קיצור דרך + סקריפט הפעלה | ~1 שנ' | לא |
| 5 | מסיים | ~1 שנ' | לא |

**אף חבילה במערכת שלכם לא תשתנה, תימחק, או תתנגש.**

### הפעלה
הפעילו מתפריט האפליקציות ("MAXHUB Dongle") או:

</div>

```bash
/opt/maxhub-dongle/maxhub-dongle.sh
```

<div dir="rtl">

### פתרון בעיות

<details>
<summary><b>הדונגל לא מזוהה</b></summary>

1. נתקו וחברו מחדש את הדונגל
2. וודאו שחוקי udev הותקנו:
   ```bash
   cat /etc/udev/rules.d/99-maxhub-dongle.rules
   ```
3. טענו מחדש:
   ```bash
   sudo udevadm control --reload-rules && sudo udevadm trigger
   ```
4. וודאו שה-hidraw device נגיש:
   ```bash
   ls -la /dev/hidraw*
   ```

</details>

<details>
<summary><b>Wayland — מסך שחור או שגיאת display</b></summary>

הכלי דורש X11. אם אתם על Wayland, ודאו ש-XWayland מופעל (ברוב הדיסטרואים הוא מופעל כברירת מחדל).

</details>

<details>
<summary><b>MAXHUB.exe לא נמצא</b></summary>

העתיקו ידנית מכונן ה-USB:
```bash
sudo cp /media/$USER/MAXHUB_USB/MAXHUB.exe /opt/maxhub-dongle/
```

</details>

<details>
<summary><b>הסרת התקנה</b></summary>

```bash
sudo rm -rf /opt/maxhub-dongle
sudo rm -f /etc/udev/rules.d/99-maxhub-dongle.rules
sudo rm -f /usr/share/applications/maxhub-dongle.desktop
sudo udevadm control --reload-rules
```

</details>

</div>

---

## English

### What is this?
An installer for the **MAXHUB WT13** wireless screen sharing dongle on Linux.
Downloads a portable Wine build (~70MB) — **no Docker, no system packages modified**.

### How it works

```
  Your system
 ┌──────────────────────────────────┐
 │                                  │
 │  USB Dongle ──► Wine 11.2        │
 │                 (portable)       │
 │                 MAXHUB.exe       │
 │  Desktop    ◄── X11 window       │
 │                                  │
 └──────────────────────────────────┘
```

Wine runs directly — no Docker, no containers. Like Steam/Proton.

### Requirements
- Linux amd64 (Ubuntu, Fedora, Debian, Arch, openSUSE, CentOS, and more)
- Internet connection
- MAXHUB dongle USB drive (or manual copy of MAXHUB.exe)

### Installation

```bash
git clone https://github.com/ysdy823/MAXHUB-LINUX.git
cd MAXHUB-LINUX
sudo bash maxhub-linux-install.sh
```

Estimated time: **~30 seconds**

### Update

If you already installed previously:

```bash
cd ~/MAXHUB-LINUX && git pull && sudo bash maxhub-linux-install.sh
```

### What the script does

| Step | Action | Est. time | Touches your packages? |
|:----:|--------|:---------:|:----------------------:|
| 1 | Downloads Wine 11.2 portable (~70MB) | ~10 sec | No |
| 2 | Creates udev rule for dongle permissions | ~1 sec | No |
| 3 | Copies MAXHUB.exe from USB drive | ~1 sec | No |
| 4 | Creates desktop launcher + shell script | ~1 sec | No |
| 5 | Finishes up | ~1 sec | No |

**No system packages are modified, removed, or conflicted with.**

### Launch

```bash
/opt/maxhub-dongle/maxhub-dongle.sh
```
Or search for "MAXHUB Dongle" in your application menu.

### Troubleshooting

<details>
<summary><b>Dongle not detected</b></summary>

1. Unplug and replug the dongle
2. Verify udev rules: `cat /etc/udev/rules.d/99-maxhub-dongle.rules`
3. Reload: `sudo udevadm control --reload-rules && sudo udevadm trigger`
4. Check hidraw: `ls -la /dev/hidraw*`

</details>

<details>
<summary><b>Wayland — black screen or display error</b></summary>

This tool requires X11. If you're on Wayland, make sure XWayland is enabled (it is by default on most distros).

</details>

<details>
<summary><b>Uninstall</b></summary>

```bash
sudo rm -rf /opt/maxhub-dongle
sudo rm -f /etc/udev/rules.d/99-maxhub-dongle.rules
sudo rm -f /usr/share/applications/maxhub-dongle.desktop
sudo udevadm control --reload-rules
```

</details>

## Technical Details

| | |
|---|---|
| **Device** | MAXHUB WT13 |
| **USB ID** | `1FF7:0F52` |
| **Protocol** | USB HID with TCP/IP tunnel (`dongle_lwip_hid.dll`) |
| **Wine** | 11.2 portable ([Kron4ek/Wine-Builds](https://github.com/Kron4ek/Wine-Builds)) |
| **WoW64** | 64-bit Wine running 32-bit apps — no i386 libs needed |
| **Download** | ~70MB (wine-11.2-amd64-wow64.tar.xz) |
| **Isolation** | Self-contained in `/opt/maxhub-dongle/wine/` |
| **Supported** | Any 64-bit Linux with X11 |

## License

[MIT](LICENSE)
