local world_areas=require("__fabric-ui-playground__/world_areas")
local components=require("__fabric-ui-playground__/components")
local workspaces=require("__fabric-ui-playground__/workspaces")
local M={name="fabric_ui_metadata",category_name="fabric_ui_category"}
local function destroy(player,name)
  local panel=player.gui.screen[name]
  if panel then panel.destroy() end
end
function M.close(player)
  destroy(player,M.name); destroy(player,M.category_name)
end
function M.show(player,state,creating)
  local instance=not creating and state.workspace=="world" and state.camera_area
  if not creating and not instance and not state.parent_template then return end
  M.close(player)
  workspaces.catalog(player,state)
  local template=creating and {name="New Template"} or instance or state.parent_template
  local panel=player.gui.screen.add{type="frame",name=M.name,direction="vertical",tags={id=template.id,creating=creating or false,instance=instance~=nil and instance~=false}}
  panel.style.width=380
  components.titlebar(panel,{title=creating and "Sew new Template" or (instance and "Edit Instance Name" or "Edit Metadata"),close_tags={action="metadata_close"}})
  panel.add{type="label",caption="Name",style="caption_label"}
  panel.add{type="textfield",name="template_name",text=template.name}.style.width=348
  if not instance then
  panel.add{type="label",caption="Icon",style="caption_label"}.style.top_margin=8
  local kind,icon_name=(template.icon or "item/blueprint"):match("^([^/]+)/(.+)$")
  local picker=panel.add{type="choose-elem-button",name="template_icon",elem_type="signal",
    tooltip="Choose template icon"}
  picker.elem_value={type=kind=="virtual-signal" and "virtual" or kind,name=icon_name}
  panel.add{type="label",caption="Category",style="caption_label"}.style.top_margin=8
  local categories=workspaces.categories(state)
  local selected=1
  for i,name in ipairs(categories) do if name==template.category then selected=i end end
  panel.add{type="drop-down",name="category",items=categories,selected_index=selected}.style.width=348
  panel.add{type="button",caption="+ New Category",tags={action="category_new"}}.style.width=348
  end
  local save=panel.add{type="button",caption=creating and "Sew new Template" or "Save",tags={action="metadata_save"}}
  save.style.width=348; save.style.height=36; save.style.top_margin=12
  panel.auto_center=true
end
function M.new_category(player)
  destroy(player,M.category_name)
  local panel=player.gui.screen.add{type="frame",name=M.category_name,direction="vertical"}
  panel.style.width=320
  components.titlebar(panel,{title="New Category",close_tags={action="category_close"}})
  panel.add{type="textfield",name="category_name",text=""}.style.width=288
  panel.add{type="button",caption="Create Category",tags={action="category_create"}}.style.width=288
  panel.auto_center=true; panel.category_name.focus()
end
function M.close_category(player) destroy(player,M.category_name) end
function M.create_category(player,state)
  local panel=player.gui.screen[M.category_name]
  local editor=player.gui.screen[M.name]
  if not panel or not editor then return false end
  local name=panel.category_name.text:match("^%s*(.-)%s*$")
  if name=="" then return false end
  local categories=workspaces.categories(state)
  local index
  for i,category in ipairs(categories) do if category:lower()==name:lower() then index=i end end
  if not index then categories[#categories+1]=name; index=#categories end
  editor.category.items=categories; editor.category.selected_index=index
  M.close_category(player)
  return true
end
function M.save(player,state)
  local panel=player.gui.screen[M.name]
  if not panel then return false end
  local name=panel.template_name.text:match("^%s*(.-)%s*$")
  if name=="" then panel.template_name.focus(); return false end
  if panel.tags.instance then
    local demo=state.contexts.world.world_demo
    for _,area in ipairs(demo.world_areas or {}) do
      if area.id==panel.tags.id then
        world_areas.rename(demo,area,name)
        M.close(player)
        return true
      end
    end
    return false
  end
  local category=workspaces.categories(state)[panel.category.selected_index]
  local signal=panel.template_icon.elem_value
  local icon=signal and ((signal.type=="virtual" and "virtual-signal" or (signal.type or "item")).."/"..signal.name) or "item/blueprint"
  if panel.tags.creating then
    local template=workspaces.create_template(player,state,name)
    template.category=category
    template.icon=icon
    M.close(player)
    return true,true
  end
  local template
  for _,entry in ipairs(workspaces.catalog(player,state)) do
    if entry.id==panel.tags.id then template=entry; break end
  end
  if not template then return false end
  local old_name=template.name
  template.name=name
  template.category=category
  template.icon=icon
  local function update_references(items)
    for _,reference in ipairs(items or {}) do
      if reference.template_id==template.id then reference.icon=icon end
    end
  end
  for _,context in pairs(state.contexts) do update_references(context.items) end
  for _,entry in ipairs(state.contexts.collection.catalog) do update_references(entry.children) end
  if template.edit_draft then template.edit_draft.name=name end
  local demo=state.contexts.collection.world_demo
  for _,area in ipairs(demo.areas) do
    if area.template.id==template.id then
      if area.label and area.label.valid then area.label.text=name
      else
        -- Older saves did not keep label references.
        for _,object in pairs(rendering.get_all_objects()) do
          if object.valid and object.type=="text" and object.text==old_name then object.text=name end
        end
      end
    end
  end
  M.close(player)
  return true
end
return M
