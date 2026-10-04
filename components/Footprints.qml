import QtQuick

// Footprints: a GitHub-style activity grid of visited days — one column
// per week, Monday on top, the current week at the right. Built from raw
// visit timestamps; intensity grows with places marked that day.
Item {
  id: root

  // Array of epoch-ms visit timestamps.
  property var stamps: []
  // Weeks of history shown. "auto" spans from the oldest mark (capped).
  property int weeks: 0

  readonly property int spanWeeks: {
    if (weeks > 0) return weeks
    if (stamps.length === 0) return 26
    var oldest = stamps[0]
    for (var i = 1; i < stamps.length; i++) if (stamps[i] < oldest) oldest = stamps[i]
    var span = Math.ceil((Date.now() - oldest) / (7 * 86400000)) + 1
    return Math.max(4, Math.min(36, span))
  }
  property int cell: 11
  property int gap: 3
  property color tint: Theme.accent

  readonly property int pitch: cell + gap
  readonly property int labelWidth: 18
  readonly property int monthHeight: 14

  readonly property var grid: {
    // Monday-based columns ending this week.
    var now = new Date()
    var dow = (now.getDay() + 6) % 7 // Mon=0
    var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    var endMonday = new Date(today.getTime() - dow * 86400000)
    var start = new Date(endMonday.getTime() - (spanWeeks - 1) * 7 * 86400000)
    var counts = {}
    for (var i = 0; i < stamps.length; i++) {
      var d = new Date(stamps[i])
      var key = d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate()
      counts[key] = (counts[key] || 0) + 1
    }
    var cols = []
    for (var w = 0; w < spanWeeks; w++) {
      var days = []
      for (var dd = 0; dd < 7; dd++) {
        var dt = new Date(start.getTime() + (w * 7 + dd) * 86400000)
        var future = dt.getTime() > today.getTime() + 86400000
        var k = dt.getFullYear() + "-" + dt.getMonth() + "-" + dt.getDate()
        var c = counts[k] || 0
        days.push({ day: dt, count: c, future: future })
      }
      cols.push(days)
    }
    return { start: start, cols: cols }
  }

  readonly property var monthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  function level(count, future) {
    if (future) return -1
    if (count <= 0) return 0
    if (count === 1) return 1
    if (count === 2) return 2
    if (count <= 4) return 3
    return 4
  }

  function cellColor(lv) {
    if (lv < 0) return "transparent"
    return Theme.alpha(root.tint, [0.07, 0.3, 0.5, 0.72, 1][lv])
  }

  implicitWidth: labelWidth + spanWeeks * pitch - gap
  implicitHeight: monthHeight + 7 * pitch - gap

  Repeater {
    model: root.grid.cols.length
    Text {
      required property int index
      readonly property var first: root.grid.cols[index][0].day
      readonly property bool starts: index === 0 ? first.getDate() <= 21 : first.getDate() <= 7
      visible: starts && index < root.grid.cols.length - 1
      x: root.labelWidth + index * root.pitch
      y: 0
      text: root.monthNames[first.getMonth()]
      color: Theme.tertiary
      font.family: Theme.font
      font.pixelSize: Theme.caption
    }
  }

  Repeater {
    model: [["M", 0], ["W", 2], ["F", 4]]
    Text {
      required property var modelData
      x: 0
      y: root.monthHeight + modelData[1] * root.pitch + (root.cell - height) / 2
      text: modelData[0]
      color: Theme.tertiary
      font.family: Theme.font
      font.pixelSize: Theme.caption
    }
  }

  Repeater {
    model: root.grid.cols.length
    Item {
      required property int index
      property var week: root.grid.cols[index]
      x: root.labelWidth + index * root.pitch
      y: root.monthHeight
      width: root.pitch
      height: 7 * root.pitch
      Repeater {
        model: parent.week
        Rectangle {
          required property var modelData
          required property int index
          readonly property int lv: root.level(modelData.count, modelData.future)
          x: 0
          y: index * root.pitch
          width: root.cell
          height: root.cell
          radius: Math.min(3, root.cell * 0.25)
          color: root.cellColor(lv)
        }
      }
    }
  }
}
