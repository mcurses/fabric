-- Helpers for Fabric's design spikes. Test-only; results are read over RCON.

local function log_event(event)
  storage.log = storage.log or {}
  local name
  for k, v in pairs(defines.events) do
    if v == event.name then name = k end
  end
  local e = event.entity or event.destination
  storage.log[#storage.log + 1] = {
    tick = event.tick,
    name = name,
    entity = e and e.valid and e.name or nil,
    gui_type = event.gui_type,
  }
end

-- S4: every event that may report a player's settings change on an entity.
for _, name in pairs({
  "on_gui_opened", "on_gui_closed", "on_entity_settings_pasted", "on_pre_entity_settings_pasted",
  "on_player_rotated_entity", "on_player_flipped_entity", "on_entity_logistic_slot_changed",
  "on_entity_color_changed", "on_player_fast_transferred", "on_train_schedule_changed",
  "on_gui_elem_changed", "on_gui_text_changed", "on_gui_checked_state_changed",
  "on_gui_selection_state_changed", "on_gui_value_changed", "on_gui_switch_state_changed",
}) do
  script.on_event(defines.events[name], log_event)
end

remote.add_interface("fabric-spike", {
  log = function() return storage.log or {} end,
  clear_log = function() storage.log = {} end,
})

local s2 = require("s2")
remote.add_interface("fabric-spike-s2", { run = function() return s2.run() end, rail_table = function() return s2.rail_table() end })

local s1 = require("s1")
remote.add_interface("fabric-spike-s1", { run = function() return s1.run() end, sample = function(n) return s1.sample(n) end, probe = function(x) return s1.probe(x) end,
  cs2_step = function(n) return s1.cs2_step(n) end })

local s5 = require("s5")
remote.add_interface("fabric-spike-s5", { setup = s5.setup, step = s5.step, eval = s5.eval, names = s5.names, leak = s5.leak })
