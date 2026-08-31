/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * The "symbols" row of the notation toolbar: the Western accidentals
 * (flat, natural, sharp) plus the two Persian quarter-tone accidentals
 * (koron / sori). Clicking a symbol assigns it to the selected note.
 *
 * The glyphs are taken from the MuseJazz music font (the same font the
 * score is typeset with), so the toolbar signs and the score signs are
 * identical.
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Muse.Ui

RowLayout {
    id: root

    property NavigationPanel navigationPanel: null

    readonly property color glyphColor: "#3c4043"
    readonly property color glyphActiveColor: "#1a73e8"
    readonly property color hoverColor: "#143c4043"
    readonly property color pressedColor: "#243c4043"

    spacing: 2
    Layout.alignment: Qt.AlignVCenter

    FontLoader {
        id: musicFont
        // MuseJazz font shipped with the app (see fonts_MuseJazz.qrc)
        source: "qrc:/fonts/musejazz/MuseJazz.otf"
    }

    AccidentalSymbolsBarController {
        id: controller
        Component.onCompleted: controller.init()
    }

    // flat, koron, natural, sori, sharp - ordered by pitch
    Repeater {
        model: [
            { variant: "flat",    glyph: "\uE260", en: "Flat",    fa: "بم" },
            { variant: "koron",   glyph: "\uE4F0", en: "Koron",   fa: "کورُن" },
            { variant: "natural", glyph: "\uE261", en: "Natural", fa: "بکار" },
            { variant: "sori",    glyph: "\uE4F1", en: "Sori",    fa: "سُری" },
            { variant: "sharp",   glyph: "\uE262", en: "Sharp",   fa: "دیز" }
        ]

        delegate: Rectangle {
            required property var modelData

            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 6
            color: ma.pressed ? root.pressedColor : (ma.containsMouse ? root.hoverColor : "transparent")

            Text {
                anchors.centerIn: parent
                text: modelData.glyph
                font.family: musicFont.name
                font.pixelSize: 21
                color: root.glyphColor
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: controller.hasNoteSelection
                onClicked: controller.applyAccidental(modelData.variant)
            }

            ToolTip {
                visible: ma.containsMouse
                text: qsTrc("notation/accidentalsymbols", "%1 (%2)").arg(modelData.en).arg(modelData.fa)
            }

            navigation.panel: root.navigationPanel
            navigation.name: "AccidentalSymbols_" + modelData.variant
        }
    }
}
