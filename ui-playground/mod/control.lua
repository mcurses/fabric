local ui = require("ui")
local world = require("world")
local overrides = require("overrides")
local pending = true
local function state(player)
  storage.players = storage.players or {}
  storage.players[player.index] = storage.players[player.index] or {builds=0}
  local s=storage.players[player.index]
  if not s.items then
    s.items={{id=1,name="Iron Plate Pickup"},{id=2,name="Copper Plate Pickup"},{id=3,name="Steel Dropoff"}}
    s.next_id=4
  end
  return s
end
local function sandbox(player)
  local s=state(player)
  if s.sandbox_enabled then return end
  player.cheat_mode=true
  player.force.research_all_technologies()
  player.surface.always_day=true
  if player.controller_type ~= defines.controllers.editor then player.toggle_map_editor() end
  -- Keep runtime UI rebuilding active after entering the editor.
  game.tick_paused=false
  s.sandbox_enabled=true
end
local function rebuild(player)
  local s=state(player); s.builds=s.builds+1
  world.clear(s)
  if not world.styles[s.highlight_style or 5] then s.highlight_style=5 end
  -- Keep a broken layout edit recoverable through the next reload keypress.
  local ok, err=pcall(ui.build,player,s)
  if not ok then player.print("[Fabric UI] "..tostring(err)); log(tostring(err)) end
  log("[Fabric UI] rebuild="..s.builds.." revision="..ui.revision)
end
local function reload(player)
  if game.is_multiplayer() then player.print("Playground reload requires single player."); return end
  game.reload_mods()
end
local function screenshot(player)
  game.take_screenshot{player=player, resolution=player.display_resolution, show_gui=true,
    path="fabric-ui/playground-"..game.tick..".png"}
