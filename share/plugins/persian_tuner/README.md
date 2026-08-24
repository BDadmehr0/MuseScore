# Persian Tuner (پلاگین کوک ایرانی)

A MuseScore plugin that tunes notes in **cents**, applies **Persian dastgah presets** with
**koron / sori** quarter-tone accidentals — and, so you never have to tune the same note a
thousand times by hand, gives you two tools: **automatic memory** and **markers**.

پلاگین کوک ایرانی برای MuseScore Studio: کوک نت‌ها بر حسب **سنت**، پیش‌تنظیم‌های
**دستگاه‌های ایرانی** با علامت‌های **کُرُن/سُری**، و دو ابزار تا مجبور نباشید یک نت
(مثلاً «فا سری») را هزار بار دستی تنظیم کنید: **حافظه‌ی خودکار** و **نشانگر**.

---

## The problem the two tools solve

In a Persian piece a note like “F sori” can appear thousands of times, and the exact size of
the sori is not a fixed number — you decide it. Retuning every occurrence by hand would be
impossible, so the value is set **once** and the plugin takes care of the rest.

در یک قطعه‌ی ایرانی، نتی مثل «فا سری» ممکن است هزاران بار تکرار شود و اندازه‌ی دقیق
«سری» عدد ثابتی نیست — خودتان تعیینش می‌کنید. تنظیم دستیِ هر occurrence غیرممکن است،
پس مقدار **یک بار** تنظیم می‌شود و بقیه را پلاگین انجام می‌دهد.

---

## 1. Automatic memory — حافظه‌ی خودکار (default: on / پیش‌فرض: روشن)

- The value you enter for a note (e.g. “F sori” = +30 ¢) is remembered.
- From that point on, **everywhere else in the score** where the same note appears, that value
  is applied automatically — you do nothing.
- Change the value somewhere else (say +50 ¢ at measure 40) and the new value takes over
  **from there**; the notes before it stay untouched. One piece can therefore have several
  sections with different tunings.

- مقداری که برای یک نت وارد می‌کنید (مثلاً «فا سری» = ‎+30¢) به خاطر سپرده می‌شود.
- از همان نقطه به بعد، **هر جای دیگری از قطعه** که همان نت بیاید، همان مقدار خودکار
  اعمال می‌شود — بدون هیچ کاری از طرف شما.
- اگر جای دیگری مقدار را عوض کنید (مثلاً در میزان ۴۰ مقدار ‎+50¢)، از همان‌جا به بعد
  مقدار جدید جایگزین می‌شود و نت‌های قبل از آن دست‌نخورده می‌مانند.

The memory is invisible: nothing is added to the page. Use **markers** (below) when the change
should be documented in the score itself.

حافظه نامرئی است: هیچ چیزی روی صفحه اضافه نمی‌شود. اگر می‌خواهید تغییر در خودِ پارتیتور
مستند باشد، از **نشانگر** استفاده کنید.

**Which notes count as “the same note”? / کدام نت‌ها «یک نت» حساب می‌شوند؟**

| Option / گزینه | Behaviour / رفتار |
| --- | --- |
| `Match notes by: Pitch class` (default / پیش‌فرض) | every note of that name, in any octave, whatever accidental it carries |
| `Match notes by: Pitch class + accidental` | only notes carrying the same koron/sori sign |
| `Per staff` | a separate memory for every staff / حافظه‌ی جدا برای هر خط حامل |

**Buttons / دکمه‌ها**

- **Re-apply** — applies the whole memory to the score again (handy after heavy editing).
- **Use remembered** — puts the remembered value on the selected notes.
- **Clear memory** — forgets this score; the tuning already written on the notes is kept.

The memory is stored with the plugin settings and survives restarts.

حافظه همراه تنظیمات پلاگین ذخیره می‌شود و با بسته و باز شدن MuseScore باقی می‌ماند.

---

## 2. Markers — نشانگر (opt-in / اختیاری)

A tool **you activate on purpose**; it leaves a permanent, visible sign in the score.

1. Press the **⚑ Marker** button (the orange dot lights up).
2. Click a note in the score.
3. A small flag is placed above that note right away, the plugin window comes to the front and
   the cents field is focused.
4. Type the value and press Enter — the flag shows that value.

