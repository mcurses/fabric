-- Blueprint extraction omits contextually marked entities. Only positive engine
-- mapping is prototype-domain evidence; a negative live sample is never cached.
local Area=require('blueprint-area');local M={};local reports={};local contextual={};local seeded=false
local function domain()
 storage.fabric_blueprint_domain=storage.fabric_blueprint_domain or {positive={}}
 local d=storage.fabric_blueprint_domain
 if not seeded then
  seeded=true
  -- Earlier engine settings exports also prove that this prototype mapped. These
  -- plain settings are migration evidence, never evidence of entity lineage.
  for _,sc in pairs(storage.playground and storage.playground.surfaces or{})do
   for _,b in pairs(sc.baseline or{})do if b.settings and b.settings.name==b.name then d.positive[b.name]={proof='prior exact engine settings mapping'}end end
   for _,c in pairs(sc.settings_cache or{})do if c.data and c.data.name then d.positive[c.data.name]={proof='prior exact engine settings mapping'}end end
  end
 end
 return d
end
local function tracked(e)
 local s=storage.playground;if not s then return false end
 local sc=s.surfaces[tostring(e.surface.index)]
 return (s.global_units and s.global_units[tostring(e.unit_number)]or sc and sc.units[tostring(e.unit_number)])~=nil
end
function M.contextual(e)return contextual[e.unit_number]or false end
function M.test(e)
 if not(e and e.valid and e.unit_number)or e.force.name~='player'then return false end
 local proto=e.type=='entity-ghost'and e.ghost_prototype or e.prototype
 if not proto or proto.has_flag('not-blueprintable')or next(proto.items_to_place_this or{})==nil then return false end
 -- Runtime blueprint-domain probes establish these mobile entity types are not
 -- blueprint entities even though their items have place_result metadata.
 if proto.type=='construction-robot'or proto.type=='logistic-robot'then return false end
 local d=domain();local key=e.type..':'..proto.name
 if d.positive[proto.name]then contextual[e.unit_number]=nil;return true end
 if e.to_be_deconstructed()then
  local keep=tracked(e);contextual[e.unit_number]=keep or nil
  reports[key]={included=keep,contextually_deferred=true,unit=e.unit_number,tick=game.tick,reason=keep and 'known runtime row retained; blueprint domain not yet proved'or 'marked first sample cannot classify prototype; deferred until positive evidence'}
  return keep
 end
 local inv=game.create_inventory(1);inv[1].set_stack{name='blueprint'}
 local ok,mapped=pcall(function()
  local map=inv[1].create_blueprint{surface=e.surface,force=e.force,area=Area(e),include_station_names=true,include_trains=true}
  for _,actual in pairs(map or{})do if actual==e then return true end end
  return false
 end)
 inv.destroy()
 if ok and mapped then d.positive[proto.name]={proof='exact unmarked engine mapping',unit=e.unit_number,surface=e.surface.index,tick=game.tick};contextual[e.unit_number]=nil
 else contextual[e.unit_number]=tracked(e)or nil end
 reports[key]={included=ok and mapped or tracked(e),engine_probe_ok=ok,contextually_deferred=not(ok and mapped),unit=e.unit_number,surface=e.surface.index,tick=game.tick,reason=ok and 'exact create_blueprint entity mapping; negative is contextual only'or tostring(mapped)}
 return ok and mapped or tracked(e)
end
function M.report()return {samples=reports,positive=domain().positive}end
return M
