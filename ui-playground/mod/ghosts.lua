-- Native ghost artwork on an isolated force: no construction bots and no capture.
local S=require('__fabric-ui-playground__/snapshots')
local M={}
function M.clear(objects)
  for _,e in pairs(objects or {}) do if e.valid then e.destroy() end end
end
function M.show(surface,snapshot,center,filter)
  local force=game.forces['Fabric Preview'] or game.create_force('Fabric Preview')
  local ghosts={}
  for _,e in ipairs(snapshot.entities or {}) do
    local p={x=center.x+e.position.x,y=center.y+e.position.y}
    if not filter or filter(e,p) then
      local g=surface.create_entity{name='entity-ghost',inner_name=e.name,position=p,direction=e.direction or 0,
        force=force,quality=e.quality,expires=false,raise_built=false,tags={fabric_preview=true}}
      if g then g.destructible=false;g.minable_flag=false;ghosts[#ghosts+1]=g end
    end
  end
  return ghosts
end
return M
