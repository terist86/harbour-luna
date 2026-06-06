
/*
  Copyright (C) 2016 Amilcar Santos
  Contact: Amilcar Santos <amilcar.santos@gmail.com>
  All rights reserved.

  You may use this file under the terms of BSD license as follows:

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Amilcar Santos nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
import QtQuick 2.0
import Sailfish.Silica 1.0
import "../scripts/Qlecti.js" as Ql
import "../scripts/Persistence.js" as Persistence
import "../scripts/Algo.js" as Algo
import "../scripts/Bleeding.js" as Bleeding
import "../scripts/Luna.js" as Luna
import "../components"

Page {
    id: page

    property bool updateAfterManage: false
    property var selectLunaIndex

    SilicaFlickable {
        id: mainView
        anchors.fill: parent

        SettingsMenu {
            model: lunasModel
            activeLunaIdx: lunaView.currentIndex
            onProfilesEdited: updateAfterManage = true
            onProfileSelected: lunaView.currentIndex = idx
        }

        PushUpMenu {
            MenuItem {
                text: qsTr("Go to today")
                onClicked: datePicker.date = new Date()
            }
            MenuItem {
                text: qsTr("Edit bleeding")
                visible: lunasModel.count > 0
                onClicked: {
                    var _lunaInfo = lunasModel.get(lunaView.currentIndex)
                    page.editBleedingForDate(_lunaInfo.dbid, datePicker.date)
                }
            }
        }

        // Tell SilicaFlickable the height of its content.
        contentHeight: isPortrait ? dateColumn.height + lunaColumn.height : dateColumn.height

        Column {
            id: dateColumn

            property var pickerLunaInfo

            width: isPortrait ? parent.width : Screen.width //parent.width * 0.55;
            spacing: 0
            PageHeader {
                id: header
                title: "Luna"
                visible: isPortrait
            }
            Item {
                id: landscapeSpacing
                visible: isLandscape
                width: parent.width
                height: Theme.paddingMedium
            }
            LunaCalendar {
                id: datePicker
                lunaInfo: dateColumn.pickerLunaInfo
                onEditBleeding: {
                    var _lunaInfo = lunasModel.get(lunaView.currentIndex)
                    page.editBleedingForDate(_lunaInfo.dbid, date)
                }
            }
        }
        Item {
            id: lunaColumn
            x: isPortrait ? 0 : dateColumn.width
            y: isPortrait ? dateColumn.height + dateColumn.y : Theme.paddingLarge
            width: isPortrait ? page.width : page.width - dateColumn.width
            height: isPortrait ? page.height - dateColumn.height : page.height
            clip: true

            SectionHeader {
                id: lunaHeader
                text: qsTr("Information")
            }

            SlideshowView {
                id: lunaView
                y: lunaHeader.y
                width: parent.width
                itemWidth: parent.width

                model: 0
                delegate: Item {
                    width: lunaView.itemWidth
                    height: labels.height

                    Column {
                        id: labels
                        width: parent.width
                        spacing: -1
                        Label {
                            id: name
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: model.name
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primaryColor
                        }
                        DetailItem {
                            id: cycles
                            label: qsTr("Cycle")
                            value: model.cycle
                        }
                        DetailItem {
                            id: dayincycle
                            label: qsTr("Day in cycle")
                            value: model.dayInCycle
                        }
                        DetailItem {
                            id: nextOv
                            label: qsTr("Next ovulation")
                            value: model.nextOv
                        }
                        DetailItem {
                            id: nextMn
                            label: qsTr("Next menstruation")
                            value: model.nextMn
                        }
                    }
                }

                onCurrentIndexChanged: {
                    Ql.on(lunasModel).at(currentIndex, function (luna) {
                        page.fillLunaInfo(luna)
                    }).empty(function () {
                        appWindow.coverInfo = undefined
                        dateColumn.pickerLunaInfo = undefined
                    })
                }
            }
        }

        Label {
            id: noLunaPlaceholder
            anchors.fill: lunaColumn
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font {
                pixelSize: Theme.fontSizeLarge
                family: Theme.fontFamilyHeading
            }
            color: Theme.rgba(Theme.highlightColor, 0.6)
            visible: lunaView.model.count === 0
            text: qsTr("No data available")
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Activating && updateAfterManage) {
            updateAfterManage = false
            Ql.on(lunasModel).at(lunaView.currentIndex, function (luna) {
                var actualDay1ms = Bleeding.getActualDay1ms(luna.dbid)
                if (actualDay1ms !== "") {
                    lunasModel.setProperty(lunaView.currentIndex, "effectiveDay1ms", actualDay1ms)
                    if (actualDay1ms !== luna.day1ms) {
                        lunasModel.setProperty(lunaView.currentIndex, "day1ms", actualDay1ms)
                    }
                }
                page.fillLunaInfo(luna)
                datePicker.forceRefresh()
            }).empty(function () {
                appWindow.coverInfo = undefined
                dateColumn.pickerLunaInfo = undefined
            })
        }
    }

    ListModel {
        id: lunasModel
    }

    function fillLunaInfo(g) {
        var colors = []
        var opacitys = []
        colors[g.cycle] = undefined
        opacitys[g.cycle] = undefined

        if (g.pms > Algo.PMS_OFF) {
            Ql.ng().loop(g.cycle - g.pms, g.pms, function (i, p) {
                colors[i] = Algo.PMS_COLOR
                opacitys[i] = (p / g.pms) * 0.5 + 0.1
            })
        }

        Ql.ng().loop(0, Algo.MN_DAYS, function (i, p) {
            colors[i] = Algo.MN_COLOR
            opacitys[i] = (Algo.MN_DAYS + 1 - p) / Algo.MN_DAYS * 0.6 + 0.2
        })
        Ql.ng().loop(g.cycle - Algo.OV_DAYS_BEFORE - Algo.OV_DAYS_SPAN,
                     Algo.OV_DAYS, function (i, p) {
                         colors[i] = Algo.OV_COLOR
                         var o = 0.75
                         if (p < Algo.OV_DAYS_SPAN) {
                             o = p / Algo.OV_DAYS_SPAN
                         } else if (p > Algo.OV_DAYS_SPAN) {
                             o = (Algo.OV_DAYS_SPAN * 2 - p) / Algo.OV_DAYS_SPAN
                         }
                         opacitys[i] = o + 0.15
                     })

        var coverColor = Theme.rgba('#a0a0a0', 0.6)
        if (colors[g.dayInCycle - 1]) {
            coverColor = Theme.rgba(colors[g.dayInCycle - 1],
                                    opacitys[g.dayInCycle - 1])
        }

        dateColumn.pickerLunaInfo = {
            "colorArr": colors,
            "opacityArr": opacitys,
            "cycle": g.cycle,
            "day1ms": g.effectiveDay1ms || g.day1ms,
            "dbid": g.dbid
        }

        appWindow.coverInfo = {
            "name": g.name,
            "color": coverColor,
            "dayInCycle": g.dayInCycle,
            "nextOv": g.coverOv,
            "nextMn": g.coverMn
        }
    }

    Component.onCompleted: {
        Persistence.initialize()
        Luna.populate(lunasModel)

        var curDayMS = Algo.todayMS()

        Ql.on(lunasModel).each(function (g, i) {
            var actualDay1ms = Bleeding.getActualDay1ms(g.dbid)
            var effectiveDay1ms = actualDay1ms !== "" ? actualDay1ms : g.day1ms

            if (actualDay1ms !== "" && actualDay1ms !== g.day1ms) {
                lunasModel.setProperty(i, "day1ms", actualDay1ms)
            }

            var _daysInCycle = Algo.daysInCycle(g.cycle, effectiveDay1ms, curDayMS)
            var ov = Algo.nextOvDays(_daysInCycle, g.cycle)
            var mn = Algo.nextMnDays(_daysInCycle, g.cycle)
            var today = Algo.formatDays(0)

            console.log("[DEBUG] luna[" + i + "] '" + g.name + "': storedDay1ms=" + g.day1ms + " actualDay1ms=" + actualDay1ms + " effectiveDay1ms=" + effectiveDay1ms + " cycle=" + g.cycle + " daysInCycle=" + (_daysInCycle + 1) + " nextOv=" + ov + " nextMn=" + mn)

            lunasModel.setProperty(i, "dayInCycle", _daysInCycle + 1)
            lunasModel.setProperty(i, "effectiveDay1ms", effectiveDay1ms)
            lunasModel.setProperty(i, "nextOv", Algo.formatDays(ov))
            lunasModel.setProperty(i, "coverOv", ov === 0 ? today : String(ov))
            lunasModel.setProperty(i, "nextMn", Algo.formatDays(mn))
            lunasModel.setProperty(i, "coverMn", mn === 0 ? today : String(mn))
        }).first(function (luna) {
            fillLunaInfo(luna)
        })
        lunaView.model = lunasModel
    }

    function editBleedingForDate(dbid, date) {
        var ms = Algo.dateToUtcTimestamp(date)
        var _bleedingInfo = Bleeding.get(dbid, ms)
        if (_bleedingInfo === '') {
            _bleedingInfo = Bleeding.emptyBleedingInfo(dbid)
            _bleedingInfo.day = ms
        }

        var dialog = pageStack.push(Qt.resolvedUrl("EditBleedingDlg.qml"), {
                                        "bleedingInfo": _bleedingInfo,
                                        "date": date
                                    })
        dialog.accepted.connect(function () {
            console.log("Bleeding accepted")
            updateAfterManage = true
        })
    }
}
