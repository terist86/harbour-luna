// Persistence.js
.import QtQuick.LocalStorage 2.0 as PersistenceLS

// First, let's create a short helper function to get the database connection
function database() {
    return PersistenceLS.LocalStorage.openDatabaseSync("luna", "",
                                                       "PersistenceDatabase",
                                                       100000)
}

function initialize() {
    var db = database()
    var ver = db.version
    if (ver === "") {
        db.changeVersion("", "1.0", function (tx) {
            tx.executeSql(
                        'CREATE TABLE IF NOT EXISTS lunas(dbid INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, cycle INTEGER, day1ms BIGINT, pms INTEGER)')
            tx.executeSql(
                        'CREATE TABLE IF NOT EXISTS notes(dbid INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, note TEXT, icon INTEGER, lunaId INTEGER, idx INTEGER)')
        })
        db = database()
        console.log("Initialize db to version 1.0")
        ver = "1.0"
    }
    if (ver === "1.0") {
        db.changeVersion("1.0", "1.1", function (tx) {
            tx.executeSql(
                        'CREATE TABLE IF NOT EXISTS bleedings(dbid INTEGER PRIMARY KEY AUTOINCREMENT, lunaId INTEGER, day BIGINT, intensity INTEGER, excluded BOOLEAN)')
        })
        db = database()
        console.log("Upgrade db to version 1.1")
        ver = "1.1"
    }
    if (ver === "1.1") {
        db.changeVersion("1.1", "1.2", function (tx) {
            tx.executeSql(
                        'CREATE TABLE IF NOT EXISTS sexual_activity(dbid INTEGER PRIMARY KEY AUTOINCREMENT, lunaId INTEGER, day BIGINT, time_of_day INTEGER, solo INTEGER, contraceptives TEXT, ejaculation INTEGER, timestamp BIGINT)')
        })
        db = database()
        console.log("Upgrade db to version 1.2")
        ver = "1.2"
    }
    console.log("Current db version '" + db.version + "'")
}
