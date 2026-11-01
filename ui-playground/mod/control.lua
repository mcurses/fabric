local R=require('runtime')
local S=require('snapshots')
local W=require('workspaces')
local ui=require('ui')
local world=require('world')
local review=require('overrides')
local metadata=require('metadata')
local placement=require('placement')
local navigation=require('navigation')
local library=require('library')
local components=require('components')
local settings=require('fabric_settings')
local pending=true
local function state(p)
  storage.players=storage.players or {}
  local s=storage.players[p.index] or {builds=0};storage.players[p.index]=s
  W.init(s);W.attach(p,s);return s
end
local function sync(p,s) W.select_camera(p,s) end
local function safe(p,fn)
  local ok,err=pcall(fn)
  if not ok then log(err);p.print('[Fabric] '..tostring(err)) end
end
local function refresh(p,s)
  sync(p,s)
  if p.gui.screen[ui.root] then ui.build(p,s) end
end
local function sandbox(p)
  p.cheat_mode=true;p.force.research_all_technologies()
  if p.controller_type~=defines.controllers.editor then p.set_controller{type=defines.controllers.editor} end
  game.tick_paused=false
end
local function open_editor(p,s)
  sandbox(p);library.close(p);sync(p,s);ui.build(p,s);p.gui.screen[ui.root].bring_to_front();ui.raise_rows(p,s)
