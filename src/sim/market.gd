extends RefCounted
## The market: goods traded for gold, a lot at a time, at prices everyone shares. Buying
## pushes a price up and selling pushes it down, so a flooded market pays less (the genre's
## way). Prices are gold per lot; selling pays less than buying costs. Integers only.

const LOT := 100           # goods per trade
const START := 100         # gold per lot at the start
const STEP := 5            # a trade moves the price this much
const LOW := 20
const HIGH := 500
const SELL_PCT := 75       # selling a lot pays this share of its price


static func setup(w) -> void:
	w.market_price = PackedInt32Array()
	for res in w.resources:
		w.market_price.append(0 if res == "gold" else START)


## What one trade would cost (buy) or pay (sell) in gold right now.
static func quote(w, r: int, buy: bool) -> int:
	return w.market_price[r] if buy else w.market_price[r] * SELL_PCT / 100


## The reason a player can't make this trade, or "" if they can.
static func why_not(w, player: int, b: int, r: int, buy: bool) -> String:
	if b < 0 or w.buildings.owner[b] != player or w.buildings.done[b] == 0 \
			or w.btypes[w.buildings.kind[b]].id != "market":
		return "needs a finished market"
	if r < 0 or w.resources[r] == "gold":
		return "gold isn't traded"
	var g: int = w.resources.find("gold")
	if buy and w.stock[g][player] < quote(w, r, true):
		return "not enough gold"
	if not buy and w.stock[r][player] < LOT:
		return "not enough to sell"
	return ""


static func cmd_trade(w, player: int, a: Dictionary) -> void:
	var b: int = w.buildings.index_of(int(a.building))
	var r: int = w.resources.find(String(a.resource))
	var buy: bool = int(a.buy) == 1
	if why_not(w, player, b, r, buy) != "":
		return
	var g: int = w.resources.find("gold")
	if buy:
		w.stock[g][player] -= quote(w, r, true)
		w.stock[r][player] += LOT
		w.market_price[r] = mini(HIGH, w.market_price[r] + STEP)
	else:
		w.stock[r][player] -= LOT
		w.stock[g][player] += quote(w, r, false)
		w.market_price[r] = maxi(LOW, w.market_price[r] - STEP)
