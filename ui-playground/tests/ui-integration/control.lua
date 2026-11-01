local step=0
local origin_id,child_id,origin_center,child_center
local cursor_position
local function find(root,predicate)
  if predicate(root) then return root end
  for _,child in ipairs(root.children or {}) do local got=find(child,predicate);if got then return got end end
end
local function action(p,name,id)
  for _,root in ipairs({p.gui.screen,p.gui.top,p.gui.left}) do
    local el=find(root,function(e) return e.tags.action==name and (not id or e.tags.id==id) end)
    if el then remote.call('fabric-ui-test','click',p.index,el);remote.call('fabric-ui-test','drain',p.index);return end
  end
  error('Missing action '..name)
end
local function inspect(p) return remote.call('fabric-ui-test','inspect',p.index) end
local function choose(p,el,index)
  el.selected_index=index;remote.call('fabric-ui-test','select',p.index,el)
end
local function create(p,name,origin)
  action(p,'template_new')
  local form=p.gui.screen.fabric_ui_metadata
  assert(form and form.template_icon and form.category and form.padding)
  assert(not form.slot_count and not form.slot_eligible,"Slots are configured after creation")
  form.template_name.text=name
  form.template_icon.elem_value={type='item',name='steel-chest'}
  form.padding.text='16'
  if origin then
    choose(p,form.origin_picker,#form.origin_picker.items)
  else
    choose(p,form.origin_picker,1);form.sizes.cell_width.text='32';form.sizes.cell_height.text='32';form.origin_template.state=true
  end
  action(p,'metadata_save')
  assert(not p.gui.screen.fabric_ui_metadata,'Create form must close')
  assert(p.gui.screen.fabric_ui_playground,'Creation must open Edit Template')
  local db=inspect(p);return db.catalog[#db.catalog]
end
local function source(p,id)
  action(p,'library');action(p,'library_select',id)
  assert(inspect(p).selected==id)
end
local function commit(p)
  action(p,'template_changes');assert(p.gui.screen.fabric_ui_overrides)
  action(p,'edit_commit')
end
local function test_slots(p)
  -- Configure a slot-compatible template by selecting a real owned entity.
  source(p,origin_id)
  local form
  local eligible=find(p.gui.screen,function(el)return el.tags.action=='slot_eligible' end);eligible.state=true
  remote.call('fabric-ui-test','checked',p.index,eligible);assert(not remote.call('fabric-ui-test','busy'),'Eligibility is metadata only');remote.call('fabric-ui-test','drain',p.index)
  action(p,'slot_anchor_pick')
  local filler=inspect(p).catalog[origin_id]
  local anchor=p.surface.find_entity('iron-chest',{filler.center.x+3.5,filler.center.y+3.5})
  assert(anchor);remote.call('fabric-ui-test','opened',p.index,anchor);remote.call('fabric-ui-test','drain',p.index)
  assert(inspect(p).catalog[origin_id].slot_anchor,'Selected filler anchor persists')
  local host=create(p,'QA Slot Host',false)
  local positions={{3.5,3.5},{3.5,9.5},{9.5,3.5}}
  for _,pos in ipairs(positions) do p.surface.create_entity{name='steel-chest',position={host.center.x+pos[1],host.center.y+pos[2]},force=p.force} end
  commit(p);action(p,'edit_exit')
  for i=1,3 do action(p,'slot_add') end
  for i,pos in ipairs(positions) do
    local button=find(p.gui.screen,function(el)return el.tags.action=='slot_anchor_pick' and el.tags.slot==i end)
    remote.call('fabric-ui-test','click',p.index,button)
    local entity=p.surface.find_entity('steel-chest',{host.center.x+pos[1],host.center.y+pos[2]})
    remote.call('fabric-ui-test','opened',p.index,entity);remote.call('fabric-ui-test','drain',p.index)
  end
  assert(inspect(p).catalog[host.id].slot_count==3)
  local parent=create(p,'QA Slotted Assembly',false)
  action(p,'add');form=p.gui.screen.fabric_ui_add_template;choose(p,form.template_picker,host.id)
  assert(#form.position_picker.items==2,'Old Left/Right presets are replaced by origin/custom')
  action(p,'placement_confirm')
  local row=find(p.gui.screen,function(el)return el.tags.fabric_ui_row and el.contents and el.contents.item_name.caption=='QA Slot Host' end)
  assert(row and row.slots and #row.slots.children==3,'Host reference has three inline slot selectors')
  for i=1,3 do
    local open=find(p.gui.screen,function(el)return el.tags.action=='slot_open' and el.tags.slot==i end)
    remote.call('fabric-ui-test','click',p.index,open)
    assert(not remote.call('fabric-ui-test','busy'),'Opening a slot picker must not rebuild')
    local picker=p.gui.screen.fabric_template_picker
    local option=find(picker,function(el)return el.tags.action=='slot_assign' and el.tags.value==origin_id end)
    assert(option,'Anchored compatible filler offered')
    remote.call('fabric-ui-test','click',p.index,option);remote.call('fabric-ui-test','drain',p.index)
    local selected=find(p.gui.screen,function(el)return el.tags.action=='slot_open' and el.tags.slot==i end)
    assert(selected.caption:find('QA',1,true),'Selected filler remains visible after rebuild')
  end
  assert(not remote.call('fabric-ui-test','busy'),'Selecting slots only stages previews')
  assert(inspect(p).preview_count>0,'Draft slot ghosts remain visible')
  action(p,'slot_apply')
  commit(p)
  assert(inspect(p).catalog[parent.id].entities==0,'Slot contents are excluded from parent own snapshot')
  action(p,'world');p.teleport({0,0},game.surfaces['Fabric World']);action(p,'edit_current')
  action(p,'add');choose(p,p.gui.screen.fabric_ui_add_template.template_picker,parent.id);action(p,'placement_confirm')
  for _,pos in ipairs(positions) do assert(p.surface.find_entity('iron-chest',pos),'Every slot aligns anchors in World') end
  source(p,origin_id);action(p,'show_usages')
  local slotted=false
  for _,entry in ipairs(inspect(p).usages) do for _,via in ipairs(entry.via) do if via:find('Slot',1,true) then slotted=true end end end
  assert(slotted,'Show Usages traverses slot assignments');action(p,'usages_close')
  p.surface.find_entity('small-lamp',{filler.center.x+12.5,filler.center.y+12.5}).destroy()
  p.surface.create_entity{name='constant-combinator',position={filler.center.x+12.5,filler.center.y+12.5},force=p.force}
  commit(p)
  assert(game.surfaces['Fabric World'].find_entity('constant-combinator',{12.5,12.5}),'Filler commits propagate through slot assignments and nested templates')
  source(p,host.id);action(p,'slot_delete')
  assert(inspect(p).catalog[host.id].slot_count==2,'Slot count remains editable')
  action(p,'world');p.teleport({1600,0},game.surfaces['Fabric World']);action(p,'edit_current')
  action(p,'create_instance')
  assert(inspect(p).last_rebuilt_cells==1,'Creating an isolated instance leaves existing cells untouched')
  local rebuild=p.gui.top.add{type='button',tags={action='rebuild_instance'}}
  action(p,'rebuild_instance');rebuild.destroy()
  assert(inspect(p).last_rebuilt_cells==0,'An unchanged composition skips world rebuild')
  local db=inspect(p);assert(#db.cells==5 and db.cells[5].center.x==1600 and db.cells[5].items[1].origin,'Create instance snaps to World lattice and includes Grid')
  action(p,'add');action(p,'placement_picker');local picker=p.gui.screen.fabric_template_picker
  local common=find(picker,function(el)return el.type=='label' and el.caption=='Most common' end);assert(common)
  picker.search.text='Universal';remote.call('fabric-ui-test','text',p.index,picker.search)
  local matched=0
  for _,el in ipairs(picker.results.children) do if el.tags.preview_template then assert(el.caption:lower():find('universal',1,true));matched=matched+1 end end
  assert(matched>0,'Search filters templates');action(p,'placement_close')
  action(p,'metadata_open')
  local metadata=p.gui.screen.fabric_ui_metadata;metadata.template_name.text='QA Icon Instance';metadata.template_icon.elem_value={type='item',name='iron-chest'}
  action(p,'metadata_save')
  local tags=p.force.find_chart_tags(p.surface,{{1599,-1},{1601,1}})
  assert(#tags==1 and tags[1].text=='QA Icon Instance' and tags[1].icon.name=='iron-chest','Instance icon is a chart tag at cell center')
  p.teleport({1760,0},game.surfaces['Fabric World']);action(p,'edit_current');action(p,'create_instance')
  local adjacent=p.surface.find_entities_filtered{area={{1680,-80},{1840,80}},type='electric-pole'}[1];assert(adjacent)
  p.teleport({1600,0},game.surfaces['Fabric World']);action(p,'edit_current')
  local untouched=game.surfaces['Fabric World'].find_entity('iron-chest',{3.5,9.5});assert(untouched)
  action(p,'add');choose(p,p.gui.screen.fabric_ui_add_template.template_picker,host.id);action(p,'placement_confirm')
  assert(untouched.valid,'Adding a template leaves other cells intact')
  action(p,'slot_open')
  local picker=p.gui.screen.fabric_template_picker
  assert(picker.search and picker.results,'Slots reuse the searchable template picker')
  local option=find(picker,function(el)return el.tags.action=='slot_assign' and el.tags.value==origin_id end)
  assert(option);remote.call('fabric-ui-test','click',p.index,option)
  assert(not remote.call('fabric-ui-test','busy'),'Slot selection does not build')
  local ref=inspect(p).cells[5].items[#inspect(p).cells[5].items]
  assert(not next(ref.slot_assignments or {}),'Draft selection does not mutate applied assignments')
  action(p,'slot_apply')
  assert(inspect(p).last_rebuilt_cells==1 and untouched.valid and adjacent.valid,'Applying slots preserves an adjacent connected cell as well as distant cells')
  local entity=p.surface.find_entity('iron-chest',{1603.5,9.5});assert(entity);entity.destroy()
  action(p,'slot_patches')
  assert(inspect(p).review_count==1,'A slot owns its deleted entity patch')
  action(p,'change_reset')
  assert(p.surface.find_entity('iron-chest',{1603.5,9.5}),'Reset restores the slot entity')
  action(p,'overrides_close')
  local combinator=p.surface.find_entity('constant-combinator',{1612.5,18.5});assert(combinator);combinator.direction=4
  action(p,'slot_patches');assert(inspect(p).review_count==1)
  action(p,'patch_commit')
  assert(game.surfaces['Fabric Templates'].find_entity('constant-combinator',{filler.center.x+12.5,filler.center.y+12.5}).direction==4,'Slot stitch maps changes back through the anchor transform')
  action(p,'overrides_close')
  local empty=find(p.gui.screen,function(el)return el.tags.action=='slot_assign' and el.tags.value==0 and el.tags.slot==1 end)
  remote.call('fabric-ui-test','click',p.index,empty);assert(not remote.call('fabric-ui-test','busy'),'Clearing a slot is staged')
  action(p,'slot_apply')
  ref=inspect(p).cells[5].items[#inspect(p).cells[5].items];assert(not next(ref.slot_assignments or {}),'Apply empties the selected slot')
  log('SLOT_DRAFT_PATCH_CELL_ISOLATION_ICON_PASS')
  log('SLOTS_ANCHORS_NESTING_CREATE_INSTANCE_SEARCH_PASS')
  return parent.id
end
local reloaded=false
script.on_load(function() reloaded=true end)
script.on_event(defines.events.on_tick,function(e)
  local p=game.get_player(1);if not p then return end
  if reloaded and storage.resume_job then
    if remote.call('fabric-ui-test','busy') then return end
    origin_id=storage.origin_id;child_id=storage.child_id
    assert(inspect(p).catalog[origin_id].entities==2,'Queued commit survives Lua reload')
    storage.idle_captures=inspect(p).catalog[origin_id].captures;storage.idle_tick=e.tick
    reloaded=false;step=7;log('QUEUED_RELOAD_PASS');return
  end
  if reloaded then
    local db=inspect(p)
    local t=db.catalog[storage.origin_id];local child=db.catalog[storage.child_id]
    assert(t and t.name=='QA Renamed Origin' and t.entities==1)
    assert(child and child.committed_refs==1 and child.entities==0)
    assert(game.surfaces['Fabric World'].find_entity('iron-chest',{4.5,4.5}))
    log('SAVE_RELOAD_PASS');reloaded=false;step=100;return
  end
  if step==0 and e.tick>=2 then
    for _,cell in ipairs(inspect(p).cells) do assert(cell.patches==0,'Fresh world must have no false patches') end
    local t=create(p,'QA Origin',false);origin_id=t.id;origin_center=t.center
    assert(t.width==32 and t.height==32 and t.padding==16 and t.is_origin)
    p.surface.create_entity{name='steel-chest',position={p.position.x+3.5,p.position.y+3.5},force=p.force}
    commit(p);assert(inspect(p).catalog[origin_id].entities==1)
    action(p,'edit_exit');assert(not p.gui.screen.fabric_ui_overrides)
    local child=create(p,'QA Child',true);child_id=child.id;child_center=child.center
    assert(child.origin_id==origin_id and child.refs==0 and child.underlay>0)
    action(p,'add')
    local form=p.gui.screen.fabric_ui_add_template
    assert(form.template_picker.selected_index==0 and not form.confirm.enabled,'No template is preselected')
    choose(p,form.template_picker,origin_id);choose(p,form.position_picker,#form.position_picker.items)
    action(p,'placement_picker')
    local picker=p.gui.screen.fabric_template_picker;assert(picker)
    local candidate=find(picker,function(el)return el.tags.preview_template==origin_id end);assert(candidate)
    remote.call('fabric-ui-test','hover',p.index,candidate)
    assert(p.surface.count_entities_filtered{type='entity-ghost',force='Fabric Preview'}>0,'Picker hover uses native ghost artwork')
    remote.call('fabric-ui-test','leave',p.index,candidate)
    action(p,'placement_picker')
    action(p,'placement_confirm');assert(p.cursor_stack.valid_for_read and p.cursor_stack.name=='blueprint')
    p.build_from_cursor{position={p.position.x+6,p.position.y+6},direction=defines.direction.east,flip_horizontal=true,build_mode=defines.build_mode.forced}
    local ghost=p.surface.find_entities_filtered{type='entity-ghost',ghost_name='steel-chest',force=p.force,area={{child_center.x-32,child_center.y-32},{child_center.x+32,child_center.y+32}}}[1]
    ghost=ghost or p.surface.find_entities_filtered{name='steel-chest',area={{child_center.x-32,child_center.y-32},{child_center.x+32,child_center.y+32}}}[1]
    assert(ghost,'Native cursor must actually place an entity')
    cursor_position=ghost.position
    log('NATIVE_CURSOR_POS '..cursor_position.x..','..cursor_position.y..' center='..child_center.x..','..child_center.y)
    step=1;return
  elseif step==1 then
    -- The mod finalizes native placement on the following tick.
    step=2;return
  elseif step==2 then
    local db=inspect(p);assert(db.catalog[child_id].refs==1,'Native cursor placement must create a reference')
    assert(p.surface.find_entity('steel-chest',{child_center.x+4.5,child_center.y+4.5}),'Native rotation and mirror must match the reference')
    assert(p.surface.find_entity('steel-chest',cursor_position),'Final reference must match the actual cursor preview position')
    commit(p);assert(inspect(p).catalog[child_id].entities==0,'Nested content must not be captured as own content')
    action(p,'world');p.teleport({0,0},game.surfaces['Fabric World']);action(p,'edit_current')
    action(p,'add');local form=p.gui.screen.fabric_ui_add_template;choose(p,form.template_picker,child_id);action(p,'placement_confirm')
    assert(p.surface.find_entity('steel-chest',{4.5,4.5}),'Preset must place committed nested contents')
    source(p,origin_id)
    p.surface.find_entity('steel-chest',{origin_center.x+3.5,origin_center.y+3.5}).destroy()
    p.surface.create_entity{name='iron-chest',position={origin_center.x+3.5,origin_center.y+3.5},force=p.force}
    commit(p)
    assert(game.surfaces['Fabric World'].find_entity('iron-chest',{4.5,4.5}),'UI commit propagates to World')
    action(p,'edit_exit');assert(not p.gui.screen.fabric_ui_overrides,'One close only')
    action(p,'metadata_open');local form=p.gui.screen.fabric_ui_metadata;form.template_name.text='QA Renamed Origin'
    action(p,'category_new');p.gui.screen.fabric_ui_category.category_name.text='QA Category';action(p,'category_create');action(p,'metadata_save')
    assert(inspect(p).catalog[origin_id].category=='QA Category')
    p.surface.create_entity{name='small-lamp',position={origin_center.x+10.5,origin_center.y+10.5},force=p.force}
    action(p,'template_changes');action(p,'edit_discard')
    assert(not p.surface.find_entity('small-lamp',{origin_center.x+10.5,origin_center.y+10.5}))
    storage.origin_id=origin_id;storage.child_id=child_id
    storage.saved_tick=e.tick
    log('UI_CREATE_PLACE_COMMIT_DISCARD_PASS');step=3
  elseif step==3 and e.tick>storage.saved_tick+20 then
    action(p,'world');p.teleport({0,0},game.surfaces['Fabric World']);action(p,'edit_current')
    local remove
    for _,el in ipairs(p.gui.screen.children) do
      if el.tags.fabric_ui_row and el.contents then
        if el.contents.item_name.caption=='The Grid' then assert(not el.contents.remove.visible,'Origin row is non-removable')
        elseif el.contents.remove.visible then remove=el.contents.remove end
      end
    end
    assert(remove);local count=inspect(p).cells[1].refs
    remote.call('fabric-ui-test','click',p.index,remove)
    assert(p.gui.screen.fabric_remove_confirm and inspect(p).cells[1].refs==count,'Remove first asks for confirmation')
    action(p,'remove_cancel');assert(inspect(p).cells[1].refs==count)
    remote.call('fabric-ui-test','click',p.index,remove);action(p,'remove_confirm')
    assert(inspect(p).cells[1].refs==count-1,'Confirmed removal changes references')
    log('PICKER_PREVIEW_CONFIRMATION_PASS')
    local dragged
    for _,el in ipairs(p.gui.screen.children) do if el.tags.fabric_ui_row and el.contents.remove.visible then dragged=el end end
    assert(dragged)
    local before=inspect(p).cells[1].first_ref_id
    storage.dragged_id=dragged.tags.id;storage.drag_tick=e.tick
    local root=p.gui.screen.fabric_ui_playground
    dragged.location={x=root.location.x+12*p.display_scale,y=root.location.y+80*p.display_scale}
    remote.call('fabric-ui-test','move',p.index,dragged)
    assert(inspect(p).cells[1].first_ref_id==before,'Dragging must not rebuild or mutate the applied order')
    step=4
  elseif step==4 and e.tick>storage.drag_tick+50 then
    action(p,'apply_order')
    assert(inspect(p).cells[1].first_ref_id==storage.dragged_id,'Apply order persists the displayed ordering')
    log('DEFERRED_REORDER_PASS')
    action(p,'toggle_neighbors')
    local individual=0;for _,el in ipairs(p.gui.screen.children) do if el.tags.fabric_ui_row and el.contents.item_name.caption:find('Neighbor ·',1,true) then individual=individual+1 end end
    assert(individual>0,'Neighbors expand individually')
    action(p,'toggle_neighbors')
    local combined=0;for _,el in ipairs(p.gui.screen.children) do if el.tags.fabric_ui_row and el.tags.id<0 then combined=combined+1 end end
    assert(combined==1,'Neighbors combine as one row')
    action(p,'toggle_neighbors')
    assert(not remote.call('fabric-ui-test','busy') and not inspect(p).cells[1].neighbors_expanded,'Grouping is staged until Apply')
    assert(p.gui.screen.fabric_ui_playground_footer.apply_order.visible)
    action(p,'close');action(p,'edit_current')
    assert(not p.gui.screen.fabric_ui_playground_footer.apply_order.visible,'Closing cancels unapplied grouping')
    action(p,'toggle_neighbors');action(p,'apply_order')
    assert(inspect(p).cells[1].neighbors_expanded,'Apply saves expanded grouping')
    action(p,'toggle_neighbors');action(p,'apply_order')
    assert(not inspect(p).cells[1].neighbors_expanded)
    local first=inspect(p).cells[1].first_ref_id
    local row=find(p.gui.screen,function(el)return el.tags.fabric_ui_row and el.contents.remove.visible end)
    row.location={x=p.gui.screen.fabric_ui_playground.location.x,y=p.gui.screen.fabric_ui_playground.location.y+400*p.display_scale}
    remote.call('fabric-ui-test','move',p.index,row)
    action(p,'close');action(p,'edit_current')
    assert(inspect(p).cells[1].first_ref_id==first and not p.gui.screen.fabric_ui_playground_footer.apply_order.visible,'Reopening discards unapplied dragging')
    for _,pair in ipairs({{'metadata_open','metadata_close'},{'add','placement_close'},{'fabric_settings','settings_close'}}) do
      action(p,pair[1]);action(p,pair[2])
      assert(p.gui.screen.fabric_ui_playground and p.gui.screen.fabric_ui_playground_footer,'Menu roundtrip retains the editor and controls')
    end
    log('MENU_ROUNDTRIPS_PENDING_GROUP_ORDER_PASS')
    action(p,'add');choose(p,p.gui.screen.fabric_ui_add_template.template_picker,child_id);action(p,'placement_confirm')
    source(p,child_id);action(p,'add')
    local form=p.gui.screen.fabric_ui_add_template
    choose(p,form.template_picker,origin_id);form.preview_only.state=true
    action(p,'placement_confirm');commit(p)
    assert(inspect(p).catalog[child_id].preview_refs==1,'Preview-only references persist')
    assert(not p.surface.find_entity('iron-chest',{child_center.x+3.5,child_center.y+3.5}),'Preview-only never builds real contents')
    local preview_row=find(p.gui.screen,function(el)return el.tags.fabric_ui_row and el.contents.item_name.caption:find('(Preview)',1,true) end)
    assert(preview_row)
    remote.call('fabric-ui-test','click',p.index,preview_row.contents.item_name)
    assert(p.gui.screen.fabric_ui_overrides and inspect(p).preview_count>0,'Clicking a preview reference focuses its geometry and shows ghosts in the template editor')
    remote.call('fabric-ui-test','hover',p.index,preview_row.contents.item_name)
    remote.call('fabric-ui-test','leave',p.index,preview_row.contents.item_name)
    assert(inspect(p).preview_count>0,'Leaving a reference hover restores the collection preview without a World cell')
    action(p,'overrides_close')
    log('PREVIEW_REFERENCE_CLICK_HOVER_LEAVE_PASS')
    source(p,origin_id);action(p,'show_usages')
    local usages=inspect(p).usages;local nested=false;local child_uses=0
    for _,entry in ipairs(usages) do if entry.cell and #entry.via>0 then nested=true end;if entry.template==child_id then child_uses=child_uses+1 end end
    assert(nested and child_uses==1,'Usages include nested world placements and exclude preview-only refs')
    action(p,'usages_close')
    action(p,'template_changes')
    p.cursor_stack.set_stack{name='small-lamp',count=1}
    p.build_from_cursor{position={origin_center.x+12.5,origin_center.y+12.5}}
    p.clear_cursor()
    storage.live_tick=e.tick;step=5
  elseif step==5 and e.tick>storage.live_tick+2 then
    assert(inspect(p).review_count==1,'Open diff updates on the next tick after building')
    assert(inspect(p).highlight_count>0,'All changes highlighted without hover')
    local row=find(p.gui.screen.fabric_ui_overrides,function(el)return el.tags.override_change end)
    remote.call('fabric-ui-test','hover',p.index,row)
    assert(inspect(p).highlight_count>0,'Diff hover creates visible top-layer highlight')
    remote.call('fabric-ui-test','leave',p.index,row)
    assert(inspect(p).highlight_count>0,'Leaving diff restores all changes')
    local button=find(p.gui.screen.fabric_ui_overrides,function(el)return el.tags.action=='edit_commit' end)
    remote.call('fabric-ui-test','click',p.index,button)
    assert(remote.call('fabric-ui-test','busy'),'Commit queues work immediately')
    assert(p.gui.screen.fabric_loading,'Progress is visible before work begins')
    storage.async_tick=e.tick;step=6
  elseif step==6 and remote.call('fabric-ui-test','busy') and e.tick>storage.async_tick+20 and not storage.resume_job then
    storage.resume_job=true;game.reload_mods();return
  elseif step==6 and not remote.call('fabric-ui-test','busy') then
    assert(e.tick>storage.async_tick+3,'Rebuild spreads across actual game ticks')
    assert(inspect(p).catalog[origin_id].entities==2,'Async commit completed')
    storage.idle_captures=inspect(p).catalog[origin_id].captures;storage.idle_tick=e.tick;step=7
  elseif step==7 and e.tick>storage.idle_tick+250 then
    assert(inspect(p).catalog[origin_id].captures==storage.idle_captures,'Idle editor does not periodically capture the padded island')
    log('RESPONSIVE_PREVIEW_USAGES_LIVE_DIFF_ASYNC_PASS')
    local parent=test_slots(p)
    source(p,parent);action(p,'slot_open')
    local option=find(p.gui.screen.fabric_template_picker,function(el)return el.tags.preview_slot==origin_id end)
    assert(option);remote.call('fabric-ui-test','hover',p.index,option)
    storage.preview_element=option;storage.preview_tick=e.tick;step=8
  elseif step==8 and e.tick>storage.preview_tick+25 then
    assert(inspect(p).preview_count>0,'Slot choice hover shows anchored ghosts')
    remote.call('fabric-ui-test','leave',p.index,storage.preview_element)
    assert(inspect(p).preview_count==0,'Slot hover ghosts clear on leave')
    action(p,'placement_picker');action(p,'world');p.teleport({3200,0},game.surfaces['Fabric World']);action(p,'edit_current')
    local button=find(p.gui.screen,function(el)return el.tags.action=='create_instance' end)
    remote.call('fabric-ui-test','hover',p.index,button);storage.preview_element=button;storage.preview_tick=e.tick;step=9
  elseif step==9 and e.tick>storage.preview_tick+25 then
    assert(inspect(p).preview_count>0,'Create instance hover previews the Grid')
    remote.call('fabric-ui-test','leave',p.index,storage.preview_element)
    assert(inspect(p).preview_count==0,'Instance preview clears on leave')
    log('SLOT_AND_INSTANCE_HOVER_PASS')
    p.teleport({1600,0},game.surfaces['Fabric World']);action(p,'edit_current')
    local before=inspect(p).cells[5].refs
    action(p,'add')
    local draft=find(p.gui.screen,function(el)return el.tags.fabric_ui_row and el.tags.id==-1000000 end)
    assert(draft and draft.contents.item_name.caption:find('New template',1,true),'Add immediately shows a placeholder row')
    choose(p,p.gui.screen.fabric_ui_add_template.template_picker,origin_id)
    draft=find(p.gui.screen,function(el)return el.tags.fabric_ui_row and el.tags.id==-1000000 end)
    assert(draft.contents.item_name.caption:find('Draft',1,true),'Selected row remains visibly a draft')
    assert(inspect(p).cells[5].refs==before and not remote.call('fabric-ui-test','busy'),'Selecting a draft does not build')
    storage.untouched=p.surface.find_entity('steel-chest',{1603.5,3.5});assert(storage.untouched)
    local root=p.gui.screen.fabric_ui_playground
    draft.location={x=root.location.x+12*p.display_scale,y=root.location.y+80*p.display_scale}
    remote.call('fabric-ui-test','move',p.index,draft);storage.preview_tick=e.tick;step=10
  elseif step==10 and e.tick>storage.preview_tick+50 then
    assert(storage.untouched.valid and not remote.call('fabric-ui-test','busy'),'Dragging the draft never rebuilds')
    assert(inspect(p).highlight_count>0,'Later rows mark conflicting draft entities in red')
    action(p,'placement_confirm')
    assert(inspect(p).cells[5].items[1].template_id==origin_id,'Add uses the chosen draft position')
    assert(not find(p.gui.screen,function(el)return el.tags.fabric_ui_row and el.tags.id==-1000000 end),'Applied placeholder becomes a real row')
    assert(p.surface.find_entity('steel-chest',{1603.5,3.5}),'Later template still wins after adding at the top')
    log('DRAFT_PLACEMENT_PRIORITY_PREVIEW_PASS')
    action(p,'slot_open')
    local option=find(p.gui.screen.fabric_template_picker,function(el)return el.tags.preview_slot==origin_id end)
    remote.call('fabric-ui-test','click',p.index,option)
    storage.draft_ghost_count=inspect(p).preview_count;assert(storage.draft_ghost_count>0)
    local second=find(p.gui.screen,function(el)return el.tags.action=='slot_open' and el.tags.slot==2 end)
    remote.call('fabric-ui-test','hover',p.index,second)
    assert(inspect(p).preview_count==storage.draft_ghost_count,'Hovering another slot retains all pending ghosts')
    remote.call('fabric-ui-test','click',p.index,second)
    option=find(p.gui.screen.fabric_template_picker,function(el)return el.tags.preview_slot==origin_id end)
    remote.call('fabric-ui-test','hover',p.index,option);storage.preview_element=option;storage.preview_tick=e.tick;step=11
  elseif step==11 and e.tick>storage.preview_tick+25 then
    assert(inspect(p).preview_count>storage.draft_ghost_count,'Choice hover adds to the other pending slot previews')
    remote.call('fabric-ui-test','leave',p.index,storage.preview_element)
    assert(inspect(p).preview_count==storage.draft_ghost_count,'Leaving restores the persistent draft ghosts')
    log('PERSISTENT_MULTI_SLOT_HOVER_PASS')
    log('UI_INTEGRATION_PASS');script.finish_test(true);step=100
  end
end)
