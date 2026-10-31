local runtime=require("__fabric-ui-playground__/runtime")
local snapshots=require("__fabric-ui-playground__/snapshots")
local world_areas=require("__fabric-ui-playground__/world_areas")
-- Shared add/reference dialog using native blueprint placement.
local components=require("__fabric-ui-playground__/components")
local workspaces=require("__fabric-ui-playground__/workspaces")
local M={name="fabric_ui_add_template",tool="blueprint"}
function M.close(player,state)
  local panel=player.gui.screen[M.name]
  if panel then panel.destroy() end
  state.placement=nil
end
function M.refresh(player,state)
  local panel=player.gui.screen[M.name]
  local draft=state.placement
  if not panel or not draft then return end
  local template=draft.catalog[panel.template_picker.selected_index]
  draft.template=template
  template.position_presets={{name="Cell origin",x=0,y=0}}
  for _,slot in ipairs(template.slots or {}) do
    template.position_presets[#template.position_presets+1]={name=slot.name,x=slot.dx,y=slot.dy}
  end
  local choices={}
  for _,preset in ipairs(template.position_presets) do choices[#choices+1]=preset.name end
  choices[#choices+1]="Custom"
  local selected=panel.position_picker.selected_index
  panel.position_picker.items=choices
  panel.position_picker.selected_index=math.max(1,math.min(selected,#choices))
  local custom=panel.position_picker.selected_index==#choices
  panel.hint.caption=custom and "Choose a point in the world with the placement cursor."
    or "Use this template's saved position preset."
  panel.confirm.caption=custom and "Place freely" or (state.workspace=="collection" and "Reference Template" or "Add Template")
end
function M.show(player,state)
  M.close(player,state)
  state.placement={catalog=workspaces.catalog(player,state),items=state.items,
    surface=player.surface,parent=state.parent_template,cell=state.camera_area}
  local panel=player.gui.screen.add{type="frame",name=M.name,direction="vertical"}
  panel.style.width=380
  components.titlebar(panel,{title=state.workspace=="collection" and "Reference a Template" or "Add a Template",
    close_tags={action="placement_close"}})
  panel.add{type="label",caption="Template",style="caption_label"}
  local names={}
  for _,template in ipairs(state.placement.catalog) do names[#names+1]=template.name end
  panel.add{type="drop-down",name="template_picker",items=names,selected_index=1,tags={action="placement_template"}}.style.width=348
  panel.add{type="label",caption="Position",style="caption_label"}.style.top_margin=12
  panel.add{type="drop-down",name="position_picker",items={"Center"},selected_index=1,tags={action="placement_position"}}.style.width=348
  local hint=panel.add{type="label",name="hint",caption=""}
  hint.style.single_line=false; hint.style.maximal_width=348
  local button=panel.add{type="button",name="confirm",caption="Add Template",tags={action="placement_confirm"}}
  button.style.width=348; button.style.height=36; button.style.top_margin=12
  M.refresh(player,state)
  panel.auto_center=true
end
function M.finish(player,state,position)
  local draft=state.placement
  if not draft or draft.items~=state.items or draft.surface~=player.surface or draft.parent~=state.parent_template then
    M.close(player,state); return false
  end
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
