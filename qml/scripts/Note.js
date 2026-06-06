.pragma library
.import "Persistence.js" as Persistence

function emptyNoteInfo(lunaId, idx) {
    return {
        "title": "",
        "note": "",
        "dbid": 0,
        "lunaId": lunaId,
        "idx": idx
    }
}
function populate(model, lunaId) {
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT * FROM notes WHERE lunaId = ?", [lunaId])
        for (var i = 0; i < rs.rows.length; i++) {
            var row = rs.rows.item(i)
            if (model.count > row.idx) {
                model.set(row.idx, row)
            }
        }
    })
}

function icons(iconArr, lunaId) {
    Persistence.database().readTransaction(function (tx) {
        var rs = tx.executeSql("SELECT idx, icon FROM notes WHERE lunaId=?",
            [lunaId])
        for (var i = 0; i < rs.rows.length; i++) {
            var row = rs.rows.item(i)
            if (iconArr.length > row.idx) {
                iconArr[row.idx] = row.icon
            }
        }
    })
}

function title(lunaId, idx) {
    var res = ""
    Persistence.database().readTransaction(function (tx) {
        res = "OK"
        var rs = tx.executeSql(
            "SELECT title FROM notes WHERE lunaId=? AND idx=?",
            [lunaId, idx])
        if (rs.rows.length === 1) {
            res = rs.rows.item(0).title
        } else {
            res = ""
        }
    })
    return res
}

function get(lunaId, idx) {
    var res = ""
    Persistence.database().readTransaction(function (tx) {
        res = "OK"
        var rs = tx.executeSql("SELECT * FROM notes WHERE lunaId=? AND idx=?",
            [lunaId, idx])
        if (rs.rows.length === 1) {
            res = rs.rows.item(0)
        } else {
            res = ""
        }
    })
    return res
}

function persist(n) {
    var res = ""
    Persistence.database().transaction(function (tx) {
        var rs = tx.executeSql(
            "INSERT INTO notes (title, note, icon, lunaId, idx) VALUES (?, ?, ?, ?, ?)",
            [n.title, n.note, n.icon, n.lunaId, n.idx])
        if (rs.rowsAffected === 0) {
            res = "Error"
        } else {
            res = rs.insertId
        }
    })
    return res
}

function update(n) {
    Persistence.database().transaction(function (tx) {
        tx.executeSql("UPDATE notes SET title=?, note=?, icon=? WHERE dbid=?",
            [n.title, n.note, n.icon, n.dbid])
    })
}

function remove(dbid) {
    var res = ""
    Persistence.database().transaction(function (tx) {
        res = "OK"
        var rs = tx.executeSql("DELETE FROM notes WHERE dbid=?", [dbid])
        if (rs.rowsAffected === 0) {
            res = "Error"
        }
    })
    return res
}

function removeAll(lunaId) {
    var res = ""
    Persistence.database().transaction(function (tx) {
        res = "OK"
        var rs = tx.executeSql("DELETE FROM notes WHERE lunaId=?", [lunaId])
        if (rs.rowsAffected === 0) {
            res = "Error"
        }
    })
    return res
}
