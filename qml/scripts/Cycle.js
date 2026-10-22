.pragma library
.import "Algo.js" as Algo
.import "Bleeding.js" as Bleeding

// Cycle lengths the predictions accept; same range as the profile setting
var MIN_CYCLE = 21
var MAX_CYCLE = 45

// "± 1–2" for a standard deviation of 1.4, "± 1" for 1.0
function formatDeviation(sd) {
    var lo = Math.floor(sd)
    var hi = Math.ceil(sd)
    return "± " + (lo === hi ? String(lo) : lo + "–" + hi)
}

// Values derived from the recorded bleedings for profile g, as model properties.
// With enough completed cycles the average replaces the profile's cycle length.
function info(g, curDayMS) {
    var actualDay1ms = Bleeding.getActualDay1ms(g.dbid)
    var day1ms = actualDay1ms !== "" ? actualDay1ms : g.day1ms
    var stats = Bleeding.cycleStats(g.dbid)

    var cycle = g.cycle
    var cycleText = qsTr("%1 days").arg(g.cycle)
    if (stats.average !== null) {
        var avg = Math.round(stats.average)
        cycleText = qsTr("%1 days").arg(avg + " " + formatDeviation(stats.deviation))
        if (avg >= MIN_CYCLE && avg <= MAX_CYCLE) {
            cycle = avg
        }
    }

    var statsText = stats.count === 0
            ? qsTr("No completed cycles yet")
            : qsTr("Cycles: %1 · shortest %2 · longest %3 days")
              .arg(stats.count).arg(stats.shortest).arg(stats.longest)

    var daysInCycle = Algo.daysInCycle(cycle, day1ms, curDayMS)
    var ov = Algo.nextOvDays(daysInCycle, cycle)
    var mn = Algo.nextMnDays(daysInCycle, cycle)
    var today = Algo.formatDays(0)

    return {
        "actualDay1ms": actualDay1ms,
        "effectiveDay1ms": day1ms,
        "effectiveCycle": cycle,
        "cycleText": cycleText,
        "statsText": statsText,
        "dayInCycle": daysInCycle + 1,
        "nextOv": Algo.formatDays(ov),
        "coverOv": ov === 0 ? today : String(ov),
        "nextMn": Algo.formatDays(mn),
        "coverMn": mn === 0 ? today : String(mn)
    }
}
