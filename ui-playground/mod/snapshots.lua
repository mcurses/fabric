-- Blueprint snapshots. Entity numbers here are only the blueprint format's local
-- wire indices, never persistent identity or matching across commits.
local M={}
-- Things completes construction at the next tick. Preserve blueprint tags only
-- during that same-tick gap, so immediate capture/commit cannot erase settings.
-- This is a transient placement cache, not persistent entity identity.
local recent_tick=-1
local recent_tags={}
local function tags_cache()
  if recent_tick~=game.tick then recent_tick=game.tick;recent_tags={} end
  return recent_tags
end
local function tag_key(surface,entity)
  return surface.index..":"..entity.name.."@"..entity.position.x..","..entity.position.y..":"..entity.direction
end
function M.copy(value)
  if type(value)~="table" then return value end
  local result={}
  for k,v in pairs(value) do result[k]=M.copy(v) end
  return result
end
function M.decode(bp) return helpers.json_to_table(helpers.decode_string(bp:sub(2))).blueprint end
function M.encode(snapshot)
  return '0'..helpers.encode_string(helpers.table_to_json({blueprint=snapshot}))
end
function M.empty() return {item='blueprint',version=562954248388608,entities={},tiles={}} end
function M.stack(snapshot)
  local inv=game.create_inventory(1)
  inv[1].set_stack{name='blueprint'}
  if #(snapshot.entities or {})>0 or #(snapshot.tiles or {})>0 then
    assert(inv[1].import_stack(M.encode(snapshot))==0,'Could not import snapshot')
  end
  return inv,inv[1]
end
function M.point(p,ref)
  local x,y=p.x,p.y
  if ref.flip_horizontal then x=-x end
  if ref.flip_vertical then y=-y end
  local turns=math.floor((ref.direction or 0)/4)%4
  for _=1,turns do x,y=-y,x end
  return {x=x+(ref.x or 0),y=y+(ref.y or 0)}
end
function M.transform(snapshot,ref)
  local out=M.copy(snapshot)
  out['snap-to-grid']=nil; out['absolute-snapping']=nil; out['position-relative-to-grid']=nil
  for _,entity in ipairs(out.entities or {}) do
    entity.position=M.point(entity.position,ref)
    local proto=prototypes.entity[entity.name]
    local kind=proto and proto.type or ''
    local curved=kind:find('curved%-rail')~=nil
    local d=entity.direction or 0
    if ref.flip_horizontal then d=(curved and 2 or 0)-d end
    if ref.flip_vertical then d=(curved and 10 or 8)-d end
    d=(d+(ref.direction or 0))%16
    if kind=='straight-rail' or kind=='elevated-straight-rail' or kind=='rail-support' then d=d%8 end
    if proto and not proto.supports_direction then d=0 end
    entity.direction=d
    if not not ref.flip_horizontal ~= not not ref.flip_vertical then
      for _,key in ipairs({'input_priority','output_priority'}) do
        if entity[key]=='left' then entity[key]='right' elseif entity[key]=='right' then entity[key]='left' end
      end
      if proto and proto.use_mirroring then entity.mirror=not entity.mirror end
    end
    if entity.orientation then
      local o=entity.orientation
      if ref.flip_horizontal then o=-o end
      if ref.flip_vertical then o=0.5-o end
      entity.orientation=(o+(ref.direction or 0)/16)%1
    end
    for _,key in ipairs({'pickup_position','drop_position'}) do
      if entity[key] then entity[key]=M.point(entity[key],{direction=ref.direction,flip_horizontal=ref.flip_horizontal,flip_vertical=ref.flip_vertical}) end
    end
  end
  for _,tile in ipairs(out.tiles or {}) do
    local p=M.point({x=tile.position.x+0.5,y=tile.position.y+0.5},ref)
    tile.position={x=math.floor(p.x),y=math.floor(p.y)}
  end
  return out
end
function M.bounds(snapshot)
  local l={x=0,y=0}; local r={x=0,y=0}
  for _,e in ipairs(snapshot.entities or {}) do
    local proto=prototypes.entity[e.name]
    local box=proto and proto.collision_box or {{-1,-1},{1,1}}
    local a=box.left_top or {x=box[1][1],y=box[1][2]}
    local b=box.right_bottom or {x=box[2][1],y=box[2][2]}
    local radius=math.max(math.abs(a.x),math.abs(a.y),math.abs(b.x),math.abs(b.y))
    l.x=math.min(l.x,e.position.x-radius); l.y=math.min(l.y,e.position.y-radius)
    r.x=math.max(r.x,e.position.x+radius); r.y=math.max(r.y,e.position.y+radius)
  end
  return {left_top=l,right_bottom=r}
