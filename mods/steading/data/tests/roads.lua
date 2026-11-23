-- Roads (the rules contract, C): a road cell is a plan that takes one stone, carried to it from the store by a serf, then
-- laid. Laid, it's ground with a road on it, no longer a building.

local function store()  -- player 0's storehouse (its first building): its slot, and the cell beside its right edge
  for b = 0, building_count() - 1 do
    if b_owner(b) == 0 then
      local x0, y0, x1, y1 = building_rect(b)
      return b, x1 // 1000 + 1, (y0 + y1) // 2000
    end
  end
end

function test_road_takes_one_stone()
  local s, cx, cy = store()
  local stone = resource_index("stone")
  local road = 0
  local at = 0
  for dx = 1, 6 do
    if road == 0 then
      road = place(0, "road", cx + dx, cy, false)
      at = cx + dx
    end
  end
  expect(road ~= 0, "a road cell is planned beside the store")
  keep("road", road)
  keep("cell", cell_of(at * 1000 + 500, cy * 1000 + 500))
  keep("stone", b_hold(s, stone))
  wait_for("drop", 2400, nil, road, stone)
end

function test_road_takes_one_stone_2()
  expect(building_index(kept("road")) >= 0, "the plan is still there when its stone comes")
  wait_for("built", 1200, nil, kept("road"))
end

function test_road_takes_one_stone_3()
  local s = store()
  expect(road(kept("cell")) > 0, "the road is laid on its cell")
  expect(building_index(kept("road")) < 0, "and the plan is gone")
  expect(b_hold(s, resource_index("stone")) == kept("stone") - 1, "one stone left the store, no more")
end

-- A road of ten (creel #192): each cell is dug before its stone comes, waits for it, then is laid. Ten stones leave the
-- store, no more, and all ten cells end up road.
function test_road_of_ten()
  local s, cx, cy = store()
  local stone = resource_index("stone")
  local rk = -1
  for k = 0, building_type_count() - 1 do
    if rk < 0 and bt_road(k) >= 0 then rk = k end
  end
  local row = nil  -- the nearest row by the store with ten free cells running right
  for _, dy in ipairs({ 0, 1, -1, 2, -2, 3, -3, 4, -4 }) do
    if row == nil then
      local free = true
      for k = 1, 10 do free = free and fits(0, rk, cx + k, cy + dy) end
      if free then row = cy + dy end
    end
  end
  expect(row ~= nil, "ten free cells in a row by the store")
  cy = row or cy
  for k = 1, 10 do
    local id = place(0, "road", cx + k, cy, false)
    expect(id ~= 0, "road cell " .. k .. " of ten is planned beside the store")
    keep("r" .. k, id)
    keep("c" .. k, cell_of((cx + k) * 1000 + 500, cy * 1000 + 500))
  end
  keep("stone", b_hold(s, stone))
  expect(site_phase(building_index(kept("r1"))) == 0, "a new road cell is levelled first")
  wait_for("drop", 2400, nil, kept("r1"), stone)
end

function test_road_of_ten_2()
  expect(site_phase(building_index(kept("r1"))) == 2, "dug before its stone came, it is laid once the stone is in")
  wait(3600)
end

function test_road_of_ten_3()
  local s = store()
  local laid = 0
  local gone = 0
  for k = 1, 10 do
    if road(kept("c" .. k)) > 0 then laid = laid + 1 end
    if building_index(kept("r" .. k)) < 0 then gone = gone + 1 end
  end
  expect(laid == 10, "all ten cells are road (" .. laid .. ")")
  expect(gone == 10, "and all ten plans are gone (" .. gone .. ")")
  expect(b_hold(s, resource_index("stone")) == kept("stone") - 10, "ten stones left the store, no more (" .. kept("stone") - b_hold(s, resource_index("stone")) .. ")")
end
