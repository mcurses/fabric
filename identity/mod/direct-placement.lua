-- Fresh direct IDs require an observed native control, matching engine pre-build
-- and material receipt, and a unique complete tick of callbacks. API builds also
-- emit pre-build; keep every sample rather than trusting first/last callback.
local D={};local A;local Geometry=require('placement-geometry')
local function S()
 storage.fabric_direct=storage.fabric_direct or{frames={},pending={},proofs={},objects={},groups={},next=0}
 storage.fabric_direct_refs=storage.fabric_direct_refs or{};return storage.fabric_direct
end
local function position_key(sf,p)return sf..'/'..tostring(p.x==0 and 0 or p.x)..'/'..tostring(p.y==0 and 0 or p.y)end
local function group(player,tick,serial,sf,pos,item)return player..'/'..tick..'/'..tostring(serial)..'/'..position_key(sf,pos)..'/'..item end
local function known(row)return row and type(row.id)=='string'and row.id:sub(1,1)=='F'end
function D.init(api)A=api end
function D.pre(e)
 local p=game.get_player(e.player_index);local c=p and p.cursor_stack
 if not(c and c.valid_for_read and(c.prototype.place_result or c.prototype.type=='rail-planner'))then return end
 local s=S();s.frames[p.index]=s.frames[p.index]or{};local f=s.frames[p.index][game.tick]
 if not f then f={positions={}};s.frames[p.index][game.tick]=f end
 local input=A.input(p.index);local v={tick=game.tick,surface=p.surface.index,position={x=e.position.x,y=e.position.y},item=c.name,quality=c.quality.name,item_number=c.item_number,direction=e.direction or 0,mode=e.build_mode,moving=e.created_by_moving or false,epoch=A.epoch(p.index)}
 if input then v.input={serial=input.serial,tick=input.tick,tool=input.tool,kind=input.kind,epoch=input.epoch,item_number=input.item_number,cursor=input.cursor and{x=input.cursor.x,y=input.cursor.y}}end
 local key=position_key(v.surface,v.position);local list=f.positions[key]or{};f.positions[key]=list;list[#list+1]=v
end
local function expected(proto,v)
 local input=v.input;if not input or not input.cursor then return end
 if proto.has_flag('placeable-off-grid')then return input.cursor end
 local w,h=proto.tile_width,proto.tile_height;if not(w and h and w>0 and h>0)then return end
 local model={entities={{entity_number=1,name=proto.name,position={x=(w%2)/2,y=(h%2)/2},direction=0}},tiles={}}
 local projection=Geometry.project(model,{position=input.cursor,direction=v.direction})
 return projection.supported and projection.entities['1'].position or nil
end
local function native(v,en)
 local input=v.input;local modes={build=0,['build-ghost']=1,['super-forced-build']=2}
 if not(input and input.tool==v.item and modes[input.kind]==v.mode and input.tick<=v.tick)then return false end
 -- Moving callbacks are engine-generated while holding the native build tool;
 -- build_from_cursor has no created_by_moving parameter. Nested API pre-builds
 -- still count as competing samples, even when their own input is unverified.
 if not v.moving and(v.tick~=input.tick or input.epoch~=v.epoch)then return false end
 if v.moving then return true end
 local pos=expected(en.prototype,v)
 return pos and math.abs(pos.x-v.position.x)<=1/256 and math.abs(pos.y-v.position.y)<=1/256 or false
end
local function matching(rec,en)
 local f=S().frames[rec.player]and S().frames[rec.player][rec.tick]
 local list=f and f.positions[position_key(rec.surface,rec.position or en.position)]or{}
 local found={}
 for _,v in ipairs(list)do if v.item==rec.item and v.quality==rec.quality and(v.input and v.input.serial or nil)==rec.serial then found[#found+1]=v end end
 return found
end
local function consumes(e)
 if not(e.consumed_items and #e.consumed_items>0)then return end
 local names={};for _,v in pairs(e.entity.prototype.items_to_place_this or{})do names[v.name]=true end
 local item=e.consumed_items[1]
 if not(item.valid_for_read and names[item.name]and item.quality.name==e.entity.quality.name)then return end
 return item.name,item.quality.name
end
function D.built(e)
 local en=e.entity
 if not(en and en.valid and en.type~='entity-ghost'and not e.tags and A.eligible(en))then return false end
 local item,quality=consumes(e);if not item then return false end
 local s=S();local k=tostring(en.unit_number)
 if storage.fabric_direct_refs[k]~=en and(s.pending[k]or s.proofs[k])then s.pending[k]=nil;s.proofs[k]=nil end
 if s.pending[k]then return true end
 A.register(en,'direct-pending');local row=A.row(en);if not row then return false end
 if known(row)then return true end
 local input=A.input(e.player_index)
 local rec={unit=en.unit_number,player=e.player_index,tick=game.tick,item=item,quality=quality,serial=input and input.serial,surface=en.surface.index,name=en.name,position={x=en.position.x,y=en.position.y}}
 local key=group(rec.player,rec.tick,rec.serial,en.surface.index,en.position,item);rec.group=key;s.groups[key]=s.groups[key]or{};s.groups[key][k]=true
 local list=matching(rec,en);local frame
 if #list==1 and native(list[1],en)then frame={tick=game.tick,name=en.name,item_number=list[1].item_number,position={x=en.position.x,y=en.position.y}}end
 rec.mined=A.mined and A.mined{entity=en,player_index=e.player_index,consumed_items=e.consumed_items,fabric_direct_frame=frame}or false
 if not rec.mined then row.operation='direct placement pending native input/receipt checks'end
 s.proofs[k]=nil;s.pending[k]=rec;storage.fabric_direct_refs[k]=en;s.objects[tostring(script.register_on_object_destroyed(en))]=k
 return true
end
function D.pending_birth(en)local rec=S().pending[tostring(en.unit_number)];if rec and storage.fabric_direct_refs[tostring(en.unit_number)]==en then return rec.tick end end
function D.ready(unit,tick)
 local s=S();local k=tostring(unit);local proof=s.proofs[k];local en=storage.fabric_direct_refs[k]
 return proof and proof.tick==tick and proof.verified and en and en.valid or false
end
function D.fresh_birth(unit,tick)
 local proof=S().proofs[tostring(unit)]
 if proof and proof.tick==tick then return proof.verified and proof.fresh_introduction or false end
end
function D.tick()
 local s=S()
 for k,rec in pairs(s.pending)do if rec.tick<game.tick then
  local en=storage.fabric_direct_refs[k];local row=en and en.valid and A.row(en)
  if not row and not rec.position then s.pending[k]=nil;s.proofs[k]=nil
  else
   if not rec.checked then
    local basis=en and en.valid and en or{prototype=prototypes.entity[rec.name]};local list=matching(rec,basis);local bodies=0;for _ in pairs(s.groups[rec.group]or{})do bodies=bodies+1 end
    rec.verified=#list==1 and bodies==1 and native(list[1],basis)or false;rec.checked=true
    rec.reason=rec.verified and'unique observed native direct input/pre-build/material receipt'or'direct birth lacks unique native input/pre-build receipt; API/competing operation unresolved'
    s.proofs[k]={tick=rec.tick,verified=rec.verified,reason=rec.reason,sample_count=#list,body_count=bodies,input_serial=rec.serial,fresh_introduction=not rec.mined,orphan_expires=not row and game.tick+2 or nil}
   end
   if not row then s.pending[k]=nil
   elseif not rec.verified then if not known(row)then row.operation=rec.reason;if row.reason=='direct-pending'then row.reason='direct-unresolved'end end;s.pending[k]=nil
   elseif not A.eligible(en)then rec.scope_wait=true
   else
    if not rec.mined and not known(row)and row.reason=='direct-pending'then row.id=A.alloc('F');row.reason='direct';row.operation='direct input '..tostring(rec.serial)..': verified fresh placement' end
    s.pending[k]=nil
   end
  end
 end end
 for k,proof in pairs(s.proofs)do if proof.orphan_expires and game.tick>proof.orphan_expires then s.proofs[k]=nil end end
 for player,ticks in pairs(s.frames)do for tick in pairs(ticks)do if tick<game.tick then ticks[tick]=nil end end;if not next(ticks)then s.frames[player]=nil end end
 -- Group keys include their tick; only outstanding unchecked receipts need them.
 local keep={};for _,rec in pairs(s.pending)do if not rec.checked then keep[rec.group]=true end end
 for key in pairs(s.groups)do if not keep[key]then s.groups[key]=nil end end
end
function D.destroyed(e)
 local s=S();local key=s.objects[tostring(e.registration_number)];if not key then return end;s.objects[tostring(e.registration_number)]=nil
 local current=storage.fabric_direct_refs[key];if current and current.valid then return end
 if not s.pending[key]then s.proofs[key]=nil end;storage.fabric_direct_refs[key]=nil
end
function D.snapshot()return S()end
return D
