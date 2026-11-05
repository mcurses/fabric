local overrides=require("__fabric-ui-playground__/overrides")
local components=require("__fabric-ui-playground__/components")
local workspaces=require("__fabric-ui-playground__/workspaces")
local M={name="fabric_ui_library"}
function M.close(player)
  local panel=player.gui.screen[M.name]
  if panel then panel.destroy() end
end
function M.show(player,state)
  M.close(player)
  local panel=player.gui.screen.add{type="frame",name=M.name,direction="vertical"}
  panel.style.width=600
  components.titlebar(panel,{title="Collection",close_tags={action="library_close"}})
  local body=panel.add{type="frame",style="inside_shallow_frame",direction="vertical"}
  body.style.padding=8
  local scroll=body.add{type="scroll-pane",name="templates",horizontal_scroll_policy="never",vertical_scroll_policy="always"}
  scroll.style.width=552
  scroll.style.height=math.min(420,math.max(180,player.display_resolution.height/player.display_scale-180))
  local catalog=workspaces.catalog(player,state)
  local group_count=0
  for _,category in ipairs(workspaces.categories(state)) do
    local items={}
    for _,template in ipairs(catalog) do
      if template.category==category then items[#items+1]=template end
    end
    if #items>0 then
      local section=scroll.add{type="flow",direction="vertical",tags={category=category}}
      section.style.vertical_spacing=8
      local heading=section.add{type="label",caption=category.." · "..#items,style="caption_label"}
      heading.style.top_margin=group_count>0 and 32 or 8
      group_count=group_count+1
      local grid=section.add{type="table",name="grid",column_count=5}
      grid.style.horizontal_spacing=12; grid.style.vertical_spacing=12
      for _,template in ipairs(items) do
        local card=grid.add{type="flow",direction="vertical"}
        card.style.width=96; card.style.height=128; card.style.horizontal_align="center"
        card.add{type="sprite-button",sprite=template.icon or "item/blueprint",
          style="blueprint_record_slot_button",tags={action="library_select",id=template.id},
          tooltip="Edit "..template.name}
        local label=card.add{type="label",caption=template.name..(overrides.pending_count(template)>0 and " [color=1,0.72,0.3]•[/color]" or ""),tags={action="library_select",id=template.id}}
        label.style.width=96; label.style.height=44
        label.style.single_line=false; label.style.horizontal_align="center"
      end
    end
  end
  panel.auto_center=true
end
return M
