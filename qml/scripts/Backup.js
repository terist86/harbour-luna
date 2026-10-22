.pragma library
.import "Persistence.js" as Persistence

var FORMAT = 1

// Exported columns per table; inserted in this order on import
var TABLES = {
    "lunas": ["dbid", "name", "cycle", "day1ms", "pms"],
    "bleedings": ["dbid", "lunaId", "day", "intensity", "excluded"],
    "sexual_activity": ["dbid", "lunaId", "day", "time_of_day", "solo",
                        "contraceptives", "ejaculation", "timestamp"]
}

function exportJson() {
    var db = Persistence.database()
    var res = {
        "app": "harbour-luna",
        "format": FORMAT,
        "dbVersion": db.version,
        "exported": new Date().toISOString()
    }
    db.readTransaction(function (tx) {
        for (var table in TABLES) {
            var cols = TABLES[table]
            // Skip records left over from deleted profiles
            var where = table === "lunas" ? "" : " WHERE lunaId IN (SELECT dbid FROM lunas)"
            var rs = tx.executeSql("SELECT " + cols.join(", ") + " FROM " + table
                                   + where + " ORDER BY dbid")
            var rows = []
            for (var i = 0; i < rs.rows.length; i++) {
                var item = rs.rows.item(i)
                var row = {}
                cols.forEach(function (c) {
                    row[c] = item[c]
                })
                rows.push(row)
            }
            res[table] = rows
        }
    })
    return JSON.stringify(res)
}

// Replaces all data with the backup in one transaction.
// Returns "" on success or an error key: "invalid", "unsupported", "db".
function importJson(text) {
    var data
    try {
        data = JSON.parse(text)
    } catch (e) {
        return "invalid"
    }
    if (!data || data.app !== "harbour-luna") {
        return "invalid"
    }
    if (data.format !== FORMAT) {
        return "unsupported"
    }
    if (!_isValid(data)) {
        return "invalid"
    }
    // Older exports may contain records of deleted profiles; drop them
    var lunaIds = {}
    data.lunas.forEach(function (l) {
        lunaIds[l.dbid] = true
    })
    function hasLuna(r) {
        return lunaIds[r.lunaId] === true
    }
    data.bleedings = data.bleedings.filter(hasLuna)
    data.sexual_activity = data.sexual_activity.filter(hasLuna)

    try {
        Persistence.database().transaction(function (tx) {
            tx.executeSql("DELETE FROM sexual_activity")
            tx.executeSql("DELETE FROM bleedings")
            tx.executeSql("DELETE FROM lunas")
            for (var table in TABLES) {
                var cols = TABLES[table]
                var sql = "INSERT INTO " + table + " (" + cols.join(", ") + ") VALUES ("
                        + cols.map(function () { return "?" }).join(", ") + ")"
                data[table].forEach(function (row) {
                    tx.executeSql(sql, cols.map(function (c) {
                        return row[c] === undefined ? null : row[c]
                    }))
                })
            }
        })
    } catch (e) {
        console.log("Import failed: " + e)
        return "db"
    }
    return ""
}

function _isNum(v) {
    return typeof v === "number" && isFinite(v)
}

function _isValid(data) {
    for (var table in TABLES) {
        if (!Array.isArray(data[table])) {
            return false
        }
    }
    var ok = data.lunas.every(function (l) {
        return l && _isNum(l.dbid) && typeof l.name === "string"
                && _isNum(l.cycle) && _isNum(l.day1ms) && _isNum(l.pms)
    })
    function isRecord(r) {
        return r && _isNum(r.dbid) && _isNum(r.lunaId) && _isNum(r.day)
    }
    return ok && data.bleedings.every(function (b) {
        return isRecord(b) && _isNum(b.intensity)
    }) && data.sexual_activity.every(isRecord)
}
