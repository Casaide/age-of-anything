# Looking at what isn't yours (2026-11-06)

**What happened.** Dominic: "You can't click on enemy buildings to see how much health they have." Claude made a left click on
a visible enemy, ally or wild thing select it view-only: name, HP and portrait in the panel, a red ring on enemies, no orders (#218).

**Decisions.** Foreign units go in their own `sel_foreign`, not in `selected`, so every order path stays mine-only without a guard on
each one. A building must be seen now: one only remembered in the fog can't be clicked, or its live HP would leak. An enemy's
garrison and training stay hidden. The race goes on its own line, because "Severan Guard Town Center" ran out of the panel (Claude).

**Pictures.** `images/2026-11-06/06-enemy-building-panel-hp.png`, `07-enemy-unit-panel-hp.png`.

**Parked.** My own building still wins a click over an enemy unit standing in front of it.
