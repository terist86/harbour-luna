import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.luna 1.0
import "../scripts/Backup.js" as Backup

Page {
    id: page

    readonly property int minPasswordLength: 8
    readonly property bool canExport: noEncrypt.checked
                                      || (password.text.length >= minPasswordLength
                                          && password.text === confirm.text)
    property string savedPath
    property string errorText

    BackupFile {
        id: backupFile
        onSaved: {
            if (error === "") {
                page.savedPath = path
                password.text = ""
                confirm.text = ""
            } else {
                page.errorText = qsTr("Export failed")
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
                title: qsTr("Export data")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: qsTr("All profiles and records are saved to a file in the Documents folder. The data is sensitive, so protect the file with a password.")
            }

            PasswordField {
                id: password
                visible: !noEncrypt.checked
                enabled: !backupFile.busy
                label: qsTr("Password")
                placeholderText: label
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: confirm.focus = true
            }

            PasswordField {
                id: confirm
                visible: !noEncrypt.checked
                enabled: !backupFile.busy
                label: text.length > 0 && text !== password.text
                       ? qsTr("Passwords do not match") : qsTr("Repeat password")
                placeholderText: qsTr("Repeat password")
                errorHighlight: text.length > 0 && text !== password.text
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !noEncrypt.checked
                         && password.text.length < page.minPasswordLength
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("At least %1 characters").arg(page.minPasswordLength)
            }

            TextSwitch {
                id: noEncrypt
                enabled: !backupFile.busy
                text: qsTr("Don't encrypt")
                description: qsTr("Anyone with access to the file can read your data")
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Export")
                enabled: page.canExport && !backupFile.busy
                onClicked: {
                    var encrypt = !noEncrypt.checked
                    page.savedPath = ""
                    page.errorText = ""
                    backupFile.save(backupFile.suggestedPath(encrypt),
                                    Backup.exportJson(),
                                    encrypt ? password.text : "")
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
                      : (page.savedPath !== "" ? qsTr("Saved to %1").arg(page.savedPath) : "")
            }
        }

        VerticalScrollDecorator {}
    }
}
