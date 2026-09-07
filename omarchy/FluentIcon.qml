import QtQuick
import qs.Commons

// Speech-bubble mark for the bar and the panel hero. Geometry only — color
// comes from the bar/theme so the icon follows Omarchy instead of shipping
// a foreign macOS glyph.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool busy: false
  property bool dimmed: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize
  opacity: dimmed ? 0.45 : 1

  Behavior on opacity {
    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
  }

  SequentialAnimation on opacity {
    running: root.busy && !root.dimmed
    loops: Animation.Infinite
    NumberAnimation { to: 0.35; duration: 420; easing.type: Easing.InOutQuad }
    NumberAnimation { to: 1.0; duration: 420; easing.type: Easing.InOutQuad }
  }

  readonly property real unit: Math.max(1, iconSize / 12)

  Rectangle {
    id: bubble
    width: root.iconSize * 0.86
    height: root.iconSize * 0.64
    x: (root.iconSize - width) / 2
    y: root.iconSize * 0.08
    radius: Math.max(2, root.iconSize * 0.18)
    color: "transparent"
    border.width: Math.max(1, Math.round(root.unit * 0.9))
    border.color: root.color

    Column {
      anchors.centerIn: parent
      spacing: Math.max(1, root.unit * 0.7)

      Repeater {
        model: 3
        Rectangle {
          required property int index
          width: bubble.width * (index === 0 ? 0.52 : (index === 1 ? 0.40 : 0.28))
          height: Math.max(1, root.unit * 0.7)
          radius: height / 2
          color: root.color
        }
      }
    }
  }

  Rectangle {
    width: Math.max(2, root.unit * 2.2)
    height: width
    radius: 1
    color: root.color
    x: bubble.x + bubble.width * 0.22
    y: bubble.y + bubble.height - height * 0.35
    rotation: 40
  }
}
