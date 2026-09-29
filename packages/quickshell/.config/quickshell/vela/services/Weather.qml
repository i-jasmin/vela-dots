pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Current conditions, a four-day forecast and the day's astronomy.
//
// Two providers, because neither one is enough on its own. wttr.in answers the
// "what is it doing right now" half -- it geolocates from the outbound IP, so
// it needs no coordinates and no key, and it names the place it picked, which
// is what the card prints. It caps at three days, though, and the design asks
// for four columns *after* today, so the daily strip and the multi-day
// astronomy come from Open-Meteo, which takes the coordinates wttr.in already
// told us and answers five days for free.
//
// Only one condition-code table exists: Open-Meteo's WMO codes are folded onto
// the provider codes wttr.in uses (`wwoForWmo`) and both go through `iconFor`,
// whose glyph names were checked against the installed Material Symbols.
//
// Two rules hold throughout: a failed fetch never blanks good data -- the last
// response stands and `error` explains itself -- and the last good response is
// cached to disk, so a cold start on a slow link shows yesterday's sky rather
// than nothing at all.
Singleton {
    id: root

    readonly property bool available: lastUpdated > 0
    property bool loading: false
    property string error: ""

    // Milliseconds since the epoch of the response currently on display,
    // whether it arrived over the network or out of the cache. Lets a widget
    // say "as of 20 minutes ago" instead of implying everything is live.
    property real lastUpdated: 0

    property string location: ""
    property string country: ""
    // Open-Meteo needs coordinates and the Sun service needs them to compute
    // sunrise offline; wttr.in hands them over with the nearest-area block, so
    // nothing has to ask a second geocoder.
    property real latitude: 0
    property real longitude: 0

    // Always Celsius internally. `temp` is what a widget should show.
    property real tempC: 0
    property real feelsLikeC: 0
    readonly property bool metric: Config.weather.units !== "imperial"
    readonly property real temp: metric ? tempC : tempC * 9 / 5 + 32
    readonly property real feelsLike: metric ? feelsLikeC : feelsLikeC * 9 / 5 + 32
    // The design prints a bare degree: `14°`, `Feels 12° · Hamburg`, and
    // `15° 17° 19° 13°` across the forecast. So metric -- the configuration the
    // design is drawn in -- carries no unit.
    //
    // Imperial keeps one. The design does not draw that case, and `57°` with
    // nothing to say which scale it is would be a guess the design never asked
    // anybody to make; filling a gap the design is silent on is not the same
    // as overruling it. The CPU sensor keeps its `48 °C` for the opposite
    // reason -- the dashboard gives it one.
    readonly property string unit: metric ? "°" : "°F"

    property string description: ""
    // The provider's WWO condition code; `icon` is the only thing that should
    // read it.
    property int code: 0
    // A Material Symbols name, already mapped from the provider's code, so no
    // widget ever has to carry its own condition-code table.
    readonly property string icon: iconFor(code, isDay)
    // Derived from the clock rather than the response, so the glyph turns over
    // at sunset instead of waiting for the next fifteen-minute refresh.
    readonly property bool isDay: {
        if (!hasSun)
            return true;
        const now = clock.date.getTime();
        return now >= sunriseAt.getTime() && now < sunsetAt.getTime();
    }

    property int humidity: 0
    property real windSpeed: 0
    property string windDir: ""
    property int pressure: 0
    property real uv: 0
    property int cloudCover: 0
    property real precipitation: 0
    property real visibility: 0

    // --- astronomy ------------------------------------------------------
    //
    // Open-Meteo dates the sunrise, wttr.in only clocks it, so today's entry in
    // `forecast` wins when it is there and the parsed wttr.in string is the
    // fallback. Both end up as real dates: the warmth ramp needs to subtract
    // them, not print them.
    property date wttrSunrise
    property date wttrSunset

    readonly property var today: {
        const iso = Qt.formatDateTime(clock.date, "yyyy-MM-dd");
        return forecast.find(d => d.date === iso) ?? null;
    }
    readonly property date sunriseAt: today && root.isDate(today.sunriseAt) ? today.sunriseAt : root.onToday(wttrSunrise)
    readonly property date sunsetAt: today && root.isDate(today.sunsetAt) ? today.sunsetAt : root.onToday(wttrSunset)

    // A fallback time moved onto today's date. Offline, with a cache older
    // than its own forecast, the fallback is an earlier day's sunrise and
    // sunset -- both long past, so `isDay` was false and every icon showed
    // night all day. A day or two moves the sun by minutes, not hours.
    function onToday(at: date): date {
        if (!root.isDate(at))
            return at;
        const moved = new Date(clock.date);
        moved.setHours(at.getHours(), at.getMinutes(), 0, 0);
        return moved;
    }
    readonly property bool hasSun: isDate(sunriseAt) && isDate(sunsetAt)
    // The dashboard prints "Sunrise 06:58" -- 24-hour, no meridiem.
    readonly property string sunrise: isDate(sunriseAt) ? Qt.formatDateTime(sunriseAt, "hh:mm") : ""
    readonly property string sunset: isDate(sunsetAt) ? Qt.formatDateTime(sunsetAt, "hh:mm") : ""

    // --- forecast -------------------------------------------------------
    //
    // [{ date, dayName, minC, maxC, icon, description, precipChance,
    //    sunriseAt, sunsetAt }], today first.
    property var meteoDays: []
    property var wttrDays: []
    readonly property var forecast: meteoDays.length > 0 ? meteoDays : wttrDays
    // The dashboard's strip: the four days after today. Empty rather than short
    // if only wttr.in answered, so the card can say so instead of drawing three
    // columns in a four-column grid.
    readonly property var forecastDays: forecast.slice(1, 5)
    // [{ time, tempC, icon, precipChance }] for today, three-hourly.
    property var hourly: []

    // Open-Meteo's hourly series, [{ at, tempC, icon }], when it has answered.
    property var meteoHours: []

    // The next five whole hours for the dashboard's strip, [{ time, icon,
    // temp }]: hourly from Open-Meteo, or wttr.in's three-hourly slots until
    // it answers.
    readonly property var nextHours: {
        const now = clock.date.getTime();
        const src = root.meteoHours.length > 0 ? root.meteoHours : root.hourly.map(h => {
            const [hh, mm] = h.time.split(":").map(Number);
            const at = new Date(clock.date);
            at.setHours(hh, mm, 0, 0);
            return {
                at: at,
                tempC: h.tempC,
                icon: h.icon
            };
        });
        return src.filter(h => h.at.getTime() > now).slice(0, 5).map(h => ({
                    time: Qt.formatDateTime(h.at, "hh:mm"),
                    icon: h.icon,
                    temp: root.formatTemp(h.tempC)
                }));
    }

    // Rain, snow, hail, thunder: weather you would change plans for.
    function isWet(icon: string): bool {
        return /rain|snow|thunder|hail/.test(icon);
    }

    // One clause about the next few hours, from the hourly series: "clears by
    // 16:00" while it is wet, "rain from 17:00" when it is about to be, and
    // nothing when the hours ahead look like this one.
    readonly property string outlook: {
        const now = clock.date.getTime();
        const ahead = root.meteoHours.filter(h => h.at.getTime() > now && h.at.getTime() < now + 12 * 3600000);
        if (!root.available || ahead.length === 0)
            return "";
        if (root.isWet(root.icon)) {
            const dry = ahead.find(h => !root.isWet(h.icon));
            return dry ? qsTr("clears by %1").arg(Qt.formatDateTime(dry.at, "hh:mm")) : "";
        }
        const wet = ahead.slice(0, 6).find(h => root.isWet(h.icon));
        if (!wet)
            return "";
        return (/snow/.test(wet.icon) ? qsTr("snow from %1") : qsTr("rain from %1")).arg(Qt.formatDateTime(wet.at, "hh:mm"));
    }

    // wttr.in geolocates from the outbound IP when the path is empty, which is
    // what "auto" means. Spaces are the one character it wants as `+` rather
    // than percent-encoded.
    readonly property string place: Config.weather.location === "auto" ? "" : Config.weather.location.trim()
    readonly property string query: encodeURIComponent(place).replace(/%20/g, "+")

    // No Config key covers this: shell.json has `weather.location` and
    // `weather.units` and nothing else. Fifteen minutes is wttr.in's own cache
    // window, so asking more often returns the same document.
    readonly property int refreshInterval: 15 * 60 * 1000

    readonly property string cacheDir: `${Quickshell.env("HOME")}/.local/state/vela`
    readonly property string cachePath: `${cacheDir}/weather.json`

    function refresh(): void {
        if (loading)
            return;
        loading = true;
        fetch.command = ["curl", "-sS", "--compressed", "--max-time", "20", "--retry", "1", `https://wttr.in/${root.query}?format=j1`];
        fetch.running = true;
    }

    function formatTemp(c: real): string {
        const v = metric ? c : c * 9 / 5 + 32;
        return `${Math.round(v)}${unit}`;
    }

    // QML hands back an invalid `date` for an unset property, and an invalid
    // one is only detectable through its time value.
    function isDate(d: var): bool {
        return d instanceof Date && !isNaN(d.getTime());
    }

    // "06:57 AM" on the given day -> a date, or an invalid one if it is not a
    // time at all. wttr.in reports "No sunrise" above the Arctic circle.
    function parseClock(t: string, on: date): date {
        const m = (t ?? "").match(/^(\d{1,2}):(\d{2})\s*(AM|PM)?$/i);
        if (!m)
            return new Date(NaN);
        let h = parseInt(m[1]);
        if (m[3]) {
            h = h % 12;
            if (m[3].toUpperCase() === "PM")
                h += 12;
        }
        const d = new Date(on);
        d.setHours(h, parseInt(m[2]), 0, 0);
        return d;
    }

    // WWO condition codes to Material Symbols. This table is the reason `icon`
    // exists at all: it lives here once rather than in the bar, the dashboard
    // and the desktop widget separately. Names checked against the installed
    // Material Symbols Rounded -- note there is no `clear_night`, which is why
    // a clear night is `moon_stars`.
    function iconFor(wwo: int, day: bool): string {
        switch (wwo) {
        case 113:
            return day ? "clear_day" : "moon_stars";
        case 116:
            return day ? "partly_cloudy_day" : "partly_cloudy_night";
        case 119:
        case 122:
            return "cloud";
        case 143:
        case 248:
        case 260:
            return "foggy";
        // Drizzle and the lighter rains.
        case 176:
        case 263:
        case 266:
        case 293:
        case 296:
        case 353:
            return "rainy_light";
        case 299:
        case 302:
        case 356:
            return "rainy";
        case 305:
        case 308:
        case 359:
            return "rainy_heavy";
        // Sleet and freezing rain: wet and frozen at once.
        case 182:
        case 185:
        case 281:
        case 284:
        case 311:
        case 314:
        case 317:
        case 320:
        case 362:
        case 365:
            return "rainy_snow";
        case 179:
        case 323:
        case 326:
        case 368:
            return "weather_snowy";
        case 329:
        case 332:
        case 371:
            return "snowing";
        case 227:
        case 230:
        case 335:
        case 338:
            return "snowing_heavy";
        case 350:
        case 374:
        case 377:
            return "weather_hail";
        case 200:
        case 386:
        case 389:
        case 392:
        case 395:
            return "thunderstorm";
        default:
            return "cloud";
        }
    }

    // Open-Meteo speaks WMO 4677, wttr.in speaks WWO. Folding one onto the
    // other keeps a single glyph table: adding a third provider means another
    // twenty lines here, not another switch statement in the dashboard.
    function wwoForWmo(wmo: int): int {
        switch (wmo) {
        case 0:
            return 113;
        case 1:
        case 2:
            return 116;
        case 3:
            return 122;
        case 45:
            return 143;
        case 48:
            return 260;
        case 51:
        case 53:
            return 266;
        case 55:
            return 302;
        case 56:
        case 57:
            return 281;
        case 61:
            return 293;
        case 63:
            return 302;
        case 65:
            return 308;
        case 66:
        case 67:
            return 314;
        case 71:
        case 77:
            return 323;
        case 73:
            return 332;
        case 75:
            return 338;
        case 80:
            return 353;
        case 81:
            return 356;
        case 82:
            return 359;
        case 85:
            return 368;
        case 86:
            return 371;
        case 95:
            return 386;
        case 96:
        case 99:
            return 392;
        default:
            return 122;
        }
    }

    // Applies a parsed wttr.in j1 document. Shared by the network path and the
    // cache path so a cached start and a live refresh cannot drift apart.
    function applyWttr(doc: var, fetchedAt: real): bool {
        const cur = doc?.current_condition?.[0];
        const days = doc?.weather;
        if (!cur || !days || days.length === 0)
            return false;

        const area = doc.nearest_area?.[0];
        root.location = area?.areaName?.[0]?.value ?? "";
        root.country = area?.country?.[0]?.value ?? "";
        root.latitude = parseFloat(area?.latitude) || 0;
        root.longitude = parseFloat(area?.longitude) || 0;

        root.tempC = parseFloat(cur.temp_C) || 0;
        root.feelsLikeC = parseFloat(cur.FeelsLikeC) || 0;
        root.code = parseInt(cur.weatherCode) || 0;
        // The provider pads its descriptions with a trailing space.
        root.description = (cur.weatherDesc?.[0]?.value ?? "").trim();
        root.humidity = parseInt(cur.humidity) || 0;
        root.windSpeed = parseFloat(cur.windspeedKmph) || 0;
        root.windDir = cur.winddir16Point ?? "";
        root.pressure = parseInt(cur.pressure) || 0;
        root.uv = parseFloat(cur.uvIndex) || 0;
        root.cloudCover = parseInt(cur.cloudcover) || 0;
        root.precipitation = parseFloat(cur.precipMM) || 0;
        root.visibility = parseFloat(cur.visibility) || 0;

        const astro = days[0].astronomy?.[0];
        // Midday, so a timezone west of UTC cannot roll the day back.
        const day0 = new Date(`${days[0].date}T12:00:00`);
        root.wttrSunrise = root.parseClock(astro?.sunrise, day0);
        root.wttrSunset = root.parseClock(astro?.sunset, day0);

        root.wttrDays = days.map(d => {
            const slots = d.hourly ?? [];
            // Midday stands for the day as a whole; the 00:00 slot would label
            // every clear day "clear night".
            const noon = slots.find(h => h.time === "1200") ?? slots[Math.floor(slots.length / 2)] ?? {};
            let chance = 0;
            for (let i = 0; i < slots.length; i++)
                chance = Math.max(chance, parseInt(slots[i].chanceofrain) || 0, parseInt(slots[i].chanceofsnow) || 0);
            const at = new Date(`${d.date}T12:00:00`);
            const a = d.astronomy?.[0];
            return {
                date: d.date,
                dayName: Qt.formatDateTime(at, "ddd"),
                minC: parseFloat(d.mintempC) || 0,
                maxC: parseFloat(d.maxtempC) || 0,
                icon: root.iconFor(parseInt(noon.weatherCode) || 0, true),
                description: (noon.weatherDesc?.[0]?.value ?? "").trim(),
                precipChance: chance,
                sunriseAt: root.parseClock(a?.sunrise, at),
                sunsetAt: root.parseClock(a?.sunset, at)
            };
        });

        root.hourly = (days[0].hourly ?? []).map(h => {
            const t = parseInt(h.time) || 0;
            const hh = Math.floor(t / 100);
            const mm = t % 100;
            const code = parseInt(h.weatherCode) || 0;
            const at = new Date(day0);
            at.setHours(hh, mm, 0, 0);
            const rise = root.wttrSunrise, set = root.wttrSunset;
            const lit = !root.isDate(rise) || !root.isDate(set) || (at >= rise && at < set);
            return {
                time: Qt.formatDateTime(at, "hh:mm"),
                tempC: parseFloat(h.tempC) || 0,
                icon: root.iconFor(code, lit),
                precipChance: Math.max(parseInt(h.chanceofrain) || 0, parseInt(h.chanceofsnow) || 0)
            };
        });

        root.lastUpdated = fetchedAt;
        // Chained here, and deliberately not from onLatitudeChanged: the two
        // coordinates are assigned one after the other, so a handler on either
        // one fires while the other is still zero and asks Open-Meteo about a
        // point in the Bay of Biscay. Measured -- it put sunset 47 minutes
        // late, which is exactly the longitude that was missing.
        meteo.start();
        return true;
    }

    // Applies an Open-Meteo daily document: the fourth and fifth day wttr.in
    // will not give, and a dated sunrise and sunset for each of them.
    function applyMeteo(doc: var): bool {
        const d = doc?.daily;
        if (!d?.time || d.time.length === 0)
            return false;
        root.meteoDays = d.time.map((iso, i) => {
            const at = new Date(`${iso}T12:00:00`);
            const wwo = root.wwoForWmo(parseInt(d.weather_code?.[i]) || 0);
            return {
                date: iso,
                dayName: Qt.formatDateTime(at, "ddd"),
                minC: d.temperature_2m_min?.[i] ?? 0,
                maxC: d.temperature_2m_max?.[i] ?? 0,
                icon: root.iconFor(wwo, true),
                description: "",
                precipChance: d.precipitation_probability_max?.[i] ?? 0,
                // Open-Meteo answers local wall-clock with `timezone=auto`, and
                // a bare ISO string with no zone parses as local time.
                sunriseAt: new Date(d.sunrise?.[i] ?? ""),
                sunsetAt: new Date(d.sunset?.[i] ?? "")
            };
        });
        const h = doc?.hourly;
        root.meteoHours = (h?.time ?? []).map((iso, i) => {
            // "2026-09-25T15:00", local wall-clock, taken apart by hand for
            // the same reason as everywhere else: `Date` need not parse it.
            const m = iso.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/);
            const wwo = root.wwoForWmo(parseInt(h.weather_code?.[i]) || 0);
            return {
                at: m ? new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]) : new Date(NaN),
                tempC: h.temperature_2m?.[i] ?? 0,
                icon: root.iconFor(wwo, (h.is_day?.[i] ?? 1) === 1)
            };
        }).filter(x => root.isDate(x.at));
        return true;
    }

    function writeCache(): void {
        cache.setText(JSON.stringify({
            fetchedAt: root.lastUpdated,
            data: wttrDoc,
            meteo: meteoDoc
        }));
    }

    // Kept so the cache can be rewritten when the second provider answers
    // without re-parsing what the first one said.
    property var wttrDoc: null
    property var meteoDoc: null

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Timer {
        running: true
        interval: root.refreshInterval
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Pinning or clearing the location in shell.json should not wait out the
    // rest of a fifteen-minute cycle.
    onQueryChanged: refresh()

    Process {
        id: fetch

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return;
                let doc = null;
                try {
                    doc = JSON.parse(text);
                } catch (e) {
                    // wttr.in answers plain text when it is overloaded or does
                    // not recognise the location, so a parse failure is the
                    // normal shape of "no data", not a bug.
                    root.error = "Weather service returned no data";
                    return;
                }
                if (!root.applyWttr(doc, Date.now())) {
                    root.error = "Weather response was incomplete";
                    return;
                }
                root.error = "";
                root.wttrDoc = doc;
                root.writeCache();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.error = text.trim().split("\n")[0];
            }
        }

        onExited: code => {
            root.loading = false;
            // Anything already on screen stays there; only the reason changes.
            if (code !== 0 && !root.error)
                root.error = `Could not reach wttr.in (curl ${code})`;
        }
    }

    Process {
        id: meteo

        function start(): void {
            if (running || (root.latitude === 0 && root.longitude === 0))
                return;
            command = ["curl", "-sS", "--compressed", "--max-time", "20", `https://api.open-meteo.com/v1/forecast?latitude=${root.latitude}&longitude=${root.longitude}&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max&hourly=temperature_2m,weather_code,is_day&forecast_hours=24&timezone=auto&forecast_days=5`];
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return;
                try {
                    const doc = JSON.parse(text);
                    if (root.applyMeteo(doc)) {
                        root.meteoDoc = doc;
                        root.writeCache();
                    }
                } catch (e) {
                    // The four-day strip simply stays at three days; nothing
                    // else in the card depends on this provider.
                }
            }
        }

        stderr: StdioCollector {}
    }

    // --- disk cache -----------------------------------------------------
    //
    // Loaded once at startup and never reloaded: after that the in-memory
    // values are always at least as fresh as the file, and this singleton is
    // the only thing that writes it.
    //
    // Read before the first frame (`blockLoading`), because the sunset comes
    // from here, and the palette's evening warmth from the sunset: read a
    // moment later, a shell started at night opened in the day's colours and
    // warmed a second in.
    FileView {
        id: cache

        path: root.cachePath
        blockLoading: true
        // A first run has no cache, and that is not an error worth logging.
        printErrors: false
        atomicWrites: true

        onLoaded: root.readCache(text())

        onSaveFailed: {
            // Almost always a missing ~/.local/state/vela on a fresh install.
            mkdir.running = true;
        }
    }

    Process {
        id: mkdir

        command: ["mkdir", "-p", root.cacheDir]
        // Only the directory is created here; the next successful fetch writes
        // the file. Retrying the write immediately would race the mkdir.
    }

    function readCache(text: string): void {
        // A response that has since arrived over the network wins; this only
        // ever fills an empty screen. Read once, however it gets here.
        if (root.lastUpdated > 0 || root.cacheRead || !text)
            return;
        root.cacheRead = true;
        try {
            const wrapper = JSON.parse(text);
            if (root.applyWttr(wrapper.data, wrapper.fetchedAt ?? 0))
                root.wttrDoc = wrapper.data;
            if (wrapper.meteo && root.applyMeteo(wrapper.meteo))
                root.meteoDoc = wrapper.meteo;
        } catch (e) {
            // A truncated cache is disposable; the fetch already in flight
            // will replace it.
        }
    }

    property bool cacheRead: false

    Component.onCompleted: {
        root.readCache(cache.text());
        mkdir.running = true;
    }
}
