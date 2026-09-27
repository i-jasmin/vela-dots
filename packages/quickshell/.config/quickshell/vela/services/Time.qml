pragma Singleton

import QtQuick
import Quickshell

// The shell's clock.
//
// One SystemClock for the whole shell: three surfaces want the same instant in
// three shapes and a timer each would drift apart visibly at the minute
// boundary. Every format the design asks for is a property here rather than a
// `Qt.formatDateTime` call at the call site, so the bar and the lock screen
// cannot disagree about what "the date" looks like.
Singleton {
    id: root

    readonly property date now: clock.date

    // The horizontal bar and the lock screen: "14:32".
    readonly property string time: format("hh:mm")
    readonly property string timeWithSeconds: format("hh:mm:ss")

    // The vertical bar stacks its clock: hour over minute, so the two
    // halves are separate strings rather than a split of `time`.
    readonly property string hour: format("hh")
    readonly property string minute: format("mm")
    readonly property string second: format("ss")

    // The lock screen: "Monday, 21 September".
    readonly property string date: format("dddd, d MMMM")
    // The horizontal bar: "Mon 21 Sep".
    readonly property string dateShort: format("ddd d MMM")
    // The vertical bar: the 9px line under the stacked clock, "21.09".
    readonly property string dateCompact: format("dd.MM")
    readonly property string iso: format("yyyy-MM-dd")

    // The dashboard and the power menu both open with one. Hour buckets rather
    // than sunset: "good evening" at 16:00 in December would read as a bug, not
    // a feature.
    readonly property string greeting: {
        const h = clock.date.getHours();
        if (h < 5)
            return qsTr("Good night");
        if (h < 12)
            return qsTr("Good morning");
        if (h < 18)
            return qsTr("Good afternoon");
        if (h < 22)
            return qsTr("Good evening");
        return qsTr("Good night");
    }

    // "Good afternoon, <name>" -- the login name, which is what the session
    // knows for certain.
    readonly property string user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
    readonly property string salutation: root.user ? qsTr("%1, %2").arg(root.greeting).arg(root.user) : root.greeting

    function format(fmt: string): string {
        return Qt.formatDateTime(clock.date, fmt);
    }

    // "2h 16m", "45m", "3d 4h" -- "2h 16m after sunset" and the uptime and
    // countdown lines that reuse the same shape.
    function span(ms: real): string {
        const total = Math.max(0, Math.round(ms / 60000));
        const d = Math.floor(total / 1440);
        const h = Math.floor(total % 1440 / 60);
        const m = total % 60;
        if (d > 0)
            return `${d}d ${h}h`;
        if (h > 0)
            return `${h}h ${m}m`;
        return `${m}m`;
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }
}
