pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.tokens

// Sunrise, sunset, and the evening warmth curve they drive.
//
// This service fetches nothing. Weather already asks two providers where the
// user is and when the sun sets there, and a second request would be a second
// answer: the dashboard card would print "Sunset 19:12" while the palette
// warmed on somebody else's 19:24. So the provider's own times are used when
// they are there, and when they are not -- no network yet, or a date past the
// five days Open-Meteo returns -- the same numbers are computed locally from
// the coordinates wttr.in reported, which are cached to disk with the rest of
// the weather. One successful fetch, ever, is enough for the ramp to keep
// working offline for good.
//
// The warmth curve: 0 at sunset, 1 after `rampMinutes`, held through the night,
// and back to 0 by sunrise. It is a hue rotation applied to the active scheme
// by Colours.warm() -- NOT a light/dark switch and not a third palette.
// `eveningWarmth.startsAt` can move the curve's edges to civil dusk and dawn;
// it does not move the sunset the weather card prints.
Singleton {
    id: root

    readonly property real latitude: Weather.latitude
    readonly property real longitude: Weather.longitude
    readonly property bool located: latitude !== 0 || longitude !== 0

    // Today's, as real dates: the ramp subtracts them, it does not print them.
    readonly property date sunrise: riseOn(clock.date)
    readonly property date sunset: setOn(clock.date)
    readonly property bool available: isDate(sunrise) && isDate(sunset)

    // Which sunset opened the night the given instant belongs to, and which
    // sunrise will close it. Between sunrise and sunset both are the night
    // *ahead*, and `warmth` reads zero there.
    readonly property date nightStart: startOf(clock.date)
    readonly property date nightEnd: endOf(clock.date)

    // --- where the ramp begins ----------------------------------------------
    //
    // `appearance.eveningWarmth.startsAt` was in the design's shell.json and
    // was read by nothing, which makes it a control the settings window could
    // one day offer and not honour. "sunset" is the default, as designed;
    // "civil-dusk" waits until the sun is six degrees below the horizon --
    // roughly half an hour later at mid-latitudes -- for somebody who finds the
    // palette warming while it is still light outside.
    //
    // It moves the *ramp* only. `sunrise`/`sunset` stay the true ones, because
    // the weather card prints them and the user would check them against an
    // almanac. Anything other than "civil-dusk" means sunset, so a typo warms
    // at the ordinary hour rather than never.
    //
    // The standard -0.833 degrees is the sun's disc half above the horizon plus
    // the refraction that bends the rest into view; -6 is the civil twilight
    // boundary. Neither is a design metric, so neither belongs in a token.
    readonly property real sunAltitude: -0.833
    readonly property real civilAltitude: -6
    readonly property bool fromCivilDusk: Config.appearance.eveningWarmth.startsAt === "civil-dusk"
    readonly property real rampAltitude: fromCivilDusk ? civilAltitude : sunAltitude

    readonly property bool day: {
        if (!available)
            return true;
        const now = clock.date.getTime();
        return now >= sunrise.getTime() && now < sunset.getTime();
    }

    // "weather" when the provider dated it, "computed" when the almanac did,
    // "none" when there is no location to work from. Worth surfacing: it is the
    // difference between a warmth curve that is right and one that is plausible.
    readonly property string source: {
        if (!available)
            return "none";
        const iso = Qt.formatDateTime(clock.date, "yyyy-MM-dd");
        const e = Weather.forecast.find(x => x.date === iso);
        return e && isDate(e.sunriseAt) ? "weather" : "computed";
    }

    // 0 = neutral daylight, 1 = fully warmed. The one number the palette wants.
    readonly property real warmth: warmthAt(clock.date)
    readonly property bool warming: warmth > 0 && warmth < 1
    // The design prints this: "matugen · dark · 3400 K". With
    // `eveningWarmth.screen` on, NightLight hands it to hyprsunset as well.
    readonly property int kelvin: Math.round(Config.appearance.eveningWarmth.fromKelvin + (Config.appearance.eveningWarmth.toKelvin - Config.appearance.eveningWarmth.fromKelvin) * warmth)

    readonly property real msSinceSunset: available ? clock.date.getTime() - sunset.getTime() : 0
    readonly property real msUntilSunrise: available ? nightEnd.getTime() - clock.date.getTime() : 0
    // The design's context line: "21:40 · 2h 16m after sunset".
    readonly property string label: {
        if (!available)
            return "";
        if (day)
            return qsTr("%1 until sunset").arg(Time.span(sunset.getTime() - clock.date.getTime()));
        return qsTr("%1 after sunset").arg(Time.span(Math.abs(clock.date.getTime() - nightStart.getTime())));
    }

    function isDate(d: var): bool {
        return d instanceof Date && !isNaN(d.getTime());
    }

    function riseOn(day: date): date {
        return eventOn(day, true);
    }

    function setOn(day: date): date {
        return eventOn(day, false);
    }

    function eventOn(day: date, rise: bool): date {
        const iso = Qt.formatDateTime(day, "yyyy-MM-dd");
        const e = Weather.forecast.find(x => x.date === iso);
        const provider = e ? (rise ? e.sunriseAt : e.sunsetAt) : null;
        if (isDate(provider))
            return provider;
        return compute(day, rise, root.sunAltitude);
    }

    // The ramp's own boundaries. At the default altitude these are exactly the
    // sun events above, provider times included; at civil dusk the provider has
    // no answer -- Open-Meteo reports sunrise and sunset and nothing between --
    // so the almanac is asked instead.
    function rampSetOn(day: date): date {
        return root.fromCivilDusk ? compute(day, false, root.rampAltitude) : setOn(day);
    }

    function rampRiseOn(day: date): date {
        return root.fromCivilDusk ? compute(day, true, root.rampAltitude) : riseOn(day);
    }

    function shift(day: date, days: int): date {
        const d = new Date(day);
        d.setDate(d.getDate() + days);
        return d;
    }

    // The sunset that opened the night containing `when`. Before today's
    // sunrise the night began yesterday.
    function startOf(when: date): date {
        const r = riseOn(when);
        if (isDate(r) && when.getTime() < r.getTime())
            return setOn(shift(when, -1));
        return setOn(when);
    }

    // The sunrise that closes it.
    function endOf(when: date): date {
        const r = riseOn(when);
        if (isDate(r) && when.getTime() < r.getTime())
            return r;
        return riseOn(shift(when, 1));
    }

    // The night as the ramp sees it, which is the night above unless
    // `startsAt` moved its edges.
    function rampStartOf(when: date): date {
        const r = rampRiseOn(when);
        if (isDate(r) && when.getTime() < r.getTime())
            return rampSetOn(shift(when, -1));
        return rampSetOn(when);
    }

    function rampEndOf(when: date): date {
        const r = rampRiseOn(when);
        if (isDate(r) && when.getTime() < r.getTime())
            return r;
        return rampRiseOn(shift(when, 1));
    }

    // Pure, so it can be checked at a simulated hour without waiting for one.
    function warmthAt(when: date): real {
        const cfg = Config.appearance.eveningWarmth;
        if (!cfg.enabled)
            return 0;
        const start = rampStartOf(when);
        const end = rampEndOf(when);
        if (!isDate(start) || !isDate(end))
            return 0;
        const t = when.getTime();
        if (t < start.getTime() || t >= end.getTime())
            return 0;
        const ramp = Math.max(1, cfg.rampMinutes) * 60000;
        // Two ramps, one up from sunset and one down into sunrise. Taking the
        // smaller means a night shorter than twice the ramp -- midsummer at
        // this latitude -- peaks lower instead of snapping between 1 and 0.
        const up = (t - start.getTime()) / ramp;
        const down = (end.getTime() - t) / ramp;
        return Math.max(0, Math.min(1, Math.min(up, down)));
    }

    // The almanac fallback: the standard sunrise equation, good to a minute or
    // two, which is well inside the ninety-minute ramp it feeds. Returns an
    // invalid date above the Arctic circle, where the sun does neither --
    // and, at `civilAltitude`, on any night the sun never sinks that far.
    //
    // `altitude` is how far below the horizon the sun has to be, in degrees.
    function compute(day: date, rise: bool, altitude: real): date {
        if (!located)
            return new Date(NaN);
        const rad = Math.PI / 180;
        const noon = new Date(day);
        noon.setHours(12, 0, 0, 0);
        const julian = noon.getTime() / 86400000 + 2440587.5;
        const n = Math.round(julian - 2451545 + 0.0008);
        const meanSolarNoon = n - longitude / 360;
        const m = (357.5291 + 0.98560028 * meanSolarNoon) % 360;
        const centre = 1.9148 * Math.sin(m * rad) + 0.02 * Math.sin(2 * m * rad) + 0.0003 * Math.sin(3 * m * rad);
        const lambda = (m + centre + 180 + 102.9372) % 360;
        const transit = 2451545 + meanSolarNoon + 0.0053 * Math.sin(m * rad) - 0.0069 * Math.sin(2 * lambda * rad);
        const declination = Math.asin(Math.sin(lambda * rad) * Math.sin(23.4397 * rad));
        const cosHour = (Math.sin(altitude * rad) - Math.sin(latitude * rad) * Math.sin(declination)) / (Math.cos(latitude * rad) * Math.cos(declination));
        if (cosHour > 1 || cosHour < -1)
            return new Date(NaN);
        const hourAngle = Math.acos(cosHour) / rad / 360;
        const j = rise ? transit - hourAngle : transit + hourAngle;
        return new Date((j - 2440587.5) * 86400000);
    }

    SystemClock {
        id: clock

        // The ramp moves about one part in ninety a minute. Anything finer
        // would wake the shell for a change nobody can see.
        precision: SystemClock.Minutes
    }

    // This is the whole point of the service: Colours.warm() is already wired
    // through every accessor, and nothing else writes the value it reads.
    // The curve says when; `strength` says how far. `warmth` itself stays the
    // curve, which is what the screen's warmth (NightLight) follows.
    Binding {
        target: Colours
        property: "warmth"
        value: root.warmth * Math.max(0, Math.min(1, Config.appearance.eveningWarmth.strength))
    }

    // Whether the palette's opening warmth -- and, in auto mode, light or
    // dark -- is settled, which needs the sunset. Colours eases nothing until
    // it is, so a shell started at night opens warm instead of fading to it
    // a second in, once the location is read.
    Binding {
        target: Colours
        property: "sunKnown"
        value: root.available || (!Config.appearance.eveningWarmth.enabled && Config.appearance.mode !== "auto")
    }

    // Mode "auto" has no other driver in the shell, and daylight is the only
    // sensible one. Inert unless the user asks for it -- shell.json ships
    // "dark" -- and deliberately independent of `warmth`: warming the palette
    // at dusk is not the same decision as inverting it.
    Binding {
        target: Colours
        property: "light"
        value: root.day
        when: Config.appearance.mode === "auto" && root.available
    }
}
