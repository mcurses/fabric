local world_areas=require("__fabric-ui-playground__/world_areas")
local navigation=require("__fabric-ui-playground__/navigation")
local components=require("__fabric-ui-playground__/components")
local overrides=require("__fabric-ui-playground__/overrides")
local highlight_styles=require("__fabric-ui-playground__/world").styles
local M = {root="fabric_ui_playground", revision="34"}
local ROW_HEIGHT, ROW_STEP, LIST_TOP = 36, 40, 52
local function visible_items(state)
  if state.workspace=="world" and state.world_camera_mode then
    return world_areas.items(state)
  end
  return state.items
end
local function list_top(state) return LIST_TOP+((state.workspace=="collection" or state.world_camera_mode) and 28 or 0)+(state.parent_template and 92 or 0) end
local WINDOW_WIDTH, ROW_WIDTH, NAME_WIDTH = 420, 396, 272
local icons = {
  ["Iron Plate Pickup"]="item/iron-plate",
  ["Copper Plate Pickup"]="item/copper-plate",
  ["Steel Dropoff"]="item/steel-plate",
}

local function row_name(id) return M.root.."_row_"..id end

function M.close(player)
  components.sample_action(player,nil)
  -- Clean up controls from the discarded scrolling experiment on reload.
  for _, suffix in ipairs({"_scroll","_thumb"}) do
    local old=player.gui.screen[M.root..suffix]
    if old then old.destroy() end
  end
  for _, element in pairs(player.gui.screen.children) do
    if element.name == M.root or element.name == overrides.panel_name or element.name == M.root.."_tuning" or element.name == M.root.."_footer" or element.name == M.root.."_review" or element.tags.fabric_ui_row then element.destroy() end
  end
end

-- Restore the composite window's stacking without moving or rebuilding rows.
function M.raise_rows(player,state)
  for _, item in ipairs(visible_items(state)) do
    local row=player.gui.screen[row_name(item.id)]
    if row then row.bring_to_front() end
  end
  if state.drag then
    local active=player.gui.screen[row_name(state.drag.id)]
    if active then active.bring_to_front() end
  end
  local footer=player.gui.screen[M.root.."_footer"]
  if footer then footer.bring_to_front() end
  local review=player.gui.screen[M.root.."_review"]
  if review then review.bring_to_front() end
  local panel=player.gui.screen[M.root.."_tuning"]
  if panel then panel.bring_to_front() end
  local detail=player.gui.screen[overrides.panel_name]
  if detail then detail.bring_to_front() end
end

