import QtQuick 2.0
import Sailfish.Silica 1.0
import "../controls"
import "../components"
import "../scripts/Algo.js" as Algo
import "../scripts/Sex.js" as Sex

Dialog {
    id: page

    property alias sexInfo: sexForm.model
    property alias date: sexDayRow.selectedDate

    DialogHeader {
        id: header
        title: sexInfo
               && sexInfo.dbid !== 0 ? qsTr("Edit sex activity") : qsTr(
                                                "Add sex activity")
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        PushUpMenu {
            id: pushUpMenu
            visible: sexInfo && sexInfo.dbid !== 0

            MenuItem {
                text: qsTr("Remove")
                onClicked: {
                    Remorse.popupAction(page, qsTr("Sex activity was removed"),
                                        function () {
                                            if (Sex.remove(sexInfo.dbid)
                                                === "OK") {
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
                id: sexDayRow
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingMedium

                property var selectedDate: new Date(Algo.todayMS())
                onSelectedDateChanged: loadDataForDay()

                function loadDataForDay() {
                    var ms = Algo.dateToUtcTimestamp(selectedDate)
                    if (sexInfo) {
                        sexInfo.day = ms
                    }
                }

                IconButton {
                    id: prevDay
                    icon.source: "image://theme/icon-m-left"
                    onClicked: {
                        var d = new Date(sexDayRow.selectedDate)
                        d.setDate(d.getDate() - 1)
                        sexDayRow.selectedDate = d
                    }
                }

                ValueButton {
                    id: datePickerButton
                    width: parent.width - prevDay.width - nextDay.width - 2 * parent.spacing
                    label: qsTr("Date")
                    value: Qt.formatDate(sexDayRow.selectedDate,
                                         Qt.DefaultLocaleShortDate)
                    onClicked: {
                        var dialog = pageStack.push(
                                    "Sailfish.Silica.DatePickerDialog", {
                                        "date": sexDayRow.selectedDate
                                    })
                        dialog.accepted.connect(function () {
                            sexDayRow.selectedDate = dialog.date
                        })
                    }
                }

                IconButton {
                    id: nextDay
                    icon.source: "image://theme/icon-m-right"
                    enabled: sexDayRow.selectedDate < new Date(Algo.todayMS())
                    onClicked: {
                        var d = new Date(sexDayRow.selectedDate)
                        d.setDate(d.getDate() + 1)
                        sexDayRow.selectedDate = d
                    }
                }
            }

            SectionHeader {
                text: qsTr("Sex")
            }

            SexForm {
                id: sexForm
            }
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: {
        if (sexInfo && sexInfo.dbid !== 0 && sexInfo.day) {
            sexDayRow.selectedDate = new Date(sexInfo.day)
        }
    }

    onAccepted: {
        if (sexInfo.dbid === 0) {
            Sex.persist(sexInfo)
        } else {
            Sex.update(sexInfo)
        }
    }

    canAccept: sexInfo && sexInfo.time_of_day >= 0 && sexInfo.solo >= 0
}
