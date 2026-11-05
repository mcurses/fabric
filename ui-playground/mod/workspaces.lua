local world_areas=require("__fabric-ui-playground__/world_areas")
-- Presentation contexts only: shared UI, isolated lists/drafts, two demo surfaces.
local world=require("__fabric-ui-playground__/world")
local collection=require("__fabric-ui-playground__/collection")
local M={}
local function templates()
  return {
    {id=1,name="Iron Plate Pickup",icon="item/iron-plate",is_template=true},
    {id=2,name="Copper Plate Pickup",icon="item/copper-plate",is_template=true},
    {id=3,name="Steel Dropoff",icon="item/steel-plate",is_template=true},
  }
end
local function save(state)
  local context=state.contexts[state.workspace]
  if state.parent_template then state.parent_template.children_next=state.next_id end
  context.items=state.items
  context.next_id=state.next_id
  context.world_demo=state.world_demo
  context.parent_template=state.parent_template
end
function M.init(state)
  if state.contexts then return end
  state.workspace="world"
  state.editing_id=nil
  state.contexts={
    world={items=state.items,next_id=state.next_id,world_demo=state.world_demo},
    collection={items=templates(),next_id=4},
  }
end
local function load(state,key)
  local context=state.contexts[key]
  if state.instance_border and state.instance_border.valid then state.instance_border.destroy() end
  state.camera_instance=nil; state.camera_area=nil; state.world_camera_mode=nil
  state.workspace=key
  state.items=context.items
  state.next_id=context.next_id
  state.world_demo=context.world_demo
  state.parent_template=context.parent_template
  state.reviewing_parent=nil
  state.override_selected=nil
  state.editing_id=nil
  state.drag=nil
end
function M.select_camera(player,state)
  if state.workspace=="world" then return world_areas.select(player,state) end
  if state.workspace~="collection" then return false end
  local context=state.contexts.collection
  collection.ensure(player,context)
  local demo=context.world_demo
  state.world_demo=demo
  if player.surface~=demo.surface then
    player.teleport(demo.areas[1].center,demo.surface)
  end
  local area=collection.area_at(demo,player.position)
  local template=area and area.template or nil
  if state.parent_template==template and state.items== (template and template.children or context.empty_items) then return false end
  world.clear(state)
  if state.parent_template then state.parent_template.children_next=state.next_id end
  state.parent_template=template
  context.empty_items=context.empty_items or {}
  state.items=template and template.children or context.empty_items
  state.next_id=template and (template.children_next or 4) or 1
  demo.groups=area and area.groups or {}
  demo.override_examples=area and area.override_examples or {}
  demo.preview_origin=area and {x=area.center.x+12,y=area.center.y+3} or nil
  for _,cell in ipairs(demo.areas) do
    cell.border.color=cell==area and {0.2,0.9,1} or {0.5,0.5,0.5}
    cell.border.width=cell==area and 3 or 2
  end
  state.reviewing_parent=nil
  state.override_selected=nil
  state.editing_id=nil
  state.drag=nil
  save(state)
  return true
end
function M.switch(player,state,key)
  M.init(state)
  world.clear(state)
  if state.workspace=="collection" and state.world_demo then
    state.contexts.collection.camera=player.position
  end
  save(state)
  load(state,key)
  if key=="collection" then
    local context=state.contexts.collection
    collection.ensure(player,context)
    state.world_demo=context.world_demo
    player.teleport(context.camera or state.world_demo.areas[1].center,state.world_demo.surface)
    player.zoom=0.65
    M.select_camera(player,state)
  else
    world.open(player,state,true,"World")
  end
  save(state)
end
function M.categories(state)
  M.init(state)
  local context=state.contexts.collection
  context.categories=context.categories or {"Base Grid","Requester","Provider","Trash","Gleba"}
  return context.categories
end
function M.catalog(player,state)
  M.init(state)
  collection.ensure(player,state.contexts.collection)
  local catalog=state.contexts.collection.catalog
  local names={"Iron smelting","Copper smelting","Steel production","Green circuits","Red circuits",
    "Blue circuits","Oil processing","Plastic production","Sulfur and acid","Battery assembly",
    "Train unloading","Train loading","Mining outpost","Power station","Mall"}
  local icons={"iron-plate","copper-plate","steel-plate","electronic-circuit","advanced-circuit",
    "processing-unit","oil-refinery","plastic-bar","sulfur","battery","cargo-wagon","locomotive",
    "electric-mining-drill","steam-engine","assembling-machine-2"}
  local id=0
  for _,template in ipairs(catalog) do id=math.max(id,template.id) end
  while #catalog<50 do
    id=id+1
    local n=#catalog-4
    local variant=n%#names+1
    local name=names[variant].." · "..(math.floor(n/#names)+1)
    catalog[#catalog+1]={id=id,name=name,icon="item/"..icons[variant],is_template=true,
      children={},children_next=1,variety_fixture_v1=true,
      edit_draft={id=id,name=name,overrides={},fixture_version=2}}
  end
  local categories=M.categories(state)
  for i,template in ipairs(catalog) do
    template.category=template.category or categories[(i-1)%5+1]
  end
  return catalog
end
function M.source_template(player,state,item)
  local catalog=M.catalog(player,state)
  local base_name=item.name:gsub(" %d+$", "")
  for _,template in ipairs(catalog) do
    if (item.template_id and template.id==item.template_id) or
      (not item.template_id and template.name==base_name) then
      item.template_id=template.id
      return template
    end
  end
  -- Legacy sample references did not yet have catalog definitions.
  local id=0
  for _,template in ipairs(catalog) do id=math.max(id,template.id) end
  local template={id=id+1,name=base_name,icon=item.icon,is_template=true,
    category=M.categories(state)[1],children={},children_next=1,variety_fixture_v1=true,
    edit_draft={id=id+1,name=base_name,overrides={},fixture_version=2}}
  catalog[#catalog+1]=template
  item.template_id=template.id
  return template
end
function M.focus_template(player,state,id)
  M.switch(player,state,"collection")
  for _,area in ipairs(state.world_demo.areas) do
    if area.template.id==id then
      player.teleport(area.center,state.world_demo.surface)
      M.select_camera(player,state)
      return true
    end
  end
  for _,template in ipairs(state.contexts.collection.catalog) do
    if template.id==id then
      collection.add(player,state.contexts.collection,template.name,template)
      return M.focus_template(player,state,id)
    end
  end
  return false
end
function M.create_template(player,state,name)
  M.init(state)
  local template=collection.add(player,state.contexts.collection,name)
  M.focus_template(player,state,template.id)
  return template
end
function M.sync(player,state)
  M.init(state)
  for key,context in pairs(state.contexts) do
    if context.world_demo and context.world_demo.surface.valid and player.surface==context.world_demo.surface then
      if state.workspace~=key then
        world.clear(state); save(state); load(state,key)
        return true
      end
      return false
    end
  end
  return false
end
return M
