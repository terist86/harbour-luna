import QtQuick 2.0
import Sailfish.Silica 1.0
import "../scripts/Algo.js" as Algo
import "../scripts/Bleeding.js" as Bleeding

Item {
    property int cellWidth: width / 7
    property int cellHeight: cellWidth
    property bool daysVisible: false
    property var lunaInfo

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
            Rectangle {
                id: rect
                width: cellWidth
                height: cellHeight
                radius: 2
                color: rectColor(model.day, model.month, model.year)
                border.color: borderColor(model.day, model.month, model.year)
                border.width: borderColor(model.day, model.month,
                                          model.year) !== 'transparent' ? 1 : 0

                function rectColor(day, month, year) {
                    var _bleeding = Bleeding.get(lunaInfo.dbid,
                                                 Date.UTC(year, month - 1, day))
                    if (!!_bleeding) {
                        return Theme.rgba(
                                    Algo.MN_COLOR,
                                    Math.min(1.0,
                                             0.2 * (1 + _bleeding.intensity)))
                    }
                    return 'transparent'
                }

                function borderColor(day, month, year) {
                    var d = Date.UTC(year, month - 1, day)
                    var _bleeding = Bleeding.get(lunaInfo.dbid, d)
                    if (!_bleeding) {
                        var _doc = Algo.daysInCycle(lunaInfo.cycle,
                                                    lunaInfo.day1ms, d)
                        if (_doc === 0)
                            return Theme.rgba(Algo.MN_COLOR, 1.0)
                    }
                    return 'transparent'
                }

                function rectIcon(day, month, year) {
                    if (lunaInfo) {
                        var d = Algo.daysInCycle(lunaInfo.cycle,
                                                 lunaInfo.day1ms,
                                                 Date.UTC(year, month - 1, day))
                        var icon = lunaInfo.iconArr[d]
                        if (icon === 0) {
                            return 'image://theme/icon-s-alarm'
                        }
                    }
                    return ''
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
                    color: Theme.primaryColor
                }


                /*TBD Image {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    source: rectIcon(model.day, model.month, model.year)
                    scale: 0.75
                }*/
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
