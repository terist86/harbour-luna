
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
    property bool updateAfterManage: false

    DialogHeader {
        id: header
        title: bleedingInfo.dbid !== 0 ? qsTr("Edit bleeding") : qsTr(
                                             "Add bleeding")
    }

    SilicaFlickable {
        anchors.top: header.bottom
        anchors.bottom: page.bottom
        anchors.left: page.left
        anchors.right: page.right
        clip: true

        contentHeight: column.height

        PushUpMenu {
            id: pushUpMenu
            visible: bleedingInfo.dbid !== 0

            MenuItem {
                text: qsTr("Remove")
                onClicked: {
                    var remorse = Remorse.popupAction(
                                page, qsTr("Bleeding was removed"),
                                function () {
                                    Bleeding.remove(bleedingInfo)
                                }).canceled.connect(function () {
                                    Notices.show("Bleeding was not removed",
                                                 Notice.Short, Notice.Center)
                                })
                }
            }
        }

        Column {
            id: column
            spacing: Theme.paddingLarge
            width: parent.width

            SectionHeader {
                text: qsTr("Date")
            }

            Row {
                id: bleeding_day
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingMedium

                property var selectedDate: new Date(Algo.todayMS())
                onSelectedDateChanged: loadDataForDay()
                function loadDataForDay() {
                    datePicker.value = selectedDate.toLocaleDateString()

                    var _bleedingInfo = Bleeding.get(bleedingInfo.lunaId,
                                                     Algo.dateToUtcTimestamp(
                                                         selectedDate))

                    if (!!_bleedingInfo) {
                        bleedingInfo.dbid = _bleedingInfo.dbid
                        bleedingInfo.intensity = _bleedingInfo.intensity
                        bleedingInfo.excluded = _bleedingInfo.excluded
                    } else {
                        bleedingInfo.dbid = 0
                    }

                    header.title = bleedingInfo.dbid !== 0 ? qsTr("Edit bleeding") : qsTr(
                                                                 "Add bleeding")
                }

                IconButton {
                    id: prevDay
                    icon.source: "image://theme/icon-m-left"
                    function setPrevDay() {
                        var currentDate = bleeding_day.selectedDate
                        currentDate.setDate(currentDate.getDate() - 1)
                        bleeding_day.selectedDate = currentDate
                    }

                    onClicked: setPrevDay()
                }
                Column {
                    width: parent.width - prevDay.width - nextDay.width - 2 * spacing
                    ValueButton {
                        id: datePicker
                        function openDateDialog() {

                            var dialog = pageStack.push(
                                        "Sailfish.Silica.DatePickerDialog", {
                                            "date": bleeding_day.selectedDate
                                        })
                            dialog.accepted.connect(function () {
                                bleeding_day.selectedDate = dialog.date
                            })
                        }

                        value: bleeding_day.selectedDate.toLocaleDateString()
                        onClicked: openDateDialog()
                    }
                }

                IconButton {
                    id: nextDay
                    icon.source: "image://theme/icon-m-right"
                    function setNextDay() {
                        var currentDate = bleeding_day.selectedDate
                        currentDate.setDate(currentDate.getDate() + 1)
                        bleeding_day.selectedDate = currentDate
                    }

                    enabled: bleeding_day.selectedDate < new Date(Algo.todayMS(
                                                                      ))

                    onClicked: setNextDay()
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
        if (bleedingInfo.dbid !== 0) {
            bleeding_day.value = Qt.formatDate(new Date(bleedingInfo.day))
            intensity.value = bleedingInfo.intensity
            exclude.checked = bleedingInfo.excluded
        }
    }

    canAccept: {

        return bleeding_day.selectedDate.length > 0
    }

    onAccepted: {
        var update = false

        var day
        if (bleeding_day.selectedDate) {
            day = Algo.dateToUtcTimestamp(bleeding_day.selectedDate)
        } else {
            day = Algo.todayMS()
        }

        if (bleedingInfo.day !== day) {
            update = true
            bleedingInfo.day = day
        }

        if (bleedingInfo.intensity !== intensity.value) {
            update = true
            bleedingInfo.intensity = intensity.value
        }

        if (bleedingInfo.excluded !== exclude.checked) {
            update = true
            bleedingInfo.excluded = exclude.checked
        }

        if (update) {
            if (bleedingInfo.dbid === 0) {
                var dbid = Bleeding.persist(bleedingInfo)
                console.log("New bleeding record created with dbid = " + dbid)
            } else {
                Bleeding.update(bleedingInfo)
                console.log("Bleeding record with dbid = " + bleedingInfo.dbid
                            + " has been updated")
            }
        }
    }
}
