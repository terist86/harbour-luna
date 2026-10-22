import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import harbour.luna 1.0
import "../scripts/Backup.js" as Backup

Page {
    id: page

    property string filePath
    property bool encrypted: false
    property bool done: false
    property string errorText

    signal imported()

    function errorMessage(code) {
        switch (code) {
        case "wrong_password":
            return qsTr("Wrong password or damaged file")
        case "unsupported":
            return qsTr("This backup was created by a newer version of Luna")
        case "invalid":
        case "too_large":
            return qsTr("The file is not a valid Luna backup")
        default:
            return qsTr("Import failed")
        }
    }

    BackupFile {
        id: backupFile
        onLoaded: {
            var result = error !== "" ? error : Backup.importJson(content)
            if (result !== "") {
                page.errorText = page.errorMessage(result)
                return
            }
            page.done = true
            password.text = ""
            page.imported()
        }
    }

    Component {
        id: filePicker
        FilePickerPage {
            title: qsTr("Select backup")
            nameFilters: ["*.json", "*.enc"]
            onSelectedContentPropertiesChanged: {
                page.filePath = selectedContentProperties.filePath
                page.encrypted = backupFile.isEncrypted(page.filePath)
                page.done = false
                page.errorText = ""
                password.text = ""
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Import data")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: qsTr("Importing replaces all profiles and records currently in the app. This cannot be undone.")
            }

            ValueButton {
                label: qsTr("File")
                value: page.filePath !== "" ? page.filePath.split("/").pop() : qsTr("Select")
                enabled: !backupFile.busy
                onClicked: pageStack.push(filePicker)
            }

            PasswordField {
                id: password
                visible: page.encrypted
                enabled: !backupFile.busy
                label: qsTr("Password")
                placeholderText: label
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Import")
                enabled: page.filePath !== "" && !page.done && !backupFile.busy
                         && (!page.encrypted || password.text.length > 0)
                onClicked: {
                    Remorse.popupAction(page, qsTr("Replacing all data"), function () {
                        page.errorText = ""
                        backupFile.load(page.filePath, page.encrypted ? password.text : "")
                    })
                }
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Medium
                running: backupFile.busy
                visible: running
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: text !== ""
                wrapMode: Text.Wrap
                color: page.errorText !== "" ? Theme.errorColor : Theme.highlightColor
                text: page.errorText !== ""
                      ? page.errorText
                      : (page.done ? qsTr("Data imported") : "")
            }
        }

        VerticalScrollDecorator {}
    }
}
