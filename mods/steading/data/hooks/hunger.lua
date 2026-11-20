-- Eating, in Lua (Casaide/creel#82), as in the genre (#132). Switched on by rules economy.hunger.life; off in any other
-- match. Units of the eater slots (economy.hunger.eaters) have a bar of "life" seconds that empties as they live; a new
-- one starts at start_pct of it, give or take jitter_pct (by its id). With hungry_at seconds or fewer left, at a pause in
-- their work they go and eat at the nearest of their side's buildings that seat people (buildings.json "seats": an
-- inn), else at a store. At an inn "seats" people sit down at once and the rest wait for a seat (or go to another inn
-- with one free). Each sits over one food at a time for eat_secs, the most filling first, never two of the same at one
-- sitting; a food fills its share of the bar (foods: [name, percent]), and they get up once full or once the inn has
-- nothing more for them. At a store a meal is one food, eaten at the door. Then they go back to the job they left. A
-- hungry unit that isn't eating works only economy.hunger.starving_pct of the time, and not at all once its bar is
-- empty. Inns keep their holds of the foods topped up, by carriers.

T_EAT = 100    -- our own task: going to eat (the engine's tasks end at T_CARRY, and its work leaves others be)
T_FAINT = 101  -- our own task: a hungry unit resting this tick from its job (it takes it up again next tick)

local LOOK = 20  -- ticks between an inn's looks at its holds, and a hungry unit's at where to eat (a second)

local hc = (rules().economy or {}).hunger or {}
local life = (hc.life or 0) * TICK_HZ
local hungry_at = life - (hc.hungry_at or 0) * TICK_HZ  -- (in ticks of the bar used up)
local start_pct = hc.start_pct or 100
local jitter_pct = hc.jitter_pct or 0
local starving = hc.starving_pct or 100
local eat_ticks = (hc.eat_secs or 0) * TICK_HZ

local foods = {}  -- the foods, the most filling first: their resources, and the ticks of the bar each fills
local fills = {}
for _, f in ipairs(hc.foods or {}) do
  local r = resource_index(f[1])
  assert(r >= 0, "economy.hunger.foods: no resource " .. tostring(f[1]))
  foods[#foods + 1] = r
  fills[#fills + 1] = life * f[2] // 100
end
assert(life == 0 or #foods > 0, "economy.hunger: life is set, but no foods")

local eater_slots = {}
for _, s in ipairs(hc.eaters or {}) do eater_slots[s] = true end

-- Per building type (k + 1): the people it seats at once, 0 if it doesn't. Per unit type: whether it eats.
local seats = {}
for k = 0, building_type_count() - 1 do seats[k + 1] = building_type(k).seats or 0 end
local eats = {}
for k = 0, unit_type_count() - 1 do eats[k + 1] = eater_slots[t_slot(k)] == true end

local col_meal = unit_column("meal")  -- 1 + the ticks of its bar used up (up to "life"); 0 for one not yet seen
local col_was = unit_column("was")  -- the job it left to eat, target * 16 + task, 0 for none
local col_rest = unit_column("rest")  -- while resting (T_FAINT), 1 + the task it rests from
local col_seat = unit_column("seat")  -- sitting at an inn's table: 1 + the foods eaten at this sitting (bit j: foods[j + 1])
local col_inside = unit_column("inside")  -- 1 while sitting at an inn's table: inside it, not drawn nor in the crowd (creel #120)
local col_seated = building_column("seated")  -- an inn: how many sit at its table now

local function food_offered(b)
  for _, r in ipairs(foods) do
    if offered(b, r) > 0 then return r end
  end
  return -1
end

-- The ticks of unit i's bar used up, and setting them (a new unit's are its start's).
local function used(i)
  local v = unit_get(col_meal, i)
  if v > 0 then return v - 1 end
  local pct = start_pct
  if jitter_pct > 0 then pct = pct + (u_id(i) * 7919) % (2 * jitter_pct + 1) - jitter_pct end
  return life - life * pct // 100
end

local function set_used(i, v)
  unit_set(col_meal, i, math.max(0, math.min(life, v)) + 1)
end

local function has_meal(b)
  return food_offered(b) >= 0
end

-- Whether inn b has a free seat at its table.
local function seat_free(b)
  return building_get(col_seated, b) < seats[b_kind(b) + 1]
end

-- Each side's finished inns and stores that have a meal, as this tick starts (building slots, in order): one look over
-- the buildings a tick, however many go looking for a meal. ([p + 1] = { inns, stores })
local function meal_places()
  local out = {}
  for b = 0, building_count() - 1 do
    local k = b_kind(b)
    local inn = seats[k + 1] ~= 0
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

-- The nearest of these buildings that still has a meal (one may have run out this tick) to unit i, with a free seat
-- if free; -1 if none does.
local function nearest_meal(i, list, free)
  local best = -1
  local best_d2 = 1 << 50
  local x, y = u_x(i), u_y(i)
  for _, b in ipairs(list) do
    if has_meal(b) and (not free or seat_free(b)) then
      local d2 = mid_dist2(b, x, y)
      if d2 < best_d2 then
        best_d2 = d2
        best = b
      end
    end
  end
  return best
end

-- Where unit i eats: the nearest inn of its side with a free seat, else the nearest inn (to wait for one), else its
-- nearest store; -1 if there's none. (places: meal_places())
local function eat_place(i, places)
  local mine = places[u_owner(i) + 1]
  if not mine then return -1 end
  local inn = nearest_meal(i, mine[1], true)
  if inn < 0 then inn = nearest_meal(i, mine[1], false) end
  if inn >= 0 then return inn end
  return nearest_meal(i, mine[2], false)
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

-- Back to the job it left to eat, if that's still there: gathering. A builder comes back idle, and the town's rules
-- (economy.lua) send it to whichever site wants one, so a site never gets more than its builders_per_site.
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
  else  -- (a builder is idle: the town sends builders where they're wanted, no more than a site may have)
    clear_task(i)
  end
end

-- The first of the foods (the most filling first) that inn b has and unit i hasn't eaten at this sitting (mask: the
-- foods it has), or nil.
local function next_food(b, mask)
  for j = 1, #foods do
    if mask & (1 << (j - 1)) == 0 and offered(b, foods[j]) > 0 then return j end
  end
  return nil
end

local function get_up(i, b)
  unit_set(col_seat, i, 0)
  unit_set(col_inside, i, 0)
  if b >= 0 then building_set(col_seated, b, building_get(col_seated, b) - 1) end
  back_from_meal(i)
end

-- Unit i at the table: one food each eat_ticks, then up once it's full or the inn has nothing more for it.
local function sit(i, b)
  set_u_moving(i, 0)
  set_u_work(i, u_work(i) + 1)
  if u_work(i) < eat_ticks then return end
  set_u_work(i, 0)
  local mask = unit_get(col_seat, i) - 1
  local j = next_food(b, mask)
  if j then
    hold_take(b, foods[j], 1)
    set_used(i, used(i) - fills[j])
    mask = mask | (1 << (j - 1))
    unit_set(col_seat, i, mask + 1)
    if used(i) > 0 and next_food(b, mask) then return end
  end
  get_up(i, b)
end

local function eat(i, places)
  local b = building_index(u_target(i))
  if unit_get(col_seat, i) > 0 then
    if b < 0 then get_up(i, b) else sit(i, b) end
    return
  end
  if b < 0 or not has_meal(b) then  -- gone, or eaten bare on the way: somewhere else, or back to work hungry
    local other = eat_place(i, places)
    if other >= 0 then go_eat(i, other) else back_from_meal(i) end
    return
  end
  if in_reach(i, building_rect(b)) then
    set_u_moving(i, 0)
    set_u_stuck(i, 0)
    if seats[b_kind(b) + 1] == 0 then  -- a store: a whole food at the door
      local r = food_offered(b)
      hold_take(b, r, 1)
      for j = 1, #foods do
        if foods[j] == r then set_used(i, used(i) - fills[j]) end
      end
      back_from_meal(i)
    elseif seat_free(b) then  -- a seat at the table
      unit_set(col_seat, i, 1)
      unit_set(col_inside, i, 1)
      building_set(col_seated, b, building_get(col_seated, b) + 1)
      set_u_work(i, 0)
    elseif (tick() + i) % LOOK == 0 then  -- waiting for a seat: another inn with one free?
      local mine = places[u_owner(i) + 1]
      local other = -1
      if mine then other = nearest_meal(i, mine[1], true) end
      if other >= 0 and other ~= b then go_eat(i, other) end
    end
  elseif u_moving(i) == 0 then
    if u_stuck(i) >= GIVE_UP then back_from_meal(i) else approach_building(i, b) end
  end
end

-- How many sit at each inn's table, counted afresh (one whose task was changed under it gets up).
local function count_seated()
  for b = 0, building_count() - 1 do
    if seats[b_kind(b) + 1] ~= 0 then building_set(col_seated, b, 0) end
  end
  for i = 0, unit_count() - 1 do
    if unit_get(col_seat, i) > 0 then
      local b = building_index(u_target(i))
      if u_task(i) ~= T_EAT or b < 0 then
        unit_set(col_seat, i, 0)
        unit_set(col_inside, i, 0)
      else building_set(col_seated, b, building_get(col_seated, b) + 1) end
    end
  end
end

-- A hungry unit rests this tick: with an empty bar always, before that outside starving_pct of each 100 ticks. From
-- gathering, carrying back, building, standing idle (a resting carrier takes no job), or a carrier's job with nothing
-- in hand yet (given back to the queue: it rests from idle). One with goods in hand works on till it puts them down
-- (it can't go to eat before: one starving with an armful would rest for ever).
local function rests(i, meal, now)
  local task = u_task(i)
  if u_carry(i) > 0 then return false end
  if task ~= T_NONE and task ~= GATHER and task ~= T_RETURN and task ~= BUILD and not (task == T_CARRY and u_carry(i) == 0) then
    return false
  end
  return meal >= life or now % 100 >= starving
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
  if not stocked() or life <= 0 then return end
  local now = tick()
  if now % LOOK == 0 then
    for b = 0, building_count() - 1 do
      if b_done(b) ~= 0 and seats[b_kind(b) + 1] ~= 0 then stock_inn(b) end
    end
  end
  count_seated()
  local places = nil  -- (meal_places(), once a unit first needs it this tick)
  for i = 0, unit_count() - 1 do
    if eats[u_kind(i) + 1] then
      if u_task(i) == T_FAINT then
        set_u_task(i, unit_get(col_rest, i) - 1)
        unit_set(col_rest, i, 0)
      end
      local meal = used(i) + 1
      set_used(i, meal)
      if u_task(i) == T_EAT then
        local b = building_index(u_target(i))
        if b < 0 or not has_meal(b) or unit_get(col_seat, i) == 0 then places = places or meal_places() end
        eat(i, places)
      elseif meal >= hungry_at then
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
  if task == T_EAT then
    if unit_get(col_seat, i) > 0 then return "Eating at the inn" end
    local b = building_index(u_target(i))
    if b >= 0 and seats[b_kind(b) + 1] ~= 0 and u_moving(i) == 0 and not seat_free(b) then return "Waiting for a seat" end
    return "Going to eat"
  end
  if task == T_FAINT then return "Hungry" end
  return ""
end
