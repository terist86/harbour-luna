.pragma library
.import "Luna.js" as Luna
.import "Persistence.js" as Persistence
.import "Algo.js" as Algo

var intensities = ["spotting", "light", "medium", "heavy"]

function emptyBleedingInfo(lunaId) {
    return {
        "dbid": 0,
        "lunaId": lunaId,
        "day": Algo.todayMS(),
        "intensity": 2,
        "excluded": false
    }
}

function get(lunaId, day) {
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

function getRange(lunaId, fromDay, toDay) {
    var res = []
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql(
                    "SELECT * FROM bleedings WHERE lunaId=? AND day>=? AND day<?",
                    [lunaId, fromDay, toDay])
        for (var i = 0; i < rs.rows.length; i++) {
            res.push(rs.rows.item(i))
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
    var res = starts.length > 0 ? starts[0] : ""
    return res
}

function autoFillMissingPeriodDays(lunaId, savedDay) {
    var luna = Luna.get(lunaId)
    if (!luna) return
    var day1ms = luna.day1ms
    if (!day1ms) {
        return
    }

    var starts = _getPeriodStarts(lunaId)
    if (starts.length === 0) {
        return
    }

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
        if (rs.rows.length === 0) {
            return
        }

        var lastDay = rs.rows.item(rs.rows.length - 1).day
        var refDuration = Math.floor((lastDay - refStart) / 86400000) + 1

        // Build intensity array with gap-filling from the reference period
        var refIntensity = []
        for (var r = 0; r < rs.rows.length; r++) {
            var row = rs.rows.item(r)
            var idx = Math.round((row.day - refStart) / 86400000)
            refIntensity[idx] = row.intensity
        }
        // Fill gaps: look back for last known intensity
        for (var d = 1; d < refDuration; d++) {
            if (refIntensity[d] === undefined) {
                for (var b = d - 1; b >= 0; b--) {
                    if (refIntensity[b] !== undefined) {
                        refIntensity[d] = refIntensity[b]
                        break
                    }
                }
            }
        }
        // Fill leading gaps: look forward for next known intensity
        for (var d = refDuration - 2; d >= 0; d--) {
            if (refIntensity[d] === undefined) {
                for (var f = d + 1; f < refDuration; f++) {
                    if (refIntensity[f] !== undefined) {
                        refIntensity[d] = refIntensity[f]
                        break
                    }
                }
            }
        }

        var fillEnd = savedDay !== undefined ? Math.min(savedDay, today) : today

        // When using next/current period as fallback, don't fill before refStart
        var fillStart = refStart > day1ms ? refStart : day1ms
        var startOffset = Math.round((fillStart - day1ms) / 86400000)

        for (var offset = startOffset; offset < refDuration; offset++) {
            var currentDay = day1ms + offset * 86400000
            if (currentDay > fillEnd) break
            if (currentDay === savedDay) continue

            var exists = tx.executeSql(
                "SELECT dbid FROM bleedings WHERE lunaId=? AND day=?",
                [lunaId, currentDay])
            if (exists.rows.length > 0) continue

            var intensity = refIntensity[offset - startOffset]
            if (intensity !== undefined) {
                tx.executeSql(
                    "INSERT INTO bleedings (lunaId, day, intensity, excluded) VALUES (?, ?, ?, ?)",
                    [lunaId, currentDay, intensity, false])
            }
        }
    })

    updateLunaCycle(lunaId)
}

function updateLunaCycle(lunaId) {
    var actualDay1ms = getActualDay1ms(lunaId)
    if (actualDay1ms === "") return

    var _luna = Luna.get(lunaId)
    if (!_luna) return

    if (_luna.day1ms !== actualDay1ms) {
        _luna.day1ms = actualDay1ms
        Luna.update(_luna)
    }
}
