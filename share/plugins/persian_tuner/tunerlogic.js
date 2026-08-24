/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Persian Tuner - core logic (no Qt/MuseScore dependencies)
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

.pragma library

// ---------------------------------------------------------------------------
// Constants
//
// Accidental values mirror mu::engraving::AccidentalType (see
// src/engraving/dom/accidental.h). They are duplicated here so this file stays
// free of any MuseScore dependency and can be unit tested on its own; the
// plugin itself always passes the values it reads from the "Accidental" enum
// of the plugin API.
// ---------------------------------------------------------------------------

var ACC_NONE = 0
var ACC_NATURAL = 2
var ACC_SORI = 89
var ACC_KORON = 90

/// Accidentals that this plugin is allowed to replace with koron/sori.
/// Anything else (sharp, flat, double sharp, ...) is a deliberate spelling and
/// is left untouched.
var REPLACEABLE_ACCIDENTALS = [ACC_NONE, ACC_NATURAL, ACC_SORI, ACC_KORON]

var MEMORY_VERSION = 1
var MAX_STORED_SCORES = 24

/// The glyph used for the (always visible) tuning markers in the score.
var MARKER_GLYPH = "\u2691"
var CENT_SIGN = "\u00A2"

// ---------------------------------------------------------------------------
// Note identity
// ---------------------------------------------------------------------------

/// Converts an accidental value read from the plugin API into a plain number.
///
/// Depending on the MuseScore version \c note.accidentalType can come back as
/// a number or as the name of the enumeration value, so every comparison goes
/// through this function.
///
/// \param value       the raw value read from a note
/// \param enumLookup  the "Accidental" enumeration object of the plugin API
function normalizeAccidental(value, enumLookup)
{
    if (typeof value === "number") {
        return value
    }
    if (typeof value === "string") {
        if (enumLookup && enumLookup[value] !== undefined) {
            return enumLookup[value]
        }
        var parsed = parseInt(value, 10)
        return isNaN(parsed) ? ACC_NONE : parsed
    }
    if (value === undefined || value === null) {
        return ACC_NONE
    }
    var asNumber = Number(value)
    return isNaN(asNumber) ? ACC_NONE : asNumber
}

/// Accidental that should be written for a note tuned by \p cents.
///
/// \param currentAccidentalType accidental the note currently has
/// \param cents                 requested tuning offset, in cents
/// \param addAccidentals        whether koron/sori signs may be written at all
///
/// Returns the accidental type to use, which may be the unchanged input value
/// (when the note carries an accidental we must not touch).
function intendedAccidental(currentAccidentalType, cents, addAccidentals)
{
    if (!addAccidentals) {
        return currentAccidentalType
    }
    if (REPLACEABLE_ACCIDENTALS.indexOf(currentAccidentalType) < 0) {
        return currentAccidentalType
    }
    if (cents > 0) {
        return ACC_SORI
    }
    if (cents < 0) {
        return ACC_KORON
    }
    // Back to 0 cents: drop a quarter-tone sign, keep anything else.
    if (currentAccidentalType === ACC_SORI || currentAccidentalType === ACC_KORON) {
        return ACC_NONE
    }
    return currentAccidentalType
}

/// Pitch class names, index = MIDI pitch modulo 12.
var PITCH_CLASS_NAMES = ["C", "C\u266F/D\u266D", "D", "D\u266F/E\u266D", "E", "F",
    "F\u266F/G\u266D", "G", "G\u266F/A\u266D", "A", "A\u266F/B\u266D", "B"]

/// Stable identity of "that note", e.g. "F with a sori".
///
/// The octave is deliberately not part of the key: in Persian music an
/// "F sori" is the same note wherever it appears in the piece.
///
/// By default only the pitch class is used. A koron/sori sign is notation, not
/// pitch, and is usually only written where the notation rules ask for it, so
/// including it in the key would split one logical note into several ones.
///
/// \param pitchClass      MIDI pitch modulo 12
/// \param accidentalType  accidental of the note (used when \p withAccidental)
/// \param staffIdx        staff index (used when \p perStaff)
/// \param options         { perStaff: <bool>, withAccidental: <bool> }
function makeKey(pitchClass, accidentalType, staffIdx, options)
{
    var opts = options || {}
    var key = String(pitchClass)
    if (opts.withAccidental) {
        key += "/" + accidentalType
    }
    if (opts.perStaff) {
        key += "@s" + staffIdx
    }
    return key
}

