.pragma library
.import Sailfish.Silica 1.0 as Sl.import "Persistence.js" as Persistence

var intensities = ["spotting", "light", "medium", "haevy"]

function emptyBleedingInfo(lunaId) {
    return {
        "dbid": 0,
        "lunaId": lunaId,
        "day": Date.now(),
        "intensity": 3,
        "excluded": false
    }
}

function populate(lunaId, model, withExcluded) {
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT * FROM bleedings WHERE lunaId=?"
                               + (!withExcluded ? " AND NOT excluded" : ""),
                               [lunaId])
        for (var i = 0; i < rs.rows.length; i++) {
            model.append(rs.rows.item(i))
        }
    })
}

function get(lunaId, day, withExcluded) {
    var res = ""
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql(
                    "SELECT * FROM bleedings WHERE lunaId=? AND day=?",
                    [lunaId, day])
        if (rs.rows.length === 1) {
            res = rs.rows.item(0)
        }
    })
    return res
}

function persist(b) {
    var res = ""
    Persistence.database().transaction(function (tx) {
        var rs = tx.executeSql(
                    "INSERT INTO bleedings (lunaId, day, intensity, excluded) VALUES (?, ?, ?, ?)",
                    [b.lunaId, b.day, b.intensity, b.excluded])
        if (rs.rowsAffected !== 0) {
            res = rs.insertId
        }
    })
    return res
}

function update(b) {
    Persistence.database().transaction(function (tx) {
        tx.executeSql(
                    "UPDATE bleedings SET day=?, intensity=?, excluded=? WHERE dbid=?",
                    [b.day, b.intensity, b.excluded, b.dbid])
    })
}

function remove(b) {
    var res = ""
    Persistence.database().transaction(function (tx) {
        var rs = tx.executeSql("DELETE FROM bleedings WHERE dbid=?", [b.dbid])
        if (rs.rowsAffected === 1) {
            res = "OK"
        }
    })
    return res
}

function calculateLunaCycle(lunaId) {
    var res = ""
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql(" \
WITH cicle_days AS ( \
SELECT strftime('%s', day) as day, \
LAG(strftime('%s', day)) OVER (ORDER BY day) AS prev_day \
FROM bleedings \
WHERE lunaId = ? AND NOT excluded \
) \
SELECT \
day AS day1ms, \
(day - LAG(day) OVER (ORDER BY day)) / 86400 AS cycle \
FROM cicle_days \
WHERE prev_day IS NULL \
OR (day - prev_day) > 86400 \
ORDER BY day DESC", [lunaId])
        if (rs.row.length > 1) {
            var sum = 0
            // last row has no set cycle value. We must skip them
            for (var i = rs.row.length - 2; i >= 0; --i) {
                sum += rs.row.item(i)
            }
            var avg_cycle = sum / (rs.row.length - 2)

            res = {
                "day1ms": rs.row.item(0).day1ms,
                "cycle": avg_cycle
            }
        }
    })
    return res
}

function updateLunaCycle(lunaId) {
    var luna = luna(lunaId)
    var new_cycle = calculateLunaCycle(lunaId)
    if (!!new_cycle) {
        luna.cycle = new_cycle.cycle
        luna.day1ms = new_cycle.day1ms
        Persistence.updateLuna(luna)
    }
}
