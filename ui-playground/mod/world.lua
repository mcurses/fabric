local R=require('__fabric-ui-playground__/runtime')
local S=require('__fabric-ui-playground__/snapshots')
local G=require('__fabric-ui-playground__/ghosts')
-- Hover feedback and camera focus for real template references.
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
local function tint(alpha) return {r=0.2*alpha,g=0.9*alpha,b=alpha,a=alpha} end
function M.highlight(player,state,id)
  if state.highlight_id==id then return end
  M.clear(state)
  local demo=state.world_demo
  local group=demo and demo.groups[id]
  if id<0 and state.camera_area then
    group={entities={}}
    for _,ref in ipairs(state.camera_area.items) do if ref.neighbor then
      for _,entity in ipairs((demo.groups[ref.id] or {}).entities or {}) do group.entities[#group.entities+1]=entity end
    end end
  end
  if not group or not demo.surface.valid or player.surface.index~=demo.surface.index then return end
  local ref=id<0 and state.camera_area and R.neighbor_group(state.camera_area) or nil
  for _,item in ipairs(state.items or {}) do if item.id==id then ref=item;break end end
  if ref then
    local center,snapshot
    if state.workspace=='world' and state.camera_area then
      center=state.camera_area.center;snapshot=R.reference_snapshot(state.camera_area,ref)
    elseif state.parent_template and ref.template_id then
      center=state.parent_template.area.center;snapshot=S.transform(R.flatten(ref.template_id,ref.slot_assignments),ref)
    end
    if snapshot then state.preview_ghosts=G.show(demo.surface,snapshot,center,function(e) return not S.find(demo.surface,e,center) end) end
  end
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
  if id<0 and state.camera_area then
    group={entities={}}
    for _,ref in ipairs(state.camera_area.items) do if ref.neighbor then
      for _,entity in ipairs((demo.groups[ref.id] or {}).entities or {}) do group.entities[#group.entities+1]=entity end
    end end
  end
  if not group or not demo.surface.valid then
    player.print("This reference has no buildings to locate.")
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
  if not x1 then player.print("This reference has no remaining buildings to locate."); return false end
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
return M
