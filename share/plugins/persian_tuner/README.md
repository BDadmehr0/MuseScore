# Persian Tuner (پلاگین کوک ایرانی)

A MuseScore plugin that tunes notes in **cents** and applies **Persian dastgah presets** with
**koron / sori** quarter-tone accidentals.

این پلاگین یک پنل QML است که هر نت انتخاب‌شده را می‌توان با سنت کوک کرد و پریست‌های دستگاه‌های
ایرانی (همایون، چهارگاه، نوا، شور و…) را روی نت‌ها اعمال می‌کند. در صورت تمایل، نت‌های ربع‌پرده‌ای
را با علامت کُرُن/سُری هم نمایش می‌دهد.

---

## Features

- **Per-note cent tuning** — select notes in the score; each note gets a slider (−100 … +100 cents),
  quick buttons **Kor** (−50), **Sor** (+50), **0**, and live preview while dragging.
- **Dastgah presets** — Mahur, Rast, Homayoun, Chahargah, Nava, Shur, Dashti, Bayat-e Tork,
  Afshari, Abu'ata, Isfahan, Segah — each defined by which scale degrees are koron (♭50 ¢) or sori (♯50 ¢).
  Choose the **tonic** and apply the preset to the selection or the whole score.
- **Koron/Sori accidentals** — optionally set the accidental symbol on quarter-tone notes so they
  are *notated* correctly (in addition to being tuned for playback).
- **Custom presets** — save/load your own preset+tonic combination (persisted via plugin Settings).
- **Undo** — all operations go through `startCmd()/endCmd()` so they can be undone.

> **Note on playback:** per-note `tuning` (in cents) is honored by MuseScore's internal
> synthesizers (Muse Sounds / FluidSynth). Standard MIDI export may not carry micro-tuning.

## Installation (no rebuild needed)

1. Copy this whole folder (`persian_tuner`) into your MuseScore **Plugins** directory.
   - Windows: `%LOCALAPPDATA%\MuseScore\MuseScoreStudio\plugins` (or the one set in
     Edit → Preferences → General → Folders → Plugins).
2. In MuseScore Studio: **Extensions → Manage extensions…**, enable **Persian Tuner**.
3. Run it from **Extensions → Persian Tuner** (a window opens; it refreshes when you change the selection).

If you build MuseScore from source, the plugin is also available in `share/plugins/persian_tuner`.

## Using it with a Persian key signature

The companion C++ change in this branch adds **Persian key signatures** (Homayoun, Chahargah,
Nava, Shur, Isfahan) to the Key Signatures palette. Drag one onto the start of the staff to show
koron symbols in the key signature; then use this plugin to apply the matching micro-tuning to
the notes (and their accidentals).

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

## License

GPL-3.0-only (same as MuseScore).
