-- Specialists staff the huts (#77). A building type's "staff" (buildings.json: {"woodcutter": 1}) names who works there
-- and how many; its "drop_off" names what they gather (the first one). Specialists are units of those roster slots,
-- trained at the school. Once a second:
--   a finished building short of its staff takes the nearest specialist of that slot with no workplace (one whose
--     workplace went has none);
--   a specialist at its workplace with nothing to do gathers the nearest of the workplace's goods round it. What it
--     gathers goes to the nearest drop-off (the hut it works at, by its trees), and carriers take it on from there.
-- A specialist isn't a carrier, nor sent to build: those are the serfs' (economy.carriers).
-- A workplace with no goods to gather round it (a mill, a bakery: a recipe) works only while one of its staff stands at
-- its door (#99): its worker goes there and waits, and the engine asks can_make before each round. After each round
-- it takes a break of REST (#139).
-- A workplace with a "reach" (a mine, #42: tiles out from its edge) has its worker gather only that near: what's
-- further is someone else's. When none is left within reach, the place is worked out and its worker waits at the door;
-- unless it "plants" (the woodcutter's hut, #126): then its worker plants that terrain (saplings) on open ground in reach,
-- which grows back into what's gathered.

-- A trade in the rules' economy.tools_for takes a tool from one of its side's stores when it's first given a workplace
-- (#102); with none in store it waits, without a workplace, till the smithy's tools are in.

local LOOK = 20  -- ticks between looks (a second)
local TOOLS = resource_index("tools")  -- (-1 if the pack has no tools)
local needs_tool = {}
for _, slot in ipairs((rules().economy or {}).tools_for or {}) do needs_tool[slot] = true end

-- Per building type (k + 1): its staff ({slot = how many}) or nil, and the resource kind its workers gather (r + 1), 0
-- for none.
local staff = {}
local gathers = {}
local reach = {}  -- (in tiles, or nil for anywhere)
local ins = {}  -- the resources its recipe takes (r, 0-based), or nil ("makes": the workshops)
local plants = {}  -- the terrain type its worker plants when nothing is left to gather in reach ("plants"), or -1
local job_slots = {}
for k = 0, building_type_count() - 1 do
  local bt = building_type(k)
  staff[k + 1] = bt.staff
  gathers[k + 1] = 0
  reach[k + 1] = bt.reach
  plants[k + 1] = -1
  if bt.makes and bt.makes["in"] then
    ins[k + 1] = {}
    for id, n in pairs(bt.makes["in"]) do
      if n > 0 then table.insert(ins[k + 1], resource_index(id)) end
    end
    table.sort(ins[k + 1])
  end
  if bt.plants then
    plants[k + 1] = terrain_type(bt.plants)
    assert(plants[k + 1] >= 0 and bt.reach, "buildings.json plants: no terrain " .. bt.plants .. ", or no reach")
  end
  if bt.staff then
    for slot, _ in pairs(bt.staff) do job_slots[slot] = true end
    local d = (bt.drop_off or {})[1]
    if d then
      local r = resource_index(d)
      assert(r >= 0, "buildings.json staff: no resource " .. d)
      gathers[k + 1] = r + 1
    end
  end
end

-- Per unit type (k + 1): the job slot its units do, or nil.
local job_of = {}
for k = 0, unit_type_count() - 1 do
  if job_slots[t_slot(k)] then job_of[k + 1] = t_slot(k) end
end

local col_work = unit_column("workplace")  -- the id of the building it works at, 0 for none
local col_present = building_column("present")  -- 1 while one of its staff stands at its door (as of the last look)
local col_tool = unit_column("tool")  -- 1 once it has its tool
local col_out = building_column("worked_out")  -- 1 once there's nothing left to gather within its reach
local col_rest = building_column("rest_until")  -- the tick its worker's break after the round going ends
local REST = 8 * TICK_HZ  -- the break a worker takes after each round of a recipe (the genre's pace, #139)
local col_plant = unit_column("plant")  -- the cell + 1 it's going to plant, 0 for none (#126)
local col_planting = unit_column("planting")  -- the looks it has stood planting there

local PLANT_LOOKS = 4  -- looks a sapling takes to plant, once there
local MOST_PLANTED = 6  -- saplings growing within one hut's reach at most: the rest of the ground stays open
local GRASS = terrain_type("grass")
local STUMP = terrain_type("stump")

-- Whether cell c is within building b's reach (if its type has one).
local function within_reach(b, c)
  local r = reach[b_kind(b) + 1]
  if not r then return true end
  local x0, y0, x1, y1 = building_rect(b)
  local x = (c % W) * TILE + TILE // 2
  local y = (c // W) * TILE + TILE // 2
  local dx = math.max(math.max(x0 - x, x - x1), 0)
  local dy = math.max(math.max(y0 - y, y - y1), 0)
  return math.max(dx, dy) <= r * TILE + TILE // 2
end

-- The building slot unit i works at, or -1 (none, or gone: then it's cleared).
local function workplace(i)
  local id = unit_get(col_work, i)
  if id == 0 then return -1 end
  local b = building_index(id)
  if b < 0 or b_done(b) == 0 then
    if b < 0 then unit_set(col_work, i, 0) end
    return -1
  end
  return b
end

-- Where a worker of building b plants next (b's type "plants"): the nearest grass or stump within its reach, nothing
-- on it or beside it, not next to b; -1 if there's none, or MOST_PLANTED are growing already.
local function plant_spot(b)
  local t = plants[b_kind(b) + 1]
  local x0, y0, x1, y1 = building_rect(b)
  local r = reach[b_kind(b) + 1]
  local cx0 = math.max(0, x0 // TILE - r)
  local cy0 = math.max(0, y0 // TILE - r)
  local cx1 = math.min(W - 1, x1 // TILE + r)
  local cy1 = math.min(H - 1, y1 // TILE + r)
  local growing = 0
  local best = -1
  local best_d2 = 1 << 50
  for y = cy0, cy1 do
    for x = cx0, cx1 do
      local c = y * W + x
      local tc = terrain_at(c)
      if tc == t then growing = growing + 1 end
      if (tc == GRASS or tc == STUMP) and x >= cx0 + 1 and x <= cx1 - 1 and y >= cy0 + 1 and y <= cy1 - 1 then
        local near_hut = x >= x0 // TILE - 1 and x <= x1 // TILE + 1 and y >= y0 // TILE - 1 and y <= y1 // TILE + 2
        local clear = not near_hut and road(c) == 0
        for _, n in ipairs({ c, c - 1, c + 1, c - W, c + W }) do
          if occupied(n) ~= 0 or road(n) ~= 0 then clear = false end
        end
        local d2 = mid_dist2(b, x * TILE + TILE // 2, y * TILE + TILE // 2)
        if clear and d2 < best_d2 then
          best_d2 = d2
          best = c
        end
      end
    end
  end
  if growing >= MOST_PLANTED then return -1 end
  return best
end

-- Unit i, sent to plant at cell c - 1 (col_plant): walks there, plants after PLANT_LOOKS there, and is done.
local function planting(i, b)
  local c = unit_get(col_plant, i) - 1
  local x = (c % W) * TILE
  local y = (c // W) * TILE
  if not in_reach(i, x, y, x + TILE - 1, y + TILE - 1) then
    if u_moving(i) == 0 then approach_cell(i, c) end
    return
  end
  local n = unit_get(col_planting, i) + 1
  if n < PLANT_LOOKS then
    unit_set(col_planting, i, n)
    return
  end
  plant(c, plants[b_kind(b) + 1])
  unit_set(col_plant, i, 0)
  unit_set(col_planting, i, 0)
end

-- The room left in building b for resource kind (r + 1).
local function room(b, kind)
  return bt_hold(b_kind(b), kind - 1) - b_hold(b, kind - 1)
end

-- Unit i, idle at its workplace b, gathers the nearest of b's goods round it (if there are any left); with none, a
-- planter plants (the genre's woodcutter: saplings, when no grown tree is in reach, #126). With b full, or i carrying
-- what b had no room for, it waits by b's door till a serf takes some away, then drops there (#134).
local function go_to_work(i, b)
  if unit_get(col_plant, i) ~= 0 then return planting(i, b) end
  local kind = gathers[b_kind(b) + 1]
  if kind ~= 0 and (room(b, kind) <= 0 or (u_carry(i) > 0 and u_carry_kind(i) == kind)) then
    if u_carry(i) > 0 and room(b, kind) > 0 then
      set_u_task(i, T_RETURN)
      set_u_target(i, b_id(b))
      approach_building(i, b)
    elseif not in_reach(i, building_rect(b)) and u_moving(i) == 0 then
      approach_building(i, b)
    end
    return
  end
  if kind == 0 then
    if not in_reach(i, building_rect(b)) and u_moving(i) == 0 then approach_building(i, b) end
    return
  end
  local x0, y0, x1, y1 = building_rect(b)
  local c = nearest_resource((x0 + x1) // 2, (y0 + y1) // 2, kind, i, false, false, true)
  if c >= 0 and within_reach(b, c) then
    building_set(col_out, b, 0)
    start_gather(i, c, kind)
  elseif plants[b_kind(b) + 1] >= 0 and plant_spot(b) >= 0 then
    building_set(col_out, b, 0)
    unit_set(col_plant, i, plant_spot(b) + 1)
    planting(i, b)
  elseif reach[b_kind(b) + 1] then
    building_set(col_out, b, 1)
    if not in_reach(i, building_rect(b)) and u_moving(i) == 0 then approach_building(i, b) end
  end
end

-- A finished store of side p with a tool in it, or -1.
local function tool_store(p)
  if TOOLS < 0 then return -1 end
  for s = 0, building_count() - 1 do
    if b_owner(s) == p and b_done(s) ~= 0 and bt_store(b_kind(s)) and b_hold(s, TOOLS) > 0 then return s end
  end
  return -1
end

-- Unit i has a tool, or takes one from a store of its side: whether it has one now.
local function tooled(i)
  if not needs_tool[t_slot(u_kind(i))] or unit_get(col_tool, i) == 1 then return true end
  local s = tool_store(u_owner(i))
  if s < 0 then return false end
  hold_take(s, TOOLS, 1)
  unit_set(col_tool, i, 1)
  return true
end

-- The nearest of these free specialists (unit slots) to building b, taken out of the list; -1 if there's none.
local function take_nearest(free, b)
  local best = -1
  local best_d2 = 1 << 50
  for j, i in ipairs(free) do
    local d2 = mid_dist2(b, u_x(i), u_y(i))
    if d2 < best_d2 then
      best_d2 = d2
      best = j
    end
  end
  if best < 0 then return -1 end
  return table.remove(free, best)
end

-- Each tick: a specialist on its way to drop its goods anywhere but its own workplace (the engine sends it on to a
-- store when its hut is full) stops, keeping them; it waits at its hut instead (go_to_work). Goods reach a store only
-- in a serf's hands, as in the genre (#134).
local function home_drops()
  for i = 0, unit_count() - 1 do
    if u_task(i) == T_RETURN and job_of[u_kind(i) + 1] then
      local b = workplace(i)
      if b >= 0 and u_target(i) ~= b_id(b) then
        clear_task(i)
        go_to_work(i, b)
      end
    end
  end
end

-- Each tick: a workshop with a round going (b_making) and no break set past it gets one: its next round waits till
-- this one is done and its worker has had a break (can_make).
local function breaks()
  for b = 0, building_count() - 1 do
    if ins[b_kind(b) + 1] and b_done(b) ~= 0 then
      local left = b_making(b)
      if left > 0 and building_get(col_rest, b) < tick() + left then building_set(col_rest, b, tick() + left + REST) end
    end
  end
end

function jobs_tick()
  if not stocked() then return end
  home_drops()
  breaks()
  if tick() % LOOK ~= 0 then return end
  -- One look over the units: who works where (by building slot + 1), and each side's free specialists by slot.
  local working = {}
  local at_door = {}
  local free = {}
  for i = 0, unit_count() - 1 do
    local job = job_of[u_kind(i) + 1]
    if job then
      local b = workplace(i)
      if b >= 0 then
        working[b + 1] = (working[b + 1] or 0) + 1
        if in_reach(i, building_rect(b)) then at_door[b + 1] = true end
        if u_task(i) == GATHER and u_carry(i) == 0 and u_target(i) >= 0 and not within_reach(b, u_target(i)) then clear_task(i) end
        if u_task(i) == T_NONE and u_orders(i) == 0 then go_to_work(i, b) end
      else
        local p = u_owner(i) + 1
        if not free[p] then free[p] = {} end
        if not free[p][job] then free[p][job] = {} end
        table.insert(free[p][job], i)
      end
    end
  end
  for b = 0, building_count() - 1 do
    local st = staff[b_kind(b) + 1]
    if st then
      local here = 0
      if at_door[b + 1] then here = 1 end
      building_set(col_present, b, here)
    end
    local mine = free[b_owner(b) + 1]
    if st and mine and b_done(b) ~= 0 then
      local have = working[b + 1] or 0
      for slot, n in pairs(st) do
        local pool = mine[slot]
        while pool and #pool > 0 and have < n do
          local i = take_nearest(pool, b)
          if not tooled(i) then break end  -- (no tools in store: none of this trade can start)
          unit_set(col_work, i, b_id(b))
          have = have + 1
          if u_task(i) == T_NONE and u_orders(i) == 0 then go_to_work(i, b) end
        end
      end
    end
  end
end

-- The engine asks before a round of building b's recipe: a staffed workplace makes only with its worker there.
function can_make(b)
  if not staff[b_kind(b) + 1] then return true end
  return building_get(col_present, b) == 1 and tick() >= building_get(col_rest, b)
end

-- What the panel says unit i does, as a specialist: "Woodcutter" ("" if it isn't one), and where if it has a workplace.
function jobs_task_name(i)
  local job = job_of[u_kind(i) + 1]
  if not job then return "" end
  local id = unit_get(col_work, i)
  local b = -1
  if id ~= 0 then b = building_index(id) end
  local name = job:sub(1, 1):upper() .. job:sub(2)
  if b < 0 then
    if needs_tool[job] and unit_get(col_tool, i) == 0 and tool_store(u_owner(i)) < 0 then
      return name .. ", waiting for tools"
    end
    return name .. ", waiting for a workplace"
  end
  local at = name .. " at the " .. (building_type(b_kind(b)).name or "hut")
  if unit_get(col_plant, i) ~= 0 then return at .. ": planting" end
  local kind = gathers[b_kind(b) + 1]
  if kind ~= 0 and room(b, kind) <= 0 then return at .. ": waiting, the hut is full" end
  if building_get(col_out, b) == 1 then return at .. ": it's worked out" end
  return at
end
