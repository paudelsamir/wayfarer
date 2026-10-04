import QtQuick
import qs.Commons
import "../components"

// ============================================================================
// clean — high contrast, zero translucency.
//
// Every layer here is a solid color: a lifted solid background, a solid
// hairline frame, solid corner ticks, solid rules. Nothing alpha-blended,
// nothing glowing, nothing moving. Visible properly in both modes.
//
// Dark:  lifted charcoal plate, pale grey frame.
// Light: paper plate, ink frame.
// ============================================================================
Item {
  id: root

  readonly property color plate: Theme.resolvedMode === "light" ? "#faf8f2" : "#14171b"
  readonly property color frame: Theme.resolvedMode === "light" ? "#4c473b" : "#8b949d"
  readonly property color faint: Theme.resolvedMode === "light" ? "#a29b8b" : "#5b636d"
  readonly property int tickLen: Theme.s(14)
  readonly property int tickThick: Math.max(1, Theme.s(1))

  // ---- 1 · solid plate -----------------------------------------------------------------
  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.plate
  }

  // ---- 2 · solid frame --------------------------------------------------------------------------
  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: "transparent"
    border.width: 1
    border.color: root.frame
  }

  // ---- 4 · header rule -----------------------------------------------------------------------------------------
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    y: 62
    height: 1
    radius: 1
    color: root.faint
  }

  // ---- 5 · footer rule -----------------------------------------------------------------------------------------------
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    y: parent.height - 54
    height: 1
    radius: 1
    color: root.faint
  }
}
