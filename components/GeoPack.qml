import QtQuick
import Quickshell
import Quickshell.Io
import "../js/GeoProvider.js" as Geo

// GeoPack — loads a boundary pack through FileView (QML's XHR refuses
// file:// reads, so this is the blessed local-file path). One instance per
// consumer; call load(iso) and read `features` on `ready`.
QtObject {
  id: root

  property string iso: ""
  property var features: []
  property string error: ""

  signal ready()

  function load(iso) {
    root.iso = iso || ""
    var entry = Geo.entryFor(root.iso)
    if (!entry || !entry.ready) {
      features = []
      error = ""
      ready()
      return
    }
    file.path = Qt.resolvedUrl("../data/" + entry.file)
  }

  property FileView file: FileView {
    watchChanges: false
    onLoaded: {
      try {
        var doc = JSON.parse(text())
        root.features = doc.features || []
        root.error = ""
      } catch (e) {
        root.features = []
        root.error = "boundary pack failed to parse"
      }
      root.ready()
    }
    onLoadFailed: function(err) {
      root.features = []
      root.error = "boundary pack failed to load"
      root.ready()
    }
  }
}
