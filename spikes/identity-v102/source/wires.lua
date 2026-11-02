-- Read-only connector snapshot. No connector creation, rewiring, or inventory edits.
local W={}
function W.snapshot(en,scope)
 local roles={}
 -- Stable settings role from the mod's explicit parent/child ledger, not a
 -- logical identity assignment to helpers and never name/position matching.
 if remote and remote.interfaces and remote.interfaces.things and remote.interfaces.things.get_thing_id and remote.interfaces.things.get_children then
  local ok,err,id=pcall(remote.call,'things','get_thing_id',en)
  if ok and not err and id then
   local got,child_err,children=pcall(remote.call,'things','get_children',id)
   if got and not child_err then
    local parent=en.unit_number and scope(en.surface).units[tostring(en.unit_number)]
    if parent then for key,c in pairs(children or{})do if type(key)=='string'and c.entity and c.entity.valid and c.entity.unit_number then roles[c.entity.unit_number]='things-child:'..parent.id..':'..#key..':'..key end end end
   else return {unsupported=true}end
  elseif not ok or err then return {unsupported=true}end
 end
 local out={};local ok,connectors=pcall(function()return en.get_wire_connectors(false)end)
 if not ok then return {unsupported=true}end
 for id,connector in pairs(connectors)do for _,connection in pairs(connector.connections)do
  local target=connection.target;local owner=target.owner
  if owner and owner.valid then
   local row=owner.unit_number and scope(owner.surface).units[tostring(owner.unit_number)]
   out[#out+1]={from=id,to=target.wire_connector_id,peer=row and row.id or roles[owner.unit_number]or 'runtime-only:'..tostring(owner.unit_number),peer_surface=owner.surface.index,origin=connection.origin}
  end
 end end
 table.sort(out,function(a,b)if a.from~=b.from then return a.from<b.from elseif a.peer~=b.peer then return a.peer<b.peer elseif a.to~=b.to then return a.to<b.to else return(a.origin or 0)<(b.origin or 0)end end)
 return out
end
function W.coverage_gap(old,new)
 local legacy=false;for _,v in ipairs(old or{})do if type(v.peer)=='string'and v.peer:sub(1,13)=='runtime-only:'then legacy=true end end
 if not legacy then return false end
 for _,v in ipairs(new or{})do if type(v.peer)=='string'and v.peer:sub(1,13)=='things-child:'then return true end end
 return false
end
return W
