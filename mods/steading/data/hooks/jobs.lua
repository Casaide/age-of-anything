-- Specialists staff the huts (#77). A building type's "staff" (buildings.json: {"woodcutter": 1}) names who works there
-- and how many; its "drop_off" names what they gather (the first one). Specialists are units of those roster slots,
-- trained at the school. Once a second:
--   a finished building short of its staff takes the nearest specialist of that slot with no workplace (one whose
--     workplace went has none);
--   a specialist at its workplace with nothing to do gathers the nearest of the workplace's goods round it. What it
--     gathers goes to the nearest drop-off (the hut it works at, by its trees), and carriers take it on from there.
-- A specialist isn't a carrier, nor sent to build: those are the villagers' (economy.carriers).
-- A workplace with no goods to gather round it (a mill, a bakery: a recipe) works only while one of its staff stands at
-- its door (#99): its worker goes there and waits, and the engine asks can_make before each round.

local LOOK = 20  -- ticks between looks (a second)

-- Per building type (k + 1): its staff ({slot = how many}) or nil, and the resource kind its workers gather (r + 1), 0
-- for none.
local staff = {}
local gathers = {}
local job_slots = {}
for k = 0, building_type_count() - 1 do
  local bt = building_type(k)
  staff[k + 1] = bt.staff
  gathers[k + 1] = 0
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

-- Unit i, idle at its workplace b, gathers the nearest of b's goods round it (if there are any left).
local function go_to_work(i, b)
  local kind = gathers[b_kind(b) + 1]
  if kind == 0 then
    if not in_reach(i, building_rect(b)) and u_moving(i) == 0 then approach_building(i, b) end
    return
  end
  local x0, y0, x1, y1 = building_rect(b)
  local c = nearest_resource((x0 + x1) // 2, (y0 + y1) // 2, kind, i, false, false, true)
  if c >= 0 then start_gather(i, c, kind) end
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

function jobs_tick()
  if not stocked() or tick() % LOOK ~= 0 then return end
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
  return building_get(col_present, b) == 1
end

-- What the panel says unit i does, as a specialist: "Woodcutter" ("" if it isn't one), and where if it has a workplace.
function jobs_task_name(i)
  local job = job_of[u_kind(i) + 1]
  if not job then return "" end
  local id = unit_get(col_work, i)
  local b = -1
  if id ~= 0 then b = building_index(id) end
  local name = job:sub(1, 1):upper() .. job:sub(2)
  if b < 0 then return name .. ", waiting for a workplace" end
  return name .. " at the " .. (building_type(b_kind(b)).name or "hut")
end
