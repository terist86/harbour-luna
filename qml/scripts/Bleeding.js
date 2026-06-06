.pragma library
.import "Luna.js" as Luna
.import "Persistence.js" as Persistence
.import "Algo.js" as Algo

var intensities = ["spotting", "light", "medium", "heavy"]

function emptyBleedingInfo(lunaId) {
    return {
        "dbid": 0,
        "lunaId": lunaId,
        "day": Date.now(),
        "intensity": 2,
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
        if (rs.rows.length > 1) {
            var sum = 0
            // last row has no set cycle value. We must skip them
            for (var i = rs.rows.length - 2; i >= 0; --i) {
                sum += rs.rows.item(i).cycle
            }
            var avg_cycle = sum / (rs.rows.length - 2)

            res = {
                "day1ms": rs.rows.item(0).day1ms,
                "cycle": avg_cycle
            }
        }
    })
    return res
}

function _getPeriodStarts(lunaId) {
    var starts = []
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql(
            "SELECT day FROM bleedings WHERE lunaId = ? AND NOT excluded ORDER BY day ASC",
            [lunaId])
        if (rs.rows.length === 0) return

        var candidates = [rs.rows.item(0).day]
        for (var i = 1; i < rs.rows.length; i++) {
            if (rs.rows.item(i).day - rs.rows.item(i - 1).day > 86400000) {
                candidates.push(rs.rows.item(i).day)
            }
        }

        starts.push(candidates[0])
        for (var i = 1; i < candidates.length; i++) {
            if (candidates[i] - starts[starts.length - 1] >= 7 * 86400000) {
                starts.push(candidates[i])
            }
        }
    })
    return starts.reverse()
}

function getActualDay1ms(lunaId) {
    var starts = _getPeriodStarts(lunaId)
    return starts.length > 0 ? starts[0] : ""
}

function autoFillMissingPeriodDays(lunaId, savedDay) {
    var luna = Luna.get(lunaId)
    if (!luna) return
    var day1ms = luna.day1ms
    if (!day1ms) return

    var starts = _getPeriodStarts(lunaId)
    if (starts.length === 0) return

    var refStart = null
    var refEnd = null
    for (var i = 0; i < starts.length; i++) {
        if (starts[i] < day1ms) {
            refStart = starts[i]
            refEnd = day1ms
            break
        }
    }
    if (refStart === null) {
        refStart = starts[0]
        refEnd = refStart + 365 * 86400000
    }

    var today = Algo.todayMS()

    Persistence.database().transaction(function (tx) {
        var rs = tx.executeSql(
            "SELECT day, intensity FROM bleedings WHERE lunaId=? AND day>=? AND day<? AND NOT excluded ORDER BY day ASC",
            [lunaId, refStart, refEnd])
        if (rs.rows.length === 0) return

        var lastDay = rs.rows.item(rs.rows.length - 1).day
        var refDuration = Math.floor((lastDay - refStart) / 86400000) + 1

        var fillEnd = savedDay !== undefined ? Math.min(savedDay, today) : today

        for (var offset = 0; offset < refDuration; offset++) {
            var currentDay = day1ms + offset * 86400000
            if (currentDay > fillEnd) break
            if (currentDay === savedDay) continue

            var exists = tx.executeSql(
                "SELECT dbid FROM bleedings WHERE lunaId=? AND day=?",
                [lunaId, currentDay])
            if (exists.rows.length > 0) continue

            var prevDay = refStart + offset * 86400000
            var ref = tx.executeSql(
                "SELECT intensity FROM bleedings WHERE lunaId=? AND day=?",
                [lunaId, prevDay])
            if (ref.rows.length === 1) {
                tx.executeSql(
                    "INSERT INTO bleedings (lunaId, day, intensity, excluded) VALUES (?, ?, ?, ?)",
                    [lunaId, currentDay, ref.rows.item(0).intensity, false])
            }
        }
    })

    var actualDay1ms = getActualDay1ms(lunaId)
    if (actualDay1ms !== "" && actualDay1ms !== luna.day1ms) {
        luna.day1ms = actualDay1ms
        Luna.update(luna)
    }
}

function updateLunaCycle(lunaId) {
    var _luna = Luna.get(lunaId)
    var new_cycle = calculateLunaCycle(lunaId)
    if (!!new_cycle) {
        _luna.cycle = new_cycle.cycle
        _luna.day1ms = new_cycle.day1ms
        Luna.update(_luna)
    }
}
