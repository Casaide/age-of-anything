// How the fog looks, as the view draws it today: never-seen land near black, seen-before land dimmed, and only
// trees showing where never seen.

let FOG_SEEN = 2  // fog[p][c]: 0 never seen, 1 seen before, 2 in sight (lib/fog.lobster)

def fog_in_sight(f:int) -> bool: return f == FOG_SEEN

def fog_ground_shade(f:int) -> float: return if f == 0: 0.12 elif f == 1: 0.55 else: 1.0

def fog_dark(f:int) -> float: return if f == 0: 0.88 elif f == 1: 0.45 else: 0.0

def fog_prop_shade(f:int) -> float: return if f == 0: 0.3 elif f == 1: 0.6 else: 1.0

def fog_shows_land(f:int) -> bool: return f != 0
