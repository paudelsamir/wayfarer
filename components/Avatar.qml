import QtQuick

// Traveler avatar: a circular portrait clipped on a canvas, or a serif
// monogram on soft accent when no picture is set. No extra modules,
// no masking tricks — just a clipped draw.
Item {
  id: root
  property string name: ""
  property string imagePath: ""
  property int size: 64

  implicitWidth: size
  implicitHeight: size

  readonly property string initial: {
    var t = (name || "").trim()
    return t ? t.charAt(0).toUpperCase() : "W"
  }

  onImagePathChanged: {
    pic.ready = false
    if (imagePath !== "") pic.loadImage(imagePath)
    else pic.requestPaint()
  }

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: Theme.alpha(Theme.accent, 0.16)
  }
  Text {
    visible: root.imagePath === "" || !pic.ready
    anchors.centerIn: parent
    text: root.initial
    color: Theme.accent
    font.family: Theme.serif
    font.pixelSize: root.size * 0.42
    font.italic: true
  }

  Canvas {
    id: pic
    anchors.fill: parent
    property bool ready: false
    onImageLoaded: requestPaint()
    Component.onCompleted: if (root.imagePath !== "") loadImage(root.imagePath)
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (root.imagePath === "" || !isImageLoaded(root.imagePath)) {
        ready = false
        return
      }
      ready = true
      ctx.save()
      ctx.beginPath()
      ctx.arc(width / 2, height / 2, width / 2, 0, Math.PI * 2)
      ctx.clip()
      // Cover-fit the portrait into the circle.
      ctx.drawImage(root.imagePath, 0, 0, width, height)
      ctx.restore()
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha(Theme.label, 0.14)
  }
}