end
script.on_init(function() storage.players={} end)
script.on_load(function() pending=true end)
script.on_event(defines.events.on_tick,function(e)
  if script.active_mods['fabric-ui-test-driver'] and script.test_arg=='unit' then return end
  if pending then
    pending=false
    for _,p in pairs(game.connected_players) do safe(p,function()
      sandbox(p);local s=state(p);sync(p,s);if s.parent_template then R.underlay(p,s.parent_template) end;components.meta_bar(p);navigation.show(p,s)
      if p.gui.screen[ui.root] then ui.build(p,s) end
    end) end
  end
  for _,p in pairs(game.connected_players) do
    local s=storage.players and storage.players[p.index]
    if s and s.snapshot_schema then
      if s.placement and s.placement.build and s.placement.build.tick<e.tick then
        safe(p,function()
          local draft=s.placement;local build=draft.build
          for _,entity in ipairs(draft.built or {}) do if entity.valid then entity.destroy() end end
          if draft.parent and draft.before then R.render_editor(p,draft.parent,draft.before) end
          placement.finish(p,s,build.position)
          p.clear_cursor();refresh(p,s)
        end)
      end
      if e.tick%6==0 then safe(p,function() if W.select_camera(p,s) and p.gui.screen[ui.root] then ui.build(p,s) end end) end
      if e.tick%120==0 and s.parent_template then
        local dirty=R.dirty(s.parent_template)
        safe(p,function()
          R.check_dirty(s.parent_template)
          if dirty~=R.dirty(s.parent_template) then ui.refresh_summary(p,s) end
        end)
      end
      world.tick(s,e.tick)
      if s.drag and e.tick-s.drag.tick>=45 then
        local drag=s.drag;s.drag=nil;s.pending_order=drag
        safe(p,function() ui.layout(p,s,nil,true) end)
      end
      if e.tick%180==0 and s.workspace=='world' and not s.drag and not s.pending_order and not s.placement and s.world_dirty then
        safe(p,function() R.scan_patches();s.world_dirty=false;if p.gui.screen[ui.root] then ui.refresh_rows(p,s) end end)
      end
    end
  end
end)
script.on_event(defines.events.on_player_created,function(e)
  if script.active_mods['fabric-ui-test-driver'] and script.test_arg=='unit' then return end
  local p=game.get_player(e.player_index);safe(p,function() sandbox(p);local s=state(p);sync(p,s);if s.parent_template then R.underlay(p,s.parent_template) end;components.meta_bar(p);navigation.show(p,s) end)
end)
script.on_event('fabric-ui-reload',function() game.reload_mods() end)
script.on_event('fabric-ui-open',function(e) local p=game.get_player(e.player_index);safe(p,function() open_editor(p,state(p)) end) end)
script.on_event('fabric-ui-screenshot',function(e) local p=game.get_player(e.player_index);game.take_screenshot{player=p,show_gui=true,path='fabric-ui/'..game.tick..'.png'} end)
script.on_event(defines.events.on_gui_click,function(e)
  if not e.element.valid then return end
  local p=game.get_player(e.player_index)
  safe(p,function()
    local s=state(p);local t=e.element.tags
    if not t.action then
      local el=e.element
      while el and el.valid do
        if el.tags.fabric_ui_row and e.element.name~='grip' then
          world.focus(p,s,el.tags.id);review.show(p,s,el.tags.id);return
        elseif el.tags.override_change then review.preview(p,s,el.tags.id,el.tags.change,true);return
        elseif el.name==ui.root then ui.raise_rows(p,s);return end
        el=el.parent
      end
      return
    end
    local a=t.action
    if a=='reload' then game.reload_mods()
    elseif a=='world' or a=='collection' then W.switch(p,s,a);ui.close(p)
    elseif a=='edit_current' then open_editor(p,s)
    elseif a=='fabric_controls_close' then navigation.close(p,s)
    elseif a=='library' then library.show(p,s)
    elseif a=='library_close' then library.close(p)
    elseif a=='library_select' then library.close(p);W.focus_template(p,s,t.id);ui.build(p,s)
    elseif a=='template_new' then metadata.show(p,s,true)
    elseif a=='metadata_open' then metadata.show(p,s)
    elseif a=='metadata_close' then metadata.close(p)
    elseif a=='category_new' then metadata.new_category(p)
    elseif a=='category_close' then metadata.close_category(p)
    elseif a=='category_create' then metadata.create_category(p,s)
    elseif a=='metadata_save' then
      local saved,created=metadata.save(p,s)
      if saved then if created then library.close(p);ui.build(p,s) end;refresh(p,s);if p.gui.screen[library.name] then library.show(p,s) end end
    elseif a=='fabric_settings' then settings.show(p)
    elseif a=='settings_close' then settings.close(p)
    elseif a=='settings_apply' then settings.apply(p);refresh(p,s)
    elseif a=='toggle_underlay' then
      local template=s.parent_template
      if template then template.show_underlay=template.show_underlay==false;R.underlay(p,template) end
    elseif a=='template_changes' then
      if s.parent_template then s.reviewing_parent=true;review.edit(p,s,s.parent_template.id,nil,'edit_start') end
    elseif a=='edit_start' or a=='edit_exit' or a=='edit_commit' or a=='edit_discard' then
      review.edit(p,s,t.id,nil,a);sync(p,s);ui.refresh_summary(p,s);ui.refresh_rows(p,s)
    elseif a=='change_reset' or a=='patch_accept' or a=='patch_commit' or a=='patch_discard' then
      review.edit(p,s,t.id,t.change,a);sync(p,s);ui.refresh_summary(p,s);ui.refresh_rows(p,s)
    elseif a=='overrides_close' then review.close(p,s)
    elseif a=='patch_template' then
      for _,ref in ipairs(s.items) do if ref.id==t.id and ref.template_id then
        review.close(p,s);W.focus_template(p,s,ref.template_id);ui.build(p,s);break
      end end
    elseif a=='rebuild_instance' then R.rebuild_world(p);refresh(p,s)
    elseif a=='apply_order' then
      local order=s.pending_order;s.pending_order=nil;s.drag=nil
      if order then R.apply_order(p,s,order.preview);refresh(p,s) end
    elseif a=='add' then
      if s.parent_template or s.camera_area then placement.show(p,s) else p.print('Move the camera into an instance or template first.') end
    elseif a=='placement_picker' then placement.picker(p,s)
    elseif a=='placement_pick' then placement.pick(p,s,t.index)
    elseif a=='placement_close' then placement.close(p,s)
    elseif a=='placement_confirm' then if placement.confirm(p,s) then refresh(p,s) end
    elseif a=='remove' then
      local old=p.gui.screen.fabric_remove_confirm;if old then old.destroy() end
      local panel=p.gui.screen.add{type='frame',name='fabric_remove_confirm',direction='vertical'}
      components.titlebar(panel,{title='Remove Template?',close_tags={action='remove_cancel'}})
      for _,ref in ipairs(s.items) do if ref.id==t.id then panel.add{type='label',caption='Remove '..ref.name..' from this instance?'} end end
      local buttons=panel.add{type='flow'}
      buttons.add{type='button',caption='Cancel',tags={action='remove_cancel'}}
      buttons.add{type='button',caption='Remove',tags={action='remove_confirm',id=t.id}};panel.auto_center=true
    elseif a=='remove_cancel' then local panel=p.gui.screen.fabric_remove_confirm;if panel then panel.destroy() end
    elseif a=='remove_confirm' then
      local panel=p.gui.screen.fabric_remove_confirm;if panel then panel.destroy() end
      R.remove_reference(p,s,t.id);sync(p,s);ui.refresh_rows(p,s)
    elseif a=='tuning' then ui.show_tuning(p,s)
    elseif a=='tune' then ui.adjust(p,s,e.element)
    elseif a=='close' then s.location=p.gui.screen[ui.root].location;world.clear(s);ui.close(p)
    end
  end)
end)
script.on_event(defines.events.on_gui_hover,function(e)
  if not e.element.valid then return end
  local p=game.get_player(e.player_index);local s=storage.players and storage.players[p.index];if not s then return end
  local el=e.element
  if el.tags.preview_template then safe(p,function() placement.preview(p,s,el.tags.preview_template);s.hover_element=e.element.index end);return end
  while el and el.valid do
    if el.tags.fabric_ui_row then safe(p,function() world.highlight(p,s,el.tags.id);s.hover_element=e.element.index end);return
    elseif el.tags.override_change then safe(p,function() review.preview(p,s,el.tags.id,el.tags.change,false);s.hover_element=e.element.index end);return
    elseif el.name==ui.root then ui.raise_rows(p,s);return end
    el=el.parent
  end
end)
script.on_event(defines.events.on_gui_leave,function(e)
  local s=storage.players and storage.players[e.player_index]
  if s and e.element.valid and s.hover_element==e.element.index then world.clear(s) end
end)
script.on_event(defines.events.on_gui_selection_state_changed,function(e)
  if not e.element.valid then return end
  local p=game.get_player(e.player_index);safe(p,function()
    local s=state(p);local a=e.element.tags.action
    if a=='placement_template' or a=='placement_position' then placement.refresh(p,s)
    elseif a=='metadata_layout' then metadata.layout(p)
    elseif a=='tuning_target' then ui.select_tuning(p,s,e.element.selected_index)
    elseif a=='highlight_style' then world.set_style(p,s,e.element.selected_index) end
  end)
end)
script.on_event(defines.events.on_gui_location_changed,function(e)
  if not e.element.valid then return end
  local p=game.get_player(e.player_index);local s=storage.players and storage.players[p.index];if not s then return end
  safe(p,function()
    if e.element.name==ui.root then s.location=e.element.location;ui.layout(p,s,nil,true)
    elseif e.element.tags.fabric_ui_row then s.drag=s.drag or {id=e.element.tags.id};s.drag.tick=game.tick;ui.move(p,s,e.element.tags.id,e.element.location.y) end
  end)
end)
script.on_event(defines.events.on_player_changed_surface,function(e)
  local p=game.get_player(e.player_index);local s=storage.players and storage.players[p.index]
  if s and s.snapshot_schema then safe(p,function() if W.sync(p,s) then ui.close(p) end end) end
end)
script.on_event(defines.events.on_lua_shortcut,function(e)
  if e.prototype_name=='fabric-ui-library' then local p=game.get_player(e.player_index);safe(p,function() navigation.toggle(p,state(p)) end) end
end)
script.on_event(defines.events.on_pre_build,function(e)
  local p=game.get_player(e.player_index);local s=storage.players and storage.players[p.index]
  if s and s.placement and s.placement.free then
    local transform={direction=e.direction,flip_horizontal=e.flip_horizontal,flip_vertical=e.flip_vertical}
    -- Native 2x2 absolute snapping rotates/mirrors around the grid square's
    -- center (1,1), while stored references transform around their origin.
    local pivot=S.point({x=1,y=1},transform)
    local position={x=e.position.x+1-pivot.x,y=e.position.y+1-pivot.y}
    s.placement.build={position=position,direction=e.direction,flip_horizontal=e.flip_horizontal,flip_vertical=e.flip_vertical,tick=e.tick}
    s.placement.built={}
    if s.parent_template then s.placement.before=R.capture(s.parent_template) end
  end
end)
script.on_event(defines.events.on_built_entity,function(e)
  local s=storage.players and storage.players[e.player_index]
  if s then s.world_dirty=true end
  if s and s.placement and s.placement.build then s.placement.built[#s.placement.built+1]=e.entity end
end)
local function world_changed(e)
  for _,s in pairs(storage.players or {}) do s.world_dirty=true end
end
script.on_event({defines.events.on_player_mined_entity,defines.events.on_robot_mined_entity,
  defines.events.on_entity_died,defines.events.on_player_rotated_entity,defines.events.on_entity_settings_pasted,
  defines.events.on_gui_closed,defines.events.on_player_built_tile,defines.events.on_player_mined_tile},world_changed)
script.on_event(defines.events.on_player_cursor_stack_changed,function(e)
  local p=game.get_player(e.player_index);local s=storage.players and storage.players[p.index]
  if s and s.placement and s.placement.free and not s.placement.build and (not p.cursor_stack.valid_for_read or p.cursor_stack.name~='blueprint') then placement.close(p,s) end
end)
script.on_event(defines.events.on_chunk_generated,function(e) R.on_chunk(e.surface,e.area) end)
commands.add_command('ui','Open Fabric editor, or /ui reload',function(e)
  local p=e.player_index and game.get_player(e.player_index)
  if p then safe(p,function() if e.parameter=='reload' then game.reload_mods() else open_editor(p,state(p)) end end) end
end)

-- Enabled only by the disposable integration-test profile.
if script.active_mods['fabric-ui-test-driver'] then
  remote.add_interface('fabric-ui-test',{
    click=function(index,element)
      script.get_event_handler(defines.events.on_gui_click){player_index=index,element=element}
    end,
    move=function(index,element) script.get_event_handler(defines.events.on_gui_location_changed){player_index=index,element=element} end,
    hover=function(index,element) script.get_event_handler(defines.events.on_gui_hover){player_index=index,element=element} end,
    leave=function(index,element) script.get_event_handler(defines.events.on_gui_leave){player_index=index,element=element} end,
    select=function(index,element)
      script.get_event_handler(defines.events.on_gui_selection_state_changed){player_index=index,element=element}
    end,
    inspect=function(index)
      local s=state(game.get_player(index));local db=R.store();local out={catalog={},cells={},selected=s.parent_template and s.parent_template.id}
      for _,t in ipairs(R.catalog()) do
        out.catalog[#out.catalog+1]={id=t.id,name=t.name,category=t.category,icon=t.icon,width=t.width,height=t.height,padding=t.padding,
          origin_id=t.origin_id,is_origin=t.is_origin,entities=#(t.snapshot.entities or {}),refs=#t.children,committed_refs=#t.committed_refs,
          version=t.version,dirty=R.dirty(t),underlay=t.area and #t.area.underlay or 0,center=t.area and t.area.center}
      end
      for _,c in ipairs(db.cells) do local patches=0;for _,ref in ipairs(c.items) do patches=patches+#(ref.patches or {}) end;out.cells[#out.cells+1]={id=c.id,name=c.name,refs=#c.items,patches=patches,first_ref_id=c.items[1] and c.items[1].id} end
      return out
    end
  })
end
