.pragma library
.import Sailfish.Silica 1.0 as Sl

var PMS_COLOR = '#5d00e5'
var MN_COLOR = '#e60003'
var OV_COLOR = '#28a928'

var MN_DAYS = 5

var PMS_OFF = 4

var OV_DAYS = 7
var OV_DAYS_SPAN = 4
var OV_DAYS_BEFORE = 14

function todayMS() {
    return dateToUtcTimestamp(new Date())
}

// Days are stored as UTC-midnight timestamps of the *local* calendar date
function dateToUtcTimestamp(date) {
    var dt = new Date(date)
    return Date.UTC(dt.getFullYear(), dt.getMonth(), dt.getDate())
}

// Inverse of dateToUtcTimestamp: local-midnight Date for a stored day
function utcTimestampToDate(ms) {
    var dt = new Date(ms)
    return new Date(dt.getUTCFullYear(), dt.getUTCMonth(), dt.getUTCDate())
}

function daysInCycle(cycle, day1ms, curDayMS) {
    if (curDayMS === undefined) {
        curDayMS = todayMS()
    }
    //	console.log((curDayMS - day1ms) / 86400000, new Date(curDayMS))
    var d = (curDayMS - day1ms) / 86400000 % cycle | 0
    if (d < 0) {
        d = cycle + d
    }
    return d
}

function nextOvDays(daysInCycle, cycle) {
    var ds = cycle - OV_DAYS_BEFORE - 2
    var de = cycle - OV_DAYS_BEFORE
    if (daysInCycle < ds) {
        return ds - daysInCycle
    }
    if (daysInCycle > de) {
        return cycle + ds - daysInCycle
    }
    return 0 // make 3 days has 'today'
}

function nextMnDays(daysInCycle, cycle) {
    if (daysInCycle === 0) {
        return 0
    }
    return cycle - daysInCycle
}

function formatDays(d) {
    if (d === 0) {
        return qsTr("today")
    }
    if (d === 1) {
        return qsTr("tomorrow")
    }
    var dt = utcTimestampToDate(todayMS())
    dt.setDate(dt.getDate() + d)
    return Sl.Format.formatDate(dt, Sl.Formatter.DurationElapsed)
}
