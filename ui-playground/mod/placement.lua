local runtime=require("__fabric-ui-playground__/runtime")
local snapshots=require("__fabric-ui-playground__/snapshots")
local world_areas=require("__fabric-ui-playground__/world_areas")
-- Shared add/reference dialog using native blueprint placement.
local components=require("__fabric-ui-playground__/components")
local workspaces=require("__fabric-ui-playground__/workspaces")
local ghosts=require('__fabric-ui-playground__/ghosts')
local world=require('__fabric-ui-playground__/world')
local M={name="fabric_ui_add_template",tool="blueprint",draft_id=-1000000}
function M.close(player,state)
  if storage.fabric_job and not storage.fabric_job.finishing then storage.fabric_job.close_panels[M.name]=true;return end
  local panel=player.gui.screen[M.name]
  if panel then panel.destroy() end
  local picker=player.gui.screen.fabric_template_picker;if picker then picker.destroy() end
  local positions=player.gui.screen.fabric_position_picker;if positions then positions.destroy() end
  world.clear(state)
  state.placement=nil;state.preview_pending=nil;state.drag=nil
end
function M.refresh(player,state)
  local panel=player.gui.screen[M.name]
  local draft=state.placement
  if not panel or not draft then return end
  local template=draft.catalog[panel.template_picker.selected_index]
  draft.template=template
  draft.row={id=M.draft_id,name=template and template.name or "New template",icon=template and template.icon or "item/blueprint",placement_draft=true}
  panel.confirm.enabled=template~=nil
  panel.position_button.enabled=template~=nil
  if not template then panel.template_button.caption='Click to select';panel.hint.caption='';return end
  if panel.template_button then panel.template_button.caption="[img="..template.icon.."]  "..template.name end
  template.position_presets={{name="Cell origin",x=0,y=0}}
  local choices={}
  for _,preset in ipairs(template.position_presets) do choices[#choices+1]=preset.name end
  choices[#choices+1]="Custom"
  local selected=panel.position_picker.selected_index
  panel.position_picker.items=choices
  panel.position_picker.selected_index=math.max(1,math.min(selected,#choices))
  panel.position_button.caption=choices[panel.position_picker.selected_index]
  local custom=panel.position_picker.selected_index==#choices
  panel.hint.caption=custom and "Choose a point in the world with the placement cursor."
    or ""
  panel.confirm.caption=custom and "Place freely" or (state.workspace=="collection" and "Reference Template" or "Add Template")
  M.preview(player,state,template.id,panel.position_picker.selected_index)
end
function M.show(player,state)
  M.close(player,state)
  state.placement={catalog=workspaces.catalog(player,state),items=state.items,
    surface=player.surface,preview_enabled=true,parent=state.parent_template,cell=state.camera_area,row={id=M.draft_id,name="New template",icon="item/blueprint",placement_draft=true}}
  local panel=player.gui.screen.add{type="frame",name=M.name,direction="vertical"}
  panel.style.width=380
  components.titlebar(panel,{title=state.workspace=="collection" and "Reference a Template" or "Add a Template",
    close_tags={action="placement_close"},icon_actions={{name="preview",sprite="fabric-ui-eye",tags={action="placement_toggle_preview"},tooltip="Toggle placement preview"}}})
  panel.add{type="label",caption="Template",style="caption_label"}
  local names={}
  for _,template in ipairs(state.placement.catalog) do names[#names+1]=template.name end
  panel.add{type="drop-down",name="template_picker",items=names,selected_index=0,tags={action="placement_template"}}.style.width=348
  panel.template_picker.visible=false
  panel.add{type='button',name='template_button',caption='Select Template',tags={action='placement_picker'}}.style.width=348
  panel.add{type="label",caption="Position",style="caption_label"}.style.top_margin=12
  panel.add{type="drop-down",name="position_picker",items={"Center"},selected_index=1,tags={action="placement_position"}}.style.width=348
  panel.position_picker.visible=false
  panel.add{type='button',name='position_button',caption='Cell origin',tags={action='placement_positions'}}.style.width=348
  if state.parent_template then panel.add{type='checkbox',name='preview_only',caption='Only as Preview',state=false,tags={action='placement_preview_only'},tooltip='Show an underlay in this editor; do not build it as part of this template.'} end
  local hint=panel.add{type="label",name="hint",caption=""}
  hint.style.single_line=false; hint.style.maximal_width=348
  local button=panel.add{type="button",name="confirm",caption="Add Template",tags={action="placement_confirm"}}
  button.style.width=348; button.style.height=36; button.style.top_margin=12
  M.refresh(player,state)
  panel.auto_center=true
end
function M.fill_picker(player,state)
  local panel=player.gui.screen.fabric_template_picker;if not panel or not (state.slot_picker or state.placement) then return end
  local list=panel.results;list.clear()
  local query=panel.search.text:lower()
  local candidates={};local categories={}
  for i,t in ipairs((state.slot_picker or state.placement).catalog) do
    if query=='' or t.name:lower():find(query,1,true) or (t.category or 'Other'):lower():find(query,1,true) then
      candidates[#candidates+1]={template=t,index=i};categories[t.category or 'Other']=true
    end
  end
  local counts=runtime.usage_counts()
  local common={};for _,entry in ipairs(candidates) do if (counts[entry.template.id] or 0)>0 then common[#common+1]=entry end end
  table.sort(common,function(a,b)
    local x,y=counts[a.template.id] or 0,counts[b.template.id] or 0
    if x~=y then return x>y end;return a.template.name:lower()<b.template.name:lower()
  end)
  local function heading(name) list.add{type='label',caption=name,style='caption_label'}.style.top_margin=12 end
  local function button(entry)
    local t=entry.template
    local button=list.add{type='button',caption='[img='..t.icon..']  '..t.name,raise_hover_events=true,tags=state.slot_picker and {action='slot_assign',id=state.slot_picker.id,slot=state.slot_picker.slot,value=t.id,preview_slot=t.id} or {action='placement_pick',index=entry.index,preview_template=t.id}}
    button.style.width=306;button.style.horizontal_align='left'
  end
  if #common>0 then heading('Most common');for i=1,math.min(5,#common) do button(common[i]) end end
  local sorted={};for name in pairs(categories) do sorted[#sorted+1]=name end;table.sort(sorted)
  for _,category in ipairs(sorted) do
    heading(category)
    for _,entry in ipairs(candidates) do if (entry.template.category or 'Other')==category then button(entry) end end
  end
  if #candidates==0 then list.add{type='label',caption='No matching templates'} end
end
function M.picker(player,state,slot)
  local old=player.gui.screen.fabric_template_picker;if old then old.destroy();if not slot then state.slot_picker=nil;world.clear(state);return end end
  state.slot_picker=slot
  local panel=player.gui.screen.add{type='frame',name='fabric_template_picker',direction='vertical'};panel.style.width=360
  components.titlebar(panel,{title='Select Template',close_tags={action='placement_picker'}})
  panel.add{type='label',caption='Hover for preview'}
  panel.add{type='label',caption='Search',style='caption_label'}
  panel.add{type='textfield',name='search',text='',tags={action='placement_search'},tooltip='Search templates or categories'}.style.width=328
  local list=panel.add{type='scroll-pane',name='results',direction='vertical',horizontal_scroll_policy='never',vertical_scroll_policy='auto'}
  list.style.width=328;list.style.maximal_height=440
  M.fill_picker(player,state);panel.auto_center=true;panel.search.focus()
end
function M.pick(player,state,index)
  world.clear(state)
  local picker=player.gui.screen.fabric_template_picker;if picker then picker.destroy() end
  player.gui.screen[M.name].template_picker.selected_index=index;player.gui.screen[M.name].position_picker.selected_index=1;M.refresh(player,state)
end
function M.preview(player,state,id,preset_index)
  world.clear(state)
  local draft=state.placement;if not draft or not draft.preview_enabled then return end
  local target=draft.parent and draft.parent.area or draft.cell
  local template=runtime.template(id)
  local preset=preset_index and (template.position_presets or {})[preset_index]
  if preset_index and not preset then return end
  if target then
    local center={x=target.center.x+(preset and preset.x or 0),y=target.center.y+(preset and preset.y or 0)}
    local snapshot=runtime.flatten(id)
    state.preview_ghosts=ghosts.show(player.surface,snapshot,center)
    if draft.template and draft.template.id==id then M.conflicts(player,state,snapshot,center) end
  end
end
-- Geometric conflict feedback only; previews never alter the World surface.
function M.conflicts(player,state,snapshot,center)
  local draft=state.placement;local later={};local after=false
  for _,ref in ipairs(draft.order or {}) do
    if ref.placement_draft then after=true
    elseif after then
      local data
      if state.camera_area then data=runtime.reference_snapshot(state.camera_area,ref)
      elseif ref.template_id then data=snapshots.transform(runtime.flatten(ref.template_id,ref.slot_assignments),ref) end
      if data then for _,entity in ipairs(data.entities or {}) do later[#later+1]=entity end end
    end
  end
  local function bounds(entity)
    local proto=prototypes.entity[entity.name];local b=proto.collision_box
    local lt={x=math.huge,y=math.huge};local rb={x=-math.huge,y=-math.huge}
    for _,point in ipairs({b.left_top,{x=b.left_top.x,y=b.right_bottom.y},b.right_bottom,{x=b.right_bottom.x,y=b.left_top.y}}) do
      local q=snapshots.point(point,{direction=entity.direction or 0});q.x=q.x+entity.position.x;q.y=q.y+entity.position.y
      lt.x=math.min(lt.x,q.x);lt.y=math.min(lt.y,q.y);rb.x=math.max(rb.x,q.x);rb.y=math.max(rb.y,q.y)
    end
    return {left_top=lt,right_bottom=rb}
  end
  state.highlight_objects={}
  for _,entity in ipairs(snapshot.entities or {}) do
    local b=bounds(entity);local blocked=false
    for _,other in ipairs(later) do
      if snapshots.intersects(b,bounds(other)) then
        local a=prototypes.entity[entity.name].collision_mask.layers;local c=prototypes.entity[other.name].collision_mask.layers
        for layer in pairs(a) do if c[layer] then blocked=true;break end end
      end
      if blocked then break end
    end
    if blocked then state.highlight_objects[#state.highlight_objects+1]=rendering.draw_rectangle{surface=player.surface,
      left_top={x=center.x+b.left_top.x,y=center.y+b.left_top.y},right_bottom={x=center.x+b.right_bottom.x,y=center.y+b.right_bottom.y},
      color={1,.15,.1},width=3,draw_on_ground=false,players={player.index}} end
  end
end
function M.restore_preview(player,state)
  local draft=state.placement;local panel=player.gui.screen[M.name]
  if draft and draft.template and panel then M.preview(player,state,draft.template.id,panel.position_picker.selected_index) end
end
function M.positions(player,state)
  local old=player.gui.screen.fabric_position_picker;if old then old.destroy();M.restore_preview(player,state);return end
  local draft=state.placement;if not draft or not draft.template then return end
  local panel=player.gui.screen.add{type='frame',name='fabric_position_picker',direction='vertical'}
  components.titlebar(panel,{title='Position',close_tags={action='placement_positions'}})
  for i,preset in ipairs(draft.template.position_presets) do
    panel.add{type='button',caption=preset.name,raise_hover_events=true,tags={action='placement_position_pick',index=i,preview_template=draft.template.id,preview_position=i}}.style.width=300
  end
  panel.add{type='button',caption='Custom',tags={action='placement_position_pick',index=#draft.template.position_presets+1}}.style.width=300
  panel.auto_center=true
end
function M.position_pick(player,state,index)
  player.gui.screen[M.name].position_picker.selected_index=index
  local popup=player.gui.screen.fabric_position_picker;if popup then popup.destroy() end
  M.refresh(player,state)
end
function M.finish(player,state,position)
  local draft=state.placement
  if not draft or draft.items~=state.items or draft.surface~=player.surface or draft.parent~=state.parent_template then
    M.close(player,state); return false
  end
  state.pending_order=nil;state.drag=nil
  runtime.add_reference(player,state,draft.template.id,position,draft.build)
  workspaces.select_camera(player,state)
  M.close(player,state)
  return true
end
function M.confirm(player,state)
  local panel=player.gui.screen[M.name]
  if not panel or not state.placement then return false end
  M.refresh(player,state)
  local draft=state.placement
  if not draft.template then return false end
  draft.preview_only=panel.preview_only and panel.preview_only.state or false
  local index=panel.position_picker.selected_index
  if index>#draft.template.position_presets then
    if not player.clear_cursor() then return false end
    local stack=player.cursor_stack
    stack.set_stack{name="blueprint",count=1}
    local snapshot=runtime.flatten(draft.template.id)
    snapshot['snap-to-grid']={x=2,y=2};snapshot['absolute-snapping']=true
    snapshot['position-relative-to-grid']={x=0,y=0}
    if #(snapshot.entities or {})>0 or #(snapshot.tiles or {})>0 then stack.import_stack(snapshots.encode(snapshot)) end
    if not stack.is_blueprint_setup() then
      stack.clear()
      panel.hint.caption="This template has no buildings to place yet."
      return false
    end
    stack.label=draft.template.name
    draft.free=true
    panel.visible=false
    player.print("Click to place the template. Rotate and flip like a blueprint; Q cancels.")
    return false
  end
  local preset=draft.template.position_presets[index]
  local target=state.workspace=="collection" and state.parent_template.area or state.camera_area
  return M.finish(player,state,{x=target.center.x+preset.x,y=target.center.y+preset.y})
end
return M
