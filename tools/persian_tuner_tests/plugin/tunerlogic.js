/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * Persian Tuner - core logic (no Qt/MuseScore dependencies)
 *
 * New logic: sign-oriented (علامت-محور). Each note is identified by
 * its letter (C D E F G A B) + accidental variant (flat, koron, natural,
 * sori, sharp). Cents are stored relative to the natural of that letter.
 *
 * Example: La (A) natural is the reference 0. La koron default -50 means
 * 50 cents flat relative to La natural. User can fine-tune it to -45, -48, etc.
 * The required MuseScore note.tuning = target - baseCentsOfVariant.
 */

.pragma library

// ---------------------------------------------------------------------------
// Accidental constants (mirror mu::engraving::AccidentalType)
// ---------------------------------------------------------------------------

var ACC_NONE = 0
var ACC_FLAT = 1
var ACC_NATURAL = 2
var ACC_SHARP = 3
var ACC_SHARP2 = 4
var ACC_FLAT2 = 5
var ACC_SORI = 89
var ACC_KORON = 90

var REPLACEABLE_ACCIDENTALS = [ACC_NONE, ACC_NATURAL, ACC_SORI, ACC_KORON, ACC_FLAT, ACC_SHARP]

var MEMORY_VERSION = 1
var MAX_STORED_SCORES = 24

var MARKER_GLYPH = "\u2691"
var CENT_SIGN = "\u00A2"

// ---------------------------------------------------------------------------
// Note letters and Persian names
// ---------------------------------------------------------------------------

var NOTE_LETTERS = ["C", "D", "E", "F", "G", "A", "B"]

var NOTE_LETTER_PERSIAN = {
    "C": "دو",
    "D": "رِ",
    "E": "می",
    "F": "فا",
    "G": "سل",
    "A": "لا",
    "B": "سی"
}

var NOTE_LETTER_PERSIAN_FULL = {
    "C": "دو (C)",
    "D": "رِ (D)",
    "E": "می (E)",
    "F": "فا (F)",
    "G": "سل (G)",
    "A": "لا (A)",
    "B": "سی (B)"
}

// Pitch class names for fallback (old)
var PITCH_CLASS_NAMES = ["C", "C\u266F/D\u266D", "D", "D\u266F/E\u266D", "E", "F",
    "F\u266F/G\u266D", "G", "G\u266F/A\u266D", "A", "A\u266F/B\u266D", "B"]

// ---------------------------------------------------------------------------
// Accidental variants - the core of sign-oriented logic
// ---------------------------------------------------------------------------

var ACC_VARIANT_DEFS = [
    {
        id: "flat",
        fa: "بمل",
        en: "Flat",
        baseCents: -100,
        symbol: "\u266D",
        accTypes: [ACC_FLAT, ACC_FLAT2],
        persianSymbol: "♭"
    },
    {
        id: "koron",
        fa: "کُرُن",
        en: "Koron",
        baseCents: -50,
        symbol: "\uD834\uDD33", // fallback, actually koron glyph may not render, use text
        accTypes: [ACC_KORON],
        persianSymbol: "𝄳"
    },
    {
        id: "natural",
        fa: "بکار",
        en: "Natural",
        baseCents: 0,
        symbol: "\u266E",
        accTypes: [ACC_NONE, ACC_NATURAL],
        persianSymbol: "♮"
    },
    {
        id: "sori",
        fa: "سُری",
        en: "Sori",
        baseCents: 50,
        symbol: "\uD834\uDD32",
        accTypes: [ACC_SORI],
        persianSymbol: "𝄲"
    },
    {
        id: "sharp",
        fa: "دیز",
        en: "Sharp",
        baseCents: 100,
        symbol: "\u266F",
        accTypes: [ACC_SHARP, ACC_SHARP2],
        persianSymbol: "♯"
    }
]

function variantDefById(id) {
    for (var i = 0; i < ACC_VARIANT_DEFS.length; ++i) {
        if (ACC_VARIANT_DEFS[i].id === id) return ACC_VARIANT_DEFS[i]
    }
    return null
}

function baseCentsForVariant(variantId) {
    var def = variantDefById(variantId)
    return def ? def.baseCents : 0
}

function symbolForVariant(variantId) {
    var def = variantDefById(variantId)
    return def ? def.persianSymbol : variantId
}

function labelFaForVariant(variantId) {
    var def = variantDefById(variantId)
    return def ? def.fa : variantId
}

