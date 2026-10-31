local world_areas=require("__fabric-ui-playground__/world_areas")
-- Shared add/reference dialog. Placement is a UI fixture, not Fabric mechanics.
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
  -- Sample anchors supplied by each template, ready for a real definition later.
  template.position_presets=template.position_presets or {
    {name="Center",x=0,y=0},{name="Input side",x=-6,y=0},{name="Output side",x=6,y=0},
  }
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
    surface=player.surface,parent=state.parent_template}
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
  local item={id=state.next_id,name=draft.template.name,icon=draft.template.icon,
    template_id=draft.template.id,position=position,overrides={},override_fixture_v2=true}
  local area=world_areas.at(state.world_demo,position)
  item.world_area=area and area.id or nil
  state.next_id=state.next_id+1
  state.items[#state.items+1]=item
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
    local demo=state.contexts.collection.world_demo
    for _,area in ipairs(demo.areas) do
      if area.template.id==draft.template.id then
        stack.create_blueprint{surface=demo.surface,force=player.force,
          area={area.left_top,area.right_bottom},always_include_tiles=false}
        break
      end
    end
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
  return M.finish(player,state,{x=player.position.x+preset.x,y=player.position.y+preset.y})
end
return M
