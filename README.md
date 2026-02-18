# MAXHUB Wireless Dongle — Linux Installer

[![Ubuntu 22.04](https://img.shields.io/badge/Ubuntu-22.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Ubuntu 24.04](https://img.shields.io/badge/Ubuntu-24.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Wine 11+](https://img.shields.io/badge/Wine-11.2+-722F37?logo=wine&logoColor=white)](https://www.winehq.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

One-command installer for the **MAXHUB WT13** wireless screen sharing dongle on Ubuntu Linux.

<div dir="rtl">

## עברית

### מה זה?
סקריפט התקנה שמאפשר להשתמש בדונגל **MAXHUB WT13** לשיתוף מסך אלחוטי על אובונטו לינוקס.

### למה צריך את זה?
הדונגל של MAXHUB מגיע עם תוכנה לווינדוס בלבד (MAXHUB.exe).
גרסת Wine הרגילה של אובונטו (9.0) לא עובדת — ה-UDEV bus שלה לא נטען, ו-Wine לא רואה את ההתקן USB HID.

הסקריפט הזה מתקין **Wine 11.2+** מה-PPA הרשמי של WineHQ, שכולל תמיכה מלאה ב-UDEV ובהתקני hidraw.

### דרישות מערכת
- אובונטו 22.04 או 24.04 (64 ביט)
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

### מה הסקריפט עושה?

| שלב | פעולה | משנה דברים קיימים? |
|:---:|-------|:-------------------:|
| 1 | מוסיף את מאגר WineHQ + מפתח GPG | לא |
| 2 | מתקין Wine 11.x+ (winehq-devel) | לא* |
| 3 | יוצר udev rule להרשאות הדונגל | לא |
| 4 | מעתיק MAXHUB.exe מכונן USB | לא |
| 5 | מאתחל Wine prefix | לא |
| 6 | יוצר קיצור דרך + סקריפט הפעלה | לא |

\* אם יש התנגשות עם חבילות Wine קיימות, הסקריפט **לא ימחק אותן** — הוא יציג הודעה מפורטת עם הוראות לתיקון ידני.

### הפעלה
אחרי ההתקנה, הפעילו מתפריט האפליקציות ("MAXHUB Dongle") או מהטרמינל:

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
<summary><b>Wine לא מותקן או גרסה ישנה</b></summary>

1. בדקו גרסה:
   ```bash
   wine --version
   ```
   צריך להיות **11 ומעלה**.
2. אם הגרסה ישנה, הריצו מחדש את סקריפט ההתקנה.

</details>

<details>
<summary><b>שגיאת "held broken packages" בהתקנה</b></summary>

הסקריפט יזהה את הבעיה ויציג לכם בדיוק מה לעשות. בדרך כלל זה בגלל חבילות Wine ישנות. הסקריפט **לא ימחק** אותן — הוא יגיד לכם אילו חבילות מתנגשות ויתן לכם להחליט.

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
Wine ישאר מותקן — הסירו אותו בנפרד אם תרצו:
```bash
sudo apt remove winehq-devel
```

</details>

</div>

---

## English

### What is this?
An installer script for the **MAXHUB WT13** wireless screen sharing dongle on Ubuntu Linux.

### Why?
The MAXHUB dongle ships with Windows-only software (MAXHUB.exe). Ubuntu's default Wine 9.0 doesn't work because its UDEV bus thread doesn't start — Wine never sees the USB HID device. Wine 11.2+ from WineHQ has a working UDEV bus that properly enumerates hidraw devices.

### Requirements
- Ubuntu 22.04 or 24.04 (amd64)
- Internet connection
- MAXHUB dongle USB drive (or manual copy of MAXHUB.exe)

### Installation

```bash
git clone https://github.com/ysdy823/MAXHUB-LINUX.git
cd MAXHUB-LINUX
sudo bash maxhub-linux-install.sh
```

### What the script does

| Step | Action | Modifies existing? |
|:----:|--------|:------------------:|
| 1 | Adds WineHQ repository + GPG key | No |
| 2 | Installs Wine 11.x+ (winehq-devel) | No* |
| 3 | Creates udev rule for dongle permissions | No |
| 4 | Copies MAXHUB.exe from USB drive | No |
| 5 | Initializes Wine prefix | No |
| 6 | Creates desktop launcher + shell script | No |

\* If conflicting Wine packages are found, the script will **not remove them** — it will display a detailed message explaining what conflicts and how to resolve it manually.

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
<summary><b>"held broken packages" error</b></summary>

The script will detect the issue and show you exactly what to do. It will **never** remove your existing packages without your consent.

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
| **Wine requirement** | 11.2+ (working UDEV bus for hidraw) |
| **Tested on** | Ubuntu 22.04, Ubuntu 24.04, Wine 11.2 |

## License

[MIT](LICENSE)