function M.layout(player, state, moving_id, raise_rows)
  local root=player.gui.screen[M.root]
  if not root then return end
  local scale=player.display_scale
  local origin=root.location
  for i, item in ipairs(visible_items(state)) do
    local row=player.gui.screen[row_name(item.id)]
    if row then
      if item.id ~= moving_id then
        local x=math.floor(origin.x+12*scale)
        local y=math.floor(origin.y+(list_top(state)+(i-1)*ROW_STEP)*scale)
        if row.location.x ~= x or row.location.y ~= y then row.location={x=x,y=y} end
      end
    end
  end
  local footer=player.gui.screen[M.root.."_footer"]
  if footer then
    footer.location={x=math.floor(origin.x+12*scale),
      y=math.floor(origin.y+(list_top(state)+4+#visible_items(state)*ROW_STEP)*scale)}
  end
  local review=player.gui.screen[M.root.."_review"]
  if review then review.location={x=math.floor(origin.x+12*scale),y=math.floor(origin.y+72*scale)} end
  if raise_rows then M.raise_rows(player,state) end
end

function M.move(player, state, id, y)
  if state.workspace=="world" and state.world_camera_mode then return end
  local root=player.gui.screen[M.root]
  if not root then return end
  local destination=math.floor(((y-root.location.y)/player.display_scale-list_top(state))/ROW_STEP+0.5)+1
  destination=math.max(1,math.min(#visible_items(state),destination))
  for i, item in ipairs(visible_items(state)) do
    if item.id == id then
      if i ~= destination then
        table.remove(state.items,i)
        table.insert(state.items,destination,item)
      end
      break
    end
  end
  -- Never reposition the frame currently controlled by the mouse.
  M.layout(player,state,id)
end

local tuning_fields={
  {key="row_offset",label="Whole row ↑ / ↓",default=-5,min=-12,max=12},
  {key="icon_offset",label="Icon ↑ / ↓",default=1,min=-8,max=8},
  {key="text_offset",label="Text ↑ / ↓",default=0,min=-8,max=8},
  {key="control_offset",label="Grip and × ↑ / ↓",default=1,min=-8,max=8},
  {key="icon_size",label="Icon size",default=24,min=16,max=28},
}
local function tuning(state)
  state.tuning=state.tuning or {}
  for _, f in ipairs(tuning_fields) do
    if state.tuning[f.key]==nil then state.tuning[f.key]=f.default end
  end
  return state.tuning
end
local function offset(element,value)
  element.style.top_margin=value
  element.style.bottom_margin=-value
end
function M.apply_tuning(player,state)
  local t=tuning(state)
  for _, item in ipairs(visible_items(state)) do
    local row=player.gui.screen[row_name(item.id)]
    if row and row.contents then
      local c=row.contents
      offset(c,t.row_offset)
      offset(c.icon_slot,t.icon_offset)
      c.icon_slot.icon.style.size=t.icon_size
      offset(c.item_name,t.text_offset)
      offset(c.grip,t.control_offset)
      offset(c.remove,t.control_offset)
    end
  end
end
function M.show_tuning(player,state)
  local old=player.gui.screen[M.root.."_tuning"]
  if old then old.destroy(); return end
  local change_mode=state.tuning_target=="changes" or
    (not state.tuning_target and player.gui.screen[overrides.panel_name]~=nil)
  local header_mode=state.tuning_target=="header"
  state.tuning_target=header_mode and "header" or (change_mode and "changes" or "references")
  local fields=header_mode and navigation.tuning_fields or (change_mode and overrides.tuning_fields or tuning_fields)
  local t=header_mode and navigation.tuning(state) or (change_mode and overrides.tuning(state) or tuning(state))
  local panel=player.gui.screen.add{type="frame",name=M.root.."_tuning",direction="vertical"}
  components.titlebar(panel,{title="Live UI tuning",close_tags={action="tuning"}})
  panel.add{type="drop-down",name="tuning_target",items={"Reference rows","Change rows","Fabric title"},
    selected_index=header_mode and 3 or (change_mode and 2 or 1),tags={action="tuning_target"}}
  if not change_mode and not header_mode then
  panel.add{type="label",caption="World highlight"}
  panel.add{type="drop-down",name="highlight_style_picker",items=highlight_styles,
    selected_index=state.highlight_style or 5,tags={action="highlight_style"}}
  panel.add{type="label",caption="Choose a style, then hover a linked row."}
  panel.add{type="button",caption="Restore demo rows",tags={action="restore_world_rows"}}
  panel.add{type="line"}
  end
  panel.add{type="label",caption="Negative = up · changes apply immediately"}
  for _, f in ipairs(fields) do
    local line=panel.add{type="flow",direction="horizontal"}
    line.style.vertical_align="center"
    line.add{type="label",caption=f.label}.style.width=170
    local minus=line.add{type="button",caption="−",tags={action="tune",key=f.key,delta=-1}}
    minus.style.width=28; minus.style.padding=0
    line.add{type="label",name="tuning_value",caption=tostring(t[f.key])}.style.width=32
    local plus=line.add{type="button",caption="+",tags={action="tune",key=f.key,delta=1}}
    plus.style.width=28; plus.style.padding=0
  end
  panel.add{type="button",caption="Done",tags={action="tuning"}}
  local root=(header_mode and player.gui.screen.fabric_ui_controls) or player.gui.screen[overrides.panel_name] or player.gui.screen[M.root] or panel
  local scale=player.display_scale
  local x=root.location.x+(WINDOW_WIDTH+8)*scale
  if x+350*scale>player.display_resolution.width then x=root.location.x-350*scale end
  panel.location={x=math.max(0,x),y=math.max(0,math.min(root.location.y,player.display_resolution.height-540*scale))}
end
function M.select_tuning(player,state,index)
  local panel=player.gui.screen[M.root.."_tuning"]
  if panel then panel.destroy() end
  state.tuning_target=index==3 and "header" or (index==2 and "changes" or "references")
  M.show_tuning(player,state)
end
function M.adjust(player,state,element)
  local header_mode=state.tuning_target=="header"
  local change_mode=state.tuning_target=="changes"
  local t=header_mode and navigation.tuning(state) or (change_mode and overrides.tuning(state) or tuning(state))
  for _, f in ipairs(header_mode and navigation.tuning_fields or (change_mode and overrides.tuning_fields or tuning_fields)) do
    if f.key==element.tags.key then
      t[f.key]=math.max(f.min,math.min(f.max,t[f.key]+element.tags.delta))
      element.parent.tuning_value.caption=tostring(t[f.key])
      if header_mode then navigation.apply_tuning(player,state)
      elseif change_mode then overrides.apply_tuning(player,state) else M.apply_tuning(player,state) end
      return
    end
  end
end

local function create_row(player,item)
    local row=player.gui.screen.add{type="frame", name=row_name(item.id), direction="horizontal", style="train_schedule_station_frame",
      tags={fabric_ui_row=true, id=item.id}}
    row.style.width=ROW_WIDTH
    row.style.height=ROW_HEIGHT
    row.style.padding=4
    row.style.vertical_align="center"
    local contents=row.add{type="flow", name="contents", direction="horizontal"}
    contents.style.margin=0
    contents.style.padding=0
    contents.style.height=28
    contents.style.horizontal_spacing=4
    contents.style.vertical_align="center"
    local slot=contents.add{type="flow",name="icon_slot",direction="horizontal"}
    slot.style.size=28
    slot.style.vertical_align="center"
    slot.style.horizontal_align="center"
    local icon=slot.add{type="sprite", name="icon", sprite=item.icon or icons[item.name] or "item/blueprint"}
    icon.style.size=28
    icon.style.margin=0
    icon.style.stretch_image_to_widget_size=true
    local name=contents.add{type="label", name="item_name", caption=item.name, tooltip=item.name.." · Click to locate and inspect", style="bold_label"}
    name.style.margin=0
    name.style.height=28
    name.style.vertical_align="center"
    name.style.width=NAME_WIDTH
    name.style.single_line=true
    name.style.horizontally_stretchable=false
    name.style.horizontally_squashable=false
    local grip=contents.add{type="empty-widget", name="grip", style="draggable_space_in_train_schedule", tooltip="Drag to reorder"}
    grip.style.margin=0
    grip.style.width=60
    grip.style.height=28
    grip.drag_target=row
    local remove=contents.add{type="sprite-button", name="remove", sprite="utility/close", style="train_schedule_delete_button",
      tags={action="remove", id=item.id}, tooltip="Remove "..item.name}
    remove.style.margin=0
    remove.style.width=16
    remove.style.height=28
    local function enable_hover(element)
      element.raise_hover_events=true
      for _, child in pairs(element.children) do enable_hover(child) end
    end
    enable_hover(row)
end

function M.refresh_summary(player,state)
  local root=player.gui.screen[M.root]
  if root and state.parent_template and root.editing_subject then
    local count=overrides.pending_count(state.parent_template)
    local subject=state.parent_template.name.." ("..(state.parent_template.category or "Base Grid")..")"
    root.editing_subject.template_name.tooltip=subject
    root.editing_subject.template_name.caption=subject
    local review=player.gui.screen[M.root.."_review"]
    if review then review.review_changes.enabled=count>0 end
    root.editing_subject.pending_count.caption=(count>0 and "[color=1,0.72,0.3]•[/color]  " or "")..count.." pending "..(count==1 and "change" or "changes")
  end
end

function M.refresh_rows(player,state)
  local root=player.gui.screen[M.root]
  if not root then return end
  local wanted={}
  for _, item in ipairs(visible_items(state)) do
    wanted[item.id]=true
    if not player.gui.screen[row_name(item.id)] then create_row(player,item) end
    local count=overrides.count(item)
    local label=player.gui.screen[row_name(item.id)].contents.item_name
    label.caption=item.name..(count>0 and "  [color=1,0.72,0.3]•[/color]" or "")
    label.tooltip=item.name..(count>0 and (" · "..count.." patches") or " · No patches").."\nClick to locate and inspect"
  end
  for _, element in pairs(player.gui.screen.children) do
    if element.tags.fabric_ui_row and not wanted[element.tags.id] then element.destroy() end
  end
  if state.override_selected and not wanted[state.override_selected] and not state.reviewing_parent then overrides.close(player,state) end
  root.style.height=(list_top(state)+52)+#visible_items(state)*ROW_STEP
  root.list_space.style.height=#visible_items(state)*ROW_STEP+8
  M.refresh_summary(player,state)
  M.apply_tuning(player,state)
  M.layout(player,state,nil,true)
end

function M.build(player, state)
  state.drag=nil
  local old=player.gui.screen[M.root]
  if old then state.location=old.location end
  M.close(player)
  local root=player.gui.screen.add{type="frame", name=M.root, direction="vertical", raise_hover_events=true}
  root.style.width=WINDOW_WIDTH
  root.style.padding=12
  local window_height=(list_top(state)+52)+#visible_items(state)*ROW_STEP
  root.style.height=window_height
  components.titlebar(root,{title=state.workspace=="collection" and "Edit Template" or "Edit Instance",close_tags={action="close"}})
  components.meta_bar(player)
  navigation.show(player,state)
  if state.workspace=="world" and state.world_camera_mode then
    local subject=root.add{type="flow",direction="horizontal"}
    subject.style.height=24; subject.style.vertical_align="center"
    subject.add{type="label",caption=state.camera_area and state.camera_area.name or "Outside instance areas",
      style="bold_label"}
    if state.camera_area then
      subject.add{type="sprite-button",sprite="utility/rename_icon",
        style="mini_button_aligned_to_text_vertically_when_centered",
        tags={action="metadata_open"},tooltip="Edit instance name"}
    end
  end
  if state.workspace=="collection" then
    local subject=root.add{type="flow",name="editing_subject",direction="horizontal"}
    subject.style.height=24
    subject.style.vertical_align="center"
    local name=subject.add{type="label",name="template_name",
      caption=state.parent_template and state.parent_template.name or "Outside template areas",
      style="bold_label"}
    name.style.maximal_width=202
    name.tooltip=state.parent_template and state.parent_template.name or nil
    if state.parent_template then
      subject.add{type="sprite-button",name="edit_metadata",sprite="utility/rename_icon",
        style="mini_button_aligned_to_text_vertically_when_centered",
        tags={action="metadata_open"},tooltip="Edit name and category"}
      local gap=subject.add{type="empty-widget"}
      gap.style.horizontally_stretchable=true
      subject.style.horizontally_stretchable=true
      subject.add{type="label",name="pending_count",caption="",style="caption_label"}
    end
  end
  if state.parent_template then
    local slot=root.add{type="empty-widget",name="review_slot"}
    slot.style.height=36; slot.style.bottom_margin=24
    local review_frame=player.gui.screen.add{type="frame",name=M.root.."_review",direction="vertical",style="invisible_frame"}
    review_frame.style.padding=0; review_frame.style.width=ROW_WIDTH; review_frame.style.height=36
    local review=review_frame.add{type="button",name="review_changes",caption="[img="..components.icons.submit.."]  View Changes",tags={action="template_changes"}}
    review.style.width=ROW_WIDTH
    review.style.height=36
    local section=root.add{type="label",caption="References",style="caption_label"}
    section.style.height=24
  end
  local list_space=root.add{type="empty-widget",name="list_space"}
  list_space.style.height=#visible_items(state)*ROW_STEP+8
  -- A click raises its top-level frame before Lua handles the event. Keeping
  -- this footer separate prevents an Add click from covering every row.
  local footer=player.gui.screen.add{type="frame",name=M.root.."_footer",direction="vertical",style="invisible_frame"}
  footer.style.width=ROW_WIDTH
  footer.style.height=36
  local add=footer.add{type="button", name="add_template", caption=state.workspace=="collection" and "+ Reference a Template" or "+ Add a Template",
    style="train_schedule_add_interrupt_station_button", tags={action="add"}}
  add.enabled=state.workspace~="collection" or state.parent_template~=nil
  add.style.width=ROW_WIDTH
  add.style.height=36
  if state.location then root.location=state.location else
    root.location={x=math.max(0,(player.display_resolution.width-WINDOW_WIDTH*player.display_scale)/2),
      y=math.max(0,(player.display_resolution.height-window_height*player.display_scale)/2)}
  end
  M.refresh_rows(player,state)
  if state.override_selected then overrides.show(player,state,state.override_selected) end
end

return M
