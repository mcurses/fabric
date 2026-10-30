local overrides=require("__fabric-ui-playground__/overrides")
local highlight_styles=require("__fabric-ui-playground__/world").styles
local M = {root="fabric_ui_playground", revision="25"}
local ROW_HEIGHT, ROW_STEP, LIST_TOP = 36, 40, 52
local WINDOW_WIDTH, ROW_WIDTH, NAME_WIDTH = 420, 396, 272
local icons = {
  ["Iron Plate Pickup"]="item/iron-plate",
  ["Copper Plate Pickup"]="item/copper-plate",
  ["Steel Dropoff"]="item/steel-plate",
}

local function row_name(id) return M.root.."_row_"..id end

function M.close(player)
  -- Clean up controls from the discarded scrolling experiment on reload.
  for _, suffix in ipairs({"_scroll","_thumb"}) do
    local old=player.gui.screen[M.root..suffix]
    if old then old.destroy() end
  end
  for _, element in pairs(player.gui.screen.children) do
    if element.name == M.root or element.name == overrides.panel_name or element.name == M.root.."_tuning" or element.name == M.root.."_footer" or element.tags.fabric_ui_row then element.destroy() end
  end
end

-- Restore the composite window's stacking without moving or rebuilding rows.
function M.raise_rows(player,state)
  for _, item in ipairs(state.items) do
    local row=player.gui.screen[row_name(item.id)]
    if row then row.bring_to_front() end
  end
  if state.drag then
    local active=player.gui.screen[row_name(state.drag.id)]
    if active then active.bring_to_front() end
  end
  local footer=player.gui.screen[M.root.."_footer"]
  if footer then footer.bring_to_front() end
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
  for i, item in ipairs(state.items) do
    local row=player.gui.screen[row_name(item.id)]
    if row then
      if item.id ~= moving_id then
        local x=math.floor(origin.x+12*scale)
        local y=math.floor(origin.y+(LIST_TOP+(i-1)*ROW_STEP)*scale)
        if row.location.x ~= x or row.location.y ~= y then row.location={x=x,y=y} end
      end
    end
  end
  local footer=player.gui.screen[M.root.."_footer"]
  if footer then
    footer.location={x=math.floor(origin.x+12*scale),
      y=math.floor(origin.y+(56+#state.items*ROW_STEP)*scale)}
  end
  if raise_rows then M.raise_rows(player,state) end
end

function M.move(player, state, id, y)
  local root=player.gui.screen[M.root]
  if not root then return end
  local destination=math.floor(((y-root.location.y)/player.display_scale-LIST_TOP)/ROW_STEP+0.5)+1
  destination=math.max(1,math.min(#state.items,destination))
  for i, item in ipairs(state.items) do
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
  for _, item in ipairs(state.items) do
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
  overrides.close(player,state)
  local old=player.gui.screen[M.root.."_tuning"]
  if old then old.destroy(); return end
  local t=tuning(state)
  local panel=player.gui.screen.add{type="frame",name=M.root.."_tuning",caption="Live row tuning",direction="vertical"}
  panel.add{type="label",caption="World highlight"}
  panel.add{type="drop-down",name="highlight_style_picker",items=highlight_styles,
    selected_index=state.highlight_style or 5,tags={action="highlight_style"}}
  panel.add{type="label",caption="Choose a style, then hover a linked row."}
  panel.add{type="button",caption="Restore demo rows",tags={action="restore_world_rows"}}
  panel.add{type="line"}
  panel.add{type="label",caption="Negative = up · changes apply immediately"}
  for _, f in ipairs(tuning_fields) do
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
  local root=player.gui.screen[M.root]
  local scale=player.display_scale
  panel.location={x=math.max(0,math.min(root.location.x+(WINDOW_WIDTH+8)*scale,
    player.display_resolution.width-350*scale)),y=math.max(0,root.location.y)}
end
function M.adjust(player,state,element)
  local t=tuning(state)
  for _, f in ipairs(tuning_fields) do
    if f.key==element.tags.key then
      t[f.key]=math.max(f.min,math.min(f.max,t[f.key]+element.tags.delta))
      element.parent.tuning_value.caption=tostring(t[f.key])
      M.apply_tuning(player,state)
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

function M.refresh_rows(player,state)
  local root=player.gui.screen[M.root]
  if not root then return end
  local wanted={}
  for _, item in ipairs(state.items) do
    wanted[item.id]=true
    if not player.gui.screen[row_name(item.id)] then create_row(player,item) end
    local count=overrides.count(item)
    local label=player.gui.screen[row_name(item.id)].contents.item_name
    label.caption=item.name..(count>0 and "  [color=1,0.72,0.3]•[/color]" or "")
    label.tooltip=item.name..(count>0 and (" · "..count.." overrides") or " · No overrides").."\nClick to locate and inspect"
  end
  for _, element in pairs(player.gui.screen.children) do
    if element.tags.fabric_ui_row and not wanted[element.tags.id] then element.destroy() end
  end
  if state.override_selected and not wanted[state.override_selected] then overrides.close(player,state) end
  root.style.height=104+#state.items*ROW_STEP
  root.list_space.style.height=#state.items*ROW_STEP+8
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
  local window_height=104+#state.items*ROW_STEP
  root.style.height=window_height
  local title=root.add{type="flow", direction="horizontal", raise_hover_events=true}
  title.style.vertical_align="center"
  title.style.height=28
  title.add{type="label", caption="Fabric", style="frame_title"}
  local drag=title.add{type="empty-widget", style="draggable_space_header", raise_hover_events=true}
  drag.style.horizontally_stretchable=true
  drag.style.height=24
  drag.drag_target=root
  title.add{type="button", caption="World", tags={action="world"}, tooltip="Open hover demo / return to previous area"}.style.width=64
  title.add{type="button", caption="Tune", tags={action="tuning"}}.style.width=68
  title.add{type="button", caption="Reload", tags={action="reload"}, tooltip="Reload Lua · Ctrl+Shift+R"}
  title.add{type="button", caption="×", tags={action="close"}}.style.width=32
  for _, child in pairs(title.children) do
    if child.type=="button" then child.style.padding=4 end
  end
  local list_space=root.add{type="empty-widget",name="list_space"}
  list_space.style.height=#state.items*ROW_STEP+8
  -- A click raises its top-level frame before Lua handles the event. Keeping
  -- this footer separate prevents an Add click from covering every row.
  local footer=player.gui.screen.add{type="frame",name=M.root.."_footer",direction="vertical",style="invisible_frame"}
  footer.style.width=ROW_WIDTH
  footer.style.height=36
  local add=footer.add{type="button", name="add_template", caption="+ Add from Template",
    style="train_schedule_add_interrupt_station_button", tags={action="add"}}
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
