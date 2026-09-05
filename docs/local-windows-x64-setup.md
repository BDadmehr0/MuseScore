# ساخت نصبکننده (Setup) ویندوز ۶۴ بیتی از همین نسخه و برنچ، بهصورت لوکال

## مهمترین نکته

- این پروژه (MuseScore / Persian Timer) برای ویندوز **از داخل لینوکس کراس‌کامپایل نمی‌شود**. ساخت نصب‌کننده‌ی `.msi` و `.paf.exe` باید روی یک **ویندوز ۱۰/۱۱ ۶۴ بیتی** (یا ویندوز CI) انجام شود.
- نسخه‌ی فعلی همین چک‌اوت: commit `5c2dda2c08e8c15451da5261092d4bef1bb2fbd7` روی شاخه‌ی محلی `arena/01a07340-musescore`.
- همین commit دقیقاً الان روی شاخه‌ی `origin/persian-tuner` هم هست، بنابراین برای گرفتن «همین نسخه» روی سیستم‌تان کافی است `persian-tuner` را checkout کنید.
- خروجی‌های قابل ساخت:
  - `MuseScore-Studio-<version>.<build>-x86_64.msi` → نصب‌کننده‌ی کلاسیک
  - `MuseScore-Studio-<version>.<build>-x86_64.paf.exe` → نسخه‌ی PortableApps
  - برای build های `devel/nightly` به‌جای MSI، یک `.7z` ساخته می‌شود.

---

## ۱) پیش‌نیازهای ویندوز ۶۴ بیتی

حدود **۳۰–۵۰ گیگابایت فضای خالی** و ترجیحاً **۱۶ گیگابایت RAM** توصیه می‌شود.

| ابزار | توضیح |
|---|---|
| Git for Windows | شامل Git Bash، `curl` و `bash` |
| Visual Studio 2022 / Build Tools | workload «Desktop development with C++»، MSVC v143 x64/x86، Windows 11 SDK (مثلاً 10.0.26100) |
| CMake ≥ 3.28 | برای MSI و ساخت |
| Ninja | برای بیلد سریع‌تر (همان‌طوری که CI استفاده می‌کند) |
| Qt 6.10.2 `win64_msvc2022_64` | ماژول‌ها: `qt5compat`, `qtnetworkauth`, `qtshadertools`, `qtwebsockets` |
| WiX Toolset v3.x | مسیر پیش‌فرض: `C:\Program Files\WiX Toolset v3.11` |
| 7-Zip | برای اسکریپت `setup.bat` |

با `choco` (پاورشل ادمین) می‌توانید این‌ها را نصب کنید:

```powershell
choco install git cmake ninja 7zip wixtoolset -y
```

### نصب Qt (دو راه)

**راه A – Qt Online Installer (پیشنهادی):**
Qt 6.10.2 را انتخاب کنید، بخش «Desktop» → «MSVC 2022 64-bit» و ماژول‌های
`Qt 5 Compatibility Module`, `Qt Network Authorization`, `Qt Shader Tools`, `Qt WebSockets`
را تیک بزنید.

مسیر نصب پیشنهادی:

```
C:\Qt\6.10.2\msvc2022_64
```

**راه B – با `aqtinstall`:**

```powershell
pip install aqtinstall
aqt install-qt windows desktop 6.10.2 win64_msvc2022_64 -O C:\Qt
```

سپس ماژول‌های لازم را از Qt Online Installer اضافه کنید (یا از `-m qt5compat,qtnetworkauth,qtshadertools,qtwebsockets` استفاده کنید).

---

## ۲) گرفتن سورس (همین نسخه)

در `cmd` یا `Git Bash`:

```bash
git clone --recurse-submodules https://github.com/BDadmehr0/MuseScore.git
cd MuseScore

# همین commit فعلی (5c2dda2):
git checkout persian-tuner
git pull origin persian-tuner

# اگر می‌خواهید دقیقاً شاخه‌ی arena/01a07340-musescore را بگیرید:
# git fetch origin arena/01a07340-musescore
# git checkout arena/01a07340-musescore

# ساب‌ماژول‌ها (muse_framework و muse_deps) مثل CI باید گرفته شوند:
git submodule update --init --recursive

# بررسی نسخه:
git rev-parse HEAD
# باید خروجی: 5c2dda2c08e8c15451da5261092d4bef1bb2fbd7
```

> نکته: شاخه‌ی محلی `arena/01a07340-musescore` همین الان هیچ commit اضافه‌ای نسبت به `persian-tuner` ندارد، پس `persian-tuner` دقیقاً همان سورس است.

---

## ۳) آماده‌سازی محیط بیلد (فقط یک‌بار)

یک **cmd ادمین** باز کنید و متغیرها را ست کنید (برای هر ترمینال جدید دوباره لازم است):

