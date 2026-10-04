import QtQuick
import QtQuick.Effects
import qs.Commons
import "../components"

// ============================================================================
// atlas — the bare default. Precision without decoration.
//
// A cartographer's plate: two hairline keylines, L-shaped corner ticks like
// crop marks, a whisper of film grain, and a faint edge vignette that keeps
// the eye on the map. No shadow play, no glow, no motion beyond a slow
// 12-second grain shimmer (so faint it reads as stillness, not animation).
//
// Dark:  keylines in lifted label-alpha, grain white.
// Light: keylines in ink-alpha, grain black.
// ============================================================================
Item {
  id: root

  // ---- dark/light tuning ---------------------------------------------------
  // One place per token so the two modes stay in deliberate balance.
  readonly property real keyOuter: Theme.resolvedMode === "light" ? 0.22 : 0.14
  readonly property real keyInner: Theme.resolvedMode === "light" ? 0.14 : 0.09
  readonly property real tickAlpha: Theme.resolvedMode === "light" ? 0.38 : 0.30
  readonly property real grainAlpha: Theme.resolvedMode === "light" ? 0.05 : 0.06
  readonly property real vigAlpha: Theme.resolvedMode === "light" ? 0.10 : 0.22
  readonly property int tickLen: Theme.s(14)
  readonly property int tickThick: Math.max(1, Theme.s(1))

  // ---- 1 · outer keyline ----------------------------------------------------
  // Sits exactly on the window edge. The only "border" atlas allows itself.
  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha(Theme.label, root.keyOuter)
  }

  // ---- 2 · inner keyline -----------------------------------------------------
  // A second hairline 7px in, like the neatline of a printed plate.
  Rectangle {
    anchors.fill: parent
    anchors.margins: 7
    radius: Math.max(0, Style.cornerRadius - 7)
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha(Theme.label, root.keyInner)
  }

  // ---- 7 · film grain ------------------------------------------------------------
  // A static scatter of single-pixel flecks. Painted once, never animated,
  // so it costs nothing after the first frame. The shimmer below only
  // breathes its container between two near-identical alphas.
  Canvas {
    id: grain
    anchors.fill: parent
    opacity: 0.92
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var dark = Theme.resolvedMode !== "light"
      ctx.fillStyle = dark ? "#ffffff" : "#000000"
      // Deterministic scatter: a cheap LCG so every launch looks identical.
      var seed = 1234567
      function rnd() {
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
      }
      var n = Math.floor(width * height / 9000)
      for (var i = 0; i < n; i++) {
        ctx.globalAlpha = (0.25 + rnd() * 0.75) * root.grainAlpha
        ctx.fillRect(Math.floor(rnd() * width), Math.floor(rnd() * height), 1, 1)
      }
      ctx.globalAlpha = 1.0
    }
    // The slowest motion in the plugin: a 12s breath between 0.92 and 1.
    SequentialAnimation on opacity {
      loops: Animation.Infinite
      NumberAnimation { to: 1.0; duration: 6000; easing.type: Easing.InOutSine }
      NumberAnimation { to: 0.92; duration: 6000; easing.type: Easing.InOutSine }
    }
  }

  // ---- 8 · vignette, top ----------------------------------------------------------
  // Darkens (or in light mode, gently shades) the top edge so the header
  // text sits on a calmer field. Gradient, but strictly chrome, never map.
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Math.min(120, parent.height * 0.22)
    color: "transparent"
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Theme.resolvedMode === "light"
          ? Qt.rgba(0.24, 0.22, 0.18, root.vigAlpha * 0.7)
          : Qt.rgba(0, 0, 0, root.vigAlpha)
      }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  // ---- 9 · vignette, bottom ----------------------------------------------------------
  // Mirrors the top so the footer line rests as quietly as the header.
  Rectangle {
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: Math.min(96, parent.height * 0.18)
    color: "transparent"
    gradient: Gradient {
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop {
        position: 1.0
        color: Theme.resolvedMode === "light"
          ? Qt.rgba(0.24, 0.22, 0.18, root.vigAlpha * 0.7)
          : Qt.rgba(0, 0, 0, root.vigAlpha)
      }
    }
  }

  // ---- 10 · vignette, left -------------------------------------------------------------
  // A narrow falloff on the long edges completes the plate without ever
  // touching the map's own contrast.
  Rectangle {
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    width: Math.min(72, parent.width * 0.1)
    color: "transparent"
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop {
        position: 0.0
        color: Theme.resolvedMode === "light"
          ? Qt.rgba(0.24, 0.22, 0.18, root.vigAlpha * 0.55)
          : Qt.rgba(0, 0, 0, root.vigAlpha * 0.8)
      }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  // ---- 11 · vignette, right --------------------------------------------------------------
  Rectangle {
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    width: Math.min(72, parent.width * 0.1)
    color: "transparent"
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop {
        position: 1.0
        color: Theme.resolvedMode === "light"
          ? Qt.rgba(0.24, 0.22, 0.18, root.vigAlpha * 0.55)
          : Qt.rgba(0, 0, 0, root.vigAlpha * 0.8)
      }
    }
  }

  // ---- 12 · plate number ------------------------------------------------------------------
  // A tiny surveyor's mark, bottom-left inside the neatline: the count of
  // nothing, just an instrument whisper. Kept at quaternary so it never
  // competes with the footer line.
  Text {
    textFormat: Text.PlainText
    anchors.left: parent.left
    anchors.leftMargin: 20
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 34
    text: "pl. i"
    color: Theme.alpha(Theme.label, 0.22)
    font.family: Theme.serif
    font.pixelSize: Theme.caption
    font.italic: true
  }

  // ---- 15 · hairline rule under the header zone ------------------------------------------------
  // A 1px rule where the header meets the map, full-bleed between the
  // neatlines. It gives the floating header text a horizon to sit on.
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    y: 62
    height: 1
    radius: 1
    color: Theme.alpha(Theme.label, Theme.resolvedMode === "light" ? 0.12 : 0.08)
  }

  // ---- 16 · hairline rule above the footer zone --------------------------------------------------
  // Matches the header rule so the chrome reads as one instrument.
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    y: parent.height - 54
    height: 1
    radius: 1
    color: Theme.alpha(Theme.label, Theme.resolvedMode === "light" ? 0.12 : 0.08)
  }

  // ---- 18 · edge midpoints -------------------------------------------------------------------------------
  Rectangle {
    x: 8
    anchors.verticalCenter: parent.verticalCenter
    width: 5
    height: root.tickThick
    radius: 1
    color: Theme.alpha(Theme.label, root.tickAlpha * 0.6)
  }
  Rectangle {
    x: parent.width - 13
    anchors.verticalCenter: parent.verticalCenter
    width: 5
    height: root.tickThick
    radius: 1
    color: Theme.alpha(Theme.label, root.tickAlpha * 0.6)
  }
  Rectangle {
    y: 8
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.tickThick
    height: 5
    radius: 1
    color: Theme.alpha(Theme.label, root.tickAlpha * 0.6)
  }
  Rectangle {
    y: parent.height - 13
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.tickThick
    height: 5
    radius: 1
    color: Theme.alpha(Theme.label, root.tickAlpha * 0.6)
  }

  // ---- 19 · second plate numeral, top-right ------------------------------------------------------------------
  // Balances "pl. i": the year the atlas was opened, set in the same whisper.
  Text {
    textFormat: Text.PlainText
    anchors.right: parent.right
    anchors.rightMargin: 20
    anchors.top: parent.top
    anchors.topMargin: 38
    text: "ed. i"
    color: Theme.alpha(Theme.label, 0.22)
    font.family: Theme.serif
    font.pixelSize: Theme.caption
    font.italic: true
  }

  // ---- 20 · coarse grain ---------------------------------------------------------------------------------------------
  // A second, sparser scatter of 2px flecks for tooth. Same deterministic
  // seed family, different stream, painted once like the fine grain.
  Canvas {
    anchors.fill: parent
    opacity: 0.5
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var dark = Theme.resolvedMode !== "light"
      ctx.fillStyle = dark ? "#ffffff" : "#000000"
      var seed = 987654321
      function rnd() {
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
      }
      var n = Math.floor(width * height / 60000)
      for (var i = 0; i < n; i++) {
        ctx.globalAlpha = (0.2 + rnd() * 0.6) * root.grainAlpha * 0.8
        ctx.fillRect(Math.floor(rnd() * width), Math.floor(rnd() * height), 2, 2)
      }
      ctx.globalAlpha = 1.0
    }
  }

  // ---- 21 · plate edge shade --------------------------------------------------------------------------------------
  // A 40px inner falloff just inside the top keyline, like the shadow a
  // frame throws on paper. Barely-there by design.
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: 7
    anchors.leftMargin: 7
    anchors.rightMargin: 7
    height: 40
    radius: 4
    color: "transparent"
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Theme.resolvedMode === "light"
          ? Qt.rgba(0.24, 0.22, 0.18, 0.06)
          : Qt.rgba(0, 0, 0, 0.10)
      }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  // ---- 22 · quietude ---------------------------------------------------------------------------------------------
  // Atlas adds nothing else. This trailing spacer documents the decision:
  // restraint is the design. (It also keeps section numbering honest.)
  Item { width: 1; height: 1 }
}
