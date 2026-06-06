import QtQuick 2.0
import Sailfish.Silica 1.0
import "../scripts/Sex.js" as Sex

Column {
    id: root
    property var model

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

    function _protected() {
        return _contraceptives().length > 0
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
                    color: root.model && root.model.time_of_day === index ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0.15)
                }

                Label {
                    anchors.centerIn: parent
                    text: Sex.timeOfDayLabels[index]
                    font.pixelSize: Theme.fontSizeTiny
                    color: root.model && root.model.time_of_day === index ? Theme.highlightColor : Theme.primaryColor
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
        spacing: Theme.paddingLarge

        BackgroundItem {
            width: (parent.width - parent.spacing) / 2
            height: Theme.itemSizeMedium

            Rectangle {
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: root.model && root.model.solo === 1 ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0.15)
            }

            Label {
                anchors.centerIn: parent
                text: qsTr("Solo")
                color: root.model && root.model.solo === 1 ? Theme.highlightColor : Theme.primaryColor
            }

            onClicked: {
                if (root.model) {
                    root.model.solo = 1
                    root.model.ejaculation = 0
                }
            }
        }

        BackgroundItem {
            width: (parent.width - parent.spacing) / 2
            height: Theme.itemSizeMedium

            Rectangle {
                anchors.fill: parent
                radius: Theme.paddingSmall
                color: root.model && root.model.solo === 0 ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0.15)
            }

            Label {
                anchors.centerIn: parent
                text: qsTr("Partner")
                color: root.model && root.model.solo === 0 ? Theme.highlightColor : Theme.primaryColor
            }

            onClicked: {
                if (root.model) {
                    root.model.solo = 0
                }
            }
        }
    }

    SectionHeader {
        text: qsTr("Did you use contraceptives?")
        visible: root.model && root.model.solo === 0
    }

    Repeater {
        model: root.model && root.model.solo === 0 ? Sex.contraceptiveLabels.length : 0
        delegate: TextSwitch {
            text: Sex.contraceptiveLabels[index]
            checked: root.model ? _contraceptives().indexOf(index) >= 0 : false
            visible: root.model && root.model.solo === 0
            onCheckedChanged: {
                if (root.model && root.model.solo === 0) {
                    _toggleContraceptive(index)
                }
            }
        }
    }

    TextSwitch {
        text: qsTr("Ejaculation into vagina?")
        visible: root.model && root.model.solo === 0 && !_protected()
        checked: root.model ? !!root.model.ejaculation : false
        onCheckedChanged: {
            if (root.model) {
                root.model.ejaculation = checked ? 1 : 0
            }
        }
    }

    Row {
        width: parent.width - 2 * Theme.horizontalPageMargin
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.paddingMedium
        visible: root.model && root.model.solo === 0

        Image {
            id: iconPreview
            source: _protected()
                    ? 'qrc:/icons/scalable/condom.svg'
                    : 'qrc:/icons/scalable/love.svg'
            width: Theme.iconSizeMedium
            height: width
            anchors.verticalCenter: parent.verticalCenter
        }

        Label {
            text: _protected() ? qsTr("Protected") : qsTr("Unprotected")
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeSmall
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    onModelChanged: {
        if (model) {
            if (model.time_of_day === undefined) model.time_of_day = -1
            if (model.solo === undefined) model.solo = 0
            if (model.contraceptives === undefined) model.contraceptives = "[]"
            if (model.ejaculation === undefined) model.ejaculation = 0
        }
    }
}
