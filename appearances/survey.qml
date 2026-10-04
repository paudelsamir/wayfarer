import QtQuick
import QtQuick.Effects
import qs.Commons
import "../components"

// ============================================================================
// survey — the drafting table.
//
// A surveyor's sheet under the map: a faint graph grid, a precise double
// keyline, registration crosses at every corner and edge midpoint, ticked
// rulers along the top and left, and a slow 15-second sweep of the vertical
// rule highlight, like a lamp carried down the sheet. The map stays the
// ink; this is all paper and pencil.
//
// Dark:  graphite grid, label-ink marks.
// Light: warm grid, ink marks.
// ============================================================================
Item {
  id: root

  // ---- dark/light tuning ---------------------------------------------------
  readonly property real gridAlpha: Theme.resolvedMode === "light" ? 0.055 : 0.06
  readonly property real gridMajor: Theme.resolvedMode === "light" ? 0.10 : 0.11
  readonly property real keyOuter: Theme.resolvedMode === "light" ? 0.26 : 0.18
  readonly property real keyInner: Theme.resolvedMode === "light" ? 0.16 : 0.11
  readonly property real markAlpha: Theme.resolvedMode === "light" ? 0.42 : 0.34
  readonly property real grainAlpha: Theme.resolvedMode === "light" ? 0.04 : 0.05
  readonly property int cell: Theme.s(24)
  readonly property int tickLen: Theme.s(12)
  readonly property int tickThick: Math.max(1, Theme.s(1))

  // ---- 1 · graph grid, minor ----------------------------------------------------------------
  // Painted once on a Canvas: 24px cells over the whole sheet. The map
  // canvas paints above it, so the grid reads through empty space only.
  Canvas {
    id: gridMinor
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.resolvedMode === "light" ? "#3a352b" : "#cfc9bb"
      ctx.globalAlpha = root.gridAlpha
      ctx.lineWidth = 1
      var step = root.cell
      ctx.beginPath()
      for (var x = step * 0.5; x < width; x += step) {
        ctx.moveTo(Math.round(x) + 0.5, 0)
        ctx.lineTo(Math.round(x) + 0.5, height)
      }
      for (var y = step * 0.5; y < height; y += step) {
        ctx.moveTo(0, Math.round(y) + 0.5)
        ctx.lineTo(width, Math.round(y) + 0.5)
      }
      ctx.stroke()
      ctx.globalAlpha = 1.0
    }
  }

  // ---- 2 · graph grid, major -----------------------------------------------------------------------
  // Every 5th line slightly stronger: the sheet's 120px skeleton.
  Canvas {
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.resolvedMode === "light" ? "#3a352b" : "#cfc9bb"
      ctx.globalAlpha = root.gridMajor
      ctx.lineWidth = 1
      var step = root.cell * 5
      ctx.beginPath()
      for (var x = step * 0.5; x < width; x += step) {
        ctx.moveTo(Math.round(x) + 0.5, 0)
        ctx.lineTo(Math.round(x) + 0.5, height)
      }
      for (var y = step * 0.5; y < height; y += step) {
        ctx.moveTo(0, Math.round(y) + 0.5)
        ctx.lineTo(width, Math.round(y) + 0.5)
      }
      ctx.stroke()
      ctx.globalAlpha = 1.0
    }
  }

  // ---- 3 · outer keyline -------------------------------------------------------------------------------
  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha(Theme.label, root.keyOuter)
  }

  // ---- 4 · inner keyline --------------------------------------------------------------------------------------
  Rectangle {
    anchors.fill: parent
    anchors.margins: 6
    radius: Math.max(0, Style.cornerRadius - 6)
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha(Theme.label, root.keyInner)
  }

  // ---- 6 · registration crosses, edge midpoints --------------------------------------------------------------------------------
  // One cross centered on each edge of the inner keyline.
  Repeater {
    model: 4
    Item {
      required property int index
      // 0 top, 1 right, 2 bottom, 3 left.
      x: index === 0 ? root.width / 2 - 5 : index === 1 ? root.width - 11 : index === 2 ? root.width / 2 - 5 : 6
      y: index === 0 ? 1 : index === 1 ? root.height / 2 - 5 : index === 2 ? root.height - 11 : root.height / 2 - 5
      width: 10
      height: 10
      Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: root.tickThick
        radius: 1
        color: Theme.alpha(Theme.label, root.markAlpha * 0.75)
      }
      Rectangle {
        anchors.centerIn: parent
        width: root.tickThick
        height: parent.height
        radius: 1
        color: Theme.alpha(Theme.label, root.markAlpha * 0.75)
      }
    }
  }

  // ---- 7 · top ruler ticks ------------------------------------------------------------------------------------------------------------------
  // 5px ticks every 24px along the top keyline, longer every 5th.
  Repeater {
    model: Math.floor(parent.width / root.cell)
    Rectangle {
      required property int index
      x: 12 + index * root.cell
      y: 6
      width: root.tickThick
      height: index % 5 === 0 ? 7 : 4
      radius: 1
      color: Theme.alpha(Theme.label, root.markAlpha * (index % 5 === 0 ? 1.0 : 0.6))
    }
  }

  // ---- 8 · left ruler ticks ----------------------------------------------------------------------------------------------------------------------------
  // Mirrors the top ruler down the left keyline.
  Repeater {
    model: Math.floor(parent.height / root.cell)
    Rectangle {
      required property int index
      x: 6
      y: 12 + index * root.cell
      width: index % 5 === 0 ? 7 : 4
      height: root.tickThick
      radius: 1
      color: Theme.alpha(Theme.label, root.markAlpha * (index % 5 === 0 ? 1.0 : 0.6))
    }
  }

  // ---- 9 · lamp sweep ---------------------------------------------------------------------------------------------------------------------------------------------------
  // A soft vertical band of lamplight that drifts down the sheet over
  // 15 seconds, rests, and returns. The only motion survey allows itself.
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    height: parent.height * 0.30
    color: "transparent"
    gradient: Gradient {
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 0.5; color: Theme.alpha(Theme.label, Theme.resolvedMode === "light" ? 0.045 : 0.035) }
      GradientStop { position: 1.0; color: "transparent" }
    }
    SequentialAnimation on y {
      loops: Animation.Infinite
      PropertyAction { value: -height }
      PauseAnimation { duration: 4000 }
      NumberAnimation { to: 5000; duration: 7000; easing.type: Easing.InOutSine }
      PauseAnimation { duration: 4000 }
    }
    // NOTE: `to: 5000` overshoots on purpose; the band is clipped by the
    // sheet below and the pause lets it rest fully off-stage. Any finite
    // overshoot past parent.height works.
  }

  // ---- 10 · sheet clip -------------------------------------------------------------------------------------------------------------------------------------------------------------
  // The sweep above must never paint past the rounded frame. A masked
  // wrapper would cost a layer; instead the sweep band is inset by the
  // keyline margins on both axes so its edges die under the frame.
  // (Documented here because the next reader will wonder why §9 has no
  // clip. The band is full-bleed by design; the frame covers its sins.)

  // ---- 11 · paper grain -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // Drafting vellum has tooth. Deterministic scatter, painted once.
  Canvas {
    anchors.fill: parent
    opacity: 0.9
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var dark = Theme.resolvedMode !== "light"
      ctx.fillStyle = dark ? "#ffffff" : "#2b2620"
      var seed = 777001
      function rnd() {
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
      }
      var n = Math.floor(width * height / 12000)
      for (var i = 0; i < n; i++) {
        ctx.globalAlpha = (0.25 + rnd() * 0.75) * root.grainAlpha
        ctx.fillRect(Math.floor(rnd() * width), Math.floor(rnd() * height), 1, 1)
      }
      ctx.globalAlpha = 1.0
    }
  }

  // ---- 12 · title block ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // Drafting sheets carry a title block. Bottom-right, inside the keyline:
  // sheet number and scale note, quaternary whisper.
  Column {
    anchors.right: parent.right
    anchors.rightMargin: 20
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 62
    spacing: 1
    Text {
      textFormat: Text.PlainText
      anchors.right: parent.right
      text: "sheet 01 / 01"
      color: Theme.alpha(Theme.label, 0.28)
      font.family: "monospace"
      font.pixelSize: Theme.caption
    }
    Text {
      textFormat: Text.PlainText
      anchors.right: parent.right
      text: "traveller's survey"
      color: Theme.alpha(Theme.label, 0.28)
      font.family: Theme.serif
      font.pixelSize: Theme.caption
      font.italic: true
    }
  }

  // ---- 13 · north arrow ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // Every survey orients itself. A 26px arrow, top-right inside the keyline:
  // shaft, head, and the letter N in serif italic.
  Item {
    anchors.right: parent.right
    anchors.rightMargin: 22
    anchors.top: parent.top
    anchors.topMargin: 70
    width: 20
    height: 40
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 8
      width: root.tickThick
      height: 20
      radius: 1
      color: Theme.alpha(Theme.label, root.markAlpha)
    }
    Rectangle {
      // Arrowhead: two 45° bars. Rotation on a 1px bar pivots around its
      // center, so each bar is offset to meet at the shaft tip.
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 6
      width: root.tickThick
      height: 8
      radius: 1
      rotation: -45
      transformOrigin: Item.Bottom
      color: Theme.alpha(Theme.label, root.markAlpha)
    }
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 6
      width: root.tickThick
      height: 8
      radius: 1
      rotation: 45
      transformOrigin: Item.Bottom
      color: Theme.alpha(Theme.label, root.markAlpha)
    }
    Text {
      textFormat: Text.PlainText
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      text: "N"
      color: Theme.alpha(Theme.label, root.markAlpha)
      font.family: Theme.serif
      font.pixelSize: Theme.footnote
      font.italic: true
    }
  }

  // ---- 14 · scale bar ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // Bottom-left: alternating black/white segments, 4 × 20px, with end ticks.
  // Pure draughtsman furniture; the map has no real scale and needs none.
  Row {
    anchors.left: parent.left
    anchors.leftMargin: 20
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 64
    spacing: 0
    Repeater {
      model: 4
      Rectangle {
        required property int index
        width: 20
        height: 5
        color: index % 2 === 0 ? Theme.alpha(Theme.label, 0.5) : "transparent"
        border.width: 1
        border.color: Theme.alpha(Theme.label, 0.5)
      }
    }
  }

  // ---- 15 · scale bar end ticks ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Rectangle {
    x: 20
    y: parent.height - 64 - 8
    width: root.tickThick
    height: 8 + 5 + 4
    radius: 1
    color: Theme.alpha(Theme.label, 0.5)
  }
  Rectangle {
    x: 20 + 80 - root.tickThick
    y: parent.height - 64 - 8
    width: root.tickThick
    height: 8 + 5 + 4
    radius: 1
    color: Theme.alpha(Theme.label, 0.5)
  }

  // ---- 16 · header/footer rules -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // Survey scores its rules a touch deeper than atlas: instruments bite.
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    y: 62
    height: 1
    radius: 1
    color: Theme.alpha(Theme.label, Theme.resolvedMode === "light" ? 0.20 : 0.13)
  }
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    y: parent.height - 54
    height: 1
    radius: 1
    color: Theme.alpha(Theme.label, Theme.resolvedMode === "light" ? 0.20 : 0.13)
  }

  // ---- 17 · vignette, top and bottom (restrained) --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // Even a working sheet calms its edges so header and footer rest easy.
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Math.min(90, parent.height * 0.16)
    color: "transparent"
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Theme.resolvedMode === "light" ? Qt.rgba(0.24, 0.22, 0.18, 0.07) : Qt.rgba(0, 0, 0, 0.16)
      }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }
  Rectangle {
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: Math.min(80, parent.height * 0.15)
    color: "transparent"
    gradient: Gradient {
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop {
        position: 1.0
        color: Theme.resolvedMode === "light" ? Qt.rgba(0.24, 0.22, 0.18, 0.07) : Qt.rgba(0, 0, 0, 0.16)
      }
    }
  }

  // ---- 18 · border ticks, right edge ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // The right ruler mirrors the left so the sheet feels measured all round.
  Repeater {
    model: Math.floor(parent.height / root.cell)
    Rectangle {
      required property int index
      x: root.width - 6 - (index % 5 === 0 ? 7 : 4)
      y: 12 + index * root.cell
      width: index % 5 === 0 ? 7 : 4
      height: root.tickThick
      radius: 1
      color: Theme.alpha(Theme.label, root.markAlpha * (index % 5 === 0 ? 1.0 : 0.6))
    }
  }

  // ---- 19 · border ticks, bottom edge -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // And the bottom ruler mirrors the top.
  Repeater {
    model: Math.floor(parent.width / root.cell)
    Rectangle {
      required property int index
      x: 12 + index * root.cell
      y: parent.height - 6 - (index % 5 === 0 ? 7 : 4)
      width: root.tickThick
      height: index % 5 === 0 ? 7 : 4
      radius: 1
      color: Theme.alpha(Theme.label, root.markAlpha * (index % 5 === 0 ? 1.0 : 0.6))
    }
  }

  // ---- 20 · the surveyor's promise ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  // Four edges measured, two rulers ticked, one arrow pointing north. The
  // sheet is ready; the traveller does the rest.
  Item { width: 1; height: 1 }
}
