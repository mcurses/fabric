-- Engine-contained death revival only. A new object must have the exact original
-- engine UID advertised by the exact on_post_entity_died ghost. No position or
-- blueprint tag can mint this proof. Runtime refs never enter snapshot/log data.
local D={};local A
local function S()
 storage.fabric_death=storage.fabric_death or{next=0,records={},by_unit={},tick_pending={},completed={},trace={},status='Death ghosts: exact engine-contained UID proof only.'}
 storage.fabric_death_refs=storage.fabric_death_refs or{};storage.fabric_death.denied_units=storage.fabric_death.denied_units or{};storage.fabric_death.ghost_objects=storage.fabric_death.ghost_objects or{};storage.fabric_death.reconcile_units=storage.fabric_death.reconcile_units or{};return storage.fabric_death
end
local function log(kind,data)local s=S();s.trace[#s.trace+1]={tick=game.tick,kind=kind,data=data};if #s.trace>512 then table.remove(s.trace,1);s.dropped=(s.dropped or 0)+1 end end
local function known(row)return row and type(row.id)=='string'and row.id:sub(1,1)=='F'end
local function finish(r,state,why)
 local s=S();if state=='invalid'or state=='ambiguous'then s.denied_units[tostring(r.source_unit)]={id=r.logical_id,receipt=r.key,reason=why}end;r.state=state;r.result_tick=game.tick;r.reason=why;s.tick_pending[r.key]=nil;s.status='Death '..r.logical_id..': '..state..'. '..why
 if s.by_unit[tostring(r.source_unit)]==r.key then s.by_unit[tostring(r.source_unit)]=nil end
 if r.ghost_registration then s.ghost_objects[tostring(r.ghost_registration)]=nil end;s.reconcile_units[tostring(r.source_unit)]=nil
 storage.fabric_death_refs[r.key]=nil
 if not r.finished then r.finished=true;s.completed[#s.completed+1]=r.key end
 while #s.completed>256 do local key=table.remove(s.completed,1);local old=s.records[key];if old and old.finished then s.records[key]=nil end end
 log(state,{receipt=r.key,id=r.logical_id,source=r.source_unit,ghost=r.ghost_unit,reason=why})
end
local function create(id,unit)
 local s=S();s.next=s.next+1;local key=tostring(s.next);local r={key=key,logical_id=id,source_unit=unit,tick=game.tick,state='awaiting-engine-ghost'}
 s.records[key]=r;s.by_unit[tostring(unit)]=key;s.denied_units[tostring(unit)]=nil;storage.fabric_death_refs[key]={};return r,storage.fabric_death_refs[key]
end
local function candidate(r,ghost)
 if not A.eligible(ghost)then return end
 A.register(ghost,'death-ghost-pending');local row=A.row(ghost)
 if row and not known(row)then row.identity_candidates={r.logical_id};row.identity_candidate_count=1;row.operation='death '..r.key..': exact contained engine unit '..r.source_unit..' pending'end
end
local function conflict(r)
 if A.history_conflicts(r.logical_id,r.ghost_unit)then
  A.history_ambiguous(r.logical_id,'competing exact native-history and engine-death ghost continuations')
  finish(r,'ambiguous','competing native history restoration; neither ghost chosen');S().status='Death/history continuation ambiguous; no logical ID selected.';return true
 end
end
local function claim(r,en)
 local refs=storage.fabric_death_refs[r.key];if not(refs and en and en.valid and en.type~='entity-ghost'and en.unit_number==r.source_unit and r.post_verified)then return end
 refs.entity=en;S().tick_pending[r.key]=true
 if not A.eligible(en)then r.scope_wait=true;return end
 A.register(en,'death-revival-pending');local row=A.row(en);if not row then return end
 if known(row)and row.id~=r.logical_id then finish(r,'invalid','destination already accepted or assigned a different ID');return end
 if not known(row)then row.identity_candidates={r.logical_id};row.identity_candidate_count=1;row.operation='death '..r.key..': original engine unit pending causal checks'end
 if refs.source and refs.source.valid then return end
 r.source_closed=true
 if refs.ghost and refs.ghost.valid then return end
 if A.history_inflight and A.history_inflight(r.logical_id)then r.history_input_wait=true;return end
 r.history_input_wait=nil
 if conflict(r)then return end
 local owner=A.owner(r.logical_id,en.unit_number)
 if owner then finish(r,'ambiguous','logical ID already continued on another live unit '..owner.unit_number);return end
 row.id=r.logical_id;row.reason=r.manual_accept and'accepted-new'or'death-restored';row.operation='death '..r.key..': engine-contained unit '..r.source_unit
 row.identity_candidates=nil;row.identity_candidate_count=nil;r.destination=en.unit_number;r.destination_registration=row.object_registration
 finish(r,'restored','exact engine-contained UID revived, no geometry/tag inference')
 S().status='Death revived '..r.logical_id..' via exact engine unit '..en.unit_number..'.'
 A.on_claim(r.logical_id,en,r.manual_accept)
end
function D.init(api)A=api end
function D.died(event)
 local en=event.entity;if not(en and en.valid and en.unit_number and en.type~='entity-ghost')then return end
 local s=S();local unit=en.unit_number;local prior=s.records[s.by_unit[tostring(unit)]or''];local prior_refs=prior and storage.fabric_death_refs[prior.key]
 local row=A.row(en);local id
 if known(row)and A.reference(unit)==en and row.object_registration==script.register_on_object_destroyed(en)then id=row.id
 elseif prior and prior.post_verified and prior_refs and prior_refs.entity==en then id=prior.logical_id end
 if prior then finish(prior,'invalid','engine-contained entity died again before pending revival completed')end
 if not id then return end
 local r,refs=create(id,unit);refs.source=en;r.source_registration=script.register_on_object_destroyed(en);r.name=en.name;r.surface=en.surface.index
 log('source-died',{receipt=r.key,id=id,unit=unit,registration=r.source_registration})
end
function D.post(event)
 local s=S();local r=s.records[s.by_unit[tostring(event.unit_number)]or''];if not(r and r.state=='awaiting-engine-ghost')then return end
 local ghost=event.ghost
 if not(ghost and ghost.valid and ghost.type=='entity-ghost'and ghost.ghost_unit_number==r.source_unit)then finish(r,'no-ghost','engine did not expose an exact contained-source ghost');return end
 local refs=storage.fabric_death_refs[r.key];refs.ghost=ghost;r.ghost_unit=ghost.unit_number;r.ghost_registration=script.register_on_object_destroyed(ghost);s.ghost_objects[tostring(r.ghost_registration)]=r.key;r.post_verified=true;r.post_tick=game.tick;r.state='pending'
 candidate(r,ghost);A.invalidate_cut(r.logical_id,'source died into an engine-contained ghost; no cut robot-removal proof')
 if conflict(r)then return end
 S().status='Death ghost '..r.logical_id..': pending original engine unit '..r.source_unit..'.'
 log('exact-engine-ghost',{receipt=r.key,id=r.logical_id,source=r.source_unit,ghost=r.ghost_unit,contained=ghost.ghost_unit_number})
end
function D.history_reserved(id,target)
 local s=S();local pending={};local different=false
 for _,key in pairs(s.by_unit)do local r=s.records[key];if r and r.logical_id==id and r.post_verified then
  pending[#pending+1]=r;local refs=storage.fabric_death_refs[key];local same
  if target.type=='entity-ghost'then same=target.ghost_unit_number==r.source_unit and(refs.ghost==target or not(refs.ghost and refs.ghost.valid))
  else same=target.unit_number==r.source_unit end
  if not same then different=true end
 end end
 if not different then return true end
 for _,r in ipairs(pending)do finish(r,'ambiguous','native history created a different continuation while exact death ghost remains')end
 A.history_ambiguous(id,'competing native history and engine-contained death continuations')
 if A.eligible(target)then A.register(target,'history-death-ambiguous');local row=A.row(target);if row and not known(row)then row.identity_candidates={id};row.identity_candidate_count=1;row.operation='native history/death conflict: no logical ID selected'end end
 S().status='History/death continuations ambiguous; neither piece selected.';return false
end
function D.ghost_source(ghost)
 if not(ghost and ghost.valid and ghost.type=='entity-ghost')then return end
 local s=S();for _,key in pairs(s.by_unit)do local r=s.records[key];local refs=storage.fabric_death_refs[key]
  if r and r.post_verified and not r.finished and refs and refs.ghost==ghost and r.ghost_unit==ghost.unit_number then
   return {kind='engine-death-ghost',receipt=r.key,id=r.logical_id,source_unit=r.source_unit,ghost_unit=r.ghost_unit}
  end
 end
end
function D.delegate_ghost(ghost,proof,op)
 if type(proof)~='table'or proof.kind~='engine-death-ghost'then return false end
 local current=D.ghost_source(ghost);if not current or current.receipt~=proof.receipt or current.id~=proof.id or current.source_unit~=proof.source_unit or current.ghost_unit~=proof.ghost_unit then return false end
 local r=S().records[current.receipt];r.delegated_op=op
 S().denied_units[tostring(r.source_unit)]={id=r.logical_id,receipt=r.key,reason='authority handed to verified native ghost cut '..op}
 finish(r,'delegated-native-cut','exact selected death ghost removed by verified native cut '..op);return true
end
function D.observed(en)
 if not(en and en.valid and en.unit_number and en.type~='entity-ghost')then return false end
 local s=S();local r=s.records[s.by_unit[tostring(en.unit_number)]or'']
 if not(r and r.post_verified and not r.finished)then
  local denied=s.denied_units[tostring(en.unit_number)]
  if denied and A.eligible(en)then A.register(en,'death-lineage-unresolved');local row=A.row(en);if row and not known(row)then row.identity_candidates={denied.id};row.identity_candidate_count=1;row.operation='death continuation unresolved: '..denied.reason;return true end end
  return false
 end
 claim(r,en);return true
end
-- Ghost removal without a build event can also be an unraised engine revive.
-- One queued actual-world search distinguishes that exact original UID from
-- cancellation; no get-by-unit-number availability assumption or endpoint match.
function D.destroyed(event)
 local s=S();local key=s.ghost_objects[tostring(event.registration_number)];if not key then return end;s.ghost_objects[tostring(event.registration_number)]=nil
 local r=s.records[key];if r and not r.finished then s.reconcile_units[tostring(r.source_unit)]=key end
end
local function reconcile()
 local s=S()
 if not s.reconcile_v62 then
  s.reconcile_v62=true
  for _,key in pairs(s.by_unit)do local r=s.records[key];local refs=storage.fabric_death_refs[key]
   if r and r.post_verified and refs and not(refs.ghost and refs.ghost.valid)and not(refs.entity and refs.entity.valid)then s.reconcile_units[tostring(r.source_unit)]=key end
  end
 end
 if not next(s.reconcile_units)then return end
 local queued=s.reconcile_units;s.reconcile_units={};local names={};local seen_names={}
 for _,key in pairs(queued)do local r=s.records[key];if r and r.name and not seen_names[r.name]then names[#names+1]=r.name;seen_names[r.name]=true end end
 local found={}
 if #names>0 then for _,sf in pairs(game.surfaces)do for _,en in pairs(sf.find_entities_filtered{name=names})do if en.valid and en.unit_number and queued[tostring(en.unit_number)]then found[tostring(en.unit_number)]=en end end end end
 for unit,key in pairs(queued)do local r=s.records[key];local refs=storage.fabric_death_refs[key]
  if r and not r.finished and refs and not(refs.ghost and refs.ghost.valid)then
   if found[unit]then D.observed(found[unit])else finish(r,'invalid','exact engine ghost disappeared and no live original-UID entity exists')end
  end
 end
end
function D.tick()
 reconcile()
 local s=S();for key in pairs(s.tick_pending)do local r=s.records[key];local refs=storage.fabric_death_refs[key]
  if r and not r.finished and refs and refs.entity and refs.entity.valid then claim(r,refs.entity)
  elseif r then finish(r,'invalid','observed revived object disappeared before claim')else s.tick_pending[key]=nil end
 end
end
function D.continued(unit,id,why)
 local s=S();local pending={};for _,key in pairs(s.by_unit)do local r=s.records[key];if r and r.logical_id==id then pending[#pending+1]=r end end
 for _,r in ipairs(pending)do finish(r,unit==r.source_unit and'continued-by-other-proof'or'invalid','newer proven continuation: '..tostring(why)..' at unit '..unit)end
end
function D.invalidate_unit(unit,why)
 local s=S();local pending={};for _,key in pairs(s.by_unit)do local r=s.records[key];if r and(r.source_unit==unit or r.ghost_unit==unit)then pending[#pending+1]=r end end
 for _,r in ipairs(pending)do finish(r,'invalid',why)end
 if why=='manual acceptance as fresh ID'then s.denied_units[tostring(unit)]=nil end
end
function D.accept_ghost(ghost,id)
 if not(ghost and ghost.valid and ghost.type=='entity-ghost'and ghost.ghost_unit_number)then return false end
 local uid=ghost.ghost_unit_number;D.invalidate_unit(uid,'manual acceptance as a fresh logical ID')
 local r,refs=create(id,uid);r.manual_accept=true;r.surface=ghost.surface.index;r.state='pending';r.post_verified=true;r.source_closed=true;r.ghost_unit=ghost.unit_number;r.name=ghost.ghost_name;r.ghost_registration=script.register_on_object_destroyed(ghost);S().ghost_objects[tostring(r.ghost_registration)]=r.key;r.post_tick=game.tick;refs.ghost=ghost
 A.on_manual_alias(uid);S().status='Accepted engine death ghost as new '..id..'; original engine unit '..uid..' retained only as revival proof.'
 log('manual-engine-ghost-alias',{receipt=r.key,id=id,source=uid,ghost=ghost.unit_number});return true
end
function D.invalidate_surface(index)
 local s=S();local pending={};for _,key in pairs(s.by_unit)do local r=s.records[key];local refs=r and storage.fabric_death_refs[key];local current=refs and(refs.ghost and refs.ghost.valid and refs.ghost or refs.entity and refs.entity.valid and refs.entity);local surface=current and current.surface.index or r and r.surface;if r and surface==index then pending[#pending+1]=r end end;for _,r in ipairs(pending)do finish(r,'invalid','surface deleted')end
end
function D.snapshot()return S()end
function D.status()return S().status end
return D
