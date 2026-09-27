import QtQuick
import QtQuick.Layouts
import qs.tokens
import qs.services
import qs.components

// Top right of the lock screen: what the machine is still attached to while it
// is locked. Read-only -- a lock screen is not the place to offer a network
// picker, and the popout that does own that is on the other side of the
// password.
//
// The design draws both halves. Each is drawn only when it has something true
// to say: no adapter, no Wi-Fi, or nothing paired, and that half is absent
// rather than showing a placeholder device.
LockChip {
    id: root

    readonly property bool hasNet: Net.connected || Net.wifiEnabled
    readonly property string netLabel: Net.label
    readonly property bool hasBt: Bt.available && Bt.enabled && Bt.connected.length > 0

    visible: root.hasNet || root.hasBt
    implicitWidth: row.implicitWidth + Appearance.lock.chipPadding * 2

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.leftMargin: Appearance.lock.chipPadding
        anchors.rightMargin: Appearance.lock.chipPadding
        spacing: Appearance.lock.chipGap

        RowLayout {
            spacing: Appearance.lock.chipItemGap
            visible: root.hasNet

            Layout.alignment: Qt.AlignVCenter

            Icon {
                text: Net.icon
                size: Appearance.size.iconLabel
                color: Colours.outline
            }

            Text {
                text: root.netLabel
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.label
                color: Colours.outline
            }
        }

        RowLayout {
            spacing: Appearance.lock.chipItemGap
            visible: root.hasBt

            Layout.alignment: Qt.AlignVCenter

            Icon {
                text: Bt.icon
                size: Appearance.size.iconLabel
                color: Colours.outline
            }

            Text {
                text: Bt.label
                font.family: Appearance.font.ui
                font.pixelSize: Appearance.size.label
                color: Colours.outline
            }
        }
    }
}
