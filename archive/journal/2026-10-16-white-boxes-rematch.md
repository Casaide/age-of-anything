# 2026-10-16: White boxes on the second match

**Milestone:** 20 (Steam Deck and controllers), a bug from the Deck
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic, on the Deck: start a match, leave it, start a new one, and the new one comes up very fast with
everything as white squares. "Seems we didn't generate the art."

The art was there. The part sprites live in one static cache (`PartShape.baked`) that only ever grew: every race the
lobby baked (each reroll's too) and every match before stayed in it, and each match packed all of it into one
atlas 2048 px wide. A script that plays lobby, match, menu, three times over measured the atlas at 11770, 12497
and 13699 px tall. GPUs take textures up to 16384 px (the Deck's and a Mac's limit). Past that the upload fails
("Texture dimensions exceed device maximum"), leaving an empty texture, and every unit, building and prop drawn from
the atlas shows white. The new match was fast because its art really was baked already.

- **A match keeps its own parts.** `ArtKit._keep_parts`, at the start of `prepare`, drops every part sprite the
  match's races and animals don't use. A dropped part that's asked for again (back in the lobby) loads from the bake
  cache on disk. Atlas height now follows the match: 11530, 11050, 6084 px over three rematches.
- **A wider atlas.** 4096 px wide instead of 2048, so one match's atlas is about 3300 to 5600 px tall, far from
  the limit. `build_atlas` asserts if it ever reaches 16384 again, instead of drawing white.

## Pictures
- `14-third-match-art-ok.png`: the third match in a row, its art drawn (desktop never showed the white; the
  atlas hadn't reached the limit there in three rounds).

## Funny moments
- "Starts really fast" was the clue: the art was all baked, it just couldn't be drawn.
