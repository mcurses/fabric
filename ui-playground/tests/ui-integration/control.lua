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
    if el then remote.call('fabric-ui-test','click',p.index,el);return end
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
local reloaded=false
script.on_load(function() reloaded=true end)
script.on_event(defines.events.on_tick,function(e)
  local p=game.get_player(1);if not p then return end
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
    log('UI_INTEGRATION_PASS');script.finish_test(true);step=100
  end
end)
