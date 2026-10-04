import QtQuick
import QtQuick.Effects
import qs.Commons
import "../components"

// ============================================================================
// mist — frosted flatness, after o-spotlight's Frosted.
//
// Frosted is the honest glass: no refraction tricks, just a flat tinted
// pane, a hairline ring, and an inner highlight along the top, built to
// stay readable over anything. Mist follows that recipe and stops there:
// bright hairline, strong specular crest, one whisper of a top wash, the
// faintest grain for tooth, and a single soft shadow so the pane still
// floats. Transparent in spirit: nothing between you and the map but light.
//
// Dark:  moonlit hairline over near-black.
// Light: ink hairline over paper.
// ============================================================================
Item {
  id: root

  // ---- dark/light tuning ---------------------------------------------------
  readonly property real rimAlpha: Theme.resolvedMode === "light" ? 0.26 : 0.19
  readonly property real specAlpha: Theme.resolvedMode === "light" ? 0.34 : 0.30
  readonly property real washAlpha: Theme.resolvedMode === "light" ? 0.05 : 0.06
  readonly property real grainAlpha: Theme.resolvedMode === "light" ? 0.045 : 0.05
  readonly property real shadowAlpha: Theme.resolvedMode === "light" ? 0.20 : 0.42

  // ---- 1 · soft shadow -----------------------------------------------------------------
  // Frosted panes float low: one modest shadow, no drama.
  RectangularShadow {
    anchors.fill: parent
    radius: Style.cornerRadius
    offset: Qt.vector2d(0, 10)
    blur: 36
    spread: -4
    color: Qt.rgba(0, 0, 0, root.shadowAlpha)
  }

  // ---- 2 · hairline ring -----------------------------------------------------------------------
  // The frosted ring: a hairline around the glass, the single hardest
  // edge in the whole appearance.
  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha(Theme.label, root.rimAlpha)
  }

  // ---- 3 · inner highlight, top ------------------------------------------------------------------------------
  // Frosted's signature: an inner highlight along the top, like light
  // caught inside the pane.
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: 3
    anchors.leftMargin: Theme.s(20)
    anchors.rightMargin: Theme.s(20)
    height: 1
    radius: 1
    color: Theme.alpha(Theme.label, root.specAlpha * 0.7)
  }

  // ---- 4 · specular crest -------------------------------------------------------------------------------------------------
  // And the hard glint riding the rim itself, full-bleed.
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: 2
    anchors.leftMargin: Theme.s(24)
    anchors.rightMargin: Theme.s(24)
    height: 1
    radius: 1
    color: Theme.alpha(Theme.label, root.specAlpha)
  }

  // ---- 5 · flat wash --------------------------------------------------------------------------------------------------------------------
  // Frosted is tinted, flatly: a cool cast over the whole window so mist
  // never reads as atlas. Strong enough to feel, even enough to read over.
  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Theme.alpha(Theme.resolvedMode === "light" ? "#5a6b7d" : "#8fa8c8", Theme.resolvedMode === "light" ? 0.16 : 0.22)
  }
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Math.min(150, parent.height * 0.28)
    color: "transparent"
    gradient: Gradient {
      GradientStop { position: 0.0; color: Theme.alpha(Theme.label, root.washAlpha) }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  // ---- 6 · tooth -------------------------------------------------------------------------------------------------------------------------------------------
  // The faintest grain so the flat pane never reads as plastic.
  Canvas {
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var dark = Theme.resolvedMode !== "light"
      ctx.fillStyle = dark ? "#ffffff" : "#2b2620"
      var seed = 31337
      function rnd() {
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
      }
      var n = Math.floor(width * height / 14000)
      for (var i = 0; i < n; i++) {
        ctx.globalAlpha = (0.25 + rnd() * 0.75) * root.grainAlpha
        ctx.fillRect(Math.floor(rnd() * width), Math.floor(rnd() * height), 1, 1)
      }
      ctx.globalAlpha = 1.0
    }
  }
}
