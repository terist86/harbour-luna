import QtQuick 2.0
import Sailfish.Silica 1.0
import "../scripts/Bleeding.js" as Bleeding

Column {
    property var model

    width: parent.width
    Slider {
        id: intensity
        width: parent.width
        label: qsTr("How heavy is the bleeding?")
        minimumValue: 0
        maximumValue: 3
        value: 2
        stepSize: 1
        valueText: Bleeding.intensities[value]
        onValueChanged: {
            valueText = Bleeding.intensities[value]
        }
    }

    TextSwitch {
        id: exclude
        text: qsTr("Exclude this bleeding")
        description: qsTr("You can exclude this value if it's not menstrual bleeding")
    }
    onModelChanged: {
        intensity.value = model.intensity
        exclude.checked = !!model.checked
    }
}
