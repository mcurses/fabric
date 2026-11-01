local handover=require('handover')
local cleanup=require('__fabric-ui-playground__/cleanup')
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
local jobs=require('jobs')
local usages=require('usages')
local Slots=require('slots')
Slots.bind_preview(world.clear)
Slots.bind_picker(placement)
local handle_click
local pending=true
local function state(p)
  storage.players=storage.players or {}
  local s=storage.players[p.index] or {builds=0};storage.players[p.index]=s
  W.init(s);W.attach(p,s);return s
end
local function sync(p,s) W.select_camera(p,s) end
local function safe(p,fn)
  local ok,err=pcall(fn)
  if not ok then if storage.fabric_job and storage.fabric_job.executing then error(err) end;log(err);p.print('[Fabric] '..tostring(err)) end
end
local function refresh(p,s)
  if storage.fabric_job and not storage.fabric_job.finishing then return end
  sync(p,s)
  if p.gui.screen[ui.root] then ui.build(p,s) end
end
local function sandbox(p)
  p.cheat_mode=true;p.force.research_all_technologies()
  if p.controller_type~=defines.controllers.editor then p.set_controller{type=defines.controllers.editor} end
  game.tick_paused=false
end
local function open_editor(p,s)
  s.pending_order=nil;s.pending_neighbors=nil;s.pending_slots=nil;s.drag=nil;world.clear(s)
  sandbox(p);library.close(p);sync(p,s);ui.build(p,s);p.gui.screen[ui.root].bring_to_front();ui.raise_rows(p,s)
end
local function tick_job()
  if storage.fabric_job and not storage.fabric_job.error then jobs.tick(handle_click,function(p,job)
      for name in pairs(job.close_panels) do local panel=p.gui.screen[name];if panel then panel.destroy() end end
      local s=storage.players[p.index]
      if job.close_panels.fabric_ui_add_template then placement.close(p,s) end
      if job.action=='apply_order' or job.action=='placement_confirm' or job.action=='remove_confirm' or job.action=='toggle_neighbors' then s.pending_order=nil;s.drag=nil end
      s.world_dirty=false;s.template_dirty=nil
      local migration=p.gui.top.fabric_neighbor_upgrade;if migration then migration.destroy() end
      if s.parent_template then review.changes(s.parent_template,true) end
      refresh(p,s)
      if s.override_selected then review.show(p,s,s.override_selected) end
    end) end