function labelEnForVariant(variantId) {
    var def = variantDefById(variantId)
    return def ? def.en : variantId
}

function variantForAccType(accType) {
    var n = normalizeAccidental(accType, null)
    for (var i = 0; i < ACC_VARIANT_DEFS.length; ++i) {
        var def = ACC_VARIANT_DEFS[i]
        if (def.accTypes.indexOf(n) >= 0) return def.id
    }
    // fallback by range
    if (n === ACC_NONE) return "natural"
    // unknown -> natural
    return "natural"
}

// ---------------------------------------------------------------------------
// TPC helpers (tonal pitch class)
// ---------------------------------------------------------------------------

function tpcName(tpc) {
    var letters = ["F", "C", "G", "D", "A", "E", "B"]
    var delta = tpc - 13
    var fifths = Math.floor(delta / 7)
    var index = ((delta % 7) + 7) % 7
    var name = letters[index]
    if (fifths > 0) {
        for (var i = 0; i < fifths; ++i) name += "\u266F"
    } else if (fifths < 0) {
        for (var j = 0; j < -fifths; ++j) name += "\u266D"
    }
    return name
}

function letterFromTpc(tpc) {
    if (typeof tpc !== "number") return null
    var letters = ["F", "C", "G", "D", "A", "E", "B"]
    var delta = tpc - 13
    var index = ((delta % 7) + 7) % 7
    return letters[index]
}

function fifthsFromTpc(tpc) {
    if (typeof tpc !== "number") return 0
    return Math.floor((tpc - 13) / 7)
}

function pitchClassName(pitchClass) {
    var index = ((pitchClass % 12) + 12) % 12
    return PITCH_CLASS_NAMES[index]
}

function letterFromPitch(pitch) {
    // fallback when tpc missing: use pitch class to approximate letter
    // C=0, C#/Db=1, D=2, etc. Map to nearest natural letter.
    var pc = ((pitch % 12) + 12) % 12
    var map = {
        0: "C",
        1: "C",
        2: "D",
        3: "D",
        4: "E",
        5: "F",
        6: "F",
        7: "G",
        8: "G",
        9: "A",
        10: "A",
        11: "B"
    }
    return map[pc] || "C"
}

// ---------------------------------------------------------------------------
// Accidental helpers
// ---------------------------------------------------------------------------

function normalizeAccidental(value, enumLookup) {
    if (typeof value === "number") return value
    if (typeof value === "string") {
        if (enumLookup && enumLookup[value] !== undefined) return enumLookup[value]
        var parsed = parseInt(value, 10)
        return isNaN(parsed) ? ACC_NONE : parsed
    }
    if (value === undefined || value === null) return ACC_NONE
    var asNumber = Number(value)
    return isNaN(asNumber) ? ACC_NONE : asNumber
}

function intendedAccidental(currentAccidentalType, cents, addAccidentals) {
    if (!addAccidentals) return currentAccidentalType
    if (REPLACEABLE_ACCIDENTALS.indexOf(currentAccidentalType) < 0) return currentAccidentalType
    if (cents > 25) return ACC_SORI
    if (cents < -25) return ACC_KORON
    if (currentAccidentalType === ACC_SORI || currentAccidentalType === ACC_KORON) return ACC_NONE
    return currentAccidentalType
}

function accidentalName(accidentalType) {
    if (accidentalType === ACC_SORI) return "sori"
    if (accidentalType === ACC_KORON) return "koron"
    if (accidentalType === ACC_FLAT) return "flat"
    if (accidentalType === ACC_SHARP) return "sharp"
    return ""
}

// ---------------------------------------------------------------------------
// Note identity (sign-oriented)
// ---------------------------------------------------------------------------

function noteIdentityFromNote(note, AccidentalEnum) {
    var tpc = note.tpc
    var accRaw = note.accidentalType
    var accType = normalizeAccidental(accRaw, AccidentalEnum)

    var letter = null
    if (typeof tpc === "number") {
        letter = letterFromTpc(tpc)
    }
    if (!letter) {
        // fallback from pitch
        if (typeof note.pitch === "number") letter = letterFromPitch(note.pitch)
        else letter = "C"
    }

    var variant = null
    // if accidentalType is explicit koron/sori/flat/sharp, use it
    if (accType === ACC_KORON) variant = "koron"
    else if (accType === ACC_SORI) variant = "sori"
    else if (accType === ACC_FLAT || accType === ACC_FLAT2) variant = "flat"
    else if (accType === ACC_SHARP || accType === ACC_SHARP2) variant = "sharp"
    else {
        // NONE or NATURAL: infer from tpc fifths (key signature)
        if (typeof tpc === "number") {
            var f = fifthsFromTpc(tpc)
            if (f < 0) variant = "flat"
            else if (f > 0) variant = "sharp"
            else variant = "natural"
        } else {
            variant = "natural"
        }
    }

    var base = baseCentsForVariant(variant)
    return { letter: letter, variant: variant, baseCents: base, accType: accType, tpc: tpc }
}