end
function M.inside(p,b) return p.x>=b.left_top.x and p.x<b.right_bottom.x and p.y>=b.left_top.y and p.y<b.right_bottom.y end
function M.intersects(a,b)
  return a.left_top.x<b.right_bottom.x and a.right_bottom.x>b.left_top.x and a.left_top.y<b.right_bottom.y and a.right_bottom.y>b.left_top.y
end
function M.shift_bounds(b,p)
  return {left_top={x=b.left_top.x+p.x,y=b.left_top.y+p.y},right_bottom={x=b.right_bottom.x+p.x,y=b.right_bottom.y+p.y}}
end
function M.clear(surface,bounds)
  for _,e in ipairs(surface.find_entities_filtered{area=bounds}) do
    if e.valid and e.type~='character' and M.inside(e.position,bounds) then e.destroy{raise_destroy=true} end
  end
end
-- Paste exact relative coordinates. Explicit absolute 2-tile snapping prevents
-- Factorio from recentering narrow station snapshots on their bounding box.
function M.place(surface,force,snapshot,offset,clip)
  local function accepts(p) return not clip or (type(clip)=='function' and clip(p)) or (type(clip)=='table' and M.inside(p,clip)) end
  local data=M.copy(snapshot)
  local entities={}; local allowed={}
  for _,e in ipairs(data.entities or {}) do
    local p={x=e.position.x+offset.x,y=e.position.y+offset.y}
    if accepts(p) then entities[#entities+1]=e; allowed[e.entity_number]=true end
  end
  data.entities=entities
  -- Things graph links use blueprint-local IDs. Clipping or applying a single
  -- patch must not leave edges to entities absent from this blueprint.
  local local_ids={}
  for _,e in ipairs(entities) do if e.tags and e.tags['@i'] then local_ids[tostring(e.tags['@i'])]=true end end
  for _,e in ipairs(entities) do
    if e.tags and e.tags['@e'] then
      for _,targets in pairs(e.tags['@e']) do for target in pairs(targets) do if not local_ids[tostring(target)] then targets[target]=nil end end end
    end
  end
  if data.wires then
    local wires={}
    for _,w in ipairs(data.wires) do if allowed[w[1]] and allowed[w[3]] then wires[#wires+1]=w end end
    data.wires=wires
  end
  local tiles={}
  for _,t in ipairs(data.tiles or {}) do
    local p={x=t.position.x+offset.x,y=t.position.y+offset.y}
    if accepts(p) then tiles[#tiles+1]={name=t.name,position=p} end
  end
  if #tiles>0 then surface.set_tiles(tiles,false,false,true,false) end
  data.tiles=nil
  if #entities==0 then return {} end
  data['snap-to-grid']={x=2,y=2};data['absolute-snapping']=true;data['position-relative-to-grid']={x=0,y=0}
  local inv,stack=M.stack(data)
  local params={surface=surface,force=force,position=offset,
    build_mode=defines.build_mode.superforced,skip_fog_of_war=false,raise_built=true}
  local coop='cooperative-blueprinting-v1'
  local function paste()
    if remote.interfaces[coop] and remote.interfaces[coop].build_blueprint then
      return remote.call(coop,'build_blueprint',stack,params) or {}
    end
    return stack.build_blueprint(params)
  end
  -- Let Factorio decide collisions, especially for curved/elevated rails.
  -- Bounding-box deletion removes valid adjacent rail pieces and signals.
  local region=M.shift_bounds(M.bounds(data),offset)
  local ghosts=paste()
  local replaced=false
  for _,old in ipairs(surface.find_entities_filtered{area=region}) do
    if old.valid and old.type~='character' and old.type~='entity-ghost' then
      if old.to_be_deconstructed(force) or old.to_be_upgraded() then
        if accepts(old.position) then old.destroy{raise_destroy=true};replaced=true
        else old.cancel_deconstruction(force);old.cancel_upgrade(force) end
      end
    end
  end
  if replaced then
    for _,g in ipairs(paste()) do ghosts[#ghosts+1]=g end
  end
  local result={}
  for _=1,100 do
    local progress=false
    for _,ghost in ipairs(ghosts) do
      if ghost.valid and ghost.type=='entity-ghost' then
        local _,real=ghost.silent_revive{raise_revive=true}
        if real then result[#result+1]=real;progress=true end
      end
    end
    if not progress then break end
  end
  for _,ghost in ipairs(ghosts) do if ghost.valid then result[#result+1]=ghost end end
  inv.destroy()
  -- Include identical existing pieces that native blueprint placement reused.
  for _,e in ipairs(entities) do
    local p={x=e.position.x+offset.x,y=e.position.y+offset.y}
    local found=surface.find_entity(e.name,p)
    if found then
      result[#result+1]=found
      if e.tags then tags_cache()[tag_key(surface,found)]=M.copy(e.tags) end
    end
  end
  return result
end
function M.find(surface,e,offset)
  local p={x=e.position.x+offset.x,y=e.position.y+offset.y}
  for _,real in ipairs(surface.find_entities_filtered{name=e.name,position=p,radius=0.05}) do
    if real.position.x==p.x and real.position.y==p.y and real.direction==(e.direction or 0) then return real end
  end
end
function M.rewire(surface,snapshot,offset)
  local found={}
  for _,e in ipairs(snapshot.entities or {}) do found[e.entity_number]=M.find(surface,e,offset) end
  for _,wire in ipairs(snapshot.wires or {}) do
    local a,b=found[wire[1]],found[wire[3]]
    if a and b then
      local ac=a.get_wire_connector(wire[2],true);local bc=b.get_wire_connector(wire[4],true)
      if ac and bc then ac.connect_to(bc,false) end
    end
  end
end
function M.settle(surface,force)
  local ghosts=surface.find_entities_filtered{type='entity-ghost',force=force}
  for _=1,100 do
    local progress=false
    for _,g in ipairs(ghosts) do
      if g.valid and not (g.tags and g.tags.fabric_preview) then local _,real=g.silent_revive{raise_revive=true};if real then progress=true end end
    end
    if not progress then break end
  end
  -- Script revives do not auto-wire poles as ordinary player placement does.
  for _,pole in ipairs(surface.find_entities_filtered{type='electric-pole',force=force}) do
    local reach=pole.prototype.get_max_wire_distance(pole.quality)
    local c=pole.get_wire_connector(defines.wire_connector_id.pole_copper,true)
    for _,other in ipairs(surface.find_entities_filtered{type='electric-pole',position=pole.position,radius=reach,force=force}) do
      local dx,dy=pole.position.x-other.position.x,pole.position.y-other.position.y
      if other~=pole and dx*dx+dy*dy<=math.min(reach,other.prototype.get_max_wire_distance(other.quality))^2 then
        c.connect_to(other.get_wire_connector(defines.wire_connector_id.pole_copper,true),false)
      end
    end
  end
end
function M.entity_key(e) return e.name.."@"..e.position.x..","..e.position.y..":"..e.direction end
function M.capture(surface,force,bounds,center,exclude)
  local inv=game.create_inventory(1);local stack=inv[1];stack.set_stack{name='blueprint'}
  local params={surface=surface,force=force,area=bounds,
    always_include_tiles=false,include_station_names=true,include_trains=false,include_modules=true}
  local mapping=stack.create_blueprint(params)
  local coop='cooperative-blueprinting-v1'
  if remote.interfaces[coop] and remote.interfaces[coop].create_blueprint then
    remote.call(coop,'create_blueprint',stack,params)
  end
  local data=stack.is_blueprint_setup() and M.decode(stack.export_stack()) or M.empty()
  local kept,allowed={},{}
  for _,e in ipairs(data.entities or {}) do
    local source=mapping[e.entity_number]
    if source and source.valid and not (source.type=='entity-ghost' and source.tags and source.tags.fabric_preview) and not (exclude and exclude[M.entity_key(source)]) then
      if not e.tags then e.tags=M.copy(tags_cache()[tag_key(surface,source)]) end
      e.position={x=source.position.x-center.x,y=source.position.y-center.y}
      kept[#kept+1]=e;allowed[e.entity_number]=true
    end
  end
  data.entities=kept
  local wires={}
  for _,w in ipairs(data.wires or {}) do if allowed[w[1]] and allowed[w[3]] then wires[#wires+1]=w end end
  data.wires=wires
  data.tiles={}
  -- Only changes from the editor's default concrete floor belong to a snapshot.
  for _,tile in ipairs(surface.find_tiles_filtered{area=bounds,name={"refined-concrete","out-of-map"},invert=true}) do
    if tile.name~='refined-concrete' and tile.name~='out-of-map' then
      data.tiles[#data.tiles+1]={name=tile.name,position={x=tile.position.x-center.x,y=tile.position.y-center.y}}
    end
  end
  data['snap-to-grid']=nil; data['absolute-snapping']=nil; data['position-relative-to-grid']=nil
  data.label=nil; data.description=nil; data.icons=nil
  inv.destroy();return data
end
return M