/// Inverse of makeKey(). Returns null for malformed keys.
function keyParts(key)
{
    if (typeof key !== "string") {
        return null
    }
    var staffIdx = -1
    var at = key.lastIndexOf("@s")
    var base = key
    if (at >= 0) {
        var suffix = key.substring(at + 2)
        if (!/^\d+$/.test(suffix)) {
            return null
        }
        staffIdx = parseInt(suffix, 10)
        base = key.substring(0, at)
    }
    var parts = base.split("/")
    if (parts.length < 1 || parts.length > 2 || !/^\d+$/.test(parts[0])) {
        return null
    }
    if (parts.length === 2 && !/^-?\d+$/.test(parts[1])) {
        return null
    }
    return {
        pitchClass: parseInt(parts[0], 10),
        accidentalType: parts.length === 2 ? parseInt(parts[1], 10) : null,
        staffIdx: staffIdx
    }
}

/// Letter + accidental name for a tonal pitch class, e.g. 13 -> "F", 20 -> "F#".
function tpcName(tpc)
{
    var letters = ["F", "C", "G", "D", "A", "E", "B"]
    var delta = tpc - 13              // 13 == F natural, see Tpc enum in pitchspelling.h
    var fifths = Math.floor(delta / 7)
    var index = ((delta % 7) + 7) % 7
    var name = letters[index]
    if (fifths > 0) {
        for (var i = 0; i < fifths; ++i) {
            name += "\u266F"          // sharp
        }
    } else if (fifths < 0) {
        for (var j = 0; j < -fifths; ++j) {
            name += "\u266D"          // flat
        }
    }
    return name
}

function pitchClassName(pitchClass)
{
    var index = ((pitchClass % 12) + 12) % 12
    return PITCH_CLASS_NAMES[index]
}

function accidentalName(accidentalType)
{
    if (accidentalType === ACC_SORI) {
        return "sori"
    }
    if (accidentalType === ACC_KORON) {
        return "koron"
    }
    return ""
}

/// Human readable description of a memory key, e.g. "F sori (staff 2)".
function describeKey(key)
{
    var parts = keyParts(key)
    if (!parts) {
        return String(key)
    }
    var text = pitchClassName(parts.pitchClass)
    var acc = accidentalName(parts.accidentalType)
    if (acc !== "") {
        text += " " + acc
    }
    if (parts.staffIdx >= 0) {
        text += " (staff " + (parts.staffIdx + 1) + ")"
    }
    return text
}

// ---------------------------------------------------------------------------
// Cents formatting / rounding
// ---------------------------------------------------------------------------

function roundCents(cents, step)
{
    if (!step || step <= 0) {
        return Math.round(cents * 10) / 10
    }
    return Math.round(cents / step) * step
}

/// "+30 ¢" / "-50 ¢" / "0 ¢"
function formatCents(cents)
{
    var rounded = Math.round(cents * 10) / 10
    var text = (rounded > 0 ? "+" : "") + rounded
    return text + " " + CENT_SIGN
}

/// Compact form used inside the score marker, e.g. "+30".
function formatCentsCompact(cents)
{
    var rounded = Math.round(cents * 10) / 10
    return (rounded > 0 ? "+" : "") + rounded
}

// ---------------------------------------------------------------------------
// Memory store
//
// The store is a plain JSON-serialisable object so it can be persisted through
// the plugin Settings element. Its shape is:
//
//   {
//     "version": 1,
//     "order": ["<scoreId>", ...],        // least recently used first
//     "scores": {
//        "<scoreId>": {
//            "keys": { "<noteKey>": [ { "t": <tick>, "c": <cents> }, ... ] }
//        }
//     }
//   }
//
// Each entry of a key list is a "from this position on, use this many cents"
// event. The list is always kept sorted by tick.
// ---------------------------------------------------------------------------

function newStore()
{
    return { version: MEMORY_VERSION, order: [], scores: {} }
}

