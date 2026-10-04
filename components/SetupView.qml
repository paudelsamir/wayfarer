import QtQuick
import "../js/GeoProvider.js" as Geo
import "../js/LocationDetect.js" as Detect

// Setup: three quiet steps — home, goal, begin. Chips pick, fields filter.
Item {
  id: root
  property var store: null
  signal finished()

  property string detectedIso: ""
  property bool detecting: false
  property string detectError: ""
  property string pickedIso: "NP"
  property string goalType: "country"
  property var pickedRegions: ({})
  property var pickedUnitIds: ({})
  property string customText: ""
  property string countryFilter: ""

  Component.onCompleted: { pickedIso = (store && store.country) || "NP"; loadPack() }
  onPickedIsoChanged: { pickedRegions = {}; pickedUnitIds = {}; loadPack() }

  property var packFeatures: []

  readonly property var pickedEntry: Geo.entryFor(pickedIso) || Geo.REGISTRY[0]
  readonly property string pickedUnit: pickedEntry ? pickedEntry.unit : "district"
  readonly property int pickedTotal: packFeatures.length > 0 ? packFeatures.length : (pickedEntry ? pickedEntry.total : 0)

  readonly property var filteredCountries: {
    var q = countryFilter.trim().toLowerCase()
    if (q === "") return []
    return Geo.REGISTRY.filter(function(e) {
      return e.name.toLowerCase().indexOf(q) >= 0 || e.iso.toLowerCase().indexOf(q) === 0
    })
  }

  readonly property var featuredEntries: {
    var out = []
    for (var i = 0; i < Geo.FEATURED.length; i++) {
      var e = Geo.entryFor(Geo.FEATURED[i])
      if (e) out.push(e)
    }
    return out
  }

  GeoPack {
    id: geo
    onReady: {
      if (root.pickedIso === geo.iso) root.packFeatures = geo.features
    }
  }

  function loadPack() { geo.load(pickedIso) }

  readonly property var packProvinces: {
    var seen = {}, out = []
    for (var i = 0; i < packFeatures.length; i++) {
      var p = packFeatures[i].provinceName || ""
      if (p && !seen[p]) { seen[p] = true; out.push(p) }
    }
    return out
  }

  readonly property bool pickByGroup: packProvinces.length > 1

  function provinceCount(p) {
    var n = 0
    for (var i = 0; i < packFeatures.length; i++)
      if (packFeatures[i].provinceName === p) n++
    return n
  }

  function toggleGroup(p) {
    var m = Object.assign({}, pickedRegions)
    if (m[p]) delete m[p]
    else m[p] = true
    pickedRegions = m
  }

  function toggleUnit(id) {
    var m = Object.assign({}, pickedUnitIds)
    if (m[id]) delete m[id]
    else m[id] = true
    pickedUnitIds = m
  }

  function regionCount() {
    return Object.keys(pickedRegions).length + Object.keys(pickedUnitIds).length
  }

  function startDetect() {
    detecting = true
    detectError = ""
    Detect.detectCountry(function(iso2) {
      detecting = false
      if (iso2) {
        detectedIso = iso2
        var e = Geo.entryForIso2(iso2)
        if (e) pickedIso = e.iso
        else detectError = "detected " + iso2 + " · not in the atlas yet, pick below"
      } else {
        detectError = "could not detect location · pick below"
      }
    })
    guard.restart()
  }

  Timer {
    id: guard
    interval: 15000
    repeat: false
    onTriggered: {
      if (root.detecting) {
        root.detecting = false
        root.detectError = "detection timed out · pick below"
      }
    }
  }

  function begin() {
    var regions = []
    if (goalType === "regions") {
      for (var i = 0; i < packFeatures.length; i++) {
        var f = packFeatures[i]
        if (pickedRegions[f.provinceName] || pickedUnitIds[f.id]) regions.push(f.id)
      }
    }
    var places = []
    if (goalType === "custom") {
      var parts = customText.split("\n")
      for (var i = 0; i < parts.length; i++) {
        var t = parts[i].trim()
        if (t) places.push({ id: "custom-" + i + "-" + t.toLowerCase().replace(/[^a-z0-9]+/g, "-"), name: t })
      }
    }
    store.set({
      country: pickedIso,
      goal: goalType === "country"
        ? { type: "country", regions: [], places: [] }
        : goalType === "regions"
          ? { type: "regions", regions: regions, places: [] }
          : { type: "custom", regions: [], places: places },
      setupDone: true,
      welcomed: true
    })
    finished()
  }

  readonly property bool canBegin: goalType === "country"
    || (goalType === "regions" && regionCount() > 0)
    || goalType === "custom"

  readonly property string wholeHint: packFeatures.length > 0
    ? ("all " + packFeatures.length + " " + pickedUnit + (packFeatures.length === 1 ? "" : "s"))
    : (pickedEntry ? ("all " + pickedEntry.total + " " + pickedEntry.unit + "s") : "")

  Flickable {
    anchors.fill: parent
    anchors.leftMargin: Theme.s(40)
    anchors.rightMargin: Theme.s(40)
    anchors.topMargin: Theme.s(24)
    anchors.bottomMargin: Theme.s(24)
    contentWidth: width
    contentHeight: col.height
    clip: true
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: col
      width: parent.width - 80
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Theme.s(16)

      Item { width: 1; height: Theme.s(24) }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "wayfarer"
        color: Theme.label
        font.family: Theme.serif
        font.pixelSize: 32
        font.italic: true
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "slowly complete the map of your life"
        color: Theme.tertiary
        font.family: Theme.font
        font.pixelSize: Theme.body
      }

      Rectangle { width: parent.width; height: 1; color: Theme.separator }

      SectionHeader { text: "where is home"; trailing: "01" }
      Row {
        spacing: Theme.gap
        width: parent.width
        PillButton {
          text: root.detecting ? "detecting…" : (root.detectedIso !== "" ? "detected · " + root.detectedIso : "detect my country")
          primary: false
          onClicked: root.startDetect()
        }
        Text {
          visible: root.detectError !== ""
          width: parent.width - 170
          text: root.detectError
          color: Theme.tertiary
          font.family: Theme.font
          font.pixelSize: Theme.footnote
          wrapMode: Text.WordWrap
          anchors.verticalCenter: parent.verticalCenter
        }
      }
      Field {
        width: parent.width
        placeholder: "search 198 countries…"
        text: root.countryFilter
        onTextChanged: root.countryFilter = text
      }
      Text {
        width: parent.width
        text: "choose"
        color: Theme.tertiary
        font.family: Theme.font
        font.pixelSize: Theme.footnote
      }
      Flow {
        width: parent.width
        spacing: Theme.gap
        Repeater {
          model: root.featuredEntries
          Chip {
            text: modelData.name
            selected: modelData.iso === root.pickedIso
            onClicked: root.pickedIso = modelData.iso
          }
        }
      }
      Flow {
        visible: root.countryFilter.trim() !== ""
        width: parent.width
        spacing: Theme.gap
        Repeater {
          model: root.filteredCountries.slice(0, 60)
          Chip {
            text: modelData.name
            selected: modelData.iso === root.pickedIso
            onClicked: root.pickedIso = modelData.iso
          }
        }
      }
      Text {
        visible: root.countryFilter.trim() === ""
        text: "search above for all 198 countries, or tap detect"
        color: Theme.quaternary
        font.family: Theme.font
        font.pixelSize: Theme.footnote
      }
      Text {
        visible: root.filteredCountries.length > 60
        text: "+" + (root.filteredCountries.length - 60) + " more · keep typing to narrow"
        color: Theme.quaternary
        font.family: Theme.font
        font.pixelSize: Theme.footnote
      }

      SectionHeader { text: "what counts as complete"; trailing: "02" }
      Column {
        width: parent.width
        spacing: Theme.s(6)
        Repeater {
          model: [
            { key: "country", label: "the whole country", hint: root.wholeHint },
            { key: "regions", label: "selected " + root.pickedUnit + "s", hint: root.pickByGroup ? "pick groups below" : "pick below" },
            { key: "custom", label: "my own list", hint: "one place per line" }
          ]
          Rectangle {
            width: parent.width
            implicitHeight: Theme.rowHeight + Theme.s(6)
            radius: Theme.radiusControl
            color: modelData.key === root.goalType ? Theme.fillStrong : (goalHover.containsMouse ? Theme.fillHover : Theme.fill)
            border.width: 1
            border.color: modelData.key === root.goalType ? Theme.alpha(Theme.accent, 0.5) : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Row {
              anchors.fill: parent
              anchors.leftMargin: Theme.s(12)
              spacing: Theme.s(10)
              Text { text: modelData.label; color: Theme.label; font.family: Theme.font; font.pixelSize: Theme.body; anchors.verticalCenter: parent.verticalCenter }
              Text { text: modelData.hint; color: Theme.tertiary; font.family: Theme.font; font.pixelSize: Theme.footnote; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { id: goalHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.goalType = modelData.key }
          }
        }
      }

      Flow {
        visible: root.goalType === "regions" && root.pickByGroup
        width: parent.width
        spacing: Theme.gap
        Repeater {
          model: root.packProvinces
          Chip {
            text: modelData + " · " + root.provinceCount(modelData)
            selected: !!root.pickedRegions[modelData]
            onClicked: root.toggleGroup(modelData)
          }
        }
      }
      Flow {
        visible: root.goalType === "regions" && !root.pickByGroup && root.packFeatures.length > 0
        width: parent.width
        spacing: Theme.gap
        Repeater {
          model: root.packFeatures.slice(0, 80)
          Chip {
            text: modelData.name
            selected: !!root.pickedUnitIds[modelData.id]
            onClicked: root.toggleUnit(modelData.id)
          }
        }
      }
      Text {
        visible: root.goalType === "regions" && !root.pickByGroup && root.packFeatures.length > 80
        text: "showing 80 of " + root.packFeatures.length + " · pick whole country, or fewer above"
        color: Theme.quaternary
        font.family: Theme.font
        font.pixelSize: Theme.footnote
      }

      Rectangle {
        visible: root.goalType === "custom"
        width: parent.width
        height: 96
        radius: Theme.radiusControl
        color: Theme.fill
        border.width: 1
        border.color: Theme.separator
        clip: true
        TextEdit {
          anchors.fill: parent
          anchors.margins: Theme.s(10)
          text: root.customText
          onTextChanged: root.customText = text
          color: Theme.label
          font.family: Theme.font
          font.pixelSize: Theme.body
          wrapMode: TextEdit.Wrap
          selectByMouse: true
        }
        Text {
          visible: root.customText === ""
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.margins: Theme.s(10)
          text: "one place per line…"
          color: Theme.quaternary
          font.family: Theme.font
          font.pixelSize: Theme.body
        }
      }

      PillButton {
        width: parent.width
        text: "begin mapping"
        primary: true
        active: root.canBegin
        tint: Theme.label
        onClicked: if (root.canBegin) root.begin()
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        visible: root.store && root.store.welcomed
        text: "or keep exploring"
        color: Theme.tertiary
        font.family: Theme.font
        font.pixelSize: Theme.callout
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { root.store.set({ welcomed: true }); root.finished() }
        }
      }

      Item { width: 1; height: Theme.s(24) }
    }
  }
}
