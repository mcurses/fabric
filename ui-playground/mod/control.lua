local collection=require("collection")
local metadata=require("metadata")
local placement=require("placement")
local navigation=require("navigation")
local library=require("library")
local workspaces=require("workspaces")
local ui = require("ui")
local components=require("components")
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
  workspaces.init(s)
  return s
end
local function sandbox(player)
  local s=state(player)
  if s.sandbox_enabled then
    if player.controller_type~=defines.controllers.editor then player.set_controller{type=defines.controllers.editor} end
    game.tick_paused=false
    return
  end
  player.cheat_mode=true
  player.force.research_all_technologies()
  player.surface.always_day=true
  if player.controller_type ~= defines.controllers.editor then player.set_controller{type=defines.controllers.editor} end
  -- Keep runtime UI rebuilding active after entering the editor.
  game.tick_paused=false
  s.sandbox_enabled=true
end
local function rebuild(player)
  local s=state(player); s.builds=s.builds+1
  world.clear(s)
  -- Older mock placements left persistent map names and origin markers.
  for _,object in pairs(rendering.get_all_objects()) do
    if object.valid and (object.type=="text" or object.type=="circle") then object.visible=false end
  end
  if not world.styles[s.highlight_style or 5] then s.highlight_style=5 end
  -- Keep a broken layout edit recoverable through the next reload keypress.
  local ok, err=pcall(function()
    components.meta_bar(player)
    navigation.show(player,s)
    if player.gui.screen[ui.root] then ui.build(player,s) end
  end)
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
      if s.workspace=="world" and (not s.world_demo or player.surface~=s.world_demo.surface) then
        local ok,err=pcall(workspaces.switch,player,s,"world")
        if not ok then log(tostring(err)) end
      end
      rebuild(player)
    end
  end
  for _, player in pairs(game.connected_players) do
    local s=state(player)
    if e.tick%6==0 then
      local ok,changed=pcall(workspaces.select_camera,player,s)
      if ok and changed and player.gui.screen[ui.root] then ui.build(player,s)
      elseif not ok then log(tostring(changed)) end
    end
    if s.clear_placement_cursor then
      s.placement_build_group=nil
      s.clear_placement_cursor=nil
      if player.cursor_stack.valid_for_read and player.cursor_stack.name==placement.tool then player.clear_cursor() end
    end
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
script.on_event("fabric-ui-open",function(e) local p=game.get_player(e.player_index); ui.build(p,state(p)) end)
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
          s.reviewing_parent=nil
          s.editing_id=nil
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
  if string.sub(t.action,1,5)=="edit_" and t.action~="edit_current" then
    local ok,err=pcall(function()
      overrides.edit(p,s,t.id,t.change,t.action)
      ui.refresh_summary(p,s)
    end)
    if not ok then p.print("[Fabric UI] "..tostring(err)); log(tostring(err)) end
  elseif t.action=="overrides_open" then
    world.clear(s)
    local tuning=p.gui.screen[ui.root.."_tuning"]
    if tuning then tuning.destroy() end
    local ok,err=pcall(overrides.show,p,s,t.id)
    if not ok then p.print("[Fabric UI] "..tostring(err)); log(tostring(err)) end
  elseif t.action=="patch_template" then
    for _,item in ipairs(s.items) do
      if item.id==t.id then
        local template=workspaces.source_template(p,s,item)
        overrides.close(p,s)
        library.close(p)
        workspaces.focus_template(p,s,template.id)
        ui.build(p,s)
        break
      end
    end
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
  elseif t.action=="fabric_controls_close" then navigation.close(p,s)
  elseif t.action=="edit_current" then
    library.close(p)
    navigation.close_new(p)
    s.override_selected=nil
    s.editing_id=nil
    s.reviewing_parent=nil
    workspaces.sync(p,s)
    sandbox(p)
    p.zoom=0.65
    workspaces.select_camera(p,s)
    ui.build(p,s)
    p.gui.screen[ui.root].bring_to_front()
    ui.raise_rows(p,s)
  elseif t.action=="template_new" then metadata.show(p,s,true)
  elseif t.action=="template_new_close" then metadata.close(p)
  elseif t.action=="library" then
    library.show(p,s)
  elseif t.action=="library_close" then library.close(p)
  elseif t.action=="library_select" then
    library.close(p)
    workspaces.focus_template(p,s,t.id)
    ui.build(p,s)
  elseif t.action=="reload" then reload(p)
  elseif t.action=="world" or t.action=="collection" then
    local ok,err=pcall(function()
      workspaces.switch(p,s,t.action)
      sandbox(p); p.zoom=0.65
      ui.close(p)
    end)
    if not ok then p.print("[Fabric UI] "..tostring(err)); log(tostring(err)) end
  elseif t.action=="metadata_open" then metadata.show(p,s)
  elseif t.action=="metadata_close" then metadata.close(p)
  elseif t.action=="category_new" then metadata.new_category(p)
  elseif t.action=="category_close" then metadata.close_category(p)
  elseif t.action=="category_create" then metadata.create_category(p,s)
  elseif t.action=="metadata_save" then
    local saved,created=metadata.save(p,s)
    if saved then
      if created then library.close(p) end
      ui.build(p,s)
      if p.gui.screen[library.name] then library.show(p,s) end
    end
  elseif t.action=="template_changes" then
    if s.parent_template then
      -- The parent uses the same change panel; supply it temporarily for rendering.
      s.reviewing_parent=true
      overrides.edit(p,s,s.parent_template.id,nil,"edit_start")
    end
  elseif t.action=="restore_world_rows" then
    world.restore_rows(s)
    ui.refresh_rows(p,s)
  elseif t.action=="tuning" then
    local ok,err=pcall(function()
      ui.show_tuning(p,s)
    end)
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
    if s.workspace=="collection" and not s.parent_template then return end
    placement.show(p,s)
  elseif t.action=="placement_close" then placement.close(p,s)
  elseif t.action=="placement_confirm" then
    if placement.confirm(p,s) then ui.refresh_rows(p,s) end

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
  if not e.element.valid then return end
  if e.element.tags.action=="placement_template" or e.element.tags.action=="placement_position" then
    local p=game.get_player(e.player_index)
    placement.refresh(p,state(p))
    return
  end
  if e.element.tags.action=="tuning_target" then
    local p=game.get_player(e.player_index)
    ui.select_tuning(p,state(p),e.element.selected_index)
    return
  end
  if e.element.tags.action~="highlight_style" then return end
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
  local p=game.get_player(e.player_index)
  local s=state(p)
  world.clear(s)
  if workspaces.sync(p,s) then ui.close(p) end
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
  if p then if e.parameter=="reload" then reload(p) else ui.build(p,state(p)) end end