function makeSignKey(letter, variant, staffIdx, options) {
    var opts = options || {}
    var key = letter + "/" + variant
    if (opts.perStaff) key += "@s" + staffIdx
    return key
}

// Old makeKey kept for backward compatibility: if first arg is number, treat as pitchClass
function makeKey(pitchClassOrLetter, accidentalOrVariant, staffIdx, options) {
    // new style: first arg is letter string like "A"
    if (typeof pitchClassOrLetter === "string" && NOTE_LETTERS.indexOf(pitchClassOrLetter) >= 0) {
        var variant = accidentalOrVariant
        if (typeof variant !== "string") variant = "natural"
        return makeSignKey(pitchClassOrLetter, variant, staffIdx, options)
    }
    // old style: pitchClass number
    var opts = options || {}
    var key = String(pitchClassOrLetter)
    if (opts.withAccidental) key += "/" + accidentalOrVariant
    if (opts.perStaff) key += "@s" + staffIdx
    return key
}

function keyParts(key) {
    if (typeof key !== "string") return null
    var staffIdx = -1
    var at = key.lastIndexOf("@s")
    var base = key
    if (at >= 0) {
        var suffix = key.substring(at + 2)
        if (!/^\d+$/.test(suffix)) return null
        staffIdx = parseInt(suffix, 10)
        base = key.substring(0, at)
    }
    var parts = base.split("/")
    if (parts.length < 1 || parts.length > 2) return null
    var first = parts[0]
    // new format: letter
    if (NOTE_LETTERS.indexOf(first) >= 0) {
        var variant = parts.length === 2 ? parts[1] : "natural"
        return { letter: first, variant: variant, pitchClass: null, accidentalType: null, staffIdx: staffIdx, isSignKey: true }
    }
    // old format: numeric pitchClass
    if (!/^\d+$/.test(first)) return null
    if (parts.length === 2 && !/^-?\d+$/.test(parts[1])) {
        // could be new variant string like "koron" but first is numeric -> invalid old, try interpret as old with string variant? treat as sign key with numeric letter? reject
        // Check if second is variant id
        if (["flat","koron","natural","sori","sharp"].indexOf(parts[1]) >= 0) {
            // actually first should be letter, but it's numeric -> fallback
            return null
        }
        return null
    }
    return {
        pitchClass: parseInt(first, 10),
        accidentalType: parts.length === 2 ? parseInt(parts[1], 10) : null,
        staffIdx: staffIdx,
        letter: null,
        variant: null,
        isSignKey: false
    }
}

function describeKey(key) {
    var parts = keyParts(key)
    if (!parts) return String(key)
    if (parts.isSignKey) {
        var txt = parts.letter + " " + labelFaForVariant(parts.variant) + " (" + parts.variant + ")"
        if (parts.staffIdx >= 0) txt += " (staff " + (parts.staffIdx + 1) + ")"
        return txt
    }
    var text = pitchClassName(parts.pitchClass)
    var acc = accidentalName(parts.accidentalType)
    if (acc !== "") text += " " + acc
    if (parts.staffIdx >= 0) text += " (staff " + (parts.staffIdx + 1) + ")"
    return text
}

// ---------------------------------------------------------------------------
// Cents formatting
// ---------------------------------------------------------------------------

function roundCents(cents, step) {
    if (!step || step <= 0) return Math.round(cents * 10) / 10
    return Math.round(cents / step) * step
}

function formatCents(cents) {
    var rounded = Math.round(cents * 10) / 10
    var text = (rounded > 0 ? "+" : "") + rounded
    return text + " " + CENT_SIGN
}

function formatCentsCompact(cents) {
    var rounded = Math.round(cents * 10) / 10
    return (rounded > 0 ? "+" : "") + rounded
}