end
script.on_init(function() storage.players={} end)
script.on_load(function() pending=true end)
script.on_event(defines.events.on_tick,function(e)
  if script.active_mods['fabric-ui-test-driver'] and script.test_arg=='unit' then return end
  if pending then
    pending=false
    for _,p in pairs(game.connected_players) do safe(p,function()
      sandbox(p);local s=state(p);sync(p,s);
      if not script.active_mods['fabric-ui-test-driver'] and R.store().slots_fix_backup~=2 then R.store().slots_fix_backup=2;game.auto_save('fabric-slot-fixes') end
      if not script.active_mods['fabric-ui-test-driver'] and not R.store().slots_ui_backup then R.store().slots_ui_backup=true;game.auto_save('fabric-before-slots') end
      if not script.active_mods['fabric-ui-test-driver'] and not R.store().responsive_backup then R.store().responsive_backup=true;game.auto_save('fabric-responsive-backup') end
      if not R.store().world_cell_cache_v2 and not storage.fabric_job then R.run_task(p,{kind='world',prime=true}) end
      for _,cell in ipairs(R.store().cells) do R.update_instance_tag(p,cell) end
      if s.parent_template then R.underlay(p,s.parent_template);s.template_dirty=true end;components.meta_bar(p);navigation.show(p,s)
      if not storage.fabric_job and p.gui.screen[ui.root] then ui.build(p,s) end
      if storage.fabric_job then
        if storage.fabric_job.error and storage.fabric_job.action=='cleanup_templates' and not R.store().test_cleanup_done then storage.fabric_job.command=true end
        storage.fabric_job.error=nil
      end
      if not script.active_mods['fabric-ui-test-driver'] and not R.store().test_cleanup_done and not storage.fabric_job then
        game.auto_save('fabric-before-template-cleanup')
        local button=p.gui.top.fabric_cleanup_templates or p.gui.top.add{type='button',name='fabric_cleanup_templates',caption='Cleaning template library',visible=false,tags={action='cleanup_templates'}}
        jobs.start(p,button)
      end
      if not R.store().neighbor_ui_revision and not storage.fabric_job then
        local button=p.gui.top.fabric_neighbor_upgrade or p.gui.top.add{type='button',name='fabric_neighbor_upgrade',caption='Updating neighbor priorities',visible=false,tags={action='neighbor_defaults'}}
        jobs.start(p,button)
      end
    end) end
  end
  if storage.fabric_job then tick_job();return end
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
      library.tick(p,s)
      if e.tick%6==0 then navigation.instance_status(p,s) end
      if s.preview_pending and e.tick>=s.preview_pending.tick then
        local hover=s.preview_pending;s.preview_pending=nil
        if hover.element.valid then safe(p,function() if hover.slot_tags then Slots.preview(p,s,hover.slot_tags) else placement.preview(p,s,hover.id,hover.position) end;s.hover_element=hover.element.index end) end
      end
      if s.template_dirty and s.parent_template then
        s.template_dirty=nil
        safe(p,function()
          review.changes(s.parent_template,true);ui.refresh_summary(p,s)
          if s.reviewing_parent and s.override_selected then review.show(p,s,s.override_selected) end
        end)
      end
      world.tick(s,e.tick)
      if s.drag and e.tick-s.drag.tick>=45 then
        local drag=s.drag;s.drag=nil;if s.placement then s.placement.order=drag.preview;placement.restore_preview(p,s) else s.pending_order=drag end
        safe(p,function() ui.layout(p,s,nil,true) end)
      end
      if e.tick%6==0 and s.workspace=='world' and not s.drag and not s.pending_order and not s.placement and s.world_dirty then
        safe(p,function() R.scan_patches();s.world_dirty=false;if p.gui.screen[ui.root] then ui.refresh_rows(p,s) end;if s.override_selected then review.show(p,s,s.override_selected) end end)
      end
    end
  end
end)
script.on_event(defines.events.on_player_created,function(e)
  if script.active_mods['fabric-ui-test-driver'] and script.test_arg=='unit' then return end
  local p=game.get_player(e.player_index);safe(p,function() sandbox(p);local s=state(p);sync(p,s);if s.parent_template then R.underlay(p,s.parent_template);s.template_dirty=true end;components.meta_bar(p);navigation.show(p,s) end)
end)
script.on_event('fabric-ui-reload',function() game.reload_mods() end)
script.on_event('fabric-ui-open',function(e) local p=game.get_player(e.player_index);safe(p,function() open_editor(p,state(p)) end) end)
script.on_event('fabric-ui-screenshot',function(e) local p=game.get_player(e.player_index);game.take_screenshot{player=p,show_gui=true,path='fabric-ui/'..game.tick..'.png'} end)
handle_click=function(e)
  if not e.element.valid then return end
  local p=game.get_player(e.player_index)
  safe(p,function()
    local s=state(p);local t=e.element.tags
    ui.raise_rows(p,s)
    local job=storage.fabric_job
    if job and not job.executing then return end
    if t.action=='slot_eligible' and not e.data then return end
    if t.action=='slot_assign' and not e.data then e.data={value=t.value} end
    local expensive={cleanup_templates=true,edit_commit=true,edit_discard=true,change_reset=true,patch_accept=true,patch_commit=true,patch_discard=true,
      placement_confirm=true,apply_order=true,remove_confirm=true,metadata_save=true,rebuild_instance=true,create_instance=true,slot_apply=true,slot_delete=true,anchor_apply=true}
    if not job and (t.action=='slot_add' or t.action=='slot_eligible') then local count=#(s.parent_template.slot_definitions or {})+(t.action=='slot_add' and 1 or 0);local eligible=t.action=='slot_eligible' and e.data.value or false;local ok,reason=Slots.can_configure(s.parent_template,count,eligible);if not ok then p.print(reason);refresh(p,s);return end end
    if t.action=='metadata_save' and not job then local ok,reason=metadata.validate(p);if not ok then p.print(reason);return end end
    if expensive[t.action] and not job then jobs.start(p,e.element,e.data);return end
    if not t.action then
      local el=e.element
      while el and el.valid do
        if el.tags.fabric_ui_row and e.element.name~='grip' then
          if s.placement and el.tags.id==placement.draft_id then return end
          s.review_slot=nil;s.reviewing_parent=nil;world.focus(p,s,el.tags.id);review.show(p,s,el.tags.id);return
        elseif el.tags.override_change then review.preview(p,s,el.tags.id,el.tags.change,true);return
        elseif el.name==ui.root then ui.raise_rows(p,s);return end
        el=el.parent
      end
      return
    end
    local a=t.action
    if a=='neighbor_defaults' then R.neighbors();R.rebuild_world(p);R.store().neighbor_ui_revision=1
    elseif a=='cleanup_templates' then
      placement.close(p,s);world.clear(s);ui.close(p);s.override_selected=nil;s.reviewing_parent=nil;s.pending_slots=nil;s.pending_order=nil
      cleanup.run(p);sync(p,s)
    elseif a=='reload' then game.reload_mods()
    elseif a=='world' or a=='collection' then placement.close(p,s);s.pending_slots=nil;s.pending_order=nil;s.pending_neighbors=nil;W.switch(p,s,a);ui.close(p)
    elseif a=='edit_current' then open_editor(p,s)
    elseif a=='fabric_controls_close' then navigation.close(p,s)
    elseif a=='anchor_cancel' then Slots.cancel(p,s)
    elseif a=='slot_anchor_pick' then Slots.pick(p,s,t.slot)
    elseif a=='slot_patches' then s.reviewing_parent=nil;s.review_slot=t.slot;review.show(p,s,t.id)
    elseif a=='slot_preview_open' then Slots.author_picker(p,s,t.slot)
    elseif a=='slot_preview_pick' then
      local panel=p.gui.screen.fabric_template_picker;if panel then panel.destroy() end;s.slot_picker=nil
      Slots.author_select(p,s,t.slot,t.value);refresh(p,s)
    elseif a=='slot_preview_remove' then
      local host=s.parent_template;if host and host.slot_previews then host.slot_previews[t.slot]=nil;world.clear(s);R.underlay(p,host);refresh(p,s) end
    elseif a=='slot_open' then Slots.picker(p,s,t.id,t.slot)
    elseif a=='slot_picker_close' then local panel=p.gui.screen.fabric_template_picker;if panel then panel.destroy() end;s.slot_picker=nil;Slots.preview_drafts(p,s)
    elseif a=='slot_assign' then
      local panel=p.gui.screen.fabric_template_picker;if panel then panel.destroy() end;s.slot_picker=nil;world.clear(s)
      Slots.draft(p,s,t.id,t.slot,e.data.value);ui.refresh_rows(p,s)
    elseif a=='slot_apply' then
      local draft=s.pending_slots and s.pending_slots[t.id];world.clear(s)
      if draft then R.assign_slots(p,s,t.id,draft.assignments);s.pending_slots[t.id]=nil end
    elseif a=='slot_add' then Slots.configure(s.parent_template,#(s.parent_template.slot_definitions or {})+1,false);R.store().slot_revision=(R.store().slot_revision or 0)+1;refresh(p,s)
    elseif a=='slot_delete' then Slots.remove(s.parent_template,t.slot);R.refresh_metadata(p,s.parent_template)
    elseif a=='slot_eligible' then Slots.configure(s.parent_template,#(s.parent_template.slot_definitions or {}),e.data.value);R.store().slot_revision=(R.store().slot_revision or 0)+1;refresh(p,s)
    elseif a=='anchor_apply' then R.refresh_metadata(p,R.template(e.data.id))
    elseif a=='create_instance' then R.create_instance(p,p.position);sync(p,s);refresh(p,s)
    elseif a=='show_usages' then usages.show(p,s)
    elseif a=='usages_close' then usages.close(p)
    elseif a=='usage_focus' then usages.focus(p,s,t.index);ui.build(p,s)
    elseif a=='toggle_neighbors' then
      local cell=s.camera_area
      if cell then
        local current=s.pending_neighbors;if current==nil then current=cell.neighbors_expanded or false end
        s.pending_neighbors=not current
        if s.pending_neighbors==(cell.neighbors_expanded or false) then s.pending_neighbors=nil end
        ui.refresh_rows(p,s)
      end
    elseif a=='library' then library.show(p,s)
    elseif a=='library_close' then library.close(p)
    elseif a=='library_select' then placement.close(p,s);s.pending_slots=nil;s.pending_order=nil;s.pending_neighbors=nil;library.close(p);W.focus_template(p,s,t.id);ui.build(p,s)
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
        local source=s.review_slot and ref.slot_assignments and ref.slot_assignments[s.review_slot] or ref.template_id;review.close(p,s);W.focus_template(p,s,source);ui.build(p,s);break
      end end
    elseif a=='rebuild_instance' then R.rebuild_world(p);refresh(p,s)
    elseif a=='apply_order' then
      local order=s.pending_order;s.pending_order=nil;s.drag=nil
      if s.pending_neighbors~=nil and s.camera_area then s.camera_area.neighbors_expanded=s.pending_neighbors;s.pending_neighbors=nil;if not s.camera_area.neighbors_expanded then R.collapse_neighbors(s.camera_area) end end
      if order then R.apply_order(p,s,order.preview) else R.rebuild_world(p) end;refresh(p,s)
    elseif a=='add' then
      if s.parent_template or s.camera_area then s.pending_order=nil;placement.show(p,s);ui.refresh_rows(p,s) else p.print('Move the camera into an instance or template first.') end
    elseif a=='placement_positions' then placement.positions(p,s)
    elseif a=='placement_position_pick' then placement.position_pick(p,s,t.index)
    elseif a=='placement_toggle_preview' then s.placement.preview_enabled=not s.placement.preview_enabled;placement.restore_preview(p,s)
    elseif a=='placement_picker' then placement.picker(p,s);if not p.gui.screen.fabric_template_picker and s.pending_slots then Slots.preview_drafts(p,s) end
    elseif a=='placement_pick' then placement.pick(p,s,t.index);ui.refresh_rows(p,s)
    elseif a=='placement_close' then placement.close(p,s);ui.refresh_rows(p,s)
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
      if storage.fabric_job then storage.fabric_job.close_panels.fabric_remove_confirm=true end
      s.pending_order=nil;s.drag=nil
      R.remove_reference(p,s,t.id);sync(p,s);ui.refresh_rows(p,s)
    elseif a=='tuning' then ui.show_tuning(p,s)
    elseif a=='tune' then ui.adjust(p,s,e.element)
    elseif a=='close' then if s.placement then placement.close(p,s) end;s.pending_slots=nil;s.pending_order=nil;s.pending_neighbors=nil;s.drag=nil;s.location=p.gui.screen[ui.root].location;world.clear(s);ui.close(p)
    end
    ui.raise_rows(p,s)
  end)
end
script.on_event(defines.events.on_gui_click,handle_click)
script.on_event(defines.events.on_gui_hover,function(e)
  if not e.element.valid then return end
  local p=game.get_player(e.player_index);local s=storage.players and storage.players[p.index];if not s then return end
  local el=e.element
  if storage.fabric_job then return end
  if el.tags.preview_slot or el.tags.preview_create then s.preview_pending={element=el,slot_tags=el.tags,tick=game.tick+20};return end
  if el.tags.preview_template then s.preview_pending={element=el,id=el.tags.preview_template,position=el.tags.preview_position,tick=game.tick+20};return end
  while el and el.valid do
    if el.tags.preview_anchor~=nil then safe(p,function() Slots.highlight_anchor(p,s,el.tags.preview_anchor);s.hover_element=e.element.index end);return end
    if el.tags.fabric_ui_row and s.pending_slots and next(s.pending_slots) then Slots.preview_drafts(p,s);s.hover_element=e.element.index;return end
    if el.tags.fabric_ui_row and s.placement then return end
    if el.tags.fabric_ui_row then safe(p,function() world.highlight(p,s,el.tags.id);s.hover_element=e.element.index end);return
    elseif el.tags.override_change then safe(p,function() review.preview(p,s,el.tags.id,el.tags.change,false);s.hover_element=e.element.index end);return
    elseif el.name==ui.root then ui.raise_rows(p,s);return end
    el=el.parent
  end
end)
script.on_event(defines.events.on_gui_leave,function(e)
  local s=storage.players and storage.players[e.player_index]
  if s and e.element.valid then
    if s.preview_pending and s.preview_pending.element==e.element then s.preview_pending=nil end
    if s.hover_element==e.element.index then
      local p=game.get_player(e.player_index)
      safe(p,function()
      world.clear(s)
      if s.author_hover and s.parent_template then s.author_hover=nil;R.underlay(p,s.parent_template) end
      if s.pending_slots and next(s.pending_slots) then Slots.preview_drafts(p,s)
      elseif s.placement then placement.restore_preview(p,s)
      elseif s.override_selected then review.preview(p,s,s.override_selected) end
      end)
    end
  end
end)
script.on_event(defines.events.on_gui_selection_state_changed,function(e)
  if not e.element.valid then return end
  local p=game.get_player(e.player_index);safe(p,function()
    local s=state(p);local a=e.element.tags.action
    if a=='slot_assign' then jobs.start(p,e.element,{value=e.element.tags.ids[e.element.selected_index]})
    elseif a=='placement_template' or a=='placement_position' then placement.refresh(p,s);ui.refresh_rows(p,s)
    elseif a=='metadata_layout' then metadata.layout(p)
    elseif a=='tuning_target' then ui.select_tuning(p,s,e.element.selected_index)
    elseif a=='highlight_style' then world.set_style(p,s,e.element.selected_index) end
  end)
end)
script.on_event(defines.events.on_gui_text_changed,function(e)
  if not e.element.valid or storage.fabric_job then return end
  local p=game.get_player(e.player_index);local s=state(p)
  safe(p,function()
    if e.element.tags.action=='placement_search' then s.preview_pending=nil;placement.fill_picker(p,s)
 end
  end)
end)
script.on_event(defines.events.on_gui_checked_state_changed,function(e)
  if e.element.valid and e.element.tags.action=='slot_eligible' then local p=game.get_player(e.player_index);handle_click{player_index=p.index,element=e.element,data={value=e.element.state}} end
end)
script.on_event(defines.events.on_gui_opened,function(e)
  local s=storage.players and storage.players[e.player_index]
  if s and s.anchor_pick and e.entity then local p=game.get_player(e.player_index);safe(p,function() local id=Slots.select(p,s,e.entity);if id then local button=p.gui.top.fabric_anchor_apply or p.gui.top.add{type='button',name='fabric_anchor_apply',visible=false,tags={action='anchor_apply'}};jobs.start(p,button,{id=id}) end end) end
end)
script.on_event(defines.events.on_gui_location_changed,function(e)
  if not e.element.valid then return end
  local p=game.get_player(e.player_index);local s=storage.players and storage.players[p.index];if not s then return end
  safe(p,function()
    if e.element.name==ui.root then s.location=e.element.location;ui.layout(p,s,nil,true)
    elseif e.element.tags.fabric_ui_row then if s.placement and e.element.tags.id~=placement.draft_id then ui.layout(p,s,nil,true);return end;s.drag=s.drag or {id=e.element.tags.id};s.drag.tick=game.tick;ui.move(p,s,e.element.tags.id,e.element.location.y) end
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
  if s and not storage.fabric_job then s.world_dirty=true;s.template_dirty=true end
  if s and s.placement and s.placement.build then s.placement.built[#s.placement.built+1]=e.entity end
end)
local function world_changed(e)
  local player=e.player_index and game.get_player(e.player_index)
  local state=player and storage.players and storage.players[player.index]
  if state and state.anchor_pick and e.gui_type==defines.gui_type.none then
    Slots.cancel(player,state)
  end
  if storage.fabric_job then return end
  for _,s in pairs(storage.players or {}) do s.world_dirty=true;s.template_dirty=true end
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
  if p then safe(p,function() if e.parameter=='reload' then game.reload_mods() elseif e.parameter=='save' then game.auto_save('fabric-responsive-backup') else open_editor(p,state(p)) end end) end
end)

-- Enabled only by the disposable integration-test profile.
if script.active_mods['fabric-ui-test-driver'] then
  remote.add_interface('fabric-ui-test',{
    prepare_handover=function(index)
      local p=game.get_player(index);local catalog=handover.prepare(p);open_editor(p,state(p));return catalog
    end,
    drain=function(index)
      local n=0
      while storage.fabric_job do
        assert(not storage.fabric_job.error,storage.fabric_job.error)
        tick_job();n=n+1;assert(n<10000,'Job must terminate')
      end
      local s=storage.players[index];while s.library_queue do library.tick(game.get_player(index),s) end
      return n
    end,
    text=function(index,element) script.get_event_handler(defines.events.on_gui_text_changed){player_index=index,element=element} end,
    checked=function(index,element) script.get_event_handler(defines.events.on_gui_checked_state_changed){player_index=index,element=element} end,
    opened=function(index,entity) script.get_event_handler(defines.events.on_gui_opened){player_index=index,entity=entity} end,
    busy=function() return storage.fabric_job~=nil end,

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
      local s=state(game.get_player(index));local db=R.store();local out={preview_count=#(s.preview_ghosts or {}),last_rebuilt_cells=db.last_rebuilt_cells,catalog={},cells={},selected=s.parent_template and s.parent_template.id,review_count=#(s.review_changes or {}),highlight_count=#(s.highlight_objects or {}),usages=s.usages,job=storage.fabric_job and {index=storage.fabric_job.index,total=#storage.fabric_job.tasks}}
      for _,t in ipairs(R.catalog()) do
        out.catalog[#out.catalog+1]={id=t.id,name=t.name,category=t.category,icon=t.icon,width=t.width,height=t.height,padding=t.padding,
          origin_id=t.origin_id,is_origin=t.is_origin,entities=#(t.snapshot.entities or {}),refs=#t.children,committed_refs=#t.committed_refs,
          captures=t.capture_serial or 0,slot_count=#(t.slot_definitions or {}),slot_eligible=t.slot_eligible,slot_anchor=t.slot_anchor,slot_definitions=t.slot_definitions,preview_refs=(function() local n=0;for _,r in ipairs(t.children) do if r.preview_only then n=n+1 end end;return n end)(),version=t.version,dirty=R.dirty(t),underlay=t.area and #t.area.underlay or 0,center=t.area and t.area.center}
      end
      for _,c in ipairs(db.cells) do local patches=0;for _,ref in ipairs(c.items) do patches=patches+#(ref.patches or {}) end;out.cells[#out.cells+1]={id=c.id,name=c.name,neighbors_expanded=c.neighbors_expanded or false,refs=#c.items,items=S.copy(c.items),center=c.center,patches=patches,first_ref_id=c.items[1] and c.items[1].id} end
      return out
    end
  })
end
