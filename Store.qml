import QtQuick
import Quickshell
import Quickshell.Io

// Store — the single owner of wayfarer state.
//
//   settings: country, goal, accent, bar/UX prefs (see defaultState)
//   visited:  { featureId: epochMs }   visitedCustom: { placeId: epochMs }
//
// Everything lives in one JSON file under $XDG_STATE_HOME/wayfarer/,
// read once at startup, rewritten (debounced) on every mutation.
// Panels never touch the file directly; they call set()/toggleVisited()
// and bind to the derived `summary` property.
QtObject {
  id: store

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/wayfarer"
  readonly property string statePath: stateDir + "/state.json"

  property bool loaded: false
  property bool setupDone: false
  property bool welcomed: false
  property bool setupOpened: false

  property string country: "NP"
  property var goal: ({ type: "country", regions: [], places: [] })
  property var visited: ({})
  property var visitedCustom: ({})
  // Per-country buckets: every mark ever made, keyed by country ISO.
  // `visited` always mirrors the ACTIVE country's bucket, so every
  // existing view keeps working unchanged while all countries persist.
  property var visitedByCountry: ({})
  property string accent: "#6f9ab0"
  property string themeMode: "auto"  // auto | dark | light
  property string appearance: "atlas" // atlas | clean | survey | mist
  property real mapOpacity: 1.0
  property string iconMode: "flag"  // flag | none
  property real flagSize: 1.0
  property string travelerName: ""
  property string avatarPath: ""
  property string barMode: "count"      // count | place | pct
  property bool dimUnvisited: true
  property string mapLevel: "district"

  signal changed()

  function defaults() {
    return {
      version: 1, setupDone: false, welcomed: false, country: "NP",
      goal: { type: "country", regions: [], places: [] },
      visited: {}, visitedCustom: {},
      accent: "#6f9ab0", themeMode: "auto", appearance: "atlas", mapOpacity: 1.0, iconMode: "flag", flagSize: 1.0, travelerName: "", avatarPath: "", barMode: "count", mapLevel: "district"
    }
  }

  function applyState(s) {
    setupDone = s.setupDone === true
    welcomed = s.welcomed === true || s.setupDone === true
    country = s.country || "NP"
    goal = s.goal || { type: "country", regions: [], places: [] }
    // Buckets first; the active bucket becomes `visited`. Legacy flat
    // files (no buckets) attribute everything to the stored country.
    visitedByCountry = s.visitedByCountry || {}
    if (!s.visitedByCountry && s.visited && Object.keys(s.visited).length) {
      var b0 = {}
      b0[country] = s.visited
      visitedByCountry = b0
    }
    visited = visitedByCountry[country] || {}
    visitedCustom = s.visitedCustom || {}
    accent = s.accent || "#6f9ab0"
    themeMode = s.themeMode || "auto"
    appearance = ({ classic: "atlas", tahoe: "clean", glacier: "clean", split: "survey", frosted: "mist", glow: "atlas", ember: "atlas",
      atlas: "atlas", clean: "clean", survey: "survey", mist: "mist" })[s.appearance] || "atlas"
    mapOpacity = s.mapOpacity === undefined ? 1.0 : Math.max(0.3, Math.min(1.0, Number(s.mapOpacity)))
    flagSize = s.flagSize === undefined ? 1.0 : Math.max(0.7, Math.min(1.6, Number(s.flagSize)))
    travelerName = s.travelerName || ""
    // Every traveler gets a goofy bundled face, assigned once at random.
    // A previously chosen custom picture is kept as-is.
    avatarPath = s.avatarPath || ("../data/avatars/av" + (1 + Math.floor(Math.random() * 5)) + ".png")
    if (s.iconMode === "none") iconMode = "none"
    else iconMode = "flag"
    barMode = ({ count: "count", place: "place", pct: "pct", "country-count": "place",
      logo: "count", full: "place" })[s.barMode] || "count"
    if ((s.barMode === "logo" || s.barMode === "full") && !s.iconMode) iconMode = "flag"
    mapLevel = s.mapLevel || "district"
    loaded = true
    changed()
  }

  function snapshot() {
    flushCountry()
    return {
      version: 1, setupDone: setupDone, welcomed: welcomed, country: country, goal: goal,
      visited: visited, visitedByCountry: visitedByCountry, visitedCustom: visitedCustom,
      accent: accent, themeMode: themeMode, appearance: appearance, mapOpacity: mapOpacity, iconMode: iconMode, flagSize: flagSize, travelerName: travelerName, avatarPath: avatarPath, barMode: barMode, mapLevel: mapLevel
    }
  }

  // Keep the active bucket in sync before any read or write of buckets.
  // Idempotent: assigns only on real difference, so bindings that call
  // footprintIsos() can never loop.
  function flushCountry() {
    var cur = visitedByCountry[country]
    if (cur) {
      var ka = Object.keys(visited), kb = Object.keys(cur)
      if (ka.length === kb.length) {
        var same = true
        for (var i = 0; i < ka.length; i++) {
          if (cur[ka[i]] !== visited[ka[i]]) { same = false; break }
        }
        if (same) return
      }
    }
    var b = Object.assign({}, visitedByCountry)
    b[country] = visited
    visitedByCountry = b
  }

  // Every country holding at least one mark, current country first.
  // Pure read: every mutation flushes buckets first, so this never
  // writes and can never loop, however often bindings evaluate it.
  function footprintIsos() {
    var out = [country]
    for (var k in visitedByCountry) {
      if (k !== country && visitedByCountry[k] && Object.keys(visitedByCountry[k]).length) out.push(k)
    }
    return out
  }

  // --- mutations ---------------------------------------------------------

  function toggleVisited(id) {
    var v = Object.assign({}, visited)
    if (v[id]) delete v[id]
    else v[id] = Date.now()
    visited = v
    flushCountry()
    changed()
    saveSoon()
  }

  function setVisited(id, on) {
    var v = Object.assign({}, visited)
    if (on) v[id] = v[id] || Date.now()
    else delete v[id]
    visited = v
    flushCountry()
    changed()
    saveSoon()
  }

  function setVisitedDate(id, ms) {
    if (!visited[id]) return
    var v = Object.assign({}, visited)
    v[id] = ms
    visited = v
    flushCountry()
    changed()
    saveSoon()
  }

  function clearVisited() {
    visited = {}
    visitedCustom = {}
    flushCountry()
    changed()
    saveSoon()
  }

  function toggleCustom(id) {
    var v = Object.assign({}, visitedCustom)
    if (v[id]) delete v[id]
    else v[id] = Date.now()
    visitedCustom = v
    changed()
    saveSoon()
  }

  function set(patch) {
    // Country switch first: stash the old bucket, load the new one, so
    // every country's marks survive switching and the views (which only
    // ever read `visited`) keep working untouched.
    if (patch.country !== undefined && patch.country !== country) {
      flushCountry()
      country = patch.country
      visited = (visitedByCountry[country] || {})
      flushCountry()
    }
    for (var k in patch) {
      if (k === "goal") goal = patch[k]
      else if (k === "country") country = patch[k]
      else if (k === "accent") accent = patch[k]
      else if (k === "themeMode") themeMode = patch[k]
      else if (k === "appearance") appearance = patch[k]
      else if (k === "mapOpacity") mapOpacity = Math.max(0.3, Math.min(1.0, Number(patch[k])))
      else if (k === "iconMode") iconMode = patch[k] === "none" ? "none" : "flag"
      else if (k === "flagSize") flagSize = Math.max(0.7, Math.min(1.6, Number(patch[k])))
      else if (k === "travelerName") travelerName = String(patch[k] || "")
      else if (k === "avatarPath") avatarPath = String(patch[k] || "")
      else if (k === "barMode") barMode = ({ count: "count", place: "place", pct: "pct" })[patch[k]] || "count"
      else if (k === "mapLevel") mapLevel = patch[k]
      else if (k === "setupDone") setupDone = patch[k]
      else if (k === "welcomed") welcomed = patch[k]
    }
    changed()
    saveSoon()
  }

  function requestSetup() {
    setupOpened = true
    setupDone = false
    changed()
    saveSoon()
  }

  function importJson(text) {
    var doc = JSON.parse(text)
    var s = doc.state ? doc.state : doc
    applyState(Object.assign(defaults(), s))
    saveSoon()
  }

  // --- friendly file backup ------------------------------------------------

  property string lastIo: ""
  property bool lastIoOk: true
  property string lastExportPath: ""

  function defaultExportPath() {
    var d = new Date()
    function p(n) { return ("0" + n).slice(-2) }
    return home + "/wayfarer-backup-" + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate())
      + "-" + p(d.getHours()) + p(d.getMinutes()) + ".json"
  }

  property FileView exportView: FileView { watchChanges: false }
  property Timer exportTimer: Timer {
    interval: 120
    repeat: false
    onTriggered: {
      exportView.setText(store.exportJson())
      var parts = store.lastExportPath.split("/")
      store.lastIo = "saved · " + parts[parts.length - 1]
      store.lastIoOk = true
    }
  }

  function exportToFile(path) {
    lastExportPath = path
    lastIo = ""
    exportView.path = "file://" + path
    exportTimer.restart()
  }

  property FileView importView: FileView {
    watchChanges: false
    onLoaded: {
      try {
        store.importJson(text())
        store.lastIo = "imported · welcome back"
        store.lastIoOk = true
      } catch (e) {
        store.lastIo = "that file did not parse"
        store.lastIoOk = false
      }
    }
    onLoadFailed: function(err) {
      store.lastIo = "could not read that file"
      store.lastIoOk = false
    }
  }

  function importFromFile(url) {
    lastIo = ""
    importView.path = ""
    importView.path = url
  }

  function exportJson() {
    return JSON.stringify({ app: "wayfarer", exportedAt: new Date().toISOString(), state: snapshot() }, null, 2)
  }

  // --- persistence -------------------------------------------------------

  property Timer _saver: Timer {
    interval: 400
    repeat: false
    onTriggered: writeFile()
  }
  function saveSoon() { _saver.restart() }

  function writeFile() {
    ensureDirProc.running = true
    fileView.setText(JSON.stringify(snapshot()))
  }

  property Process ensureDirProc: Process {
    command: ["mkdir", "-p", store.stateDir]
  }

  property FileView fileView: FileView {
    path: Qt.resolvedUrl("file://" + store.statePath)
    watchChanges: false
    onLoaded: {
      try {
        var doc = JSON.parse(text())
        store.applyState(Object.assign(store.defaults(), doc))
      } catch (e) {
        store.applyState(store.defaults())
      }
    }
    onLoadFailed: function(error) {
      // Fresh install — start from defaults and persist them.
      store.applyState(store.defaults())
      store.writeFile()
    }
  }

  function load() {
    ensureDirProc.running = true
    fileView.reload()
  }

  Component.onCompleted: load()
}
