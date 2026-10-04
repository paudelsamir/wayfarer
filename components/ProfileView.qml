import QtQuick
import "../js/GeoProvider.js" as Geo

// Profile: the traveler's dashboard. Avatar and name, a ringed total,
// quiet stats, footprints of visited days, and every group with its bar.
Item {
  id: root
  property var store: null
  property var features: []
  property var summary: ({ visited: 0, total: 0, remaining: 0, pct: 0 })
  property var provinces: []

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

  property string groupLabel: ""
  property string unitLabel: "district"

  signal back()

  // Country footprint, always bucket-fresh: Store flushes buckets on
  // every mutation, so this binding converges without ever writing.
  readonly property var footprint: store ? store.footprintIsos() : []

  Flickable {
    anchors.fill: parent
    anchors.leftMargin: Theme.s(40)
    anchors.rightMargin: Theme.s(40)
    anchors.topMargin: Theme.s(20)
    anchors.bottomMargin: Theme.s(20)
    contentWidth: width
    contentHeight: col.height
    clip: true
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: col
      width: Math.min(520, parent.width - 80)
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Theme.s(14)

      Item { width: 1; height: Theme.s(8) }

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
        color: Theme.label
        font.family: Theme.serif
        font.pixelSize: 24
        font.italic: true
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        visible: root.since !== ""
        text: "mapping since " + root.since + " · " + stamps.length + " marks"
        color: Theme.tertiary
        font.family: Theme.font
        font.pixelSize: Theme.callout
      }

      Item {
        width: parent.width
        height: 120
        Ring {
          anchors.centerIn: parent
          size: 112
          lineWidth: 9
          color: Theme.accent
          value: root.summary.total > 0 ? root.summary.visited / root.summary.total : 0
          Column {
            anchors.centerIn: parent
            spacing: 0
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.summary.pct + "%"
              color: Theme.label
              font.family: Theme.serif
              font.pixelSize: 22
              font.italic: true
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.summary.visited + " / " + root.summary.total
              color: Theme.secondary
              font.family: "monospace"
              font.pixelSize: Theme.footnote
            }
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.s(28)
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
              color: Theme.label
              font.family: Theme.font
              font.pixelSize: Theme.title
              font.weight: Font.DemiBold
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.label
              color: Theme.tertiary
              font.family: Theme.font
              font.pixelSize: Theme.caption
            }
          }
        }
      }

      SectionHeader { text: "footprints"; trailing: "visited days" }
      Footprints {
        anchors.horizontalCenter: parent.horizontalCenter
        stamps: root.stamps
      }

      SectionHeader { text: root.groupLabel !== "" ? root.groupLabel : root.unitLabel; trailing: root.summary.visited + " / " + root.summary.total }
      // Multi-level packs list groups; single-level packs list units.
      Repeater {
        model: root.groupLabel !== "" ? root.provinces : []
        SettingRow {
          title: modelData
          detail: {
            var v = 0, t = 0
            var vv = root.store ? root.store.visited : {}
            for (var i = 0; i < root.features.length; i++) {
              if (root.features[i].provinceName !== modelData) continue
              t++
              if (vv[root.features[i].id]) v++
            }
            return v + " of " + t + " visited"
          }
          ProgressBar {
            width: 130
            value: {
              var v2 = 0, t2 = 0
              var vv2 = root.store ? root.store.visited : {}
              for (var k = 0; k < root.features.length; k++) {
                if (root.features[k].provinceName !== modelData) continue
                t2++
                if (vv2[root.features[k].id]) v2++
              }
              return t2 > 0 ? v2 / t2 : 0
            }
            fillColor: Theme.accent
          }
        }
      }
      Repeater {
        model: root.groupLabel !== "" ? [] : root.features
        SettingRow {
          title: modelData.name
          detail: {
            var vv3 = root.store ? root.store.visited : {}
            return vv3[modelData.id] ? "visited" : "unvisited"
          }
          CheckCircle {
            checked: {
              var vv4 = root.store ? root.store.visited : {}
              return !!vv4[modelData.id]
            }
            onToggled: root.store.toggleVisited(modelData.id)
          }
        }
      }

      SectionHeader { text: "countries"; trailing: "everywhere marked" }
      Repeater {
        model: root.footprint
        Item {
          width: parent.width
          height: Theme.rowHeight + Theme.s(8)
          property string iso: modelData
          property var entry: Geo.entryFor(iso)
          property var marks: {
            var b = root.store ? root.store.visitedByCountry : {}
            return (b && b[iso]) || {}
          }
          property int nVisited: Object.keys(marks).length
          property int nTotal: entry ? entry.total : 0
          GeoPack {
            id: pk
            onReady: {
              if (pk.features.length > 0) parent.nTotal = pk.features.length
            }
          }
          Component.onCompleted: pk.load(parent.iso)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.s(12)
            anchors.rightMargin: Theme.s(12)
            spacing: Theme.s(10)
            Image {
              width: 20
              height: 14
              fillMode: Image.PreserveAspectFit
              smooth: true
              mipmap: true
              anchors.verticalCenter: parent.verticalCenter
              source: entry && entry.iso2
                ? Qt.resolvedUrl("../data/flags/" + String(entry.iso2).toLowerCase() + ".png") : ""
            }
            Column {
              width: parent.width - 20 - Theme.s(10) * 2 - 130 - Theme.s(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1
              Text {
                width: parent.width
                text: entry ? entry.name : iso
                color: Theme.label
                font.family: Theme.font
                font.pixelSize: Theme.body
                font.weight: Font.Medium
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: nVisited + " of " + nTotal + " visited"
                color: Theme.tertiary
                font.family: Theme.font
                font.pixelSize: Theme.footnote
              }
            }
            ProgressBar {
              width: 130
              anchors.verticalCenter: parent.verticalCenter
              value: nTotal > 0 ? nVisited / nTotal : 0
              fillColor: Theme.accent
            }
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.store.country !== iso) root.store.set({ country: iso })
              root.back()
            }
          }
        }
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "← back to map"
        color: Theme.tertiary
        font.family: Theme.font
        font.pixelSize: Theme.callout
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
      }

      Item { width: 1; height: Theme.s(16) }
    }
  }
}
