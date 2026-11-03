// ------------------------------------------------------------------ the counter chain (D-199)
// The counter chain: infantry > spear > large and mounted > ranged > infantry, and skirmishers > archers. Horse
// archers fall to the large line and to scouts, who catch them (Dominic, 2026-11-03: the genre's way), not to spears.
// (Not skirmishers > infantry: the roster gives swords +3 against skirmishers, who are for archers.)
// [counter, countered, the tag the countered unit needs for this to be the counter]. test_sim and calibrate.lobster
// check each pair on its own: a strong pair can't carry a weak one.
let RR_COUNTERS = [ [ "infantry", "spear", "spear" ], [ "spear", "large", "large" ], [ "spear", "scout", "mounted" ],
                    [ "skirmisher", "mounted_archer", "archer" ], [ "large", "mounted_archer", "ranged" ], [ "scout", "mounted_archer", "archer" ],
                    [ "large", "archer", "ranged" ], [ "large", "skirmisher", "ranged" ],
                    [ "scout", "skirmisher", "skirmish" ], [ "archer", "infantry", "infantry" ], [ "archer", "spear", "infantry" ],
                    [ "skirmisher", "archer", "archer" ] ]
let RR_COUNTER_PROMPTS = [ "angry swamp frogs with reed spears", "sewer rats with cheese hammers", "centaur romans",
                           "greek hoplites", "royal knights", "viking beetle riders" ]
// Pairs the chain asks for that the fights don't give at calibrated prices with the soldiers' research (D-200;
// Dominic's call, docs/backlog.md): in age 2 crossbows and giants on foot turn the large line's fights with archers.
// calibrate.lobster pairs reports them without failing.
let RR_COUNTERS_OPEN = [ "large>archer" ]
