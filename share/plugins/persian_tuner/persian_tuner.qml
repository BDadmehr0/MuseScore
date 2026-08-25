/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * Persian Tuner - sign-oriented (علامت-محور)
 * Each note is identified by letter (C D E F G A B) + accidental variant
 * (flat, koron, natural, sori, sharp). Cents are stored relative to natural
 * of that letter. e.g. La natural is reference 0, La koron -50 means 50 cents
 * flat relative to La natural.
 *
 * Copyright (C) 2026 BDadmehr0
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

    version: "3.0.0"
    title: qsTr("Persian Tuner - علامت‌محور")
    description: qsTr("Tune every sign (letter + accidental) in cents relative to its natural. Marker links to tuning table for range-based changes.")
    pluginType: "dialog"
    categoryCode: "playback"
    thumbnailName: "persian_tuner.png"
    requiresScore: false

    width: 760
    height: 980

    // ------------------------------------------------------------------
    // Data - old kept for backward compatibility with tests
    // ------------------------------------------------------------------

    property var pcNames: Logic.PITCH_CLASS_NAMES
    property int tonicPc: 0
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

    // New sign-oriented data
    property var noteLetters: Logic.NOTE_LETTERS
    property var variantIds: ["flat", "koron", "natural", "sori", "sharp"]
    property string selectedLetter: "A"
    property var tuningTable: Logic.defaultTuningTable()

    // ------------------------------------------------------------------
    // Tool state
    // ------------------------------------------------------------------

    property bool autoMemory: true
    property bool addAccidentals: false
    property bool matchAccidental: true
    property bool perStaffMemory: false

    property bool markerToolArmed: false
    property var pendingMarker: null

    // ------------------------------------------------------------------
    // Runtime state
    // ------------------------------------------------------------------

    property var noteObjects: []
    property var markerEntries: []
    property var memoryStore: Logic.newStore()
    property string scoreId: ""
    property int memoryCounter: 0
    readonly property int noMemoryValue: -99999

    // ------------------------------------------------------------------
    // Persistent settings
    // ------------------------------------------------------------------

    Settings {
        id: options
        category: "Persian Tuner"
        property var customPreset: ''
        property var autoMemory: '1'
        property var accidentals: '0'
        property var matchAccidental: '1'
        property var perStaffMemory: '0'
        property var memory: '{}'
        property var tuningTableJson: ''
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function boolFromSetting(value, fallback) {
        if (value === undefined || value === null || value === "") return fallback
        if (typeof value === "boolean") return value
        return String(value) !== '0'
    }

    function loadSettings() {
        autoMemory = boolFromSetting(options.autoMemory, true)
        addAccidentals = boolFromSetting(options.accidentals, false)
        matchAccidental = boolFromSetting(options.matchAccidental, true)
        perStaffMemory = boolFromSetting(options.perStaffMemory, false)
        tuningTable = Logic.parseTuningTable(options.tuningTableJson)
    }

    function saveSettings() {
        options.autoMemory = autoMemory ? '1' : '0'
        options.accidentals = addAccidentals ? '1' : '0'
        options.matchAccidental = matchAccidental ? '1' : '0'
        options.perStaffMemory = perStaffMemory ? '1' : '0'
        options.memory = Logic.serializeStore(memoryStore)
        options.tuningTableJson = Logic.serializeTuningTable(tuningTable)
    }

    function status(message) {
        statusLabel.text = message
        statusTimer.restart()
    }

    function round1(value) {
        return Math.round(value * 10) / 10
    }

    function syncAccidentalConstants() {
        try {
            Logic.ACC_NONE = 0 + Accidental.NONE
            Logic.ACC_NATURAL = 0 + Accidental.NATURAL
            Logic.ACC_FLAT = 0 + Accidental.FLAT
            Logic.ACC_SHARP = 0 + Accidental.SHARP
            Logic.ACC_SORI = 0 + Accidental.SORI
            Logic.ACC_KORON = 0 + Accidental.KORON
            Logic.REPLACEABLE_ACCIDENTALS = [Logic.ACC_NONE, Logic.ACC_NATURAL, Logic.ACC_SORI, Logic.ACC_KORON, Logic.ACC_FLAT, Logic.ACC_SHARP]
        } catch (e) {}
    }

    function accidentalValue(note) {
        return Logic.normalizeAccidental(note.accidentalType, Accidental)
    }

    function settingsJson() {
        return options.memory
    }

    function currentScoreId() {
        if (!curScore) return ""
        var id = ""
        try { id = curScore.scoreName } catch (e) { id = "" }
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

    function noteTick(note) {
        var fraction = note.fraction
        return fraction ? fraction.ticks : 0
    }

    function noteStaffIdx(note) {
        var idx = note.staffIdx
        return (idx === undefined || idx === null) ? 0 : idx
    }

    // New sign-oriented identity
    function noteIdentity(note) {
        return Logic.noteIdentityFromNote(note, Accidental)
    }

    function memoryKeyFor(note) {
        var ident = noteIdentity(note)
        var staff = noteStaffIdx(note)
        if (!matchAccidental) {
            // pitch class only? For new logic, letter only when not matching accidental
            return Logic.makeSignKey(ident.letter, "natural", staff, { perStaff: perStaffMemory, withAccidental: false }) // we will override to letter only
            // Actually make key letter only
        }
        // when matchAccidental false, key is just letter (or letter+staff)
        if (!matchAccidental) {
            var k = ident.letter
            if (perStaffMemory) k += "@s" + staff
            return k
        }
        return Logic.makeSignKey(ident.letter, ident.variant, staff, { perStaff: perStaffMemory })
    }

    // More precise for table: letter/variant
    function signKeyFor(letter, variant, staffIdx) {
        var opts = { perStaff: perStaffMemory }
        return Logic.makeSignKey(letter, variant, staffIdx || 0, opts)
    }

    function letterFa(letter) {
        return Logic.NOTE_LETTER_PERSIAN[letter] || letter
    }

    function letterFullFa(letter) {
        return Logic.NOTE_LETTER_PERSIAN_FULL[letter] || letter
    }

    function variantFa(variant) {
        return Logic.labelFaForVariant(variant)
    }

    function variantSymbol(variant) {
        return Logic.symbolForVariant(variant)
    }

    function baseCentsForVariant(variant) {
        return Logic.baseCentsForVariant(variant)
    }

    function getTableCents(letter, variant) {
        return Logic.getTuning(tuningTable, letter, variant)
    }

    function effectiveTargetForNote(note) {
        var id = ensureScoreMemory()
        var key = memoryKeyFor(note)
        var tick = noteTick(note)
        var mem = Logic.resolveCents(memoryStore, id, key, tick)
        if (mem !== null) return round1(mem)
        // if matchAccidental false, we need to look up letter only? For simplicity fallback to table with note's variant
        var ident = noteIdentity(note)
        return round1(getTableCents(ident.letter, ident.variant))
    }

    function requiredTuningForNote(note, target) {
        var ident = noteIdentity(note)
        return round1(target - ident.baseCents)
    }

    function noteLabel(note) {
        var ident = noteIdentity(note)
        var pc = note.pitch % 12
        var octave = Math.floor(note.pitch / 12) - 1
        var target = effectiveTargetForNote(note)
        // show letter + variant fa + octave
        return ident.letter + " " + variantFa(ident.variant) + " " + octave + " (" + Logic.formatCents(target) + " نسبت به " + letterFa(ident.letter) + " بکار)"
    }

    function noteLabelShort(note) {
        var ident = noteIdentity(note)
        var octave = Math.floor(note.pitch / 12) - 1
        return ident.letter + " " + variantFa(ident.variant) + " " + octave
    }

    function measureNumberFor(note) {
        try {
            var chord = note.parent
            var measure = chord ? chord.measure : null
            if (measure) return measure.measureNumber
        } catch (e) {}
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

    function firstSelectedNote() {
        var notes = selectedNotes()
        return notes.length > 0 ? notes[0] : null
    }

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

    // Old tuneNotes kept for tests - sets tuning directly
    function tuneNotes(notes, targetCents) {
        for (var i = 0; i < notes.length; ++i) {
            var note = notes[i]
            var ident = noteIdentity(note)
            var current = accidentalValue(note)
            // if addAccidentals, decide accidental based on target
            if (addAccidentals) {
                var intended = current
                if (targetCents <= -75) intended = Accidental.FLAT
                else if (targetCents <= -25) intended = Accidental.KORON
                else if (targetCents < 25) intended = Accidental.NATURAL
                else if (targetCents <= 75) intended = Accidental.SORI
                else intended = Accidental.SHARP
                try {
                    if (intended !== current) note.accidentalType = intended
                } catch (e) {}
            }
            // required tuning = target - base of (new) variant
            var newIdent = noteIdentity(note)
            var required = targetCents - newIdent.baseCents
            note.tuning = round1(required)
        }
        return notes.length
    }

    // New: apply table value to notes without changing accidental (unless addAccidentals)
    function tuneNotesToTarget(notes, targetCents) {
        return tuneNotes(notes, targetCents)
    }

    function rememberAndPropagate(notes, targetCents) {
        if (notes.length === 0) return 0
        var id = ensureScoreMemory()
        var startTicks = {}
        var keyOrder = []
        for (var i = 0; i < notes.length; ++i) {
            var key = memoryKeyFor(notes[i])
            var tick = noteTick(notes[i])
            if (startTicks[key] === undefined) {
                startTicks[key] = tick
                keyOrder.push(key)
            } else if (tick < startTicks[key]) startTicks[key] = tick
        }
        var allNotes = collectScoreNotes()
        var meta = []
        for (var m = 0; m < allNotes.length; ++m) {
            meta.push({ key: memoryKeyFor(allNotes[m]), tick: noteTick(allNotes[m]) })
        }
        var applied = 0
        for (var k = 0; k < keyOrder.length; ++k) {
            var memoryKey = keyOrder[k]
            var range = Logic.setChange(memoryStore, id, memoryKey, startTicks[memoryKey], targetCents)
            var indices = Logic.indicesToTune(meta, memoryKey, range)
            for (var n = 0; n < indices.length; ++n) {
                applied += tuneNotes([allNotes[indices[n]]], targetCents)
            }
        }
        return applied
    }

    // ------------------------------------------------------------------
    // Selection list (new sign-oriented)
    // ------------------------------------------------------------------

    function refreshNotes() {
        notesModel.clear()
        noteObjects = []
        if (!curScore) {
            notesFlick.visible = false
            emptyLabel.visible = true
            countLabel.text = qsTr("Open a score to tune notes")
            selectionSummary.text = qsTr("هیچ نتی انتخاب نشده - یک نت را در پارتیتور انتخاب کنید")
            return
        }
        var id = ensureScoreMemory()
        var notes = selectedNotes()
        var memoryValue = noMemoryValue
        for (var i = 0; i < notes.length; ++i) {
            var note = notes[i]
            noteObjects.push(note)
            var ident = noteIdentity(note)
            var target = effectiveTargetForNote(note)
            var remembered = Logic.resolveCents(memoryStore, id, memoryKeyFor(note), noteTick(note))
            notesModel.append({
                idx: i,
                label: noteLabelShort(note),
                fullLabel: noteLabel(note),
                letter: ident.letter,
                variant: ident.variant,
                base: ident.baseCents,
                cents: round1(target),
                required: round1(target - ident.baseCents),
                remembered: remembered === null ? noMemoryValue : round1(remembered)
            })
            if (i === 0) memoryValue = remembered === null ? noMemoryValue : round1(remembered)
        }
        var hasNotes = notes.length > 0
        notesFlick.visible = hasNotes
        emptyLabel.visible = !hasNotes
        countLabel.text = hasNotes ? qsTr("نت‌های انتخاب شده: ") + notes.length : qsTr("برای کوک، نت‌ها را در پارتیتور انتخاب کنید")

        if (hasNotes) {
            var first = notes[0]
            var ident0 = noteIdentity(first)
            // auto-select letter in table
            if (selectedLetter !== ident0.letter) {
                selectedLetter = ident0.letter
            }
            selectionSummary.text = qsTr("نت: ") + noteLabel(first) + " | تیونینگ فعلی: " + first.tuning + "¢ (required) => هدف: " + Logic.formatCents(effectiveTargetForNote(first)) + " نسبت به " + letterFa(ident0.letter) + " بکار"
            centsControl.currentValue = round1(effectiveTargetForNote(first))
            memoryLabel.text = memoryValue === noMemoryValue ? qsTr("هنوز مقداری به خاطر سپرده نشده") : qsTr("به خاطر سپرده شده: ") + Logic.formatCents(memoryValue)
            // update table controls to reflect selection
            refreshTuningTableControls()
        } else {
            selectionSummary.text = qsTr("هیچ نتی انتخاب نشده")
            memoryLabel.text = ""
        }
    }

    function refreshTuningTableControls() {
        // update the variant controls for selectedLetter
        tableModel.clear()
        for (var i = 0; i < variantIds.length; ++i) {
            var vid = variantIds[i]
            var cents = getTableCents(selectedLetter, vid)
            var base = baseCentsForVariant(vid)
            tableModel.append({
                variant: vid,
                label: variantSymbol(vid) + " " + variantFa(vid),
                base: base,
                cents: round1(cents),
                reference: qsTr("مبنا: ") + letterFa(selectedLetter) + qsTr(" بکار (") + base + "¢) - هدف: " + Logic.formatCents(cents) + qsTr(" نسبت به طبیعی")
            })
        }
        baseReferenceLabel.text = qsTr("مبنای سنت برای ") + letterFullFa(selectedLetter) + qsTr(": ") + letterFa(selectedLetter) + qsTr(" بکار = 0¢ - تمام مقادیر نسبت به ") + letterFa(selectedLetter) + qsTr(" طبیعی سنجیده می‌شوند")
    }

    // ------------------------------------------------------------------
    // Automatic memory
    // ------------------------------------------------------------------

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
            status(qsTr("حداقل یک نت را در پارتیتور انتخاب کنید"))
            return false
        }
        targetCents = round1(targetCents)

        curScore.startCmd(qsTr("Tune notes"))
        tuneNotes(notes, targetCents)
        var applied = notes.length
        if (autoMemory) {
            applied = rememberAndPropagate(notes, targetCents)
        }
        if (pendingMarker) {
            pendingMarker.text = Logic.markerText(targetCents)
            pendingMarker = null
        }
        curScore.endCmd()

        saveSettings()
        memoryCounter = memoryCount()
        refreshNotes()
        refreshMarkers()
        refreshTuningTableControls()
        status(autoMemory ? qsTr("%1 نت کوک شد (از اینجا به بعد)").arg(applied) : qsTr("%1 نت انتخاب شده کوک شد").arg(notes.length))
        return true
    }

    function applyMemoryToSelection() {
        if (!curScore) return
        var id = ensureScoreMemory()
        var notes = selectedNotes()
        if (notes.length === 0) {
            status(qsTr("حداقل یک نت انتخاب کنید"))
            return
        }
        curScore.startCmd(qsTr("Apply remembered tuning"))
        var applied = 0
        for (var i = 0; i < notes.length; ++i) {
            var target = Logic.resolveCents(memoryStore, id, memoryKeyFor(notes[i]), noteTick(notes[i]))
            if (target === null) {
                // fallback to table
                var ident = noteIdentity(notes[i])
                target = getTableCents(ident.letter, ident.variant)
            }
            tuneNotes([notes[i]], target)
            ++applied
        }
        curScore.endCmd()
        refreshNotes()
        status(applied > 0 ? qsTr("مقدار به خاطر سپرده شده به %1 نت اعمال شد").arg(applied) : qsTr("برای نت‌های انتخاب شده چیزی به خاطر سپرده نشده"))
    }

    function reapplyMemory() {
        if (!curScore) return
        var id = ensureScoreMemory()
        var notes = collectScoreNotes()
        curScore.startCmd(qsTr("Re-apply remembered tuning"))
        var applied = 0
        for (var i = 0; i < notes.length; ++i) {
            var target = Logic.resolveCents(memoryStore, id, memoryKeyFor(notes[i]), noteTick(notes[i]))
            if (target === null) {
                var ident = noteIdentity(notes[i])
                target = getTableCents(ident.letter, ident.variant)
            }
            // only apply if target differs from default base? apply all
            tuneNotes([notes[i]], target)
            ++applied
        }
        curScore.endCmd()
        refreshNotes()
        status(qsTr("حافظه به %1 نت اعمال شد").arg(applied))
    }

    function applyTuningTableToScore() {
        if (!curScore) return
        curScore.startCmd(qsTr("Apply tuning table to score"))
        var notes = collectScoreNotes()
        var applied = 0
        for (var i = 0; i < notes.length; ++i) {
            var ident = noteIdentity(notes[i])
            var target = getTableCents(ident.letter, ident.variant)
            // check if memory overrides at this tick - if so skip, because memory is more specific
            var mem = Logic.resolveCents(memoryStore, ensureScoreMemory(), memoryKeyFor(notes[i]), noteTick(notes[i]))
            if (mem !== null) continue
            tuneNotes([notes[i]], target)
            ++applied
        }
        curScore.endCmd()
        refreshNotes()
        status(qsTr("جدول کوک به %1 نت اعمال شد").arg(applied))
    }

    function applyTuningTableToSelection() {
        if (!curScore) return
        var notes = selectedNotes()
        if (notes.length === 0) {
            status(qsTr("نت انتخاب کنید"))
            return
        }
        curScore.startCmd(qsTr("Apply tuning table to selection"))
        for (var i = 0; i < notes.length; ++i) {
            var ident = noteIdentity(notes[i])
            var target = getTableCents(ident.letter, ident.variant)
            tuneNotes([notes[i]], target)
        }
        curScore.endCmd()
        refreshNotes()
        status(qsTr("جدول به انتخاب اعمال شد"))
    }

    function clearMemory() {
        var id = ensureScoreMemory()
        Logic.removeScore(memoryStore, id)
        saveSettings()
        memoryCounter = memoryCount()
        refreshNotes()
        status(qsTr("حافظه خودکار پاک شد"))
    }

    function memoryCount() {
        return Logic.countChanges(memoryStore, ensureScoreMemory())
    }

    function setTableCents(letter, variant, cents) {
        cents = round1(cents)
        Logic.setTuning(tuningTable, letter, variant, cents)
        saveSettings()
        // also set memory at tick 0 for this sign
        var id = ensureScoreMemory()
        var key = signKeyFor(letter, variant, 0)
        // if perStaff, we need to set for all staves? set for staff 0 only for global default, but also update table
        Logic.setChange(memoryStore, id, key, 0, cents)
        // if perStaffMemory, also set for other staves? keep simple
        saveSettings()
        memoryCounter = memoryCount()
        // apply to score where no more specific override
        if (curScore) {
            curScore.startCmd(qsTr("Update tuning table"))
            var allNotes = collectScoreNotes()
            var meta = []
            for (var m = 0; m < allNotes.length; ++m) meta.push({ key: memoryKeyFor(allNotes[m]), tick: noteTick(allNotes[m]) })
            var range = { from: 0, to: null }
            // find next change for this key to limit range
            var changes = Logic.changesFor(memoryStore, id, key)
            if (changes.length > 1) {
                // second change is boundary
                range.to = changes[1].t
            }
            var indices = Logic.indicesToTune(meta, key, range)
            for (var n = 0; n < indices.length; ++n) {
                // only tune if no more specific memory beyond 0? indicesToTune already respects next change
                tuneNotes([allNotes[indices[n]]], cents)
            }
            curScore.endCmd()
        }
        refreshNotes()
        refreshTuningTableControls()
        refreshMarkers()
        status(qsTr("%1 %2 = %3").arg(letter).arg(variantFa(variant)).arg(Logic.formatCents(cents)))
    }

    // ------------------------------------------------------------------
    // Markers - now linked to tuning table
    // ------------------------------------------------------------------

    function toggleMarkerTool() {
        markerToolArmed = !markerToolArmed
        if (markerToolArmed) status(qsTr("ابزار مارکر فعال: روی نتی در پارتیتور کلیک کنید"))
        else {
            pendingMarker = null
            status(qsTr("ابزار مارکر لغو شد"))
        }
        markerHint.visible = markerToolArmed
    }

    function placeMarker(note, targetCents) {
        if (!curScore || !note) return null
        var element = newElement(Element.TEXT)
        if (!element) {
            status(qsTr("ساخت مارکر ممکن نشد"))
            return null
        }
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
        if (!note) {
            status(qsTr("روی یک نت (نه سکوت) کلیک کنید"))
            return false
        }
        var target = effectiveTargetForNote(note)
        var element = placeMarker(note, target)
        if (!element) return false
        markerToolArmed = false
        markerHint.visible = false
        pendingMarker = element
        centsControl.currentValue = target
        // also select letter
        var ident = noteIdentity(note)
        selectedLetter = ident.letter
        refreshTuningTableControls()
        status(qsTr("مارکر اضافه شد - مقدار را تنظیم کنید و Apply بزنید"))
        try {
            var win = root.Window.window
            if (win) { win.raise(); win.requestActivate() }
        } catch (e) {}
        return true
    }

    function refreshMarkers() {
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
                if (el.type != Element.TEXT) continue
                var parsed = Logic.parseMarkerText(el.text)
                if (!parsed) continue
                var ident = noteIdentity(note)
                markerEntries.push({ note: note, element: el, letter: ident.letter, variant: ident.variant })
                markersModel.append({
                    idx: markerEntries.length - 1,
                    label: qsTr("میزان ") + measureNumberFor(note) + " - " + noteLabelShort(note),
                    cents: round1(parsed.cents),
                    detail: ident.letter + " " + variantFa(ident.variant) + " = " + Logic.formatCents(parsed.cents)
                })
            }
        }
        markersGroup.visible = markerEntries.length > 0
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
        status(qsTr("مارکر حذف شد"))
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
        status(qsTr("همه مارکرها حذف شدند"))
    }

    // ------------------------------------------------------------------
    // Presets (kept for backward compat, hidden in UI)
    // ------------------------------------------------------------------

    function applyPreset(wholeScore) {
        if (typeof presetDropdown !== "undefined") applyPresetAt(presetDropdown.currentIndex, wholeScore)
    }

    function applyPresetAt(presetIndex, wholeScore) {
        if (!curScore) return
        if (presetIndex < 0 || presetIndex >= presets.length) return
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
                for (var j = 0; j < chords.length; ++j) if (chords[j].is(el.parent)) { add = false; break }
                if (add) chords.push(el.parent)
            }
        }
        for (var c = 0; c < chords.length; ++c) {
            var notes = chords[c].notes
            for (var n = 0; n < notes.length; ++n) {
                var note = notes[n]
                var relative = (note.pitch % 12 - tonic + 12) % 12
                // old offsets are tuning directly, convert to target
                var ident = noteIdentity(note)
                var target = offsets[relative] + ident.baseCents // offsets were relative to natural? old was direct tuning
                tuneNotes([note], target)
            }
        }
        curScore.endCmd()
        refreshNotes()
        status(qsTr("Preset applied to %1 chord(s)").arg(chords.length))
    }

    function resetSelection() { commitCents(0) }

    function saveCustomPreset() {
        // save tuning table as custom
        options.customPreset = JSON.stringify(tuningTable)
        status(qsTr("جدول کوک ذخیره شد"))
    }

    function loadCustomPreset() {
        if (!options.customPreset || options.customPreset === "") {
            status(qsTr("جدول ذخیره شده‌ای وجود ندارد"))
            return
        }
        try {
            var data = JSON.parse(options.customPreset)
            // if it's old preset format, ignore
            if (data && typeof data === "object" && !data["C"]) {
                status(qsTr("فرمت قدیمی - نادیده گرفته شد"))
                return
            }
            tuningTable = Logic.parseTuningTable(options.customPreset)
            saveSettings()
            refreshTuningTableControls()
            applyTuningTableToScore()
            status(qsTr("جدول کوک بارگذاری شد"))
        } catch (e) {
            status(qsTr("بارگذاری جدول ممکن نشد"))
        }
    }

    // ------------------------------------------------------------------
    // Lifecycle
    // ------------------------------------------------------------------

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
        if (state.undoRedo) {
            refreshNotes()
            refreshMarkers()
            return
        }
        if (state.selectionChanged) {
            if (markerToolArmed) {
                if (handleMarkerClick()) centsControl.forceActiveFocus()
            } else {
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

    ListModel { id: notesModel }
    ListModel { id: markersModel }
    ListModel { id: tableModel }

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

                    MU.FlatButton { text: qsTr("Re-apply"); onClicked: root.reapplyMemory() }
                    MU.FlatButton { text: qsTr("Clear memory"); onClicked: root.clearMemory() }

                    Item { Layout.fillWidth: true }

                    MU.StyledTextLabel { text: qsTr("Remembered values: ") }
                    MU.StyledTextLabel { id: memoryCountLabel; text: String(root.memoryCounter) }
                }

                MU.StyledTextLabel {
                    id: markerHint
                    Layout.fillWidth: true
                    visible: false
                    text: qsTr("ابزار مارکر فعال: روی نتی در پارتیتور کلیک کنید. از آن نقطه به بعد، علامت انتخاب شده با کوک جدید صدا می‌دهد. مارکر در پارتیتور می‌ماند.")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.StyledTextLabel { text: qsTr("تطبیق نت‌ها بر اساس:") }

                    MU.StyledDropdown {
                        id: matchDropdown
                        Layout.preferredWidth: 200
                        model: [qsTr("حرف نت (C,D...)"), qsTr("حرف + علامت (A کرن)") ]
                        currentIndex: root.matchAccidental ? 1 : 0
                        onActivated: function(index, value) {
                            root.matchAccidental = (index === 1)
                            root.saveSettings()
                            root.refreshNotes()
                        }
                    }

                    MU.CheckBox {
                        id: perStaffCheck
                        text: qsTr("جدا برای هر حامل")
                        checked: root.perStaffMemory
                        onClicked: {
                            root.perStaffMemory = !root.perStaffMemory
                            root.saveSettings()
                            root.refreshNotes()
                        }
                    }

                    MU.CheckBox {
                        id: accidentalsCheck
                        text: qsTr("نوشتن علامت کرن/سری")
                        checked: root.addAccidentals
                        onClicked: {
                            root.addAccidentals = !root.addAccidentals
                            root.saveSettings()
                        }
                    }
                }
            }
        }

        // ----- Tuning Table (sign-oriented) ----------------------------
        MU.StyledGroupBox {
            Layout.fillWidth: true
            title: qsTr("جدول کوک علامت‌محور - هر علامت نسبت به بکار همان نت")

            ColumnLayout {
                width: parent.width
                spacing: 8

                MU.StyledTextLabel {
                    Layout.fillWidth: true
                    text: qsTr("منطق: نت را انتخاب کنید (مثلاً لا)، سپس در پنل کناری علامت را انتخاب کنید (کرن، بکار، سری...) و سنت را تنظیم کنید. سنت همیشه نسبت به نت بکار همان حرف سنجیده می‌شود. مثلاً لا کرن -50¢ یعنی 50 سنت بم‌تر از لا بکار.")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MU.StyledTextLabel { text: qsTr("حرف نت:") }

                    Repeater {
                        model: root.noteLetters
                        delegate: MU.FlatButton {
                            text: modelData + " (" + letterFa(modelData) + ")"
                            // highlight selected
                            property bool isSelected: root.selectedLetter === modelData
                            // use accent color via opacity?
                            onClicked: {
                                root.selectedLetter = modelData
                                root.refreshTuningTableControls()
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MU.FlatButton {
                        text: qsTr("اعمال جدول به کل قطعه")
                        onClicked: root.applyTuningTableToScore()
                    }

                    MU.FlatButton {
                        text: qsTr("ذخیره جدول")
                        onClicked: root.saveCustomPreset()
                    }

                    MU.FlatButton {
                        text: qsTr("بارگذاری جدول")
                        onClicked: root.loadCustomPreset()
                    }
                }

                MU.StyledTextLabel {
                    id: baseReferenceLabel
                    Layout.fillWidth: true
                    text: qsTr("مبنا: لا بکار = 0¢")
                }

                // Variant rows
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: tableModel

                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            MU.StyledTextLabel {
                                text: model.label
                                Layout.preferredWidth: 90
                            }

                            MU.StyledTextLabel {
                                text: model.base + "¢ پایه"
                                Layout.preferredWidth: 70
                                opacity: 0.7
                            }

                            MU.IncrementalPropertyControl {
                                Layout.preferredWidth: 130
                                currentValue: model.cents
                                decimals: 1
                                step: 1
                                minValue: -150
                                maxValue: 150
                                measureUnitsSymbol: "¢"
                                onValueEdited: function(newValue) {
                                    // preview: update table model but not yet save? we save on finished
                                }
                                onValueEditingFinished: function(newValue) {
                                    root.setTableCents(root.selectedLetter, model.variant, newValue)
                                }
                            }

                            MU.StyledSlider {
                                Layout.fillWidth: true
                                from: -100
                                to: 100
                                stepSize: 1
                                value: model.cents
                                onMoved: {
                                    // live preview for selected notes matching this sign?
                                }
                                onPressedChanged: {
                                    if (!pressed) {
                                        root.setTableCents(root.selectedLetter, model.variant, value)
                                    }
                                }
                            }

                            MU.StyledTextLabel {
                                text: model.cents + "¢"
                                Layout.preferredWidth: 50
                            }

                            MU.StyledTextLabel {
                                Layout.fillWidth: true
                                text: model.reference
                                opacity: 0.8
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.FlatButton {
                        text: qsTr("اعمال به انتخاب")
                        onClicked: root.applyTuningTableToSelection()
                    }

                    MU.StyledTextLabel {
                        Layout.fillWidth: true
                        text: qsTr("هر ردیف: علامت + سنت نسبت به بکار همان حرف. مثلاً می بکار = 0، می کرن = -50، می سری = +50 به صورت پیش‌فرض، قابل تنظیم دقیق.")
                        opacity: 0.7
                    }
                }
            }
        }

        // ----- Selection cent tuning -----------------------------------
        MU.StyledGroupBox {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: qsTr("کوک انتخاب (سنت نسبت به بکار)")

            ColumnLayout {
                width: parent.width
                height: parent.height
                spacing: 8

                MU.StyledTextLabel {
                    id: selectionSummary
                    Layout.fillWidth: true
                    text: qsTr("هیچ نتی انتخاب نشده")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MU.IncrementalPropertyControl {
                        id: centsControl
                        Layout.preferredWidth: 150
                        currentValue: 0
                        decimals: 1
                        step: 1
                        minValue: -150
                        maxValue: 150
                        measureUnitsSymbol: "¢"
                        onValueEdited: function(newValue) { root.previewCents(newValue) }
                        onValueEditingFinished: function(newValue) { root.commitCents(newValue) }
                    }

                    MU.FlatButton { text: qsTr("کرن -50"); onClicked: root.commitCents(-50) }
                    MU.FlatButton { text: qsTr("بکار 0"); onClicked: root.commitCents(0) }
                    MU.FlatButton { text: qsTr("سری +50"); onClicked: root.commitCents(50) }
                    MU.FlatButton { text: qsTr("اعمال"); onClicked: root.commitCents(centsControl.currentValue) }
                    MU.FlatButton { text: qsTr("استفاده از حافظه"); onClicked: root.applyMemoryToSelection() }
                    Item { Layout.fillWidth: true }
                }

                MU.StyledTextLabel { id: memoryLabel; Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MU.StyledTextLabel { id: countLabel; Layout.fillWidth: true }
                    MU.FlatButton { text: qsTr("تازه‌سازی"); onClicked: root.refreshNotes() }
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
                                        Layout.preferredWidth: 90
                                    }

                                    MU.StyledSlider {
                                        Layout.fillWidth: true
                                        from: -150
                                        to: 150
                                        stepSize: 1
                                        value: model.cents
                                        onMoved: {
                                            if (model.idx >= 0 && model.idx < root.noteObjects.length) {
                                                var ident = root.noteIdentity(root.noteObjects[model.idx])
                                                root.noteObjects[model.idx].tuning = value - ident.baseCents
                                            }
                                        }
                                        onPressedChanged: {
                                            if (!pressed) root.commitCents(value)
                                        }
                                    }

                                    MU.StyledTextLabel {
                                        text: model.cents + "¢ نسبت به بکار"
                                        Layout.preferredWidth: 130
                                    }

                                    MU.StyledTextLabel {
                                        text: model.required + "¢ تیونینگ"
                                        Layout.preferredWidth: 90
                                        opacity: 0.7
                                    }

                                    MU.StyledTextLabel {
                                        text: model.remembered === root.noMemoryValue ? "" : qsTr("حافظه ") + model.remembered
                                        Layout.preferredWidth: 70
                                    }
                                }
                            }
                        }
                    }
                }

                MU.StyledTextLabel {
                    id: emptyLabel
                    Layout.fillWidth: true
                    text: qsTr("نت‌ها را در پارتیتور انتخاب کنید تا اینجا کوک شوند. مقدار سنت همیشه نسبت به بکار همان حرف است. مثلاً لا کرن را انتخاب کنید، مقدار -45 را بدهید یعنی 45 سنت بم‌تر از لا بکار.")
                }
            }
        }

        // ----- Markers (linked to table) --------------------------------
        MU.StyledGroupBox {
            id: markersGroup
            Layout.fillWidth: true
            visible: false
            title: qsTr("مارکرهای کوک - لینک به جدول")

            ColumnLayout {
                width: parent.width
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MU.StyledTextLabel {
                        Layout.fillWidth: true
                        text: qsTr("مارکرها نقاطی هستند که از آنجا به بعد، یک علامت خاص با کوک جدید صدا می‌دهد. مثلاً از میزان 10 تا 20، لا کرن = -40¢ نسبت به لا بکار، بقیه دیفالت.")
                    }
                    MU.FlatButton { text: qsTr("حذف همه"); onClicked: root.removeAllMarkers() }
                }

                Repeater {
                    model: markersModel
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MU.StyledTextLabel { text: Logic.MARKER_GLYPH; Layout.preferredWidth: 16 }
                        MU.StyledTextLabel { text: model.label; Layout.fillWidth: true }
                        MU.StyledTextLabel { text: model.detail; Layout.preferredWidth: 180 }
                        MU.FlatButton { text: qsTr("برو"); onClicked: root.gotoMarker(model.idx) }
                        MU.FlatButton { text: qsTr("حذف"); onClicked: root.removeMarker(model.idx) }
                    }
                }
            }
        }

        // ----- Status ---------------------------------------------------
    }
}
