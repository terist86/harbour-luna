import QtQuick 2.0
import Sailfish.Silica 1.0
import "../scripts/Sex.js" as Sex

Column {
    id: root
    property var model
    property alias isSolo: soloRow.isSolo
    property alias timeOfDay: timeOfDayComboBox.currentIndex

    property bool _contraceptionUsed: false

    width: parent.width
    spacing: Theme.paddingMedium

    function _contraceptives() {
        if (!root.model) return []
        try { return JSON.parse(root.model.contraceptives || "[]") }
        catch (e) { return [] }
    }

    function _toggleContraceptive(idx) {
        if (!root.model) return
        var arr = _contraceptives()
        var pos = arr.indexOf(idx)
        if (pos >= 0) arr.splice(pos, 1)
        else arr.push(idx)
        arr.sort()
        root.model.contraceptives = JSON.stringify(arr)
    }

    Row {
        width: parent.width - 2 * Theme.horizontalPageMargin
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.paddingSmall

        ComboBox {
            id: timeOfDayComboBox
            label: qsTr("Time of day")
            currentIndex: root.model.time_of_day
            menu: ContextMenu {
                Repeater {
                    model: Sex.timeOfDayLabels.length
                    delegate: MenuItem {
                        text: qsTr(Sex.timeOfDayLabels[index])
                        onClicked: {
                            if (root.model) {
                                root.model.time_of_day = index
                            }
                        }
                    }
                }
            }
        }
    }

    SectionHeader {
        text: qsTr("Who did you have sex with today?")
    }

    Row {
        id: soloRow
        width: parent.width - 2 * Theme.horizontalPageMargin
        anchors.horizontalCenter: parent.horizontalCenter
        height: Theme.itemSizeSmall
        spacing: Theme.paddingMedium

        property bool isSolo: model ? !!model.solo : false

        BackgroundItem {
            width: parent.width / 2
            height: parent.height

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - Theme.paddingSmall
                height: Theme.paddingMedium
                radius: 4
                color: soloRow.isSolo ? Theme.highlightColor : Theme.primaryColor
            }

            Label {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Solo")
                font.pixelSize: Theme.fontSizeSmall
                color: soloRow.isSolo ? Theme.highlightColor : Theme.primaryColor
            }

            onClicked: {
                if (root.model) {
                    root.model.solo = 1
                    root.model.ejaculation = 0
                    root.model.contraceptives = "[]"
                    _contraceptionUsed = false
                    soloRow.isSolo = true
                }
            }
        }

        BackgroundItem {
            width: parent.width / 2
            height: parent.height

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - Theme.paddingSmall
                height: Theme.paddingMedium
                radius: 4
                color: !soloRow.isSolo ? Theme.highlightColor : Theme.primaryColor
            }

            Label {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Partner")
                font.pixelSize: Theme.fontSizeSmall
                color: !soloRow.isSolo ? Theme.highlightColor : Theme.primaryColor
            }

            onClicked: {
                if (root.model) {
                    root.model.solo = 0
                    soloRow.isSolo = false
                }
            }
        }
    }

    ExpandingSection {
        id: contraceptiveSection
        title: qsTr("Protected sex")
        visible: !soloRow.isSolo && Sex.contraceptiveLabels.length > 0
        content.sourceComponent: Column {
            width: contraceptiveSection.width
            Repeater {
                model: Sex.contraceptiveLabels.length
                delegate: TextSwitch {
                    text: Sex.contraceptiveLabels[index]
                    checked: root.model ? _contraceptives().indexOf(index) >= 0 : false
                    onCheckedChanged: {
                        if (root.model) {
                            _toggleContraceptive(index)
                            _contraceptionUsed = _contraceptives().length > 0
                        }
                    }
                }
            }
        }
    }

    TextSwitch {
        text: qsTr("Ejaculation into vagina?")
        visible: !soloRow.isSolo
        checked: _contraceptionUsed
        onCheckedChanged: {
            if (root.model) {
                root.model.ejaculation = checked ? 1 : 0
            }
        }
    }

    onModelChanged: {
        if (model) {
            if (model.time_of_day === undefined) model.time_of_day = Sex.timeOfDayLabels.length - 1
            if (model.solo === undefined) model.solo = -1
            if (model.contraceptives === undefined) model.contraceptives = "[]"
            if (model.ejaculation === undefined) model.ejaculation = -1
            _contraceptionUsed = _contraceptives().length > 0
        }
    }
}
