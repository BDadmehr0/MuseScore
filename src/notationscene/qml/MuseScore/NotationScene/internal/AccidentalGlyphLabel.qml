/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2026 MuseScore Limited and others
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import QtQuick

import Muse.Ui
import Muse.UiComponents

//! NOTE Draws a SMuFL accidental glyph for note input bar actions that have
//! no counterpart in the MuseScore icon font (the Persian quarter-tone
//! accidentals koron and sori). The glyph is taken from Bravura, which is
//! always bundled with the app (the default UI musical font, Leland, does
//! not contain these code points).
Item {
    id: root

    //! The action code of the item this label represents ("koron" / "sori")
    property string actionCode: ""

    //! Pixel size of the regular icon this label stands in for
    property real iconPixelSize: ui.theme.iconsFont.pixelSize

    property alias color: label.color

    readonly property bool isEmpty: prv.glyph === ""

    implicitWidth: prv.pixelSize
    implicitHeight: prv.pixelSize

    QtObject {
        id: prv

        // SMuFL glyphs are drawn on a staff-relative scale, so they need to be
        // noticeably larger than icon-font glyphs to look the same size
        readonly property int pixelSize: Math.round(root.iconPixelSize * 1.75)

        // SMuFL: U+E460 accidentalKoron, U+E461 accidentalSori
        readonly property string glyph: {
            switch (root.actionCode) {
            case "koron": return "\uE460"
            case "sori": return "\uE461"
            }

            return ""
        }

        // Vertical centre of the glyph's ink relative to the baseline, in em
        // (positive = below the baseline). Accidentals are designed to sit on
        // a staff line, so unlike icon-font glyphs they are not centred on the
        // line box; koron in particular hangs below the baseline (Bravura
        // bounding boxes: koron -0.472..0.157, sori -0.318..0.328).
        readonly property real inkCenterY: {
            switch (root.actionCode) {
            case "koron": return 0.158
            case "sori": return -0.005
            }

            return 0
        }
    }

    FontLoader {
        id: fontLoader

        source: "qrc:/fonts/bravura/Bravura.otf"
    }

    StyledTextLabel {
        id: label

        // Bravura has symmetric ascent/descent, so the baseline of the
        // (vertically centred) line box lies on the vertical centre of this
        // item; shift the text so that the ink itself ends up centred
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -prv.inkCenterY * prv.pixelSize

        text: prv.glyph

        font.family: fontLoader.status === FontLoader.Ready ? fontLoader.name : "Bravura"
        font.pixelSize: prv.pixelSize
    }
}
