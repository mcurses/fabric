-- Anonymous ordinary inventory items do not carry entity lineage. Retain possible
-- mined sources, never FIFO/LIFO-assign an ID or silently call the item fresh.
local M={};local A
local function S()storage.fabric_mined_items=storage.fabric_mined_items or{sources={}};return storage.fabric_mined_items end
local function known(r)return r and type(r.id)=='string'and r.id:sub(1,1)=='F'end
local function key(name,quality)return name..'/'..quality end
function M.init(api)A=api end
local function candidate_set(ids)
 local st=S();st.candidate_sets=st.candidate_sets or{};st.candidate_lookup=st.candidate_lookup or{}
 local text=table.concat(ids,',');local id=st.candidate_lookup[text]
 if not id then id=#st.candidate_sets+1;st.candidate_sets[id]={ids=ids,count=#ids};st.candidate_lookup[text]=id end
 return id
end
local function source_candidates(row)
 local set=row.fabric_material_candidate_set and S().candidate_sets and S().candidate_sets[row.fabric_material_candidate_set]
 local seen={};local ids={};for _,id in ipairs(set and set.ids or row.identity_candidates or{})do if type(id)=='string'and id:sub(1,1)=='F'and not seen[id]then seen[id]=true;ids[#ids+1]=id end end;table.sort(ids);return ids
end
local function root_set(ids)
 local st=S();st.uncertain_sets=st.uncertain_sets or{};st.uncertain_set_lookup=st.uncertain_set_lookup or{}
 local text=table.concat(ids,',');local id=st.uncertain_set_lookup[text]
 if not id then id=#st.uncertain_sets+1;st.uncertain_sets[id]=ids;st.uncertain_set_lookup[text]=id end;return id
end
local function retain_uncertain(en,row,groups,event)
 if not next(groups)then return end
 local st=S();st.uncertain_sources=st.uncertain_sources or{};st.uncertain_by_item=st.uncertain_by_item or{}
 local inherited=row.fabric_uncertain_set and st.uncertain_sets and st.uncertain_sets[row.fabric_uncertain_set];local roots={}
 for _,id in ipairs(inherited or{})do if st.uncertain_sources[id]then roots[#roots+1]=id end end
 if #roots==0 then
  st.next_uncertain=(st.next_uncertain or 0)+1;local id='material-'..st.next_uncertain
  local ids=source_candidates(row);local pending=A.direct_pending_birth and A.direct_pending_birth(en)
  st.uncertain_sources[id]={id=id,source_label=row.id,source_unit=en.unit_number,source_surface=en.surface.index,tick=game.tick,player=event.player_index,candidate_set=candidate_set(ids),candidate_count=row.identity_candidate_count or #ids,incomplete_candidates=(row.identity_candidate_count or #ids)>#ids,pending_direct_birth=pending,outputs={},mining_events=0};roots[1]=id
  if pending then st.deferred_birth_roots=st.deferred_birth_roots or{};st.deferred_birth_roots[id]=true end
 end
 for _,id in ipairs(roots)do local root=st.uncertain_sources[id];root.mining_events=root.mining_events+1;root.last_mined_tick=game.tick
  local ids={};local seen={};for _,candidate in ipairs(st.candidate_sets[root.candidate_set].ids)do seen[candidate]=true;ids[#ids+1]=candidate end
  for _,candidate in ipairs(source_candidates(row))do if not seen[candidate]then seen[candidate]=true;ids[#ids+1]=candidate end end;table.sort(ids);root.candidate_set=candidate_set(ids);root.candidate_count=math.max(root.candidate_count or 0,row.identity_candidate_count or 0,#ids);root.incomplete_candidates=root.incomplete_candidates or root.candidate_count>#ids
  for k,g in pairs(groups)do
   local output=root.outputs[k]or{numbers={},unnumbered=false};root.outputs[k]=output
   for number in pairs(g.numbers)do output.numbers[number]=true end;output.unnumbered=output.unnumbered or g.unnumbered or false
   st.uncertain_by_item[k]=st.uncertain_by_item[k]or{};st.uncertain_by_item[k][id]=true
  end
 end
end
local function resolve_fresh_births()
 local st=S()
 for id in pairs(st.deferred_birth_roots or{})do
  local root=st.uncertain_sources[id];local result=A.direct_fresh_birth and A.direct_fresh_birth(root.source_unit,root.pending_direct_birth)
  if result~=nil or game.tick>root.tick+3 then
   if result==true and root.candidate_count==0 and not root.incomplete_candidates then root.retired_fresh_birth={tick=game.tick,reason='complete native birth proof establishes genuinely fresh material; no old identity claimed'}end
   st.deferred_birth_roots[id]=nil
  end
 end
end
local function uncertain_material(e)
 local st=S();if not st.uncertain_by_item then return false end
 local roots={};local found={}
 for i=1,#e.consumed_items do local item=e.consumed_items[i]
  if item.valid_for_read then local k=key(item.name,item.quality.name)
   for id in pairs(st.uncertain_by_item[k]or{})do local root=st.uncertain_sources[id];local output=root and root.outputs[k]
    if output and not root.retired_fresh_birth and(output.unnumbered or item.item_number and output.numbers[tostring(item.item_number)])and not found[id]then found[id]=true;roots[#roots+1]=id end
   end
  end
 end
 if #roots==0 then return false end;table.sort(roots)
 A.register(e.entity,'mined-item-unresolved');local row=A.scope(e.entity.surface).units[tostring(e.entity.unit_number)];if not row then return false end
 if known(row)then return true end;row.reason='mined-item-unresolved'
 local ids={};local seen={};local lower=0;local incomplete=false
 for _,id in ipairs(roots)do local root=st.uncertain_sources[id];local set=st.candidate_sets[root.candidate_set];for _,candidate in ipairs(set and set.ids or{})do if not seen[candidate]then seen[candidate]=true;ids[#ids+1]=candidate end end;lower=math.max(lower,root.candidate_count or 0);incomplete=incomplete or root.incomplete_candidates end
 -- Keep compatible authoritative source candidates in the preview too, but
 -- uncertainty in any consumed source prevents choosing one as continuation.
 for i=1,#e.consumed_items do local item=e.consumed_items[i];if item.valid_for_read then
  for id,source in pairs(st.sources[key(item.name,item.quality.name)]or{})do
   if(not item.item_number or source.unnumbered or source.output_numbers and source.output_numbers[tostring(item.item_number)]or not source.output_numbers and(not source.item_number or source.item_number==item.item_number))and not seen[id]then seen[id]=true;ids[#ids+1]=id end
  end
 end end
 table.sort(ids);row.fabric_material_candidate_set=candidate_set(ids);row.fabric_uncertain_set=root_set(roots)
 row.identity_candidates={};for i=1,math.min(#ids,12)do row.identity_candidates[i]=ids[i]end
 row.identity_candidate_count=math.max(#ids,lower);row.identity_candidate_count_lower_bound=incomplete or nil
 row.operation='Material '..row.fabric_uncertain_set..': unresolved mining lineage from '..#roots..' source(s); no ID claimed'
 return true
end

function M.mined(e)
 local en=e.entity;if not A.eligible(en)then return end
 local row=A.scope(en.surface).units[tostring(en.unit_number)];if not row then A.register(en,'mined-source-unresolved');row=A.scope(en.surface).units[tostring(en.unit_number)]end;if not row then return end
 storage.fabric_mined_refs=storage.fabric_mined_refs or{};storage.fabric_mined_refs[en.unit_number]=en
 local place={};for _,v in pairs(en.prototype.items_to_place_this or{})do place[v.name]=true end
 local groups={};local total=0
 for i=1,#e.buffer do local item=e.buffer[i]
  if item.valid_for_read and place[item.name]then
   total=total+item.count;local k=key(item.name,item.quality.name);local g=groups[k]or{name=item.name,quality=item.quality.name,numbers={},slots=0};groups[k]=g;g.slots=g.slots+1
   if item.item_number then g.numbers[tostring(item.item_number)]=true;g.number=item.item_number else g.unnumbered=true end
  end
 end
 if not known(row)then retain_uncertain(en,row,groups,e);return end
 -- One source with multiple matching outputs has no chosen continuation. Save
 -- every observed output serial, never a last-slot-wins authoritative token.
 for k,g in pairs(groups)do local pool=S().sources[k]or{};S().sources[k]=pool
  pool[row.id]={id=row.id,unit=en.unit_number,player=e.player_index,tick=game.tick,surface=en.surface.index,actor=e.robot and'robot'or'player',receipt=tostring(en.unit_number)..'/'..game.tick..'/'..(e.player_index or'robot-'..tostring(e.robot and e.robot.unit_number)),item=g.name,quality=g.quality,item_number=total==1 and g.number or nil,unique_output=total==1 and g.slots==1 and not g.unnumbered,output_count=total,output_numbers=g.numbers,unnumbered=g.unnumbered or false}
 end
end
-- A later proven history incarnation consumes the old material capability.
-- Keep an exact-number tombstone; never convert this uncertainty to fresh by
-- dropping the source pool or waiting until the restored building disappears.
function M.history_claimed(id,unit,action,entity)
 local st=S();st.superseded_numbers=st.superseded_numbers or{}
 for _,pool in pairs(st.sources)do local source=pool[id]
  if source and(source.unit~=unit or(entity and storage.fabric_mined_refs and storage.fabric_mined_refs[source.unit]and storage.fabric_mined_refs[source.unit]~=entity))and source.unique_output==true and source.item_number then
   local number=tostring(source.item_number)
   st.superseded_numbers[number]=st.superseded_numbers[number]or{id=id,source=source.unit,receipt=source.receipt,history_unit=unit,history_action=action,tick=game.tick,reason='later authoritative history restoration'}
   source.superseded_by_history=st.superseded_numbers[number]
  end
 end
end
function M.engine_continued(id,en)
 local st=S();st.superseded_numbers=st.superseded_numbers or{}
 for _,pool in pairs(st.sources)do local source=pool[id]
  if source and source.unique_output==true and source.item_number then
   local old=storage.fabric_mined_refs and storage.fabric_mined_refs[source.unit]
   if source.unit~=en.unit_number or old~=en then
    local number=tostring(source.item_number);st.superseded_numbers[number]=st.superseded_numbers[number]or{id=id,source=source.unit,receipt=source.receipt,claim_unit=en.unit_number,tick=game.tick,reason='later proven engine continuation (death, cut, or upgrade)'}
    source.superseded_by_engine=st.superseded_numbers[number]
   end
  end
 end
end
local function migrate_history_caps()
 local st=S();if st.history_cap_migration_v56 then return end
 st.history_cap_migration_v56={tick=game.tick,marked=0,ambiguous_same_tick=0}
 for _,pool in pairs(st.sources)do for id,source in pairs(pool)do if source.unique_output==true and source.item_number then
  for _,r in pairs(storage.fabric_history and storage.fabric_history.restores or{})do
   if r.logical_id==id and r.state=='restored'and r.unit and r.unit~=source.unit and r.restored_tick and source.tick and r.restored_tick>=source.tick then
    local number=tostring(source.item_number);st.superseded_numbers=st.superseded_numbers or{}
    if not st.superseded_numbers[number]then
     local same=r.restored_tick==source.tick
     st.superseded_numbers[number]={id=id,source=source.unit,receipt=source.receipt,history_unit=r.unit,history_action=r.action,tick=game.tick,reason=same and'legacy same-tick history/material ordering unresolved'or'legacy later authoritative history restoration'}
     source.superseded_by_history=st.superseded_numbers[number]
     st.history_cap_migration_v56[same and'ambiguous_same_tick'or'marked']=st.history_cap_migration_v56[same and'ambiguous_same_tick'or'marked']+1
    end
   end
  end
 end end end
end
function M.built(e)
 if not A.eligible(e.entity) or not e.consumed_items then return false end
 migrate_history_caps();resolve_fresh_births()
 if uncertain_material(e)then return true end
 local superseded={}
 for i=1,#e.consumed_items do local item=e.consumed_items[i];local old=item.valid_for_read and item.item_number and S().superseded_numbers and S().superseded_numbers[tostring(item.item_number)]
  if old then superseded[old.id]=true end
 end
 if next(superseded)then
  A.register(e.entity,'mined-item-unresolved');local row=A.scope(e.entity.surface).units[tostring(e.entity.unit_number)];if not row then return false end
  if known(row)then return true end;row.reason='mined-item-unresolved'
  local ids={};for id in pairs(superseded)do ids[#ids+1]=id end;table.sort(ids);row.identity_candidates=ids;row.identity_candidate_count=#ids;row.operation='unique item receipt superseded by history; identity unresolved, no old ID claimed';return true
 end
 local relevant=false;for i=1,#e.consumed_items do local item=e.consumed_items[i];if item.valid_for_read and S().sources[key(item.name,item.quality.name)]and next(S().sources[key(item.name,item.quality.name)])then relevant=true;break end end
 if not relevant then return false end
 -- A different, already-proven live runtime can retire a restored source.
 -- The original runtime is still valid during its mined callback; it must
 -- never retire its own just-recorded candidate during nested API builds.
 -- No timeout or inventory-order inference is used to retire them.
 local live=A.live_ids and A.live_ids()or{}
 for k,pool in pairs(S().sources)do for id,v in pairs(pool)do if live[id] and live[id]~=v.unit then pool[id]=nil end end;if not next(pool)then S().sources[k]=nil end end
 local candidates={}
 for i=1,#e.consumed_items do local item=e.consumed_items[i]
  if item.valid_for_read then
   for id,v in pairs(S().sources[key(item.name,item.quality.name)]or{})do
    -- Unique item numbers may disqualify a particular source. Their mere
    -- presence is not yet proof of preserved entity data/identity.
    if not item.item_number or v.unnumbered or(v.output_numbers and v.output_numbers[tostring(item.item_number)])or(not v.output_numbers and(not v.item_number or item.item_number==v.item_number))then candidates[id]=true end
   end
  end
 end
 if not next(candidates)then return false end
 A.register(e.entity,'mined-item-unresolved');local row=A.scope(e.entity.surface).units[tostring(e.entity.unit_number)]
 if not row then return false end -- scope may have changed in an earlier callback
 if known(row)then return true end;row.reason='mined-item-unresolved'
 local ids={};for id in pairs(candidates)do ids[#ids+1]=id end;table.sort(ids)
 row.fabric_material_candidate_set=candidate_set(ids);row.identity_candidate_count=#ids;row.identity_candidates={};for i=1,math.min(#ids,12)do row.identity_candidates[i]=ids[i]end
 row.operation='ordinary mined item: source lineage unavailable; candidates retained, no ID assigned'
 local f=e.fabric_direct_frame or(S().frames and S().frames[e.player_index]);local item=e.consumed_items[1]
 if #ids==1 and #e.consumed_items==1 and item.valid_for_read and item.count==1 and item.item_number and f and f.tick==game.tick and f.item_number==item.item_number and f.name==e.entity.name and f.position.x==e.entity.position.x and f.position.y==e.entity.position.y then
  local source=S().sources[key(item.name,item.quality.name)][ids[1]]
  if source.unique_output==true and source.item_number==item.item_number and source.receipt then
   local st=S();st.pending=st.pending or{};local number=tostring(item.item_number);local pending=st.pending[number]or{tick=game.tick,receipts={}};st.pending[number]=pending
   pending.receipts[#pending.receipts+1]={unit=e.entity.unit_number,surface=e.entity.surface.index,source=source,id=source.id,number=number,tick=game.tick}
   storage.fabric_mined_refs=storage.fabric_mined_refs or{};storage.fabric_mined_refs[e.entity.unit_number]=e.entity
   row.operation='unique mined item receipt pending duplicate/source checks'
  end
 end
 return true
end
function M.pre(e)
 local st=S();st.frames=st.frames or{};st.frames[e.player_index]=nil
 local p=game.get_player(e.player_index);local c=p.cursor_stack;local input=A.input and A.input(e.player_index)
 if not(c and c.valid_for_read and c.item_number and c.prototype.place_result and input and input.item_number==c.item_number and input.tool==c.name and input.kind=='build' and game.tick>=input.tick and game.tick-input.tick<=1 and e.build_mode==0 and not e.created_by_moving)then return end
 if not input.cursor or math.abs(input.cursor.x-e.position.x)>1/256 or math.abs(input.cursor.y-e.position.y)>1/256 then return end
 st.frames[e.player_index]={tick=game.tick,item_number=c.item_number,name=c.prototype.place_result.name,position={x=e.position.x,y=e.position.y}}
end
function M.tick()
 migrate_history_caps();resolve_fresh_births()
 local st=S();if not(st.pending and next(st.pending))then return end
 local live;st.consumed=st.consumed or{};st.consumed_sources=st.consumed_sources or{}
 for number,pending in pairs(st.pending)do if pending.tick<game.tick then
  st.pending[number]=nil
  if #pending.receipts==1 then
   local v=pending.receipts[1];local source=v.source;local refs=storage.fabric_mined_refs or{};local en=refs[v.unit]
   local row=en and en.valid and A.scope(en.surface).units[tostring(en.unit_number)]
   local proof=not(st.superseded_numbers and st.superseded_numbers[number])and type(source)=='table'and source.unique_output==true and source.output_count==1 and type(source.output_numbers)=='table'and source.output_numbers[number]and tostring(source.item_number)==number and source.id==v.id
   local pool=proof and st.sources[key(source.item,source.quality)];local authority=pool and pool[source.id]
   proof=proof and authority and authority.receipt==source.receipt and authority.item_number==source.item_number and authority.unique_output==true and authority.output_count==1
   if proof and A.direct_ready then proof=A.direct_ready(v.unit,v.tick)end
   -- Old saves did not retain cardinality. Do not infer it from a last serial;
   -- also reject expired/replaced issuance before retaining any scope wait.
   if proof then
    local old=refs[source.unit]
    if row and row.reason=='mined-item-unresolved'and not A.eligible(en)then pending.scope_wait=true;st.pending[number]=pending
    elseif row and row.reason=='mined-item-unresolved'and not(old and old.valid)and not st.consumed[number]and not st.consumed_sources[source.receipt]then
     if not live then live=A.live_ids()end -- no global scan for scope waits/legacy/invalid receipts
     if not live[v.id]then
      row.id=v.id;row.reason='item-receipt';row.operation='unique consumed mined item '..number;row.identity_candidates=nil;row.identity_candidate_count=nil
      st.consumed[number]={id=v.id,source=source.unit,destination=v.unit,tick=game.tick,receipt=source.receipt};st.consumed_sources[source.receipt]=number;live[v.id]=v.unit
      for _,sources in pairs(st.sources)do for id,candidate in pairs(sources)do if candidate.receipt==source.receipt then sources[id]=nil end end end
      if A.on_transfer then A.on_transfer(source.unit,en,v.id)end
     end
    end
   elseif row and row.reason=='mined-item-unresolved'then row.operation='legacy, superseded, or unverified native item receipt lacks authoritative proof; identity unresolved' end
  end
 end end
end
function M.snapshot()return S()end
return M
