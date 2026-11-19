-- Steading's hook points, in Lua (Casaide/creel#82): each tick its town rules (economy.lua), then eating (hunger.lua).
-- The files run in name order, so the functions they define are all there by this one.

function on_tick()
  economy_tick()
  hunger_tick()
end
