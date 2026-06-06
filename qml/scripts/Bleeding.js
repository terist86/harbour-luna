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
    var starts = _getPeriodStarts(lunaId)
    if (starts.length < 2) {
        console.log("[DEBUG] calculateLunaCycle lunaId=" + lunaId + " starts.length=" + starts.length + " < 2, returning empty")
        return ""
    }

    var chronological = []
    for (var i = starts.length - 1; i >= 0; i--) {
        chronological.push(starts[i])
    }

    var intervals = []
    for (var i = 1; i < chronological.length; i++) {
        var interval = (chronological[i] - chronological[i - 1]) / 86400000
        intervals.push(interval)
    }

    // Filter outliers: only consider intervals between 20 and 45 days
    var filtered = []
    for (var i = 0; i < intervals.length; i++) {
        if (intervals[i] >= 20 && intervals[i] <= 45) {
            filtered.push(intervals[i])
        }
    }

    if (filtered.length === 0) {
        console.log("[DEBUG] calculateLunaCycle lunaId=" + lunaId + " no valid intervals (20-45d) after filtering, returning empty")
        return ""
    }

    var sum = 0
    for (var i = 0; i < filtered.length; i++) {
        sum += filtered[i]
    }
    var avgCycle = sum / filtered.length

    console.log("[DEBUG] calculateLunaCycle lunaId=" + lunaId + " chronological=[" + chronological.join(",") + "] intervals=[" + intervals.join(",") + "] filtered=[" + filtered.join(",") + "] avg=" + avgCycle + " day1ms=" + starts[0])

    return {
        "day1ms": starts[0],
        "cycle": avgCycle
    }
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
    console.log("[DEBUG] _getPeriodStarts lunaId=" + lunaId + " starts=" + JSON.stringify(starts))
    return starts.reverse()
}

function getActualDay1ms(lunaId) {
    var starts = _getPeriodStarts(lunaId)
    var res = starts.length > 0 ? starts[0] : ""
    console.log("[DEBUG] getActualDay1ms lunaId=" + lunaId + " starts=[" + starts.join(",") + "] return=" + res)
    return res
}

function autoFillMissingPeriodDays(lunaId, savedDay) {
    var luna = Luna.get(lunaId)
    if (!luna) return
    var day1ms = luna.day1ms
    if (!day1ms) {
        console.log("[DEBUG] autoFillMissingPeriodDays lunaId=" + lunaId + " no day1ms, skip")
        return
    }

    var starts = _getPeriodStarts(lunaId)
    if (starts.length === 0) {
        console.log("[DEBUG] autoFillMissingPeriodDays lunaId=" + lunaId + " no period starts, skip")
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
    console.log("[DEBUG] autoFillMissingPeriodDays lunaId=" + lunaId + " day1ms=" + day1ms + " savedDay=" + savedDay + " refStart=" + refStart + " refEnd=" + refEnd)

    var today = Algo.todayMS()

    Persistence.database().transaction(function (tx) {
        var rs = tx.executeSql(
            "SELECT day, intensity FROM bleedings WHERE lunaId=? AND day>=? AND day<? AND NOT excluded ORDER BY day ASC",
            [lunaId, refStart, refEnd])
        if (rs.rows.length === 0) {
            console.log("[DEBUG] autoFill: no ref period entries, skip")
            return
        }

        var lastDay = rs.rows.item(rs.rows.length - 1).day
        var refDuration = Math.floor((lastDay - refStart) / 86400000) + 1

        var fillEnd = savedDay !== undefined ? Math.min(savedDay, today) : today
        console.log("[DEBUG] autoFill: refDuration=" + refDuration + " fillEnd=" + fillEnd + " today=" + today)

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

            var prevDay = refStart + (offset - startOffset) * 86400000
            var ref = tx.executeSql(
                "SELECT intensity FROM bleedings WHERE lunaId=? AND day=?",
                [lunaId, prevDay])
            if (ref.rows.length === 1) {
                var intensity = ref.rows.item(0).intensity
                console.log("[DEBUG] autoFill: offset=" + offset + " fill day=" + currentDay + " (from ref day=" + prevDay + " intensity=" + intensity + ")")
                tx.executeSql(
                    "INSERT INTO bleedings (lunaId, day, intensity, excluded) VALUES (?, ?, ?, ?)",
                    [lunaId, currentDay, intensity, false])
            }
        }
    })

    console.log("[DEBUG] autoFill: calling updateLunaCycle for lunaId=" + lunaId)
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
        console.log("[DEBUG] updateLunaCycle lunaId=" + lunaId + " updated day1ms to " + actualDay1ms)
    }
}
