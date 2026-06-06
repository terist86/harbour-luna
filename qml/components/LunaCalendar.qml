import QtQuick 2.0
import Sailfish.Silica 1.0
import "../scripts/Algo.js" as Algo
import "../scripts/Bleeding.js" as Bleeding

Item {
    id: root
    property int cellWidth: width / 7
    property int cellHeight: cellWidth
    property bool daysVisible: false
    property var lunaInfo

    property alias date: datePicker.date

    property int __renderVersion: 0

    function forceRefresh() {
        __renderVersion++
    }

    signal editNote(var date)
    signal editBleeding(var date)

    width: parent.width
    height: datePicker.height + weekDaysSimulator.height
    Row {
        id: weekDaysSimulator
        height: Theme.paddingMedium + Theme.iconSizeExtraSmall + Theme.paddingSmall
        Repeater {
            model: 7
            delegate: Label {
                // 2 Jan 2000 was a Sunday
                text: Qt.formatDateTime(new Date(2000, 0, 3 + index, 12), "ddd")
                width: cellWidth
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.highlightColor
                opacity: 0.5
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
    Image {
        anchors.fill: parent
        source: "image://theme/graphic-gradient-edge"
        rotation: 180
        visible: isPortrait
    }
    DatePicker {
        id: datePicker
        property bool daysVisible: false
        anchors.top: weekDaysSimulator.bottom

        delegate: Component {
            ListItem {
                id: rect
                width: cellWidth
                height: cellHeight

                property var cellDate: Date.UTC(model.year, model.month - 1,
                                                model.day)

                contentHeight: height
                contentWidth: width

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 8
                    color: 'transparent'
                    border.color: 'transparent'
                    border.width: 0
                }

                property var bleedingData: {
                    root.__renderVersion
                    if (!lunaInfo) return null
                    var res = Bleeding.get(lunaInfo.dbid, cellDate)
                    return res !== "" ? res : null
                }

                Label {
                    property bool _today: {
                        return datePicker.day === model.day
                                && datePicker.month === model.month
                                && datePicker.year === model.year
                    }
                    anchors.centerIn: parent
                    text: model.day
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: _today
                }

                Image {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    source: 'qrc:/icons/scalable/temperature.svg'
                    visible: false
                    width: Theme.iconSizeExtraSmall
                    height: width
                }

                Row {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.paddingSmall
                    spacing: -Theme.paddingSmall / 2

                    Repeater {
                        model: bleedingData ? bleedingData.intensity + 1 : 0
                        Image {
                            source: 'qrc:/icons/scalable/blood-drop.svg'
                            width: Theme.iconSizeExtraSmall / 1.5
                            height: width
                        }
                    }
                }

                Row {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    spacing: -Theme.paddingSmall / 2

                    Image {
                        source: 'qrc:/icons/scalable/kiss.svg'
                        visible: false
                        width: Theme.iconSizeExtraSmall
                        height: width
                    }
                    Image {
                        source: 'qrc:/icons/scalable/condom.svg'
                        visible: false
                        width: Theme.iconSizeExtraSmall
                        height: width
                    }
                    Image {
                        source: 'qrc:/icons/scalable/love.svg'
                        visible: false
                        width: Theme.iconSizeExtraSmall
                        height: width
                    }
                }

                onClicked: {
                    datePicker.date = new Date(cellDate)
                }

                onDoubleClicked: {
                    var _d = new Date(cellDate)
                    datePicker.date = _d
                    editBleeding(_d)
                }
            }
        }
    }

    Component.onCompleted: {
        if (daysVisible) {
            weekDaysSimulator.height = 0
            weekDaysSimulator.visible = false
            datePicker.daysVisible = true
            cellWidth = datePicker.cellWidth
            cellHeight = datePicker.cellHeight
        }
    }
}