end
script.on_init(function() storage.players={} end)
-- on_load only changes a local flag. GUI and storage writes wait for a runtime event.
script.on_load(function() pending=true end)
script.on_event(defines.events.on_tick,function(e)
  if pending then
    pending=false
    for _, player in pairs(game.connected_players) do
      sandbox(player)
      local s=state(player)
      if s.world_demo and not s.restored_world_rows_v1 then
        local restored=world.restore_rows(s)
        s.restored_world_rows_v1=true
        player.print("Restored "..restored.." linked demo rows. Hover one to highlight its buildings.")
      end
      rebuild(player)
    end
  end
  for _, player in pairs(game.connected_players) do
    local s=state(player)
    world.tick(s,e.tick)
    -- Factorio exposes movement, not a GUI mouse-release event. Settle after
    -- a short quiet interval instead of fighting every native drag update.
    if s.drag and e.tick-s.drag.tick >= 15 then
      s.drag=nil
      ui.layout(player,s)
    end
  end
end)
script.on_event(defines.events.on_player_created,function(e)
  local p=game.get_player(e.player_index)
  sandbox(p)
  rebuild(p)
end)
script.on_event("fabric-ui-reload",function(e) reload(game.get_player(e.player_index)) end)
script.on_event("fabric-ui-open",function(e) rebuild(game.get_player(e.player_index)) end)
script.on_event("fabric-ui-screenshot",function(e) screenshot(game.get_player(e.player_index)) end)
script.on_event(defines.events.on_gui_click,function(e)
  if not e.element.valid then return end
  local p=game.get_player(e.player_index); local s=state(p)
  local ancestor=e.element
  while ancestor and ancestor.valid do
    if ancestor.name==ui.root then ui.raise_rows(p,s); break end
    ancestor=ancestor.parent
  end
  local t=e.element.tags
  if not t.action then
    if e.button~=defines.mouse_button_type.left then return end
    local target=e.element
    while target and target.valid do
      if target.tags.override_change then
        local ok,err=pcall(overrides.preview,p,s,target.tags.id,target.tags.change,true)
        s.hover_element=e.element.index
        if not ok then world.clear(s); log(tostring(err)) end
        return
      end
      if target.name=="grip" then return end
      if target.tags.fabric_ui_row then
        local ok,err=pcall(function()
          local tuning=p.gui.screen[ui.root.."_tuning"]
          if tuning then tuning.destroy() end
          local group=s.world_demo and s.world_demo.groups[target.tags.id]
          if group then world.focus(p,s,target.tags.id) end
          overrides.show(p,s,target.tags.id)
        end)
        if not ok then p.print("[Fabric UI] "..tostring(err)); log(tostring(err)) end
        return
      end
      target=target.parent
    end
    return
  end
  if t.action=="overrides_open" then
    world.clear(s)
    local tuning=p.gui.screen[ui.root.."_tuning"]
    if tuning then tuning.destroy() end
    local ok,err=pcall(overrides.show,p,s,t.id)
    if not ok then p.print("[Fabric UI] "..tostring(err)); log(tostring(err)) end
  elseif t.action=="overrides_close" then overrides.close(p,s)
  elseif t.action=="override_apply" or t.action=="override_reset" or t.action=="override_seed" then
    local ok,err=pcall(function()
      world.clear(s)
      if overrides.act(s,t.id,t.change,t.action) then
        ui.refresh_rows(p,s)
        overrides.show(p,s,t.id)
      end
    end)
    if not ok then p.print("[Fabric UI] "..tostring(err)); log(tostring(err)) end
  elseif t.action=="reload" then reload(p)
  elseif t.action=="world" then
    local ok,err=pcall(world.open,p,s)
    if not ok then p.print("[Fabric UI] "..tostring(err)); log(tostring(err)) end
  elseif t.action=="restore_world_rows" then
    world.restore_rows(s)
    ui.refresh_rows(p,s)
  elseif t.action=="tuning" then
    local ok,err=pcall(ui.show_tuning,p,s)
    if not ok then p.print("[Fabric UI] "..tostring(err)); log(tostring(err)) end
  elseif t.action=="tune" then
    local ok,err=pcall(ui.adjust,p,s,e.element)
    if not ok then p.print("[Fabric UI] "..tostring(err)); log(tostring(err)) end
  elseif t.action=="screenshot" then screenshot(p)
  elseif t.action=="close" then local root=p.gui.screen[ui.root]; s.location=root.location; s.drag=nil; world.clear(s); ui.close(p)
  elseif t.action=="remove" then
    world.clear(s)
    for i, item in ipairs(s.items) do if item.id==t.id then table.remove(s.items,i); break end end
    s.drag=nil
    ui.refresh_rows(p,s)
  elseif t.action=="add" then
    s.items[#s.items+1]={id=s.next_id,name="New Template "..s.next_id}
    s.next_id=s.next_id+1
    ui.refresh_rows(p,s)
  end
end)
script.on_event(defines.events.on_gui_hover,function(e)
  if not e.element.valid then return end
  local ancestor=e.element
  while ancestor and ancestor.valid do
    if ancestor.tags.override_change then
      local p=game.get_player(e.player_index); local s=state(p)
      local ok,err=pcall(overrides.preview,p,s,ancestor.tags.id,ancestor.tags.change,false)
      if not ok then world.clear(s); log(tostring(err)) end
      s.hover_element=e.element.index
      return
    end
    if ancestor.tags.fabric_ui_row then
      local p=game.get_player(e.player_index); local s=state(p)
      local ok,err=pcall(world.highlight,p,s,ancestor.tags.id)
      if not ok then world.clear(s); log(tostring(err)) end
      s.hover_element=e.element.index
      return
    end
    if ancestor.name==ui.root then
      local p=game.get_player(e.player_index)
      ui.raise_rows(p,state(p))
      return
    end
    ancestor=ancestor.parent
  end
end)
script.on_event(defines.events.on_gui_selection_state_changed,function(e)
  if not e.element.valid or e.element.tags.action~="highlight_style" then return end
  local p=game.get_player(e.player_index)
  local ok,err=pcall(world.set_style,p,state(p),e.element.selected_index)
  if not ok then world.clear(state(p)); p.print("[Fabric UI] "..tostring(err)); log(tostring(err)) end
end)
script.on_event(defines.events.on_gui_leave,function(e)
  if not e.element.valid then return end
  local s=state(game.get_player(e.player_index))
  if s.hover_element==e.element.index then world.clear(s) end
end)
script.on_event(defines.events.on_player_changed_surface,function(e)
  world.clear(state(game.get_player(e.player_index)))
end)
script.on_event(defines.events.on_gui_location_changed,function(e)
  if not e.element.valid then return end
  local p=game.get_player(e.player_index); local s=state(p)
  if e.element.name==ui.root then
    s.location=e.element.location
    ui.layout(p,s,nil,true)
  elseif e.element.tags.fabric_ui_row then
    s.drag={id=e.element.tags.id,tick=e.tick}
    ui.move(p,s,e.element.tags.id,e.element.location.y)
  end
end)
script.on_event({defines.events.on_player_display_scale_changed,defines.events.on_player_display_resolution_changed},function(e)
  local p=game.get_player(e.player_index)
  if p.gui.screen[ui.root] then rebuild(p) end
end)
commands.add_command("ui", "Open the Fabric UI playground; /ui reload to reload scripts",function(e)
  local p=e.player_index and game.get_player(e.player_index)
  if p then if e.parameter=="reload" then reload(p) else rebuild(p) end end
end)
