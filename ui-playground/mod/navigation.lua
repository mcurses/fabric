local components=require("__fabric-ui-playground__/components")
local M={dialog="fabric_ui_new_template"}
M.tuning_fields={
  {key="icon_size",label="Icon size",default=20,min=12,max=48},
  {key="icon_gap",label="Icon → title gap",default=7,min=0,max=40},
  {key="icon_x",label="Icon ← / →",default=0,min=-12,max=24},
  {key="icon_y",label="Icon ↑ / ↓",default=0,min=-16,max=16},
  {key="title_y",label="Title ↑ / ↓",default=0,min=-16,max=16},
}
function M.tuning(state)
  state.navigation_tuning=state.navigation_tuning or {}
  for _,f in ipairs(M.tuning_fields) do
    if state.navigation_tuning[f.key]==nil then state.navigation_tuning[f.key]=f.default end
  end
  return state.navigation_tuning
end
function M.apply_tuning(player,state)
  local panel=player.gui.screen.fabric_ui_controls
  if not panel or not panel.header then return end
  local t=M.tuning(state)
  local icon=panel.header.brand
  icon.style.size=t.icon_size
  icon.style.stretch_image_to_widget_size=true
  icon.style.left_margin=t.icon_x
  icon.style.right_margin=t.icon_gap-4
  icon.style.top_margin=t.icon_y; icon.style.bottom_margin=-t.icon_y
  panel.header.title_text.style.top_margin=t.title_y
  panel.header.title_text.style.bottom_margin=-t.title_y
end
function M.show(player,state)
  local old=player.gui.left.fabric_ui_controls
  if old then old.destroy() end
  local existing=player.gui.screen.fabric_ui_controls
  if state and state.navigation_closed then
    if existing then existing.destroy() end
    return
  end
  if existing and existing.tags.version==5 and existing.tags.complete then
    pcall(function() existing.children[1].children[1].sprite="fabric-ui-brand" end)
    M.apply_tuning(player,state)
    return
  end
  if existing then existing.destroy() end
  local panel=player.gui.screen.add{type="frame",name="fabric_ui_controls",direction="vertical"}
  panel.style.width=230
  local scale=player.display_scale
  panel.location={x=12*scale,y=math.min(330*scale,math.max(80*scale,player.display_resolution.height-210*scale))}
  local title=panel.add{type="flow",name="header",direction="horizontal"}
  title.style.horizontal_spacing=4
  title.style.vertical_align="center"
  local ok,icon=pcall(function()
    return title.add{type="sprite",name="brand",sprite="fabric-ui-brand",tooltip="Fabric"}
  end)
  if not ok then icon=title.add{type="sprite",name="brand",sprite="item/blueprint",tooltip="Fabric"} end
  icon.style.size=28
  local caption=title.add{type="label",name="title_text",caption="Fabric",style="frame_title"}
  caption.drag_target=panel
  local drag=title.add{type="empty-widget",style="draggable_space_header"}
  drag.style.horizontally_stretchable=true; drag.style.height=24; drag.drag_target=panel
  title.style.horizontally_stretchable=true
  title.add{type="sprite-button",sprite="utility/close",style="close_button",tags={action="fabric_controls_close"}}
  for _,spec in ipairs({
    {"View Template Collection","library"},{"+ Sew new Template","template_new"},{"Edit on Map","edit_current"},
  }) do
    local button=panel.add{type="button",caption=spec[1],tags={action=spec[2]}}
    button.style.width=206; button.style.height=32
  end
  panel.tags={complete=true,version=5}
  M.apply_tuning(player,state)
end
function M.close(player,state)
  state.navigation_closed=true
  local panel=player.gui.screen.fabric_ui_controls
  if panel then panel.destroy() end
end
function M.toggle(player,state)
  if player.gui.screen.fabric_ui_controls then M.close(player,state)
  else state.navigation_closed=false; M.show(player,state) end
end
function M.close_new(player)
  local dialog=player.gui.screen[M.dialog]
  if dialog then dialog.destroy() end
end
return M
