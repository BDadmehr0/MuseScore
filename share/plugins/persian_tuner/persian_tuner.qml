/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Persian Tuner - tune notes in cents, remember quarter-tone values and
 *                 mark tuning changes in the score
 *
 * Copyright (C) 2026 BDadmehr0
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
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

    version: "2.0.0"
    title: qsTr("Persian Tuner")
    description: qsTr("Tune notes in cents, apply Persian (dastgah) presets, remember quarter-tone values automatically and mark tuning changes in the score")
    pluginType: "dialog"
    categoryCode: "playback"
    thumbnailName: "persian_tuner.png"
    requiresScore: false

    width: 620
    height: 880

    // ------------------------------------------------------------------
    // Data
    // ------------------------------------------------------------------

    property var pcNames: Logic.PITCH_CLASS_NAMES
    property int tonicPc: 0

    // Dastgah presets.
    // koron / sori: 1-based scale degrees (1=C, 2=D, 3=E, 4=F, 5=G, 6=A, 7=B
    // relative to the tonic). Every koron degree is tuned -50 cents, every
    // sori degree +50 cents (24-TET approximation); all values are editable in
    // the note list below and a custom preset can be saved with "Save preset".
    property var presets: [
        { name: "Mahur (major)", koron: [], sori: [] },
        { name: "Rast", koron: [], sori: [] },
        { name: "Homayoun", koron: [2, 6], sori: [] },
        { name: "Chahargah", koron: [2, 4, 6], sori: [] },
        { name: "Nava", koron: [3, 7], sori: [] },
        { name: "Shur", koron: [2], sori: [] },
        { name: "Dashti", koron: [2], sori: [] },
        { name: "Bayat-e Tork", koron: [2], sori: [] },
        { name: "Afshari", koron: [2], sori: [] },
        { name: "Abu'ata", koron: [2], sori: [] },
        { name: "Isfahan", koron: [2, 6], sori: [] },
        { name: "Segah", koron: [3], sori: [] }
    ]

    // ------------------------------------------------------------------
    // Tool state
    // ------------------------------------------------------------------

    /// Tool 1 - automatic memory. Remembers the last value used for a note
    /// and re-uses it for every later occurrence of that note.
    property bool autoMemory: true
    /// Write koron/sori signs when a note is tuned by a quarter tone.
    property bool addAccidentals: true
    /// Distinguish "F" from "F with a sori sign" when remembering a value.
    property bool matchAccidental: false
    /// Keep a separate memory for every staff instead of one for the score.
    property bool perStaffMemory: false

    /// Tool 2 - the marker tool. Armed by the user, it places a permanent
    /// visible sign in the score at the next clicked note.
    property bool markerToolArmed: false
    /// Marker that is waiting for the user to type its value.
    property var pendingMarker: null

    // ------------------------------------------------------------------
    // Runtime state
    // ------------------------------------------------------------------

    property var noteObjects: []        // notes of the current selection
    property var markerEntries: []      // { note, element } of every marker found
    property var memoryStore: Logic.newStore()
    property string scoreId: ""
    /// Kept in sync with the memory so the toolbar badge updates itself.
    property int memoryCounter: 0

    /// Value used in the list model when no memory entry exists.
    readonly property int noMemoryValue: -99999

    // ------------------------------------------------------------------
    // Persistent settings (saved automatically by the framework)
    // ------------------------------------------------------------------

    Settings {
        id: options
        category: "Persian Tuner"
        property var customPreset: ''
        property var autoMemory: '1'
        property var accidentals: '1'
        property var matchAccidental: '0'
        property var perStaffMemory: '0'
        property var memory: '{}'
    }

    // ------------------------------------------------------------------
    // Small helpers
    // ------------------------------------------------------------------

    function boolFromSetting(value, fallback)
    {
        if (value === undefined || value === null || value === "") {
            return fallback
        }
        if (typeof value === "boolean") {
            return value
        }
        return String(value) !== '0'
    }

    function loadSettings()
    {
        autoMemory = boolFromSetting(options.autoMemory, true)
        addAccidentals = boolFromSetting(options.accidentals, true)
        matchAccidental = boolFromSetting(options.matchAccidental, false)
        perStaffMemory = boolFromSetting(options.perStaffMemory, false)
    }

    function saveSettings()
    {
        options.autoMemory = autoMemory ? '1' : '0'
        options.accidentals = addAccidentals ? '1' : '0'
        options.matchAccidental = matchAccidental ? '1' : '0'
        options.perStaffMemory = perStaffMemory ? '1' : '0'
        options.memory = Logic.serializeStore(memoryStore)
    }

    function status(message)
    {
        statusLabel.text = message
        statusTimer.restart()
    }

    function round1(value)
    {
        return Math.round(value * 10) / 10
    }

    /// The logic module ships with fallback values for the accidental
    /// enumeration; take the real ones from the running MuseScore instead.
    function syncAccidentalConstants()
    {
        try {
            Logic.ACC_NONE = 0 + Accidental.NONE
            Logic.ACC_NATURAL = 0 + Accidental.NATURAL
            Logic.ACC_SORI = 0 + Accidental.SORI
            Logic.ACC_KORON = 0 + Accidental.KORON
            Logic.REPLACEABLE_ACCIDENTALS = [Logic.ACC_NONE, Logic.ACC_NATURAL,
                Logic.ACC_SORI, Logic.ACC_KORON]
        } catch (e) {
            // keep the built-in values
        }
    }

    /// Accidental of a note as a plain number (the API may hand back the name
    /// of the enumeration value instead).
    function accidentalValue(note)
    {
        return Logic.normalizeAccidental(note.accidentalType, Accidental)
    }

    /// The JSON blob the memory is persisted in (also used by the tests).
    function settingsJson()
    {
        return options.memory
    }

    function currentScoreId()
    {
        if (!curScore) {
            return ""
        }
        var id = ""
        try {
            id = curScore.scoreName
        } catch (e) {
            id = ""
        }
        if (!id) {
            id = curScore.title
        }
        return id ? id : "score"
    }

    /// Makes sure the memory store holds an entry for the current score and
    /// returns its id.
    function ensureScoreMemory()
    {
        var id = currentScoreId()
        if (id !== scoreId) {
            scoreId = id
            memoryStore = Logic.parseStore(options.memory)
        }
        return id
    }

    function noteTick(note)
    {
        var fraction = note.fraction
        return fraction ? fraction.ticks : 0
    }

    function noteStaffIdx(note)
    {
        var idx = note.staffIdx
        return (idx === undefined || idx === null) ? 0 : idx
    }

    /// Identity used by the memory for this note.
    function memoryKeyFor(note)
    {
        return Logic.makeKey(note.pitch % 12, accidentalValue(note), noteStaffIdx(note),
                             { perStaff: perStaffMemory, withAccidental: matchAccidental })
    }

    function noteLabel(note)
    {
        var pc = note.pitch % 12
        var octave = Math.floor(note.pitch / 12) - 1
        return pcNames[pc] + " " + octave
    }

    function measureNumberFor(note)
    {
        try {
            var chord = note.parent
            var measure = chord ? chord.measure : null
            if (measure) {
                return measure.measureNumber
            }
        } catch (e) {
            // fall through
        }
        return 0
    }

    function selectedNotes()
    {
        var result = []
        if (!curScore) {
            return result
        }
        var elements = curScore.selection.elements
        for (var i = 0; i < elements.length; ++i) {
            var el = elements[i]
            if (el.type == Element.NOTE && el.parent && el.parent.type == Element.CHORD) {
                result.push(el)
            }
        }
        return result
    }

    function firstSelectedNote()
    {
        var notes = selectedNotes()
        return notes.length > 0 ? notes[0] : null
    }

    /// Every note of the score, in reading order (grace notes are not visited;
    /// they can still be tuned through the selection).
    function collectScoreNotes()
    {
        var result = []
        if (!curScore) {
            return result
        }
        var ntracks = curScore.ntracks
        var measure = curScore.firstMeasure
        var measureGuard = 0
        while (measure && measureGuard < 100000) {
            var segment = measure.firstSegment
            var segmentGuard = 0
            while (segment && segmentGuard < 100000) {
                for (var track = 0; track < ntracks; ++track) {
                    var el = segment.elementAt(track)
                    if (el && el.type == Element.CHORD) {
                        var notes = el.notes
                        for (var n = 0; n < notes.length; ++n) {
                            result.push(notes[n])
                        }
                    }
                }
                segment = segment.nextInMeasure
                ++segmentGuard
            }
            measure = measure.nextMeasure
            ++measureGuard
        }
        return result
    }

    /// Applies a cents value to a list of notes (no undo handling here).
    function tuneNotes(notes, cents)
    {
        for (var i = 0; i < notes.length; ++i) {
            var note = notes[i]
            var current = accidentalValue(note)
            var accidental = Logic.intendedAccidental(current, cents, addAccidentals)
            if (accidental !== current) {
                note.accidentalType = accidental
            }
            note.tuning = cents
        }
        return notes.length
    }

    /// Stores the new value in the memory and returns how many notes of the
    /// score it was applied to.
    function rememberAndPropagate(notes, cents)
    {
        if (notes.length === 0) {
            return 0
        }
        var id = ensureScoreMemory()

        // Earliest position per note identity: that is where the new value
        // starts to be valid.
        var startTicks = {}
        var keyOrder = []
        for (var i = 0; i < notes.length; ++i) {
            var key = memoryKeyFor(notes[i])
            var tick = noteTick(notes[i])
            if (startTicks[key] === undefined) {
                startTicks[key] = tick
                keyOrder.push(key)
            } else if (tick < startTicks[key]) {
                startTicks[key] = tick
            }
        }

        var allNotes = collectScoreNotes()
        var meta = []
        for (var m = 0; m < allNotes.length; ++m) {
            meta.push({ key: memoryKeyFor(allNotes[m]), tick: noteTick(allNotes[m]) })
        }

        var applied = 0
        for (var k = 0; k < keyOrder.length; ++k) {
            var memoryKey = keyOrder[k]
            var range = Logic.setChange(memoryStore, id, memoryKey, startTicks[memoryKey], cents)
            var indices = Logic.indicesToTune(meta, memoryKey, range)
            for (var n = 0; n < indices.length; ++n) {
                applied += tuneNotes([allNotes[indices[n]]], cents)
            }
        }
        return applied
    }

    // ------------------------------------------------------------------
    // Selection list
    // ------------------------------------------------------------------

    function refreshNotes()
    {
        notesModel.clear()
        noteObjects = []
        if (!curScore) {
            notesFlick.visible = false
            emptyLabel.visible = true
            countLabel.text = qsTr("Open a score to tune notes")
            selectionSummary.text = qsTr("No note selected")
            return
        }

        var id = ensureScoreMemory()
        var notes = selectedNotes()
        var memoryValue = noMemoryValue
        for (var i = 0; i < notes.length; ++i) {
            var note = notes[i]
            noteObjects.push(note)
            var remembered = Logic.resolveCents(memoryStore, id, memoryKeyFor(note), noteTick(note))
            notesModel.append({
                idx: i,
                label: noteLabel(note),
                cents: round1(note.tuning),
                remembered: remembered === null ? noMemoryValue : round1(remembered)
            })
            if (i === 0) {
                memoryValue = remembered === null ? noMemoryValue : round1(remembered)
            }
        }

        var hasNotes = notes.length > 0
        notesFlick.visible = hasNotes
        emptyLabel.visible = !hasNotes
        countLabel.text = hasNotes ? qsTr("Selected notes: ") + notes.length : qsTr("Select notes in the score")

        if (hasNotes) {
            var first = notes[0]
            selectionSummary.text = qsTr("Note: ") + noteLabel(first)
                                    + "   " + qsTr("Now: ") + Logic.formatCents(first.tuning)
            centsControl.currentValue = round1(first.tuning)
            memoryLabel.text = memoryValue === noMemoryValue
                               ? qsTr("No remembered value yet")
                               : qsTr("Remembered: ") + Logic.formatCents(memoryValue)
        } else {
            selectionSummary.text = qsTr("No note selected")
            memoryLabel.text = ""
        }
    }

    // ------------------------------------------------------------------
    // Tool 1 - automatic memory
    // ------------------------------------------------------------------

    /// Live preview while the user is typing or dragging: tunes the selection
    /// only and creates no undo entry.
    function previewCents(cents)
    {
        if (!curScore) {
            return
        }
        var notes = selectedNotes()
        for (var i = 0; i < notes.length; ++i) {
            notes[i].tuning = round1(cents)
        }
    }

    /// Sets the tuning of the current selection and (when the automatic memory
    /// is on) every later occurrence of the same notes.
    function commitCents(cents)
    {
        if (!curScore) {
            return false
        }
        var notes = selectedNotes()
        if (notes.length === 0) {
            status(qsTr("Select at least one note in the score"))
            return false
        }
        cents = round1(cents)

        curScore.startCmd(qsTr("Tune notes"))
        tuneNotes(notes, cents)
        var applied = notes.length
        if (autoMemory) {
            applied = rememberAndPropagate(notes, cents)
        }
        if (pendingMarker) {
            pendingMarker.text = Logic.markerText(cents)
            pendingMarker = null
        }
        curScore.endCmd()

        saveSettings()
        memoryCounter = memoryCount()
        refreshNotes()
        refreshMarkers()
        status(autoMemory
               ? qsTr("Tuned %1 note(s)").arg(applied)
               : qsTr("Tuned %1 selected note(s)").arg(notes.length))
        return true
    }

    /// Applies the remembered values to the current selection.
    function applyMemoryToSelection()
    {
        if (!curScore) {
            return
        }
        var id = ensureScoreMemory()
        var notes = selectedNotes()
        if (notes.length === 0) {
            status(qsTr("Select at least one note in the score"))
            return
        }
        curScore.startCmd(qsTr("Apply remembered tuning"))
        var applied = 0
        for (var i = 0; i < notes.length; ++i) {
            var cents = Logic.resolveCents(memoryStore, id, memoryKeyFor(notes[i]), noteTick(notes[i]))
            if (cents === null) {
                continue
            }
            tuneNotes([notes[i]], cents)
            ++applied
        }
        curScore.endCmd()
        refreshNotes()
        status(applied > 0 ? qsTr("Applied the remembered value to %1 note(s)").arg(applied)
                           : qsTr("Nothing remembered for the selected notes yet"))
    }

    /// Re-applies the whole memory to the whole score.
    function reapplyMemory()
    {
        if (!curScore) {
            return
        }
        var id = ensureScoreMemory()
        if (Logic.countChanges(memoryStore, id) === 0) {
            status(qsTr("The memory is empty"))
            return
        }
        var notes = collectScoreNotes()
        curScore.startCmd(qsTr("Re-apply remembered tuning"))
        var applied = 0
        for (var i = 0; i < notes.length; ++i) {
            var cents = Logic.resolveCents(memoryStore, id, memoryKeyFor(notes[i]), noteTick(notes[i]))
            if (cents === null) {
                continue
            }
            tuneNotes([notes[i]], cents)
            ++applied
        }
        curScore.endCmd()
        refreshNotes()
        status(qsTr("Re-applied the memory to %1 note(s)").arg(applied))
    }

    function clearMemory()
    {
        var id = ensureScoreMemory()
        Logic.removeScore(memoryStore, id)
        saveSettings()
        memoryCounter = memoryCount()
        refreshNotes()
        status(qsTr("Automatic memory cleared"))
    }

    /// Number of remembered values, for the toolbar badge.
    function memoryCount()
    {
        return Logic.countChanges(memoryStore, ensureScoreMemory())
    }

    // ------------------------------------------------------------------
    // Tool 2 - markers
    // ------------------------------------------------------------------

    function toggleMarkerTool()
    {
        markerToolArmed = !markerToolArmed
        if (markerToolArmed) {
            status(qsTr("Marker tool: click a note in the score"))
        } else {
            pendingMarker = null
            status(qsTr("Marker tool cancelled"))
        }
        markerHint.visible = markerToolArmed
    }

    /// Places a permanent marker above \p note.
    function placeMarker(note, cents)
    {
        if (!curScore || !note) {
            return null
        }
        var element = newElement(Element.TEXT)
        if (!element) {
            status(qsTr("Could not create the marker"))
            return null
        }
        element.text = Logic.markerText(cents)
        element.subStyle = Tid.STAFF
        element.placement = Placement.ABOVE
        element.align = Align.BASELINE

        curScore.startCmd(qsTr("Add tuning marker"))
        note.add(element)
        curScore.endCmd()

        refreshMarkers()
        return element
    }

    /// Called when the marker tool is armed and the user clicked in the score.
    function handleMarkerClick()
    {
        var note = firstSelectedNote()
        if (!note) {
            status(qsTr("Click a note (not a rest) in the score"))
            return false
        }
        var cents = round1(note.tuning)
        var element = placeMarker(note, cents)
        if (!element) {
            return false
        }
        markerToolArmed = false
        markerHint.visible = false
        pendingMarker = element
        centsControl.currentValue = cents
        status(qsTr("Marker added - set the value and press Apply"))
        // bring the plugin window to the front so the value can be typed in
        try {
            var pluginWindow = root.Window.window
            if (pluginWindow) {
                pluginWindow.raise()
                pluginWindow.requestActivate()
            }
        } catch (e) {
            // not available for every plugin window, that is fine
        }
        return true
    }

    function refreshMarkers()
    {
        markersModel.clear()
        markerEntries = []
        if (!curScore) {
            markersGroup.visible = false
            return
        }
        var notes = collectScoreNotes()
        for (var i = 0; i < notes.length; ++i) {
            var note = notes[i]
            var elements = note.elements
            for (var e = 0; e < elements.length; ++e) {
                var el = elements[e]
                if (el.type != Element.TEXT) {
                    continue
                }
                var parsed = Logic.parseMarkerText(el.text)
                if (!parsed) {
                    continue
                }
                markerEntries.push({ note: note, element: el })
                markersModel.append({
                    idx: markerEntries.length - 1,
                    label: qsTr("Measure ") + measureNumberFor(note) + " - " + noteLabel(note),
                    cents: round1(parsed.cents)
                })
            }
        }
        markersGroup.visible = markerEntries.length > 0
    }

    function gotoMarker(index)
    {
        if (index < 0 || index >= markerEntries.length) {
            return
        }
        var entry = markerEntries[index]
        if (curScore.selection.select(entry.note)) {
            refreshNotes()
        }
        curScore.showElementInScore(entry.note)
    }

    function removeMarker(index)
    {
        if (index < 0 || index >= markerEntries.length) {
            return
        }
        var entry = markerEntries[index]
        curScore.startCmd(qsTr("Remove tuning marker"))
        try {
            entry.note.remove(entry.element)
        } catch (e) {
            removeElement(entry.element)
        }
        curScore.endCmd()
        if (pendingMarker && pendingMarker === entry.element) {
            pendingMarker = null
        }
        refreshMarkers()
        status(qsTr("Marker removed"))
    }

    function removeAllMarkers()
    {
        if (markerEntries.length === 0) {
            return
        }
        var entries = markerEntries
        curScore.startCmd(qsTr("Remove tuning markers"))
        for (var i = 0; i < entries.length; ++i) {
            try {
                entries[i].note.remove(entries[i].element)
            } catch (e) {
                removeElement(entries[i].element)
            }
        }
        curScore.endCmd()
        pendingMarker = null
        refreshMarkers()
        status(qsTr("All markers removed"))
    }

    // ------------------------------------------------------------------
    // Presets
    // ------------------------------------------------------------------

    function applyPreset(wholeScore)
    {
        applyPresetAt(presetDropdown.currentIndex, wholeScore)
    }

    /// Applies preset number \p presetIndex to the selection (or to the whole
    /// score when \p wholeScore is true or nothing is selected).
    function applyPresetAt(presetIndex, wholeScore)
    {
        if (!curScore) {
            return
        }
        if (presetIndex < 0 || presetIndex >= presets.length) {
            return
        }
        if (wholeScore || curScore.selection.elements.length === 0) {
            curScore.startCmd(qsTr("Apply Persian tuning to score"))
            cmd("select-all")
        } else {
            curScore.startCmd(qsTr("Apply Persian tuning to selection"))
        }

        var offsets = Logic.offsetsForPreset(presets[presetIndex])
        var tonic = root.tonicPc

        var chords = []
        var elements = curScore.selection.elements
        for (var i = 0; i < elements.length; ++i) {
            var el = elements[i]
            if (el.type == Element.NOTE && el.parent && el.parent.type == Element.CHORD) {
                var add = true
                for (var j = 0; j < chords.length; ++j) {
                    if (chords[j].is(el.parent)) {
                        add = false
                        break
                    }
                }
                if (add) {
                    chords.push(el.parent)
                }
            }
        }

        for (var c = 0; c < chords.length; ++c) {
            var notes = chords[c].notes
            for (var n = 0; n < notes.length; ++n) {
                var note = notes[n]
                var relative = (note.pitch % 12 - tonic + 12) % 12
                tuneNotes([note], offsets[relative])
            }
        }

        curScore.endCmd()
        refreshNotes()
        status(qsTr("Preset applied to %1 chord(s)").arg(chords.length))
    }

    function resetSelection()
    {
        commitCents(0)
    }

    function saveCustomPreset()
    {
        options.customPreset = JSON.stringify({
            "name": presets[presetDropdown.currentIndex].name,
            "koron": presets[presetDropdown.currentIndex].koron,
            "sori": presets[presetDropdown.currentIndex].sori,
            "tonic": root.tonicPc
        })
        status(qsTr("Custom preset saved"))
    }

    function loadCustomPreset()
    {
        if (!options.customPreset || options.customPreset === "") {
            status(qsTr("No custom preset saved yet"))
            return
        }
        var data = null
        try {
            data = JSON.parse(options.customPreset)
        } catch (e) {
            status(qsTr("Could not load the custom preset"))
            return
        }
        var index = Logic.indexOfPreset(presets, data.name)
        if (index < 0) {
            presets.push({ name: data.name, koron: data.koron, sori: data.sori })
            index = presets.length - 1
        }
        presetDropdown.currentIndex = index
        root.tonicPc = data.tonic ? data.tonic : 0
        tonicDropdown.currentIndex = root.tonicPc
        status(qsTr("Custom preset loaded"))
    }

    // ------------------------------------------------------------------
    // Plugin lifecycle
    // ------------------------------------------------------------------

    onRun: {
        syncAccidentalConstants()
        loadSettings()
        memoryStore = Logic.parseStore(options.memory)
        scoreId = ""
        ensureScoreMemory()
        refreshNotes()
        refreshMarkers()
        memoryCounter = memoryCount()
    }

    onScoreStateChanged: function(state) {
        if (!curScore) {
            return
        }
        if (state.undoRedo) {
            refreshNotes()
            refreshMarkers()
            return
        }
        if (state.selectionChanged) {
            if (markerToolArmed) {
                if (handleMarkerClick()) {
                    centsControl.forceActiveFocus()
                }
            } else {
                // moving away cancels a marker value that was not confirmed
                pendingMarker = null
            }
            refreshNotes()
        }
    }

    Timer {
        id: statusTimer
        interval: 4000
        onTriggered: statusLabel.text = ""
    }

    // ------------------------------------------------------------------
    // Models
    // ------------------------------------------------------------------

    ListModel {
        id: notesModel
    }

    ListModel {
        id: markersModel
    }

    // ------------------------------------------------------------------
    // UI
    // ------------------------------------------------------------------

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ----- Tuner toolbar -------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: toolbarColumn.implicitHeight + 16
            radius: 6
            color: "#14000000"
            border.color: "#22000000"

            ColumnLayout {
                id: toolbarColumn
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.FlatButton {
                        id: markerToolButton
                        text: Logic.MARKER_GLYPH + "  " + qsTr("Marker")
                        onClicked: root.toggleMarkerTool()
                    }

                    Rectangle {
                        id: markerArmedDot
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10
                        radius: 5
                        color: root.markerToolArmed ? "#e67e22" : "transparent"
                        border.color: "#66000000"
                    }

                    MU.CheckBox {
                        id: autoMemoryCheck
                        text: qsTr("Automatic memory")
                        checked: root.autoMemory
                        onClicked: {
                            root.autoMemory = !root.autoMemory
                            root.saveSettings()
                        }
                    }

                    MU.FlatButton {
                        text: qsTr("Re-apply")
                        onClicked: root.reapplyMemory()
                    }

                    MU.FlatButton {
                        text: qsTr("Clear memory")
                        onClicked: root.clearMemory()
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    MU.StyledTextLabel {
                        text: qsTr("Remembered values: ")
                    }

                    MU.StyledTextLabel {
                        id: memoryCountLabel
                        text: String(root.memoryCounter)
                    }
                }

                MU.StyledTextLabel {
                    id: markerHint
                    Layout.fillWidth: true
                    visible: false
                    text: qsTr("Marker tool is active: click a note in the score. A permanent sign is placed there and the value can be entered right away.")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.StyledTextLabel {
                        text: qsTr("Match notes by:")
                    }

                    MU.StyledDropdown {
                        id: matchDropdown
                        Layout.preferredWidth: 170
                        model: [qsTr("Pitch class"), qsTr("Pitch class + accidental")]
                        currentIndex: root.matchAccidental ? 1 : 0
                        onActivated: function(index, value) {
                            root.matchAccidental = (index === 1)
                            root.saveSettings()
                            root.refreshNotes()
                        }
                    }

                    MU.CheckBox {
                        id: perStaffCheck
                        text: qsTr("Per staff")
                        checked: root.perStaffMemory
                        onClicked: {
                            root.perStaffMemory = !root.perStaffMemory
                            root.saveSettings()
                            root.refreshNotes()
                        }
                    }

                    MU.CheckBox {
                        id: accidentalsCheck
                        text: qsTr("Write koron/sori signs")
                        checked: root.addAccidentals
                        onClicked: {
                            root.addAccidentals = !root.addAccidentals
                            root.saveSettings()
                        }
                    }
                }
            }
        }

        // ----- Dastgah preset ------------------------------------------
        MU.StyledGroupBox {
            Layout.fillWidth: true
            title: qsTr("Dastgah preset")

            ColumnLayout {
                width: parent.width
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.StyledTextLabel {
                        text: qsTr("Tonic:")
                    }

                    MU.StyledDropdown {
                        id: tonicDropdown
                        Layout.preferredWidth: 140
                        model: root.pcNames
                        currentIndex: root.tonicPc
                        onActivated: function(index, value) {
                            root.tonicPc = index
                        }
                    }

                    MU.StyledTextLabel {
                        text: qsTr("Dastgah:")
                    }

                    MU.StyledDropdown {
                        id: presetDropdown
                        Layout.fillWidth: true
                        model: Logic.presetNames(root.presets)
                        currentIndex: 2   // Homayoun
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.FlatButton {
                        text: qsTr("Apply to selection")
                        onClicked: root.applyPreset(false)
                    }

                    MU.FlatButton {
                        text: qsTr("Apply to score")
                        onClicked: root.applyPreset(true)
                    }

                    MU.FlatButton {
                        text: qsTr("Save preset")
                        onClicked: root.saveCustomPreset()
                    }

                    MU.FlatButton {
                        text: qsTr("Load preset")
                        onClicked: root.loadCustomPreset()
                    }

                    MU.FlatButton {
                        text: "\u25B6  " + qsTr("Play")
                        onClicked: root.cmd("play")
                    }
                }
            }
        }

        // ----- Cent tuning panel ---------------------------------------
        MU.StyledGroupBox {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: qsTr("Cent tuning")

            ColumnLayout {
                width: parent.width
                height: parent.height
                spacing: 8

                MU.StyledTextLabel {
                    id: selectionSummary
                    Layout.fillWidth: true
                    text: qsTr("No note selected")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.IncrementalPropertyControl {
                        id: centsControl
                        Layout.preferredWidth: 120
                        currentValue: 0
                        decimals: 1
                        step: 1
                        minValue: -100
                        maxValue: 100
                        measureUnitsSymbol: "\u00A2"
                        // valueEdited fires while typing: only preview the selection
                        onValueEdited: function(newValue) {
                            root.previewCents(newValue)
                        }
                        // valueEditingFinished fires on Enter / focus out: commit it
                        onValueEditingFinished: function(newValue) {
                            root.commitCents(newValue)
                        }
                    }

                    MU.FlatButton {
                        text: qsTr("Koron -50")
                        onClicked: root.commitCents(-50)
                    }

                    MU.FlatButton {
                        text: qsTr("Natural 0")
                        onClicked: root.commitCents(0)
                    }

                    MU.FlatButton {
                        text: qsTr("Sori +50")
                        onClicked: root.commitCents(50)
                    }

                    MU.FlatButton {
                        text: qsTr("Apply")
                        onClicked: root.commitCents(centsControl.currentValue)
                    }

                    MU.FlatButton {
                        text: qsTr("Use remembered")
                        onClicked: root.applyMemoryToSelection()
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                MU.StyledTextLabel {
                    id: memoryLabel
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.StyledTextLabel {
                        id: countLabel
                        Layout.fillWidth: true
                    }

                    MU.FlatButton {
                        text: qsTr("Refresh")
                        onClicked: root.refreshNotes()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 80
                    color: "transparent"
                    clip: true
                    border.color: "#33000000"
                    radius: 4

                    Flickable {
                        id: notesFlick
                        anchors.fill: parent
                        contentHeight: notesCol.implicitHeight
                        clip: true

                        ColumnLayout {
                            id: notesCol
                            width: notesFlick.width
                            spacing: 6

                            Repeater {
                                model: notesModel

                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    MU.StyledTextLabel {
                                        text: model.label
                                        Layout.preferredWidth: 70
                                    }

                                    MU.StyledSlider {
                                        Layout.fillWidth: true
                                        from: -100
                                        to: 100
                                        stepSize: 5
                                        value: model.cents
                                        onMoved: {
                                            if (model.idx >= 0 && model.idx < root.noteObjects.length) {
                                                root.noteObjects[model.idx].tuning = value
                                            }
                                        }
                                        onPressedChanged: {
                                            if (!pressed) {
                                                root.commitCents(value)
                                            }
                                        }
                                    }

                                    MU.StyledTextLabel {
                                        text: model.cents + " \u00A2"
                                        Layout.preferredWidth: 58
                                        Layout.alignment: Qt.AlignRight
                                    }

                                    MU.StyledTextLabel {
                                        text: model.remembered === root.noMemoryValue
                                              ? ""
                                              : qsTr("mem ") + model.remembered
                                        Layout.preferredWidth: 62
                                    }
                                }
                            }
                        }
                    }
                }

                MU.StyledTextLabel {
                    id: emptyLabel
                    Layout.fillWidth: true
                    text: qsTr("Select notes in the score to tune them here.")
                }
            }
        }

        // ----- Markers --------------------------------------------------
        MU.StyledGroupBox {
            id: markersGroup
            Layout.fillWidth: true
            visible: false
            title: qsTr("Tuning markers")

            ColumnLayout {
                width: parent.width
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.StyledTextLabel {
                        Layout.fillWidth: true
                        text: qsTr("Permanent signs in the score, marking where the tuning changes.")
                    }

                    MU.FlatButton {
                        text: qsTr("Remove all")
                        onClicked: root.removeAllMarkers()
                    }
                }

                Repeater {
                    model: markersModel

                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MU.StyledTextLabel {
                            text: Logic.MARKER_GLYPH
                            Layout.preferredWidth: 16
                        }

                        MU.StyledTextLabel {
                            text: model.label
                            Layout.fillWidth: true
                        }

                        MU.StyledTextLabel {
                            text: model.cents + " \u00A2"
                            Layout.preferredWidth: 58
                        }

                        MU.FlatButton {
                            text: qsTr("Go to")
                            onClicked: root.gotoMarker(model.idx)
                        }

                        MU.FlatButton {
                            text: qsTr("Delete")
                            onClicked: root.removeMarker(model.idx)
                        }
                    }
                }
            }
        }

        // ----- Status ---------------------------------------------------
        MU.StyledTextLabel {
            id: statusLabel
            Layout.fillWidth: true
        }
    }
}
