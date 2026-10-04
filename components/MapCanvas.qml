import QtQuick
import "../js/Projection.js" as Proj

// MapCanvas — the entire visual experience, in two layers:
//   base    — fills + hairline borders. Repaints only when data, theme,
//             visited or scope change. Never on hover.
//   overlay — hover brightening, selection ring, celebration pulse.
//             Repaints cheaply (one or two shapes) on interaction.
//
// Hit-testing resolves through point-in-polygon with a nearest-edge
// fallback, throttled so fast mouse sweeps stay smooth.
Item {
  id: root

  property var features: []
  property var visited: ({})
  property var scopeIds: null
  property string accent: "#6f9ab0"
  property string dimColor: "#22272c"
  property string borderColor: "#3a4148"
  property string hoverBorder: "#7d8892"
  property real glow: 8
  // Overall fill presence. Borders stay crisp so the map never melts.
  property real mapOpacity: 1.0
  // Ids whose whole group is complete render deeper.
  property var completeIds: ({})
  property string hoverId: ""
  property string selectedId: ""

  // Zoom + pan: wheel zooms toward the cursor, drag pans,
  // double-click empty space resets. Projection rebuilds cheaply.
  property real zoom: 1.0
  property real panX: 0
  property real panY: 0
  readonly property real zoomMin: 1.0
  readonly property real zoomMax: 8.0

  signal hovered(string id, real x, real y)
  signal unhovered()
  signal clicked(string id)

  property var _projected: []
  property var _boxes: []
  property var _bbox: null

  onFeaturesChanged: rebuild()
  onWidthChanged: rebuild()
  onHeightChanged: rebuild()
  onZoomChanged: rebuild()
  onPanXChanged: rebuild()
  onPanYChanged: rebuild()

  function zoomAt(mx, my, factor) {
    var nz = Math.max(zoomMin, Math.min(zoomMax, zoom * factor))
    if (nz === zoom) return
    // Keep the point under the cursor pinned while scaling.
    // (Transform is applied about the canvas center — see rebuild.)
    var cx = width / 2, cy = height / 2
    var k = nz / zoom
    panX = (mx - cx) - ((mx - cx) - panX) * k
    panY = (my - cy) - ((my - cy) - panY) * k
    zoom = nz
  }

  function resetView() {
    zoom = 1.0
    panX = 0
    panY = 0
  }

  function rebuild() {
    if (!features || features.length === 0 || width <= 0 || height <= 0) {
      _projected = []
      _boxes = []
      _bbox = null
      base.requestPaint()
      hoverLayer.requestPaint()
      return
    }
    _bbox = Proj.bboxOf(features)
    var t = Proj.fitTransform(_bbox, width, height, Math.min(width, height) * 0.07)
    // Zoom about the canvas center, then pan.
    var cx = width / 2, cy = height / 2
    var zt = {
      scale: t.scale * zoom,
      ox: cx + (t.ox - cx) * zoom + panX,
      oy: cy + (t.oy - cy) * zoom + panY
    }
    _projected = Proj.projectFeatures(features, zt)
    _boxes = []
    for (var i = 0; i < _projected.length; i++) {
      var x0 = 1e12, y0 = 1e12, x1 = -1e12, y1 = -1e12
      var rings = _projected[i]
      for (var r = 0; r < rings.length; r++) {
        var pts = rings[r]
        for (var p = 0; p < pts.length; p++) {
          if (pts[p][0] < x0) x0 = pts[p][0]
          if (pts[p][1] < y0) y0 = pts[p][1]
          if (pts[p][0] > x1) x1 = pts[p][0]
          if (pts[p][1] > y1) y1 = pts[p][1]
        }
      }
      _boxes[i] = [x0, y0, x1, y1]
    }
    base.requestPaint()
    hoverLayer.requestPaint()
  }

  function tracePath(ctx, rings) {
    ctx.beginPath()
    for (var r = 0; r < rings.length; r++) {
      var pts = rings[r]
      for (var p = 0; p < pts.length; p++) {
        if (p === 0) ctx.moveTo(pts[p][0], pts[p][1])
        else ctx.lineTo(pts[p][0], pts[p][1])
      }
      ctx.closePath()
    }
  }

  function idAt(x, y) {
    if (_projected.length === 0) return ""
    // Direct hit, bbox-rejected first.
    for (var i = _projected.length - 1; i >= 0; i--) {
      var b0 = _boxes[i]
      if (x < b0[0] || x > b0[2] || y < b0[1] || y > b0[3]) continue
      var rr = _projected[i]
      if (rr.length && Proj.pointInRing(x, y, rr[0])) return String(features[i].id)
    }
    // Forgiving fallback: nearest edge within 14px, bbox-rejected first.
    var best = -1, bd = 14 * 14
    for (var k = 0; k < _projected.length; k++) {
      var b = _boxes[k]
      if (x < b[0] - 14 || x > b[2] + 14 || y < b[1] - 14 || y > b[3] + 14) continue
      var rings = _projected[k]
      for (var r = 0; r < rings.length; r++) {
        var pts = rings[r]
        for (var p = 0; p < pts.length - 1; p++) {
          var ax = pts[p][0], ay = pts[p][1]
          var dx = pts[p + 1][0] - ax, dy = pts[p + 1][1] - ay
          var tt = dx === 0 && dy === 0 ? 0 : ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)
          tt = tt < 0 ? 0 : (tt > 1 ? 1 : tt)
          var ex = ax + tt * dx - x, ey = ay + tt * dy - y
          var d2 = ex * ex + ey * ey
          if (d2 < bd) { bd = d2; best = k }
        }
      }
    }
    return best >= 0 ? String(features[best].id) : ""
  }

  function centroidOfId(id) {
    for (var i = 0; i < features.length; i++) {
      if (String(features[i].id) === id && _projected[i]) {
        var c = Proj.centroidOf(_projected[i])
        return Qt.point(c[0], c[1])
      }
    }
    return Qt.point(width / 2, height / 2)
  }

  function featureById(id) {
    for (var i = 0; i < features.length; i++)
      if (String(features[i].id) === id) return features[i]
    return null
  }

  function indexOf(id) {
    for (var i = 0; i < features.length; i++)
      if (String(features[i].id) === id) return i
    return -1
  }

  // Celebration pulse on toggle.
  property string pulseId: ""
  property real pulseT: 0
  Timer {
    id: pulseTimer
    interval: 40
    repeat: true
    onTriggered: {
      root.pulseT += 1 / 15
      if (root.pulseT >= 1) { stop(); root.pulseId = ""; root.pulseT = 0 }
      hoverLayer.requestPaint()
    }
  }
  function pulse(id) {
    pulseId = id
    pulseT = 0
    pulseTimer.restart()
  }

  // ---- base layer: everything static ----
  Canvas {
    id: base
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (root._projected.length === 0) return
      for (var i = 0; i < root.features.length; i++) {
        var f = root.features[i]
        var isV = !!root.visited[f.id]
        var isDone = isV && !!root.completeIds[f.id]
        var inScope = !root.scopeIds || root.scopeIds[f.id]
        root.tracePath(ctx, root._projected[i])
        ctx.fillStyle = isDone ? Qt.darker(root.accent, 1.45) : (isV ? root.accent : root.dimColor)
        // Wide separation: visited land glows forward, the rest recedes.
        ctx.globalAlpha = inScope ? (isV ? (isDone ? 0.95 : 0.92) : 0.5) : 0.22
        ctx.globalAlpha *= root.mapOpacity
        if (isV && inScope && root.glow > 0) {
          // Clip the halo inside the shape: glow must never spill onto
          // neighbours and shade districts you never touched.
          ctx.save()
          ctx.clip()
          ctx.shadowColor = root.accent
          ctx.shadowBlur = root.glow
          ctx.fill()
          ctx.restore()
        } else {
          ctx.fill()
        }
        ctx.shadowBlur = 0
        ctx.globalAlpha = 1.0
        // Visited shapes get an accent edge so amber never melts into tan.
        ctx.strokeStyle = (isV && inScope) ? root.accent : root.borderColor
        ctx.lineWidth = 1
        ctx.globalAlpha = inScope ? (isV ? 0.55 : 1.0) : 0.35
        ctx.stroke()
        ctx.globalAlpha = 1.0
      }
    }
  }

  // ---- hover layer: one-shape highlights, cheap ----
  Canvas {
    id: hoverLayer
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (root._projected.length === 0) return
      function drawIdx(i, hover, selected) {
        var f = root.features[i]
        var isV = !!root.visited[f.id]
        var inScope = !root.scopeIds || root.scopeIds[f.id]
        root.tracePath(ctx, root._projected[i])
        if (hover) {
          ctx.fillStyle = isV ? root.accent : root.hoverBorder
          ctx.globalAlpha = inScope ? (isV ? 0.95 : 0.35) : 0.3
          if (isV && inScope && root.glow > 0) {
            ctx.save()
            ctx.clip()
            ctx.shadowColor = root.accent
            ctx.shadowBlur = root.glow * 1.6
            ctx.fill()
            ctx.restore()
          } else {
            ctx.fill()
          }
          ctx.shadowBlur = 0
          ctx.globalAlpha = 1.0
        }
        ctx.strokeStyle = selected ? root.accent : root.hoverBorder
        ctx.lineWidth = selected ? 1.6 : 1.2
        ctx.globalAlpha = inScope ? 1.0 : 0.4
        ctx.stroke()
        ctx.globalAlpha = 1.0
      }
      if (root.selectedId !== "") {
        var s = root.indexOf(root.selectedId)
        if (s >= 0 && s !== root.indexOf(root.hoverId)) drawIdx(s, false, true)
      }
      if (root.hoverId !== "") {
        var h = root.indexOf(root.hoverId)
        if (h >= 0) drawIdx(h, true, h === root.indexOf(root.selectedId))
      }
      if (root.pulseId !== "") {
        var pi = root.indexOf(root.pulseId)
        if (pi >= 0) {
          root.tracePath(ctx, root._projected[pi])
          ctx.save()
          ctx.globalAlpha = Math.max(0, 0.55 * (1 - root.pulseT))
          ctx.strokeStyle = root.accent
          ctx.lineWidth = 1 + root.pulseT * 3
          ctx.shadowColor = root.accent
          ctx.shadowBlur = 14
          ctx.stroke()
          ctx.restore()
        }
      }
    }
  }

  onVisitedChanged: base.requestPaint()
  onCompleteIdsChanged: base.requestPaint()
  onScopeIdsChanged: { base.requestPaint(); hoverLayer.requestPaint() }
  onAccentChanged: { base.requestPaint(); hoverLayer.requestPaint() }
  onDimColorChanged: base.requestPaint()
  onBorderColorChanged: base.requestPaint()
  onHoverBorderChanged: hoverLayer.requestPaint()
  onGlowChanged: base.requestPaint()
  onMapOpacityChanged: { base.requestPaint(); hoverLayer.requestPaint() }
  onHoverIdChanged: hoverLayer.requestPaint()
  onSelectedIdChanged: hoverLayer.requestPaint()

  property double _lastHit: 0
  property string _lastHitId: ""

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: root.hoverId !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor

    property real pressX: 0
    property real pressY: 0
    property bool panning: false

    onPressed: function(mouse) {
      pressX = mouse.x
      pressY = mouse.y
      panning = false
    }
    onPositionChanged: function(mouse) {
      if (pressedButtons & Qt.LeftButton) {
        if (!panning && Math.hypot(mouse.x - pressX, mouse.y - pressY) > 6) {
          panning = true
          root.unhovered()
        }
        if (panning) {
          root.panX += mouse.x - pressX
          root.panY += mouse.y - pressY
          pressX = mouse.x
          pressY = mouse.y
          return
        }
      }
      // Throttle the expensive hit-test; the tooltip still follows freely.
      var now = Date.now()
      var id = root._lastHitId
      if (now - root._lastHit > 28 || Math.abs(mouse.x - root._lastX) + Math.abs(mouse.y - root._lastY) > 30) {
        id = root.idAt(mouse.x, mouse.y)
        root._lastHit = now
        root._lastHitId = id
        root._lastX = mouse.x
        root._lastY = mouse.y
      }
      if (id !== root.hoverId) root.hoverId = id
      if (id !== "") root.hovered(id, mouse.x, mouse.y)
      else root.unhovered()
    }
    onReleased: function(mouse) {
      // Click selects; drag pans (handled above). Touch taps land here too.
      if (!panning) {
        var id = root.idAt(mouse.x, mouse.y)
        if (id !== "") root.clicked(id)
        else root.clicked("")
      }
      panning = false
    }
    onDoubleClicked: function(mouse) {
      var id = root.idAt(mouse.x, mouse.y)
      if (id === "" && (root.zoom !== 1.0 || root.panX !== 0 || root.panY !== 0)) root.resetView()
    }
    onWheel: function(wheel) {
      if (wheel.angleDelta.y === 0) return
      root.unhovered()
      root.zoomAt(wheel.x, wheel.y, wheel.angleDelta.y > 0 ? 1.18 : 1 / 1.18)
    }
    onExited: {
      root.hoverId = ""
      root.unhovered()
    }
  }
  property real _lastX: -1e9
  property real _lastY: -1e9
}
