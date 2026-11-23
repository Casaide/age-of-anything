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
