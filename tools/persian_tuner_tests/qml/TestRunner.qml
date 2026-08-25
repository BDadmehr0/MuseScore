/*
 * Test runner for the Persian Tuner plugin.
 *
 * It loads the *real* share/plugins/persian_tuner/persian_tuner.qml with stub
 * modules for MuseScore/Muse.Ui/Muse.UiComponents and a mock of the plugin
 * API, then drives the plugin the same way MuseScore would.
 *
 * Run it with tools/persian_tuner_tests/run_tests.sh
 */

import QtQuick

import "MockScore.js" as Mock
import "../../../share/plugins/persian_tuner/tunerlogic.js" as TunerLogic

Item {
    id: runner

    /// Set by run_tests.py to the absolute path of persian_tuner.qml
    property url pluginUrl: typeof persianTunerPluginUrl !== "undefined" ? persianTunerPluginUrl : ""

    property int passed: 0
    property int failed: 0
    property string failureText: ""
    property bool finished: false
    property var plugin: null

    readonly property var enums: ({
        NOTE: Element.NOTE,
        CHORD: Element.CHORD,
        TEXT: Element.TEXT,
        SEGMENT: Element.SEGMENT,
        MEASURE: Element.MEASURE,
        Accidental_NONE: Accidental.NONE
    })

    Component.onCompleted: {
        try {
            runAll()
        } catch (e) {
            fail("unexpected exception: " + e)
        }
        finished = true
        console.log("")
        console.log("RESULT passed=" + passed + " failed=" + failed)
        if (failed > 0) {
            console.log(failureText)
        }
    }

    // ------------------------------------------------------------------
    // Assertion helpers
    // ------------------------------------------------------------------

    function check(name, condition, detail)
    {
        if (condition) {
            passed++
            console.log("  ok   " + name)
        } else {
            fail(name, detail)
        }
    }

    function equal(name, actual, expected)
    {
        if (actual === expected) {
            passed++
            console.log("  ok   " + name)
        } else {
            fail(name, "expected " + JSON.stringify(expected) + ", got " + JSON.stringify(actual))
        }
    }

    function fail(name, detail)
    {
        failed++
        var line = "  FAIL " + name + (detail ? " -> " + detail : "")
        console.log(line)
        failureText += line + "\n"
    }

    // ------------------------------------------------------------------
    // Fixtures
    // ------------------------------------------------------------------

    function createPlugin()
    {
        var component = Qt.createComponent(pluginUrl)
        if (component.status !== Component.Ready) {
            fail("load plugin", component.errorString())
            return null
        }
        var instance = component.createObject(runner)
        if (!instance) {
            fail("instantiate plugin", component.errorString())
            return null
        }
        return instance
    }

    /// Single staff: F C F D F A F C on consecutive quarter notes.
    function noteSpecsA()
    {
        return [
            { pitch: 65, tpc: 13, tick: 0 },
            { pitch: 60, tpc: 14, tick: 480 },
            { pitch: 65, tpc: 13, tick: 960 },
            { pitch: 62, tpc: 16, tick: 1440 },
            { pitch: 65, tpc: 13, tick: 1920 },
            { pitch: 69, tpc: 17, tick: 2400 },
            { pitch: 65, tpc: 13, tick: 2880 },
            { pitch: 60, tpc: 14, tick: 3360 }
        ]
    }

    /// Sets up a fresh plugin + score and returns { plugin, score, notes }.
    function setup(specs, options)
    {
        var score = Mock.buildScore(enums, specs, options)
        var instance = createPlugin()
        if (!instance) {
            return null
        }
        instance.curScore = score
        instance.run()
        return { plugin: instance, score: score, notes: score.allNotes }
    }

    function select(env, notes)
    {
        env.score.selection.elements = notes
    }

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------

    function runAll()
    {
        console.log("Persian Tuner plugin tests")
        console.log("plugin: " + pluginUrl)

        testLogicUnits()
        testAutomaticMemory()
        testAutomaticMemoryOff()
        testAccidentals()
        testMarkerTool()
        testMarkerRemoval()
        testPreset()
        testReapplyAndPersistence()
        testPerStaffMemory()
        testMatchAccidental()
        testMarkerPendingCancel()
        testUndoWrapping()
        testNoSelection()
        testToolbarControls()
    }

    // ------------------------------------------------------------------
    // Finding widgets inside the plugin (the ids are private to it)
    // ------------------------------------------------------------------

    function findChildByProperty(item, prop, value)
    {
        if (!item) {
            return null
        }
        if (item[prop] !== undefined && item[prop] === value) {
            return item
        }
        var children = item.children
        if (!children) {
            return null
        }
        for (var i = 0; i < children.length; ++i) {
            var found = findChildByProperty(children[i], prop, value)
            if (found) {
                return found
            }
        }
        return null
    }

    function testToolbarControls()
    {
        console.log("- toolbar controls")
        var env = setup(noteSpecsA())
        if (!env) {
            return
        }
        var plugin = env.plugin
        var notes = env.notes

        // the automatic memory toggle is a MU.CheckBox, which does not toggle
        // itself - the plugin has to flip the setting on "clicked"
        var autoCheck = findChildByProperty(plugin, "text", "Automatic memory")
        check("automatic memory checkbox exists", autoCheck !== null)
        if (autoCheck) {
            equal("checkbox starts checked", autoCheck.checked, true)
            autoCheck.clicked()
            equal("click switches the memory off", plugin.autoMemory, false)
            equal("checkbox follows the setting", autoCheck.checked, false)

            select(env, [notes[0]])
            plugin.commitCents(30)
            equal("nothing propagated while off", notes[2].tuning, 0)

            autoCheck.clicked()
            equal("click switches the memory on", plugin.autoMemory, true)
            equal("checkbox follows again", autoCheck.checked, true)
            select(env, [notes[0]])
            plugin.commitCents(30)
            equal("propagation is back", notes[2].tuning, 30)
        }

        var markerButton = findChildByProperty(plugin, "text", "⚑  Marker")
        check("marker button exists", markerButton !== null)
        if (markerButton) {
            markerButton.clicked()
            equal("button arms the tool", plugin.markerToolArmed, true)
            markerButton.clicked()
            equal("button disarms the tool", plugin.markerToolArmed, false)
        }

        // the cents field previews while typing and commits when editing ends
        var centsField = findChildByProperty(plugin, "stubType", "IncrementalPropertyControl")
        check("cents field exists", centsField !== null)
        if (centsField) {
            select(env, [notes[1]])
            centsField.edit(25)
            equal("typing previews the selection", notes[1].tuning, 25)
            equal("typing does not propagate", notes[3].tuning, 0)
            centsField.editFinished(25)
            equal("entering the value keeps the preview", notes[1].tuning, 25)

            select(env, [notes[3]])
            centsField.editFinished(-15)
            equal("committed value applied", notes[3].tuning, -15)
        }

        env.plugin.destroy()
    }

    function testLogicUnits()
    {
        console.log("- logic units")
        var Logic = TunerLogic

        equal("tpcName(F)", Logic.tpcName(13), "F")
        equal("tpcName(F sharp)", Logic.tpcName(20), "F\u266F")
        equal("tpcName(B flat)", Logic.tpcName(12), "B\u266D")
        equal("tpcName(C)", Logic.tpcName(14), "C")

        equal("pitchClassName(5)", Logic.pitchClassName(5), "F")
        equal("pitchClassName(9)", Logic.pitchClassName(9), "A")

        equal("makeKey pitch class only", Logic.makeKey(5, Accidental.SORI, 0, {}), "5")
        equal("makeKey with accidental", Logic.makeKey(5, Accidental.SORI, 0, { withAccidental: true }), "5/" + Accidental.SORI)
        equal("makeKey per staff", Logic.makeKey(5, Accidental.SORI, 1, { perStaff: true, withAccidental: true }),
              "5/" + Accidental.SORI + "@s1")
        equal("keyParts staff", Logic.keyParts("5/" + Accidental.SORI + "@s1").staffIdx, 1)
        equal("keyParts pitch class", Logic.keyParts("5@" + "s1").pitchClass, 5)
        equal("describeKey", Logic.describeKey("5/" + Accidental.SORI), "F sori")
        equal("describeKey plain", Logic.describeKey("5"), "F")
        equal("describeKey staff", Logic.describeKey("9@s2"), "A (staff 3)")

        equal("intendedAccidental up", Logic.intendedAccidental(Accidental.NONE, 50, true), Accidental.SORI)
        equal("intendedAccidental down", Logic.intendedAccidental(Accidental.NONE, -50, true), Accidental.KORON)
        equal("intendedAccidental zero clears sori", Logic.intendedAccidental(Accidental.SORI, 0, true), Accidental.NONE)
        equal("intendedAccidental keeps sharp", Logic.intendedAccidental(Accidental.SHARP, 50, true), Accidental.SHARP)
        equal("intendedAccidental disabled", Logic.intendedAccidental(Accidental.NONE, 50, false), Accidental.NONE)

        equal("normalizeAccidental number", Logic.normalizeAccidental(Accidental.SORI, Accidental), Accidental.SORI)
        equal("normalizeAccidental string", Logic.normalizeAccidental("SORI", Accidental), Accidental.SORI)
        equal("normalizeAccidental unknown", Logic.normalizeAccidental(undefined, Accidental), Accidental.NONE)

        var offsets = Logic.offsetsForPreset({ koron: [2], sori: [] })
        equal("preset koron degree 2", offsets[2], -50)
        equal("preset untouched degree", offsets[0], 0)

        equal("markerText", Logic.markerText(50), "\u2691 +50")
        equal("markerText negative", Logic.markerText(-12.5), "\u2691 -12.5")
        equal("parseMarkerText", Logic.parseMarkerText(Logic.markerText(-12.5)).cents, -12.5)
        equal("parseMarkerText rejects other text", Logic.parseMarkerText("Allegro"), null)
        equal("isMarkerText", Logic.isMarkerText("\u2691 +30"), true)

        // memory store
        var store = Logic.newStore()
        var range = Logic.setChange(store, "score", "5", 0, 30)
        equal("setChange range open", range.to, null)
        equal("resolve at 0", Logic.resolveCents(store, "score", "5", 0), 30)
        equal("resolve unknown key", Logic.resolveCents(store, "score", "7", 0), null)
        var range2 = Logic.setChange(store, "score", "5", 1920, 50)
        equal("second change bounds the first", range2.from, 1920)
        equal("resolve before second change", Logic.resolveCents(store, "score", "5", 960), 30)
        equal("resolve after second change", Logic.resolveCents(store, "score", "5", 1920), 50)
        var indices = Logic.indicesToTune([{ key: "5", tick: 0 }, { key: "5", tick: 1920 }, { key: "7", tick: 1920 }],
                                          "5", { from: 0, to: 1920 })
        equal("indicesToTune respects range and key", indices.length, 1)

        var parsed = Logic.parseStore(Logic.serializeStore(store))
        equal("store roundtrip", Logic.resolveCents(parsed, "score", "5", 3000), 50)
        equal("parseStore garbage", Logic.parseStore("not json").version, 1)
        equal("parseStore empty", Logic.countChanges(Logic.parseStore(""), "score"), 0)

        var big = Logic.newStore()
        for (var i = 0; i < 40; ++i) {
            Logic.setChange(big, "score" + i, "5", 0, i)
        }
        equal("store prunes old scores", Object.keys(big.scores).length <= 24, true)
        equal("pruned store keeps the newest", Logic.resolveCents(big, "score39", "5", 0), 39)
    }

    function testAutomaticMemory()
    {
        console.log("- automatic memory")
        var env = setup(noteSpecsA())
        if (!env) {
            return
        }
        var plugin = env.plugin
        var notes = env.notes
        var score = env.score

        equal("auto memory on by default", plugin.autoMemory, true)

        // tune the first F: every later F in the score must follow
        select(env, [notes[0]])
        equal("commitCents returns true", plugin.commitCents(30), true)
        equal("F at 0", notes[0].tuning, 30)
        equal("F at 960 follows", notes[2].tuning, 30)
        equal("F at 1920 follows", notes[4].tuning, 30)
        equal("F at 2880 follows", notes[6].tuning, 30)
        equal("C untouched", notes[1].tuning, 0)
        equal("D untouched", notes[3].tuning, 0)
        equal("one remembered value", plugin.memoryCount(), 1)

        // change it again further down the piece
        select(env, [notes[4]])
        plugin.commitCents(50)
        equal("F at 0 keeps 30", notes[0].tuning, 30)
        equal("F at 960 keeps 30", notes[2].tuning, 30)
        equal("F at 1920 now 50", notes[4].tuning, 50)
        equal("F at 2880 now 50", notes[6].tuning, 50)
        equal("two remembered values", plugin.memoryCount(), 2)

        // and once more in between: only the region up to the next change
        select(env, [notes[2]])
        plugin.commitCents(20)
        equal("F at 0 still 30", notes[0].tuning, 30)
        equal("F at 960 now 20", notes[2].tuning, 20)
        equal("F at 1920 still 50", notes[4].tuning, 50)
        equal("F at 2880 still 50", notes[6].tuning, 50)
        equal("three remembered values", plugin.memoryCount(), 3)

        // the settings blob holds the memory
        var persisted = plugin.settingsJson()
        check("settings hold the memory", persisted.indexOf("\"keys\"") >= 0, persisted)

        // "use remembered" restores the value of a note edited by hand
        notes[6].tuning = 0
        select(env, [notes[6]])
        plugin.applyMemoryToSelection()
        equal("use remembered applies 50", notes[6].tuning, 50)

        env.plugin.destroy()
    }

    function testAutomaticMemoryOff()
    {
        console.log("- automatic memory off")
        var env = setup(noteSpecsA())
        if (!env) {
            return
        }
        var plugin = env.plugin
        var notes = env.notes

        select(env, [notes[0]])
        plugin.commitCents(30)

        plugin.autoMemory = false
        var before = plugin.memoryCount()
        select(env, [notes[6]])
        plugin.commitCents(-10)
        equal("only the selected note changed", notes[6].tuning, -10)
        equal("earlier F untouched", notes[4].tuning, 30)
        equal("memory not extended", plugin.memoryCount(), before)

        env.plugin.destroy()
    }

    function testAccidentals()
    {
        console.log("- koron/sori signs (sign-oriented: target relative to natural)")
        var env = setup(noteSpecsA())
        if (!env) {
            return
        }
        var plugin = env.plugin
        var notes = env.notes

        // new default: addAccidentals false (sign-oriented keeps accidental as is unless user wants)
        // but we test both modes
        plugin.addAccidentals = true
        equal("write signs enabled for test", plugin.addAccidentals, true)
        select(env, [notes[0]])
        plugin.commitCents(50)
        equal("sori sign written", notes[0].accidentalType, Accidental.SORI)
        // effective pitch = base 50 + tuning 0 = 50 relative to natural
        equal("sori effective 50 (tuning 0 + base 50)", notes[0].tuning + 50, 50)
        equal("sori sign written on later F", notes[4].accidentalType, Accidental.SORI)

        select(env, [notes[0]])
        plugin.commitCents(-50)
        equal("koron sign written", notes[0].accidentalType, Accidental.KORON)
        equal("koron effective -50", notes[0].tuning - 50, -50)

        select(env, [notes[0]])
        plugin.commitCents(0)
        equal("sign cleared at 0 cents", notes[0].accidentalType, Accidental.NONE)
        equal("natural at 0", notes[0].tuning, 0)

        plugin.addAccidentals = false
        select(env, [notes[2]])
        plugin.commitCents(50)
        equal("no sign when disabled", notes[2].accidentalType, Accidental.NONE)
        equal("tuning still applied (target 50, base 0 => 50)", notes[2].tuning, 50)

        env.plugin.destroy()
    }

    function testMarkerTool()
    {
        console.log("- marker tool")
        var env = setup(noteSpecsA())
        if (!env) {
            return
        }
        var plugin = env.plugin
        var notes = env.notes

        equal("tool starts disarmed", plugin.markerToolArmed, false)
        plugin.toggleMarkerTool()
        equal("tool armed", plugin.markerToolArmed, true)

        // a click on a rest must not place anything
        select(env, [])
        plugin.scoreStateChanged({ selectionChanged: true })
        equal("no marker without a note", notes[6].elements.length, 0)
        equal("tool stays armed", plugin.markerToolArmed, true)

        // click on a note
        select(env, [notes[6]])
        plugin.scoreStateChanged({ selectionChanged: true })
        equal("marker element added", notes[6].elements.length, 1)
        var marker = notes[6].elements.length > 0 ? notes[6].elements[0] : null
        if (marker) {
            equal("marker is a text element", marker.type, Element.TEXT)
            check("marker text is a marker", TunerLogic.isMarkerText(marker.text), marker.text)
        }
        equal("tool disarmed after the click", plugin.markerToolArmed, false)
        check("marker pending a value", plugin.pendingMarker !== null)
        equal("marker listed", plugin.markerEntries.length, 1)

        // typing the value updates the marker and the tuning
        plugin.commitCents(45)
        check("marker text updated", marker && marker.text === TunerLogic.markerText(45), marker ? marker.text : "no marker")
        check("no marker pending any more", plugin.pendingMarker === null)
        equal("note tuned", notes[6].tuning, 45)
        equal("propagated to the end of the piece", notes[6].tuning, 45)

        env.plugin.destroy()
    }

    function testMarkerRemoval()
    {
        console.log("- marker removal")
        var env = setup(noteSpecsA())
        if (!env) {
            return
        }
        var plugin = env.plugin
        var notes = env.notes

        plugin.toggleMarkerTool()
        select(env, [notes[2]])
        plugin.scoreStateChanged({ selectionChanged: true })
        equal("marker present", plugin.markerEntries.length, 1)

        plugin.removeMarker(0)
        equal("marker gone from the note", notes[2].elements.length, 0)
        equal("marker list empty", plugin.markerEntries.length, 0)

        env.plugin.destroy()
    }

    function testMarkerPendingCancel()
    {
        console.log("- unconfirmed marker")
        var env = setup(noteSpecsA())
        if (!env) {
            return
        }
        var plugin = env.plugin
        var notes = env.notes

        plugin.toggleMarkerTool()
        select(env, [notes[0]])
        plugin.scoreStateChanged({ selectionChanged: true })
        check("marker waits for a value", plugin.pendingMarker !== null)

        // moving the selection away must not leave the marker attached to the
        // next value the user happens to type
        select(env, [notes[1]])
        plugin.scoreStateChanged({ selectionChanged: true })
        check("moving away cancels it", plugin.pendingMarker === null)

        var markerTextBefore = notes[0].elements.length > 0 ? notes[0].elements[0].text : ""
        plugin.commitCents(60)
        var markerTextAfter = notes[0].elements.length > 0 ? notes[0].elements[0].text : ""
        equal("old marker keeps its own value", markerTextAfter, markerTextBefore)

        env.plugin.destroy()
    }

    function testPreset()
    {
        console.log("- dastgah preset (kept for backward compat, now sign-oriented)")
        var env = setup(noteSpecsA())
        if (!env) {
            return
        }
        var plugin = env.plugin
        var notes = env.notes

        plugin.addAccidentals = false
        select(env, [notes[3], notes[5]])      // D and A
        plugin.applyPresetAt(2, false)         // Homayoun: koron on degrees 2 and 6
        // With sign-oriented, target -50, base 0 => tuning -50 when accidentals disabled
        equal("D lowered", notes[3].tuning, -50)
        equal("A lowered", notes[5].tuning, -50)
        equal("F untouched by the preset", notes[0].tuning, 0)

        // Now with accidentals enabled, effective pitch still -50 but tuning 0 + koron sign
        plugin.addAccidentals = true
        select(env, [notes[3], notes[5]])
        plugin.applyPresetAt(2, false)
        equal("koron sign written when enabled", notes[3].accidentalType, Accidental.KORON)
        equal("D effective still -50 (tuning 0 + base -50)", notes[3].tuning - 50, -50)

        env.plugin.destroy()
    }

    function testReapplyAndPersistence()
    {
        console.log("- re-apply and persistence (sign-oriented keys)")
        var env = setup(noteSpecsA())
        if (!env) {
            return
        }
        var plugin = env.plugin
        var notes = env.notes

        select(env, [notes[0]])
        plugin.commitCents(30)
        select(env, [notes[4]])
        plugin.commitCents(50)

        for (var i = 0; i < notes.length; ++i) {
            notes[i].tuning = 0
            // reset accidental for clean re-apply
            notes[i].accidentalType = Accidental.NONE
        }
        plugin.reapplyMemory()
        equal("re-applied 0", notes[0].tuning, 30)
        equal("re-applied 960", notes[2].tuning, 30)
        equal("re-applied 1920", notes[4].tuning, 50)
        equal("re-applied 2880", notes[6].tuning, 50)
        equal("re-applied C untouched", notes[1].tuning, 0)

        var store = TunerLogic.parseStore(plugin.settingsJson())
        // new keys are like "F/natural" - find the key for F
        var keys = TunerLogic.keysOf(store, plugin.scoreId)
        var fKey = null
        for (var k = 0; k < keys.length; ++k) {
            if (keys[k].indexOf("F") === 0) { fKey = keys[k]; break }
        }
        check("found F key in store", fKey !== null, JSON.stringify(keys))
        if (fKey) {
            equal("persisted store resolves for F", TunerLogic.resolveCents(store, plugin.scoreId, fKey, 2000), 50)
        }

        plugin.clearMemory()
        equal("memory cleared", plugin.memoryCount(), 0)

        env.plugin.destroy()
    }

    function testPerStaffMemory()
    {
        console.log("- per staff memory")
        var specs = [
            { pitch: 65, tpc: 13, tick: 0, track: 0, staffIdx: 0 },
            { pitch: 65, tpc: 13, tick: 960, track: 0, staffIdx: 0 },
            { pitch: 65, tpc: 13, tick: 0, track: 1, staffIdx: 1 },
            { pitch: 65, tpc: 13, tick: 960, track: 1, staffIdx: 1 }
        ]
        var env = setup(specs, { tracks: 2 })
        if (!env) {
            return
        }
        var plugin = env.plugin
        var notes = env.notes

        plugin.perStaffMemory = true
        select(env, [notes[0]])
        plugin.commitCents(30)
        equal("staff 1 tuned at 0", notes[0].tuning, 30)
        equal("staff 1 tuned at 960", notes[1].tuning, 30)
        equal("staff 2 untouched at 0", notes[2].tuning, 0)
        equal("staff 2 untouched at 960", notes[3].tuning, 0)

        select(env, [notes[2]])
        plugin.commitCents(-20)
        equal("staff 2 tuned", notes[2].tuning, -20)
        equal("staff 1 unchanged", notes[0].tuning, 30)

        env.plugin.destroy()
    }

    function testMatchAccidental()
    {
        console.log("- match by accidental")
        var specs = [
            { pitch: 65, tpc: 13, tick: 0, accidentalType: Accidental.SORI },
            { pitch: 65, tpc: 13, tick: 960, accidentalType: Accidental.NONE }
        ]
        var env = setup(specs)
        if (!env) {
            return
        }
        var plugin = env.plugin
        var notes = env.notes

        plugin.matchAccidental = true
        select(env, [notes[0]])
        plugin.commitCents(40)
        equal("F with sori tuned", notes[0].tuning, 40)
        equal("plain F left alone", notes[1].tuning, 0)

        env.plugin.destroy()
    }

    function testUndoWrapping()
    {
        console.log("- undo grouping")
        var env = setup(noteSpecsA())
        if (!env) {
            return
        }
        var plugin = env.plugin
        var notes = env.notes
        var score = env.score

        select(env, [notes[0]])
        plugin.commitCents(30)
        plugin.toggleMarkerTool()
        select(env, [notes[2]])
        plugin.scoreStateChanged({ selectionChanged: true })
        plugin.removeMarker(0)
        plugin.reapplyMemory()

        equal("no open undo command left", score.openCommands, 0)
        check("undo commands were used", score.cmdLog.length > 0, JSON.stringify(score.cmdLog))
        var starts = 0
        var ends = 0
        for (var i = 0; i < score.cmdLog.length; ++i) {
            if (score.cmdLog[i].indexOf("start:") === 0) {
                starts++
            } else if (score.cmdLog[i] === "end") {
                ends++
            }
        }
        equal("start/end balanced", starts, ends)

        env.plugin.destroy()
    }

    function testNoSelection()
    {
        console.log("- no selection")
        var env = setup(noteSpecsA())
        if (!env) {
            return
        }
        var plugin = env.plugin
        select(env, [])
        equal("commit without selection fails", plugin.commitCents(10), false)
        plugin.applyMemoryToSelection()
        plugin.reapplyMemory()
        plugin.clearMemory()
        equal("still alive", plugin.markerEntries.length, 0)
        env.plugin.destroy()
    }

}
