local R=require('__fabric-ui-playground__/runtime')
local S=require('__fabric-ui-playground__/snapshots')
local world=require('__fabric-ui-playground__/world')
local M={}
function M.init(state) state.workspace=state.workspace or 'world' end
function M.attach(player,state)
  local db=R.ensure(player)
  if not state.snapshot_schema then
    local old=state.contexts
    state.contexts={world={world_demo={surface=db.world_surface,groups={},world_areas=db.cells}},
      collection={catalog=R.catalog(),categories=db.categories,world_demo={surface=db.collection_surface,areas={},groups={}}}}
    state.workspace='world';state.snapshot_schema=1;state.items={};state.next_id=db.next_ref
    state.parent_template=nil;state.camera_area=nil;state.override_selected=nil;state.editing_id=nil
    player.teleport(db.cells[1].center,db.world_surface)
    -- Remove only the prior disposable prototype surfaces, never unrelated saves.
    for _,context in pairs(old or {}) do
      local sf=context.world_demo and context.world_demo.surface
      if sf and sf.valid and sf~=db.world_surface and sf~=db.collection_surface then
        local occupied=false
        for _,p in pairs(game.players) do if p.surface==sf then occupied=true end end
        if not occupied then game.delete_surface(sf) end
      end
    end
  end
  state.contexts.collection.catalog=R.catalog()
  return db
end
function M.select_camera(player,state)
  local db=M.attach(player,state)
  local old_template,old_area=state.parent_template,state.camera_area
  if player.surface==db.collection_surface then state.workspace='collection'
  elseif player.surface==db.world_surface then state.workspace='world'
  else return false end
  state.parent_template=nil;state.camera_area=nil
  if state.workspace=='collection' then
    local areas={}
    for _,t in ipairs(R.catalog()) do
      if t.area then
        areas[#areas+1]=t.area
        if S.inside(player.position,t.area.edit_bounds) then state.parent_template=t end
      end
    end
    state.world_demo=state.contexts.collection.world_demo;state.world_demo.areas=areas
    local t=state.parent_template
    state.items=t and t.children or {}
    state.world_demo.groups=t and t.area.groups or {}
    for _,area in ipairs(areas) do area.border.color=area.template==t and {0.2,0.9,1} or {0.5,0.5,0.5} end
  else
    state.world_camera_mode=true
    state.world_demo=state.contexts.world.world_demo
    for _,cell in ipairs(db.cells) do if S.inside(player.position,cell.bounds) then state.camera_area=cell end end
    local cell=state.camera_area
    state.items=cell and cell.items or {}
    state.world_demo.groups=cell and cell.groups or {}
    for _,c in ipairs(db.cells) do c.border.color=c==cell and {0.2,0.9,1} or {0.5,0.5,0.5} end
  end
  for _,ref in ipairs(state.items) do
    ref.name=R.ref_name(ref)
    if not ref.neighbor then ref.icon=R.template(ref.template_id).icon end
  end
  state.next_id=db.next_ref
  state.contexts[state.workspace].items=state.items
  if old_template~=state.parent_template or old_area~=state.camera_area then
    world.clear(state);state.override_selected=nil;state.editing_id=nil;state.reviewing_parent=nil;state.drag=nil
    return true
  end
  return false
end
function M.switch(player,state,key)
  local db=M.attach(player,state);world.clear(state)
  if state.world_demo then state.contexts[state.workspace].camera=player.position end
  state.workspace=key
  if key=='collection' then
    local t=R.template(1);local area=R.ensure_area(player,t)
    player.teleport(state.contexts.collection.camera or area.center,db.collection_surface)
  else player.teleport(state.contexts.world.camera or db.cells[1].center,db.world_surface) end
  player.zoom=0.35
  M.select_camera(player,state)
end
function M.categories(state) return R.store().categories end
function M.catalog(player,state) M.attach(player,state);return R.catalog() end
function M.source_template(player,state,item) return item.template_id and R.template(item.template_id) end
function M.focus_template(player,state,id)
  local db=M.attach(player,state);local t=assert(R.template(id));local area=R.ensure_area(player,t)
  world.clear(state)
  player.teleport(area.center,db.collection_surface);player.zoom=0.35
  M.select_camera(player,state);return true
end
function M.create_template(player,state,name,options)
  options=options or {};options.name=name
  local t=R.create(player,options);M.focus_template(player,state,t.id);return t
end
function M.sync(player,state)
  local before=state.workspace;M.select_camera(player,state);return before~=state.workspace
end
return M