function formatCentsRelative(cents, letter) {
    // e.g. "+30¢ نسبت به لا طبیعی"
    var fa = NOTE_LETTER_PERSIAN[letter] || letter
    return formatCents(cents) + " نسبت به " + fa + " بکار"
}

// ---------------------------------------------------------------------------
// Tuning Table (global defaults, relative to natural)
// ---------------------------------------------------------------------------

function defaultTuningTable() {
    var table = {}
    for (var i = 0; i < NOTE_LETTERS.length; ++i) {
        var l = NOTE_LETTERS[i]
        table[l] = {}
        for (var j = 0; j < ACC_VARIANT_DEFS.length; ++j) {
            var v = ACC_VARIANT_DEFS[j]
            table[l][v.id] = v.baseCents
        }
    }
    return table
}

function parseTuningTable(text) {
    if (!text || typeof text !== "string") return defaultTuningTable()
    var parsed = null
    try { parsed = JSON.parse(text) } catch (e) { return defaultTuningTable() }
    if (!parsed || typeof parsed !== "object") return defaultTuningTable()
    var table = defaultTuningTable()
    for (var l in parsed) {
        if (NOTE_LETTERS.indexOf(l) < 0) continue
        if (typeof parsed[l] !== "object" || parsed[l] === null) continue
        for (var v in parsed[l]) {
            if (!variantDefById(v)) continue
            var val = parsed[l][v]
            if (typeof val !== "number") continue
            table[l][v] = Math.round(val * 10) / 10
        }
    }
    return table
}

function serializeTuningTable(table) {
    return JSON.stringify(table)
}

function getTuning(table, letter, variant) {
    if (!table) return baseCentsForVariant(variant)
    if (!table[letter]) return baseCentsForVariant(variant)
    if (typeof table[letter][variant] !== "number") return baseCentsForVariant(variant)
    return table[letter][variant]
}

function setTuning(table, letter, variant, cents) {
    if (!table[letter]) table[letter] = {}
    table[letter][variant] = Math.round(cents * 10) / 10
}

// Required MuseScore note.tuning = target - base
function requiredTuning(targetCents, variant) {
    return targetCents - baseCentsForVariant(variant)
}

// ---------------------------------------------------------------------------
// Memory store (timeline of target cents relative to natural)
// ---------------------------------------------------------------------------

function newStore() {
    return { version: MEMORY_VERSION, order: [], scores: {} }
}

function parseStore(text) {
    if (!text || typeof text !== "string") return newStore()
    var parsed = null
    try { parsed = JSON.parse(text) } catch (e) { return newStore() }
    if (!parsed || typeof parsed !== "object" || typeof parsed.scores !== "object" || parsed.scores === null) return newStore()
    var store = newStore()
    store.scores = {}
    for (var scoreId in parsed.scores) {
        var src = parsed.scores[scoreId]
        if (!src || typeof src.keys !== "object" || src.keys === null) continue
        var keys = {}
        for (var key in src.keys) {
            var list = []
            var raw = src.keys[key]
            for (var i = 0; raw && i < raw.length; ++i) {
                var entry = raw[i]
                if (!entry || typeof entry.t !== "number" || typeof entry.c !== "number") continue
                list.push({ t: entry.t, c: entry.c })
            }
            if (list.length > 0) keys[key] = sortChanges(list)
        }
        store.scores[scoreId] = { keys: keys }
    }
    store.order = []
    if (parsed.order && parsed.order.length) {
        for (var o = 0; o < parsed.order.length; ++o) {
            if (store.scores[parsed.order[o]]) store.order.push(parsed.order[o])
        }
    }
    for (var sid in store.scores) {
        if (store.order.indexOf(sid) < 0) store.order.push(sid)
    }
    return store
}

function serializeStore(store) {
    return JSON.stringify(store)
}

function sortChanges(list) {
    list.sort(function(a, b) { return a.t - b.t })
    return list
}

function hasScore(store, scoreId) {
    return !!store.scores[scoreId]
}

function scoreEntry(store, scoreId, create) {
    var entry = store.scores[scoreId]
    if (entry) {
        touch(store, scoreId)
        return entry
    }
    if (!create) return null
    entry = { keys: {} }
    store.scores[scoreId] = entry
    touch(store, scoreId)
    prune(store, MAX_STORED_SCORES)
    return entry
}

