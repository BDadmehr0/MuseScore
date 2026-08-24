// Mirrors Muse.UiComponents/CheckBox.qml: a FocusScope with a "checked"
// property and a "clicked" signal. It does NOT toggle itself, the user of the
// component has to flip "checked" (like share/plugins/tuning/tuning.qml does).
import QtQuick

FocusScope {
    id: checkBox

    property string text: ""
    property bool checked: false
    property string stubType: "CheckBox"

    signal clicked

    implicitWidth: 140
    implicitHeight: 24

    function click()
    {
        clicked()
    }
}
