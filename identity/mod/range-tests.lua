-- Actual engine objects + production snapshot/diff functions. NOT native player tests.
local R={};local A
function R.init(api)A=api end
local protos={'transport-belt','underground-belt','splitter','inserter','long-handed-inserter','bulk-inserter','wooden-chest','steel-chest','requester-chest','constant-combinator','arithmetic-combinator','decider-combinator','selector-combinator','assembling-machine-2','electric-furnace','lab','small-electric-pole','substation','pipe','pipe-to-ground','storage-tank','pump','offshore-pump','boiler','steam-engine','solar-panel','accumulator','radar','stone-wall','gate','gun-turret','roboport','train-stop','rail-signal','straight-rail','cargo-wagon','locomotive'}
function R.run(names)
 local protos=names or protos
 local out={kind='scriptedengine',tick=game.tick,scenarios={},assertions=0,failures=0}
 local sf=game.create_surface('coverage-range-'..game.tick,{width=512,height=256});sf.request_to_generate_chunks({0,0},2);sf.force_generate_chunk_requests()
 for _,e in pairs(sf.find_entities())do e.destroy()end
 local tiles={};for x=-64,64 do for y=-64,64 do tiles[#tiles+1]={name='refined-concrete',position={x,y}}end end;sf.set_tiles(tiles)
 A.initialize(sf)
 for n,name in ipairs(protos)do
  local pos={x=((n-1)%8)*16-56,y=math.floor((n-1)/8)*16-32}
  local function scenario(suffix,expect,fn)
   local c={case_id='E-'..name..'-'..suffix,expected_logical_identity=expect,provenance_level='scriptedengine',assertions={}}
   out.scenarios[#out.scenarios+1]=c
   local function check(label,want,got)c.assertions[#c.assertions+1]={name=label,expected=want,actual=got,pass=want==got};out.assertions=out.assertions+1;if want~=got then out.failures=out.failures+1 end end
   local ok,err=pcall(fn,check);c.outcome=ok and 'PASS'or 'FAIL';if not ok then c.reason=tostring(err);out.failures=out.failures+1 end
   for _,a in pairs(c.assertions)do if not a.pass then c.outcome='FAIL'end end
  end
  local s=A.scope(sf);local function d()return A.diff(s,A.snapshot(sf,true))end
  local helperrails={}
  if prototypes.entity[name] and prototypes.entity[name].type:find('wagon')or name=='locomotive'then for y=pos.y-8,pos.y+8,2 do local rail=sf.create_entity{name='straight-rail',position={pos.x,y},direction=defines.direction.north,force='player'};if rail then helperrails[#helperrails+1]=rail;A.register(rail,'direct')end end;A.commit(sf)end
  local ok,e=pcall(function()return sf.create_entity{name=name,position=pos,force='player',direction=defines.direction.north}end)
  if not ok or not e or not A.eligible(e)then
   for _,suffix in ipairs({'add','live-change','remove','recreate','accept'})do out.scenarios[#out.scenarios+1]={case_id='E-'..name..'-'..suffix,outcome='ENGINE_LIMIT',reason=not ok and tostring(e)or not e and 'fixture could not create prototype (rail/water constraints require specialized setup)'or 'prototype outside buildable entity-with-unit scope',provenance_level='scriptedengine'}end
   if ok and e then e.destroy()end
  else
   local id,unit=e.unit_number
   scenario('add','fresh explicit fixture ID Added',function(check)
    A.register(e,'direct');unit=e.unit_number;id=s.units[tostring(unit)].id;check('Added count',1,#d().Added);check('new ID F prefix',true,id:sub(1,1)=='F');check('no unresolved',false,d().blocked);A.commit(sf)
   end)
   scenario('live-change','same-runtime identity retained through changes',function(check)
    local old=e.direction;local ok=pcall(function()e.direction=defines.direction.east end)
    if ok and e.direction~=old then check('direction Changed',1,#d().Changed);A.commit(sf)end
    local moved=e.teleport({x=pos.x+4,y=pos.y});if not moved then check('engine rejected teleport without changing ID',id,s.units[tostring(e.unit_number)].id)end
    if moved then check('Moved count',1,#d().Moved);check('same ID',id,s.units[tostring(e.unit_number)].id);A.commit(sf)end
    if e.type=='container' or e.type=='logistic-container'then e.get_inventory(defines.inventory.chest).insert{name='iron-plate',count=7};check('inventory excluded by declared scope',0,#d().Changed)end
   end)
   local last={x=e.position.x,y=e.position.y}
   scenario('remove','Removed without inferred lineage',function(check)e.destroy{raise_destroy=true};check('Removed count',1,#d().Removed);A.commit(sf)end)
   local replacement
   scenario('recreate','same endpoint unproven replacement unresolved',function(check)
    replacement=sf.create_entity{name=name,position=last,force='player',raise_built=true};assert(replacement,'replacement creation failed');check('new runtime differs',true,replacement.unit_number~=unit);check('explicit unresolved',true,d().blocked);local rev=s.revision;A.commit(sf);check('blocked revision unchanged',rev,s.revision);check('old ID not stolen',true,s.units[tostring(replacement.unit_number)].id~=id)
   end)
   scenario('accept','explicit new ID only after acceptance',function(check)
    A.accept(sf,1);local row=s.units[tostring(replacement.unit_number)];check('fresh accepted ID',true,row.id~=id and row.id:sub(1,1)=='F');check('resolved after explicit acceptance',false,d().blocked);check('nochange commit',0,#A.commit(sf).Added);replacement.destroy{raise_destroy=true};A.commit(sf)
   end)
  end
  for _,rail in pairs(helperrails)do if rail.valid then rail.destroy{raise_destroy=true}end end;A.commit(sf)
 end
 out.surface=sf.name;return out
end
return R
