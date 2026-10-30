-- Disposable world fixture for testing UI feedback, not Fabric placement logic.
local M={styles={"Border", "Soft fill", "Border + fill", "Group area", "Pulsing soft fill", "Markers"}}
function M.clear(state)
  for _,entity in pairs(state.preview_ghosts or {}) do
    if entity.valid then entity.destroy() end
  end
  state.preview_ghosts=nil
  -- Remove persistent baseline ghosts from the earlier prototype on reload.
  local demo=state.world_demo
  for _,fixture in pairs(demo and demo.override_examples or {}) do
    for _,key in ipairs({"old","before","deleted"}) do
      local entity=fixture[key]
      if entity and entity.valid then entity.destroy() end
      fixture[key]=nil
    end
  end
  for _, object in pairs(state.highlight_objects or {}) do
    if object.valid then object.destroy() end
  end
  state.highlight_objects=nil
  state.highlight_fills=nil
  state.highlight_id=nil
  state.hover_element=nil
end
function M.restore_rows(state)
  local demo=state.world_demo
  if not demo then return 0 end
  local present={}
  for _, item in ipairs(state.items) do present[item.id]=true end
  local ids={}
  for id in pairs(demo.groups) do ids[#ids+1]=id end
  table.sort(ids)
  local names={[1]="Iron Plate Pickup",[2]="Copper Plate Pickup",[3]="Steel Dropoff"}
  local restored=0
  for _,id in ipairs(ids) do
    if not present[id] then
      local group=demo.groups[id]
      state.items[#state.items+1]={id=id,name=group.name or names[id] or ("New Template "..id),icon=group.icon}
      restored=restored+1
    end
    state.next_id=math.max(state.next_id or 1,id+1)
  end
  return restored
end
local function tint(alpha) return {r=0.2*alpha,g=0.9*alpha,b=alpha,a=alpha} end
function M.highlight(player,state,id)
  if state.highlight_id==id then return end
  M.clear(state)
  local demo=state.world_demo
  local group=demo and demo.groups[id]
  if not group or not demo.surface.valid or player.surface.index~=demo.surface.index then return end
  state.highlight_id=id
  state.highlight_objects={}
  state.highlight_fills={}
  local mode=state.highlight_style or 5
  local function rectangle(left_top,right_bottom,filled)
    local object=rendering.draw_rectangle{
      color=filled and tint(0.18) or tint(1),width=3,filled=filled,
      left_top=left_top,right_bottom=right_bottom,surface=demo.surface,
      players={player.index},draw_on_ground=false,
    }
    state.highlight_objects[#state.highlight_objects+1]=object
    if filled then state.highlight_fills[#state.highlight_fills+1]=object end
  end
  local bounds
  for _, entity in ipairs(group.entities) do
    if entity.valid then
      local box=entity.prototype.selection_box
      local left={entity=entity,offset=box.left_top}
      local right={entity=entity,offset=box.right_bottom}
      if mode==4 then
        local b=entity.bounding_box
        if not bounds then bounds={left_top={x=b.left_top.x,y=b.left_top.y},right_bottom={x=b.right_bottom.x,y=b.right_bottom.y}}
        else
          bounds.left_top.x=math.min(bounds.left_top.x,b.left_top.x)
          bounds.left_top.y=math.min(bounds.left_top.y,b.left_top.y)
          bounds.right_bottom.x=math.max(bounds.right_bottom.x,b.right_bottom.x)
          bounds.right_bottom.y=math.max(bounds.right_bottom.y,b.right_bottom.y)
        end
      elseif mode==6 then
        state.highlight_objects[#state.highlight_objects+1]=rendering.draw_text{
          text="▼",surface=entity.surface,target={entity=entity,offset={0,box.left_top.y-0.8}},
          color=tint(1),scale=2,alignment="center",players={player.index},
        }
      else
        if mode==2 or mode==3 or mode==5 then rectangle(left,right,true) end
        if mode==1 or mode==3 then rectangle(left,right,false) end
      end
    end
  end
  if bounds then
    rectangle(bounds.left_top,bounds.right_bottom,true)
    rectangle(bounds.left_top,bounds.right_bottom,false)
  end
end
function M.set_style(player,state,index)
  if not M.styles[index] then return end
  local id=state.highlight_id
  M.clear(state)
  state.highlight_style=index
  if id then M.highlight(player,state,id) end
end
function M.tick(state,tick)
  if (state.highlight_style or 5)~=5 then return end
  local alpha=0.10+0.18*(0.5+0.5*math.sin(tick*math.pi/45))
  for _, object in ipairs(state.highlight_fills or {}) do
    if object.valid then object.color=tint(alpha) end
  end
end
function M.focus(player,state,id)
  local demo=state.world_demo
  local group=demo and demo.groups[id]
  if not group or not demo.surface.valid then
    player.print("This row has no demo buildings yet.")
    return false
  end
  local x1,y1,x2,y2
  for _,entity in ipairs(group.entities) do
    if entity.valid then
      local b=entity.bounding_box
      x1=math.min(x1 or b.left_top.x,b.left_top.x)
      y1=math.min(y1 or b.left_top.y,b.left_top.y)
      x2=math.max(x2 or b.right_bottom.x,b.right_bottom.x)
      y2=math.max(y2 or b.right_bottom.y,b.right_bottom.y)
    end
  end
  if not x1 then player.print("This group's demo buildings have been removed."); return false end
  local center={x=(x1+x2)/2,y=(y1+y2)/2}
  if player.controller_type==defines.controllers.editor or player.controller_type==defines.controllers.god then
    player.teleport(center,demo.surface)
  else
    -- Remote view centers the camera without moving a physical character.
    player.set_controller{type=defines.controllers.remote,position=center,surface=demo.surface}
  end
  M.highlight(player,state,id)
  return true
end
-- Render-only change fixtures: no building is moved, replaced, or deleted.
function M.preview_change(player,state,id,change,focus)
  local demo=state.world_demo
  if not demo or not demo.surface.valid then
    if focus then player.print("Open World first to preview sample changes.") end
    return false
  end
  -- Three real, isolated fixture instances, reused across reloads.
  demo.override_examples=demo.override_examples or {}
  local variant=id%3+1
  local fixture=demo.override_examples[variant]
  if not fixture then
    local y=(variant-2)*16
    local machine=({"electric-furnace","assembling-machine-2","steel-chest"})[variant]
    local function place(name,x,dy,ghost)
      return demo.surface.create_entity{name=ghost and "entity-ghost" or name,
        inner_name=ghost and name or nil,position={x=x,y=y+dy},force=player.force,
        direction=defines.direction.east}
    end
    fixture={y=y,machine=machine,
      moved=place(machine,-12,0),
      replaced=place("fast-transport-belt",-12,4),
}
    for x=-16,-10 do place("transport-belt",x,10) end
    place("steel-chest",-16,6); place("medium-electric-pole",-17,3)
    demo.override_examples[variant]=fixture
  end
  local y=fixture.y+(change.category=="Replaced" and 4 or change.category=="Deleted" and 7 or 0)
  local center={x=change.category=="Deleted" and -12 or -13,y=y}
  if focus then
    if player.controller_type==defines.controllers.editor or player.controller_type==defines.controllers.god then
      player.teleport(center,demo.surface)
    else
      player.set_controller{type=defines.controllers.remote,position=center,surface=demo.surface}
    end
  end
  M.clear(state)
  if player.surface~=demo.surface then return false end
  state.highlight_objects={}
  state.highlight_fills={}
  local function draw(kind,args)
    args.surface=demo.surface; args.players={player.index}
    state.highlight_objects[#state.highlight_objects+1]=rendering[kind](args)
  end
  local function ghost(name,x)
    local entity=demo.surface.create_entity{name="entity-ghost",inner_name=name,
      position={x=x,y=y},force=player.force,direction=defines.direction.east}
    state.preview_ghosts=state.preview_ghosts or {}
    if entity then state.preview_ghosts[#state.preview_ghosts+1]=entity end
    return entity
  end
  local function marker(entity,label,old)
    if not entity or not entity.valid then return end
    local color=old and {r=1,g=0.45,b=0.2,a=1} or tint(1)
    local box=entity.bounding_box
    draw("draw_rectangle",{color=color,width=2,filled=false,
      left_top=box.left_top,right_bottom=box.right_bottom})
    if not old then
      draw("draw_rectangle",{color=tint(0.2),filled=true,left_top=box.left_top,right_bottom=box.right_bottom})
      state.highlight_fills[#state.highlight_fills+1]=state.highlight_objects[#state.highlight_objects]
    end
    draw("draw_text",{text=label,target={x=entity.position.x,y=box.left_top.y-0.7},
      color=color,alignment="center",scale=0.8})
  end
  if change.category=="Moved" then
    marker(ghost(fixture.machine,-14),"Old position",true)
    marker(fixture.moved,"New position",false)
    draw("draw_text",{text="→",target={x=-13,y=y+2},color=tint(1),alignment="center"})
  elseif change.category=="Replaced" then
    marker(ghost("transport-belt",-14),"Before",true)
    marker(fixture.replaced,"After",false)
  else
    marker(ghost("inserter",-12),"Deleted · former position",true)
  end
  draw("draw_text",{text="Demo instance "..variant,target={x=-13,y=y+3},color={1,1,1},alignment="center",scale=0.7})
  return true
end
function M.open(player,state)
  M.clear(state)
  local demo=state.world_demo
  local return_surface,return_position=player.surface,player.position
  if demo and demo.layout_version~=2 then
    if player.surface==demo.surface and demo.return_surface and demo.return_surface.valid then
      return_surface,return_position=demo.return_surface,demo.return_position
    end
    demo=nil -- Keep the old test area intact; create the expanded fixture separately.
  end
  if demo and demo.surface.valid and player.surface==demo.surface then
    if demo.return_surface and demo.return_surface.valid then
      player.teleport(demo.return_position,demo.return_surface)
    end
    return
  end
  if not demo or not demo.surface.valid then
    local surface=game.create_surface("fabric-ui-hover-v2-"..player.index.."-"..game.tick,{
      width=64,height=64,peaceful_mode=true,
      autoplace_settings={entity={treat_missing_as_default=false,settings={}},
        decorative={treat_missing_as_default=false,settings={}}},
    })
    surface.request_to_generate_chunks({0,0},1)
    surface.force_generate_chunk_requests()
    surface.always_day=true
    local tiles={}
    for x=-24,24 do for y=-24,24 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    surface.set_tiles(tiles)
    demo={surface=surface,groups={},layout_version=2}
    state.highlight_style=state.highlight_style or 5
    state.world_demo=demo
    for i=1,math.min(3,#state.items) do
      local item=state.items[i]
      local y=(i-2)*16-3
      local group={entities={},name=item.name,icon=item.icon}
      demo.groups[item.id]=group
      local function place(name,x,dy,direction)
        local entity=surface.create_entity{name=name,position={x=x,y=y+dy},force=player.force,
          direction=direction or defines.direction.north}
        if entity then group.entities[#group.entities+1]=entity end
      end
      -- L-shaped assembly, U-shaped smelting, then two staggered storage islands.
      if i==1 then
        for _, pos in ipairs({{2,0},{6,0},{10,0},{2,4},{2,8}}) do place("assembling-machine-2",pos[1],pos[2]) end
        for x=5,13 do place("transport-belt",x,6,defines.direction.east) end
        place("inserter",4,4,defines.direction.east)
        place("inserter",6,5)
        place("steel-chest",14,6)
        place("medium-electric-pole",6,3)
        place("medium-electric-pole",10,3)
      elseif i==2 then
        for _, pos in ipairs({{2,0},{6,0},{10,0},{2,4},{10,4},{2,8},{10,8}}) do place("electric-furnace",pos[1],pos[2]) end
        for yoff=3,9 do place("transport-belt",6,yoff) end
        place("inserter",4,4,defines.direction.east)
        place("inserter",8,4,defines.direction.west)
        place("steel-chest",6,10)
        place("medium-electric-pole",4,7)
        place("medium-electric-pole",8,7)
      else
        for _, pos in ipairs({{2,0},{4,0},{6,0},{2,2},{4,2},{6,2},{10,5},{12,5},{10,7},{12,7}}) do place("steel-chest",pos[1],pos[2]) end
        for x=2,12 do place("transport-belt",x,4,defines.direction.east) end
        place("inserter",4,3)
        place("inserter",10,3,defines.direction.south)
        place("medium-electric-pole",8,1)
      end
      rendering.draw_text{text=item.name,surface=surface,target={x=6,y=y-3},
        color={r=1,g=1,b=1},alignment="center",players={player.index},scale=1.1}
    end
  end
  demo.return_surface=return_surface
  demo.return_position=return_position
  player.teleport({x=-7,y=0},demo.surface)
  player.zoom=0.65
  player.print("Hover the first three list rows to highlight their demo buildings. World returns to your previous area.")
end
return M
