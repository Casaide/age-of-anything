-- Eating, in Lua (Casaide/creel#82). Switched on by rules economy.hunger.every; off in any other match.
-- Units of the eater slots (economy.hunger.eaters) count the ticks since they last ate. Once hungry, at a pause in their
-- work they go and eat at the nearest of their side's buildings that serve (buildings.json "serves": an inn), else at
-- a store. A meal at a store is a whole food; an inn opens one food into "serves" meals, so it feeds a town for less.
-- Then they go back to the job they left. A hungry unit that isn't eating works only economy.hunger.starving_pct of the time, and not at all once it has gone twice "every"
-- without a meal. Serving buildings keep their holds of economy.hunger.foods topped up, by carriers.

T_EAT = 100    -- our own task: going to eat (the engine's tasks end at T_CARRY, and its work leaves others be)
T_FAINT = 101  -- our own task: a hungry unit resting this tick from its job (it takes it up again next tick)

local LOOK = 20  -- ticks between an inn's looks at its holds, and a hungry unit's at where to eat (a second)

local hc = (rules().economy or {}).hunger or {}
local every = (hc.every or 0) * TICK_HZ
local starving = hc.starving_pct or 100

local foods = {}
for _, name in ipairs(hc.foods or {}) do
  local r = resource_index(name)
  assert(r >= 0, "economy.hunger.foods: no resource " .. name)
  foods[#foods + 1] = r
end
assert(every == 0 or #foods > 0, "economy.hunger: every is set, but no foods")

local eater_slots = {}
for _, s in ipairs(hc.eaters or {}) do eater_slots[s] = true end

-- Per building type (k + 1): the meals one food makes there, 0 if it doesn't serve. Per unit type: whether it eats.
local serves = {}
for k = 0, building_type_count() - 1 do serves[k + 1] = building_type(k).serves or 0 end
local eats = {}
for k = 0, unit_type_count() - 1 do eats[k + 1] = eater_slots[t_slot(k)] == true end

local col_meal = unit_column("meal")  -- ticks since it last ate (up to twice "every")
local col_was = unit_column("was")  -- the job it left to eat, target * 16 + task, 0 for none
local col_rest = unit_column("rest")  -- while resting (T_FAINT), 1 + the task it rests from
local col_portions = building_column("portions")  -- an inn's meals left of the food it opened

local function food_offered(b)
  for _, r in ipairs(foods) do
    if offered(b, r) > 0 then return r end
  end
  return -1
end

local function has_meal(b)
  return (serves[b_kind(b) + 1] ~= 0 and building_get(col_portions, b) > 0) or food_offered(b) >= 0
end

local function take_meal(b)
  local n = serves[b_kind(b) + 1]
  local left = building_get(col_portions, b)
  if n ~= 0 and left > 0 then
    building_set(col_portions, b, left - 1)
    return
  end
  hold_take(b, food_offered(b), 1)
  if n ~= 0 then building_set(col_portions, b, n - 1) end
end

-- Each side's finished inns and stores that have a meal, as this tick starts (building slots, in order): one look over
-- the buildings a tick, however many go looking for a meal. ([p + 1] = { inns, stores })
local function meal_places()
  local out = {}
  for b = 0, building_count() - 1 do
    local k = b_kind(b)
    local inn = serves[k + 1] ~= 0
    local store = bt_store(k)
    if (inn or store) and b_done(b) ~= 0 and has_meal(b) then
      local p = b_owner(b) + 1
      if not out[p] then out[p] = { {}, {} } end
      if inn then table.insert(out[p][1], b) end
      if store then table.insert(out[p][2], b) end
    end
  end
  return out
end

-- The nearest of these buildings that still has a meal (one may have run out this tick) to unit i; -1 if none does.
local function nearest_meal(i, list)
  local best = -1
  local best_d2 = 1 << 50
  local x, y = u_x(i), u_y(i)
  for _, b in ipairs(list) do
    if has_meal(b) then
      local d2 = mid_dist2(b, x, y)
      if d2 < best_d2 then
        best_d2 = d2
        best = b
      end
    end
  end
  return best
end

-- Where unit i eats: the nearest inn of its side, else its nearest store; -1 if there's none. (places: meal_places())
local function eat_place(i, places)
  local mine = places[u_owner(i) + 1]
  if not mine then return -1 end
  local inn = nearest_meal(i, mine[1])
  if inn >= 0 then return inn end
  return nearest_meal(i, mine[2])
end

-- A pause in its work: idle, building, gathering with nothing in hand, or carrying with nothing in hand yet (a carrier
-- that leaves such a job gives it back to the queue: the engine drops a job whose carrier went).
local function at_a_pause(i)
  local task = u_task(i)
  return task == T_NONE or task == BUILD or ((task == GATHER or task == T_CARRY) and u_carry(i) == 0)
end

local function go_eat(i, b)
  local task = u_task(i)
  if task ~= T_EAT then  -- (sent on to somewhere else to eat: the job it left is the one it had)
    local was = 0
    if task ~= T_NONE and task ~= T_CARRY and u_target(i) >= 0 then was = u_target(i) * 16 + task end
    unit_set(col_was, i, was)
  end
  set_u_task(i, T_EAT)
  set_u_target(i, b_id(b))
  set_u_work(i, 0)
  set_u_stuck(i, 0)
  approach_building(i, b)
end

-- Back to the job it left to eat, if that's still there.
local function back_from_meal(i)
  local was = unit_get(col_was, i)
  unit_set(col_was, i, 0)
  local task = was % 16
  local target = was // 16
  set_u_task(i, T_NONE)
  set_u_target(i, -1)
  set_u_stuck(i, 0)  -- (a crowd at the inn isn't the job's: a builder stuck there would give its site up)
  if was <= 0 then  -- (no job, or none with a target to go back to)
    clear_task(i)
  elseif task == GATHER then
    local kind = u_carry_kind(i)
    local c = -1
    if res_at(target) == kind and amount(target) > 0 then c = target
    else c = nearest_resource(target % W * TILE + TILE // 2, target // W * TILE + TILE // 2, kind, i, false, false, true) end
    if kind > 0 and c >= 0 then start_gather(i, c, kind) else clear_task(i) end
  elseif task == BUILD then
    local b = building_index(target)
    if b >= 0 and b_done(b) ~= 1 then start_build(i, target) else clear_task(i) end
  else
    clear_task(i)
  end
end

local function eat(i, places)
  local b = building_index(u_target(i))
  if b < 0 or not has_meal(b) then  -- gone, or eaten bare on the way: somewhere else, or back to work hungry
    local other = eat_place(i, places)
    if other >= 0 then go_eat(i, other) else back_from_meal(i) end
    return
  end
  if in_reach(i, building_rect(b)) then
    set_u_moving(i, 0)
    take_meal(b)
    unit_set(col_meal, i, 0)
    back_from_meal(i)
  elseif u_moving(i) == 0 then
    if u_stuck(i) >= GIVE_UP then back_from_meal(i) else approach_building(i, b) end
  end
end

-- A hungry unit rests this tick: past twice "every" always, before that outside starving_pct of each 100 ticks. From
-- gathering, carrying back, building, standing idle (a resting carrier takes no job), or a carrier's job with nothing
-- in hand yet (given back to the queue: it rests from idle). One with goods in hand works on till it puts them down
-- (it can't go to eat before: one starving with an armful would rest for ever).
local function rests(i, meal, now)
  local task = u_task(i)
  if u_carry(i) > 0 then return false end
  if task ~= T_NONE and task ~= GATHER and task ~= T_RETURN and task ~= BUILD and not (task == T_CARRY and u_carry(i) == 0) then
    return false
  end
  return meal >= 2 * every or now % 100 >= starving
end

local function stock_inn(b)
  local k = b_kind(b)
  for _, r in ipairs(foods) do
    local lack = bt_hold(k, r) - b_hold(b, r) - b_want(b, r) - b_coming(b, r)
    if lack > 0 then want(b, r, lack) end
  end
end

-- Each tick, after the economy's steps (so a rest set here is the next tick's work skipped).
function hunger_tick()
  if not stocked() or every <= 0 then return end
  local now = tick()
  if now % LOOK == 0 then
    for b = 0, building_count() - 1 do
      if b_done(b) ~= 0 and serves[b_kind(b) + 1] ~= 0 then stock_inn(b) end
    end
  end
  local places = nil  -- (meal_places(), once a unit first needs it this tick)
  for i = 0, unit_count() - 1 do
    if eats[u_kind(i) + 1] then
      if u_task(i) == T_FAINT then
        set_u_task(i, unit_get(col_rest, i) - 1)
        unit_set(col_rest, i, 0)
      end
      local meal = unit_get(col_meal, i)
      if meal < 2 * every then unit_set(col_meal, i, meal + 1) end
      if u_task(i) == T_EAT then
        local b = building_index(u_target(i))
        if b < 0 or not has_meal(b) then places = places or meal_places() end
        eat(i, places)
      elseif meal >= every then
        local b = -1
        if (now + i) % LOOK == 0 and at_a_pause(i) then
          places = places or meal_places()
          b = eat_place(i, places)
        end
        if b >= 0 then
          go_eat(i, b)
        elseif rests(i, meal, now) then
          local task = u_task(i)
          if task == T_CARRY then task = T_NONE end
          unit_set(col_rest, i, 1 + task)
          set_u_task(i, T_FAINT)
        end
      end
    end
  end
end

-- What the panel says a worker is doing, for our own tasks ("" for the engine's).
function hunger_task_name(i)
  local task = u_task(i)
  if task == T_EAT then return "Going to eat" end
  if task == T_FAINT then return "Hungry" end
  return ""
end
