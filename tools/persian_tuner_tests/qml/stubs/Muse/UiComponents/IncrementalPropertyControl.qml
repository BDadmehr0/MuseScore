// Mirrors the surface of Muse.UiComponents/IncrementalPropertyControl.qml that
// the plugin uses: currentValue/step/decimals/minValue/maxValue, the
// valueEdited + valueEditingFinished signals and forceActiveFocus().
import QtQuick

Item {
    id: control

    property real currentValue: 0
    property int decimals: 0
    property real step: 1
    property real minValue: 0
    property real maxValue: 100
    property string measureUnitsSymbol: ""
    property string stubType: "IncrementalPropertyControl"

    signal valueEdited(var newValue)
    signal valueEditingFinished(var newValue)

    implicitWidth: 120
    implicitHeight: 30

    function forceActiveFocus()
    {
    }

    function edit(newValue)
    {
        valueEdited(newValue)
    }

    function editFinished(newValue)
    {
        valueEdited(newValue)
        valueEditingFinished(newValue)
    }
}
