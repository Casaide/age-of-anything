#!/bin/sh
# Writes mods/big_battle/data/maps/open_field.json, the big-battle and trailer field: a wide clear middle between the starts, framed by a
# river on one flank, a hill with slopes on the other, groves, rocks and a ruin. (A map is data; this draws its rows.)
cd "$(dirname "$0")/../.." || exit 1
awk 'BEGIN {
  n = 160
  print "{\n \"schema\": \"aow.map/2\",\n \"id\": \"open_field\",\n \"name\": \"Open Field\",\n \"width\": " n ",\n \"height\": " n ","
  print " \"legend\": {\n  \".\": \"grass\",\n  \"T\": \"tree\",\n  \"#\": \"rock\",\n  \"r\": \"rubble\",\n  \"R\": \"river\",\n  \"D\": \"deep_river\",\n  \"v\": \"reeds\",\n  \"s\": \"stone\",\n  \"g\": \"gold\",\n  \"b\": \"bugbush\"\n },"
  # the groves: scattered, of all sizes
  srand(2026); groves = 90
  for (g = 0; g < groves; g++) { gcx[g] = int(rand() * n); gcy[g] = int(rand() * n); gr[g] = 6 + int(rand() * 40) }
  for (y = 0; y < n; y++) {
    line = ""; hill = ""
    for (x = 0; x < n; x++) {
      u = x - y                         # across the field (the starts lie on u = 0)
      v = x + y                         # along it
      w = int(5 * sin(v * 0.07) + 3 * sin(v * 0.19))  # the river and the hill wander
      noise = (x * 7 + y * 13 + x * y) % 11
      c = "."
      h = "0"
      if (u >= 92 + w && u < 100 + w) c = "D"
      else if (u >= 88 + w && u < 104 + w) c = "R"
      else if (u >= 80 + w && u < 88 + w && noise < 4) c = "v"
      else if (u > 104 + w && noise < 7) c = "T"
      if (u <= -82 + w) h = "1"
      else if (u <= -74 + w) h = "a"
      if (u < -110 + w && noise < 7) c = "T"
      # groves along both flanks, rocks among them
      if (c == "." && (u > 58 || u < -58)) {
        for (g = 0; g < groves; g++) {
          if ((x - gcx[g]) * (x - gcx[g]) + (y - gcy[g]) * (y - gcy[g]) < gr[g] + noise) c = (g % 5 == 0 && noise < 6) ? "#" : "T"
        }
      }
      # and behind each start the forest closes it off
      if (c == "." && (v < 26 + noise || v > 292 - noise)) c = "T"
      # a ruin on the near flank
      if (u >= 54 && u < 64 && v >= 150 && v < 172 && (noise < 5 || u == 54 || v == 150)) c = "r"
      # stone, gold and berries behind each start
      if ((x >= 14 && x < 18 && y >= 24 && y < 28) || (x >= 142 && x < 146 && y >= 132 && y < 136)) c = "s"
      if ((x >= 24 && x < 28 && y >= 14 && y < 18) || (x >= 132 && x < 136 && y >= 142 && y < 146)) c = "g"
      if ((x >= 18 && x < 21 && y >= 18 && y < 21) || (x >= 139 && x < 142 && y >= 139 && y < 142)) c = "b"
      line = line c
      hill = hill h
    }
    rows[y] = line; hills[y] = hill
  }
  print " \"rows\": ["
  for (y = 0; y < n; y++) printf "  \"%s\"%s\n", rows[y], (y < n - 1 ? "," : "")
  print " ],\n \"heights\": ["
  for (y = 0; y < n; y++) printf "  \"%s\"%s\n", hills[y], (y < n - 1 ? "," : "")
  print " ],\n \"starts\": [\n  [\n   30,\n   30\n  ],\n  [\n   129,\n   129\n  ]\n ]\n}"
}' > mods/big_battle/data/maps/open_field.json
