# Milestone 19: UI that feels like the game

**Status:** planned (proposed 2026-10-12; concept round can start any time)
**Exit criterion:** the menu, lobby, loaders, HUD, tech tree page and end screens look designed and
finished, not flat; the UI wears your race's culture; every wait shows something worth watching;
Dominic: "this looks like a real game".

Dominic (2026-10-12): "lobby looks really cheap, our UI in general needs some work, and I thought
the milestone said we'd adjust UI for each race? It looks very lazy and flat at the moment." And:
"'baking the art' needs to be replaced with a proper game loader that shows the armies that were
generated during the lobby. The lobby also needs proper loaders for army generation and the dice
roll." The per-race UI was planned in the art and UI track (A3: "the UI picks up the race's
culture: colours, frames, small ornaments") and never built.

Done already (2026-10-12): the dice above a big empty prompt box, every side rolled on entry, no
presets menu; a fixed-width centre with a bigger map.

## Scope

1. **A UI look of our own** (concept round first, D-080: 3-4 directions at real size, Dominic
   picks): materials and depth instead of flat panels (carved wood, hammered bronze, parchment,
   stone, by direction), a type pairing (a display face for titles, a readable text face; our own
   or open-licence fonts), ornaments, button states with weight, transitions and sounds. A theme
   resource the whole UI shares, so one change reaches every screen.
2. **The UI wears the race.** Per culture (data in `data/families.json`, a `ui` block): frame
   material and colour, an ornament (reeds and lily pads for swamp, bottle caps and rivets for
   sewer, laurels and marble for imperial, felt and stitching for steppe...), accent colour, a
   banner shape. The HUD, panel, tooltips, tech tree page and the lobby banner of each side take
   that side's look; the neutral look is for menus.
3. **Loaders.**
   - **Match loader** (replaces "Baking the art..."): the two armies generated in the lobby on a
     stage facing each other, race names and the map, a progress bar fed by the real bake steps,
     a tip line; the match fades in from it.
   - **Lobby generation:** the dice tumbles while a race is generated and baked (a real
     animation, a sound), the banner's army fades in when ready; typing shows a "forging" state
     on the stage instead of stale art.
4. **Lobby redesign** (production quality): the two banners as the race's own banner (culture
   look), the army stage bigger and lit, the roster as cards with portraits and roles, the race's
   bonuses and hero (milestone 14) shown, the map card with a real minimap render and its notes,
   match rules (milestone 18) in a card, Start as the centrepiece; nothing moves when content
   changes.
5. **Menu, pause and end screens:** a title screen with life (a battle scene behind it), the pause
   menu, win/lose screens with the match's story (armies, losses, timeline).
6. **HUD pass:** the top bar, command panel, unit card, minimap frame and tooltips in the new look
   and the race's look; readable at the UI sizes from 40% to 100%.
7. **The tech tree page** in the new look (the race's banner on its panel).

## Plan
1. Concept round: 3-4 UI directions, each shown as the lobby and the in-match HUD (mock renders),
   one culture variant each; Dominic picks.
2. Theme resource and type; the neutral look on menus and the lobby.
3. Loaders (match and lobby): they're the most-seen screens.
4. Per-culture UI looks (data + art for each culture), on the HUD and banners.
5. Lobby redesign; menus, pause, end screens.
6. HUD and tech tree pass; UI-size check at 40-100%.
7. A Fable-style review of every screen (as milestone 11's exit), fixes, Dominic's look.

## Checklist
- [ ] Plan approved by Dominic
- [ ] 1. Concept round (Dominic's pick)
- [ ] 2. Theme and type
- [ ] 3. Match loader, lobby loaders
- [ ] 4. The UI wears the race
- [ ] 5. Lobby, menus, pause, end screens
- [ ] 6. HUD and tech tree
- [ ] 7. Review and fixes
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

## Results

## Changes from the original plan

## Links
- `art-ui-track.md` (A3: race select and menus taking the culture's look)
- `m11-cleanup.md` phase 6 (the first lobby), `m14-race-identity.md` (heroes on the lobby card),
  `m18-match-rules.md` (the rules card)
