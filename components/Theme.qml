pragma Singleton
import QtQuick
import qs.Commons

// Wayfarer design tokens: colors come from the active Omarchy theme
// (auto) or the forced dark/light bases, while shape, type and motion are
// wayfarer's own. Surfaces are soft alpha fills, never hard borders; motion
// is fast and physical.
QtObject {
  id: root

  // Set by MapPanel/BarWidget from stored settings (idempotent).
  property string mode: "auto"           // auto | dark | light
  property string accentName: "#6f9ab0"  // hex or "auto"

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  function s(px) { return Math.round(px * (Style.fontScale || 1)) }
  function luminance(c) {
    function lin(u) { return u <= 0.03928 ? u / 12.92 : Math.pow((u + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
  }

  readonly property string resolvedMode: mode === "dark" || mode === "light"
    ? mode : (luminance(Color.popups.background) > 0.45 ? "light" : "dark")

  // ---- color
  readonly property color fg: {
    if (mode === "dark") return "#e8e4da"
    if (mode === "light") return "#2b2822"
    return Color.popups.text
  }
  readonly property color bg: {
    if (mode === "dark") return "#0a0c0d"
    if (mode === "light") return "#f2efe7"
    return Color.popups.background
  }
  readonly property color accent: accentName === "auto" ? Color.accent : accentName

  readonly property color label: fg
  readonly property color secondary: alpha(fg, 0.6)
  readonly property color tertiary: alpha(fg, 0.36)
  readonly property color quaternary: alpha(fg, 0.16)
  readonly property color fill: alpha(fg, 0.045)
  readonly property color fillHover: alpha(fg, 0.08)
  readonly property color fillStrong: alpha(fg, 0.12)
  readonly property color separator: alpha(fg, 0.075)

  // Map geometry: curated per forced mode, alpha-blended in auto so any
  // omarchy theme — not just light/dark — gets a fitting map. Borders run
  // a touch bright so regions read as cut lines, not smudges.
  readonly property color mapShape: mode === "dark" ? "#242a30"
    : mode === "light" ? "#d9d5c9" : alpha(fg, 0.10)
  readonly property color mapBorder: mode === "dark" ? "#4b535c"
    : mode === "light" ? "#a89f8e" : alpha(fg, 0.22)
  readonly property color mapHoverBorder: mode === "dark" ? "#9aa5b1"
    : mode === "light" ? "#5f594d" : alpha(fg, 0.45)

  // ---- type (editorial serif for place names, quiet grotesk for UI)
  readonly property string font: {
    var families = Qt.fontFamilies()
    var wanted = ["Inter", "Inter Variable", "SF Pro Text", "Geist", "Noto Sans"]
    for (var i = 0; i < wanted.length; i++) if (families.indexOf(wanted[i]) >= 0) return wanted[i]
    return Style.font.family
  }
  readonly property string iconFont: Style.font.family
  readonly property string serif: "Georgia, 'Times New Roman', serif"

  readonly property int largeTitle: s(28)
  readonly property int title: s(19)
  readonly property int headline: s(14)
  readonly property int body: s(13)
  readonly property int callout: s(12)
  readonly property int footnote: s(11)
  readonly property int caption: s(10)

  // ---- shape
  readonly property int radius: s(14)
  readonly property int radiusControl: s(9)
  readonly property int radiusSmall: s(6)
  readonly property int gap: s(8)
  readonly property int pad: s(14)
  readonly property int rowHeight: s(34)
  readonly property int controlHeight: s(30)

  // ---- motion
  readonly property int fast: 120
  readonly property int normal: 220
  readonly property int slow: 360
}
