-- Amortized bounded diagnostics. Never prune authoritative identity receipts.
local T={}
function T.push(state,field,value,limit,dropped)
 local list=state[field];list[#list+1]=value
 if #list>limit then
  local trim=math.max(1,math.floor(limit/8));local keep=#list-trim
  for i=1,keep do list[i]=list[i+trim]end
  for i=keep+1,#list do list[i]=nil end
  state[dropped]=(state[dropped]or 0)+trim
 end
end
return T
