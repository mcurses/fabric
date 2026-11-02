-- Read-only installed Things tag settings. No blueprint extraction or identity token minting.
local M={}
local function clone(value,seen,depth)
 local t=type(value)
 if t=='nil'or t=='string'or t=='boolean'then return value end
 if t=='number'then assert(value==value and value~=math.huge and value~=-math.huge,'nonfinite setting');return value end
 assert(t=='table'and depth<32 and not seen[value],'nonplain mod settings')
 seen[value]=true;local out={}
 for k,v in pairs(value)do assert(type(k)=='string'or type(k)=='number','nonplain setting key');out[k]=clone(v,seen,depth+1)end
 seen[value]=nil;return out
end
function M.attach(data,entity)
 if not(remote.interfaces['things']and remote.interfaces['things'].get_thing_id and remote.interfaces['things-tags-v1']and remote.interfaces['things-tags-v1'].get_tags)then return data end
 local err,id=remote.call('things','get_thing_id',entity);assert(not err,'Things entity lookup unavailable')
 if not id then return data end
 local tagerr,tags=remote.call('things-tags-v1','get_tags',id);assert(not tagerr,'Things tag readout unavailable')
 assert(tags==nil or type(tags)=='table','Things tags are not plain settings')
 local copy=clone(tags or{},{},0)
 -- Only Fabric's own root transport namespaces; foreign/nested settings stay intact.
 for _,k in ipairs({'fabric_playground_cut_v1','fabric_pg_history_v1','fabric_pg_entity_v1'})do copy[k]=nil end
 data.mod_settings={things=copy};return data
end
function M.coverage_gap(old,new)
 local a=old and old.mod_settings;local b=new and new.mod_settings
 return(a~=nil)~=(b~=nil)
end
function M.engine_fields(data)
 if type(data)~='table'then return data end
 local out={};for k,v in pairs(data)do if k~='mod_settings'then out[k]=v end end;return out
end
return M
