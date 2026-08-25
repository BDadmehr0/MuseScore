/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 * Persian Tuner Panel - built-in dock panel like Mixer
 * Dark theme from cent-tuning-panel.html and ribbon from tuner-ribbon-tab.html
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

    // Theme from HTML
    readonly property color bgPage: "#0b0f14"
    readonly property color bgPanel: "#121821"
    readonly property color bgCard: "#0f151c"
    readonly property color bgBtn: "#1a222c"
    readonly property color bgBtnHover: "#232d39"
    readonly property color border: "#232b36"
    readonly property color borderStrong: "#2e3947"
    readonly property color textPrimary: "#e8ecf1"
    readonly property color textSecondary: "#9aa6b4"
    readonly property color textMuted: "#5f6b7a"
    readonly property color accent: "#2ee6b8"
    readonly property color accentDim: "#12352e"

    // State (mirrors plugin logic, simplified for built-in panel)
    property string selectedLetter: "A"
    property string selectedVariant: "sori"
    property int selectedOctave: 4
    property double currentCents: 50
    property double refFreq: 440
    property bool autoMemory: true
    property bool markerArmed: false

    function letterFa(l) {
        var map = { "C":"دو", "D":"رِ", "E":"می", "F":"فا", "G":"سل", "A":"لا", "B":"سی" }
        return map[l] || l
    }
    function variantFa(v) {
        var map = { "flat":"بمل", "koron":"کُرُن", "natural":"بکار", "sori":"سُری", "sharp":"دیز" }
        return map[v] || v
    }
    function baseCents(v) {
        var map = { "flat":-100, "koron":-50, "natural":0, "sori":50, "sharp":100 }
        return map[v] !== undefined ? map[v] : 0
    }
    function calcFreq(letter, octave, variant, cents, ref) {
        var baseSemitone = { "C":0, "D":2, "E":4, "F":5, "G":7, "A":9, "B":11 }[letter]
        if (baseSemitone === undefined) baseSemitone = 0
        var midi = (octave + 1) * 12 + baseSemitone
        if (variant === "flat") midi -= 1
        else if (variant === "sharp") midi += 1
        var naturalMidi = (octave + 1) * 12 + baseSemitone
        var targetMidi = naturalMidi + cents / 100.0
        var diff = targetMidi - 69
        return ref * Math.pow(2, diff / 12.0)
    }

    Rectangle {
        anchors.fill: parent
        color: bgPage

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            // Ribbon
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 86
                color: "#131a22"
                border.color: border
                border.width: 1
                radius: 14

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: "#0f151c"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            spacing: 2
                            Repeater {
                                model: ["خانه", "ورود نت", "چیدمان", "تیونر", "پخش", "نما"]
                                delegate: Rectangle {
                                    Layout.preferredHeight: 36
                                    Layout.preferredWidth: 64
                                    color: "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: modelData === "تیونر" ? root.accent : root.textSecondary
                                        font.pixelSize: 13
                                    }
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 2
                                        color: modelData === "تیونر" ? root.accent : "transparent"
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: border }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 10
                        spacing: 8

                        ColumnLayout {
                            spacing: 6
                            Rectangle {
                                Layout.preferredWidth: 64; Layout.preferredHeight: 52; radius: 9; color: root.accentDim; border.color: "#2ee6b833"; border.width: 1
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: 4
                                    Text { text: "◫"; color: root.accent; font.pixelSize: 20; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: "پنل کلی"; color: root.textPrimary; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                }
                            }
                            Text { text: "تنظیم کوک"; color: root.textMuted; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                        }
                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: root.border }
                        ColumnLayout {
                            spacing: 6
                            Rectangle {
                                Layout.preferredWidth: 64; Layout.preferredHeight: 52; radius: 9; color: root.markerArmed ? root.accentDim : root.bgBtn; border.color: root.markerArmed ? "#2ee6b833" : root.border; border.width: 1
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: 4
                                    Text { text: "⚑"; color: root.markerArmed ? root.accent : root.textSecondary; font.pixelSize: 18; Layout.alignment: Qt.AlignHCenter }
                                    Text { text: "نشانگر"; color: root.markerArmed ? root.accent : root.textSecondary; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                }
                                MouseArea { anchors.fill: parent; onClicked: root.markerArmed = !root.markerArmed }
                            }
                            Text { text: "مرز مدگردی"; color: root.textMuted; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                        }
                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: root.border }
                        ColumnLayout {
                            spacing: 6
                            Rectangle {
                                Layout.preferredWidth: 64; Layout.preferredHeight: 52; radius: 9; color: root.bgBtn; border.color: root.border; border.width: 1
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: 6
                                    Rectangle {
                                        Layout.preferredWidth: 30; Layout.preferredHeight: 16; radius: 8; color: root.accentDim; border.color: "#2ee6b866"; border.width: 1
                                        Rectangle { x: root.autoMemory ? parent.width - 13 : 1; y: 1; width: 12; height: 12; radius: 6; color: root.accent }
                                    }
                                    Text { text: root.autoMemory ? "فعال" : "خاموش"; color: root.autoMemory ? root.accent : root.textSecondary; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                }
                                MouseArea { anchors.fill: parent; onClicked: root.autoMemory = !root.autoMemory }
                            }
                            Text { text: "حافظه خودکار"; color: root.textMuted; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // Main cent tuning panel
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
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "میزان‌کننده بر پایه سنت"; color: root.textMuted; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        radius: 10
                        color: root.bgCard
                        border.color: root.border
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            ColumnLayout {
                                spacing: 4
                                Text { text: "نت مرجع (دیاپازون)"; color: root.textMuted; font.pixelSize: 11 }
                                Text { text: "لا۴ (A4)"; color: root.textPrimary; font.pixelSize: 15 }
                            }
                            Item { Layout.fillWidth: true }
                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    Layout.preferredWidth: 64; Layout.preferredHeight: 28; radius: 6; color: root.bgPanel; border.color: root.borderStrong; border.width: 1
                                    TextInput {
                                        anchors.centerIn: parent
                                        text: String(root.refFreq)
                                        color: root.textPrimary
                                        font.pixelSize: 14
                                        onEditingFinished: {
                                            var v = parseFloat(text)
                                            if (!isNaN(v)) root.refFreq = v
                                        }
                                    }
                                }
                                Text { text: "Hz"; color: root.textMuted; font.pixelSize: 12 }
                            }
                        }
                    }

                    Text { text: "انتخاب اکتاو، نت و علامت"; color: root.textMuted; font.pixelSize: 11 }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        StyledDropdown {
                            Layout.preferredWidth: 110
                            model: ["اکتاو ۳", "اکتاو ۴", "اکتاو ۵", "اکتاو ۶"]
                            currentIndex: 1
                            onActivated: function(index) { root.selectedOctave = 3 + index }
                        }
                        StyledDropdown {
                            Layout.preferredWidth: 90
                            model: ["دو", "رِ", "می", "فا", "سل", "لا", "سی"]
                            currentIndex: 5
                            onActivated: function(index) {
                                var letters = ["C","D","E","F","G","A","B"]
                                root.selectedLetter = letters[index]
                            }
                        }
                        StyledDropdown {
                            Layout.fillWidth: true
                            model: ["بکار", "بمل", "سری", "کرن", "دیز"]
                            currentIndex: 2
                            onActivated: function(index) {
                                var ids = ["natural","flat","sori","koron","sharp"]
                                root.selectedVariant = ids[index]
                            }
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
                            Text { text: "در حال تنظیم:"; color: root.textSecondary; font.pixelSize: 12 }
                            Text { text: root.letterFa(root.selectedLetter) + " " + root.variantFa(root.selectedVariant); color: root.accent; font.pixelSize: 15 }
                            Item { Layout.fillWidth: true }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        radius: 12
                        color: root.bgCard
                        border.color: root.border
                        border.width: 1
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "سنت نسبت به " + root.letterFa(root.selectedLetter) + " طبیعی"; color: root.textSecondary; font.pixelSize: 12 }
                                Item { Layout.fillWidth: true }
                                Text { text: (root.currentCents > 0 ? "+" : "") + root.currentCents; color: root.textPrimary; font.pixelSize: 16 }
                            }
                            StyledSlider {
                                Layout.fillWidth: true
                                from: -100; to: 100; stepSize: 1; value: root.currentCents
                                onMoved: {
                                    root.currentCents = value
                                    hzLabel.text = root.calcFreq(root.selectedLetter, root.selectedOctave, root.selectedVariant, value, root.refFreq).toFixed(1) + " Hz"
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
                                Text { text: root.selectedVariant === "sori" ? "مقدار مرسوم سری معمولاً +50 سنت است" : root.selectedVariant === "koron" ? "مقدار مرسوم کرن معمولاً -50 سنت است" : "بکار مبنا است"; color: root.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: root.border }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "فرکانس محاسبه‌شده"; color: root.textSecondary; font.pixelSize: 12 }
                                Item { Layout.fillWidth: true }
                                Text { id: hzLabel; text: root.calcFreq(root.selectedLetter, root.selectedOctave, root.selectedVariant, root.currentCents, root.refFreq).toFixed(1) + " Hz"; color: root.accent; font.pixelSize: 20 }
                            }
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
                            Text { text: "پخش این نت"; color: root.textPrimary; font.pixelSize: 14 }
                        }
                    }

                    Text { text: "برای استفاده کامل، افزونه Persian Tuner را از Extensions اجرا کنید - این پنل داخلی نمای کلی است"; color: root.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
            }
        }
    }
}