end)

script.on_event(defines.events.on_lua_shortcut,function(e)
  if e.prototype_name=="fabric-ui-library" then
    local p=game.get_player(e.player_index)
    navigation.toggle(p,state(p))
  end
end)

script.on_event(defines.events.on_pre_build,function(e)
  local p=game.get_player(e.player_index)
  local s=state(p)
  if s.placement and s.placement.free and p.cursor_stack.valid_for_read and p.cursor_stack.name==placement.tool then
    s.placement.build={position=e.position,direction=e.direction,
      flip_horizontal=e.flip_horizontal,flip_vertical=e.flip_vertical,tick=e.tick}
  end
end)
script.on_event(defines.events.on_built_entity,function(e)
  local p=game.get_player(e.player_index)
  local s=state(p)
  if s.placement_build_group and s.placement_build_group.tick==e.tick then
    table.insert(s.placement_build_group.group.entities,e.entity)
    return
  end
  local draft=s.placement
  if not draft or not draft.free or not draft.build or draft.build.tick~=e.tick then return end
  local build=draft.build
  if placement.finish(p,s,build.position) then
    local item=s.items[#s.items]
    local group={name=item.name,icon=item.icon,entities={e.entity}}
    s.world_demo.groups[item.id]=group
    s.placement_build_group={tick=e.tick,group=group}
    item.direction=build.direction
    item.flip_horizontal=build.flip_horizontal; item.flip_vertical=build.flip_vertical
    s.clear_placement_cursor=true
    ui.refresh_rows(p,s)
  end
end)
script.on_event(defines.events.on_player_cursor_stack_changed,function(e)
  local p=game.get_player(e.player_index)
  local s=state(p)
  if s.placement and s.placement.free and
    (not p.cursor_stack or not p.cursor_stack.valid_for_read or p.cursor_stack.name~=placement.tool) then
    placement.close(p,s)
  end
end)

script.on_event(defines.events.on_chunk_generated,function(e)
  for _,s in pairs(storage.players or {}) do
    local context=s.contexts and s.contexts.collection
    local demo=context and context.world_demo
    if demo and demo.surface==e.surface then
      collection.void_chunk(e.surface,e.area,demo.areas)
      return
    end
  end
end)
