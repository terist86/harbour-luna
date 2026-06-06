
/*
  Copyright (C) 2025 Ladislav Galadík
  Contact: Ladislav Galadík <terist@duck.com>
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
import "../controls"
import "../components"
import "../scripts/Algo.js" as Algo
import "../scripts/Bleeding.js" as Bleeding

Dialog {
    id: page

    property alias bleedingInfo: bleedingForm.model
    property alias date: bleedingDayRow.selectedDate
    property bool _removed: false

    DialogHeader {
        id: header
        title: bleedingInfo
               && bleedingInfo.dbid !== 0 ? qsTr("Edit bleeding") : qsTr(
                                                "Add bleeding")
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PushUpMenu {
            id: pushUpMenu
            visible: bleedingInfo && bleedingInfo.dbid !== 0

            MenuItem {
                text: qsTr("Remove")
                onClicked: {
                    Remorse.popupAction(page, qsTr("Bleeding was removed"),
                                        function () {
                                            if (Bleeding.remove(
                                                        bleedingInfo) === "OK") {
                                                page._removed = true
                                                page.accept()
                                            }
                                        })
                }
            }
        }

        Column {
            id: column
            anchors.top: parent.top
            anchors.topMargin: header.height
            spacing: Theme.paddingLarge
            width: parent.width

            SectionHeader {
                text: qsTr("Date")
            }

            Row {
                id: bleedingDayRow
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingMedium

                property var selectedDate: new Date(Algo.todayMS())
                onSelectedDateChanged: loadDataForDay()

                function loadDataForDay() {
                    var ms = Algo.dateToUtcTimestamp(selectedDate)
                    var _existing = Bleeding.get(bleedingInfo.lunaId, ms)

                    if (_existing) {
                        bleedingInfo.dbid = _existing.dbid
                        bleedingInfo.intensity = _existing.intensity
                        bleedingInfo.excluded = _existing.excluded
                        bleedingInfo.day = _existing.day
                    } else {
                        bleedingInfo.dbid = 0
                        bleedingInfo.intensity = -1
                        bleedingInfo.excluded = false
                        bleedingInfo.day = ms
                    }
                    // Trigger update in form
                    bleedingForm.modelChanged()
                }

                IconButton {
                    id: prevDay
                    icon.source: "image://theme/icon-m-left"
                    onClicked: {
                        var d = new Date(bleedingDayRow.selectedDate)
                        d.setDate(d.getDate() - 1)
                        bleedingDayRow.selectedDate = d
                    }
                }

                ValueButton {
                    id: datePickerButton
                    width: parent.width - prevDay.width - nextDay.width - 2 * parent.spacing
                    label: qsTr("Date")
                    value: Qt.formatDate(bleedingDayRow.selectedDate,
                                         Qt.DefaultLocaleShortDate)
                    onClicked: {
                        var dialog = pageStack.push(
                                    "Sailfish.Silica.DatePickerDialog", {
                                        "date": bleedingDayRow.selectedDate
                                    })
                        dialog.accepted.connect(function () {
                            bleedingDayRow.selectedDate = dialog.date
                        })
                    }
                }

                IconButton {
                    id: nextDay
                    icon.source: "image://theme/icon-m-right"
                    enabled: bleedingDayRow.selectedDate < new Date(Algo.todayMS(
                                                                        ))
                    onClicked: {
                        var d = new Date(bleedingDayRow.selectedDate)
                        d.setDate(d.getDate() + 1)
                        bleedingDayRow.selectedDate = d
                    }
                }
            }

            SectionHeader {
                text: qsTr("Bleeding")
            }

            BleedingForm {
                id: bleedingForm
            }
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: {
        if (bleedingInfo && bleedingInfo.dbid !== 0) {
            bleedingDayRow.selectedDate = new Date(bleedingInfo.day)
        }
    }

    onAccepted: {
        if (page._removed) return
        if (bleedingInfo.dbid === 0) {
            var savedDay = bleedingInfo.day
            Bleeding.persist(bleedingInfo)
            Bleeding.autoFillMissingPeriodDays(bleedingInfo.lunaId, savedDay)
        } else {
            Bleeding.update(bleedingInfo)
        }
    }

    canAccept: bleedingDayRow.selectedDate <= new Date(Algo.todayMS()) && bleedingForm.intensity >= 0
}