۱. دکمه‌ی **⚑ Marker** را بزنید (نقطه‌ی نارنجی روشن می‌شود).
۲. روی یک نت در پارتیتور کلیک کنید.
۳. همان لحظه یک پرچم کوچک بالای نت ثبت می‌شود، پنجره‌ی پلاگین جلو می‌آید و فیلد سنت
فعال می‌شود.
۴. مقدار را بنویسید و Enter بزنید؛ پرچم همان مقدار را نشان می‌دهد.

Unlike the automatic memory, a marker stays on the page: for you when you reopen the piece
months later, and for anyone reading the score. The **Tuning markers** section lists all of
them with **Go to** (jump to the note) and **Delete**.

برخلاف حافظه‌ی خودکار، نشانگر همیشه روی صفحه می‌ماند: هم برای خودتان وقتی ماه‌ها بعد
قطعه را باز می‌کنید، هم برای هر کسی که نت را می‌خواند. بخش **Tuning markers** فهرست
نشانگرها را با دکمه‌های **Go to** و **Delete** نشان می‌دهد.

---

## Features / امکانات

- **Per-note cent tuning** — a number field (live preview while typing, committed on Enter), a
  slider (−100 … +100 cents) and the quick buttons **Koron −50** / **Natural 0** / **Sori +50**.
- **Dastgah presets** — Mahur, Rast, Homayoun, Chahargah, Nava, Shur, Dashti, Bayat-e Tork,
  Afshari, Abu'ata, Isfahan, Segah — each defined by which scale degrees are koron (−50 ¢) or
  sori (+50 ¢). Choose the **tonic** and apply the preset to the selection or the whole score.
- **Koron/Sori accidentals** — optionally write or clear the accidental symbol on quarter-tone
  notes so they are *notated* correctly (in addition to being tuned for playback).
- **Custom presets** — save/load your own preset+tonic combination (persisted via plugin Settings).
- **Undo** — every operation is wrapped in one `startCmd()/endCmd()` pair, so it can be undone
  in a single step.

> **Note on playback:** per-note `tuning` (in cents) is honored by MuseScore's internal
> synthesizers (Muse Sounds / FluidSynth). Standard MIDI export may not carry micro-tuning.

## Installation (no rebuild needed)

1. Copy this whole folder (`persian_tuner`) into your MuseScore **Plugins** directory.
   - Windows: `%LOCALAPPDATA%\MuseScore\MuseScoreStudio\plugins` (or the one set in
     Edit → Preferences → General → Folders → Plugins).
2. In MuseScore Studio: **Extensions → Manage extensions…**, enable **Persian Tuner**.
3. Run it from **Extensions → Persian Tuner** (the window stays open and refreshes when you
   change the selection).

If you build MuseScore from source, the plugin is also available in `share/plugins/persian_tuner`.

## Notation

This plugin is self-contained: it applies **playback tuning** (cents) and can optionally write
**koron / sori accidentals** and **⚑ markers** on the notes. It does not add custom Persian key
signatures to MuseScore's palettes — use the accidentals (or a custom key signature) if you want
them shown in the staff.

Markers are ordinary text elements attached to a note, so they can be moved, restyled or deleted
in MuseScore like any other text.

## Preset values (editable)

Presets use 24-TET approximations: koron = −50 ¢, sori = +50 ¢ on the marked scale degrees
(1=C, 2=D, 3=E, 4=F, 5=G, 6=A, 7=B relative to the chosen tonic):

| Dastgah            | koron degrees |
|--------------------|---------------|
| Mahur / Rast       | — (diatonic)  |
| Homayoun           | 2, 6          |
| Chahargah          | 2, 4, 6       |
| Nava               | 3, 7          |
| Shur / Dashti / Bayat-e Tork / Afshari / Abu'ata | 2 |
| Isfahan            | 2, 6          |
| Segah              | 3             |

There are different performance traditions for some dastgahs — adjust the cents per note in the
panel and use **Save preset** to keep your own version.

## For developers / برای توسعه‌دهنده‌ها

- `tunerlogic.js` holds the pure logic (memory timeline, note keys, marker text, presets) and has
  no Qt/MuseScore dependency.
- Tests live in `tools/persian_tuner_tests` and run the real plugin inside a QML engine against a
  mock of the plugin API:

```sh
./tools/persian_tuner_tests/run_tests.sh
```

## License

GPL-3.0-only (same as MuseScore).
