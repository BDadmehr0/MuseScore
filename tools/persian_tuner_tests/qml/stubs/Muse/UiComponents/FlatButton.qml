import QtQuick
Item {
    id: button
    property string text: ""
    property bool buttonEnabled: true
    signal clicked()
    implicitWidth: 100
    implicitHeight: 28
    function click() { clicked() }
}
