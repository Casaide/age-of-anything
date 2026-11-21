-- The marketplace, as in the genre (#43): the player picks one good to give and one to get, and how many trades. Serfs
-- bring the good given; once enough of it is in for one trade, the market swaps it for one of the good got, and serfs
-- carry that to the storehouse. No one works there. A trade's rate follows what each good is worth, as the genre
-- reckons it (a good's worth is the time it takes to get: a raw good its gathering time, a made good what goes into it
-- plus the time to make it, split over what comes out), and the market keeps its cut: tradeoff_pct of the worth given
-- for the worth got (the genre's 2.2, rules economy.market). Switched on by a building type with "market": true.
-- Its orders (the panel's, game/market.lobster): MARKET_SET (ids {market}, give + 1, get + 1: 0 for none) and
-- MARKET_MORE (ids {market}, how many more trades, or fewer).

MARKET_SET = 140
MARKET_MORE = 141

local mk = (rules().economy or {}).market or {}
local tradeoff = mk.tradeoff_pct or 220
local most = mk.most_orders or 99

local col_give = building_column("m_give")  -- 1 + the good it takes for a trade, 0 for none
local col_get = building_column("m_get")    -- 1 + the good it gives for one
local col_left = building_column("m_left")  -- trades still ordered
local col_paid = building_column("m_paid")  -- of the good it takes, how much is in (taken out of its hold as it comes)
local col_rate = building_column("m_rate")  -- how many of the good it takes one trade costs (for the panel; 0 unset)

local is_market = {}
for k = 0, building_type_count() - 1 do is_market[k + 1] = building_type(k).market == true end

-- Each good's worth (index + 1), in ticks: raw goods their gathering time, made goods what goes in and the time, over
-- what comes out. Made goods are reckoned again till nothing changes (a chain several deep).
local worth = {}
for name, t in pairs((rules().economy or {}).gather_ticks or {}) do
  local r = resource_index(name)
  if r >= 0 and type(t) == "number" then worth[r + 1] = t end
end
for _ = 1, 6 do
  for k = 0, building_type_count() - 1 do
    local m = building_type(k).makes
    if m and m["in"] and m.out then
      local cost = (m.time or 0) * TICK_HZ
      local known = true
      for name, n in pairs(m["in"]) do
        if n > 0 then
          local v = worth[resource_index(name) + 1]
          if v then cost = cost + v * n else known = false end
        end
      end
      local outs = 0
      for _, n in pairs(m.out) do outs = outs + n end
      if known and outs > 0 then
        for name, n in pairs(m.out) do
          if n > 0 then worth[resource_index(name) + 1] = math.max(1, cost // outs) end
        end
      end
    end
  end
end

-- How many of good give (index) one of good get costs at the market: at least one.
function market_rate(give, get)
  local a, b = worth[give + 1], worth[get + 1]
  if not a or not b then return 0 end
  return math.max(1, (b * tradeoff + a * 100 - 1) // (a * 100))
end

function market_tradable(r) return worth[r + 1] ~= nil end

local function stop_asking(b, r)
  local w = b_want(b, r)
  if w > 0 then want(b, r, -w) end
end

-- The player's orders for their own finished market.
function market_order(code, p, ids, x, y)
  if code ~= MARKET_SET and code ~= MARKET_MORE then return end
  local b = building_index(ids[1] or -1)
  if b < 0 or b_owner(b) ~= p or b_done(b) == 0 or not is_market[b_kind(b) + 1] then return end
  if code == MARKET_SET then
    local give, get = x - 1, y - 1
    if give >= resource_count() or get >= resource_count() then return end
    if give >= 0 and (give == get or not market_tradable(give)) then return end
    if get >= 0 and not market_tradable(get) then return end
    local was = building_get(col_give, b) - 1
    if was >= 0 and was ~= give then  -- what was paid of the old good goes back out, for the serfs to take home
      stop_asking(b, was)
      hold_put(b, was, building_get(col_paid, b))
      building_set(col_paid, b, 0)
    end
    building_set(col_give, b, give + 1)
    building_set(col_get, b, get + 1)
  else
    building_set(col_left, b, math.max(0, math.min(most, building_get(col_left, b) + x)))
  end
end

-- Each tick (before the carriers'): what's come of the good given is taken in as paid (so it's never sent back out),
-- a trade is made once enough is paid and there's room for what it gets, and the market asks for what it still needs,
-- one more than that while trades are left (so a delivery is never mistaken for goods to send home, creel #144).
function market_tick()
  for b = 0, building_count() - 1 do
    if b_done(b) ~= 0 and is_market[b_kind(b) + 1] then
      local give, get, left = building_get(col_give, b) - 1, building_get(col_get, b) - 1, building_get(col_left, b)
      if give >= 0 then
        local paid = building_get(col_paid, b) + hold_take(b, give, b_hold(b, give))
        local need = 0
        if get >= 0 then need = market_rate(give, get) end
        building_set(col_rate, b, need)
        if get >= 0 and left > 0 and paid >= need and hold_put(b, get, 1) == 1 then
          paid = paid - need
          left = left - 1
          building_set(col_left, b, left)
        end
        building_set(col_paid, b, paid)
        if get >= 0 and left > 0 then
          local lack = need - paid + 1 - b_want(b, give) - b_coming(b, give)
          if lack > 0 then want(b, give, lack) end
        else
          stop_asking(b, give)
        end
      end
    end
  end
end
