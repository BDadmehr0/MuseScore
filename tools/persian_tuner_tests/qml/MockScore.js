/*
 * Mock of the MuseScore v1 plugin API objects, used by the Persian Tuner test
 * harness (tools/persian_tuner_tests). Only the surface that the plugin
 * actually touches is implemented.
 *
 * Nothing in here ships with MuseScore; it lives outside share/ on purpose.
 */

.pragma library

var nextId = 1

function createFraction(ticks)
{
    return {
        ticks: ticks,
        numerator: ticks,
        denominator: 480,
        lessThan: function(other) { return this.ticks < other.ticks },
        greaterThan: function(other) { return this.ticks > other.ticks }
    }
}

function createSelection()
{
    return {
        elements: [],
        isRange: false,
        startStaff: 0,
        endStaff: 0,
        selectLog: [],
        select: function(el) {
            this.elements = [el]
            this.selectLog.push(el.uid)
            return true
        },
        clear: function() { this.elements = [] }
    }
}

function createScore(enums, options)
{
    var opts = options || {}
    return {
        scoreName: opts.scoreName || "TestScore.mscz",
        title: opts.title || "Test score",
        composer: "Tester",
        ntracks: opts.tracks || 1,
        nstaves: opts.tracks || 1,
        nmeasures: 0,
        firstMeasure: null,
        lastMeasure: null,
        selection: createSelection(),
        cmdLog: [],
        openCommands: 0,
        shownElement: null,
        allNotes: [],
        startCmd: function(name) {
            this.cmdLog.push("start:" + name)
            this.openCommands++
        },
        endCmd: function() {
            this.cmdLog.push("end")
            this.openCommands--
        },
        showElementInScore: function(el) { this.shownElement = el },
        doLayout: function() {},
        style: { value: function() { return 1 } }
    }
}

function createMeasure(enums, number, tick)
{
    return {
        uid: nextId++,
        type: enums.MEASURE,
        measureNumber: number,
        tick: createFraction(tick),
        firstSegment: null,
        nextMeasure: null,
        is: function(other) { return !!other && other.uid === this.uid }
    }
}

function createSegment(enums, tick, measure)
{
    return {
        uid: nextId++,
        type: enums.SEGMENT,
        tick: tick,
        fraction: createFraction(tick),
        measure: measure,
        parent: measure,
        annotations: [],
        tracks: {},
        nextInMeasure: null,
        elementAt: function(track) {
            return this.tracks[track] === undefined ? null : this.tracks[track]
        },
        is: function(other) { return !!other && other.uid === this.uid }
    }
}

function createChord(enums, tick, segment)
{
    return {
        uid: nextId++,
        type: enums.CHORD,
        notes: [],
        parent: segment,
        measure: segment ? segment.measure : null,
        fraction: createFraction(tick),
        is: function(other) { return !!other && other.uid === this.uid }
    }
}

function createNote(enums, spec, tick, chord)
{
    return {
        uid: nextId++,
        type: enums.NOTE,
        pitch: spec.pitch,
        tpc: spec.tpc,
        accidentalType: spec.accidentalType === undefined ? enums.Accidental_NONE : spec.accidentalType,
        tuning: spec.tuning || 0,
        staffIdx: spec.staffIdx || 0,
        track: spec.track || 0,
        parent: chord,
        elements: [],
        fraction: createFraction(tick),
        add: function(el) {
            el.parent = this
            this.elements.push(el)
            return true
        },
        remove: function(el) {
            var index = this.elements.indexOf(el)
            if (index < 0) {
                return false
            }
            this.elements.splice(index, 1)
            return true
        },
        is: function(other) { return !!other && other.uid === this.uid }
    }
}

/// Builds a score from a flat list of note specs:
///   { pitch, tpc, accidentalType, staffIdx, track, tick, tuning }
/// Notes sharing a tick end up in different tracks of the same segment.
function buildScore(enums, noteSpecs, options)
{
    var opts = options || {}
    var ticksPerMeasure = opts.ticksPerMeasure || 1920
    var score = createScore(enums, opts)

    var tickList = []
    var seenTicks = {}
    for (var i = 0; i < noteSpecs.length; ++i) {
        var tick = noteSpecs[i].tick
        if (seenTicks[tick] === undefined) {
            seenTicks[tick] = true
            tickList.push(tick)
        }
    }
    tickList.sort(function(a, b) { return a - b })

    var measureByIndex = {}
    var segmentByTick = {}
    var prevSegment = null
    var prevSegmentMeasure = null
    var prevMeasure = null

    for (var t = 0; t < tickList.length; ++t) {
        var segTick = tickList[t]
        var measureIndex = Math.floor(segTick / ticksPerMeasure)
        var measure = measureByIndex[measureIndex]
        if (!measure) {
            measure = createMeasure(enums, measureIndex + 1, measureIndex * ticksPerMeasure)
            measureByIndex[measureIndex] = measure
            if (prevMeasure) {
                prevMeasure.nextMeasure = measure
            } else {
                score.firstMeasure = measure
            }
            prevMeasure = measure
        }
        var segment = createSegment(enums, segTick, measure)
        segmentByTick[segTick] = segment
        if (!measure.firstSegment) {
            measure.firstSegment = segment
        }
        if (prevSegment && prevSegmentMeasure === measure) {
            prevSegment.nextInMeasure = segment
        }
        prevSegment = segment
        prevSegmentMeasure = measure
    }

    for (var n = 0; n < noteSpecs.length; ++n) {
        var spec = noteSpecs[n]
        var segment2 = segmentByTick[spec.tick]
        var chord = createChord(enums, spec.tick, segment2)
        var note = createNote(enums, spec, spec.tick, chord)
        chord.notes.push(note)
        var track = spec.track || 0
        segment2.tracks[track] = chord
        score.allNotes.push(note)
    }

    score.lastMeasure = prevMeasure
    score.nmeasures = Object.keys(measureByIndex).length
    return score
}

/// Tunings of every note of the score, keyed by tick (helper for assertions).
function tuningsByTick(score)
{
    var result = {}
    for (var i = 0; i < score.allNotes.length; ++i) {
        var note = score.allNotes[i]
        var key = note.track + "@" + note.fraction.ticks
        result[key] = note.tuning
    }
    return result
}
