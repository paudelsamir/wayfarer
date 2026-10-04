import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "js/GeoProvider.js" as Geo
import "js/Goals.js" as Goals
import "components"

// MapPanel — the large floating map experience. The map is the interface:
// one near-black canvas, a whisper of a header, controls that reveal on
// hover, tooltip + detail card only when interacting.
Panel {
  id: root
  moduleName: "local.wayfarer"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var store: null

  // mode: map | setup | settings | (setup doubles as re-setup)
  property string mode: "map"
  property var features: []
  property string geoError: ""
  property string search: ""
  property string provinceFilter: ""
  property string hoverId: ""
  property point hoverPos: Qt.point(0, 0)
  property string selectedId: ""
  property bool chromeVisible: false

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function requestClose() {
    if (selectedId !== "") selectedId = ""
    else if (search !== "") search = ""
    else if (mode !== "map") mode = (store && store.setupDone) ? "map" : "setup"
    else close()
  }
  function toggle() { root.opened ? root.close() : root.open() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  readonly property var entry: Geo.entryFor(store ? store.country : "NP") || Geo.REGISTRY[0]
  readonly property string countryName: entry ? entry.name : "nepal"
  // Mist cools the map itself, not just the frame: unmistakable.
  readonly property bool misty: appearance === "mist"
  readonly property color mistShape: Theme.resolvedMode === "light" ? "#ccd2d4" : "#2c333b"
  readonly property color mistBorder: Theme.resolvedMode === "light" ? "#8b949d" : "#5f6b78"
  // Level words: Nepal groups districts into provinces; single-level
  // countries (US states, …) have no group at all.
  readonly property string unitWord: entry ? entry.unit : "district"
  readonly property string groupWord: (entry && entry.groupUnit) || ""

  // "Gandaki province · Jomsom, Marpha" or just "state".
  function subLineFor(feat) {
    if (!feat) return ""
    var extra = feat.highlights ? feat.highlights.slice(0, 3).join(", ") : unitWord
    if (groupWord !== "" && feat.provinceName)
      return feat.provinceName + " " + groupWord + " · " + extra
    return extra
  }
  readonly property string appearance: store ? (store.appearance || "atlas") : "atlas"
  readonly property bool splitMode: appearance === "survey" && mode === "map" && !useCustomList

  function syncTheme() {
    if (!store) return
    Theme.mode = store.themeMode || "auto"
    Theme.accentName = store.accent || "#6f9ab0"
  }

  Connections {
    target: store
    function onChanged() {
      // Geometry only changes with the country; visited toggles must not
      // re-fetch the pack (avoids flicker + wasted read per click).
      if ((store ? store.country : "NP") !== root._geoCountry) root.loadGeo()
      root.refreshMode()
      root.syncTheme()
    }
  }

  Component.onCompleted: { loadGeo(); refreshMode(); syncTheme() }

  property var summary: (store && store.goal && store.goal.type === "custom")
    ? Goals.customProgress(store.goal.places || [], store ? store.visitedCustom : ({}))
    : Goals.progress(features, store ? store.goal : null, store ? store.visited : ({}))

  readonly property bool useCustomList: !!(store && store.goal && store.goal.type === "custom")

  readonly property var scopeIds: {
    if (!store || !store.goal || store.goal.type === "country") return null
    if (store.goal.type === "regions") {
      var m = {}
      var r = store.goal.regions || []
      for (var i = 0; i < r.length; i++) m[r[i]] = true
      return m
    }
    return null
  }

  readonly property var effectiveScope: {
    if (provinceFilter === "") return scopeIds
    var m = {}
    for (var i = 0; i < features.length; i++) {
      var id = features[i].id
      if (features[i].provinceName === provinceFilter && (!scopeIds || scopeIds[id])) m[id] = true
    }
    return m
  }

  readonly property var provinces: {
    var seen = {}, out = []
    for (var i = 0; i < features.length; i++) {
      var p = features[i].provinceName || ""
      if (p && !seen[p]) { seen[p] = true; out.push(p) }
    }
    return out
  }

  function provinceStats(p) {
    var v = 0, t = 0
    var vv = store ? store.visited : {}
    for (var i = 0; i < features.length; i++) {
      if (features[i].provinceName !== p) continue
      t++
      if (vv[features[i].id]) v++
    }
    return { visited: v, total: t }
  }

  // Ids whose whole group is complete render deeper: finished land rests.
  readonly property var completeIds: {
    var m = {}
    var vv = store ? store.visited : {}
    var groups = {}
    for (var i = 0; i < features.length; i++) {
      var g = features[i].provinceName || ""
      if (!groups[g]) groups[g] = []
      groups[g].push(i)
    }
    for (var k in groups) {
      var all = true
      var idxs = groups[k]
      for (var j = 0; j < idxs.length; j++) {
        if (!vv[features[idxs[j]].id]) { all = false; break }
      }
      if (all) for (var q = 0; q < idxs.length; q++) m[features[idxs[q]].id] = true
    }
    return m
  }

  // Rail rows: per-group when the pack has groups, per-unit otherwise.
  readonly property bool railByGroup: provinces.length > 1
  readonly property var railRows: {
    if (railByGroup) return provinces
    var out = []
    for (var i = 0; i < features.length; i++) out.push(features[i].name)
    return out
  }
  function railDone(name) {
    var vv = store ? store.visited : {}
    if (railByGroup) {
      var st = provinceStats(name)
      return st.visited === st.total && st.total > 0
    }
    for (var i = 0; i < features.length; i++)
      if (features[i].name === name) return !!vv[features[i].id]
    return false
  }
  function railCount(name) {
    if (railByGroup) {
      var st = provinceStats(name)
      return st.visited + "/" + st.total
    }
    return railDone(name) ? "1/1" : "0/1"
  }
  function railActivate(name) {
    if (railByGroup) {
      provinceFilter = (provinceFilter === name) ? "" : name
      return
    }
    for (var i = 0; i < features.length; i++) {
      if (features[i].name === name) {
        selectedId = (selectedId === features[i].id) ? "" : String(features[i].id)
        return
      }
    }
  }
  function railActive(name) {
    if (railByGroup) return provinceFilter === name
    for (var i = 0; i < features.length; i++)
      if (features[i].name === name) return selectedId === features[i].id
    return false
  }

  readonly property var searchMatches: {
    if (search.trim() === "") return []
    var q = search.trim().toLowerCase()
    var out = []
    for (var i = 0; i < features.length && out.length < 7; i++)
      if (features[i].name.toLowerCase().indexOf(q) === 0 || features[i].name.toLowerCase().indexOf(q) > 0) out.push(features[i])
    return out
  }

  function refreshMode() {
    if (!store) return
    if (store.setupOpened) {
      store.setupOpened = false
      mode = "setup"
    } else if (!store.setupDone && !store.welcomed) {
      mode = "setup"
    } else if (mode === "setup" && store.setupDone) {
      mode = "map"
    }
  }

  function loadGeo() {
    var iso = store ? store.country : "NP"
    _geoCountry = iso
    geo.load(iso)
  }

  property string _geoCountry: ""

  GeoPack {
    id: geo
    onReady: {
      root.features = geo.features
      root.geoError = geo.error
      root.refreshMode()
    }
  }

  function featureById(id) {
    for (var i = 0; i < features.length; i++)
      if (String(features[i].id) === id) return features[i]
    return null
  }

  function maybeCelebrate() {
    if (summary.total > 0 && summary.pct === 100 && _lastPct !== 100 && _lastPct >= 0)
      confetti.burst()
    _lastPct = summary.pct
  }
  property int _lastPct: -1
  onSummaryChanged: root.maybeCelebrate()

  function fmtDate(ms) {
    if (!ms) return ""
    var d = new Date(ms)
    return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // A compact map popup anchored just below the bar widget.
    centerOnBar: false
    contentWidth: Math.min(760, (panel.screen ? panel.screen.width : 1600) - 120)
    contentHeight: Math.min(540, (panel.screen ? panel.screen.height : 900) - 160)

      PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchInput.activeFocus
      onCloseRequested: root.requestClose()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "/" && root.mode === "map" && !searchInput.activeFocus)
          searchInput.focusInput()
      }

      Rectangle {
        id: view
        anchors.fill: parent
        // The window's own background. In auto it matches the panel card
        // exactly (seamless, no box-in-box); in forced modes it carries
        // the curated palette so light mode is truly light.
        color: Theme.bg

        // — appearance world: one full treatment file per look.
        // Map mode only: treatments are composed for the map chrome and
        // would float arbitrarily over setup, settings or profile.
        Loader {
          id: appearanceLoader
          anchors.fill: parent
          visible: root.mode === "map"
          source: "appearances/" + (["atlas", "clean", "survey", "mist"].indexOf(root.appearance) >= 0 ? root.appearance : "atlas") + ".qml"
        }

        // ================= MAP MODE =================
        Item {
          anchors.fill: parent
          visible: root.mode === "map"

          CustomPlaces {
            anchors.fill: parent
            visible: root.useCustomList
            store: root.store
          }

          // — the canvas —
          MapCanvas {
            id: map
            visible: !root.useCustomList
            anchors.fill: parent
            anchors.topMargin: 64
            anchors.bottomMargin: 56
            anchors.leftMargin: 16
            anchors.rightMargin: root.splitMode ? 252 : 16
            features: root.features
            visited: store ? store.visited : ({})
            scopeIds: root.effectiveScope
            accent: Theme.accent
            dimColor: root.misty ? root.mistShape : Theme.mapShape
            borderColor: root.misty ? root.mistBorder : Theme.mapBorder
            hoverBorder: Theme.mapHoverBorder
            glow: 7
            mapOpacity: store ? store.mapOpacity : 1.0
            completeIds: root.completeIds
            selectedId: root.selectedId

            onHovered: function(id, x, y) {
              root.hoverId = id
              var p = map.mapToItem(view, x, y)
              root.hoverPos = Qt.point(p.x, p.y)
            }
            onUnhovered: root.hoverId = ""
            onClicked: function(id) {
              if (id === "") root.selectedId = ""
              else root.selectedId = (root.selectedId === id) ? "" : id
            }
          }

          // — header: always present, never shouting —
          Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 64

            // Hovering the header reveals the footer controls too.
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.NoButton
              hoverEnabled: true
              onEntered: root.chromeVisible = true
              onExited: root.chromeVisible = false
            }

            Row {
              anchors.left: parent.left
              anchors.leftMargin: 28
              anchors.verticalCenter: parent.verticalCenter
              spacing: Theme.s(9)

              // the wayfarer mark: an accent dot with a soft halo
              Item {
                width: Theme.s(14)
                height: Theme.s(14)
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                  anchors.centerIn: parent
                  width: Theme.s(14)
                  height: Theme.s(14)
                  radius: width / 2
                  color: Theme.alpha(Theme.accent, 0.22)
                  Behavior on color { ColorAnimation { duration: Theme.normal } }
                }
                Rectangle {
                  anchors.centerIn: parent
                  width: Theme.s(6)
                  height: Theme.s(6)
                  radius: width / 2
                  color: Theme.accent
                  Behavior on color { ColorAnimation { duration: Theme.normal } }
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.countryName + " · " + root.summary.visited + "/" + root.summary.total
                color: Theme.label
                font.family: Theme.font
                font.pixelSize: Theme.headline
              }
            }
            Text {
              anchors.right: parent.right
              anchors.rightMargin: 28
              anchors.verticalCenter: parent.verticalCenter
              text: map.zoom !== 1.0
                ? (Math.round(map.zoom * 100) + "% · double-click empty to reset")
                : (root.summary.pct + "% explored · " + root.summary.remaining + " remaining")
              color: map.zoom !== 1.0 ? Theme.accent : Theme.tertiary
              font.pixelSize: 12
              Behavior on color { ColorAnimation { duration: Theme.normal } }
            }

            // search — a quiet field, results drop below
            Field {
              id: searchInput
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              width: 210
              placeholder: "search  ( / )"
              text: root.search
              onTextChanged: root.search = text
              onEscaped: { root.search = ""; keyCatcher.forceActiveFocus() }
            }

            // search results: drop BELOW the header, over the map top —
            // never over chrome. Capped at five rows, scrolls within.
            Rectangle {
              visible: root.searchMatches.length > 0
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.bottom
              anchors.topMargin: 6
              width: 240
              height: Math.min(resultsFlick.contentHeight + 12, 5 * 28 + 12)
              radius: Theme.radiusControl
              color: Theme.bg
              border.color: Theme.separator
              border.width: 1
              clip: true
              z: 5
              Flickable {
                id: resultsFlick
                anchors.fill: parent
                anchors.margins: 6
                contentWidth: width
                contentHeight: resultsCol.height
                clip: true
                flickableDirection: Flickable.VerticalFlick
                Column {
                  id: resultsCol
                  width: parent.width
                  Repeater {
                    model: root.searchMatches
                  Rectangle {
                    width: parent.width
                    height: 28
                    radius: 3
                    color: rowHover.containsMouse ? Theme.fillStrong : "transparent"
                    Text {
                      anchors.left: parent.left
                      anchors.leftMargin: 8
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.name
                      color: Theme.label
                      font.pixelSize: 12
                    }
                    MouseArea {
                      id: rowHover
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.selectedId = String(modelData.id)
                        root.search = ""
                        searchInput.focus = false
                      }
                    }
                  }
                }
              }
            }
          }
          }

          // — footer: progress line + reveal-on-hover controls —
          Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 56

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.NoButton
              hoverEnabled: true
              onEntered: root.chromeVisible = true
              onExited: root.chromeVisible = false
            }

            Text {
              anchors.centerIn: parent
              visible: root.summary.total > 0 && root.summary.visited === root.summary.total
              text: "map complete · every " + (root.entry ? root.entry.unit : "district") + " visited"
              color: Theme.accent
              font.pixelSize: 11
              font.family: "monospace"
              Behavior on color { ColorAnimation { duration: Theme.normal } }
            }

            Row {
              anchors.right: parent.right
              anchors.rightMargin: 24
              anchors.verticalCenter: parent.verticalCenter
              spacing: 16
              opacity: root.chromeVisible ? 1.0 : 0.55
              Behavior on opacity { NumberAnimation { duration: Theme.normal } }

              Text {
                text: "profile"
                color: Theme.secondary
                font.pixelSize: 11
                font.family: Theme.font
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = "profile" }
              }
              Text {
                text: "reset"
                color: Theme.tertiary; font.pixelSize: 11
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = "settings" }
              }
              Text {
                text: "export"
                color: Theme.tertiary; font.pixelSize: 11
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = "settings" }
              }
              Text {
                text: "settings"
                color: Theme.secondary; font.pixelSize: 11
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = "settings" }
              }
            }

            // province filter pills (left, reveal on hover; hidden when pointless)
            Row {
              anchors.left: parent.left
              anchors.leftMargin: 24
              anchors.verticalCenter: parent.verticalCenter
              spacing: 6
              opacity: root.provinces.length > 1 ? (root.chromeVisible ? 1.0 : 0.55) : 0.0
              Behavior on opacity { NumberAnimation { duration: Theme.normal } }
              visible: opacity > 0
              Repeater {
                model: root.provinces
                Chip {
                  text: shortProv(modelData)
                  selected: root.provinceFilter === modelData
                  onClicked: root.provinceFilter = (root.provinceFilter === modelData) ? "" : modelData
                }
              }
            }
          }

          // — survey rail (appearance: survey) —
          Item {
            visible: root.splitMode
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 236
            anchors.topMargin: 64
            anchors.bottomMargin: 56
            anchors.rightMargin: 16

            Rectangle {
              anchors.fill: parent
              radius: Theme.radiusControl
              color: Theme.fill
            }

            Item {
              id: railBody
              anchors.fill: parent
              anchors.margins: Theme.pad

              property var feat: root.featureById(root.selectedId)

              Column {
                id: railHead
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Theme.s(6)

              Text {
                width: parent.width
                visible: !!railBody.feat
                text: railBody.feat ? railBody.feat.name : ""
                color: Theme.label
                font.family: Theme.serif
                font.pixelSize: 19
                wrapMode: Text.WordWrap
              }
              Item {
                width: parent.width
                height: 92
                visible: !railBody.feat
                Ring {
                  anchors.centerIn: parent
                  size: 88
                  lineWidth: 7
                  color: Theme.accent
                  value: root.summary.total > 0 ? root.summary.visited / root.summary.total : 0
                  Text {
                    anchors.centerIn: parent
                    text: root.summary.pct + "%"
                    color: Theme.label
                    font.family: Theme.serif
                    font.pixelSize: 20
                    font.italic: true
                  }
                }
              }
                Text {
                  width: parent.width
                  text: railBody.feat
                    ? root.subLineFor(railBody.feat)
                    : (root.countryName + " · " + root.summary.visited + "/" + root.summary.total)
                  color: Theme.secondary
                  font.family: railBody.feat ? Theme.font : "monospace"
                  font.pixelSize: Theme.footnote
                  wrapMode: Text.WordWrap
                }
                Text {
                  width: parent.width
                  visible: !railBody.feat
                  text: root.summary.remaining + " remaining"
                  color: Theme.tertiary
                  font.family: Theme.font
                  font.pixelSize: Theme.footnote
                }
                Text {
                  width: parent.width
                  visible: !!railBody.feat
                  text: railBody.feat && store && store.visited[railBody.feat.id]
                    ? ("visited · " + root.fmtDate(store.visited[railBody.feat.id])) : "unvisited"
                  color: railBody.feat && store && store.visited[railBody.feat.id] ? Theme.accent : Theme.tertiary
                  font.family: Theme.font
                  font.pixelSize: Theme.footnote
                }

                PillButton {
                  width: parent.width
                  visible: !!railBody.feat
                  text: {
                    var f = railBody.feat
                    var v = f && store ? !!store.visited[f.id] : false
                    return v ? "mark unvisited" : "mark visited"
                  }
                  primary: !(railBody.feat && store && store.visited[railBody.feat.id])
                  onClicked: {
                    if (railBody.feat) {
                      var w = store && store.visited[railBody.feat.id]
                      store.toggleVisited(railBody.feat.id)
                      if (!w) map.pulse(railBody.feat.id)
                    }
                  }
                }

                Rectangle { visible: !railBody.feat; width: parent.width; height: 1; color: Theme.separator }
              }

              // per-group progress fills the middle
              Flickable {
                visible: !railBody.feat
                anchors.top: railHead.bottom
                anchors.topMargin: Theme.s(8)
                anchors.bottom: railFoot.top
                anchors.bottomMargin: Theme.s(8)
                anchors.left: parent.left
                anchors.right: parent.right
                contentWidth: width
                contentHeight: provCol.height
                clip: true
                flickableDirection: Flickable.VerticalFlick
                Column {
                  id: provCol
                  width: parent.width
                  spacing: 2
                  Repeater {
                    model: root.railRows
                    Item {
                      width: provCol.width
                      height: Theme.rowHeight
                      Row {
                        anchors.fill: parent
                        spacing: Theme.s(8)
                        Rectangle {
                          width: Theme.s(6)
                          height: Theme.s(6)
                          radius: width / 2
                          anchors.verticalCenter: parent.verticalCenter
                          color: root.railDone(modelData) ? Theme.accent : Theme.quaternary
                          Behavior on color { ColorAnimation { duration: Theme.fast } }
                        }
                        Text {
                          width: parent.width - Theme.s(6) - Theme.s(8) - provCount.width - Theme.s(8)
                          text: modelData
                          color: root.railActive(modelData) ? Theme.label : Theme.secondary
                          font.family: Theme.font
                          font.pixelSize: Theme.callout
                          elide: Text.ElideRight
                          anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          id: provCount
                          text: root.railCount(modelData)
                          color: Theme.tertiary
                          font.family: "monospace"
                          font.pixelSize: Theme.caption
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.railActivate(modelData)
                      }
                    }
                  }
                }
              }

              Column {
                id: railFoot
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Theme.s(8)
                PillButton {
                  width: parent.width
                  visible: !railBody.feat
                  text: "settings"
                  primary: false
                  onClicked: root.mode = "settings"
                }
                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  visible: !railBody.feat
                  text: "change map…"
                  color: mapLink.containsMouse ? "#b07f6f" : Theme.alpha("#b07f6f", 0.6)
                  font.family: Theme.font
                  font.pixelSize: Theme.callout
                  font.weight: Font.DemiBold
                  Behavior on color { ColorAnimation { duration: Theme.fast } }
                  MouseArea {
                    id: mapLink
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: store.requestSetup()
                  }
                }
              }
            }
          }

          // — empty states —
          EmptyState {
            visible: !root.useCustomList && root.features.length === 0 && (root.geoError !== "" || !(root.entry && root.entry.ready))
            anchors.centerIn: parent
            width: Math.min(360, parent.width - 80)
            icon: "○"
            title: root.geoError !== "" ? root.geoError : noPackLine()
            hint: "pick another country in setup"
          }

          // celebration burst on 100%
          Confetti {
            id: confetti
            anchors.fill: parent
            z: 9
          }

          // — tooltip follows cursor —
          Tooltip {
            id: tip
            property var feat: root.featureById(root.hoverId)
            placeName: feat ? feat.name : ""
            subLine: root.subLineFor(feat)
            statusLine: feat ? ((store && store.visited[feat.id]) ? "visited · " + root.fmtDate(store.visited[feat.id]) : "unvisited · click to mark") : ""
            x: Math.min(view.width - width - 20, Math.max(20, root.hoverPos.x + 18))
            y: Math.min(view.height - height - 20, Math.max(20, root.hoverPos.y - 10))
            z: 10
          }

          // — detail card near selection —
          DetailCard {
            id: detail
            property var feat: root.featureById(root.selectedId)
            property var featStats: feat ? root.provinceStats(feat.provinceName) : ({ visited: 0, total: 0 })
            feature: feat
            isVisited: feat ? !!(store && store.visited[feat.id]) : false
            visitedOn: feat && store && store.visited[feat.id] ? root.fmtDate(store.visited[feat.id]) : ""
            provVisited: featStats.visited
            provTotal: featStats.total
            unit: root.entry ? root.entry.unit : "district"
            sub: root.subLineFor(feat)
            x: Math.min(view.width - width - 24, Math.max(24, detailAnchor.x))
            y: Math.min(view.height - height - 70, Math.max(70, detailAnchor.y))
            z: 11
            onToggle: {
              if (feat) {
                var was = store && store.visited[feat.id]
                store.toggleVisited(feat.id)
                if (!was) map.pulse(feat.id)
              }
            }
            onSaveDate: function(ms) {
              if (feat) store.setVisitedDate(feat.id, ms)
            }
            onDismiss: root.selectedId = ""
          }
          Item {
            id: detailAnchor
            property point c: root.selectedId !== "" ? map.centroidOfId(root.selectedId) : Qt.point(0, 0)
            x: map.x + c.x + 16
            y: map.y + c.y - 40
          }
        }

        // ================= SETUP MODE =================
        SetupView {
          anchors.fill: parent
          visible: root.mode === "setup"
          store: root.store
          onFinished: { root.mode = "map" }
        }

        // ================= SETTINGS MODE =================
        Item {
          anchors.fill: parent
          visible: root.mode === "settings"
          SettingsView {
            anchors.fill: parent
            store: root.store
            features: root.features
          }
          Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 18
            text: "← back to map"
            color: Theme.tertiary
            font.pixelSize: 12
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = "map" }
          }
        }

        // ================= PROFILE MODE =================
        ProfileView {
          anchors.fill: parent
          visible: root.mode === "profile"
          store: root.store
          features: root.features
          summary: root.summary
          provinces: root.provinces
          groupLabel: root.groupWord !== "" ? root.groupWord + "s" : ""
          unitLabel: root.unitWord + "s"
          onBack: root.mode = "map"
        }

        // (shortcuts live on keyCatcher above: Esc stages out, "/" searches)
      }
    }
  }

  function shortProv(name) {
    var parts = String(name).split(" ")
    if (parts.length > 1) return (parts[0][0] + parts[1][0]).toLowerCase()
    return String(name).slice(0, 3).toLowerCase()
  }

  function noPackLine() {
    if (!entry || !entry.ready)
      return "no boundary pack for " + countryName + " yet · add custom places in setup"
    return "loading boundaries…"
  }
}
