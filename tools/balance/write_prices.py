#!/usr/bin/env python3
"""Put calibrated price points into the data, keeping its formatting (D-186).

Usage (from the repo root): python3 tools/balance/write_prices.py [build/calibrate/prices.json]

prices.json is {part id or "slot:<slot>": price points}, from `lobster calibrate.lobster -- fit write`
(src/calibrate.lobster). A part's go in data/parts.json: one whose price is its points and has no price_points
is left alone; otherwise its price_points is set (replaced in place, or added right after its points, with the
same spacing). A slot's go on that line of the roster in every data/rules/*.json (added after its "slot"),
"size:giant" and "size:tiny" in their cost as giant_price_points and tiny_price_points (what a tiny one takes off).
"""
import glob
import json
import sys


def spans(text, i=0):
    """Each element's (start, end) of the array that starts at i."""
    out, depth, start, in_str = [], 0, None, False
    while i < len(text):
        c = text[i]
        if in_str:
            if c == "\\":
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c in "[{":
            depth += 1
            if depth == 2:
                start = i
        elif c in "]}":
            if depth == 2:
                out.append((start, i + 1))
            depth -= 1
            if depth == 0:
                break
        i += 1
    return out


def top_keys(obj):
    """Each depth-1 key of an object's text: name -> (key start, value start, value end)."""
    keys, depth, i, in_str, key_at = {}, 0, 0, False, None
    while i < len(obj):
        c = obj[i]
        if in_str:
            if c == "\\":
                i += 1
            elif c == '"':
                in_str = False
                if depth == 1 and key_at is not None:
                    j = i + 1
                    while obj[j] in " \t\n":
                        j += 1
                    if obj[j] == ":":
                        name = obj[key_at + 1:i]
                        v = j + 1
                        while obj[v] in " \t\n":
                            v += 1
                        e = v
                        while obj[e] not in ",}\n ":
                            e += 1
                        keys[name] = (key_at, v, e)
                key_at = None
        elif c == '"':
            in_str = True
            key_at = i
        elif c in "[{":
            depth += 1
        elif c in "]}":
            depth -= 1
        i += 1
    return keys


def price_edits(text, elements, want_of, after):
    """The edits that set each element's price_points to want_of(element) (None: leave it), added after `after`."""
    edits = []
    for s, e in elements:
        obj = text[s:e]
        want = want_of(json.loads(obj))
        if want is None:
            continue
        keys = top_keys(obj)
        if "price_points" in keys:
            _, v, ve = keys["price_points"]
            if int(obj[v:ve]) != want:
                edits.append((s + v, s + ve, str(want)))
        else:
            k, _, pe = keys[after]
            gap = k
            while obj[gap - 1] in " \t\n":
                gap -= 1
            edits.append((s + pe, s + pe, "," + obj[gap:k] + '"price_points": ' + str(want)))
    return edits


def apply(path, text, edits):
    for a, b, new in sorted(edits, reverse=True):
        text = text[:a] + new + text[b:]
    json.loads(text)
    open(path, "w").write(text)
    print(f"{len(edits)} prices changed in {path}")


def main():
    prices = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "build/calibrate/prices.json"))
    path = "data/parts.json"
    text = open(path).read()

    def part_want(p):
        want = prices.get(p["id"])
        if want is None or ("price_points" not in p and want == p["points"]):
            return None
        return want
    apply(path, text, price_edits(text, spans(text), part_want, "points"))
    for path in sorted(glob.glob("data/rules/*.json")):
        text = open(path).read()
        at = text.index('"roster"')
        def slot_want(sd):
            want = prices.get("slot:" + sd["slot"])
            if want is None or ("price_points" not in sd and want == 0):
                return None
            return want
        edits = price_edits(text, spans(text, text.index("[", at)), slot_want, "slot")
        cost = text.index("{", text.index('"cost"'))
        keys = top_keys(text[cost:])
        for size, key, sign in [("giant", "giant_price_points", 1), ("tiny", "tiny_price_points", -1)]:
            if "size:" + size not in prices:
                continue
            want = sign * prices["size:" + size]
            if key in keys:
                _, v, ve = keys[key]
                if int(text[cost + v:cost + ve]) != want:
                    edits.append((cost + v, cost + ve, str(want)))
            else:
                k, _, be = keys["base"]
                gap = k
                while text[cost + gap - 1] in " \t\n":
                    gap -= 1
                edits.append((cost + be, cost + be, "," + text[cost + gap:cost + k] + '"' + key + '": ' + str(want)))
        apply(path, text, edits)


main()
