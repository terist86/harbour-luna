.pragma library
.import "Persistence.js" as Persistence

function populate(model) {
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT * FROM lunas ORDER BY name")
        for (var i = 0; i < rs.rows.length; i++) {
            model.append(rs.rows.item(i))
        }
    })
}

function get(lunaId) {
    var res = ""
    Persistence.database().readTransaction(function (tx) {
        res = "OK"
        var rs = tx.executeSql("SELECT * FROM lunas WHERE lunaId=?", [lunaId])
        if (rs.rows.length === 1) {
            res = rs.rows.item(0)
        } else {
            res = ""
        }
    })
    return res
}

function persist(g) {
    var res = ""
    Persistence.database().transaction(function (tx) {
        var rs = tx.executeSql(
                    "INSERT INTO lunas (name, cycle, day1ms, pms) VALUES (?, ?, ?, ?)",
                    [g.name, g.cycle, g.day1ms, g.pms])
        if (rs.rowsAffected === 0) {
            res = "Error"
        } else {
            res = rs.insertId
        }
    })
    return res
}

function update(g) {
    Persistence.database().transaction(function (tx) {
        tx.executeSql(
                    "UPDATE lunas SET name=?, cycle=?, day1ms=?, pms=? WHERE dbid=?",
                    [g.name, g.cycle, g.day1ms, g.pms, g.dbid])
    })
}

function remove(dbid) {
    var res = ""
    Persistence.database().transaction(function (tx) {
        res = "OK"
        var rs = tx.executeSql("DELETE FROM lunas WHERE dbid=?", [dbid])
        if (rs.rowsAffected === 0) {
            res = "Error"
        }
    })
    return res
}

function removeAll() {
    var res = ""
    Persistence.database().transaction(function (tx) {
        res = "OK"
        var rs = tx.executeSql("DELETE FROM lunas")
        if (rs.rowsAffected === 0) {
            res = "Error"
        }
    })
    return res
}
