/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 * Persian Tuner — built-in dock panel (same docking as Mixer)
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Muse.Ui
import Muse.UiComponents
import MuseScore.NotationScene

Item {
    id: root

    property NavigationSection navigationSection: null
    property int contentNavigationPanelOrderStart: 1

    signal resizeRequested(var newWidth, var newHeight)

    readonly property color bgPage: "#0b0f14"
    readonly property color bgPanel: "#121821"
    readonly property color bgCard: "#0f151c"
    readonly property color bgBtn: "#1a222c"
    readonly property color borderColor: "#232b36"
    readonly property color borderStrong: "#2e3947"
    readonly property color textPrimary: "#e8ecf1"
    readonly property color textSecondary: "#9aa6b4"
    readonly property color textMuted: "#5f6b7a"
    readonly property color accent: "#2ee6b8"
    readonly property color accentDim: "#12352e"

    NavigationPanel {
        id: navPanel
        name: "PersianTunerPanel"
        section: root.navigationSection
        order: root.contentNavigationPanelOrderStart
        enabled: root.enabled && root.visible
        direction: NavigationPanel.Vertical
    }

    PersianTunerPanelModel {
        id: tunerModel
        Component.onCompleted: tunerModel.init()
    }

    // Labels for the "Key signature (Charghah)" dropdown:
    // "Do Koron — La koron, Re koron"
    function keySigPatternLabels() {
        var rows = tunerModel.keySigPatterns || []
        var labels = []
        for (var i = 0; i < rows.length; ++i) {
            labels.push(rows[i].nameEn + " — " + rows[i].description)
        }
        return labels
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgPage

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: "#131a22"
                border.color: root.borderColor
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: qsTrc("notation/persiantuner", "Persian Tuner")
                            color: root.textPrimary
                            font.pixelSize: 14
                        }
                        Text {
                            text: qsTrc("notation/persiantuner", "View ▸ Persian Tuner — dock like Mixer")
                            color: root.textMuted
                            font.pixelSize: 10
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 88
                        Layout.preferredHeight: 44
                        radius: 9
                        color: root.bgBtn
                        border.color: root.borderColor
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Rectangle {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 16
                                Layout.alignment: Qt.AlignHCenter
                                radius: 8
                                color: root.accentDim
                                border.color: "#2ee6b866"
                                border.width: 1
                                Rectangle {
                                    x: tunerModel.autoMemory ? parent.width - 13 : 1
                                    y: 1
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: root.accent
                                }
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: tunerModel.autoMemory
                                      ? qsTrc("notation/persiantuner", "Memory on")
                                      : qsTrc("notation/persiantuner", "Memory off")
                                color: tunerModel.autoMemory ? root.accent : root.textSecondary
                                font.pixelSize: 10
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: tunerModel.autoMemory = !tunerModel.autoMemory
                        }
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: mainCol.implicitHeight + 20
                clip: true

                ColumnLayout {
                    id: mainCol
                    width: parent.width - 20
                    x: 10
                    y: 10
                    spacing: 14

                    Text {
                        text: qsTrc("notation/persiantuner", "Cent tuner")
                        color: root.textMuted
                        font.pixelSize: 13
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        radius: 10
                        color: root.bgCard
                        border.color: root.borderColor
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            ColumnLayout {
                                spacing: 4
                                Text {
                                    text: qsTrc("notation/persiantuner", "Reference (A4)")
                                    color: root.textMuted
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: qsTrc("notation/persiantuner", "La4 (A4)")
                                    color: root.textPrimary
                                    font.pixelSize: 15
                                }
                            }
                            Item { Layout.fillWidth: true }
                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    Layout.preferredWidth: 64
                                    Layout.preferredHeight: 28
                                    radius: 6
                                    color: root.bgPanel
                                    border.color: root.borderStrong
                                    border.width: 1
                                    TextInput {
                                        anchors.centerIn: parent
                                        text: String(tunerModel.refFreq)
                                        color: root.textPrimary
                                        font.pixelSize: 14
                                        onEditingFinished: {
                                            var v = parseFloat(text)
                                            if (!isNaN(v)) {
                                                tunerModel.refFreq = v
                                            }
                                        }
                                    }
                                }
                                Text {
                                    text: "Hz"
                                    color: root.textMuted
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }

                    Text {
                        text: qsTrc("notation/persiantuner", "Octave, note and accidental")
                        color: root.textMuted
                        font.pixelSize: 11
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        StyledDropdown {
                            Layout.preferredWidth: 110
                            model: [
                                qsTrc("notation/persiantuner", "Octave 3"),
                                qsTrc("notation/persiantuner", "Octave 4"),
                                qsTrc("notation/persiantuner", "Octave 5"),
                                qsTrc("notation/persiantuner", "Octave 6")
                            ]
                            currentIndex: tunerModel.octaveIndex
                            onActivated: function(index) { tunerModel.octaveIndex = index }
                        }
                        StyledDropdown {
                            Layout.preferredWidth: 90
                            model: [
                                qsTrc("notation/persiantuner", "Do"),
                                qsTrc("notation/persiantuner", "Re"),
                                qsTrc("notation/persiantuner", "Mi"),
                                qsTrc("notation/persiantuner", "Fa"),
                                qsTrc("notation/persiantuner", "Sol"),
                                qsTrc("notation/persiantuner", "La"),
                                qsTrc("notation/persiantuner", "Si")
                            ]
                            currentIndex: tunerModel.letterIndex
                            onActivated: function(index) { tunerModel.letterIndex = index }
                        }
                        StyledDropdown {
                            Layout.fillWidth: true
                            model: [
                                qsTrc("notation/persiantuner", "Natural"),
                                qsTrc("notation/persiantuner", "Flat"),
                                qsTrc("notation/persiantuner", "Sori"),
                                qsTrc("notation/persiantuner", "Koron"),
                                qsTrc("notation/persiantuner", "Sharp")
                            ]
                            currentIndex: tunerModel.variantIndex
                            onActivated: function(index) { tunerModel.variantIndex = index }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 8
                        color: root.accentDim
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4; color: root.accent }
                            Text {
                                text: qsTrc("notation/persiantuner", "Editing:")
                                color: root.textSecondary
                                font.pixelSize: 12
                            }
                            Text {
                                text: tunerModel.currentLabel
                                color: root.accent
                                font.pixelSize: 15
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: tunerModel.selectionSummary
                                color: root.textSecondary
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.maximumWidth: 220
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        radius: 12
                        color: root.bgCard
                        border.color: root.borderColor
                        border.width: 1
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: tunerModel.refNoteLabel
                                    color: root.textSecondary
                                    font.pixelSize: 12
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: tunerModel.centsLabel
                                    color: root.textPrimary
                                    font.pixelSize: 16
                                }
                            }
                            StyledSlider {
                                id: centsSlider
                                Layout.fillWidth: true
                                from: -100
                                to: 100
                                stepSize: 1
                                value: tunerModel.currentCents
                                onMoved: tunerModel.currentCents = value
                                onPressedChanged: {
                                    if (!pressed) {
                                        tunerModel.applyCents(value)
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "-100"; color: root.textMuted; font.pixelSize: 11 }
                                Item { Layout.fillWidth: true }
                                Text { text: "0"; color: root.textMuted; font.pixelSize: 11 }
                                Item { Layout.fillWidth: true }
                                Text { text: "+100"; color: root.textMuted; font.pixelSize: 11 }
                            }
                            RowLayout {
                                spacing: 6
                                Text { text: "ⓘ"; color: root.textMuted; font.pixelSize: 11 }
                                Text {
                                    text: tunerModel.hintText
                                    color: root.textMuted
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: root.borderColor }
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: qsTrc("notation/persiantuner", "Calculated frequency")
                                    color: root.textSecondary
                                    font.pixelSize: 12
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: tunerModel.computedFreq.toFixed(1) + " Hz"
                                    color: root.accent
                                    font.pixelSize: 20
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 8
                            color: root.accentDim
                            border.color: "#2ee6b833"
                            border.width: 1
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: qsTrc("notation/persiantuner", "Apply tuning")
                                    color: root.accent
                                    font.pixelSize: 14
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: tunerModel.applyCents(tunerModel.currentCents)
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 8
                            color: root.bgCard
                            border.color: root.borderStrong
                            border.width: 1
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "▶"; color: root.textPrimary; font.pixelSize: 14 }
                                Text {
                                    text: qsTrc("notation/persiantuner", "Play")
                                    color: root.textPrimary
                                    font.pixelSize: 14
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: tunerModel.playCurrent()
                            }
                        }
                    }

                    Text {
                        text: qsTrc("notation/persiantuner", "Key signature (Charghah)")
                        color: root.textMuted
                        font.pixelSize: 13
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 118
                        radius: 12
                        color: root.bgCard
                        border.color: root.borderColor
                        border.width: 1
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                StyledDropdown {
                                    Layout.fillWidth: true
                                    model: [
                                        qsTrc("notation/persiantuner", "None (no key)"),
                                    ] + keySigPatternLabels()
                                    currentIndex: tunerModel.keySigPatternIndex + 1
                                    onActivated: function(index) { tunerModel.setKeySigPatternIndex(index - 1) }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: tunerModel.keySigPatternIndex >= 0
                                text: tunerModel.keySigPatternDescription
                                color: root.textSecondary
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    radius: 8
                                    color: root.accentDim
                                    border.color: "#2ee6b833"
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTrc("notation/persiantuner", "Apply key")
                                        color: root.accent
                                        font.pixelSize: 12
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: tunerModel.applyKeySigPattern() }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    radius: 8
                                    color: root.bgPanel
                                    border.color: root.borderStrong
                                    border.width: 1
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text { text: "▶"; color: root.textPrimary; font.pixelSize: 11 }
                                        Text {
                                            text: qsTrc("notation/persiantuner", "Play")
                                            color: root.textPrimary
                                            font.pixelSize: 12
                                        }
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: tunerModel.playKeySigPattern() }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    radius: 8
                                    color: root.bgPanel
                                    border.color: root.borderStrong
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTrc("notation/persiantuner", "Clear")
                                        color: root.textSecondary
                                        font.pixelSize: 12
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: tunerModel.clearKeySigPattern() }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 8
                            color: root.bgBtn
                            border.color: root.borderColor
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: qsTrc("notation/persiantuner", "Re-apply memory")
                                color: root.textPrimary
                                font.pixelSize: 12
                            }
                            MouseArea { anchors.fill: parent; onClicked: tunerModel.reapplyMemory() }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 8
                            color: root.bgBtn
                            border.color: root.borderColor
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: qsTrc("notation/persiantuner", "Clear memory")
                                color: root.textPrimary
                                font.pixelSize: 12
                            }
                            MouseArea { anchors.fill: parent; onClicked: tunerModel.clearMemory() }
                        }
                    }

                    Text {
                        text: qsTrc("notation/persiantuner", "All accidentals of %1").arg(tunerModel.letterFa(tunerModel.selectedLetter))
                        color: root.textMuted
                        font.pixelSize: 11
                    }

                    Repeater {
                        model: tunerModel.variantRows
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: 8
                            color: root.bgCard
                            border.color: root.borderColor
                            border.width: 1
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8
                                Text {
                                    text: modelData.label
                                    color: root.textPrimary
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 48
                                }
                                Text {
                                    text: Number(modelData.cents).toFixed(0) + "¢"
                                    color: root.textSecondary
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 44
                                }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    from: -100
                                    to: 100
                                    stepSize: 1
                                    value: modelData.cents
                                    onPressedChanged: {
                                        if (!pressed) {
                                            tunerModel.setTableCents(tunerModel.selectedLetter, modelData.id, value)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: tunerModel.selectedNotesInfo
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 6
                            color: root.bgCard
                            border.color: root.borderColor
                            border.width: 1
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Text {
                                    text: modelData.label
                                    color: root.textPrimary
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 90
                                }
                                Text {
                                    text: Number(modelData.cents).toFixed(1) + qsTrc("notation/persiantuner", "¢ relative to natural")
                                    color: root.textSecondary
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: tunerModel.statusMessage
                        color: root.textSecondary
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
