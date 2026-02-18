# MAXHUB Wireless Dongle — Linux Installer

[![Linux](https://img.shields.io/badge/Linux-any_distro-FCC624?logo=linux&logoColor=black)](https://kernel.org)
[![Docker](https://img.shields.io/badge/Docker-required-2496ED?logo=docker&logoColor=white)](https://docker.com)
[![Wine 11+](https://img.shields.io/badge/Wine-11.2+_(in_container)-722F37?logo=wine&logoColor=white)](https://www.winehq.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

One-command installer for the **MAXHUB WT13** wireless screen sharing dongle on Linux.

Wine runs inside a Docker container — **your system packages are never modified**.

<div dir="rtl">

## עברית

### מה זה?
סקריפט התקנה שמאפשר להשתמש בדונגל **MAXHUB WT13** לשיתוף מסך אלחוטי על לינוקס.

### למה צריך את זה?
הדונגל של MAXHUB מגיע עם תוכנה לווינדוס בלבד (MAXHUB.exe).
Wine רגיל (גרסה 9.0 ומטה) לא עובד — ה-UDEV bus שלו לא נטען, ו-Wine לא רואה את ההתקן.

הסקריפט הזה מריץ **Wine 11.2+** בתוך Docker — בלי לגעת בחבילות שלכם.

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

זמן התקנה משוער: **~2-4 דקות** (מהיר יותר אם Docker כבר מותקן)

### איך זה עובד?

```
  המחשב שלכם                    Docker container
 ┌──────────────┐              ┌──────────────────┐
 │              │   hidraw     │                  │
 │  USB Dongle ─┼──────────►  │  Wine 11.2+      │
 │              │   X11        │  MAXHUB.exe      │
 │  Desktop    ◄┼──────────── │                  │
 │              │              │  (Debian bookworm)│
 └──────────────┘              └──────────────────┘
```

### מה הסקריפט עושה?

| שלב | פעולה | זמן צפוי | נוגע בחבילות שלכם? |
|:---:|-------|:---------:|:-------------------:|
| 1 | מתקין Docker (אם לא קיים) | ~1 דק' | לא |
| 2 | מוריד image מוכן עם Wine 11+ | ~1-2 דק' | לא |
| 3 | יוצר udev rule להרשאות הדונגל | ~1 שנ' | לא |
| 4 | מעתיק MAXHUB.exe מכונן USB | ~1 שנ' | לא |
| 5 | יוצר קיצור דרך + סקריפט הפעלה | ~1 שנ' | לא |

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
<summary><b>שגיאת Docker permissions</b></summary>

אם מקבלים שגיאה על הרשאות Docker, התנתקו והתחברו מחדש (או הריצו `newgrp docker`).
הלאנצ'ר ינסה לפתור את זה אוטומטית, אבל logout/login הוא הפתרון הנקי.

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
# הסרת הקבצים
sudo rm -rf /opt/maxhub-dongle
sudo rm -f /etc/udev/rules.d/99-maxhub-dongle.rules
sudo rm -f /usr/share/applications/maxhub-dongle.desktop
sudo udevadm control --reload-rules

# הסרת Docker image
docker rmi maxhub-dongle
```
Docker עצמו ישאר — הסירו בנפרד אם תרצו.

</details>

</div>

---

## English

### What is this?
An installer for the **MAXHUB WT13** wireless screen sharing dongle on Linux.
Wine runs inside a Docker container — **your system packages are never touched**.

### How it works

```
  Your system                    Docker container
 ┌──────────────┐              ┌──────────────────┐
 │              │   hidraw     │                  │
 │  USB Dongle ─┼──────────►  │  Wine 11.2+      │
 │              │   X11        │  MAXHUB.exe      │
 │  Desktop    ◄┼──────────── │                  │
 │              │              │  (Debian bookworm)│
 └──────────────┘              └──────────────────┘
```

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

Estimated time: **~2-4 minutes** (faster if Docker is already installed)

### What the script does

| Step | Action | Est. time | Touches your packages? |
|:----:|--------|:---------:|:----------------------:|
| 1 | Installs Docker (if not present) | ~1 min | No |
| 2 | Pulls pre-built Wine 11+ image | ~1-2 min | No |
| 3 | Creates udev rule for dongle permissions | ~1 sec | No |
| 4 | Copies MAXHUB.exe from USB drive | ~1 sec | No |
| 5 | Creates desktop launcher + shell script | ~1 sec | No |

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
<summary><b>Docker permission denied</b></summary>

Log out and log back in (or run `newgrp docker`).
The launcher will try to work around this automatically, but logout/login is the clean fix.

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
docker rmi maxhub-dongle
```

</details>

## Technical Details

| | |
|---|---|
| **Device** | MAXHUB WT13 |
| **USB ID** | `1FF7:0F52` |
| **Protocol** | USB HID with TCP/IP tunnel (`dongle_lwip_hid.dll`) |
| **Wine** | 11.2+ in Docker (Debian bookworm base) |
| **Isolation** | Full — Wine never installed on host |
| **Supported** | Ubuntu, Debian, Fedora, CentOS/RHEL, Arch, Manjaro, openSUSE, and more |

## License

[MIT](LICENSE)