function touch(store, scoreId) {
    var idx = store.order.indexOf(scoreId)
    if (idx >= 0) store.order.splice(idx, 1)
    store.order.push(scoreId)
}

function prune(store, maxScores) {
    while (store.order.length > maxScores) {
        var oldest = store.order.shift()
        delete store.scores[oldest]
    }
}

function removeScore(store, scoreId) {
    var idx = store.order.indexOf(scoreId)
    if (idx >= 0) store.order.splice(idx, 1)
    delete store.scores[scoreId]
}

function keysOf(store, scoreId) {
    var entry = store.scores[scoreId]
    if (!entry) return []
    var result = []
    for (var key in entry.keys) result.push(key)
    return result
}

function changesFor(store, scoreId, key) {
    var entry = store.scores[scoreId]
    if (!entry || !entry.keys[key]) return []
    return entry.keys[key]
}

function countChanges(store, scoreId) {
    var entry = store.scores[scoreId]
    if (!entry) return 0
    var total = 0
    for (var key in entry.keys) total += entry.keys[key].length
    return total
}

function setChange(store, scoreId, key, tick, cents) {
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
    if (!replaced) list.push({ t: tick, c: cents })
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

function clearChangesFrom(store, scoreId, key, tick) {
    var entry = store.scores[scoreId]
    if (!entry || !entry.keys[key]) return { from: tick, to: null }
    var kept = []
    var to = null
    var list = entry.keys[key]
    for (var i = 0; i < list.length; ++i) {
        if (list[i].t < tick) kept.push(list[i])
        else if (to === null) to = list[i].t
    }
    if (kept.length === 0) delete entry.keys[key]
    else entry.keys[key] = kept
    return { from: tick, to: to }
}

function resolveCents(store, scoreId, key, tick) {
    var entry = store.scores[scoreId]
    if (!entry || !entry.keys[key]) return null
    var list = entry.keys[key]
    var cents = null
    for (var i = 0; i < list.length; ++i) {
        if (list[i].t <= tick) cents = list[i].c
        else break
    }
    return cents
}

function indicesToTune(notesMeta, key, range) {
    var result = []
    if (!range) return result
    for (var i = 0; i < notesMeta.length; ++i) {
        var meta = notesMeta[i]
        if (!meta || meta.key !== key) continue
        if (meta.tick < range.from) continue
        if (range.to !== null && range.to !== undefined && meta.tick >= range.to) continue
        result.push(i)
    }
    return result
}

function resolveAll(notesMeta, store, scoreId) {
    var result = []
    for (var i = 0; i < notesMeta.length; ++i) {
        var meta = notesMeta[i]
        result.push(meta ? resolveCents(store, scoreId, meta.key, meta.tick) : null)
    }
    return result
}

// ---------------------------------------------------------------------------
// Score markers
// ---------------------------------------------------------------------------

function markerText(cents) {
    return MARKER_GLYPH + " " + formatCentsCompact(cents)
}

function parseMarkerText(text) {
    if (typeof text !== "string") return null
    var match = text.match(new RegExp("^" + MARKER_GLYPH + "\\s*([+-]?\\d+(?:\\.\\d+)?)\\s*" + CENT_SIGN + "?$"))
    if (!match) return null
    return { cents: parseFloat(match[1]) }
}

function isMarkerText(text) {
    return parseMarkerText(text) !== null
}

// ---------------------------------------------------------------------------
// Dastgah presets (kept for backward compatibility, not used in new UI)
// ---------------------------------------------------------------------------

function offsetsForPreset(preset) {
    var offsets = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    if (!preset) return offsets
    var degreeToPc = [0, 2, 4, 5, 7, 9, 11]
    var koron = preset.koron || []
    var sori = preset.sori || []
    for (var i = 0; i < koron.length; ++i) {
        var downIdx = koron[i] - 1
        if (downIdx >= 0 && downIdx < 7) offsets[degreeToPc[downIdx]] = -50
    }
    for (var j = 0; j < sori.length; ++j) {
        var upIdx = sori[j] - 1
        if (upIdx >= 0 && upIdx < 7) offsets[degreeToPc[upIdx]] = 50
    }
    return offsets
}

function presetNames(presets) {
    var names = []
    for (var i = 0; i < presets.length; ++i) names.push(presets[i].name)
    return names
}

function indexOfPreset(presets, name) {
    for (var i = 0; i < presets.length; ++i) if (presets[i].name === name) return i
    return -1
}
