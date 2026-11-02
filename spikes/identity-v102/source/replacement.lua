-- Native direct fast replacement: exact pre-build candidate -> native mined callback
-- -> replacement built callback. Coordinates qualify that observed gesture only.
local R={};local A
local function S()storage.fabric_replace=storage.fabric_replace or {frames={},trace={},seq=0};storage.fabric_replace_refs=storage.fabric_replace_refs or {};return storage.fabric_replace end
local function known(r)return r and r.id:sub(1,1)=='F'and r.reason~='replacement-unresolved'end
local function log(k,d)local s=S();s.seq=s.seq+1;s.trace[#s.trace+1]={seq=s.seq,tick=game.tick,kind=k,data=d};if #s.trace>8192 then table.remove(s.trace,1)end end
local function runtime_row(e)if A.row then return A.row(e)end;return e and e.unit_number and A.scope(e.surface).units[tostring(e.unit_number)]end
function R.init(api)A=api end
function R.pre(e)
 S()
 local p=game.get_player(e.player_index);local c=p.cursor_stack;local input=A.input(p.index)
 if not(c and c.valid_for_read and c.prototype.place_result and input and input.tool==c.name and game.tick-input.tick<=1)then S().frames[p.index]=nil;return end
 local proto=c.prototype.place_result;local group=proto.fast_replaceable_group
 if not group or group==''then return end
 local f={tick=game.tick,player=p.index,name=proto.name,group=group,surface=p.surface.index,candidates={},mined={}}
 for _,en in pairs(p.surface.find_entities_filtered{position=e.position,force=p.force})do
  if A.eligible(en)and en.type~='entity-ghost'and en.prototype.fast_replaceable_group==group then
   local row=A.scope(en.surface).units[tostring(en.unit_number)]
   f.candidates[tostring(en.unit_number)]={unit=en.unit_number,id=known(row)and row.id or nil,name=en.name,position={x=en.position.x,y=en.position.y}}
   storage.fabric_replace_refs[en.unit_number]=en
  end
 end
 S().frames[p.index]=f
end
function R.mined(e)
 local f=S().frames[e.player_index];if not f or f.tick~=game.tick then return end
 local v=f.candidates[tostring(e.entity.unit_number)]
 if v then f.mined[#f.mined+1]=v;log('native-replacement-mined',{player=e.player_index,source=v,target=f.name});return true end
end
function R.built(e)
 local f=S().frames[e.player_index];local en=e.entity
 if not f or f.tick~=game.tick or en.type=='entity-ghost'or en.name~=f.name or en.surface.index~=f.surface or #f.mined==0 then return false end
 local candidates={};for _,v in pairs(f.mined)do if v.position.x==en.position.x and v.position.y==en.position.y then candidates[#candidates+1]=v end end
 if #candidates~=1 then A.register(en,'replacement-unresolved');log('ambiguous-replacement',{unit=en.unit_number,count=#candidates});return true end
 local v=candidates[1];local old=storage.fabric_replace_refs[v.unit]
 A.register(en,'replacement-unresolved')
 if not v.id or(old and old.valid)then log('unproven-replacement',{source=v.unit,destination=en.unit_number});return true end
 if A.owner then local owner=A.owner(v.id,en.unit_number);if owner then log('replacement-id-already-live',{id=v.id,unit=owner.unit_number});return true end
 else
 for _,sf in pairs(game.surfaces)do local sc=A.scope(sf);for _,other in pairs(sf.find_entities())do local row=other.unit_number and runtime_row(other);if other~=en and other.type~='entity-ghost'and row and row.id==v.id then log('replacement-id-already-live',{id=v.id,unit=other.unit_number});return true end end end
 end
 local row=A.scope(en.surface).units[tostring(en.unit_number)];row.id=v.id;row.reason='history-restored';row.operation='native fast replacement '..v.unit
 if A.continued then A.continued(en.unit_number,v.id,'verified native fast replacement')end
 log('native-replacement-transferred',{id=v.id,source=v.unit,destination=en.unit_number,from=v.name,to=en.name});return true
end
-- Robot upgrade: exact robot's mined entity -> built target in one engine tick.
-- This is not generic robot copy/delete inference; get_upgrade_target must identify
-- the planned target on that very source at mining time.
function R.robot_mined(e)
 local s=S();s.robots=s.robots or {};local target,quality=e.entity.get_upgrade_target()
 if not target then s.robots[tostring(e.robot.unit_number)]=nil;return end
 local row=A.scope(e.entity.surface).units[tostring(e.entity.unit_number)]
 local v={tick=game.tick,source=e.entity.unit_number,id=known(row)and row.id or nil,name=target.name,quality=quality.name,surface=e.entity.surface.index,position={x=e.entity.position.x,y=e.entity.position.y},robot=e.robot.unit_number}
 local key=tostring(e.robot.unit_number);local previous=s.robots[key]
 if previous and previous.tick==game.tick then v.ambiguous=true end
 s.robots[key]=v;storage.fabric_replace_refs[v.source]=e.entity;log('upgrade-robot-mined',v)
end
function R.robot_built(e)
 local s=S();local key=tostring(e.robot.unit_number);local v=s.robots and s.robots[key]
 if not v or v.tick~=game.tick then return false end
 s.robots[key]=nil;local en=e.entity
 if v.ambiguous or en.name~=v.name or en.quality.name~=v.quality or en.surface.index~=v.surface or en.position.x~=v.position.x or en.position.y~=v.position.y then log('upgrade-rejected',{source=v.source,destination=en.unit_number,reason='job batch mismatch'});return false end
 A.register(en,'replacement-unresolved');local source=storage.fabric_replace_refs[v.source]
 if not v.id or(source and source.valid)then return true end
 if A.owner then local owner=A.owner(v.id,en.unit_number);if owner then log('upgrade-rejected',{reason='ID already live',id=v.id,unit=owner.unit_number});return true end
 else
 for _,sf in pairs(game.surfaces)do local sc=A.scope(sf);for _,other in pairs(sf.find_entities())do local row=other.unit_number and runtime_row(other);if other~=en and other.type~='entity-ghost'and row and row.id==v.id then log('upgrade-rejected',{reason='ID already live',id=v.id});return true end end end
 end
 local row=A.scope(en.surface).units[tostring(en.unit_number)];row.id=v.id;row.reason='history-restored';row.operation='verified robot upgrade '..v.source
 if A.upgraded then A.upgraded(v.source,en,v.id)end
 log('upgrade-transferred',{id=v.id,source=v.source,destination=en.unit_number,robot=v.robot});return true
end
function R.snapshot()return S()end
return R
