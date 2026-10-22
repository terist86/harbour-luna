.pragma library
.import "Persistence.js" as Persistence
.import "Algo.js" as Algo

var timeOfDayLabels = [qsTr("Morning - after waking"),
                       qsTr("Forenoon"),
                       qsTr("Afternoon"),
                       qsTr("Evening"),
                       qsTr("Night - before sleep")]

var contraceptiveLabels = [qsTr("Condom"),
                           qsTr("Pill"),
                           qsTr("IUD"),
                           qsTr("Patch"),
                           qsTr("Ring"),
                           qsTr("Implant"),
                           qsTr("Diaphragm")]

function emptySexInfo(lunaId) {
    return {
        "dbid": 0,
        "lunaId": lunaId,
        "day": Algo.todayMS(),
        "time_of_day": undefined,
        "solo": undefined,
        "contraceptives": "[]",
        "ejaculation": 0,
        "timestamp": Date.now()
    }
}

function getAll(lunaId, day) {
    var res = []
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql(
            "SELECT * FROM sexual_activity WHERE lunaId=? AND day=? ORDER BY timestamp ASC",
            [lunaId, day])
        for (var i = 0; i < rs.rows.length; i++) {
            res.push(rs.rows.item(i))
        }
    })
    return res
}

function get(dbid) {
    var res = ""
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql(
            "SELECT * FROM sexual_activity WHERE dbid=?", [dbid])
        if (rs.rows.length === 1) {
            res = rs.rows.item(0)
        }
    })
    return res
}

function persist(s) {
    var res = ""
    Persistence.database().transaction(function (tx) {
        var rs = tx.executeSql(
            "INSERT INTO sexual_activity (lunaId, day, time_of_day, solo, contraceptives, ejaculation, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)",
            [s.lunaId, s.day, s.time_of_day, s.solo, s.contraceptives, s.ejaculation, s.timestamp])
        if (rs.rowsAffected !== 0) {
            res = rs.insertId
        }
    })
    return res
}

function update(s) {
    Persistence.database().transaction(function (tx) {
        tx.executeSql(
            "UPDATE sexual_activity SET day=?, time_of_day=?, solo=?, contraceptives=?, ejaculation=?, timestamp=? WHERE dbid=?",
            [s.day, s.time_of_day, s.solo, s.contraceptives, s.ejaculation, s.timestamp, s.dbid])
    })
}

function remove(dbid) {
    var res = ""
    Persistence.database().transaction(function (tx) {
        var rs = tx.executeSql("DELETE FROM sexual_activity WHERE dbid=?", [dbid])
        if (rs.rowsAffected === 1) {
            res = "OK"
        }
    })
    return res
}

function isProtected(contraceptivesStr) {
    if (!contraceptivesStr || contraceptivesStr === "[]") return false
    try {
        var arr = JSON.parse(contraceptivesStr)
        return arr.length > 0
    } catch (e) {
        return false
    }
}

function hasSexOnDay(lunaId, day) {
    var count = 0
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql(
            "SELECT COUNT(*) AS cnt FROM sexual_activity WHERE lunaId=? AND day=?",
            [lunaId, day])
        if (rs.rows.length === 1) {
            count = rs.rows.item(0).cnt
        }
    })
    return count > 0
}

function hasUnprotectedOnDay(lunaId, day) {
    var count = 0
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql(
            "SELECT COUNT(*) AS cnt FROM sexual_activity WHERE lunaId=? AND day=? AND solo=0 AND (contraceptives IS NULL OR contraceptives='[]')",
            [lunaId, day])
        if (rs.rows.length === 1) {
            count = rs.rows.item(0).cnt
        }
    })
    return count > 0
}

function hasProtectedOnDay(lunaId, day) {
    var count = 0
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql(
            "SELECT COUNT(*) AS cnt FROM sexual_activity WHERE lunaId=? AND day=? AND solo=0 AND contraceptives IS NOT NULL AND contraceptives!='[]'",
            [lunaId, day])
        if (rs.rows.length === 1) {
            count = rs.rows.item(0).cnt
        }
    })
    return count > 0
}
