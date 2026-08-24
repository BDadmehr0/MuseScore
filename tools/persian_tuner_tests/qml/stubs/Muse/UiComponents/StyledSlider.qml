import QtQuick
Item {
    id: slider
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0
    property bool pressed: false
    signal moved()
    implicitWidth: 120
    implicitHeight: 20
    function moveTo(newValue) {
        value = newValue
        moved()
    }
}
