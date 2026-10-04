// LocationDetect.js — one-shot, opt-in country detection. No tracking:
// called only from the setup screen, never in the background.
//
// Endpoint: ip-api.com free tier (no key, plain HTTP, CORS-open). Falls
// back to ipinfo.io (HTTPS, plain-text country code). Both are best-effort;
// the manual picker is always one tap away.

function detectCountry(cb) {
  var done = false
  function finish(iso) {
    if (done) return
    done = true
    cb(iso)
  }
  function attempt(url, parse) {
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE || done) return
      if (xhr.status === 200) {
        try {
          var iso = parse(xhr.responseText)
          if (iso) { finish(iso); return }
        } catch (e) {}
      }
      next()
    }
    try {
      xhr.open("GET", url)
      xhr.timeout = 7000
      xhr.send()
    } catch (e) { next() }
  }
  var steps = [
    ["http://ip-api.com/json/?fields=status,countryCode", function(body) {
      var doc = JSON.parse(body)
      return (doc && doc.status === "success" && doc.countryCode)
        ? String(doc.countryCode).toUpperCase() : ""
    }],
    ["https://ipinfo.io/country", function(body) {
      var t = String(body || "").trim().toUpperCase()
      return /^[A-Z]{2}$/.test(t) ? t : ""
    }]
  ]
  var i = 0
  function next() {
    if (done) return
    if (i >= steps.length) { finish(""); return }
    var s = steps[i++]
    attempt(s[0], s[1])
  }
  next()
}
