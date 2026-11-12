-- Exact player construction receipt: native pre-build observes one ghost,
-- the same callback batch consumes its material, and that ghost actually dies.
-- Tags/positions alone never authorize identity. Finalize after the entire tick.
local P={};local A
local Geometry=require('placement-geometry')
local function S()storage.fabric_player_revival=storage.fabric_player_revival or{frames={},pending={}};return storage.fabric_player_revival end
local function samepos(a,b)return a.x==b.x and a.y==b.y end
function P.init(api)A=api end
function P.pre(e)
 local p=game.get_player(e.player_index);local c=p and p.cursor_stack
 if not(c and c.valid_for_read and c.prototype.place_result)then return end
 local input=A.input(p.index);local st=S();local key=p.index..'/'..game.tick
 local f=st.frames[key]or{samples={}};st.frames[key]=f
 local v={position={x=e.position.x,y=e.position.y},surface=p.surface.index,item=c.name,quality=c.quality.name,ghosts={}}
 local mode=({build=0,['build-ghost']=1,['super-forced-build']=2})[input and input.kind]
 v.native=input and input.tool==c.name and input.epoch==A.epoch(p.index) and input.tick<=game.tick and mode==e.build_mode and (e.created_by_moving==true or game.tick==input.tick) or false
 for _,g in pairs(p.surface.find_entities_filtered{position=e.position,type='entity-ghost',force=p.force})do
  if g.valid and g.ghost_name==c.prototype.place_result.name and g.quality.name==c.quality.name then
   v.ghosts[#v.ghosts+1]={ref=g,unit=g.unit_number,name=g.ghost_name,position={x=g.position.x,y=g.position.y},surface=g.surface.index,quality=g.quality.name}
  end
 end
 if v.native and e.created_by_moving~=true then
  local proto=c.prototype.place_result;local w,h=proto.tile_width,proto.tile_height
  if not(input.cursor and w and h)then v.native=false
  else local model={entities={{entity_number=1,name=proto.name,position={x=(w%2)/2,y=(h%2)/2},direction=0}},tiles={}}
   local projection=Geometry.project(model,{position=input.cursor,direction=e.direction or 0})
   local expected=projection.supported and projection.entities['1'].position
   v.native=expected and samepos(expected,v.position)or false
  end
 end
 f.samples[#f.samples+1]=v
end
function P.built(e)
 local en=e.entity;if not(en and en.valid and en.type~='entity-ghost')then return false end
 local st=S();local f=st.frames[e.player_index..'/'..game.tick];if not f then return false end
 local relevant=false;for _,v in ipairs(f.samples)do if #v.ghosts>0 and samepos(v.position,en.position)then relevant=true end end
 if not relevant then return false end
 local k=tostring(en.unit_number);if st.pending[k]then st.pending[k].duplicate=true;return true end
 local material=e.consumed_items and e.consumed_items[1]
 local count=e.consumed_items and #e.consumed_items or 0
 A.register(en,'player-revival-unresolved')
 st.pending[k]={entity=en,player=e.player_index,tick=game.tick,position={x=en.position.x,y=en.position.y},surface=en.surface.index,tags=e.tags,material=count==1 and material.valid_for_read and{name=material.name,quality=material.quality.name}or nil}
 return true
end
function P.matches(proof,ghost)
 return proof and proof.kind=='verified-player-revival' and proof.tick==game.tick and proof.target==ghost or false
end
function P.tick()
 local st=S()
 for key,r in pairs(st.pending)do if r.tick<game.tick then
  local en=r.entity;local f=st.frames[r.player..'/'..r.tick];local samples={};local bodies=0
  for _,other in pairs(st.pending)do if other.player==r.player and other.tick==r.tick and other.surface==r.surface and samepos(other.position,r.position)then bodies=bodies+1 end end
  for _,v in ipairs(f and f.samples or{})do if v.surface==r.surface and samepos(v.position,r.position)then samples[#samples+1]=v end end
  local v=#samples==1 and samples[1];local g=v and #v.ghosts==1 and v.ghosts[1]
  if en.valid and not r.duplicate and bodies==1 and v and v.native and g and not g.ref.valid and r.material and r.material.name==v.item and r.material.quality==v.quality and en.name==g.name and en.quality.name==g.quality and en.surface.index==g.surface and samepos(en.position,g.position)then
   A.revive({entity=en,player_index=r.player,tags=r.tags},{kind='verified-player-revival',tick=game.tick,target=g.unit,built_tick=r.tick,player=r.player})
  end
 end end
 for key,r in pairs(st.pending)do if r.tick<game.tick then st.pending[key]=nil end end
 for key in pairs(st.frames)do local tick=tonumber(key:match('/(%d+)$'));if tick<game.tick then st.frames[key]=nil end end
end
return P
