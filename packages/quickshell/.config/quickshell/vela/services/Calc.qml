pragma Singleton

import QtQuick
import Quickshell

// Answers typed into the launcher: sums, and conversions between units.
//
//     12*7              84
//     sqrt(2)/2         0.707106781187
//     200 * 15%         30
//     5 km in mi        3.106856 mi
//     100 f to c        37.77778 °C
//     2^10 mb in gib    0.9536743 GiB
//
// A small recursive-descent parser rather than `eval` or `Function`: the
// launcher hands over whatever was typed, and a parser that knows numbers,
// five operators and a short list of functions cannot be talked into running
// anything else. It is also what lets the launcher ask "is this a sum at all?"
// before it spends a row on the answer -- a bare number, a unary minus or an
// unknown word is not.
//
// Pure: nothing here holds state, so the launcher can ask on every keystroke.
Singleton {
    id: root

    // Radians, as in every programming language; `30deg` is there for
    // somebody who thinks in degrees.
    readonly property var functions: ({
            sqrt: Math.sqrt,
            cbrt: Math.cbrt,
            abs: Math.abs,
            round: Math.round,
            floor: Math.floor,
            ceil: Math.ceil,
            sin: Math.sin,
            cos: Math.cos,
            tan: Math.tan,
            asin: Math.asin,
            acos: Math.acos,
            atan: Math.atan,
            ln: Math.log,
            log: Math.log10,
            log10: Math.log10,
            log2: Math.log2,
            exp: Math.exp
        })
    readonly property var constants: ({
            pi: Math.PI,
            π: Math.PI,
            tau: 2 * Math.PI,
            e: Math.E,
            deg: Math.PI / 180
        })

    // ---- units ---------------------------------------------------------------
    //
    // Every spelling of a unit maps to its quantity and its size in that
    // quantity's base unit (metres, kilograms, litres, seconds, bytes, metres
    // a second, square metres, degrees). Temperature has no single factor and
    // is handled apart. Data is decimal unless it says otherwise: "mb" is what
    // people type for megabytes, and the binary sizes are spelled "mib".
    readonly property var units: {
        const table = {};
        const add = (quantity, factor, symbol, names) => {
            for (const n of names)
                table[n] = {
                    quantity,
                    factor,
                    symbol
                };
        };
        add("length", 1e-9, "nm", ["nm", "nanometre", "nanometres", "nanometer", "nanometers"]);
        add("length", 1e-6, "µm", ["µm", "um", "micron", "microns"]);
        add("length", 0.001, "mm", ["mm", "millimetre", "millimetres", "millimeter", "millimeters"]);
        add("length", 0.01, "cm", ["cm", "centimetre", "centimetres", "centimeter", "centimeters"]);
        add("length", 1, "m", ["m", "metre", "metres", "meter", "meters"]);
        add("length", 1000, "km", ["km", "kilometre", "kilometres", "kilometer", "kilometers"]);
        add("length", 0.0254, "in", ["in", "inch", "inches", "\""]);
        add("length", 0.3048, "ft", ["ft", "foot", "feet", "'"]);
        add("length", 0.9144, "yd", ["yd", "yard", "yards"]);
        add("length", 1609.344, "mi", ["mi", "mile", "miles"]);
        add("length", 1852, "nmi", ["nmi", "nautical"]);

        add("mass", 1e-6, "mg", ["mg", "milligram", "milligrams"]);
        add("mass", 0.001, "g", ["g", "gram", "grams"]);
        add("mass", 1, "kg", ["kg", "kilo", "kilos", "kilogram", "kilograms"]);
        add("mass", 1000, "t", ["t", "tonne", "tonnes"]);
        add("mass", 0.028349523125, "oz", ["oz", "ounce", "ounces"]);
        add("mass", 0.45359237, "lb", ["lb", "lbs", "pound", "pounds"]);
        add("mass", 6.35029318, "st", ["st", "stone", "stones"]);

        add("volume", 0.001, "ml", ["ml", "millilitre", "millilitres", "milliliter", "milliliters"]);
        add("volume", 0.01, "cl", ["cl", "centilitre", "centilitres"]);
        add("volume", 0.1, "dl", ["dl", "decilitre", "decilitres"]);
        add("volume", 1, "l", ["l", "litre", "litres", "liter", "liters"]);
        add("volume", 1000, "m³", ["m3", "m³"]);
        add("volume", 0.00492892159375, "tsp", ["tsp", "teaspoon", "teaspoons"]);
        add("volume", 0.01478676478125, "tbsp", ["tbsp", "tablespoon", "tablespoons"]);
        add("volume", 0.0295735295625, "fl oz", ["floz"]);
        add("volume", 0.2365882365, "cup", ["cup", "cups"]);
        add("volume", 0.473176473, "pt", ["pt", "pint", "pints"]);
        add("volume", 0.946352946, "qt", ["qt", "quart", "quarts"]);
        add("volume", 3.785411784, "gal", ["gal", "gallon", "gallons"]);

        add("time", 0.001, "ms", ["ms", "millisecond", "milliseconds"]);
        add("time", 1, "s", ["s", "sec", "secs", "second", "seconds"]);
        add("time", 60, "min", ["min", "mins", "minute", "minutes"]);
        add("time", 3600, "h", ["h", "hr", "hrs", "hour", "hours"]);
        add("time", 86400, "d", ["d", "day", "days"]);
        add("time", 604800, "wk", ["wk", "week", "weeks"]);
        add("time", 31556952, "yr", ["yr", "yrs", "year", "years"]);

        add("data", 0.125, "bit", ["bit", "bits"]);
        add("data", 1, "B", ["b", "byte", "bytes"]);
        add("data", 1e3, "kB", ["kb", "kilobyte", "kilobytes"]);
        add("data", 1e6, "MB", ["mb", "megabyte", "megabytes"]);
        add("data", 1e9, "GB", ["gb", "gigabyte", "gigabytes"]);
        add("data", 1e12, "TB", ["tb", "terabyte", "terabytes"]);
        add("data", 1024, "KiB", ["kib"]);
        add("data", 1048576, "MiB", ["mib"]);
        add("data", 1073741824, "GiB", ["gib"]);
        add("data", 1099511627776, "TiB", ["tib"]);
        add("data", 125, "kbit", ["kbit", "kbits"]);
        add("data", 125000, "Mbit", ["mbit", "mbits"]);
        add("data", 125000000, "Gbit", ["gbit", "gbits"]);

        add("speed", 1, "m/s", ["m/s", "mps"]);
        add("speed", 1 / 3.6, "km/h", ["km/h", "kmh", "kph"]);
        add("speed", 0.44704, "mph", ["mph"]);
        add("speed", 1852 / 3600, "kn", ["kn", "kt", "knot", "knots"]);
        add("speed", 0.3048, "ft/s", ["ft/s", "fps"]);

        add("area", 1e-4, "cm²", ["cm2", "cm²"]);
        add("area", 1, "m²", ["m2", "m²", "sqm"]);
        add("area", 1e6, "km²", ["km2", "km²"]);
        add("area", 1e4, "ha", ["ha", "hectare", "hectares"]);
        add("area", 4046.8564224, "ac", ["ac", "acre", "acres"]);
        add("area", 0.09290304, "ft²", ["ft2", "ft²", "sqft"]);
        add("area", 0.00064516, "in²", ["in2", "in²", "sqin"]);

        add("angle", 1, "°", ["°", "degree", "degrees"]);
        add("angle", 180 / Math.PI, "rad", ["rad", "radian", "radians"]);
        add("angle", 360, "turn", ["turn", "turns"]);

        // Temperature: the factor is unused; `toKelvin` and `fromKelvin` do
        // the work.
        add("temperature", 0, "°C", ["c", "°c", "degc", "celsius", "centigrade"]);
        add("temperature", 0, "°F", ["f", "°f", "degf", "fahrenheit"]);
        add("temperature", 0, "K", ["k", "kelvin"]);
        return table;
    }

    // The Material Symbol each quantity's answer row carries.
    readonly property var symbols: ({
            length: "straighten",
            mass: "scale",
            volume: "water_drop",
            time: "schedule",
            data: "storage",
            speed: "speed",
            area: "square_foot",
            angle: "architecture",
            temperature: "thermostat"
        })

    function toKelvin(v: real, symbol: string): real {
        return symbol === "°C" ? v + 273.15 : symbol === "°F" ? (v - 32) * 5 / 9 + 273.15 : v;
    }

    function fromKelvin(v: real, symbol: string): real {
        return symbol === "°C" ? v - 273.15 : symbol === "°F" ? (v - 273.15) * 9 / 5 + 32 : v;
    }

    // ---- the launcher's question ---------------------------------------------

    // { value, text, copy, symbol } for something the launcher should answer,
    // or null: `text` is what the row shows, `copy` what enter puts on the
    // clipboard -- the number without its unit, ready to paste into a cell.
    // `loose` is the `=` prefix: the user has said it is a sum, so a bare
    // number is an answer too.
    function answer(text: string, loose: bool): var {
        const q = text.trim();
        if (!q)
            return null;

        const converted = root.convert(q);
        if (converted)
            return converted;

        const sum = root.evaluate(q);
        if (!sum || !isFinite(sum.value) || (!loose && sum.operations === 0))
            return null;
        const number = root.format(sum.value, 12);
        return {
            value: sum.value,
            text: number,
            copy: number,
            symbol: "calculate"
        };
    }

    // "5 km in mi", "5km to mi", "(2+3) kg as lb". The amount may be a sum.
    //
    // The unit is found by trying each place the amount could end, shortest
    // amount first, until what is left is a unit and what came before it is a
    // number: that is what splits "1e3m" into 1e3 and m rather than 1 and
    // "e3m", and lets "12 in in cm" mean inches.
    function convert(text: string): var {
        const m = text.match(/^(.+?)\s+(?:in|to|as|into|->|→|=)\s+(\S+)$/i);
        if (!m)
            return null;
        const to = root.units[m[2].toLowerCase()];
        if (!to)
            return null;

        const left = m[1].trim();
        let from = root.units[left.toLowerCase()];
        let amount = from ? 1 : NaN;
        for (let i = 1; !from && i < left.length; i++) {
            const unit = root.units[left.slice(i).trim().toLowerCase()];
            if (!unit)
                continue;
            const sum = root.evaluate(left.slice(0, i));
            if (sum && isFinite(sum.value)) {
                from = unit;
                amount = sum.value;
            }
        }
        if (!from || from.quantity !== to.quantity)
            return null;

        const value = from.quantity === "temperature" ? root.fromKelvin(root.toKelvin(amount, from.symbol), to.symbol) : amount * from.factor / to.factor;
        const number = root.format(value, 7);
        return {
            value,
            text: `${number} ${to.symbol}`,
            copy: number,
            symbol: root.symbols[from.quantity]
        };
    }

    // Twelve significant figures for a sum, which is past where binary
    // floating point stops being exact and so hides 0.1 + 0.2's tail; seven
    // for a conversion, whose factors are rarely known better than that.
    function format(value: real, digits: int): string {
        if (value === 0)
            return "0";
        const size = Math.abs(value);
        if (size >= 1e15 || size < 1e-9)
            return value.toExponential(Math.min(digits, 6) - 1).replace(/\.?0+e/, "e");
        return `${parseFloat(value.toPrecision(digits))}`;
    }

    // ---- the parser --------------------------------------------------------------
    //
    //     sum      := product (("+" | "-") product)*
    //     product  := unary (("*" | "/" | "mod") unary | <implicit ×> unary)*
    //     unary    := ("-" | "+") unary | power
    //     power    := postfix ("^" unary)?
    //     postfix  := atom ("!" | "%")*
    //     atom     := number | constant | function unary | "(" sum ")"
    //
    // `-2^2` is -4 and `2^-1` is 0.5, as on paper. `%` is per cent -- `200 *
    // 15%` is 30 -- because a desktop calculator is asked for a tip far more
    // often than a remainder; the remainder is `mod`. A number followed by a
    // bracket or a name multiplies (`2pi`, `3(4+5)`); two numbers side by
    // side do not, because "2 3" is more likely a typo than a product.

    // { value, operations } or null when the text is not a sum. `operations`
    // counts what makes it worth answering: operators and functions, not a
    // leading minus.
    function evaluate(text: string): var {
        const tokens = root.tokenize(text);
        if (!tokens || tokens.length === 0)
            return null;
        const state = {
            tokens,
            at: 0,
            operations: 0,
            failed: false
        };
        const value = root.parseSum(state);
        if (state.failed || state.at !== tokens.length)
            return null;
        return {
            value,
            operations: state.operations
        };
    }

    function tokenize(text: string): var {
        const tokens = [];
        // A comma between digits is a decimal comma, as a European keyboard
        // types it: nothing here takes two arguments, so it cannot be a
        // separator, and nobody types thousands separators into a sum.
        const s = text.replace(/[×·]/g, "*").replace(/÷/g, "/").replace(/−/g, "-").replace(/\*\*/g, "^").replace(/(\d),(\d)/g, "$1.$2");
        let i = 0;
        while (i < s.length) {
            const c = s[i];
            if (/\s/.test(c)) {
                i++;
                continue;
            }
            const number = s.slice(i).match(/^(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?/i);
            if (number) {
                tokens.push({
                    type: "number",
                    value: parseFloat(number[0])
                });
                i += number[0].length;
                continue;
            }
            const word = s.slice(i).match(/^(?:[a-z]+\d*|π)/i);
            if (word) {
                const w = word[0].toLowerCase();
                if (w === "mod")
                    tokens.push({
                        type: "op",
                        value: "mod"
                    });
                else if (root.functions[w])
                    tokens.push({
                        type: "function",
                        value: w
                    });
                else if (root.constants[w] !== undefined)
                    tokens.push({
                        type: "number",
                        value: root.constants[w],
                        constant: true
                    });
                else
                    return null;
                i += word[0].length;
                continue;
            }
            if ("+-*/^%!()".includes(c)) {
                tokens.push({
                    type: c === "(" || c === ")" ? c : "op",
                    value: c
                });
                i++;
                continue;
            }
            return null;
        }
        return tokens;
    }

    function peek(state: var): var {
        return state.tokens[state.at] ?? null;
    }

    function isOp(state: var, ...ops): bool {
        const t = root.peek(state);
        return !!t && t.type === "op" && ops.includes(t.value);
    }

    function parseSum(state: var): real {
        let value = root.parseProduct(state);
        while (!state.failed && root.isOp(state, "+", "-")) {
            const op = state.tokens[state.at++].value;
            const right = root.parseProduct(state);
            value = op === "+" ? value + right : value - right;
            state.operations++;
        }
        return value;
    }

    function parseProduct(state: var): real {
        let value = root.parseUnary(state);
        while (!state.failed) {
            const t = root.peek(state);
            if (root.isOp(state, "*", "/", "mod")) {
                state.at++;
                const right = root.parseUnary(state);
                value = t.value === "*" ? value * right : t.value === "/" ? value / right : value - right * Math.floor(value / right);
                state.operations++;
            } else if (t && (t.type === "(" || t.type === "function" || t.constant)) {
                value *= root.parseUnary(state);
                state.operations++;
            } else {
                break;
            }
        }
        return value;
    }

    function parseUnary(state: var): real {
        if (root.isOp(state, "-", "+")) {
            const op = state.tokens[state.at++].value;
            const value = root.parseUnary(state);
            return op === "-" ? -value : value;
        }
        return root.parsePower(state);
    }

    function parsePower(state: var): real {
        const base = root.parsePostfix(state);
        if (!state.failed && root.isOp(state, "^")) {
            state.at++;
            state.operations++;
            return Math.pow(base, root.parseUnary(state));
        }
        return base;
    }

    function parsePostfix(state: var): real {
        let value = root.parseAtom(state);
        while (!state.failed && root.isOp(state, "!", "%")) {
            const op = state.tokens[state.at++].value;
            value = op === "%" ? value / 100 : root.factorial(value);
            state.operations++;
        }
        return value;
    }

    function parseAtom(state: var): real {
        const t = root.peek(state);
        if (!t) {
            state.failed = true;
            return NaN;
        }
        state.at++;
        if (t.type === "number")
            return t.value;
        if (t.type === "function") {
            state.operations++;
            return root.functions[t.value](root.parseUnary(state));
        }
        if (t.type === "(") {
            const value = root.parseSum(state);
            if (root.peek(state)?.type !== ")") {
                state.failed = true;
                return NaN;
            }
            state.at++;
            return value;
        }
        state.failed = true;
        return NaN;
    }

    // Whole numbers only, and only as far as a double can hold the answer.
    function factorial(n: real): real {
        if (n < 0 || n > 170 || n !== Math.floor(n))
            return NaN;
        let out = 1;
        for (let i = 2; i <= n; i++)
            out *= i;
        return out;
    }
}
