import QtQuick
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide()
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
        }
        Image {
            id: logo
            source: "logo.png"
            width: Math.min(parent.width * 0.45, 420)
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 48
            text: "Installing Sable Linux…"
            color: "#cdd6f4"
            font.pixelSize: 22
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
        }
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.7
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: "#cdd6f4"
            font.pixelSize: 20
            text: "A Debian 13 (Trixie) system with KDE Plasma.\nOptional software is downloaded from APT when you select it in the installer."
        }
    }
}
