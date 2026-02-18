# MAXHUB Wireless Dongle — Linux Installer

<div dir="rtl">

## הוראות התקנה בעברית

### מה זה?
סקריפט התקנה שמאפשר להשתמש בדונגל MAXHUB WT13 לשיתוף מסך אלחוטי על אובונטו לינוקס.

### למה צריך את זה?
הדונגל של MAXHUB מגיע עם תוכנה לווינדוס בלבד (`MAXHUB.exe`). גרסת Wine הרגילה של אובונטו (9.0) לא עובדת כי ה-UDEV bus שלה לא מזהה את ההתקן. הסקריפט הזה מתקין Wine 11.2+ מה-PPA הרשמי של WineHQ שכולל תמיכה מלאה ב-USB HID.

### דרישות מערכת
- אובונטו 22.04 או 24.04 (64 ביט)
- חיבור לאינטרנט
- דונגל MAXHUB מחובר ב-USB (או העתקה ידנית של MAXHUB.exe)

### התקנה מהירה

</div>

```bash
sudo bash maxhub-linux-install.sh
```

<div dir="rtl">

### מה הסקריפט עושה?
1. מוסיף את מאגר WineHQ ומתקין Wine 11.x+
2. מתקין חוקי udev להרשאות הדונגל
3. מעתיק את MAXHUB.exe מכונן USB (אם מורכב)
4. מאתחל Wine prefix
5. יוצר קיצור דרך בתפריט האפליקציות וסקריפט הפעלה

### הפעלה
אחרי ההתקנה, אפשר להפעיל מתפריט האפליקציות ("MAXHUB Dongle") או מהטרמינל:

</div>

```bash
/opt/maxhub-dongle/maxhub-dongle.sh
```

<div dir="rtl">

### פתרון בעיות

**הדונגל לא מזוהה:**
- נתק וחבר מחדש את הדונגל
- וודא שחוקי udev הותקנו: `cat /etc/udev/rules.d/99-maxhub-dongle.rules`
- טען מחדש: `sudo udevadm control --reload-rules && sudo udevadm trigger`

**Wine לא מותקן או גרסה ישנה:**
- בדוק גרסה: `wine --version` (צריך להיות 11+)
- הרץ מחדש את סקריפט ההתקנה

**MAXHUB.exe לא נמצא:**
- העתק ידנית: `sudo cp /path/to/MAXHUB.exe /opt/maxhub-dongle/`

</div>

---

## English Instructions

### What is this?
An installer script that enables the MAXHUB WT13 wireless screen sharing dongle to work on Ubuntu Linux.

### Why?
The MAXHUB dongle ships with Windows-only software (`MAXHUB.exe`). Ubuntu's default Wine 9.0 doesn't work because its UDEV bus thread doesn't start — Wine never sees the USB HID device. Wine 11.2+ from WineHQ has a working UDEV bus that properly enumerates hidraw devices.

### What it does
- Adds WineHQ PPA and installs Wine 11.x+ (winehq-devel)
- Installs udev rules for dongle permissions (hidraw + USB)
- Copies `MAXHUB.exe` from USB drive (if mounted)
- Initializes a Wine prefix
- Creates a desktop launcher and shell script

### Quick start

```bash
sudo bash maxhub-linux-install.sh
```

### Requirements
- Ubuntu 22.04 or 24.04 (amd64)
- Internet connection (for Wine installation)
- MAXHUB dongle USB drive mounted (or copy `MAXHUB.exe` manually)

### After installation

Launch from the application menu ("MAXHUB Dongle") or run:

```bash
/opt/maxhub-dongle/maxhub-dongle.sh
```

### Troubleshooting

**Dongle not detected:**
- Unplug and replug the dongle
- Verify udev rules: `cat /etc/udev/rules.d/99-maxhub-dongle.rules`
- Reload rules: `sudo udevadm control --reload-rules && sudo udevadm trigger`

**Wine not installed or wrong version:**
- Check version: `wine --version` (should be 11+)
- Re-run the install script

**MAXHUB.exe not found:**
- Copy manually: `sudo cp /path/to/MAXHUB.exe /opt/maxhub-dongle/`

## Technical Details

- **Device:** MAXHUB WT13 (VID: `1FF7`, PID: `0F52`)
- **Protocol:** USB HID with custom TCP/IP tunnel (`dongle_lwip_hid.dll`)
- **Wine requirement:** 11.2+ (working UDEV bus for hidraw enumeration)
- **Tested on:** Ubuntu 24.04 LTS with Wine 11.2
