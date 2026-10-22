import QtQuick 2.0
import Sailfish.Silica 1.0
import "../scripts/Algo.js" as Algo
import "../scripts/Bleeding.js" as Bleeding
import "../scripts/Sex.js" as Sex

Item {
    id: root
    property int cellWidth: width / 7
    property int cellHeight: cellWidth
    property bool daysVisible: false
    property var lunaInfo

    property alias date: datePicker.date

    property int __renderVersion: 0
    // "lunaId:year-month" -> { dayMs: { bleeding, protectedSex, unprotectedSex } }
    property var __monthCache: ({})

    function forceRefresh() {
        __monthCache = {}
        __renderVersion++
    }

    onLunaInfoChanged: __monthCache = {}

    function _dayEntry(days, ms) {
        if (!days[ms]) {
            days[ms] = { "bleeding": null, "protectedSex": false, "unprotectedSex": false }
        }
        return days[ms]
    }

    // Loads a whole month with one query per table; cells then read from the cache
    function loadDay(lunaId, ms) {
        var d = new Date(ms)
        var y = d.getUTCFullYear()
        var m = d.getUTCMonth()
        var key = lunaId + ":" + y + "-" + m
        var days = __monthCache[key]
        if (!days) {
            days = {}
            var from = Date.UTC(y, m, 1)
            var to = Date.UTC(y, m + 1, 1)
            Bleeding.getRange(lunaId, from, to).forEach(function (b) {
                _dayEntry(days, b.day).bleeding = b
            })
            Sex.getRange(lunaId, from, to).forEach(function (e) {
                if (e.solo === 1) return
                var n
                try { n = JSON.parse(e.contraceptives || "[]").length }
                catch (ex) { return }
                var entry = _dayEntry(days, e.day)
                if (n > 0) entry.protectedSex = true
                else entry.unprotectedSex = true
            })
            __monthCache[key] = days
        }
        return days[ms] || null
    }

    signal showDayDetail(var date)

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

                property var dayData: {
                    root.__renderVersion
                    if (!lunaInfo) return null
                    return root.loadDay(lunaInfo.dbid, cellDate)
                }
                property var bleedingData: dayData ? dayData.bleeding : null

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
                        source: 'qrc:/icons/scalable/condom.svg'
                        visible: dayData ? dayData.protectedSex : false
                        width: Theme.iconSizeExtraSmall
                        height: width
                    }
                    Image {
                        source: 'qrc:/icons/scalable/love.svg'
                        visible: dayData ? dayData.unprotectedSex : false
                        width: Theme.iconSizeExtraSmall
                        height: width
                    }
                }

                onClicked: {
                    datePicker.date = Algo.utcTimestampToDate(cellDate)
                }

                onDoubleClicked: {
                    var _d = Algo.utcTimestampToDate(cellDate)
                    datePicker.date = _d
                    showDayDetail(_d)
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
