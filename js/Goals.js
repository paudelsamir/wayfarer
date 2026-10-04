// Goals.js — what "complete" means. Kept separate from persistence so
// goal logic can grow (per-province goals, streaks) without touching Store.

function scopeFeatures(allFeatures, goal) {
  if (!goal || goal.type === "country") return allFeatures
  if (goal.type === "regions") {
    var want = {}
    for (var i = 0; i < (goal.regions || []).length; i++) want[goal.regions[i]] = true
    return allFeatures.filter(function(f) { return want[f.id] })
  }
  return allFeatures // "custom" places are tracked separately, map stays whole
}

function progress(allFeatures, goal, visited) {
  var scope = scopeFeatures(allFeatures, goal)
  var count = 0
  for (var i = 0; i < scope.length; i++)
    if (visited[scope[i].id]) count++
  var total = scope.length
  var pct = total > 0 ? Math.round(count / total * 100) : 0
  return { visited: count, total: total, remaining: total - count, pct: pct }
}

function customProgress(places, visitedCustom) {
  var count = 0
  for (var i = 0; i < places.length; i++)
    if (visitedCustom[places[i].id]) count++
  var total = places.length
  return { visited: count, total: total, remaining: total - count,
           pct: total > 0 ? Math.round(count / total * 100) : 0 }
}