function parseStore(text)
{
    if (!text || typeof text !== "string") {
        return newStore()
    }
    var parsed = null
    try {
        parsed = JSON.parse(text)
    } catch (e) {
        return newStore()
    }
    if (!parsed || typeof parsed !== "object" || typeof parsed.scores !== "object" || parsed.scores === null) {
        return newStore()
    }
    var store = newStore()
    store.scores = {}
    for (var scoreId in parsed.scores) {
        var src = parsed.scores[scoreId]
        if (!src || typeof src.keys !== "object" || src.keys === null) {
            continue
        }
        var keys = {}
        for (var key in src.keys) {
            var list = []
            var raw = src.keys[key]
            for (var i = 0; raw && i < raw.length; ++i) {
                var entry = raw[i]
                if (!entry || typeof entry.t !== "number" || typeof entry.c !== "number") {
                    continue
                }
                list.push({ t: entry.t, c: entry.c })
            }
            if (list.length > 0) {
                keys[key] = sortChanges(list)
            }
        }
        store.scores[scoreId] = { keys: keys }
    }
    store.order = []
    if (parsed.order && parsed.order.length) {
        for (var o = 0; o < parsed.order.length; ++o) {
            if (store.scores[parsed.order[o]]) {
                store.order.push(parsed.order[o])
            }
        }
    }
    for (var sid in store.scores) {
        if (store.order.indexOf(sid) < 0) {
            store.order.push(sid)
        }
    }
    return store
}

function serializeStore(store)
{
    return JSON.stringify(store)
}

function sortChanges(list)
{
    list.sort(function(a, b) { return a.t - b.t })
    return list
}

function hasScore(store, scoreId)
{
    return !!store.scores[scoreId]
}

function scoreEntry(store, scoreId, create)
{
    var entry = store.scores[scoreId]
    if (entry) {
        touch(store, scoreId)
        return entry
    }
    if (!create) {
        return null
    }
    entry = { keys: {} }
    store.scores[scoreId] = entry
    touch(store, scoreId)
    prune(store, MAX_STORED_SCORES)
    return entry
}

function touch(store, scoreId)
{
    var idx = store.order.indexOf(scoreId)
    if (idx >= 0) {
        store.order.splice(idx, 1)
    }
    store.order.push(scoreId)
}

/// Keeps at most \p maxScores scores in the store, dropping the oldest ones.
function prune(store, maxScores)
{
    while (store.order.length > maxScores) {
        var oldest = store.order.shift()
        delete store.scores[oldest]
    }
}

function removeScore(store, scoreId)
{
    var idx = store.order.indexOf(scoreId)
    if (idx >= 0) {
        store.order.splice(idx, 1)
    }
    delete store.scores[scoreId]
}

function keysOf(store, scoreId)
{
    var entry = store.scores[scoreId]
    if (!entry) {
        return []
    }
    var result = []
    for (var key in entry.keys) {
        result.push(key)
    }
    return result
}

function changesFor(store, scoreId, key)
{
    var entry = store.scores[scoreId]
    if (!entry || !entry.keys[key]) {
        return []
    }
    return entry.keys[key]
}

/// Number of stored change events for one score (used for status messages).
function countChanges(store, scoreId)
{
    var entry = store.scores[scoreId]
    if (!entry) {
        return 0
    }
    var total = 0
    for (var key in entry.keys) {
        total += entry.keys[key].length
    }
    return total
}

/// Records "from \p tick on, <key> is tuned by \p cents" and returns the range
/// of the score that this change is responsible for.
///
/// The returned range stops at the next change event for the same key, so
/// explicit decisions made later in the piece are never overwritten.
///
/// \returns { from: <tick>, to: <tick or null>, cents: <cents> }
function setChange(store, scoreId, key, tick, cents)
{
    var entry = scoreEntry(store, scoreId, true)
    var list = entry.keys[key]
    if (!list) {
        list = []
        entry.keys[key] = list
    }
    var replaced = false
    for (var i = 0; i < list.length; ++i) {
        if (list[i].t === tick) {
            list[i].c = cents
            replaced = true
            break
        }
    }
    if (!replaced) {
        list.push({ t: tick, c: cents })
    }
    sortChanges(list)

    var to = null
    for (var j = 0; j < list.length; ++j) {
        if (list[j].t > tick) {
            to = list[j].t
            break
        }
    }
    return { from: tick, to: to, cents: cents }
}

