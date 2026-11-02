-- Native history correlation. Endpoint coordinates qualify an observed event batch;
-- they are never used to discover or label arbitrary world entities.
local Jobs=require('robot-jobs')
local H={};local A;local TAG='fabric_pg_history_v1';local RECEIPT='fabric_pg_entity_v1'
local function S()
 storage.fabric_history=storage.fabric_history or {next=0,next_restore=0,actions={},restores={},contexts={},frames={},objects={},trace={},seq=0,status='History: observing; unsupported actions remain unresolved.'}
 storage.fabric_history_refs=storage.fabric_history_refs or {};storage.fabric_history_frame_refs=storage.fabric_history_frame_refs or {};return storage.fabric_history
end
local function plain(v,d)
 d=d or 0;if d>15 then return 'depth'end
 local t=type(v);if t=='userdata'then return 'runtime-object-not-retained'end
 if t~='table'then return v end
 local r={}for k,x in pairs(v)do if type(k)=='number' or type(k)=='string'then r[k]=plain(x,d+1)end end;return r
end
local function log(k,d)local s=S();s.seq=s.seq+1;s.trace[#s.trace+1]={seq=s.seq,tick=game.tick,kind=k,data=plain(d)};if #s.trace>8192 then table.remove(s.trace,1);s.dropped_trace=(s.dropped_trace or 0)+1 end end
local function ref(e)
 if not(e and e.valid and e.unit_number)then return end
 storage.fabric_history_refs[e.unit_number]=e;S().objects[tostring(script.register_on_object_destroyed(e))]=e.unit_number
end
local function get(unit)local e=unit and storage.fabric_history_refs[unit];return e and e.valid and e or nil end
local function info(e)return {unit=e.unit_number,name=e.type=='entity-ghost'and e.ghost_name or e.name,surface=e.surface.index,position={x=e.position.x,y=e.position.y},event_tick=game.tick,ghost=e.type=='entity-ghost',quality=e.quality and e.quality.name or 'normal'}end
local function known(r)return r and (r.reason=='direct' or r.reason=='initial' or r.reason=='accepted-new' or r.reason=='clipboard-copy' or r.reason=='engine-clone-copy' or r.reason=='cut-transfer' or r.reason=='item-receipt' or r.reason=='history-restored'or r.reason=='death-restored')end
local function runtime_row(e)if A.row then return A.row(e)end;return e and e.unit_number and A.scope(e.surface).units[tostring(e.unit_number)]end
local function entry(e)return runtime_row(e)end
local function candidate(e,id,why)
 if not(e and e.valid and type(id)=='string')then return end
 local row=entry(e);if not row or known(row)then return end
 local ids={};local seen={};for _,old in ipairs(type(row.identity_candidates)=='table'and row.identity_candidates or{})do if type(old)=='string'and not seen[old]then ids[#ids+1]=old;seen[old]=true end end
 if not seen[id]then ids[#ids+1]=id end;table.sort(ids);row.identity_candidates=ids;row.identity_candidate_count=#ids;row.operation=why
end
local function matches(a,v)
 local t=a.target;return t and a.surface_index==v.surface and t.position and t.position.x==v.position.x and t.position.y==v.position.y and (t.name==v.name or t.name=='entity-ghost')
end
local function same(a,b,opposite)
 if not(a.target and b.target and a.target.position and b.target.position)then return false end
 local typ=a.type;if opposite then if typ=='built-entity'then typ='removed-entity'elseif typ=='removed-entity'then typ='built-entity'end end
 if opposite and typ=='upgraded-entity'and b.type==typ then return a.surface_index==b.surface_index and a.target.position.x==b.target.position.x and a.target.position.y==b.target.position.y and a.original_name==b.target.name and b.original_name==a.target.name end
 return typ==b.type and a.surface_index==b.surface_index and a.target.position.x==b.target.position.x and a.target.position.y==b.target.position.y and (a.target.name==b.target.name or a.target.name=='entity-ghost' or b.target.name=='entity-ghost')
end
local function new_action(player,a)
 local s=S();s.next=s.next+1;local n=s.next
 s.actions[tostring(n)]={id=n,player=player,type=a.type,spec=plain(a),created_tick=game.tick}
 return n
end
local function token(n)return {world=A.world(),action=n}end
local function action_from_tag(tag)
 return type(tag)=='table'and tag.world==A.world()and S().actions[tostring(tag.action)]or nil
end
local function owned_action(tag,a,player)
 local h=action_from_tag(tag)
 if not h or h.player~=player then return nil end
 -- Unsupported tile/wire action layouts still need a stable opaque label. They
 -- have no entity identity; never repeatedly relabel them because no entity
 -- target exists. A known entity action cannot be borrowed for this branch.
 if not(a.target and a.target.position and h.spec.target and h.spec.target.position)then
  return not h.logical_id and not h.current_unit and not h.ghost_unit and h.type==a.type and h or nil
 end
 -- The engine temporarily omits surface_index on old entity actions after
 -- their runtime is removed. Retain the owned label and saved source spec;
 -- applied event/source batches must still prove the actual surface later.
 local comparable=a
 if a.surface_index==nil and h.spec.surface_index~=nil then comparable={type=a.type,target=a.target,original_name=a.original_name,surface_index=h.spec.surface_index}end
 if not(same(comparable,h.spec,false)or same(comparable,h.spec,true))then return nil end
 local f=S().frames[player]
 if f and game.tick-f.tick<=1 and h.event_tick~=f.tick then
  for _,v in pairs(f.events)do if v.kind=='built-entity'and a.type==v.kind and matches(a,v)and type(v.action_tag)=='table'and v.action_tag.world==A.world()and v.action_tag.action==h.id then return nil end end
 end
 return h
end
local function addframe(player,kind,e,target_name,event_tag)
 if not A.eligible(e)then return end
 ref(e);local s=S();local f=s.frames[player]
 if not f or f.tick~=game.tick then f={tick=game.tick,events={}};s.frames[player]=f;storage.fabric_history_frame_refs[player]={tick=game.tick,events={}} end
 local v=info(e);v.name=target_name or v.name;v.kind=kind;v.action_tag=plain(event_tag);local r=entry(e);v.logical_id=known(r)and r.id or nil
 f.events[#f.events+1]=v
 local refs=storage.fabric_history_frame_refs[player];if refs and refs.tick==f.tick then refs.events[#f.events]=e end
 if kind=='removed-entity'and v.logical_id then
  s.pending_sources=s.pending_sources or{};local key=player..'/'..game.tick..'/'..v.unit
  s.pending_sources[key]={player=player,entity=plain(v)}
 end
end
-- Engine undo targets can follow a teleport while callback positions are snapshots.
-- A stale endpoint must never bind a different callback's runtime. Retain exact
-- event references outside serializable diagnostics and reject an unstable batch.
local function stable_built_frame(player,f)
 local refs=storage.fabric_history_frame_refs[player]
 for i,v in ipairs(f.events)do if v.kind=='built-entity'then
  local e=refs and refs.tick==f.tick and refs.events[i]
  if not(e and e.valid and e.unit_number==v.unit and e.surface.index==v.surface
   and (e.type=='entity-ghost'and e.ghost_name or e.name)==v.name
   and (e.type=='entity-ghost')==v.ghost
   and (e.quality and e.quality.name or 'normal')==v.quality
   and e.position.x==v.position.x and e.position.y==v.position.y)then
   if not f.unstable_built_receipt then f.unstable_built_receipt={unit=v.unit,index=i,reason='exact built callback runtime changed or disappeared before history binding'};log('history-built-frame-unstable',{player=player,event_tick=f.tick,receipt=f.unstable_built_receipt})end
   return false
  end
 end end
 return not f.unstable_built_receipt
end
function H.observe_new_ghost(en)
 if not(en and en.valid and en.type=='entity-ghost')then return end
 local tags=en.tags or{};local receipt=tags[RECEIPT]
 if receipt~=nil and (type(receipt)~='table'or receipt.ghost~=en.unit_number)then tags[RECEIPT]=nil;en.tags=tags;log('copied-history-receipt-stripped',{ghost=en.unit_number,receipt=receipt})end
end
function H.built(e)
 H.observe_new_ghost(e.entity)
 local s=S();local c=s.contexts[e.player_index]
 -- An earlier callback may invalidate the exact engine event entity. Never read
 -- its runtime fields or let a partial context authorize another restoration.
 if not(e.entity and e.entity.valid)then
  if c then c.invalid_built_tick=game.tick end
  log('history-built-invalid',{player=e.player_index,context=c and c.kind});return true
 end
 if c then
  A.register(e.entity,'history-unresolved');ref(e.entity);local v=info(e.entity);v.action_tag=plain(e.tags and e.tags[TAG]);c.built[#c.built+1]=v;log('history-native-built',{player=e.player_index,entity=info(e.entity)});return true
 end
 addframe(e.player_index,'built-entity',e.entity,nil,e.tags and e.tags[TAG]);return false
end
function H.upgrade(e)
 if e.player_index and not S().contexts[e.player_index]then addframe(e.player_index,'upgraded-entity',e.entity,e.target.name)end
end
-- A separately proved newer continuation makes an older pending restoration
-- stale. Its real entity/ghost stays in the world with its unresolved row.
-- This is causal ledger invalidation, never a live-owner absence heuristic.
function H.continued(unit,id,why)
 if A.on_continued then A.on_continued(unit,id,why)end
 local st=S()
 for _,r in pairs(st.restores)do
  if r.state=='pending'and r.logical_id==id and r.unit~=unit then
   candidate(get(r.unit or r.ghost_unit),r.logical_id,'history candidate superseded by newer proof');r.state='invalid';r.reason='superseded by later proved continuation';r.superseded={unit=unit,tick=game.tick,proof=why}
   log('restore-superseded-by-continuation',{restore=r.id,id=id,unit=unit,proof=why})
  end
 end
end
function H.inflight_restore(id)
 for _,context in pairs(S().contexts)do for _,action in pairs(context.before or{})do local h=action_from_tag(action.tags and action.tags[TAG]);if action.type=='removed-entity'and h and not h.invalid and h.logical_id==id then return true end end end;return false
end
function H.pending_conflict(id,ghost)
 for _,r in pairs(S().restores)do if r.state=='pending'and r.logical_id==id and r.ghost_unit~=ghost then return true end end;return false
end
function H.ambiguous(id,why)
 local s=S();for _,r in pairs(s.restores)do if r.state=='pending'and r.logical_id==id then candidate(get(r.unit or r.ghost_unit),r.logical_id,'history candidate: '..why);r.state='invalid';r.reason=why end end
 for _,h in pairs(s.actions)do if h.logical_id==id then h.invalid=true;h.invalid_reason=why end end
 log('logical-lineage-ambiguous',{id=id,reason=why})
end
function H.claimed(unit,id)
 H.continued(unit,id,'exact consumed unique mined item')
 for _,f in pairs(S().frames)do for _,v in pairs(f.events)do if v.unit==unit and v.kind=='built-entity'and (not v.logical_id or v.logical_id==id)then v.logical_id=id end end end
 log('exact-item-claim-history-frame',{unit=unit,id=id})
end
function H.upgraded(source,en,id)
 H.continued(en.unit_number,id,"verified robot upgrade")
 for _,h in pairs(S().actions)do if h.current_unit==source and h.logical_id==id and not h.invalid then h.current_unit=en.unit_number;ref(en);log('upgrade-action-unit-updated',{action=h.id,id=id,source=source,destination=en.unit_number})end end
end
-- The pending ghost's row was unresolved. Bind its observed upgrade action
-- only AFTER Cut has independently proved the final body owns the logical ID.
function H.ghost_upgraded_claim(source,en,id)
 for _,h in pairs(S().actions)do if h.current_unit==source and h.type=='upgraded-entity'and not h.invalid and(not h.logical_id or h.logical_id==id)then h.logical_id=id;h.current_unit=en.unit_number;ref(en);log('proved-cut-ghost-upgrade-action-bound',{action=h.id,id=id,ghost=source,unit=en.unit_number})end end
end
function H.mined(e)
 -- Manual mining is a separate observed source operation, not robot work from
 -- an outstanding history confirmation. Do not suppress its exact source frame.
 if S().contexts[e.player_index]then H.interrupted(e.player_index,'manual mining callback')end
 addframe(e.player_index,'removed-entity',e.entity)
end
function H.proven_ghost_removed(player,en,id)
 addframe(player,'removed-entity',en);local f=S().frames[player];local v=f and f.events[#f.events]
 if v and v.unit==en.unit_number and v.ghost then v.logical_id=id;S().pending_sources=S().pending_sources or{};S().pending_sources[player..'/'..game.tick..'/'..v.unit]={player=player,entity=plain(v)};log('proven-native-ghost-removal-history-frame',{player=player,id=id,ghost=v.unit})end
end
function H.marked(e)
 if not e.player_index then return end
 local c=S().contexts[e.player_index]
 if c then ref(e.entity);c.marked[#c.marked+1]=info(e.entity);log('history-native-marked',{player=e.player_index,entity=info(e.entity)})
 else addframe(e.player_index,'removed-entity',e.entity)end
end
function H.interrupted(player,kind)
 local c=S().contexts[player];if c then S().contexts[player]=nil;log('history-context-interrupted',{player=player,input=kind})end
end
-- The current real runtime can acquire its proved ID between periodic ticks
-- (for example an exact robot-built clipboard copy). Reuse the same continuity
-- check at the native history boundary before Undo can remove that runtime.
local function bind_current_identity(h)
 if not h or h.logical_id or h.invalid then return false end
 local en=get(h.current_unit);local r=en and entry(en)
 if known(r)and en.type~='entity-ghost'then
  h.logical_id=r.id;log('action-identity-bound',{action=h.id,id=r.id,unit=en.unit_number});return true
 end
 return false
end
function H.linked(kind,e)
 local p=game.get_player(e.player_index);local stack=p.undo_redo_stack;local side=kind=='undo'and'undo'or'redo'
 local actions=stack['get_'..side..'_item_count']()>0 and stack['get_'..side..'_item'](1)or {}
 -- Ensure even preexisting unknown actions have opaque correlation labels.
 for j,a in pairs(actions)do if not owned_action(a.tags and a.tags[TAG],a,p.index)then local n=new_action(p.index,a);stack['set_'..side..'_tag'](1,j,TAG,token(n))end end
 actions=stack['get_'..side..'_item_count']()>0 and stack['get_'..side..'_item'](1)or {}
 if next(actions)==nil then S().contexts[p.index]=nil;return end
 local blocked={}
 for _,a in pairs(actions)do local h=action_from_tag(a.tags and a.tags[TAG])
  if bind_current_identity(h)and A.on_bound then A.on_bound(h)end
  if h and h.logical_id then for _,pending in pairs(S().pending_sources or{})do local v=pending.entity
   if pending.player==p.index and v.logical_id~=h.logical_id and matches(a,v)then blocked[tostring(h.id)]={source_unit=v.unit,source_id=v.logical_id,event_tick=v.event_tick,retained_action_id=h.logical_id};log('history-source-action-conflict',{action=h.id,source=v,reason='observed source removal has no independent native action binding; retained tag cannot prove this source'})end
  end end
 end
 if next(blocked)then S().status='History unresolved: observed source removal conflicts with retained action tag; no identity claimed.'end
 S().contexts[p.index]={tick=game.tick,kind=kind,before=plain(actions),built={},marked={},blocked=blocked}
 log('linked-history',{player=p.index,kind=kind,actions=actions})
end
local function assign_restore(r)
 if r.state~='pending'or not r.unit or (r.ghost_unit and not r.ghost_destroyed)then return end
 if r.ghost_unit and (not r.built_tick or math.abs(r.ghost_destroyed_tick-r.built_tick)>2) then r.state='invalid';r.reason='stale ghost receipt';log('receipt-rejected',r);return end
 local e=get(r.unit);if not e then r.state='invalid';r.reason='destination gone';return end
 local h=r.action and S().actions[tostring(r.action)]
 if not r.manual_accept and(not h or h.invalid or h.logical_id~=r.logical_id)then
  r.state='invalid';r.reason='owning native history action missing, invalid, or identity changed';candidate(e,r.logical_id,r.reason);log('history-owner-authority-rejected',{restore=r.id,action=r.action,id=r.logical_id,unit=r.unit,reason=r.reason});return
 end
 if not r.manual_accept and A.source_ready then
  local proof=A.source_ready(h)
  if proof and proof.state~='ready'then
   if r.source_prerequisite_state~=proof.state or r.source_prerequisite_reason~=proof.reason then
    r.source_prerequisite_state=proof.state;r.source_prerequisite_reason=proof.reason
    log('history-source-prerequisite',{restore=r.id,action=r.action,id=r.logical_id,proof=proof})
   end
   candidate(e,r.logical_id,proof.reason)
   if proof.state~='waiting'then r.state='invalid';r.reason=proof.reason end
   return
  end
 end
 local current=entry(e);if not current or known(current)then r.state='invalid';r.reason='already assigned / manually accepted';return end
 -- Global uniqueness, including pieces still waiting for construction-robot removal.
 if A.owner then local owner=A.owner(r.logical_id,e.unit_number);if owner then r.waiting_for=owner.unit_number;return end
 else
 for _,surface in pairs(game.surfaces)do
  local scope=A.scope(surface)
  for _,other in pairs(surface.find_entities())do
   local row=other.unit_number and runtime_row(other)
   if other~=e and other.type~='entity-ghost'and row and row.id==r.logical_id and known(row)then r.waiting_for=other.unit_number;return end
  end
 end
 end
 current.identity_candidates=nil;current.identity_candidate_count=nil;current.id=r.logical_id;current.reason=r.manual_accept and 'accepted-new' or 'history-restored';current.operation=r.manual_accept and 'accepted ghost construction' or 'history '..r.action
 r.state='restored';r.restored_tick=game.tick;if A.on_restore_claimed then A.on_restore_claimed(r.logical_id,e.unit_number,r.action,e)end;if r.action and S().actions[tostring(r.action)]then S().actions[tostring(r.action)].current_unit=e.unit_number end
 log('history-restored',{restore=r.id,action=r.action,id=r.logical_id,entity=info(e)})
 S().status='History restored '..r.logical_id..' via '..(r.manual_accept and 'accepted ghost receipt' or 'action '..r.action)..'; pending duplicates never claimed.'
end
function H.applied(kind,e)
 local s=S();local c=s.contexts[e.player_index];s.contexts[e.player_index]=nil
 log('applied',{player=e.player_index,kind=kind,actions=e.actions,context=c})
 if not c or c.kind~=kind or #c.before~=#e.actions then log('history-unresolved',{reason='no matching native same-tick context'});return end
 if c.invalid_built_tick then log('history-unresolved',{reason='invalid built callback in native context',invalid_tick=c.invalid_built_tick});return end
 local matched={};local used={};local valid=true
 for j,a in pairs(e.actions)do
  local found={};for k,b in pairs(c.before)do if same(a,b,false) and a.tags and b.tags and type(a.tags[TAG])=='table' and type(b.tags[TAG])=='table' and a.tags[TAG].world==b.tags[TAG].world and a.tags[TAG].action==b.tags[TAG].action then found[#found+1]=k end end
  if #found~=1 or used[found[1]]then valid=false;break end
  used[found[1]]=true;local b=c.before[found[1]];matched[j]=action_from_tag(b.tags and b.tags[TAG])
 end
 if not valid then log('history-unresolved',{reason='ambiguous source action bijection'});return end
 -- Mirror labels explicitly onto the engine-generated inverse action. No tag propagation assumed.
 local p=game.get_player(e.player_index);local stack=p.undo_redo_stack;local dest=kind=='undo'and'redo'or'undo'
 local inverse=stack['get_'..dest..'_item_count']()>0 and stack['get_'..dest..'_item'](1)or {};local mirror={};used={}
 if #inverse==#e.actions then
  for j,a in pairs(e.actions)do
   local candidates={};for k,b in pairs(inverse)do if same(a,b,true)then candidates[#candidates+1]=k end end
   if #candidates~=1 or used[candidates[1]]then mirror={};break end
   used[candidates[1]]=true;mirror[j]=candidates[1]
  end
 end
 if #mirror==#e.actions then for j,k in pairs(mirror)do local record=matched[j];if record then stack['set_'..dest..'_tag'](1,k,TAG,token(record.id))end end;log('inverse-mirrored',{player=p.index,side=dest,mapping=mirror})
 else log('inverse-unresolved',{reason='inverse action bijection unavailable'})end
 for j,a in pairs(e.actions)do
  local h=matched[j]
  if h and not h.invalid and not(c.blocked and c.blocked[tostring(h.id)])and a.type=='removed-entity'and A.on_ghost_recreated then
   local list={};for _,v in pairs(c.built)do if v.event_tick==game.tick and v.ghost and matches(a,v)and action_from_tag(v.action_tag)==h then list[#list+1]=v end end
   local duplicates=0;if #list==1 then for _,other in pairs(e.actions)do if matches(other,list[1])then duplicates=duplicates+1 end end end
   if #list==1 and duplicates==1 then local en=get(list[1].unit)
    if en and A.on_ghost_recreated(h,en,kind)then h.current_unit=en.unit_number;h.ghost_unit=en.unit_number;h.ghost_expected=info(en);local tags=en.tags or{};tags[RECEIPT]={world=A.world(),action=h.id,ghost=en.unit_number};en.tags=tags;log('native-cut-ghost-history-rebound',{action=h.id,ghost=en.unit_number})end
   end
  end
  if h and h.logical_id and not h.invalid and not(c.blocked and c.blocked[tostring(h.id)])then
   if a.type=='removed-entity'then
    local list={};for _,v in pairs(c.built)do if v.event_tick==game.tick and matches(a,v)and action_from_tag(v.action_tag)==h then list[#list+1]=v end end
    if #list==1 then
     local v=list[1];local en=get(v.unit);local duplicates=0;for _,other in pairs(e.actions)do if matches(other,v)then duplicates=duplicates+1 end end
     if en and duplicates==1 then
      if A.on_restore and A.on_restore(h.logical_id,en)==false then log('history-restore-causally-ambiguous',{action=h.id,id=h.logical_id});en=nil end
      if en then
      s.next_restore=s.next_restore+1;local n=s.next_restore
      local r={id=n,action=h.id,logical_id=h.logical_id,state='pending',player=p.index,tick=game.tick,surface=en.surface.index}
      s.restores[tostring(n)]=r;candidate(en,r.logical_id,'native history restoration pending causal checks')
      if en.type=='entity-ghost'then
       r.ghost_unit=en.unit_number;r.expected=info(en);local tags=en.tags or {};tags[RECEIPT]={world=A.world(),action=h.id,restore=n,ghost=en.unit_number};en.tags=tags
      else r.unit=en.unit_number end
      log('restore-reserved',r);assign_restore(r)
      end
     end
    elseif #list>1 then log('history-unresolved',{action=h.id,reason='multiple native creation candidates'})end
   elseif a.type=='built-entity'then
    local list={};for _,v in pairs(c.marked)do if v.event_tick==game.tick and matches(a,v)and h.current_unit==v.unit then list[#list+1]=v end end
    if #list==1 then local en=get(list[1].unit);local r=en and entry(en);if known(r)and r.id~=h.logical_id then h.invalid=true;log('history-unresolved',{action=h.id,reason='removal identity changed'})elseif en and known(r)and A.on_redeconstruct then A.on_redeconstruct(h,en,kind)end end
   end
  end
 end
end
function H.settings_pasted(e)
 local en=e.entity;if not(en and en.valid and en.type=='entity-ghost')then return end
 local s=S();local candidates={};local tags=en.tags or{};tags[RECEIPT]=nil
 for _,r in pairs(s.restores)do if r.state=='pending'and r.ghost_unit==en.unit_number and not r.unit and not r.ghost_destroyed then candidates[#candidates+1]={world=A.world(),action=r.action,restore=r.id,ghost=en.unit_number,accepted=r.manual_accept or nil}end end
 if #candidates==0 then for _,h in pairs(s.actions)do if not h.invalid and h.ghost_unit==en.unit_number then candidates[#candidates+1]={world=A.world(),action=h.id,ghost=en.unit_number}end end end
 if #candidates==1 then tags[RECEIPT]=candidates[1];log('history-ghost-receipt-restored-after-settings-paste',{ghost=en.unit_number,receipt=candidates[1]})end
 en.tags=tags
end
-- A copied tag is not a revival receipt. The saved expected ghost and its
-- disappearance must both agree with the actual robot destination callback.
local function revival_matches(expected,ghost,entity)
 if get(ghost)then return false,'original ghost still live'end
 if not expected then return false,'no saved exact ghost specification'end
 local v=info(entity)
 if expected.surface~=v.surface or expected.name~=v.name or expected.quality~=v.quality or expected.position.x~=v.position.x or expected.position.y~=v.position.y then return false,'destination differs from recorded ghost'end
 return true
end
function H.pending_robot_receipt(e,job)
 local tag=e.tags and e.tags[RECEIPT];if not(type(tag)=='table'and tag.world==A.world()and tag.restore)then return false end
 local s=S();local r=s.restores[tostring(tag.restore)];local h=s.actions[tostring(tag.action)]
 if not(r and r.state=='pending'and r.ghost_unit==tag.ghost and not r.unit and r.action==tag.action and(r.manual_accept or h and not h.invalid))then return false end
 local ok=revival_matches(r.expected,r.ghost_unit,e.entity);return ok and Jobs.matches(job,r.ghost_unit)or false
end
function H.robot_built(e,job)
 local tag=e.tags and e.tags[RECEIPT];if not(type(tag)=='table'and tag.world==A.world())then return end
 local s=S();local h=s.actions[tostring(tag.action)]
 if tag.restore then
  A.register(e.entity,'history-unresolved')
  local r=s.restores[tostring(tag.restore)]
  if r and r.ghost_unit==tag.ghost and not r.unit and r.action==tag.action then
   local ok,why=revival_matches(r.expected,r.ghost_unit,e.entity)
   if ok then ok,why=Jobs.matches(job,r.ghost_unit)end
   if not ok then log('restore-robot-rejected',{restore=r.id,ghost=tag.ghost,entity=info(e.entity),reason=why});return true end
   ref(e.entity);r.unit=e.entity.unit_number;r.built_tick=game.tick;candidate(e.entity,r.logical_id,r.state=='pending'and 'native history restoration pending causal checks'or 'invalidated native history candidate: '..tostring(r.reason));log('restore-robot-built',{restore=r.id,ghost=tag.ghost,entity=info(e.entity)});assign_restore(r)
  end
  return true
 elseif h and not h.invalid and h.ghost_unit==tag.ghost and h.current_unit==h.ghost_unit then
  local ok,why=revival_matches(h.ghost_expected,h.ghost_unit,e.entity)
  if ok then ok,why=Jobs.matches(job,h.ghost_unit)end
  if not ok then log('action-robot-rejected',{action=h.id,ghost=tag.ghost,entity=info(e.entity),reason=why});return end
  ref(e.entity);h.current_unit=e.entity.unit_number;log('action-robot-built',{action=h.id,ghost=tag.ghost,unit=e.entity.unit_number})
 end
end
function H.destroyed(e)
 local unit=S().objects[tostring(e.registration_number)];if not unit then return end;S().objects[tostring(e.registration_number)]=nil
 local current=storage.fabric_history_refs[unit]
 if current and current.valid then log('stale-object-destroyed',{unit=unit,registration=e.registration_number});return end
 storage.fabric_history_refs[unit]=nil
 for _,r in pairs(S().restores)do if r.ghost_unit==unit then r.ghost_destroyed=true;r.ghost_destroyed_tick=game.tick;assign_restore(r)end end
end
function H.accept_ghost(en,id)
 if not(en and en.valid and en.type=='entity-ghost')then return false end
 local s=S();ref(en);s.next_restore=s.next_restore+1;local n=s.next_restore
 local r={id=n,logical_id=id,state='pending',manual_accept=true,ghost_unit=en.unit_number,tick=game.tick,surface=en.surface.index,expected=info(en)};s.restores[tostring(n)]=r;candidate(en,r.logical_id,'native history restoration pending causal checks')
 local tags=en.tags or {};tags[RECEIPT]={world=A.world(),restore=n,ghost=en.unit_number,accepted=true};en.tags=tags
 log('accepted-ghost-receipt',r);return true
end
-- A human-accepted generic ghost has an exact local receipt, not a trusted tag.
-- Native cut may delegate that pending receipt; the old receipt is retired.
function H.accepted_ghost_source(en)
 if not(en and en.valid and en.type=='entity-ghost'and get(en.unit_number)==en)then return end
 local row=entry(en);if not(row and row.reason=='accepted-new')then return end
 local found
 for _,r in pairs(S().restores)do if r.manual_accept and r.state=='pending'and r.ghost_unit==en.unit_number and r.logical_id==row.id and not r.unit and not r.ghost_destroyed then
  if found then return end;found=r
 end end
 if found then return{kind='accepted-ghost',id=row.id,ghost_unit=en.unit_number,receipt=found.id}end
end
function H.delegate_accepted_ghost(en,proof,operation)
 local actual=H.accepted_ghost_source(en)
 if not actual or actual.receipt~=proof.receipt or actual.id~=proof.id or actual.ghost_unit~=proof.ghost_unit then return false end
 local r=S().restores[tostring(actual.receipt)];r.state='delegated';r.delegated_cut=operation;r.delegated_tick=game.tick
 log('accepted-ghost-delegated-cut',{receipt=r.id,id=r.logical_id,ghost=r.ghost_unit,operation=operation});return true
end
function H.invalidate_unit(unit,why)
 for _,r in pairs(S().restores)do if r.unit==unit or r.ghost_unit==unit then r.state='invalid';r.reason=why;local h=S().actions[tostring(r.action)];if h then h.invalid=true end end end
 for _,h in pairs(S().actions)do if h.current_unit==unit or h.ghost_unit==unit then
  local c=S().contexts[h.player];local exact=0
  if why=='ghost placement cancelled'and h.cut_placement and c and c.kind=='undo'and c.tick==game.tick then for _,a in pairs(c.before)do if a.type=='built-entity'and action_from_tag(a.tags and a.tags[TAG])==h then exact=exact+1 end end end
  if exact~=1 then h.invalid=true;h.invalid_reason=why else log('native-undo-cut-ghost-retained',{action=h.id,ghost=unit})end
 end end
end
local function context_owns_top(p,c)
 local stack=p.undo_redo_stack;local side=c.kind
 if side~='undo'and side~='redo'then return false end
 if stack['get_'..side..'_item_count']()==0 then return false end
 local current=stack['get_'..side..'_item'](1);if #current~=#c.before then return false end
 local expected={};for _,a in pairs(c.before)do local h=action_from_tag(a.tags and a.tags[TAG]);if not h or expected[tostring(h.id)]then return false end;expected[tostring(h.id)]=a end
 local used={};for _,a in pairs(current)do local h=action_from_tag(a.tags and a.tags[TAG]);local key=h and tostring(h.id);local b=key and expected[key]
  if not b or used[key]or not same(a,b,false)then return false end;used[key]=true
 end
 return true
end
H.test_context_top=context_owns_top
function H.tick()
 local st=S()
 if not st.item_reservation_migration_v57 then
  local proofs={};for _,event in ipairs(st.trace)do if event.kind=='exact-item-claim-history-frame'and event.data and event.data.id then proofs[#proofs+1]=event end end
  for _,event in ipairs(proofs)do for _,r in pairs(st.restores)do if r.state=='pending'and r.logical_id==event.data.id and r.unit~=event.data.unit and event.tick>(r.tick or event.tick)then
   r.state='invalid';r.reason='legacy reservation superseded by retained later exact item claim';r.superseded={unit=event.data.unit,tick=event.tick,proof=event.kind}
  end end end
  st.item_reservation_migration_v57={tick=game.tick,retained_proofs=#proofs}
 end
 Jobs.poll()
 local s=S()
 -- Keep delayed confirmation contexts without a timeout while their exact
 -- tagged action remains on top. An API/new action clearing/replacing that
 -- stack cancels the old attempt; no applied event is assumed to follow it.
 for player,c in pairs(s.contexts)do if game.tick>c.tick then local p=game.get_player(player)
  if not p or not context_owns_top(p,c)then s.contexts[player]=nil;log('unapplied-history-context-cleared',{player=player,kind=c.kind,started=c.tick,reason='original tagged stack item no longer current'})end
 end end

 if not s.opaque_cleanup_v34 then
  local referenced={}
  for _,p in pairs(game.players)do local stack=p.undo_redo_stack
   for _,side in ipairs{'undo','redo'}do for i=1,stack['get_'..side..'_item_count']()do for _,a in pairs(stack['get_'..side..'_item'](i))do local t=a.tags and a.tags[TAG];if type(t)=='table'and t.world==A.world()then referenced[tostring(t.action)]=true end end end end
  end
  for _,r in pairs(s.restores)do if r.action then referenced[tostring(r.action)]=true end end
  for _,op in pairs(storage.vanilla_cut and storage.vanilla_cut.ops or{})do for _,pc in pairs(op.pieces)do if pc.history_action then referenced[tostring(pc.history_action)]=true end end end
  local removed,retained=0,0;local sample={}
  for id,h in pairs(s.actions)do
   if not referenced[id]and not h.logical_id and not h.current_unit and not h.ghost_unit then s.actions[id]=nil;removed=removed+1;if #sample<20 then sample[#sample+1]=id end
   else retained=retained+1 end
  end
  s.opaque_cleanup_v34={tick=game.tick,removed_unreferenced_unknown_labels=removed,retained=retained,sample_removed=sample,rule='No live engine stack, restore or cut history reference; no entity/id/ghost ownership. Monotonic next counter retained.'};log('opaque-history-churn-cleanup',s.opaque_cleanup_v34)
 end
 for _,r in pairs(s.restores)do if r.state=='pending'and not r.expected then local en=get(r.ghost_unit);if en then r.expected=info(en)end end end
 for _,h in pairs(s.actions)do if h.ghost_unit and not h.ghost_expected then local en=get(h.ghost_unit);if en then h.ghost_expected=info(en)end end end
 for _,p in pairs(game.connected_players)do
  local frame=s.frames[p.index]
  -- Native source callbacks require same/next-tick binding. Idle stack polling
  -- is diagnostic discovery only; linked undo/redo validates/tag its exact top
  -- synchronously. Never spend two complete engine-stack reads every idle tick.
  local immediate=frame and game.tick-frame.tick>=0 and game.tick-frame.tick<=1
  s.stack_scan_ticks=s.stack_scan_ticks or{}
  if immediate or s.contexts[p.index]or not s.stack_scan_ticks[p.index]or game.tick-s.stack_scan_ticks[p.index]>=60 then
  s.stack_scan_ticks[p.index]=game.tick
  local stable_built=immediate and stable_built_frame(p.index,frame)
  if immediate then frame.native_stack_scanned=true end
  local stack=p.undo_redo_stack;local unowned={}
  for i=1,stack.get_undo_item_count()do for _,a in pairs(stack.get_undo_item(i))do if not owned_action(a.tags and a.tags[TAG],a,p.index)then unowned[#unowned+1]=a end end end
  for _,side in ipairs({'undo','redo'})do for i=1,stack['get_'..side..'_item_count']()do
   for j,a in pairs(stack['get_'..side..'_item'](i))do
    if not owned_action(a.tags and a.tags[TAG],a,p.index)then
     local n=new_action(p.index,a);local h=s.actions[tostring(n)]
     -- Manual mining appends its native action one tick after the mined event
     -- in measured 2.1.24. Only a newly untagged, uniquely matching action qualifies.
     if side=='undo'and frame and game.tick-frame.tick>=0 and game.tick-frame.tick<=1 then
      local list={};for _,v in pairs(frame.events)do if a.type==v.kind and (v.kind~='built-entity'or stable_built)and matches(a,v)then list[#list+1]=v end end
      -- Unique within the gesture frame AND the stack item, otherwise fail closed.
      if #list==1 then
       local v=list[1];local count=0;for _,other in pairs(stack.get_undo_item(i))do if other.type==v.kind and matches(other,v)then count=count+1 end end
       local en=get(v.unit)
       local all=0;for _,candidate in pairs(unowned)do if candidate.type==v.kind and matches(candidate,v)then all=all+1 end end
       if count==1 and all==1 and (en or (a.type=='removed-entity' and v.logical_id))then
        h.current_unit=v.unit;h.name=v.name;h.event_tick=frame.tick;h.logical_id=v.logical_id;if v.kind=='built-entity'then h.frame_receipt_version=96 end
        if en and en.type=='entity-ghost'then h.ghost_unit=en.unit_number;h.ghost_expected=info(en);local tags=en.tags or {};tags[RECEIPT]={world=A.world(),action=n,ghost=en.unit_number};en.tags=tags end
        local row=en and entry(en);if known(row)then h.logical_id=row.id end
        log('action-bound',{action=n,kind=a.type,entity=v,id=h.logical_id})
       end
      end
     end
     stack['set_'..side..'_tag'](i,j,TAG,token(n))
    end
   end
  end end
  end
 end
 for _,h in pairs(s.actions)do bind_current_identity(h)end
 for key,pending in pairs(s.pending_sources or{})do local v=pending.entity
  for _,h in pairs(s.actions)do if not h.invalid and h.player==pending.player and h.current_unit==v.unit and h.event_tick==v.event_tick and h.logical_id==v.logical_id then s.pending_sources[key]=nil;break end end
 end
 if A.on_bound then for _,h in pairs(s.actions)do if h.current_unit and not h.invalid then A.on_bound(h)end end end
 for _,r in pairs(s.restores)do if r.state=='pending'and r.ghost_destroyed and not r.unit and game.tick>(r.ghost_destroyed_tick or game.tick)+2 then r.state='invalid';r.reason='original ghost disappeared without verified robot destination';log('restore-expired-without-destination',{restore=r.id,ghost=r.ghost_unit})else assign_restore(r)end end
 for p,f in pairs(s.frames)do if f.tick<game.tick then if f.native_stack_scanned and A.on_birth_scan then A.on_birth_scan(p,f.tick)end;s.frames[p]=nil;storage.fabric_history_frame_refs[p]=nil end end
 -- Confirmation dialogs may remain open indefinitely. Exact source tags and
 -- applied-tick event batches, rather than elapsed time, validate correlation.
end
function H.reject_birth(action,why)
 local h=S().actions[tostring(action)];if not h then return end
 h.invalid=true;h.invalid_reason=why;log('unverified-legacy-birth-action-retired',{action=action,reason=why})
 for _,r in pairs(S().restores)do if r.action==action and r.state=='pending'then r.state='invalid';r.reason=why end end
end
function H.init(api)A=api end
function H.snapshot()return S()end
H.test_matches=matches
H.test_same=same
function H.invalidate_surface(index)
 local s=S();for _,h in pairs(s.actions)do if h.spec.surface_index==index then h.invalid=true;h.invalid_reason='surface deleted'end end
 for _,r in pairs(s.restores)do local h=r.action and s.actions[tostring(r.action)];if r.surface==index or(h and h.invalid)then r.state='invalid';r.reason='surface deleted'end end
end
function H.status()return S().status end
return H
