-- Mines go into the mountain (#42). A building type with "against" (buildings.json: "against": "coal") goes up only
-- with a seam of that resource touching its footprint, on any side: its back to the mountain. Its miner digs only
-- what lies within its "reach" (jobs.lua), so when that's dug out the mine stops.

-- Per building type (k + 1): the resource kind (index + 1, as res_at gives it) its footprint must touch, or -1 for none.
local against = {}
for k = 0, building_type_count() - 1 do
  local name = building_type(k).against
  against[k + 1] = -1
  if name then
    local r = resource_index(name)
    assert(r >= 0, "buildings.json against: no resource " .. name)
    against[k + 1] = r + 1
  end
end

-- Whether a seam of resource r, not dug out, touches the footprint at cx, cy (size sx, sy): one of the cells round it.
local function touches(r, cx, cy, sx, sy)
  for y = cy - 1, cy + sy do
    for x = cx - 1, cx + sx do
      local edge = x < cx or x >= cx + sx or y < cy or y >= cy + sy
      if edge and x >= 0 and y >= 0 and x < W and y < H then
        local c = y * W + x
        if res_at(c) == r and amount(c) > 0 then return true end
      end
    end
  end
  return false
end

function mines_can_place(p, k, cx, cy, sx, sy)
  local r = against[k + 1]
  return r < 0 or touches(r, cx, cy, sx, sy)
end
