// Projection.js — pure geometry helpers, no Qt dependencies.
//
// The map is deliberately tile-free: raw lon/lat rings are fitted into the
// canvas with a simple equirectangular projection (fine for one country at
// a time) preserving aspect ratio, with generous padding so empty space
// frames the map.

function bboxOf(features) {
  var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9
  for (var i = 0; i < features.length; i++) {
    var rings = features[i].rings
    for (var r = 0; r < rings.length; r++) {
      var ring = rings[r]
      for (var p = 0; p < ring.length; p++) {
        var x = ring[p][0], y = ring[p][1]
        if (x < minX) minX = x
        if (y < minY) minY = y
        if (x > maxX) maxX = x
        if (y > maxY) maxY = y
      }
    }
  }
  return { minX: minX, minY: minY, maxX: maxX, maxY: maxY }
}

// Returns { scale, ox, oy } mapping lon/lat -> canvas px.
function fitTransform(bbox, w, h, pad) {
  var bw = bbox.maxX - bbox.minX || 1
  var bh = bbox.maxY - bbox.minY || 1
  var s = Math.min((w - pad * 2) / bw, (h - pad * 2) / bh)
  var ox = pad + (w - pad * 2 - bw * s) / 2 - bbox.minX * s
  // y is flipped (lat grows upward, canvas grows downward)
  var oy = pad + (h - pad * 2 - bh * s) / 2 + bbox.maxY * s
  return { scale: s, ox: ox, oy: oy }
}

function project(lon, lat, t) {
  return [t.ox + lon * t.scale, t.oy - lat * t.scale]
}

function projectFeatures(features, t) {
  // Pre-project once per resize; hit-testing and drawing reuse this.
  var out = new Array(features.length)
  for (var i = 0; i < features.length; i++) {
    var rings = features[i].rings
    var pr = new Array(rings.length)
    for (var r = 0; r < rings.length; r++) {
      var ring = rings[r]
      var pts = new Array(ring.length)
      for (var p = 0; p < ring.length; p++)
        pts[p] = [t.ox + ring[p][0] * t.scale, t.oy - ring[p][1] * t.scale]
      pr[r] = pts
    }
    out[i] = pr
  }
  return out
}

function pointInRing(x, y, ring) {
  var inside = false
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    var xi = ring[i][0], yi = ring[i][1]
    var xj = ring[j][0], yj = ring[j][1]
    if (((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi))
      inside = !inside
  }
  return inside
}

function hitTest(x, y, projected) {
  // Smallest-first would be ideal; districts rarely overlap, so reverse
  // order (later = on top) is enough. Returns feature index or -1.
  for (var i = projected.length - 1; i >= 0; i--) {
    var rings = projected[i]
    if (rings.length === 0) continue
    if (pointInRing(x, y, rings[0])) return i
  }
  return nearestHit(x, y, projected, 14)
}

// Forgiving fallback: concave regions and scattered islands often have
// their centroid (and nearby water) outside every ring. Snap to the
// nearest edge within maxPx so coasts and bays still hover correctly.
function nearestHit(x, y, projected, maxPx) {
  var best = -1, bd = maxPx * maxPx
  for (var i = 0; i < projected.length; i++) {
    var rings = projected[i]
    for (var r = 0; r < rings.length; r++) {
      var pts = rings[r]
      for (var p = 0; p < pts.length - 1; p++) {
        var ax = pts[p][0], ay = pts[p][1]
        var bx = pts[p + 1][0], by = pts[p + 1][1]
        var dx = bx - ax, dy = by - ay
        var t = dx === 0 && dy === 0 ? 0 : ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)
        t = t < 0 ? 0 : (t > 1 ? 1 : t)
        var ex = ax + t * dx - x, ey = ay + t * dy - y
        var d2 = ex * ex + ey * ey
        if (d2 < bd) { bd = d2; best = i }
      }
    }
  }
  return best
}

function centroidOf(projectedRings) {
  var sx = 0, sy = 0, n = 0
  var outer = projectedRings[0] || []
  var step = Math.max(1, Math.floor(outer.length / 24))
  for (var i = 0; i < outer.length; i += step) {
    sx += outer[i][0]; sy += outer[i][1]; n++
  }
  if (!n) return [0, 0]
  return [sx / n, sy / n]
}
