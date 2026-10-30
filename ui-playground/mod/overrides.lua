-- UI fixtures only. Actions resolve sample entries; no world/template writes.
local world=require("__fabric-ui-playground__/world")
local M={panel_name="fabric_ui_overrides"}
local categories={"Moved","Replaced","Deleted"}
function M.seed(item)
  item.override_fixture_v2=true
  item.overrides={
    {id=1,category="Moved",title="Electric furnace",detail="Moved 2 tiles east",icon="electric-furnace"},
    {id=2,category="Replaced",title="Transport belt → Fast transport belt",detail="Yellow belt replaced with red belt",icon="fast-transport-belt"},
    {id=3,category="Deleted",title="Inserter",detail="Removed from this instance",icon="inserter"},
  }
  item.override_message=nil
end
function M.count(item)
  if not item.override_fixture_v2 then
    -- Mix clean and changed demo rows; preserve any actions already tried.
    if not item.override_message and item.id%3~=0 then item.overrides={}
    elseif not item.overrides then M.seed(item) end
    item.override_fixture_v2=true
  end
  item.overrides=item.overrides or {}
  return #item.overrides
end
local function find(state,id)
  for _,item in ipairs(state.items) do if item.id==id then return item end end
end
function M.close(player,state)
  local panel=player.gui.screen[M.panel_name]
  if panel then panel.destroy() end
  world.clear(state)
  state.override_selected=nil
end
local function button(parent,caption,action,item,change)
  local b=parent.add{type="button",caption=caption,tags={action=action,id=item.id,change=change}}
  b.style.height=28
  b.style.padding=4
  return b
end
function M.show(player,state,id)
  local item=find(state,id)
  if not item then M.close(player,state); return end
  M.count(item)
  for _,change in ipairs(item.overrides) do
    if change.category=="Moved" then
      change.icon=({"electric-furnace","assembling-machine-2","steel-chest"})[id%3+1]
      change.title=change.icon
    end
  end
  state.override_selected=id
  local panel=player.gui.screen[M.panel_name]
  if not panel then
    panel=player.gui.screen.add{type="frame",name=M.panel_name,direction="vertical"}
    panel.style.width=420
    local root=player.gui.screen.fabric_ui_playground
    local scale=player.display_scale
    local x=root.location.x+432*scale
    if x+420*scale>player.display_resolution.width then x=root.location.x-432*scale end
    panel.location={x=math.max(0,x),y=math.max(0,math.min(root.location.y,player.display_resolution.height-300*scale))}
  end
  panel.clear()
  local header=panel.add{type="flow",direction="horizontal"}
  header.add{type="label",caption="Overrides",style="frame_title"}
  local drag=header.add{type="empty-widget",style="draggable_space_header"}
  drag.style.horizontally_stretchable=true; drag.style.height=24; drag.drag_target=panel
  button(header,"×","overrides_close",item).style.width=28
  local name=panel.add{type="label",caption=item.name,style="bold_label"}
  name.style.single_line=false; name.style.maximal_width=388
  if #item.overrides==0 then
    panel.add{type="label",caption="No overrides · matches the base template"}
  end
  for _,change in ipairs(item.overrides) do
    local row=panel.add{type="frame",direction="horizontal",style="train_schedule_station_frame",
      tags={override_change=true,id=item.id,change=change.id},
      tooltip=change.title.."\n"..change.detail.."\nHover to preview · click to locate (sample)"}
    row.style.vertical_align="center"; row.style.width=388; row.style.height=36; row.style.padding=0
    local content=row.add{type="flow",direction="horizontal"}
    content.style.vertical_align="center"; content.style.horizontal_spacing=6
    content.style.height=28; content.style.left_margin=8; content.style.right_margin=8
    content.style.top_margin=-1; content.style.bottom_margin=1
    local category=content.add{type="label",caption=change.category,style="bold_label"}
    category.style.width=72; category.style.height=28; category.style.vertical_align="center"
    local function icon(name)
      local sprite=content.add{type="sprite",sprite="item/"..name}
      sprite.style.size=24; sprite.style.top_margin=1
    end
    if change.category=="Replaced" then
      icon("transport-belt")
      content.add{type="label",caption="→"}
      icon(change.icon)
    else
      icon(change.icon)
      if change.category=="Moved" then content.add{type="label",caption="→ 2 tiles"} end
    end
    local space=content.add{type="empty-widget"}
    space.style.horizontally_stretchable=true
    content.style.horizontally_stretchable=true
    for _,spec in ipairs({
      {"utility/check_mark_white","override_apply","Apply to base template (sample)"},
      {"utility/reset_white","override_reset","Reset instance to base template (sample)"},
    }) do
      local action=content.add{type="sprite-button",sprite=spec[1],tooltip=spec[3],
        tags={action=spec[2],id=item.id,change=change.id}}
      action.style.size=28
    end
    local function hover(element)
      element.raise_hover_events=true
      for _,child in pairs(element.children) do hover(child) end
    end
    hover(row)
  end
  local all=panel.add{type="flow",direction="horizontal"}
  button(all,"Apply all to template","override_apply",item).enabled=#item.overrides>0
  button(all,"Reset all","override_reset",item).enabled=#item.overrides>0
  if item.override_message then
    local notice=panel.add{type="label",caption=item.override_message}
    notice.style.single_line=false; notice.style.maximal_width=388
  end
  button(panel,"Restore sample changes","override_seed",item)
  panel.bring_to_front()
end
function M.preview(player,state,id,change_id,focus)
  local item=find(state,id)
  if not item then return end
  for _,change in ipairs(item.overrides or {}) do
    if change.id==change_id then return world.preview_change(player,state,id,change,focus) end
  end
end
function M.act(state,id,change_id,action)
  local item=find(state,id)
  if not item then return false end
  M.count(item)
  if action=="override_seed" then M.seed(item); return true end
  local affected=0
  for i=#item.overrides,1,-1 do
    if not change_id or item.overrides[i].id==change_id then table.remove(item.overrides,i); affected=affected+1 end
  end
  item.override_message="Mock: "..affected.." change(s) "..(action=="override_apply" and "applied to the base template." or "reset to the base template.")
  return true
end
return M
