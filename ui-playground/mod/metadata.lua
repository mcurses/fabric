local runtime=require("__fabric-ui-playground__/runtime")
local world_areas=require("__fabric-ui-playground__/world_areas")
local components=require("__fabric-ui-playground__/components")
local workspaces=require("__fabric-ui-playground__/workspaces")
local slots=require('__fabric-ui-playground__/slots')
local snapshots=require('__fabric-ui-playground__/snapshots')
local M={name="fabric_ui_metadata",category_name="fabric_ui_category"}
local function destroy(player,name)
  local panel=player.gui.screen[name]
  if panel then panel.destroy() end
end
function M.close(player)
  if storage.fabric_job and not storage.fabric_job.finishing then storage.fabric_job.close_panels[M.name]=true;return end

  destroy(player,M.name); destroy(player,M.category_name)
end
function M.show(player,state,creating)
  local instance=not creating and state.workspace=="world" and state.camera_area
  if not creating and not instance and not state.parent_template then return end
  M.close(player)
  workspaces.catalog(player,state)
  local template=creating and {name="New Template"} or instance or state.parent_template
  state.anchor_draft={[0]=snapshots.copy(template.slot_anchor)}
  for i,slot in ipairs(template.slot_definitions or {}) do state.anchor_draft[i]=snapshots.copy(slot.anchor) end
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
  if creating then
    panel.add{type="checkbox",name="origin_template",caption="Origin Template",state=false,
      tooltip="Defines a layout and can be shown as an underlay. It is not an inherited reference."}
    panel.add{type="label",caption="Layout",style="caption_label"}
    local names={"Custom size"};local ids={0}
    for _,entry in ipairs(runtime.catalog()) do if entry.is_origin then names[#names+1]=entry.name;ids[#ids+1]=entry.id end end
    panel.add{type="drop-down",name="origin_picker",items=names,selected_index=#names>1 and 2 or 1,
      tags={action="metadata_layout",ids=ids}}.style.width=348
    local sizes=panel.add{type="flow",name="sizes",direction="horizontal"}
    sizes.add{type="label",caption="Width"}
    sizes.add{type="textfield",name="cell_width",text="160",numeric=true,allow_decimal=false,allow_negative=false}.style.width=72
    sizes.add{type="label",caption="Height"}
    sizes.add{type="textfield",name="cell_height",text="160",numeric=true,allow_decimal=false,allow_negative=false}.style.width=72
    panel.add{type="label",caption="Editing padding (each side)",style="caption_label"}
    panel.add{type="textfield",name="padding",text="32",numeric=true,allow_decimal=false,allow_negative=false}.style.width=100
  elseif template.width then
    panel.add{type="label",caption=template.width.." × "..template.height.." · padding "..template.padding..(template.is_origin and " · Origin Template" or "")}
  end
  panel.add{type='label',caption='Slots',style='caption_label'}.style.top_margin=8
  local count=panel.add{type='textfield',name='slot_count',text=tostring(#(template.slot_definitions or {})),numeric=true,allow_decimal=false,allow_negative=false,tags={action='slot_count'}}
  count.style.width=64;count.tooltip='Number of slots (0–32). Reducing this removes assignments in deleted slots.'
  panel.add{type='checkbox',name='slot_eligible',caption='Can be filled into a slot',state=template.slot_eligible or false,tags={action='slot_eligible'}}
  local anchors=panel.add{type='scroll-pane',name='slot_anchors',direction='vertical',horizontal_scroll_policy='never',vertical_scroll_policy='auto'}
  anchors.style.width=348;anchors.style.maximal_height=150
  M.anchors(player,state)
  end
  local save=panel.add{type="button",caption=creating and "Sew new Template" or "Save",tags={action="metadata_save"}}
  save.style.width=348; save.style.height=36; save.style.top_margin=12
  panel.auto_center=true
  if creating then M.layout(player) end
end
function M.anchors(player,state)
  local panel=player.gui.screen[M.name];if not panel or not panel.slot_count then return end
  local count=tonumber(panel.slot_count.text) or 0;count=math.max(0,math.min(32,math.floor(count)))
  panel.slot_eligible.enabled=count==0
  if count>0 then panel.slot_eligible.state=false end
  local list=panel.slot_anchors;list.clear()
  local function anchor_row(index,label)
    local row=list.add{type='flow',direction='horizontal'};row.style.vertical_align='center'
    local anchor=state.anchor_draft and state.anchor_draft[index]
    row.add{type='label',caption=label..(anchor and ('  [entity='..anchor.name..']') or ' · inactive')}.style.width=190
    row.add{type='button',caption=anchor and 'Change anchor' or 'Select anchor',enabled=not panel.tags.creating,tags={action='slot_anchor_pick',slot=index},tooltip=panel.tags.creating and 'Create this template first, then select its anchor entity.' or 'Click an owned entity in the template editor.'}
  end
  for i=1,count do anchor_row(i,'Slot '..i) end
  if panel.slot_eligible.state then anchor_row(0,'Template anchor') end
end
function M.layout(player)
  local panel=player.gui.screen[M.name]
  if not panel or not panel.origin_picker then return end
  local id=panel.origin_picker.tags.ids[panel.origin_picker.selected_index]
  local origin=id~=0 and runtime.template(id)
  panel.sizes.cell_width.enabled=not origin
  panel.sizes.cell_height.enabled=not origin
  if origin then panel.sizes.cell_width.text=tostring(origin.width);panel.sizes.cell_height.text=tostring(origin.height) end
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
function M.validate(player)
  local panel=player.gui.screen[M.name]
  if not panel or panel.tags.instance then return true end
  local t=not panel.tags.creating and runtime.template(panel.tags.id) or nil
  return slots.can_configure(t,tonumber(panel.slot_count.text),panel.slot_eligible.state)
end
function M.save(player,state)
  local panel=player.gui.screen[M.name]
  if not panel then return false end
  local name=panel.template_name.text:match("^%s*(.-)%s*$")
  if name=="" then panel.template_name.focus(); return false end
  if panel.tags.instance then
    local demo=state.contexts.world.world_demo
    for _,area in ipairs(runtime.store().cells) do
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
  local slot_count=tonumber(panel.slot_count.text)
  assert(slot_count and slot_count%1==0 and slot_count>=0 and slot_count<=32,'Choose between 0 and 32 slots.')
  if panel.tags.creating then
    local origin=panel.origin_picker.tags.ids[panel.origin_picker.selected_index]
    local options={origin_id=origin~=0 and origin or nil,is_origin=panel.origin_template.state,
      width=tonumber(panel.sizes.cell_width.text),height=tonumber(panel.sizes.cell_height.text),
      padding=tonumber(panel.padding.text),category=category,icon=icon,slot_count=slot_count,slot_eligible=panel.slot_eligible.state}
    if not options.width or not options.height or not options.padding then player.print("Enter dimensions and padding.");return false end
    local template=workspaces.create_template(player,state,name,options)
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
  local previous=helpers.table_to_json({template.slot_definitions,template.slot_eligible or false,template.slot_anchor})
  slots.configure(template,slot_count,panel.slot_eligible.state)
  template.slot_anchor=snapshots.copy(state.anchor_draft and state.anchor_draft[0])
  for i,slot in ipairs(template.slot_definitions) do slot.anchor=snapshots.copy(state.anchor_draft and state.anchor_draft[i]) end
  local changed=previous~=helpers.table_to_json({template.slot_definitions,template.slot_eligible or false,template.slot_anchor})
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
  if changed then runtime.refresh_metadata(player,template) end
  M.close(player)
  return true
end
return M