/// Removes every change event for \p key at or after \p tick.
/// Returns the range that now falls back to the previous value.
function clearChangesFrom(store, scoreId, key, tick)
{
    var entry = store.scores[scoreId]
    if (!entry || !entry.keys[key]) {
        return { from: tick, to: null }
    }
    var kept = []
    var to = null
    var list = entry.keys[key]
    for (var i = 0; i < list.length; ++i) {
        if (list[i].t < tick) {
            kept.push(list[i])
        } else if (to === null) {
            to = list[i].t
        }
    }
    if (kept.length === 0) {
        delete entry.keys[key]
    } else {
        entry.keys[key] = kept
    }
    return { from: tick, to: to }
}

/// Cents in effect for \p key at \p tick, or null when nothing was ever set
/// at or before that position.
function resolveCents(store, scoreId, key, tick)
{
    var entry = store.scores[scoreId]
    if (!entry || !entry.keys[key]) {
        return null
    }
    var list = entry.keys[key]
    var cents = null
    for (var i = 0; i < list.length; ++i) {
        if (list[i].t <= tick) {
            cents = list[i].c
        } else {
            break
        }
    }
    return cents
}

/// Indexes of the notes that a change starting at \p range.from should be
/// applied to.
///
/// \param notesMeta array of { key: <string>, tick: <number> }, aligned with
///                  the caller's own array of notes
function indicesToTune(notesMeta, key, range)
{
    var result = []
    if (!range) {
        return result
    }
    for (var i = 0; i < notesMeta.length; ++i) {
        var meta = notesMeta[i]
        if (!meta || meta.key !== key) {
            continue
        }
        if (meta.tick < range.from) {
            continue
        }
        if (range.to !== null && range.to !== undefined && meta.tick >= range.to) {
            continue
        }
        result.push(i)
    }
    return result
}

/// Value each note of \p notesMeta should have when the whole memory is
/// re-applied. Returns an array of cents values, null where the memory has
/// nothing to say (the note keeps whatever it has).
function resolveAll(notesMeta, store, scoreId)
{
    var result = []
    for (var i = 0; i < notesMeta.length; ++i) {
        var meta = notesMeta[i]
        result.push(meta ? resolveCents(store, scoreId, meta.key, meta.tick) : null)
    }
    return result
}

// ---------------------------------------------------------------------------
// Score markers
//
// A marker is a small always-visible text element attached to a note. Its text
// both documents the change for the reader of the score and lets the plugin
// find the marker again later on.
// ---------------------------------------------------------------------------

function markerText(cents)
{
    return MARKER_GLYPH + " " + formatCentsCompact(cents)
}

/// Parses a marker text. Returns { cents: <number> } or null when \p text is
/// not a marker written by this plugin.
function parseMarkerText(text)
{
    if (typeof text !== "string") {
        return null
    }
    var match = text.match(new RegExp("^" + MARKER_GLYPH + "\\s*([+-]?\\d+(?:\\.\\d+)?)\\s*" + CENT_SIGN + "?$"))
    if (!match) {
        return null
    }
    return { cents: parseFloat(match[1]) }
}

function isMarkerText(text)
{
    return parseMarkerText(text) !== null
}

// ---------------------------------------------------------------------------
// Dastgah presets
// ---------------------------------------------------------------------------

/// Returns the 12 cent offsets of a preset, indexed by pitch class relative to
/// the tonic (0 = tonic).
function offsetsForPreset(preset)
{
    var offsets = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    if (!preset) {
        return offsets
    }
    var degreeToPc = [0, 2, 4, 5, 7, 9, 11]
    var koron = preset.koron || []
    var sori = preset.sori || []
    for (var i = 0; i < koron.length; ++i) {
        var downIdx = koron[i] - 1
        if (downIdx >= 0 && downIdx < 7) {
            offsets[degreeToPc[downIdx]] = -50
        }
    }
    for (var j = 0; j < sori.length; ++j) {
        var upIdx = sori[j] - 1
        if (upIdx >= 0 && upIdx < 7) {
            offsets[degreeToPc[upIdx]] = 50
        }
    }
    return offsets
}

function presetNames(presets)
{
    var names = []
    for (var i = 0; i < presets.length; ++i) {
        names.push(presets[i].name)
    }
    return names
}

/// Index of the preset with the given name, or -1.
function indexOfPreset(presets, name)
{
    for (var i = 0; i < presets.length; ++i) {
        if (presets[i].name === name) {
            return i
        }
    }
    return -1
}
