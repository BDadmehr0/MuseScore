# Persian Tuner tests

These tests run the **real** plugin
(`share/plugins/persian_tuner/persian_tuner.qml` and its `tunerlogic.js`)
inside a QML engine, against a mock of the MuseScore v1 plugin API. Nothing in
this directory is installed with MuseScore.

```sh
./run_tests.sh          # bootstraps a venv with PySide6 the first time
```

`run_tests.sh` creates a throw-away Python virtualenv (default `~/.venv-qt`,
override with `PERSIAN_TUNER_VENV`) and installs `PySide6-Essentials`, which
provides Qt 6 and its QML engine. If you already have a Qt 6 `qml` runtime you
can also run `run_tests.py` with it.

Exit code: `0` when every assertion passes, `1` on a failure, `2` when the
harness itself could not start.

## How it works

| Path | Role |
| --- | --- |
| `run_tests.py` | Starts a `QQmlApplicationEngine`, publishes the plugin API enumerations (`Element`, `Accidental`, `Placement`, `Align`, `Tid`) as context properties, loads the runner and reports the result. |
| `qml/TestRunner.qml` | Builds mock scores, drives the plugin the way MuseScore would (`run()`, `scoreStateChanged()`, selection changes, widget clicks) and asserts on the outcome. |
| `qml/MockScore.js` | Mock of the plugin API objects the plugin touches: score, measure, segment, chord, note, selection, `startCmd`/`endCmd`. |
| `qml/stubs/MuseScore` | Stub of the `MuseScore 3.0` plugin root type (`curScore`, `newElement`, `removeElement`, `cmd`, `run`, `scoreStateChanged`). |
| `qml/stubs/Muse/Ui` | Stub `Settings` element (values stay in memory). |
| `qml/stubs/Muse/UiComponents` | Stubs of `FlatButton`, `CheckBox`, `StyledTextLabel`, `StyledGroupBox`, `StyledDropdown`, `StyledSlider`, `IncrementalPropertyControl`, mirroring the public surface of the real components. |

The stubs are deliberately thin but faithful where it matters: `CheckBox` does
not toggle itself (the real `MU.CheckBox` only emits `clicked`), and
`IncrementalPropertyControl` emits `valueEdited` while typing and
`valueEditingFinished` when editing ends.

## What is covered

- automatic memory: forward propagation, later and mid-piece overrides,
  being switched off, re-apply, "use remembered", clear
- matching modes: pitch class, pitch class + accidental, per staff
- koron/sori accidentals being written, cleared and never overwriting a
  sharp/flat
- the marker tool: arming, ignoring clicks on rests, placing the sign,
  updating it when the value is entered, listing, deleting
- dastgah presets
- persistence: the memory JSON survives a serialise/parse round trip and old
  scores are pruned
- every score edit is wrapped in exactly one `startCmd`/`endCmd` pair
- toolbar wiring: clicking the check box and the marker button, typing in the
  cents field

## Static check

`qmllint` can be run over the plugin (the stubs are on the import path):

```sh
pyside6-qmllint -I qml/stubs ../../../share/plugins/persian_tuner/persian_tuner.qml
```

It reports "unqualified access" warnings for `Element`, `Accidental`,
`Placement`, `Align`, `Tid`, `curScore`, `cmd`, `newElement` and friends:
those are provided by the real `MuseScore` root type in C++ and cannot be
declared in a QML stub. They are expected; anything else is worth looking at.
