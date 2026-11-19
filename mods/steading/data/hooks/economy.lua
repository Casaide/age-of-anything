-- Steading's town rules, in Lua (Casaide/creel#82). Three rules, each switched on in the rules file (rules/steading.json,
-- "economy") and off in any other match:
--   doors_on_roads: a building goes up only with the tile in front of its door on a road or its owner's road plan.
--   homes.born_every: in a stocked economy, a building with beds (buildings.json "beds") keeps the foods its holds have
--     room for topped up, and while it has a free bed, food in its larder and room under its owner's cap it counts
--     down; at the end it takes one food and a worker is born at its door.
--   builders_come: a site nobody is building, with goods brought for more than is built, gets the nearest idle worker
--     of its side, once a second. (The engine drops a site whose builder can't get to it; this sends someone back.)

local HOME_LOOK = 20  -- ticks between an idle home's looks at its beds and larder (a second)

local ec = rules().economy or {}
local doors = ec.doors_on_roads == true
local builders_come = ec.builders_come == true
local homes = ec.homes or {}
local born_ticks = (homes.born_every or 0) * TICK_HZ

-- What a larder keeps and a birth takes one of.
local foods = {}
for _, name in ipairs(homes.foods or {}) do
  local r = resource_index(name)
  assert(r >= 0, "economy.homes.foods: no resource " .. name)
  foods[#foods + 1] = r
end

-- Per building type (k + 1): its beds.
local beds = {}
for k = 0, building_type_count() - 1 do
  beds[k + 1] = building_type(k).beds or 0
end

local col_house = unit_column("house")  -- the id of the home a unit was born in, 0 for none
local col_born = building_column("born")  -- a home's ticks to its next birth, 0 while it isn't counting

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

function can_place(p, k, cx, cy, sx, sy)
  return not doors or door_on_road(p, k, cx, cy, sx, sy)
end

-- The units born in building b that are still alive.
local function residents(b)
  local id = b_id(b)
  local n = 0
  for i = 0, unit_count() - 1 do
    if unit_get(col_house, i) == id then n = n + 1 end
  end
  return n
end

local function larder_food(b)
  for _, r in ipairs(foods) do
    if b_hold(b, r) > 0 then return r end
  end
  return -1
end

local function stock_larder(b)
  local k = b_kind(b)
  for _, r in ipairs(foods) do
    local lack = bt_hold(k, r) - b_hold(b, r) - b_want(b, r) - b_coming(b, r)
    if lack > 0 then want(b, r, lack) end
  end
end

local function can_be_born(b)
  local p = b_owner(b)
  local k = worker_type(p)
  return k >= 0 and larder_food(b) >= 0 and pop(p) + t_pop(k) <= pop_cap(p) and residents(b) < beds[b_kind(b) + 1]
end

local function born(b)
  local p = b_owner(b)
  local k = worker_type(p)
  hold_take(b, larder_food(b), 1)
  local i = trained(b, k)
  unit_set(col_house, i, b_id(b))
  set_pop(p, pop(p) + t_pop(k))
end

local function homes_tick()
  local second = tick() % HOME_LOOK == 0
  for b = 0, building_count() - 1 do
    if b_done(b) ~= 0 and beds[b_kind(b) + 1] > 0 then
      local left = building_get(col_born, b)
      if left > 0 then
        building_set(col_born, b, left - 1)
        if left == 1 and can_be_born(b) then born(b) end
      elseif second then
        stock_larder(b)
        if can_be_born(b) then building_set(col_born, b, born_ticks) end
      end
    end
  end
end

local function idle_worker(b)
  local best = -1
  local best_d2 = 1 << 50
  local p = b_owner(b)
  for i = 0, unit_count() - 1 do
    if u_owner(i) == p and t_worker(u_kind(i)) and u_task(i) == T_NONE and u_orders(i) == 0 then
      local d2 = mid_dist2(b, u_x(i), u_y(i))
      if d2 < best_d2 then
        best_d2 = d2
        best = i
      end
    end
  end
  return best
end

local function builders_tick()
  if tick() % HOME_LOOK ~= 0 then return end
  local building = {}
  for i = 0, unit_count() - 1 do
    if u_task(i) == BUILD then
      local b = building_index(u_target(i))
      if b >= 0 then building[b + 1] = true end
    end
  end
  for b = 0, building_count() - 1 do
    local k = b_kind(b)
    if b_done(b) == 0 and not building[b + 1] and b_is_site(b) and b_progress(b) * 1000 < bt_build_ticks(k) * site_permille(b) then
      local w = idle_worker(b)
      if w >= 0 then start_build(w, b_id(b)) end
    end
  end
end

-- Each tick, after the economy's steps (rules.lua's on_tick).
function economy_tick()
  if not stocked() then return end
  if born_ticks > 0 then homes_tick() end
  if builders_come then builders_tick() end
end
