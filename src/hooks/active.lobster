// ------------------------------------------------------------------ the hook points
// Where the engine calls game code: plain ints and lists in and out, so what runs behind them can change (#234). The
// sim calls these names only. A program that plays by other rules imports its own file with these names instead.

// The state these rules keep is declared here, at the match start (hook_declare_unit, hook_declare_player,
// hook_declare_building).
def hook_declare():
    eco_declare()
    hunger_declare()

// A blow or shot is about to land on unit slot `target` from unit id `by`: the damage it does.
def hook_on_hit(by:int, target:int, damage:int) -> int: return damage

// After the tick's blows: unit slot `target` is still alive and was hurt, last by unit id `by`.
def hook_on_hurt(target:int, by:int): game_on_hurt(target, by)

// Unit slot `i` is dying, last hurt by unit id `killer`, and it's still there to read.
def hook_on_death(i:int, killer:int): game_on_death(i, killer)

// Each tick, for each unit whose type asks ("tick": true in its row of the table).
def hook_unit_tick(i:int): return

// Once a tick, after the economy's steps: births in homes (hooks/economy), eating (hooks/hunger).
def hook_tick():
    homes_tick()
    hunger_tick()

// Whether player p may put a building of type k at cx, cy (its size sx, sy), once the engine's own checks pass.
def hook_can_place(p:int, k:int, cx:int, cy:int, sx:int, sy:int) -> bool: return eco_can_place(p, k, cx, cy, sx, sy)

// An order with a code from HOOK_ORDER_BASE up. ids: the unit ids it was given to; x, y: its two arguments.
def hook_on_order(code:int, p:int, ids:[int], x:int, y:int): return

// What a bot makes of training type k of this slot: `score` is its counter-pick's.
def hook_ai_train_score(p:int, slot:string, k:int, score:int) -> int: return game_ai_train_score(p, slot, k, score)
