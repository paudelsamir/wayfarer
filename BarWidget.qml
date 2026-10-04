import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "js/GeoProvider.js" as Geo
import "js/Goals.js" as Goals
import "components"

// BarWidget — the compact end of wayfarer. A whisper of text:
// "36/77", "nepal · 36/77", or "47%". Left-click opens the map.
BarWidget {
  id: root
  moduleName: "local.wayfarer"

  property Store store: Store { id: storeInstance }

  property var features: []
  property var summary: (store.goal && store.goal.type === "custom")
    ? Goals.customProgress(store.goal.places || [], store.visitedCustom)
    : Goals.progress(features, store.goal, store.visited)

  readonly property var entry: Geo.entryFor(store.country) || Geo.REGISTRY[0]
  readonly property string countryName: entry ? entry.name : "nepal"

  readonly property string barText: {
    if (!store.loaded) return "···"
    if (!store.setupDone && !store.welcomed) return "wayfarer"
    var s = summary
    var mode = store.barMode || "count"
    if (mode === "pct") return s.pct + "%"
    var core = s.visited + "/" + s.total
    if (mode === "place") return countryName + " · " + core
    if (s.total === 0) return countryName + " · " + s.visited
    return core
  }

  readonly property string tooltip: {
    if (!store.setupDone && !store.welcomed) return "wayfarer · click to set up your map"
    var s = summary
    return countryName + " · " + s.visited + "/" + s.total + "\n" + s.pct + "% explored · " + s.remaining + " remaining"
  }

  property string _geoCountry: ""

  GeoPack {
    id: geo
    onReady: { root.features = geo.features }
  }

  function loadGeo() {
    _geoCountry = store.country
    geo.load(store.country)
  }

  Connections {
    target: store
    function onChanged() {
      if (store.country !== root._geoCountry) root.loadGeo()
      Theme.mode = store.themeMode || "auto"
      Theme.accentName = store.accent || "#6f9ab0"
    }
  }
  Component.onCompleted: {
    loadGeo()
    Theme.mode = store.themeMode || "auto"
    Theme.accentName = store.accent || "#6f9ab0"
  }

  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  readonly property real _sideGap: Style.space(6)
  implicitWidth: content.implicitWidth + _sideGap * 2
  implicitHeight: root.bar ? root.bar.barSize : content.implicitHeight

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("MapPanel.qml")
    visible: false
    onLoaded: inject()
  }

  function inject() {
    if (panelLoader.item) {
      panelLoader.item.bar = root.bar
      panelLoader.item.anchorItem = button
      panelLoader.item.hostWidget = root
      panelLoader.item.store = root.store
    }
  }
  onBarChanged: inject()

  readonly property string flagFile: {
    if (!entry || !entry.iso2) return ""
    return Qt.resolvedUrl("data/flags/" + String(entry.iso2).toLowerCase() + ".png")
  }
  property bool flagBroken: false
  onFlagFileChanged: flagBroken = false

  // Icon follows the iconMode setting, always. The text never
  // contains the icon, so the two can never double up.
  readonly property string iconKind: {
    if ((store.iconMode || "flag") === "none") return ""
    return root.flagFile !== "" && !root.flagBroken ? "flag" : ""
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(6)

    Image {
      source: root.flagFile
      visible: root.iconKind === "flag"
      width: Math.round(18 * (store.flagSize || 1))
      height: Math.round(13 * (store.flagSize || 1))
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
      anchors.verticalCenter: parent.verticalCenter
      onStatusChanged: if (status === Image.Error) root.flagBroken = true
    }
    Text {
      text: "◦"
      visible: store.setupDone && summary.total > 0 && summary.visited === summary.total
      color: Theme.accent
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: root.barText
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    keepSpace: true
    text: "​"
    tooltipText: root.tooltip
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.RightButton) {
        if (panelLoader.item) {
          panelLoader.item.mode = "settings"
          panelLoader.item.open()
        }
      }
    }
  }
}
