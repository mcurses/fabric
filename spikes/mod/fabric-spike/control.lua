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
script.on_event("fabric-spike-on_tags_changed", s5.on_tags_changed)
script.on_event("cybersyn2-combinator-on_tags_changed", s5.on_tags_changed)
remote.add_interface("fabric-spike-s5", { setup = s5.setup, step = s5.step, eval = s5.eval, names = s5.names, leak = s5.leak,
  play_setup = s5.play_setup, play_report = s5.play_report })

-- In-game check: "/s5 <label>" prints and stores the identity report, "/s5 setup" rebuilds the pieces.
commands.add_command("s5", "Fabric spike S5: /s5 setup, or /s5 <label> to report piece identity", function(cmd)
  local p = cmd.player_index and game.get_player(cmd.player_index)
  if cmd.parameter == "setup" then
    s5.play_setup()
    storage.play_log = {}
    if p then
      p.admin = true
      p.teleport({ 0, 2 })
      if p.controller_type ~= defines.controllers.editor then p.toggle_map_editor() end
      p.print("S5 pieces built: two constant combinators, inserter, requester chest, assembler. Editor is on.")
    end
    return
  end
  local lines = s5.play_report()
  storage.play_log = storage.play_log or {}
  storage.play_log[#storage.play_log + 1] = { label = cmd.parameter or "", lines = lines }
  if p then for _, l in ipairs(lines) do p.print(l) end end
end)
remote.add_interface("fabric-spike-play", { log = function() return storage.play_log end })
