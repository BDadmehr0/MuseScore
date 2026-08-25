/*
 * Persian Tuner - dock panel like Mixer, dark theme from cent-tuning-panel.html
 * Sign-oriented: letter + accidental variant, cents relative to natural
 * Ribbon tab: tuner-ribbon-tab.html
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import Muse.Ui
import Muse.UiComponents as MU

import MuseScore 3.0

import "tunerlogic.js" as Logic

MuseScore {
    id: root

    version: "4.0.0"
    title: qsTr("Persian Tuner")
    description: qsTr("Dockable Persian tuner - mixer-like panel, cent tuning per sign relative to natural")
    // Dock like mixer, not separate window
    pluginType: "dock"
    dockArea: "right"
    implicitWidth: 480
    implicitHeight: 800
    // For dock, width/height are initial, but we also set window size for dialog fallback
    width: 480
    height: 900

    categoryCode: "playback"
    thumbnailName: "persian_tuner.png"
    requiresScore: false

    // Data
    property var pcNames: Logic.PITCH_CLASS_NAMES
    property int tonicPc: 0
    property var presets: [
        { name: "Mahur", koron: [], sori: [] },
        { name: "Rast", koron: [], sori: [] },
        { name: "Homayoun", koron: [2, 6], sori: [] },
        { name: "Chahargah", koron: [2, 4, 6], sori: [] },
        { name: "Nava", koron: [3, 7], sori: [] },
        { name: "Shur", koron: [2], sori: [] }
    ]

    property var noteLetters: Logic.NOTE_LETTERS
    property var variantIds: ["flat", "koron", "natural", "sori", "sharp"]
    property string selectedLetter: "A"
    property string selectedVariant: "sori"
    property int selectedOctave: 4
    property var tuningTable: Logic.defaultTuningTable()

    // reference
    property int refOctave: 4
    property string refLetter: "A"
    property double refFreq: 440.0

    // current target cents relative to natural of selected letter
    property double currentCents: 50

    // Tools
    property bool autoMemory: true
    property bool addAccidentals: false
    property bool matchAccidental: true
    property bool perStaffMemory: false
    property bool markerToolArmed: false
    property var pendingMarker: null

    // Runtime
    property var noteObjects: []
    property var markerEntries: []
    property var memoryStore: Logic.newStore()
    property string scoreId: ""
    property int memoryCounter: 0
    readonly property int noMemoryValue: -99999

    // Settings
    Settings {
        id: options
        category: "Persian Tuner"
        property var autoMemory: '1'
        property var accidentals: '0'
        property var matchAccidental: '1'
        property var perStaffMemory: '0'
        property var memory: '{}'
        property var tuningTableJson: ''
        property var refFreq: '440'
    }

    // Theme colors from HTML
    readonly property color bgPage: "#0b0f14"
    readonly property color bgPanel: "#121821"
    readonly property color bgCard: "#0f151c"
    readonly property color bgBtn: "#1a222c"
    readonly property color bgBtnHover: "#232d39"
    readonly property color border: "#232b36"
    readonly property color borderStrong: "#2e3947"
    readonly property color textPrimary: "#e8ecf1"
    readonly property color textSecondary: "#9aa6b4"
    readonly property color textMuted: "#5f6b7a"
    readonly property color accent: "#2ee6b8"
    readonly property color accentDim: "#12352e"

    function boolFromSetting(v, fb) {
        if (v === undefined || v === null || v === "") return fb
        if (typeof v === "boolean") return v
        return String(v) !== '0'
    }

    function loadSettings() {
        autoMemory = boolFromSetting(options.autoMemory, true)
        addAccidentals = boolFromSetting(options.accidentals, false)
        matchAccidental = boolFromSetting(options.matchAccidental, true)
        perStaffMemory = boolFromSetting(options.perStaffMemory, false)
        tuningTable = Logic.parseTuningTable(options.tuningTableJson)
        var rf = parseFloat(options.refFreq)
        if (!isNaN(rf) && rf > 0) refFreq = rf
    }

    function saveSettings() {
        options.autoMemory = autoMemory ? '1' : '0'
        options.accidentals = addAccidentals ? '1' : '0'
        options.matchAccidental = matchAccidental ? '1' : '0'
        options.perStaffMemory = perStaffMemory ? '1' : '0'
        options.memory = Logic.serializeStore(memoryStore)
        options.tuningTableJson = Logic.serializeTuningTable(tuningTable)
        options.refFreq = String(refFreq)
    }

    function status(msg) {
        statusLabel.text = msg
        statusTimer.restart()
    }

    function round1(v) { return Math.round(v * 10) / 10 }

    function syncAccidentalConstants() {
        try {
            Logic.ACC_NONE = 0 + Accidental.NONE
            Logic.ACC_NATURAL = 0 + Accidental.NATURAL
            Logic.ACC_FLAT = 0 + Accidental.FLAT
            Logic.ACC_SHARP = 0 + Accidental.SHARP
            Logic.ACC_SORI = 0 + Accidental.SORI
            Logic.ACC_KORON = 0 + Accidental.KORON
        } catch (e) {}
    }

    function accidentalValue(note) { return Logic.normalizeAccidental(note.accidentalType, Accidental) }
    function settingsJson() { return options.memory }
    function currentScoreId() {
        if (!curScore) return ""
        var id = ""
        try { id = curScore.scoreName } catch (e) {}
        if (!id) id = curScore.title
        return id ? id : "score"
    }
    function ensureScoreMemory() {
        var id = currentScoreId()
        if (id !== scoreId) {
            scoreId = id
            memoryStore = Logic.parseStore(options.memory)
        }
        return id
    }
    function noteTick(note) { var f = note.fraction; return f ? f.ticks : 0 }
    function noteStaffIdx(note) { var idx = note.staffIdx; return (idx === undefined || idx === null) ? 0 : idx }
    function noteIdentity(note) { return Logic.noteIdentityFromNote(note, Accidental) }
    function memoryKeyFor(note) {
        var ident = noteIdentity(note)
        var staff = noteStaffIdx(note)
        if (!matchAccidental) {
            var k = ident.letter
            if (perStaffMemory) k += "@s" + staff
            return k
        }
        return Logic.makeSignKey(ident.letter, ident.variant, staff, { perStaff: perStaffMemory })
    }
    function signKeyFor(letter, variant, staffIdx) {
        return Logic.makeSignKey(letter, variant, staffIdx || 0, { perStaff: perStaffMemory })
    }
    function letterFa(letter) { return Logic.NOTE_LETTER_PERSIAN[letter] || letter }
    function letterFullFa(letter) { return Logic.NOTE_LETTER_PERSIAN_FULL[letter] || letter }
    function variantFa(variant) { return Logic.labelFaForVariant(variant) }
    function variantSymbol(variant) { return Logic.symbolForVariant(variant) }
    function baseCentsForVariant(variant) { return Logic.baseCentsForVariant(variant) }
    function getTableCents(letter, variant) { return Logic.getTuning(tuningTable, letter, variant) }
    function effectiveTargetForNote(note) {
        var id = ensureScoreMemory()
        var key = memoryKeyFor(note)
        var tick = noteTick(note)
        var mem = Logic.resolveCents(memoryStore, id, key, tick)
        if (mem !== null) return round1(mem)
        var ident = noteIdentity(note)
        return round1(getTableCents(ident.letter, ident.variant))
    }
    function noteLabelShort(note) {
        var ident = noteIdentity(note)
        var octave = Math.floor(note.pitch / 12) - 1
        return ident.letter + " " + variantFa(ident.variant) + " " + octave
    }
    function measureNumberFor(note) {
        try { var chord = note.parent; var measure = chord ? chord.measure : null; if (measure) return measure.measureNumber } catch (e) {}
        return 0
    }
    function selectedNotes() {
        var result = []
        if (!curScore) return result
        var elements = curScore.selection.elements
        for (var i = 0; i < elements.length; ++i) {
            var el = elements[i]
            if (el.type == Element.NOTE && el.parent && el.parent.type == Element.CHORD) result.push(el)
        }
        return result
    }
    function firstSelectedNote() { var notes = selectedNotes(); return notes.length > 0 ? notes[0] : null }
    function collectScoreNotes() {
        var result = []
        if (!curScore) return result
        var ntracks = curScore.ntracks
        var measure = curScore.firstMeasure
        var guard = 0
        while (measure && guard < 100000) {
            var segment = measure.firstSegment
            var sguard = 0
            while (segment && sguard < 100000) {
                for (var track = 0; track < ntracks; ++track) {
                    var el = segment.elementAt(track)
                    if (el && el.type == Element.CHORD) {
                        var notes = el.notes
                        for (var n = 0; n < notes.length; ++n) result.push(notes[n])
                    }
                }
                segment = segment.nextInMeasure
                ++sguard
            }
            measure = measure.nextMeasure
            ++guard
        }
        return result
    }

    function tuneNotes(notes, targetCents) {
        for (var i = 0; i < notes.length; ++i) {
            var note = notes[i]
            var current = accidentalValue(note)
            if (addAccidentals) {
                var intended = current
                if (targetCents <= -75) intended = Accidental.FLAT
                else if (targetCents <= -25) intended = Accidental.KORON
                else if (targetCents < 25) intended = Accidental.NATURAL
                else if (targetCents <= 75) intended = Accidental.SORI
                else intended = Accidental.SHARP
                try { if (intended !== current) note.accidentalType = intended } catch (e) {}
            }
            var newIdent = noteIdentity(note)
            var required = targetCents - newIdent.baseCents
            note.tuning = round1(required)
        }
        return notes.length
    }

    function rememberAndPropagate(notes, targetCents) {
        if (notes.length === 0) return 0
        var id = ensureScoreMemory()
        var startTicks = {}
        var keyOrder = []
        for (var i = 0; i < notes.length; ++i) {
            var key = memoryKeyFor(notes[i])
            var tick = noteTick(notes[i])
            if (startTicks[key] === undefined) { startTicks[key] = tick; keyOrder.push(key) }
            else if (tick < startTicks[key]) startTicks[key] = tick
        }
        var allNotes = collectScoreNotes()
        var meta = []
        for (var m = 0; m < allNotes.length; ++m) meta.push({ key: memoryKeyFor(allNotes[m]), tick: noteTick(allNotes[m]) })
        var applied = 0
        for (var k = 0; k < keyOrder.length; ++k) {
            var memoryKey = keyOrder[k]
            var range = Logic.setChange(memoryStore, id, memoryKey, startTicks[memoryKey], targetCents)
            var indices = Logic.indicesToTune(meta, memoryKey, range)
            for (var n = 0; n < indices.length; ++n) applied += tuneNotes([allNotes[indices[n]]], targetCents)
        }
        return applied
    }

    // Frequency calc: midi = letter to semitone + octave*12 + accidental base/100
    function midiFromLetterOctaveVariant(letter, octave, variant) {
        var baseSemitone = { "C":0, "D":2, "E":4, "F":5, "G":7, "A":9, "B":11 }[letter]
        if (baseSemitone === undefined) baseSemitone = 0
        var midi = (octave + 1) * 12 + baseSemitone
        // variant base cents already relative to natural, but for midi we need semitone offset: flat -1, sharp +1, koron/sori 0 (quarter)
        var vBase = baseCentsForVariant(variant)
        // for midi, only full semitone shifts count for pitch class, quarter stays
        if (variant === "flat") midi -= 1
        else if (variant === "sharp") midi += 1
        return midi
    }

    function calcFreq(letter, octave, variant, centsRelativeToNatural, refFreq) {
        // centsRelativeToNatural is target, e.g. 50 for sori
        // base midi for natural of that letter
        var naturalMidi = midiFromLetterOctaveVariant(letter, octave, "natural")
        var targetMidiFloat = naturalMidi + centsRelativeToNatural / 100.0
        // A4 = 69 midi = refFreq
        var refMidi = 69 // A4
        var diff = targetMidiFloat - refMidi
        return refFreq * Math.pow(2, diff / 12.0)
    }

    function refreshNotes() {
        notesModel.clear()
        noteObjects = []
        if (!curScore) {
            selectionSummary.text = "هیچ نتی انتخاب نشده"
            return
        }
        var notes = selectedNotes()
        for (var i = 0; i < notes.length; ++i) {
            var note = notes[i]
            noteObjects.push(note)
            var ident = noteIdentity(note)
            var target = effectiveTargetForNote(note)
            notesModel.append({
                idx: i,
                label: noteLabelShort(note),
                letter: ident.letter,
                variant: ident.variant,
                cents: round1(target)
            })
        }
        if (notes.length > 0) {
            var first = notes[0]
            var ident0 = noteIdentity(first)
            selectedLetter = ident0.letter
            selectedVariant = ident0.variant
            selectedOctave = Math.floor(first.pitch / 12) - 1
            currentCents = effectiveTargetForNote(first)
            // update UI dropdowns
            octaveDropdown.currentIndex = Math.max(0, Math.min(octaveModel.count - 1, selectedOctave - 3))
            noteDropdown.currentIndex = noteLetters.indexOf(selectedLetter)
            variantDropdown.currentIndex = variantIds.indexOf(selectedVariant)
            selectionSummary.text = noteLabelShort(first) + " - هدف: " + currentCents + "¢ نسبت به " + letterFa(selectedLetter) + " بکار"
            refreshTuningTableControls()
        } else {
            selectionSummary.text = "هیچ نتی انتخاب نشده - یک نت را در پارتیتور انتخاب کنید"
        }
    }

    function refreshTuningTableControls() {
        tableModel.clear()
        for (var i = 0; i < variantIds.length; ++i) {
            var vid = variantIds[i]
            var cents = getTableCents(selectedLetter, vid)
            tableModel.append({ variant: vid, cents: round1(cents) })
        }
        // update current display
        var curTarget = getTableCents(selectedLetter, selectedVariant)
        currentCents = curTarget
        centsSlider.value = curTarget
        centsLabel.text = (curTarget > 0 ? "+" : "") + curTarget
        refNoteLabel.text = "سنت نسبت به " + letterFa(selectedLetter) + " طبیعی"
        // hint
        var hint = ""
        if (selectedVariant === "sori") hint = "مقدار مرسوم سری معمولاً +50 سنت است — این فقط نقطه شروع است"
        else if (selectedVariant === "koron") hint = "مقدار مرسوم کرن معمولاً -50 سنت است"
        else if (selectedVariant === "flat") hint = "بمل معمولاً -100 سنت نسبت به بکار"
        else if (selectedVariant === "sharp") hint = "دیز معمولاً +100 سنت"
        else hint = "بکار مبنا است: 0 سنت"
        hintLabel.text = hint
        var freq = calcFreq(selectedLetter, selectedOctave, selectedVariant, curTarget, refFreq)
        hzLabel.text = freq.toFixed(1) + " Hz"
        currentBadgeLabel.text = letterFa(selectedLetter) + " " + variantFa(selectedVariant)
    }

    function previewCents(targetCents) {
        if (!curScore) return
        var notes = selectedNotes()
        for (var i = 0; i < notes.length; ++i) {
            var ident = noteIdentity(notes[i])
            notes[i].tuning = round1(targetCents - ident.baseCents)
        }
    }

    function commitCents(targetCents) {
        if (!curScore) return false
        var notes = selectedNotes()
        if (notes.length === 0) {
            // if no selection, update table only
            setTableCents(selectedLetter, selectedVariant, targetCents)
            return true
        }
        targetCents = round1(targetCents)
        curScore.startCmd(qsTr("Tune notes"))
        tuneNotes(notes, targetCents)
        var applied = notes.length
        if (autoMemory) applied = rememberAndPropagate(notes, targetCents)
        if (pendingMarker) { pendingMarker.text = Logic.markerText(targetCents); pendingMarker = null }
        curScore.endCmd()
        saveSettings()
        memoryCounter = memoryCount()
        refreshNotes()
        refreshMarkers()
        status(autoMemory ? "%1 نت کوک شد".arg(applied) : "%1 نت".arg(notes.length))
        return true
    }

    function setTableCents(letter, variant, cents) {
        cents = round1(cents)
        Logic.setTuning(tuningTable, letter, variant, cents)
        saveSettings()
        var id = ensureScoreMemory()
        var key = signKeyFor(letter, variant, 0)
        Logic.setChange(memoryStore, id, key, 0, cents)
        saveSettings()
        memoryCounter = memoryCount()
        if (curScore) {
            curScore.startCmd(qsTr("Update tuning table"))
            var allNotes = collectScoreNotes()
            var meta = []
            for (var m = 0; m < allNotes.length; ++m) meta.push({ key: memoryKeyFor(allNotes[m]), tick: noteTick(allNotes[m]) })
            var changes = Logic.changesFor(memoryStore, id, key)
            var range = { from: 0, to: changes.length > 1 ? changes[1].t : null }
            var indices = Logic.indicesToTune(meta, key, range)
            for (var n = 0; n < indices.length; ++n) tuneNotes([allNotes[indices[n]]], cents)
            curScore.endCmd()
        }
        refreshNotes()
        refreshTuningTableControls()
        refreshMarkers()
        status(letter + " " + variantFa(variant) + " = " + cents + "¢")
    }

    function memoryCount() { return Logic.countChanges(memoryStore, ensureScoreMemory()) }

    function toggleMarkerTool() {
        markerToolArmed = !markerToolArmed
        if (markerToolArmed) status("ابزار مارکر فعال: روی نت کلیک کنید")
        else { pendingMarker = null; status("مارکر لغو شد") }
    }

    function placeMarker(note, targetCents) {
        if (!curScore || !note) return null
        var element = newElement(Element.TEXT)
        if (!element) return null
        element.text = Logic.markerText(targetCents)
        element.subStyle = Tid.STAFF
        element.placement = Placement.ABOVE
        element.align = Align.BASELINE
        curScore.startCmd(qsTr("Add tuning marker"))
        note.add(element)
        curScore.endCmd()
        refreshMarkers()
        return element
    }

    function handleMarkerClick() {
        var note = firstSelectedNote()
        if (!note) { status("روی نت کلیک کنید"); return false }
        var target = effectiveTargetForNote(note)
        var element = placeMarker(note, target)
        if (!element) return false
        markerToolArmed = false
        pendingMarker = element
        var ident = noteIdentity(note)
        selectedLetter = ident.letter
        selectedVariant = ident.variant
        selectedOctave = Math.floor(note.pitch / 12) - 1
        currentCents = target
        refreshTuningTableControls()
        status("مارکر اضافه شد")
        try { var win = root.Window.window; if (win) { win.raise(); win.requestActivate() } } catch (e) {}
        return true
    }

    function refreshMarkers() {
        markersModel.clear()
        markerEntries = []
        if (!curScore) return
        var notes = collectScoreNotes()
        for (var i = 0; i < notes.length; ++i) {
            var note = notes[i]
            var elements = note.elements
            for (var e = 0; e < elements.length; ++e) {
                var el = elements[e]
                if (el.type != Element.TEXT) continue
                var parsed = Logic.parseMarkerText(el.text)
                if (!parsed) continue
                markerEntries.push({ note: note, element: el })
                markersModel.append({ idx: markerEntries.length - 1, label: "میزان " + measureNumberFor(note) + " - " + noteLabelShort(note), cents: round1(parsed.cents) })
            }
        }
    }

    function gotoMarker(index) {
        if (index < 0 || index >= markerEntries.length) return
        var entry = markerEntries[index]
        if (curScore.selection.select(entry.note)) refreshNotes()
        curScore.showElementInScore(entry.note)
    }
    function removeMarker(index) {
        if (index < 0 || index >= markerEntries.length) return
        var entry = markerEntries[index]
        curScore.startCmd(qsTr("Remove tuning marker"))
        try { entry.note.remove(entry.element) } catch (e) { removeElement(entry.element) }
        curScore.endCmd()
        if (pendingMarker && pendingMarker === entry.element) pendingMarker = null
        refreshMarkers()
    }
    function removeAllMarkers() {
        if (markerEntries.length === 0) return
        var entries = markerEntries
        curScore.startCmd(qsTr("Remove tuning markers"))
        for (var i = 0; i < entries.length; ++i) {
            try { entries[i].note.remove(entries[i].element) } catch (e) { removeElement(entries[i].element) }
        }
        curScore.endCmd()
        pendingMarker = null
        refreshMarkers()
    }

    function applyPresetAt(presetIndex, wholeScore) {
        if (!curScore) return
        if (presetIndex < 0 || presetIndex >= presets.length) return
        if (wholeScore || curScore.selection.elements.length === 0) {
            curScore.startCmd(qsTr("Apply Persian tuning to score"))
            cmd("select-all")
        } else curScore.startCmd(qsTr("Apply Persian tuning to selection"))
        var offsets = Logic.offsetsForPreset(presets[presetIndex])
        var tonic = root.tonicPc
        var chords = []
        var elements = curScore.selection.elements
        for (var i = 0; i < elements.length; ++i) {
            var el = elements[i]
            if (el.type == Element.NOTE && el.parent && el.parent.type == Element.CHORD) {
                var add = true
                for (var j = 0; j < chords.length; ++j) if (chords[j].is(el.parent)) { add = false; break }
                if (add) chords.push(el.parent)
            }
        }
        for (var c = 0; c < chords.length; ++c) {
            var notes = chords[c].notes
            for (var n = 0; n < notes.length; ++n) {
                var note = notes[n]
                var relative = (note.pitch % 12 - tonic + 12) % 12
                var ident = noteIdentity(note)
                var target = offsets[relative] + ident.baseCents
                tuneNotes([note], target)
            }
        }
        curScore.endCmd()
        refreshNotes()
    }

    onRun: {
        syncAccidentalConstants()
        loadSettings()
        memoryStore = Logic.parseStore(options.memory)
        scoreId = ""
        ensureScoreMemory()
        refreshNotes()
        refreshMarkers()
        refreshTuningTableControls()
        memoryCounter = memoryCount()
    }

    onScoreStateChanged: function(state) {
        if (!curScore) return
        if (state.undoRedo) { refreshNotes(); refreshMarkers(); return }
        if (state.selectionChanged) {
            if (markerToolArmed) { if (handleMarkerClick()) {} }
            else pendingMarker = null
            refreshNotes()
        }
    }

    Timer { id: statusTimer; interval: 4000; onTriggered: statusLabel.text = "" }

    ListModel { id: notesModel }
    ListModel { id: markersModel }
    ListModel { id: tableModel }

    ListModel {
        id: octaveModel
        ListElement { text: "اکتاو ۳" }
        ListElement { text: "اکتاو ۴" }
        ListElement { text: "اکتاو ۵" }
        ListElement { text: "اکتاو ۶" }
    }

    // ------------------------------------------------------------------
    // UI - dark theme like mixer
    // ------------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: bgPage

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            // Ribbon tab bar (tuner-ribbon-tab.html)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 86
                color: "#131a22"
                border.color: border
                border.width: 1
                radius: 14

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Tab row
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: "#0f151c"
                        border.color: border
                        border.width: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            spacing: 2

                            Repeater {
                                model: ["خانه", "ورود نت", "چیدمان", "تیونر", "پخش", "نما"]
                                delegate: Rectangle {
                                    Layout.preferredHeight: 36
                                    Layout.preferredWidth: 64
                                    color: "transparent"
                                    border.width: 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: modelData === "تیونر" ? accent : textSecondary
                                        font.pixelSize: 13
                                    }
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 2
                                        color: modelData === "تیونر" ? accent : "transparent"
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: border }
                    }

                    // Subtoolbar
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 10
                        spacing: 8

                        // پنل کلی
                        ColumnLayout {
                            spacing: 6
                            Rectangle {
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 52
                                radius: 9
                                color: accentDim
                                border.color: "#2ee6b833"
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: "◫"; color: accent; font.pixelSize: 20; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: "پنل کلی"; color: textPrimary; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                }
                                MouseArea { anchors.fill: parent; onClicked: refreshNotes() }
                            }
                            Text { text: "تنظیم کوک"; color: textMuted; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                        }

                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: border }

                        // نشانگر
                        ColumnLayout {
                            spacing: 6
                            Rectangle {
                                id: markerBtn
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 52
                                radius: 9
                                color: markerToolArmed ? accentDim : bgBtn
                                border.color: markerToolArmed ? "#2ee6b833" : border
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: "⚑"; color: markerToolArmed ? accent : textSecondary; font.pixelSize: 18; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: "نشانگر"; color: markerToolArmed ? accent : textSecondary; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                }
                                MouseArea { anchors.fill: parent; onClicked: toggleMarkerTool() }
                            }
                            Text { text: "مرز مدگردی"; color: textMuted; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                        }

                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: border }

                        // حافظه خودکار
                        ColumnLayout {
                            spacing: 6
                            Rectangle {
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 52
                                radius: 9
                                color: bgBtn
                                border.color: border
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 16
                                        radius: 8
                                        color: accentDim
                                        border.color: "#2ee6b866"
                                        border.width: 1
                                        Rectangle {
                                            x: autoMemory ? parent.width - 13 : 1
                                            y: 1
                                            width: 12; height: 12; radius: 6
                                            color: accent
                                        }
                                    }
                                    Text { text: autoMemory ? "فعال" : "خاموش"; color: autoMemory ? accent : textSecondary; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { autoMemory = !autoMemory; saveSettings() }
                                }
                            }
                            Text { text: "حافظه خودکار"; color: textMuted; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                        }

                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: border }

                        // مدیریت
                        ColumnLayout {
                            spacing: 6
                            RowLayout {
                                spacing: 4
                                Rectangle {
                                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 9; color: bgBtn; border.color: border; border.width: 1
                                    Text { anchors.centerIn: parent; text: "👁"; color: textSecondary; font.pixelSize: 16 }
                                    MouseArea { anchors.fill: parent; onClicked: {} }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 9; color: bgBtn; border.color: border; border.width: 1
                                    Text { anchors.centerIn: parent; text: "☰"; color: textSecondary; font.pixelSize: 16 }
                                    MouseArea { anchors.fill: parent; onClicked: {} }
                                }
                            }
                            Text { text: "مدیریت"; color: textMuted; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // Main panel - cent-tuning-panel.html
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: mainCol.implicitHeight + 20
                clip: true

                ColumnLayout {
                    id: mainCol
                    width: parent.width - 20
                    x: 10
                    y: 10
                    spacing: 16

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "میزان‌کننده بر پایه سنت"; color: textMuted; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                    }

                    // Ref row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: 10
                            color: bgCard
                            border.color: border
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                ColumnLayout {
                                    spacing: 4
                                    Text { text: "نت مرجع (دیاپازون)"; color: textMuted; font.pixelSize: 11 }
                                    Text { text: "لا۴ (A4)"; color: textPrimary; font.pixelSize: 15 }
                                }
                                Item { Layout.fillWidth: true }
                                RowLayout {
                                    spacing: 6
                                    Rectangle {
                                        Layout.preferredWidth: 64
                                        Layout.preferredHeight: 28
                                        radius: 6
                                        color: bgPanel
                                        border.color: borderStrong
                                        border.width: 1

                                        TextInput {
                                            id: refFreqInput
                                            anchors.centerIn: parent
                                            text: String(refFreq)
                                            color: textPrimary
                                            font.pixelSize: 14
                                            horizontalAlignment: TextInput.AlignHCenter
                                            validator: DoubleValidator { bottom: 300; top: 600 }
                                            onEditingFinished: {
                                                var v = parseFloat(text)
                                                if (!isNaN(v)) { refFreq = v; saveSettings(); refreshTuningTableControls() }
                                            }
                                        }
                                    }
                                    Text { text: "Hz"; color: textMuted; font.pixelSize: 12 }
                                }
                            }
                        }
                    }

                    Text { text: "انتخاب اکتاو، نت و علامت"; color: textMuted; font.pixelSize: 11 }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Octave
                        MU.StyledDropdown {
                            id: octaveDropdown
                            Layout.preferredWidth: 110
                            model: ["اکتاو ۳", "اکتاو ۴", "اکتاو ۵", "اکتاو ۶"]
                            currentIndex: 1
                            onActivated: function(index) {
                                selectedOctave = 3 + index
                                refreshTuningTableControls()
                            }
                        }
                        // Note
                        MU.StyledDropdown {
                            id: noteDropdown
                            Layout.preferredWidth: 90
                            model: ["دو", "رِ", "می", "فا", "سل", "لا", "سی"]
                            currentIndex: 5
                            onActivated: function(index) {
                                var letters = ["C","D","E","F","G","A","B"]
                                selectedLetter = letters[index]
                                refreshTuningTableControls()
                            }
                        }
                        // Accidental
                        MU.StyledDropdown {
                            id: variantDropdown
                            Layout.fillWidth: true
                            model: ["بکار", "بمل", "سری", "کرن", "دیز"]
                            currentIndex: 2
                            onActivated: function(index) {
                                var ids = ["natural","flat","sori","koron","sharp"]
                                selectedVariant = ids[index]
                                var tblCents = getTableCents(selectedLetter, selectedVariant)
                                currentCents = tblCents
                                centsSlider.value = tblCents
                                refreshTuningTableControls()
                            }
                        }
                    }

                    // Current badge
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 8
                        color: accentDim

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4; color: accent }
                            Text { text: "در حال تنظیم:"; color: textSecondary; font.pixelSize: 12 }
                            Text { id: currentBadgeLabel; text: "فا سری"; color: accent; font.pixelSize: 15 }
                            Item { Layout.fillWidth: true }
                            Text { id: selectionSummary; text: ""; color: textSecondary; font.pixelSize: 11 }
                        }
                    }

                    // Tuner card
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        radius: 12
                        color: bgCard
                        border.color: border
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                Text { id: refNoteLabel; text: "سنت نسبت به فا طبیعی"; color: textSecondary; font.pixelSize: 12 }
                                Item { Layout.fillWidth: true }
                                Text { id: centsLabel; text: "+50"; color: textPrimary; font.pixelSize: 16 }
                            }

                            MU.StyledSlider {
                                id: centsSlider
                                Layout.fillWidth: true
                                from: -100
                                to: 100
                                stepSize: 1
                                value: 50
                                onMoved: {
                                    currentCents = value
                                    centsLabel.text = (value > 0 ? "+" : "") + Math.round(value)
                                    var freq = calcFreq(selectedLetter, selectedOctave, selectedVariant, value, refFreq)
                                    hzLabel.text = freq.toFixed(1) + " Hz"
                                    previewCents(value)
                                }
                                onPressedChanged: {
                                    if (!pressed) commitCents(value)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "-100"; color: textMuted; font.pixelSize: 11 }
                                Item { Layout.fillWidth: true }
                                Text { text: "0"; color: textMuted; font.pixelSize: 11 }
                                Item { Layout.fillWidth: true }
                                Text { text: "+100"; color: textMuted; font.pixelSize: 11 }
                            }

                            RowLayout {
                                spacing: 6
                                Text { text: "ⓘ"; color: textMuted; font.pixelSize: 11 }
                                Text { id: hintLabel; Layout.fillWidth: true; text: "مقدار مرسوم سری معمولاً 50+ سنت است"; color: textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: border }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "فرکانس محاسبه‌شده (فقط‌خواندنی)"; color: textSecondary; font.pixelSize: 12 }
                                Item { Layout.fillWidth: true }
                                Text { id: hzLabel; text: "357.3 Hz"; color: accent; font.pixelSize: 20 }
                            }
                        }
                    }

                    // Play button
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 8
                        color: bgCard
                        border.color: borderStrong
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: "▶"; color: textPrimary; font.pixelSize: 14 }
                            Text { text: "پخش این نت"; color: textPrimary; font.pixelSize: 14 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // play via MuseScore cmd
                                try { root.cmd("play") } catch (e) {}
                            }
                        }
                    }

                    // Quick table for all variants of selected letter
                    Text { text: "تنظیمات همه علامت‌های " + letterFa(selectedLetter); color: textMuted; font.pixelSize: 11 }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: tableModel
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                radius: 8
                                color: bgCard
                                border.color: border
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8
                                    Text { text: variantFa(model.variant); color: textPrimary; font.pixelSize: 12; Layout.preferredWidth: 40 }
                                    Text { text: model.cents + "¢"; color: textSecondary; font.pixelSize: 11; Layout.preferredWidth: 50 }
                                    MU.StyledSlider {
                                        Layout.fillWidth: true
                                        from: -100; to: 100; value: model.cents; stepSize: 1
                                        onPressedChanged: { if (!pressed) setTableCents(selectedLetter, model.variant, value) }
                                    }
                                    Rectangle {
                                        Layout.preferredWidth: 36; Layout.preferredHeight: 28; radius: 6; color: bgPanel; border.color: border; border.width: 1
                                        Text { anchors.centerIn: parent; text: model.cents; color: textPrimary; font.pixelSize: 11 }
                                    }
                                }
                            }
                        }
                    }

                    // Selected notes list
                    Text { id: countLabel; text: ""; color: textMuted; font.pixelSize: 11 }

                    Repeater {
                        model: notesModel
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 6
                            color: bgCard
                            border.color: border
                            border.width: 1
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Text { text: model.label; color: textPrimary; font.pixelSize: 12; Layout.preferredWidth: 80 }
                                Text { text: model.cents + "¢ نسبت به بکار"; color: textSecondary; font.pixelSize: 11; Layout.fillWidth: true }
                            }
                        }
                    }

                    // Markers
                    Repeater {
                        model: markersModel
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 6
                            color: bgCard
                            border.color: border
                            border.width: 1
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Text { text: "⚑"; color: accent; font.pixelSize: 12 }
                                Text { text: model.label; color: textPrimary; font.pixelSize: 11; Layout.fillWidth: true }
                                Text { text: model.cents + "¢"; color: accent; font.pixelSize: 11 }
                                Rectangle {
                                    Layout.preferredWidth: 40; Layout.preferredHeight: 24; radius: 6; color: bgBtn; border.color: border; border.width: 1
                                    Text { anchors.centerIn: parent; text: "برو"; color: textSecondary; font.pixelSize: 10 }
                                    MouseArea { anchors.fill: parent; onClicked: gotoMarker(model.idx) }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 40; Layout.preferredHeight: 24; radius: 6; color: bgBtn; border.color: border; border.width: 1
                                    Text { anchors.centerIn: parent; text: "حذف"; color: textSecondary; font.pixelSize: 10 }
                                    MouseArea { anchors.fill: parent; onClicked: removeMarker(model.idx) }
                                }
                            }
                        }
                    }

                    Text { id: statusLabel; Layout.fillWidth: true; color: textSecondary; font.pixelSize: 11 }
                }
            }
        }
    }
}
