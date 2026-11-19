-- Steading's hook points, in Lua (Casaide/creel#82): each tick its town rules (economy.lua), the specialists (jobs.lua),
-- then eating (hunger.lua). The files run in name order, so the functions they define are all there by this one.

function on_tick()
  economy_tick()
  jobs_tick()
  hunger_tick()
end

-- What the panel says unit i is doing: eating or resting from hunger first, else its trade.
function task_name(i)
  local s = hunger_task_name(i)
  if s ~= "" then return s end
  return jobs_task_name(i)
end
