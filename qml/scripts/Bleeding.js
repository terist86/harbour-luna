.pragma library
.import "Luna.js" as Luna
.import "Persistence.js" as Persistence
.import "Algo.js" as Algo

var intensities = [qsTr("spotting"), qsTr("light"), qsTr("medium"), qsTr("heavy")]

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

var DAY_MS = 86400000
// Bleeding within this many days of a period start belongs to that period
var PERIOD_WINDOW_DAYS = 7

// Groups the non-excluded bleedings into periods, oldest first:
// [{ start, end, days: [{ day, intensity }] }]
// Days with at most one missing day between them form a run. A run with real
// bleeding starts a new period unless it lies within the window of the previous
// period's start. Runs of spotting only extend a period within that window but
// never start one, so mid-cycle spotting does not restart the cycle.
function _getPeriods(lunaId) {
    var rows = []
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql(
            "SELECT day, intensity FROM bleedings WHERE lunaId = ? AND NOT excluded ORDER BY day ASC",
            [lunaId])
        for (var i = 0; i < rs.rows.length; i++) {
            rows.push({ "day": rs.rows.item(i).day, "intensity": rs.rows.item(i).intensity })
        }
    })

    var runs = []
    rows.forEach(function (r) {
        var run = runs[runs.length - 1]
        if (run && r.day - run[run.length - 1].day <= 2 * DAY_MS) {
            run.push(r)
        } else {
            runs.push([r])
        }
    })

    var periods = []
    runs.forEach(function (run) {
        var last = periods[periods.length - 1]
        if (last && run[0].day - last.start < PERIOD_WINDOW_DAYS * DAY_MS) {
            last.days = last.days.concat(run)
            last.end = run[run.length - 1].day
        } else if (run.some(function (r) { return r.intensity > 0 })) {
            periods.push({ "start": run[0].day, "end": run[run.length - 1].day, "days": run })
        }
    })
    return periods
}

function getActualDay1ms(lunaId) {
    var periods = _getPeriods(lunaId)
    return periods.length > 0 ? periods[periods.length - 1].start : ""
}

// Intensity per day offset of a period; missing days take the previous
// known intensity (or the next one for leading gaps)
function _intensityPattern(period) {
    var duration = Math.round((period.end - period.start) / DAY_MS) + 1
    var pattern = []
    period.days.forEach(function (r) {
        pattern[Math.round((r.day - period.start) / DAY_MS)] = r.intensity
    })
    var known
    for (var d = 0; d < duration; d++) {
        if (pattern[d] === undefined) pattern[d] = known
        else known = pattern[d]
    }
    for (d = duration - 1; d >= 0; d--) {
        if (pattern[d] === undefined) pattern[d] = known
        else known = pattern[d]
    }
    return pattern
}

// Fills the missing days of the period that savedDay belongs to, between its
// first and last logged day. The previous period serves as the reference for
// length and intensities; without one the period's own pattern is used.
// Days outside that period are never touched.
function autoFillMissingPeriodDays(lunaId, savedDay) {
    var periods = _getPeriods(lunaId)
    var idx = -1
    for (var i = 0; i < periods.length; i++) {
        if (periods[i].start <= savedDay && savedDay <= periods[i].end) {
            idx = i
            break
        }
    }

    if (idx >= 0) {
        var cur = periods[idx]
        var ref = idx > 0 ? periods[idx - 1] : cur
        var pattern = _intensityPattern(ref)

        Persistence.database().transaction(function (tx) {
            for (var day = cur.start + DAY_MS; day < cur.end; day += DAY_MS) {
                var intensity = pattern[Math.round((day - cur.start) / DAY_MS)]
                if (intensity === undefined) break
                var exists = tx.executeSql(
                    "SELECT dbid FROM bleedings WHERE lunaId=? AND day=?",
                    [lunaId, day])
                if (exists.rows.length > 0) continue
                tx.executeSql(
                    "INSERT INTO bleedings (lunaId, day, intensity, excluded) VALUES (?, ?, ?, ?)",
                    [lunaId, day, intensity, false])
            }
        })
    }

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