```bat
set QT_DIR=C:\Qt\6.10.2\msvc2022_64
set QTDIR=%QT_DIR%
set PATH=%QTDIR%\bin;%PATH%
set WIX=C:\Program Files\WiX Toolset v3.11
set PATH=%WIX%;%PATH%
cd /d C:\MuseScore
```

### دانلود وابستگی‌های ویندوز (اسکریپت CI)

```bat
buildscripts\ci\windows\setup.bat
```

این اسکریپت این‌ها را می‌آورد:
- `Jack` به `C:\Program Files (x86)\Jack`
- وابستگی‌های کلی (شامل KDDockWidgets / فونت‌ها و...) به `C:\musescore_dependencies`

اگر می‌خواهید نسخه‌ی **PortableApps** بسازید، به‌جای بالا:

```bat
buildscripts\ci\windows\setup.bat --portable ON
```

---

## ۴) ساخت فایل‌های build metadata

در **Git Bash** داخل ریشه‌ی پروژه (پوشه‌ی `MuseScore`):

```bash
bash buildscripts/ci/tools/make_build_mode_env.sh -e workflow_dispatch -m stable
bash buildscripts/ci/tools/make_build_number.sh 2026090501
```

- `stable` → خروجی `.msi`
- `devel` یا `nightly` → خروجی `.7z`
- `testing` → خروجی `.msi` (اما channel مختلف)

---

## ۵) بیلد و نصب برنامه

این‌جا همان دستور CI است (ساخت `RelWithDebInfo` و کپی در پوشه‌ی install):

```bat
buildscripts\ci\windows\build.bat -n 2026090501 --dockwidgets_v2 ON
```

برای **PortableApps**:

```bat
buildscripts\ci\windows\build.bat -n 2026090501 --dockwidgets_v2 ON --portable ON
```

اگر می‌خواهید فقط exe را بدون بسته‌بندی تست کنید، بعد از بیلد این‌جا قرار دارد:

```
C:\MuseScore\build.install\bin\MuseScoreStudio5.exe
```

---

## ۶) ساخت نصب‌کننده (Setup)

### الف) MSI (نصب‌کننده‌ی کلاسیک)

```bat
buildscripts\ci\windows\package.bat -m stable --guid 11111111-1111-1111-1111-111111111111
```

خروجی:

```
build.artifacts\MuseScore-Studio-1.0.1.2026090501-x86_64.msi
```

> نکته: اسکریپت `package.bat` برای ساخت GUID از
> `C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\uuidgen.exe`
> استفاده می‌کند. اگر مسیر Windows SDK شما متفاوت است، یا این `uuidgen.exe` وجود ندارد،
> در `buildscripts\ci\windows\package.bat` این خط را با مسیر `uuidgen.exe` سیستم خودتان اصلاح کنید
> یا با یک GUID ثابت مستقیم CMake را صدا بزنید.

### ب) PortableApps (`.paf.exe`)

```bat
buildscripts\ci\windows\package.bat -m stable --portable ON --guid 11111111-1111-1111-1111-111111111111
```

خروجی:

```
build.artifacts\MuseScore-Studio-1.0.1.2026090501-x86_64.paf.exe
```

---

## ۷) چک‌سام / امضا

- اگر key امضای اینترنتی (Azure S3 / code signing) نداشته باشید، `package.bat` می‌نویسد `warning: not set SIGN_KEY` و MSI/PAF را **بدون امضا** می‌سازد.
- بدون امضا هم نصب می‌شود، فقط ویندوز ممکن است SmartScreen یا هشدار «unknown publisher» بدهد — طبیعی است.

برای ساخت `checksums.sha256.txt`:

```bash
bash buildscripts/ci/tools/checksum.sh
```

---

## ۸) اگر ساخت در UI سخت است: از GitHub Actions استفاده کنید (سریع‌تر)

اگر فقط فایل آماده می‌خواهید، این پایپ‌لاین همان بیلد محلی را روی سرورهای GitHub انجام می‌دهد (و راحت‌تر است):

1. در GitHub بروید به **Actions → Build: Windows**
2. **Run workflow**
3. `platforms = windows_x64 windows_portable`
4. `build_mode = stable` (برای MSI/PAF) یا `devel/nightly`
5. بعد از اتمام، **Artifacts** را دانلود کنید: `MU4_...Win...`.

یا با پایپ‌لاین **Release: Persian Tuner** یک GitHub Release کامل با MSI/PAF و checksum می‌گیرید.

---

## ۹) زمان و منابع

- اولین بیلد کامل معمولاً **۲ تا ۴+ ساعت** زمان می‌برد (اعم از داونلود وابستگی‌ها، کامپایل Qt modules، Ninja build، MSI).
- مقدار قابل توجهی فضای دیسک مصرف می‌شود؛ پوشه‌های `build.release`, `build.install`, `build.artifacts`, `msvc.build`, `msvc.install` را می‌توانید بعداً پاک کنید.
