-- Steading's town rules, in Lua (Casaide/creel#82). Each is switched on in the rules file (rules/steading.json,
-- "economy") and off in any other match:
--   doors_on_roads: a building goes up only with the tile in front of its door on a road or its owner's road plan.
--   door_roads (with doors_on_roads): a building may go up with free ground at its door, and a road plan goes there the
--     tick after (the genre lays the road tile in front of a new building with it, #124).
--   foundation_pct (the engine's rule, creel #105): a site's first share is its foundation, built with no goods; its
--     builder then waits there, busy, till the goods are in (one at a site, and at most half its side's serfs).
--   doors_clear: a building never goes up over the tile in front of another's door, nor with its own door against one
--     (a road may: that's where a road goes). A town laid out by a child stays walkable to every door.
--   builders_come: a site with goods brought for more than is built gets an idle serf of its side, the nearest,
--     once a second; once all its goods are in, up to builders_per_site (1 if unset) at once. A serf with a site
--     that has work within NEXT goes there first (a road's next cell, #119). (The engine drops a site
--     whose builder can't get to it; this sends someone back too.)
--   idle_wait: an idle serf (a carrier slot, economy.carriers) with nothing to do walks back to its side's nearest
--     store and waits by it, rather than standing wherever its last job left it.

local LOOK = 20  -- ticks between looks (a second)
local WAIT = 2 * TILE  -- how far from a store's middle, past its half size, an idle serf may stand
local NEXT = 4 * TILE  -- how far from a builder a site with work may be for it to go there first (next_door)

local ec = rules().economy or {}
local doors = ec.doors_on_roads == true
local doors_clear = ec.doors_clear == true
local builders_come = ec.builders_come == true
local per_site = ec.builders_per_site or 1
local idle_wait = ec.idle_wait == true
local foundation = ec.foundation_pct or 0  -- the share of a site built before its goods are in (the engine's rule, #105)
local door_roads = doors and ec.door_roads == true

-- The road plan a door gets (door_roads): the first road type.
local road_kind = -1
for k = 0, building_type_count() - 1 do
  if road_kind < 0 and bt_road(k) >= 0 then road_kind = k end
end

-- Per unit type (k + 1): whether its units are serfs (a carrier slot).
local carrier_slots = {}
for _, s in ipairs(ec.carriers or {}) do carrier_slots[s] = true end
local serf = {}
for k = 0, unit_type_count() - 1 do serf[k + 1] = carrier_slots[t_slot(k)] == true end

-- The tile in front of a building's door (below its bottom edge's middle) is road, or the player's road plan. Roads
-- themselves, walls and gates, and ladders have no door.
local function door_on_road(p, k, cx, cy, sx, sy)
  if bt_road(k) >= 0 or bt_line(k) or bt_ladder(k) then return true end
  local dx = cx + sx // 2
  local dy = cy + sy
  if dy >= H then return false end
  local c = dy * W + dx
  if road(c) > 0 then return true end
  local b = building_index(occupied(c))
  if b >= 0 then return b_owner(b) == p and bt_road(b_kind(b)) >= 0 end
  return door_roads and road_kind >= 0 and fits(p, road_kind, dx, dy)  -- free ground: its road plan goes down with it
end

-- Whether a building of type k could have a door to keep clear: roads, walls and gates, and ladders have none.
local function has_door(k)
  return bt_road(k) < 0 and not bt_line(k) and not bt_ladder(k)
end

-- Neither does the footprint cover another building's door tile, nor is its own door tile in a building (a road
-- aside).
local function doors_kept_clear(k, cx, cy, sx, sy)
  if bt_road(k) >= 0 then return true end
  for b = 0, building_count() - 1 do
    if has_door(b_kind(b)) then
      local x0, y0, x1, y1 = building_rect(b)
      local dx = x0 // TILE + (x1 + 1 - x0) // TILE // 2  -- (as for a new one: below its bottom edge's middle)
      local dy = (y1 + 1) // TILE
      if dx >= cx and dx < cx + sx and dy >= cy and dy < cy + sy then return false end
    end
  end
  if not has_door(k) then return true end
  local dx = cx + sx // 2
  local dy = cy + sy
  if dy >= H then return false end
  local b = building_index(occupied(dy * W + dx))
  return b < 0 or bt_road(b_kind(b)) >= 0
end

function doors_can_place(p, k, cx, cy, sx, sy)
  if doors_clear and not doors_kept_clear(k, cx, cy, sx, sy) then return false end
  return not doors or door_on_road(p, k, cx, cy, sx, sy)
end

-- The nearest of these idle serfs (unit slots) to building b, taken out of the list; -1 if there's none.
local function take_nearest(idle, b)
  local best = -1
  local best_d2 = 1 << 50
  for j, i in ipairs(idle) do
    local d2 = mid_dist2(b, u_x(i), u_y(i))
    if d2 < best_d2 then
      best_d2 = d2
      best = j
    end
  end
  if best < 0 then return -1 end
  return table.remove(idle, best)
end

-- Whether site b has goods brought for more than is built: work for a builder now.
local function work_at(b)
  if b_done(b) ~= 0 or not b_is_site(b) then return false end
  local cap = foundation * 10 + (1000 - foundation * 10) * site_permille(b) // 1000  -- (as the engine caps it, #105)
  return b_progress(b) * 1000 < bt_build_ticks(b_kind(b)) * cap
end

-- Whether site b is still waiting on goods: a builder there waits with it (the genre's foundations: lay it, then wait).
local function waiting(b)
  return b_done(b) == 0 and b_is_site(b) and site_permille(b) < 1000
end

-- One look over the units: how many build each site (by slot + 1), and each side's idle serfs (in slot order). A
-- serf building a site with no work at it now (its goods not yet brought) stops, and is idle: a carrier the site
-- is waiting on, maybe; it's sent back once there's work again.
local function look()
  local builders = {}
  local idle = {}
  local hands = {}    -- each side's serfs (by side + 1)
  local waiters = {}  -- each side's serfs waiting at a site for its goods
  for i = 0, unit_count() - 1 do
    if serf[u_kind(i) + 1] then hands[u_owner(i) + 1] = (hands[u_owner(i) + 1] or 0) + 1 end
  end
  for i = 0, unit_count() - 1 do
    local task = u_task(i)
    local p = u_owner(i) + 1
    if task == BUILD then
      local b = building_index(u_target(i))
      local keep = b >= 0 and foundation > 0 and waiting(b) and (builders[b + 1] or 0) == 0 and (waiters[p] or 0) * 2 < (hands[p] or 0)
      if keep and not work_at(b) then waiters[p] = (waiters[p] or 0) + 1 end
      if b >= 0 and serf[u_kind(i) + 1] and b_is_site(b) and not work_at(b) and not keep then
        clear_task(i)
        task = T_NONE
      elseif b >= 0 then
        builders[b + 1] = (builders[b + 1] or 0) + 1
      end
    end
    if task == T_NONE and serf[u_kind(i) + 1] and u_orders(i) == 0 then
      local p = u_owner(i) + 1
      if not idle[p] then idle[p] = {} end
      table.insert(idle[p], i)
    end
  end
  return builders, idle
end

-- How many may build site b at once: one till its goods are all in (till then the carriers are needed), then per_site.
local function most_at(b)
  if b_is_site(b) and site_permille(b) >= 1000 then return per_site end
  return 1
end

-- An idle serf with a site that has work within NEXT of it goes there first, the nearest: a builder done with one
-- cell of a road goes on to the next, as a player expects, not back to the store and out again (#119).
local function next_door(builders, idle)
  local open = {}  -- the sites with work and room for a builder (one look over the buildings, not one per serf)
  for b = 0, building_count() - 1 do
    if work_at(b) and (builders[b + 1] or 0) < most_at(b) then table.insert(open, b) end
  end
  if #open == 0 then return end
  for p, mine in pairs(idle) do
    local j = 1
    while j <= #mine do
      local i = mine[j]
      local best = -1
      local best_d2 = NEXT * NEXT + 1
      for _, b in ipairs(open) do
        if b_owner(b) == p - 1 and (builders[b + 1] or 0) < most_at(b) then
          local d2 = mid_dist2(b, u_x(i), u_y(i))
          if d2 < best_d2 then
            best_d2 = d2
            best = b
          end
        end
      end
      if best >= 0 then
        builders[best + 1] = (builders[best + 1] or 0) + 1
        start_build(i, b_id(best))
        table.remove(mine, j)
      else
        j = j + 1
      end
    end
  end
end

local function send_builders(builders, idle)
  next_door(builders, idle)
  for b = 0, building_count() - 1 do
    local k = b_kind(b)
    local mine = idle[b_owner(b) + 1]
    local have = builders[b + 1] or 0
    local most = most_at(b)
    if mine and #mine > 0 and have < most and work_at(b) then
      for _ = have + 1, most do
        local w = take_nearest(mine, b)
        if w < 0 then break end
        start_build(w, b_id(b))
      end
    end
  end
end

-- The idle serfs left, not walking: each to its side's nearest finished store, if it's further than WAIT past its
-- edge. (approach_building leaves it idle, so a carrier's job or a site still takes it on the way.)
local function wait_by_stores(idle)
  local stores = {}  -- each side's finished stores (by side + 1)
  for b = 0, building_count() - 1 do
    if b_done(b) ~= 0 and bt_store(b_kind(b)) then
      local p = b_owner(b) + 1
      if not stores[p] then stores[p] = {} end
      table.insert(stores[p], b)
    end
  end
  for p, mine in pairs(idle) do
    local theirs = stores[p] or {}
    for _, i in ipairs(mine) do
      if u_moving(i) == 0 then
        local best = -1
        local best_d2 = 1 << 50
        for _, b in ipairs(theirs) do
          local d2 = mid_dist2(b, u_x(i), u_y(i))
          if d2 < best_d2 then
            best_d2 = d2
            best = b
          end
        end
        if best >= 0 then
          local x0, y0, x1, y1 = building_rect(best)
          local reach = (x1 - x0) // 2 + WAIT
          if best_d2 > reach * reach then approach_building(i, best) end
        end
      end
    end
  end
end

-- Each site with a door on free ground gets a road plan there, its owner's (door_roads: the genre lays the road tile in
-- front of a new building with it; the player joins it to the rest).
local function plan_door_roads()
  for b = 0, building_count() - 1 do
    local k = b_kind(b)
    if b_done(b) == 0 and b_is_site(b) and has_door(k) then
      local x0, y0, x1, y1 = building_rect(b)
      local dx = x0 // TILE + (x1 + 1 - x0) // TILE // 2
      local dy = (y1 + 1) // TILE
      if dy < H and road(dy * W + dx) == 0 and occupied(dy * W + dx) == 0 then lay_foundation(b_owner(b), road_kind, dx, dy) end
    end
  end
end

-- Each tick, after the economy's steps (rules.lua's on_tick).
function economy_tick()
  if door_roads and stocked() and road_kind >= 0 then plan_door_roads() end
  if not stocked() or tick() % LOOK ~= 0 or not (builders_come or idle_wait) then return end
  local builders, idle = look()
  if builders_come then send_builders(builders, idle) end
  if idle_wait then wait_by_stores(idle) end
end
