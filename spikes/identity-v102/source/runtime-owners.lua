-- Exact runtime continuity index. Never discover identities from geometry/prototype.
-- Registry rows are authoritative mutable records; unit lookups include all forces
-- and surfaces without repeatedly enumerating unrelated world entities.
-- LuaEntity refs are runtime ledger data, never committed snapshot values.
-- Do not replace this with get_entity_by_unit_number: its prototype flag is optional.
local O={};local registry;local references
function O.init(get_registry,get_references)registry=get_registry;references=assert(get_references)end
local function live(key)
 local e=(references()or{})[tostring(key)]
 return e and e.valid and e.unit_number==tonumber(key)and e.type~='entity-ghost'and e or nil
end
function O.find(id,except)
 for key,row in pairs(registry())do if row.id==id then local e=live(key)
  if e and e.unit_number~=except then return e end
 end end
end
function O.live_ids()
 local out,ambiguous={},{}
 for key,row in pairs(registry())do if type(row.id)=='string'and row.id:sub(1,1)=='F'then local e=live(key)
  if e then if out[row.id]and out[row.id]~=e.unit_number then ambiguous[row.id]=true end;out[row.id]=e.unit_number end
 end end
 -- Invalid duplicate states are not proof of a unique restoration for retirement.
 for id in pairs(ambiguous)do out[id]=nil end
 return out
end
return O
