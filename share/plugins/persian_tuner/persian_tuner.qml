/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Persian Tuner - tune notes in cents and apply Persian (dastgah) presets
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

import Muse.Ui
import Muse.UiComponents as MU

import MuseScore 3.0

MuseScore {
    version: "1.0.0"
    title: qsTr("Persian Tuner")
    description: qsTr("Tune notes in cents and apply Persian dastgah presets (koron/sori)")
    pluginType: "dialog"
    categoryCode: "playback"
    thumbnailName: "persian_tuner.png"
    requiresScore: false
    id: root

    width: 460
    height: 780

    // ------------------------------------------------------------------
    // Data
    // ------------------------------------------------------------------

    // Generic pitch-class names (also used for the tonic selector)
    property var pcNames: ["C", "C♯/D♭", "D", "D♯/E♭", "E", "F", "F♯/G♭", "G", "G♯/A♭", "A", "A♯/B♭", "B"]
    property int tonicPc: 0

    // Dastgah presets.
    // koron / sori: 1-based scale degrees (1=C, 2=D, 3=E, 4=F, 5=G, 6=A, 7=B relative to the tonic).
    // Each koron degree is tuned -50 cents, each sori degree +50 cents (24-TET approximation).
    // NOTE: there are different traditions for some dastgahs; all values are editable in the UI
    // and a custom preset can be saved with Settings.
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

    property var noteObjects: []   // parallel array of plugin Note objects for the current list

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function noteName(note)
    {
        var pc = note.pitch % 12
        var oct = Math.floor(note.pitch / 12) - 1
        return pcNames[pc] + " " + oct
    }

    // Returns 12 cent offsets, index = pitch class relative to the tonic (C..B).
    function offsetsForPreset(preset)
    {
        var offsets = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        var degToPc = [0, 2, 4, 5, 7, 9, 11]
        for (var i = 0; i < preset.koron.length; ++i) {
            offsets[degToPc[preset.koron[i] - 1]] = -50
        }
        for (var j = 0; j < preset.sori.length; ++j) {
            offsets[degToPc[preset.sori[j] - 1]] = 50
        }
        return offsets
    }

    function selectedNotes()
    {
        var result = []
        if (!curScore) {
            return result
        }
        for (var i in curScore.selection.elements) {
            var el = curScore.selection.elements[i]
            if (el.type == Element.NOTE && el.parent && el.parent.type == Element.CHORD) {
                result.push(el)
            }
        }
        return result
    }

    function refreshNotes()
    {
        notesModel.clear()
        noteObjects = []
        if (!curScore) {
            notesFlick.visible = false
            emptyLabel.visible = true
            countLabel.text = qsTr("Open a score to tune notes")
            return
        }
        var notes = selectedNotes()
        for (var i = 0; i < notes.length; ++i) {
            noteObjects.push(notes[i])
            notesModel.append({ idx: i, label: noteName(notes[i]), cents: Math.round(notes[i].tuning * 10) / 10 })
        }
        var hasNotes = notes.length > 0
        notesFlick.visible = hasNotes
        emptyLabel.visible = !hasNotes
        countLabel.text = hasNotes ? (qsTr("Selected notes: ") + notes.length) : qsTr("Select notes in the score")
    }

    // live preview while dragging the slider (no undo entry)
    function previewNoteCents(idx, cents)
    {
        if (idx >= 0 && idx < noteObjects.length) {
            noteObjects[idx].tuning = cents
        }
    }

    // commit a single note tuning with one undo step
    function setNoteCents(idx, cents)
    {
        if (!curScore || idx < 0 || idx >= noteObjects.length) {
            return
        }
        curScore.startCmd("Tune note")
        noteObjects[idx].tuning = cents
        curScore.endCmd()
        notesModel.setProperty(idx, "cents", Math.round(cents * 10) / 10)
    }

    function quickTune(idx, cents)
    {
        setNoteCents(idx, cents)
    }

    function applyPreset(wholeScore)
    {
        if (!curScore) {
            return
        }
        if (wholeScore || curScore.selection.elements.length === 0) {
            curScore.startCmd("Apply Persian tuning to score")
            cmd("select-all")
        } else {
            curScore.startCmd("Apply Persian tuning to selection")
        }

        var offsets = offsetsForPreset(presets[presetDropdown.currentIndex])
        var addAcc = accidentalsCheck.checked

        // collect unique chords (one undo step for the whole operation)
        var chords = []
        for (var i in curScore.selection.elements) {
            var el = curScore.selection.elements[i]
            if (el.type == Element.NOTE && el.parent && el.parent.type == Element.CHORD) {
                var add = true
                for (var j in chords) {
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
            var chord = chords[c]
            for (var n in chord.notes) {
                var note = chord.notes[n]
                var rel = (note.pitch % 12 - root.tonicPc + 12) % 12
                var cents = offsets[rel]
                note.tuning = cents
                if (addAcc && cents !== 0) {
                    note.accidentalType = cents < 0 ? Accidental.KORON : Accidental.SORI
                }
            }
        }

        curScore.endCmd()
        refreshNotes()
    }

    function resetSelection()
    {
        if (!curScore || noteObjects.length === 0) {
            return
        }
        curScore.startCmd("Reset tuning")
        for (var i = 0; i < noteObjects.length; ++i) {
            noteObjects[i].tuning = 0
        }
        curScore.endCmd()
        refreshNotes()
    }

    function saveCustomPreset()
    {
        // save the currently selected preset + tonic as JSON so it can be reloaded next session
        options.customPreset = JSON.stringify({
            "name": presets[presetDropdown.currentIndex].name,
            "koron": presets[presetDropdown.currentIndex].koron,
            "sori": presets[presetDropdown.currentIndex].sori,
            "tonic": root.tonicPc
        })
        statusLabel.text = qsTr("Custom preset saved")
        savedTimer.restart()
    }

    function loadCustomPreset()
    {
        if (!options.customPreset || options.customPreset === "") {
            statusLabel.text = qsTr("No custom preset saved yet")
            savedTimer.restart()
            return
        }
        try {
            var data = JSON.parse(options.customPreset)
            // find matching preset or append a custom entry
            var found = -1
            for (var i = 0; i < presets.length; ++i) {
                if (presets[i].name === data.name) {
                    found = i
                    break
                }
            }
            if (found < 0) {
                presets.push({ name: data.name, koron: data.koron, sori: data.sori })
                found = presets.length - 1
            }
            presetDropdown.currentIndex = found
            root.tonicPc = data.tonic
            tonicDropdown.currentIndex = data.tonic
            statusLabel.text = qsTr("Custom preset loaded")
            savedTimer.restart()
        } catch (e) {
            statusLabel.text = qsTr("Could not load custom preset")
            savedTimer.restart()
        }
    }

    onRun: {
        refreshNotes()
    }

    onScoreStateChanged: {
        if (state.selectionChanged && curScore) {
            refreshNotes()
        }
    }

    // ------------------------------------------------------------------
    // Persistent settings (saved automatically by the framework)
    // ------------------------------------------------------------------

    Settings {
        id: options
        category: "Persian Tuner"
        property var customPreset: ''
    }

    Timer {
        id: savedTimer
        interval: 2500
        onTriggered: statusLabel.text = ""
    }

    // ------------------------------------------------------------------
    // UI
    // ------------------------------------------------------------------

    ListModel {
        id: notesModel
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ----- Preset group -----
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
                        Layout.fillWidth: true
                        model: root.pcNames
                        currentIndex: root.tonicPc
                        onActivated: function(index, value) {
                            root.tonicPc = index
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.StyledTextLabel {
                        text: qsTr("Dastgah:")
                    }

                    MU.StyledDropdown {
                        id: presetDropdown
                        Layout.fillWidth: true
                        model: {
                            var names = []
                            for (var i = 0; i < presets.length; ++i) {
                                names.push(presets[i].name)
                            }
                            return names
                        }
                        currentIndex: 2   // Homayoun by default
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.FlatButton {
                        text: qsTr("Apply to selection")
                        onClicked: applyPreset(false)
                    }

                    MU.FlatButton {
                        text: qsTr("Apply to score")
                        onClicked: applyPreset(true)
                    }

                    MU.FlatButton {
                        text: qsTr("Save preset")
                        onClicked: saveCustomPreset()
                    }

                    MU.FlatButton {
                        text: qsTr("Load preset")
                        onClicked: loadCustomPreset()
                    }
                }

                MU.CheckBox {
                    id: accidentalsCheck
                    text: qsTr("Add koron/sori accidentals to quarter-tone notes")
                    checked: true
                }
            }
        }

        // ----- Notes group -----
        MU.StyledGroupBox {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: qsTr("Notes (selection)")

            ColumnLayout {
                width: parent.width
                height: parent.height
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.StyledTextLabel {
                        id: countLabel
                        Layout.fillWidth: true
                    }

                    MU.FlatButton {
                        text: qsTr("Reset to 0")
                        onClicked: resetSelection()
                    }

                    MU.FlatButton {
                        text: qsTr("Refresh")
                        onClicked: refreshNotes()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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
                                        id: noteSlider
                                        Layout.fillWidth: true
                                        from: -100
                                        to: 100
                                        stepSize: 5
                                        value: model.cents
                                        onMoved: previewNoteCents(model.idx, value)
                                        onPressedChanged: {
                                            if (!pressed) {
                                                setNoteCents(model.idx, value)
                                            }
                                        }
                                    }

                                    MU.StyledTextLabel {
                                        text: model.cents + " ¢"
                                        Layout.preferredWidth: 62
                                        Layout.alignment: Qt.AlignRight
                                    }

                                    MU.FlatButton {
                                        text: "Kor"
                                        onClicked: quickTune(model.idx, -50)
                                    }

                                    MU.FlatButton {
                                        text: "Sor"
                                        onClicked: quickTune(model.idx, 50)
                                    }

                                    MU.FlatButton {
                                        text: "0"
                                        onClicked: quickTune(model.idx, 0)
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

        // ----- Status -----
        MU.StyledTextLabel {
            id: statusLabel
            Layout.fillWidth: true
        }
    }
}
