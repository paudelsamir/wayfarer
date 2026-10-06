import QtQuick
import "../js/GeoProvider.js" as Geo

// ShareCard: a portrait postcard of the traveler's map, rendered offscreen
// and saved with grabToImage. Fixed 1080x1350 so the PNG is deterministic;
// every number on it is live data from the store, never placeholder text.
Item {
  id: root
  width: 1080
  height: 1350

  property var store: null
  property var summary: ({ visited: 0, total: 0, remaining: 0, pct: 0 })
  property var features: []
  property var provinces: []
  property string countryName: "nepal"
  property string unitLabel: "districts"

  readonly property var stamps: {
    var out = []
    if (!store) return out
    for (var k in store.visited) out.push(store.visited[k])
    for (var k2 in store.visitedCustom) out.push(store.visitedCustom[k2])
    return out
  }

  readonly property string since: {
    if (stamps.length === 0) return ""
    var m = stamps[0]
    for (var i = 1; i < stamps.length; i++) if (stamps[i] < m) m = stamps[i]
    var d = new Date(m)
    return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2)
  }

  readonly property var footprint: store ? store.footprintIsos() : []
  readonly property var shownCountries: footprint.slice(0, 3)
  readonly property int hiddenCountries: Math.max(0, footprint.length - shownCountries.length)

  // Top areas by marks, most-visited first, capped for the card.
  readonly property var topAreas: {
    var rows = []
    if (!store) return rows
    var vv = store.visited || {}
    for (var i = 0; i < provinces.length; i++) {
      var v = 0, t = 0
      for (var j = 0; j < features.length; j++) {
        if (features[j].provinceName !== provinces[i]) continue
        t++
        if (vv[features[j].id]) v++
      }
      if (v > 0) rows.push({ name: provinces[i], v: v, t: t })
    }
    rows.sort(function(a, b) { return b.v - a.v })
    return rows.slice(0, 3)
  }

  Rectangle {
    anchors.fill: parent
    radius: 40
    color: "#0b0e10"
    border.width: 2
    border.color: "#232a31"
  }

  Column {
    x: 84
    y: 56
    width: parent.width - 168
    spacing: 16

    Avatar {
      anchors.horizontalCenter: parent.horizontalCenter
      size: 72
      name: store ? (store.travelerName || "") : ""
      imagePath: store ? (store.avatarPath || "") : ""
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: (store && store.travelerName) ? store.travelerName : "wayfarer"
      color: "#f2f4f6"
      font.family: Theme.serif
      font.pixelSize: 68
      font.italic: true
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      visible: root.since !== ""
      text: "mapping since " + root.since + " · " + stamps.length + " marks"
      color: "#8b95a1"
      font.family: Theme.font
      font.pixelSize: 26
    }

    Item {
      width: parent.width
      height: 224
      Ring {
        anchors.centerIn: parent
        size: 216
        lineWidth: 18
        color: Theme.accent
        value: root.summary.total > 0 ? root.summary.visited / root.summary.total : 0
        Column {
          anchors.centerIn: parent
          spacing: 0
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.summary.pct + "%"
            color: "#f2f4f6"
            font.family: Theme.serif
            font.pixelSize: 56
            font.italic: true
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.summary.visited + " / " + root.summary.total
            color: "#8b95a1"
            font.family: "monospace"
            font.pixelSize: 24
          }
        }
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 72
      Repeater {
        model: [
          { n: root.summary.visited, label: "visited" },
          { n: root.summary.remaining, label: "remaining" },
          { n: root.summary.total, label: root.unitLabel }
        ]
        Column {
          spacing: 2
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: modelData.n
            color: "#f2f4f6"
            font.family: Theme.font
            font.pixelSize: 48
            font.weight: Font.DemiBold
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: modelData.label
            color: "#8b95a1"
            font.family: Theme.font
            font.pixelSize: 22
          }
        }
      }
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      visible: root.topAreas.length > 0
      text: "TOP AREAS"
      color: "#5f6b78"
      font.family: Theme.font
      font.pixelSize: 22
      font.letterSpacing: 6
    }

    Repeater {
      model: root.topAreas
      Item {
        width: parent.width
        height: 46
        required property var modelData
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: 300
          text: modelData.name
          color: "#d7dde3"
          font.family: Theme.font
          font.pixelSize: 27
          elide: Text.ElideRight
        }
        ProgressBar {
          anchors.centerIn: parent
          width: 380
          value: modelData.t > 0 ? modelData.v / modelData.t : 0
          fillColor: Theme.accent
        }
        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.v + "/" + modelData.t
          color: "#8b95a1"
          font.family: "monospace"
          font.pixelSize: 24
        }
      }
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      visible: root.topAreas.length === 0 && root.stamps.length === 0
      text: "nothing marked yet · tap the map to begin"
      color: "#8b95a1"
      font.family: Theme.serif
      font.pixelSize: 28
      font.italic: true
    }

    Item {
      width: parent.width
      height: 182
      visible: root.stamps.length > 0
      Footprints {
        anchors.centerIn: parent
        weeks: 22
        cell: 18
        gap: 5
        labelPixelSize: 22
        stamps: root.stamps
      }
    }

    Column {
      width: parent.width
      spacing: 10
      visible: root.footprint.length > 0
      Repeater {
        model: root.shownCountries
        Item {
          id: chip
          width: parent.width
          height: 38
          required property string modelData
          property var entry: Geo.entryFor(modelData)
          property var marks: (root.store && root.store.visitedByCountry && root.store.visitedByCountry[modelData]) || {}
          Row {
            anchors.centerIn: parent
            spacing: 12
            Image {
              width: 38
              height: 27
              fillMode: Image.PreserveAspectFit
              smooth: true
              mipmap: true
              anchors.verticalCenter: parent.verticalCenter
              source: chip.entry && chip.entry.iso2
                ? Qt.resolvedUrl("../data/flags/" + String(chip.entry.iso2).toLowerCase() + ".png") : ""
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: (chip.entry ? chip.entry.name : chip.modelData) + "  " + Object.keys(chip.marks).length + "/" + (chip.entry ? chip.entry.total : 0)
              color: "#aeb7c2"
              font.family: Theme.font
              font.pixelSize: 25
            }
          }
        }
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        visible: root.hiddenCountries > 0
        text: "+" + root.hiddenCountries + " more"
        color: "#5f6b78"
        font.family: Theme.font
        font.pixelSize: 22
      }
    }
  }

  Text {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 52
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    text: "The world is yours to fill in."
    color: "#d7dde3"
    font.family: Theme.serif
    font.pixelSize: 38
    font.italic: true
  }
}
