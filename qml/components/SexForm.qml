import QtQuick 2.0
import Sailfish.Silica 1.0
import "../scripts/Sex.js" as Sex

Column {
    id: root
    property var model

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

    Label {
        text: qsTr("Time of day")
        color: Theme.highlightColor
        font.pixelSize: Theme.fontSizeSmall
        anchors.left: parent.left
        anchors.leftMargin: Theme.horizontalPageMargin
    }

    Row {
        width: parent.width - 2 * Theme.horizontalPageMargin
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.paddingSmall

        Repeater {
            model: Sex.timeOfDayLabels.length
            delegate: BackgroundItem {
                width: (parent.width - (Sex.timeOfDayLabels.length - 1) * parent.spacing) / Sex.timeOfDayLabels.length
                height: Theme.itemSizeSmall

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.paddingSmall
                    color: root.model && root.model.time_of_day === index
                           ? Theme.rgba(Theme.highlightColor, 0.3)
                           : Theme.rgba(Theme.primaryColor, 0.1)
                    border.width: root.model && root.model.time_of_day === index ? 1 : 0
                    border.color: Theme.highlightColor
                }

                Label {
                    anchors.centerIn: parent
                    text: Sex.timeOfDayLabels[index]
                    font.pixelSize: Theme.fontSizeTiny
                    color: root.model && root.model.time_of_day === index
                           ? Theme.highlightColor : Theme.primaryColor
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                onClicked: {
                    if (root.model) {
                        root.model.time_of_day = index
                    }
                }
            }
        }
    }

    SectionHeader {
        text: qsTr("Were you sexually active today?")
    }

    Row {
        width: parent.width - 2 * Theme.horizontalPageMargin
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.paddingMedium

        Button {
            text: qsTr("Solo")
            highlighted: root.model && root.model.solo === 1
            onClicked: {
                if (root.model) {
                    root.model.solo = 1
                    root.model.ejaculation = 0
                    root.model.contraceptives = "[]"
                    _contraceptionUsed = false
                }
            }
        }

        Button {
            text: qsTr("Partner")
            highlighted: root.model && root.model.solo === 0
            onClicked: {
                if (root.model) {
                    root.model.solo = 0
                }
            }
        }
    }

    Row {
        width: parent.width - 2 * Theme.horizontalPageMargin
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.paddingMedium
        visible: root.model && root.model.solo === 0

        Label {
            text: qsTr("Did you use contraceptives?")
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeSmall
            anchors.verticalCenter: parent.verticalCenter
        }

        Button {
            text: qsTr("No")
            highlighted: root.model && root.model.solo === 0 && !_contraceptionUsed
            onClicked: {
                if (root.model) {
                    root.model.contraceptives = "[]"
                    _contraceptionUsed = false
                }
            }
        }

        Button {
            text: qsTr("Yes")
            highlighted: root.model && root.model.solo === 0 && _contraceptionUsed
            onClicked: {
                _contraceptionUsed = true
            }
        }
    }

    Repeater {
        model: root.model && root.model.solo === 0 && _contraceptionUsed
               ? Sex.contraceptiveLabels.length : 0
        delegate: TextSwitch {
            text: Sex.contraceptiveLabels[index]
            checked: root.model ? _contraceptives().indexOf(index) >= 0 : false
            onCheckedChanged: {
                if (root.model) {
                    _toggleContraceptive(index)
                }
            }
        }
    }

    TextSwitch {
        text: qsTr("Ejaculation into vagina?")
        visible: root.model && root.model.solo === 0 && !_contraceptionUsed
        checked: root.model ? !!root.model.ejaculation : false
        onCheckedChanged: {
            if (root.model) {
                root.model.ejaculation = checked ? 1 : 0
            }
        }
    }

    onModelChanged: {
        if (model) {
            if (model.time_of_day === undefined) model.time_of_day = -1
            if (model.solo === undefined) model.solo = 0
            if (model.contraceptives === undefined) model.contraceptives = "[]"
            if (model.ejaculation === undefined) model.ejaculation = 0
            _contraceptionUsed = _contraceptives().length > 0
        }
    }
}
