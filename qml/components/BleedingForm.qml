import QtQuick 2.0
import Sailfish.Silica 1.0
import "../scripts/Bleeding.js" as Bleeding

Column {
    id: root
    property var model
    property alias intensity: intensityRow.currentIntensity

    width: parent.width
    spacing: Theme.paddingMedium

    Label {
        text: qsTr("How heavy is the bleeding?")
        color: Theme.highlightColor
        font.pixelSize: Theme.fontSizeSmall
        anchors.left: parent.left
        anchors.leftMargin: Theme.horizontalPageMargin
    }

    Row {
        id: intensityRow
        width: parent.width - 2 * Theme.horizontalPageMargin
        anchors.horizontalCenter: parent.horizontalCenter
        height: Theme.itemSizeSmall

        property int currentIntensity: model ? model.intensity : -1

        Repeater {
            model: Bleeding.intensities.length
            delegate: BackgroundItem {
                width: parent.width / Bleeding.intensities.length
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - Theme.paddingSmall
                    height: Theme.paddingMedium
                    radius: 4
                    color: Theme.rgba(
                               intensityRow.currentIntensity
                               === index ? Theme.highlightColor : Theme.primaryColor,
                               0.25 * index + 0.1)
                }

                Label {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Bleeding.intensities[index]
                    font.pixelSize: Theme.fontSizeTiny
                    color: intensityRow.currentIntensity
                           === index ? Theme.highlightColor : Theme.primaryColor
                }

                onClicked: {
                    if (root.model) {
                        root.model.intensity = index
                        intensityRow.currentIntensity = index
                    }
                }
            }
        }
    }

    TextSwitch {
        id: excludeSwitch
        text: qsTr("Exclude this bleeding")
        description: qsTr("You can exclude this value if it's not menstrual bleeding")
        checked: model ? !!model.excluded : false
        onCheckedChanged: {
            if (root.model) {
                root.model.excluded = checked
            }
        }
    }

    onModelChanged: {
        if (model) {
            intensityRow.currentIntensity = model.intensity
            excludeSwitch.checked = !!model.excluded
        }
    }
}
