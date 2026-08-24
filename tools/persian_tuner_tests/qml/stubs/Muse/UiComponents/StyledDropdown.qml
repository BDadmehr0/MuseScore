import QtQuick
Item {
    id: dropdown
    property var model: []
    property int currentIndex: -1
    signal activated(int index, var value)
    implicitWidth: 120
    implicitHeight: 28
    function activate(index) {
        currentIndex = index
        activated(index, model && model[index] !== undefined ? model[index] : null)
    }
}
