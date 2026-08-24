// Test stub of the persistent Settings element used by MuseScore plugins.
// Values are kept in memory so tests can inspect what the plugin persisted.
import QtQuick

QtObject {
    id: settings

    property string category: ""
    property var persisted: ({})

    function value(key, fallback)
    {
        return persisted[key] === undefined ? fallback : persisted[key]
    }

    function setValue(key, val)
    {
        persisted[key] = val
    }
}
