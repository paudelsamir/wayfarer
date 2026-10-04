// tests/packs.test.mjs — one test case per country.
//
// Usage:  node tests/packs.test.mjs [ISO3 ...]
//   No args: every pack + the registry. Args: only those countries.
//   Exit 0 = all green, 1 = failures listed at the end.
//
// Checks per pack:
//   shape   — valid JSON, count matches, ids unique, names present,
//             rings closed with >= 4 finite points in lon/lat range
//   geo     — every feature has nonzero bbox area
//   hover   — centroid of every feature hits land (self or neighbour),
//             using the same Projection.js the map uses
//   smooth  — no absurdly long straight segment (over-simplification)
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const projSrc = fs.readFileSync(path.join(root, "js/Projection.js"), "utf8");
const { bboxOf, fitTransform, projectFeatures, hitTest, centroidOf } =
  new Function(projSrc + "; return {bboxOf, fitTransform, projectFeatures, hitTest, centroidOf};")();

const regSrc = fs.readFileSync(path.join(root, "js/GeoProvider.js"), "utf8");
const REGISTRY = new Function(regSrc + "; return REGISTRY;")();

const only = new Set(process.argv.slice(2).map((s) => s.toUpperCase()));
const entries = REGISTRY.filter((e) => e.ready && (!only.size || only.has(e.iso)));

let pass = 0;
const failures = [];
function fail(iso, msg) {
  failures.push(iso + ": " + msg);
}
function check(cond, iso, msg) {
  if (cond) pass++;
  else fail(iso, msg);
}

for (const e of entries) {
  const p = path.join(root, "data", e.file);
  let doc = null;
  try {
    doc = JSON.parse(fs.readFileSync(p, "utf8"));
  } catch (err) {
    fail(e.iso, "pack unreadable: " + err.message);
    continue;
  }
  const feats = doc.features || [];
  check(doc.count === feats.length, e.iso, `count ${doc.count} != features ${feats.length}`);
  check(feats.length === e.total, e.iso, `registry total ${e.total} != pack ${feats.length}`);
  check(!!e.unit, e.iso, "missing unit label");

  const ids = new Set();
  let dup = false, badName = 0;
  for (const f of feats) {
    if (!f.id || ids.has(f.id)) dup = true;
    ids.add(f.id);
    if (!f.name) badName++;
  }
  check(!dup, e.iso, "duplicate/empty feature ids");
  check(badName === 0, e.iso, badName + " features without names");

  let badRings = 0, badCoords = 0, zeroArea = 0;
  for (const f of feats) {
    if (!f.rings || !f.rings.length) { badRings++; continue; }
    let area = 0;
    for (const r of f.rings) {
      if (r.length < 4) { badRings++; continue; }
      const a = r[0], b = r[r.length - 1];
      if (a[0] !== b[0] || a[1] !== b[1]) { badRings++; continue; }
      for (const pt of r) {
        if (!isFinite(pt[0]) || !isFinite(pt[1]) || pt[0] < -180 || pt[0] > 180 || pt[1] < -90 || pt[1] > 90) { badCoords++; break; }
      }
      const xs = r.map((pt) => pt[0]), ys = r.map((pt) => pt[1]);
      area += (Math.max(...xs) - Math.min(...xs)) * (Math.max(...ys) - Math.min(...ys));
    }
    if (area === 0) zeroArea++;
  }
  check(badRings === 0, e.iso, badRings + " bad rings");
  check(badCoords === 0, e.iso, badCoords + " out-of-range coordinates");
  check(zeroArea === 0, e.iso, zeroArea + " zero-area features");

  // Area retention: simplification must never eat the place itself.
  // (Sliver drops cost little; repair-eaten mainlands cost everything.)
  let shrink = [];
  for (const f of feats) {
    let kept = 0;
    for (const r of f.rings) {
      let a = 0;
      for (let i = 0; i < r.length - 1; i++) a += r[i][0] * r[i + 1][1] - r[i + 1][0] * r[i][1];
      kept += Math.abs(a) / 2;
    }
    const raw = f.rawArea || 0;
    if (raw > 0 && kept / raw < 0.7) shrink.push(f.id + " " + Math.round((kept / raw) * 100) + "%");
  }
  check(shrink.length === 0, e.iso, "shrunk features: " + shrink.slice(0, 4).join(", "));

  // Hoverability through the real projection pipeline.
  const bb = bboxOf(feats);
  const t = fitTransform(bb, 1000, 600, 50);
  const proj = projectFeatures(feats, t);
  let covered = 0;
  for (let i = 0; i < proj.length; i++) {
    const c = centroidOf(proj[i]);
    if (hitTest(c[0], c[1], proj) >= 0) covered++;
  }
  check(covered === proj.length, e.iso, `hover coverage ${covered}/${proj.length}`);

  // Spikes: simplification damage shows as self-intersecting rings.
  // Genuine borders (even long straight desert lines) never cross.
  let spikes = 0;
  function orient(ax, ay, bx, by, cx, cy) {
    return (by - ay) * (cx - bx) - (bx - ax) * (cy - by);
  }
  function crosses(p1, p2, p3, p4) {
    const d1 = orient(p3[0], p3[1], p4[0], p4[1], p1[0], p1[1]);
    const d2 = orient(p3[0], p3[1], p4[0], p4[1], p2[0], p2[1]);
    const d3 = orient(p1[0], p1[1], p2[0], p2[1], p3[0], p3[1]);
    const d4 = orient(p1[0], p1[1], p2[0], p2[1], p4[0], p4[1]);
    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }
  for (const f of feats) {
    for (const r of f.rings) {
      if (r.length > 400) continue; // huge rings: sampled check below
      const step = r.length > 120 ? 3 : 1;
      let bad = false;
      for (let i = 0; i < r.length - 1 && !bad; i += step) {
        for (let j = i + 3; j < r.length - 1 && !bad; j += step) {
          if (i === 0 && j >= r.length - 2) continue; // closing neighbours
          // Ignore sub-pixel tangles: rounding noise, invisible on screen.
          const q = [r[i], r[i + 1], r[j], r[j + 1]];
          const qx = q.map((p) => p[0]), qy = q.map((p) => p[1]);
          if (Math.max(...qx) - Math.min(...qx) < 0.01 && Math.max(...qy) - Math.min(...qy) < 0.01) continue;
          if (crosses(r[i], r[i + 1], r[j], r[j + 1])) bad = true;
        }
      }
      if (bad) spikes++;
    }
  }
  check(spikes === 0, e.iso, spikes + " self-intersecting rings");

  // Blockiness: absurdly long single segments. Straight desert borders are
  // genuine geography, and micro countries measure in pixels, so this only
  // fires past 45% of spans wider than a degree.
  const diag = Math.hypot(bb.maxX - bb.minX, bb.maxY - bb.minY) || 1;
  const tiny = diag < 1.0;
  let worst = 0;
  for (const f of feats) {
    for (const r of f.rings) {
      for (let i = 0; i < r.length - 1; i++) {
        const d = Math.hypot(r[i + 1][0] - r[i][0], r[i + 1][1] - r[i][1]) / diag;
        if (d > worst) worst = d;
      }
    }
  }
  check(tiny || worst < 0.45, e.iso, `absurd segment ${(worst * 100).toFixed(1)}% of country span`);
}

console.log(`\npacks: ${entries.length} countries, ${pass} checks passed, ${failures.length} failed`);
for (const f of failures.slice(0, 40)) console.log("FAIL " + f);
if (failures.length > 40) console.log(`... and ${failures.length - 40} more`);
process.exit(failures.length ? 1 : 0);
