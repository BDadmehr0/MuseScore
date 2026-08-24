#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
#
# Runs the Persian Tuner plugin (share/plugins/persian_tuner) inside a real QML
# engine, against stub modules for MuseScore / Muse.Ui / Muse.UiComponents and a
# mock of the plugin API. See qml/TestRunner.qml for the test cases.
#
# Usage: run_tests.sh  (bootstraps a venv with PySide6) or
#        python3 run_tests.py

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
QML_DIR = os.path.join(HERE, "qml")
STUBS_DIR = os.path.join(QML_DIR, "stubs")
PLUGIN_QML = os.path.abspath(os.path.join(
    HERE, "..", "..", "share", "plugins", "persian_tuner", "persian_tuner.qml"))

# Enumeration values as exposed by the plugin API (src/engraving/api/v1).
# ElementType and AccidentalType are copied from the engraving sources; the
# remaining ones only need to be self-consistent for the mock.
ELEMENT_TYPE = {
    "INVALID": 0,
    "TEXT": 6,
    "NOTE": 29,
    "REST": 34,
    "STAFF_TEXT": 55,
    "MEASURE": 115,
    "SEGMENT": 125,
    "CHORD": 127,
}
ACCIDENTAL_TYPE = {
    "NONE": 0,
    "FLAT": 1,
    "NATURAL": 2,
    "SHARP": 3,
    "SHARP2": 4,
    "SORI": 89,
    "KORON": 90,
}
PLACEMENT = {"ABOVE": 0, "BELOW": 1, "LEFT": 2, "RIGHT": 3}
ALIGN = {"TOP": 0, "VCENTER": 1, "BOTTOM": 2, "BASELINE": 3,
         "LEFT": 4, "RIGHT": 5, "HCENTER": 6, "JUSTIFY": 7}
TID = {"DEFAULT": 0, "STAFF": 21}


def main() -> int:
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

    from PySide6.QtCore import QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine

    if not os.path.exists(PLUGIN_QML):
        print("plugin not found: %s" % PLUGIN_QML)
        return 2

    app = QGuiApplication(sys.argv[:1])  # noqa: F841
    engine = QQmlApplicationEngine()
    engine.addImportPath(STUBS_DIR)

    context = engine.rootContext()
    context.setContextProperty("Element", ELEMENT_TYPE)
    context.setContextProperty("Accidental", ACCIDENTAL_TYPE)
    context.setContextProperty("Placement", PLACEMENT)
    context.setContextProperty("Align", ALIGN)
    context.setContextProperty("Tid", TID)
    context.setContextProperty("persianTunerPluginUrl", QUrl.fromLocalFile(PLUGIN_QML))

    engine.load(QUrl.fromLocalFile(os.path.join(QML_DIR, "TestRunner.qml")))
    roots = engine.rootObjects()
    if not roots:
        print("FAILED: TestRunner.qml did not load")
        return 2

    runner = roots[0]
    passed = runner.property("passed")
    failed = runner.property("failed")
    print("")
    print("=" * 60)
    print("passed: %s   failed: %s" % (passed, failed))
    if failed:
        print(runner.property("failureText"))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
