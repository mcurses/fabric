-- Geometric snapshot comparison; no persistent entity identity.
local S=require('__fabric-ui-playground__/snapshots')
local M={}
local function stable(v)
  if type(v)~='table' then return tostring(v) end
  local keys={};for k in pairs(v) do keys[#keys+1]=k end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
  local out={};for _,k in ipairs(keys) do out[#out+1]=tostring(k)..'='..stable(v[k]) end
  return '{'..table.concat(out,',')..'}'
end
function M.key(e) return e.position.x..','..e.position.y end
function M.signature(entity,position)
  local e=S.copy(entity);e.entity_number=nil
  if not position then e.position=nil end
  if e.tags then e.tags['@i']=nil;e.tags['@e']=nil end
  if e.direction==0 then e.direction=nil end
  if e.control_behavior and e.control_behavior.circuit_set_filters then e.filters=nil end
  if e.name=='ghost-scanner-ia' or e.name=='cybersyn2-combinator' then e.control_behavior=nil end
  return stable(e)
end
function M.compare(before,after)
  local changes,removed,added={}, {}, {}
  local used={};local index={}
  for i,b in ipairs(after.entities or {}) do
    local key=b.name..'@'..M.key(b)..':'..(b.direction or 0);index[key]=index[key] or {};table.insert(index[key],i)
  end
  for _,a in ipairs(before.entities or {}) do
    local found
    local candidates=index[a.name..'@'..M.key(a)..':'..(a.direction or 0)]
    if candidates then found=table.remove(candidates) end
    if found then
      used[found]=true;local b=after.entities[found]
      if M.signature(a)~=M.signature(b) then changes[#changes+1]={kind='Changed',before=a,after=b} end
    else removed[#removed+1]=a end
  end
  for i,b in ipairs(after.entities or {}) do if not used[i] then added[#added+1]=b end end
  for _,a in ipairs(removed) do
    local match,kind
    for i,b in ipairs(added) do if M.key(a)==M.key(b) then match=i;kind=a.name==b.name and 'Changed' or 'Replaced';break end end
    -- Only infer movement when the same settings occur once on each side.
    if not match then
      local n=0
      for i,b in ipairs(added) do if M.signature(a)==M.signature(b) then match=i;n=n+1 end end
      local old=0;for _,b in ipairs(removed) do if M.signature(a)==M.signature(b) then old=old+1 end end
      if n~=1 or old~=1 then match=nil else kind='Moved' end
    end
    if match then changes[#changes+1]={kind=kind,before=a,after=table.remove(added,match)}
    else changes[#changes+1]={kind='Deleted',before=a} end
  end
  for _,b in ipairs(added) do changes[#changes+1]={kind='Added',after=b} end
  local tiles={};for _,t in ipairs(before.tiles or {}) do tiles[M.key(t)]=t end
  for _,t in ipairs(after.tiles or {}) do
    local old=tiles[M.key(t)];tiles[M.key(t)]=nil
    if not old or old.name~=t.name then changes[#changes+1]={kind='Tile',before=old,after=t,tile=true} end
  end
  for _,t in pairs(tiles) do changes[#changes+1]={kind='Tile',before=t,tile=true} end
  table.sort(changes,function(a,b)
    local ap=(a.after or a.before).position;local bp=(b.after or b.before).position
    return ap.y==bp.y and ap.x<bp.x or ap.y<bp.y
  end)
  return changes
end
function M.apply(snapshot,changes,reverse)
  local result=S.copy(snapshot);result.entities=result.entities or {};result.tiles=result.tiles or {}
  local next_id=0;for _,e in ipairs(result.entities) do next_id=math.max(next_id,e.entity_number) end
  for _,c in ipairs(changes) do
    local before,after=c.before,c.after;if reverse then before,after=after,before end
    local list=c.tile and result.tiles or result.entities
    local id
    if before then
      for i=#list,1,-1 do if M.key(list[i])==M.key(before) and list[i].name==before.name then id=list[i].entity_number;table.remove(list,i) end end
    end
    if after then
      local e=S.copy(after)
      if not c.tile then next_id=next_id+1;e.entity_number=id or next_id end
      list[#list+1]=e
    end
  end
  local ids={};for _,e in ipairs(result.entities) do ids[e.entity_number]=true end
  local wires={};for _,w in ipairs(result.wires or {}) do if ids[w[1]] and ids[w[3]] then wires[#wires+1]=w end end
  result.wires=wires;return result
end
return M
