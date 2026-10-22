# NOTICE:
#
# Application name defined in TARGET has a corresponding QML filename.
# If name defined in TARGET is changed, the following needs to be done
# to match new name:
#   - corresponding QML filename must be changed
#   - desktop icon filename must be changed
#   - desktop filename must be changed
#   - icon definition filename in desktop file must be changed
#   - translation filenames have to be changed

# The name of your application
TARGET = harbour-luna

CONFIG += sailfishapp

# VERSION is passed by the RPM spec (QMakeOptions); fallback for Qt Creator builds
isEmpty(VERSION): VERSION = 0.4
DEFINES += APP_VERSION=\\\"$$VERSION\\\"

QT += concurrent
PKGCONFIG += libcrypto

SOURCES += src/harbour-luna.cpp \
    src/backupfile.cpp

HEADERS += src/backupfile.h

OTHER_FILES += qml/harbour-luna.qml \
    qml/cover/CoverPage.qml \
    qml/pages/CyclePage.qml \
    qml/pages/ProfilesPage.qml \
    qml/pages/EditLunaDlg.qml \
    qml/pages/EditBleedingDlg.qml \
    qml/pages/EditSexDlg.qml \
    qml/pages/DailyDetail.qml \
    qml/scripts/Qlecti.js \
    qml/scripts/Persistence.js \
    qml/scripts/Algo.js \
    qml/scripts/Bleeding.js \
    qml/controls/ValueButtonEx.qml \
    rpm/harbour-luna.changes \
    rpm/harbour-luna.spec \
    rpm/harbour-luna.yaml \
    translations/*.ts \
    harbour-luna.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172 256x256
#SAILFISHAPP_ICONS = 86x86

# to disable building translations every time, comment out the
# following CONFIG line
CONFIG += sailfishapp_i18n

# German translation is enabled as an example. If you aren't
# planning to localize your app, remember to comment out the
# following TRANSLATIONS line. And also do not forget to
# modify the localized app name in the the .desktop file.
TRANSLATIONS += translations/harbour-luna-de.ts

DISTFILES += \
    qml/components/LunaCalendar.qml \
    qml/pages/AboutPage.qml \
    qml/scripts/Luna.js \
    qml/scripts/Sex.js \
    qml/scripts/Backup.js \
    qml/pages/ExportPage.qml \
    qml/pages/ImportPage.qml \
    qml/components/BleedingForm.qml \
    qml/components/SexForm.qml \
    qml/components/SettingsMenu.qml

resources.files = \
    icons/scalable/blood-drop.svg \
    icons/scalable/condom.svg \
    icons/scalable/love.svg
resources.prefix = /

RESOURCES += resources
