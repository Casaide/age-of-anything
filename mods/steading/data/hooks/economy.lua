-- Steading's town rules, in Lua (Casaide/creel#82). Each is switched on in the rules file (rules/steading.json,
-- "economy") and off in any other match:
--   doors_on_roads: a building goes up only with the tile in front of its door on a road or its owner's road plan.
--   builders_come: a site with goods brought for more than is built gets an idle villager of its side, the nearest,
--     once a second; once all its goods are in, up to builders_per_site (1 if unset) at once. (The engine drops a site
--     whose builder can't get to it; this sends someone back too.)
--   idle_wait: an idle villager (a carrier slot, economy.carriers) with nothing to do walks back to its side's nearest
--     store and waits by it, rather than standing wherever its last job left it.

local LOOK = 20  -- ticks between looks (a second)
local WAIT = 2 * TILE  -- how far from a store's middle, past its half size, an idle villager may stand

local ec = rules().economy or {}
local doors = ec.doors_on_roads == true
local builders_come = ec.builders_come == true
local per_site = ec.builders_per_site or 1
local idle_wait = ec.idle_wait == true

-- Per unit type (k + 1): whether its units are villagers (a carrier slot).
local carrier_slots = {}
for _, s in ipairs(ec.carriers or {}) do carrier_slots[s] = true end
local villager = {}
for k = 0, unit_type_count() - 1 do villager[k + 1] = carrier_slots[t_slot(k)] == true end

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
  return b >= 0 and b_owner(b) == p and bt_road(b_kind(b)) >= 0
end

function doors_can_place(p, k, cx, cy, sx, sy)
  return not doors or door_on_road(p, k, cx, cy, sx, sy)
end

-- The nearest of these idle villagers (unit slots) to building b, taken out of the list; -1 if there's none.
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
  return b_done(b) == 0 and b_is_site(b) and b_progress(b) * 1000 < bt_build_ticks(b_kind(b)) * site_permille(b)
end

-- One look over the units: how many build each site (by slot + 1), and each side's idle villagers (in slot order). A
-- villager building a site with no work at it now (its goods not yet brought) stops, and is idle: a carrier the site
-- is waiting on, maybe; it's sent back once there's work again.
local function look()
  local builders = {}
  local idle = {}
  for i = 0, unit_count() - 1 do
    local task = u_task(i)
    if task == BUILD then
      local b = building_index(u_target(i))
      if b >= 0 and villager[u_kind(i) + 1] and b_is_site(b) and not work_at(b) then
        clear_task(i)
        task = T_NONE
      elseif b >= 0 then
        builders[b + 1] = (builders[b + 1] or 0) + 1
      end
    end
    if task == T_NONE and villager[u_kind(i) + 1] and u_orders(i) == 0 then
      local p = u_owner(i) + 1
      if not idle[p] then idle[p] = {} end
      table.insert(idle[p], i)
    end
  end
  return builders, idle
end

local function send_builders(builders, idle)
  for b = 0, building_count() - 1 do
    local k = b_kind(b)
    local mine = idle[b_owner(b) + 1]
    local have = builders[b + 1] or 0
    local most = 1
    if b_is_site(b) and site_permille(b) >= 1000 then most = per_site end  -- (helpers once its goods are all in: till then the carriers are needed)
    if mine and #mine > 0 and have < most and work_at(b) then
      for _ = have + 1, most do
        local w = take_nearest(mine, b)
        if w < 0 then break end
        start_build(w, b_id(b))
      end
    end
  end
end

-- The idle villagers left, not walking: each to its side's nearest finished store, if it's further than WAIT past its
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

-- Each tick, after the economy's steps (rules.lua's on_tick).
function economy_tick()
  if not stocked() or tick() % LOOK ~= 0 or not (builders_come or idle_wait) then return end
  local builders, idle = look()
  if builders_come then send_builders(builders, idle) end
  if idle_wait then wait_by_stores(idle) end
end
