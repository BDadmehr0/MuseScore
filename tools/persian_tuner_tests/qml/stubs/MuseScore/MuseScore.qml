// Test stub of the "MuseScore" plugin root type (src/engraving/api/v1/qmlpluginapi.h).
// Only what the Persian Tuner plugin uses is implemented.
import QtQuick

Item {
    id: stub

    property string version: ""
    property string title: ""
    property string description: ""
    property string pluginType: ""
    property string categoryCode: ""
    property string thumbnailName: ""
    property string menuPath: ""
    property string dockArea: ""
    property bool requiresScore: true
    property real mscoreDPI: 96
    property var curScore: null

    signal run()
    signal scoreStateChanged(var state)
    signal closeRequested()

    property var cmdLog: []
    property var removedElements: []
    property int elementIdCounter: 0
    property var logLines: []

    function cmd(name)
    {
        cmdLog.push(name)
    }

    function newElement(type)
    {
        elementIdCounter++
        return {
            uid: 100000 + elementIdCounter,
            type: type,
            text: "",
            subStyle: -1,
            placement: -1,
            align: -1,
            fontSize: 10,
            offset: { x: 0, y: 0 },
            parent: null,
            is: function(other) { return !!other && other.uid === this.uid }
        }
    }

    function removeElement(el)
    {
        removedElements.push(el)
    }

    function log(text)
    {
        logLines.push(text)
    }

    function fraction(numerator, denominator)
    {
        return { numerator: numerator, denominator: denominator, ticks: numerator * 480 / denominator }
    }
}
