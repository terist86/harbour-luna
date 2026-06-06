import QtQuick 2.0
import Sailfish.Silica 1.0
import "../controls"
import "../components"
import "../scripts/Algo.js" as Algo
import "../scripts/Bleeding.js" as Bleeding
import "../scripts/Sex.js" as Sex

Page {
    id: page

    property int lunaId: 0
    property var selectedDate: new Date()
    property var _bleedingInfo: null

    ListModel {
        id: sexModel
    }

    function refresh() {
        var ms = Algo.dateToUtcTimestamp(selectedDate)

        var b = Bleeding.get(lunaId, ms)
        _bleedingInfo = b !== "" ? b : null

        sexModel.clear()
        var entries = Sex.getAll(lunaId, ms)
        for (var i = 0; i < entries.length; i++) {
            sexModel.append(entries[i])
        }
    }

    function openEditBleeding() {
        var ms = Algo.dateToUtcTimestamp(selectedDate)
        var info = Bleeding.get(lunaId, ms)
        if (info === '') {
            info = Bleeding.emptyBleedingInfo(lunaId)
            info.day = ms
        }

        var dialog = pageStack.push(Qt.resolvedUrl("EditBleedingDlg.qml"), {
                                        "bleedingInfo": info,
                                        "date": selectedDate
                                    })
        dialog.accepted.connect(function () {
            refresh()
        })
    }

    function editSex(dbid) {
        var info
        if (dbid > 0) {
            info = Sex.get(dbid)
        }
        if (!info || info === '') {
            info = Sex.emptySexInfo(lunaId)
            info.day = Algo.dateToUtcTimestamp(selectedDate)
            info.timestamp = Date.now()
        }

        var dialog = pageStack.push(sexDialogComponent, {"sexInfo": info})
        dialog.accepted.connect(function () {
            refresh()
        })
    }

    Component {
        id: sexDialogComponent
        Dialog {
            id: sexDlg
            property var sexInfo

            DialogHeader {
                title: sexInfo && sexInfo.dbid !== 0 ? qsTr("Edit sex activity") : qsTr("Add sex activity")
            }

            SilicaFlickable {
                anchors.fill: parent
                contentHeight: column.height

                PushUpMenu {
                    visible: sexInfo && sexInfo.dbid !== 0

                    MenuItem {
                        text: qsTr("Remove")
                        onClicked: {
                            Remorse.popupAction(sexDlg, qsTr("Sex activity was removed"),
                                function () {
                                    if (Sex.remove(sexInfo.dbid) === "OK") {
                                        sexDlg.accept()
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

                    SexForm {
                        model: sexInfo
                    }
                }

                VerticalScrollDecorator {}
            }

            canAccept: sexInfo && sexInfo.time_of_day >= 0 && sexInfo.solo >= 0

            onAccepted: {
                if (sexInfo.dbid === 0) {
                    Sex.persist(sexInfo)
                } else {
                    Sex.update(sexInfo)
                }
            }
        }
    }

    SilicaFlickable {
        id: flickable
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                text: qsTr("Go to today")
                onClicked: {
                    selectedDate = new Date()
                    refresh()
                }
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: 0

            PageHeader {
                title: Qt.formatDate(selectedDate, Qt.DefaultLocaleLongDate)
            }

            SectionHeader {
                text: qsTr("Bleeding")
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeLarge
                onClicked: openEditBleeding()

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.paddingSmall

                    Repeater {
                        model: _bleedingInfo ? _bleedingInfo.intensity + 1 : 0
                        Image {
                            source: 'qrc:/icons/scalable/blood-drop.svg'
                            width: Theme.iconSizeExtraSmall
                            height: width
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Label {
                        text: _bleedingInfo
                              ? Bleeding.intensities[_bleedingInfo.intensity]
                              : qsTr("No bleeding logged")
                        color: _bleedingInfo ? Theme.primaryColor : Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Image {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    source: "image://theme/icon-m-right"
                }
            }

            SectionHeader {
                text: qsTr("Sex")
            }

            Repeater {
                model: sexModel

                delegate: BackgroundItem {
                    width: parent.width
                    height: Theme.itemSizeMedium

                    onClicked: editSex(model.dbid)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.paddingMedium

                        Image {
                            source: {
                                var c = model.contraceptives || "[]"
                                var protectedSex = false
                                try {
                                    protectedSex = JSON.parse(c).length > 0
                                } catch (e) {}
                                return protectedSex
                                       ? 'qrc:/icons/scalable/condom.svg'
                                       : 'qrc:/icons/scalable/love.svg'
                            }
                            width: Theme.iconSizeMedium
                            height: width
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: -Theme.paddingSmall

                            Label {
                                text: Sex.timeOfDayLabels[model.time_of_day] || ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.highlightColor
                            }

                            Label {
                                text: {
                                    var t = model.solo === 1 ? qsTr("Solo") : qsTr("Partner")
                                    if (model.solo === 0 && model.ejaculation === 1) {
                                        t += " \u2022 " + qsTr("Ejaculation")
                                    }
                                    return t
                                }
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                            }
                        }
                    }

                    Image {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://theme/icon-m-right"
                    }
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeMedium

                onClicked: editSex(0)

                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Add sex activity")
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }

    onSelectedDateChanged: refresh()
}
