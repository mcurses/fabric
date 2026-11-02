-- Narrow native cut extension. All authoritative ledger/log data are plain values.
local M={};local A;local post;local unresolved_candidate;local finish_copy;local native_birth
local issuer_ok,issuer_config=pcall(require,'session-issuer');local ISSUER=issuer_ok and type(issuer_config)=='table'and type(issuer_config.value)=='string'and #issuer_config.value>=32 and issuer_config.value or nil
local Geometry=require('placement-geometry')
local Jobs=require('robot-jobs')
local TAG='fabric_playground_cut_v1'
local function S()
 storage.vanilla_cut=storage.vanilla_cut or {next_op=0,next_place=0,ops={},places={},arms={},inputs={},latest={},sources={},objects={},trace={},sequence=0,namespace=tostring(math.random(1,2147483646))..':'..tostring(math.random(1,2147483646)),status='Native cut extension: experimental; native history experimental; unsupported actions unresolved.'}
 storage.vanilla_cut_refs=storage.vanilla_cut_refs or {}
 return storage.vanilla_cut
end
-- A copy recipient cannot contest the owner's live move permission. Unknown
-- actors remain conservative. Later gestures are copies only after an earlier
-- tick's exact native birth approved the unique original reservation.
local function copy_recipient(op,pc,actor,pl)
 if not(op and pc)then return false end
 if op.mode=='copy'or pc.state=='copy'or pc.state=='transferred'then return true end
 if type(op.player)=='number'and type(actor)=='number'and op.player~=actor then return true end
 if (pc.state=='reserved'or pc.state=='delegated')and pl then
  local prior=S().places[tostring(pc.placement)]
  if prior and prior.id~=pl.id and prior.approved and native_birth and native_birth(prior)and type(pl.tick)=='number'and pl.tick>prior.tick then return true end
 end
 return false
end
local function log(kind,data)
 local s=S();s.sequence=s.sequence+1;s.trace[#s.trace+1]={seq=s.sequence,tick=game.tick,kind=kind,data=data or {}};if #s.trace>8192 then table.remove(s.trace,1);s.dropped_trace=(s.dropped_trace or 0)+1 end
end
local function entity(e)
 return e and e.valid and {unit=e.unit_number,name=e.type=='entity-ghost' and e.ghost_name or e.name,ghost=e.type=='entity-ghost',surface=e.surface.index,position={x=e.position.x,y=e.position.y}} or nil
end
local function ref(e)
 if not (e and e.valid and e.unit_number)then return end
 storage.vanilla_cut_refs[e.unit_number]=e
 local reg=script.register_on_object_destroyed(e);S().objects[tostring(reg)]=e.unit_number
end
local function get(unit)local e=storage.vanilla_cut_refs and storage.vanilla_cut_refs[unit];return e and e.valid and e or nil end
local function runtime_row(e)if A.row then return A.row(e)end;return e and e.unit_number and A.scope(e.surface).units[tostring(e.unit_number)]end
local function entry(e)return runtime_row(e)end
local function known(r)return r and (r.reason=='initial' or r.reason=='direct' or r.reason=='accepted-new' or r.reason=='cut-transfer' or r.reason=='clipboard-copy' or r.reason=='engine-clone-copy' or r.reason=='item-receipt' or r.reason=='history-restored'or r.reason=='death-restored')end
local function blueprint(p,r,st)
 r=r or p.cursor_record
 if r then while r and r.type=='blueprint-book'do r=r.get_selected_record(p)end;if r and not r.is_preview and r.type=='blueprint'then return r end end
 st=st or p.cursor_stack
 if st and st.valid_for_read then while st and st.is_blueprint_book do local inv=st.get_inventory(defines.inventory.item_main);st=inv and inv[st.active_index]end;if st and st.valid_for_read and st.is_blueprint then return st end end
end
local function invalidate(piece,why)
 if piece.ambiguous and piece.placement then
  piece.ambiguity_readout_refreshed=true
  local pl=S().places[tostring(piece.placement)]
  for _,unit in pairs(pl and{pl.ghost_unit,pl.dest_unit}or{})do local en=get(unit);local row=en and A and(A.row or A.scope)and entry(en)
   if row and not known(row)then row.identity_candidates={piece.id};row.identity_candidate_count=1;row.operation='cut '..piece.op..': '..why end
  end
 end
 if piece.state=='transferred' or piece.state=='invalid' then return end
 piece.state='invalid';piece.invalid_reason=why;log('invalidated',{op=piece.op,piece=piece.index,id=piece.id,reason=why})
 S().status='Cut transfer cancelled: '..why..'. Clipboard replay cannot claim old ID.'
end
local function cancel_player(player,why)
 local s=S();s.arms[player]=nil
 for _,op in pairs(s.ops)do if op.player==player then for _,piece in pairs(op.pieces)do invalidate(piece,why)end end end
end
function M.invalidate_unit(unit,why)
 for _,op in pairs(S().ops)do for _,piece in pairs(op.pieces)do
  local pl=piece.placement and S().places[tostring(piece.placement)]
  if piece.source_unit==unit or (pl and (pl.ghost_unit==unit or pl.dest_unit==unit))then invalidate(piece,why)end
 end end
end
local function tagpiece(tag)
 if type(tag)~='table' or tag.world~=S().namespace then return end
 local op=S().ops[tostring(tag.op)];if not op or op.issuer~=tag.issuer or(op.issuer_required and not op.issuer)then return end
 local piece=op.pieces[tostring(tag.piece)]
 if piece and piece.source_unit==tag.source and piece.id==tag.id then return op,piece end
end
local function fresh(e,why)
 A.register(e,'recreated-or-blueprint');local r=entry(e);if not r then return end
 -- Never replace an already known living assignment (including human acceptance).
 if known(r)then return end
 r.id=A.alloc('F');r.reason='clipboard-copy';r.operation=why
 log('fresh-copy',{entity=entity(e),id=r.id,reason=why})
end
-- A pre-deconstruction callback is intent, not proof of deletion cause. A later
-- mod can revive the exact ghost without raising an event. Its engine-contained
-- original UID must therefore be absent before this delegated cut may continue.
local function ghost_source_closed(piece)
 if piece.source_kind~='engine-death-ghost'then return true end
 local proof=piece.ghost_proof
 if not(type(proof)=='table'and type(proof.source_unit)=='number'and proof.ghost_unit==piece.source_unit and proof.id==piece.id)then
  piece.ambiguous=true;invalidate(piece,'delegated death ghost lacks exact original-unit proof');return false
 end
 for _,sf in pairs(game.surfaces)do for _,en in pairs(sf.find_entities_filtered{name=piece.name})do
  if en.valid and en.type~='entity-ghost'and en.unit_number==proof.source_unit then
   piece.ambiguous=true;piece.original_revival_seen={unit=en.unit_number,tick=game.tick,surface=en.surface.index}
   invalidate(piece,'selected death ghost revived original engine unit during native cut')
   if A.eligible(en)then A.register(en,'death-lineage-unresolved');local row=entry(en);if row and not known(row)then row.identity_candidates={piece.id};row.identity_candidate_count=1;row.operation='delegated ghost cut: original engine unit revived; identity unresolved'end end
   return false
  end
 end end
 return true
end
local function owned_ghost_source(ghost,player)
 for _,pl in pairs(S().places)do
  local op=S().ops[tostring(pl.op)];local pc=op and op.pieces[tostring(pl.piece)]
  if op and op.player==player and pc and pc.state=='reserved'and not pc.ambiguous and not pc.delegated_to and pc.placement==pl.id and pl.state=='reserved'and pl.approved and pl.ghost_unit==ghost.unit_number and get(pl.ghost_unit)==ghost and not pl.dest_unit and S().latest[pc.id]==op.id then
   return{kind='owned-cut-ghost',id=pc.id,op=op.id,piece=tostring(pc.index),placement=pl.id,ghost_unit=ghost.unit_number}
  end
 end
end
local function unit_set(name)
 local units={};local n=0
 for _,sf in pairs(game.surfaces)do for _,en in pairs(sf.find_entities_filtered{name=name})do if en.valid and en.type~='entity-ghost'and en.unit_number then units[tostring(en.unit_number)]=true;n=n+1 end end end
 return units,n
end
local function legacy_owned_ghost_closed(pc)
 if pc.source_kind~='owned-cut-ghost'and pc.source_kind~='accepted-ghost'then return true end
 if pc.ghost_lifetime_checked then return not pc.ambiguous end
 if type(pc.before_ghost_bodies)~='table'then pc.ambiguous=true;invalidate(pc,'owned cut ghost lacks pre-removal body inventory');return false end
 local unknown={}
 for _,sf in pairs(game.surfaces)do for _,en in pairs(sf.find_entities_filtered{name=pc.name})do
  if en.valid and en.type~='entity-ghost'and en.unit_number and not pc.before_ghost_bodies[tostring(en.unit_number)]then
   unknown[#unknown+1]=en.unit_number
   if A.eligible(en)then A.register(en,'ghost-removal-unresolved');local row=entry(en);if row and not known(row)then row.identity_candidates={pc.id};row.identity_candidate_count=1;row.operation='owned cut ghost removal coincided with newly observed body; lineage unresolved'end end
  end
 end end
 pc.ghost_lifetime_checked=true;pc.before_ghost_bodies=nil
 if #unknown>0 then pc.ambiguous=true;pc.unraised_body_candidates=unknown;invalidate(pc,'owned cut ghost disappeared alongside new bodies; deletion versus unraised revival unresolved');return false end
 return true
end
-- One before/after body inventory per prototype in an actual extraction batch.
-- No member receives removal permission until every exact selected ghost closes.
-- A newly observed body is ambiguous among ALL same-prototype group candidates.
local function owned_ghost_closed(pc)
 if pc.source_kind~='owned-cut-ghost'and pc.source_kind~='accepted-ghost'then return true end
 if pc.ghost_lifetime_checked then return not pc.ambiguous end
 if not pc.ghost_inventory_key then return legacy_owned_ghost_closed(pc)end
 local op=S().ops[tostring(pc.op)];local b=op and op.ghost_body_inventories and op.ghost_body_inventories[pc.ghost_inventory_key]
 if not(b and b.members[tostring(pc.index)])then pc.ambiguous=true;invalidate(pc,'owned ghost extraction batch inventory missing');return false end
 local key=tostring(pc.index)
 if not b.closed[key]then b.closed[key]=game.tick;b.closed_count=b.closed_count+1 end
 if b.closed_count~=b.expected then return false end
 local unknown={};local entities={};local ids={}
 for index in pairs(b.members)do local member=op.pieces[index];ids[#ids+1]=member.id end;table.sort(ids)
 for _,sf in pairs(game.surfaces)do for _,en in pairs(sf.find_entities_filtered{name=b.name})do
  if en.valid and en.type~='entity-ghost'and en.unit_number and not b.units[tostring(en.unit_number)]then unknown[#unknown+1]=en.unit_number;entities[#entities+1]=en end
 end end
 b.finished=true;b.units=nil;b.unknown_count=#unknown
 local batchkey=tostring(op.id)..':'..b.name;if S().pending_ghost_batches then S().pending_ghost_batches[batchkey]=nil end
 for index in pairs(b.members)do local member=op.pieces[index];member.ghost_lifetime_checked=true
  if #unknown>0 then member.ambiguous=true;member.unraised_body_candidates=unknown;invalidate(member,'owned ghost batch disappeared alongside new bodies; source candidate within batch unresolved')
  else member.source_removed=true;member.removed_tick=b.closed[index]end
 end
 for _,en in ipairs(entities)do if A.eligible(en)then A.register(en,'ghost-removal-unresolved');local row=entry(en);if row and not known(row)then row.identity_candidates=ids;row.identity_candidate_count=#ids;row.operation='owned ghost batch removal coincided with new body; no member selected'end end end
 log('owned-ghost-batch-closed',{op=op.id,name=b.name,members=b.expected,before_count=b.before_count,new_bodies=#unknown})
 return not pc.ambiguous
end
local function upstream_closed(pc)
 local child=pc;local seen={}
 while child.source_kind=='owned-cut-ghost'do
  local proof=child.ghost_proof;local op=proof and S().ops[tostring(proof.op)];local parent=op and op.pieces[tostring(proof.piece)]
  if not parent or seen[parent]or parent.id~=pc.id or parent.delegated_to~=child.op or parent.placement~=proof.placement or parent.state~='delegated'or parent.ambiguous or parent.source_cancelled or parent.source_provenance_invalid then
   pc.ambiguous=true;invalidate(pc,'upstream owned cut ghost source proof invalid');return false
  end
  seen[parent]=true
  local parent_place=S().places[tostring(proof.placement)];if not native_birth(parent_place)then return false end
  if not parent.source_removed then return false end
  if not ghost_source_closed(parent)or not owned_ghost_closed(parent)then pc.ambiguous=true;invalidate(pc,'upstream ghost removal ambiguous');return false end
  child=parent
 end
 return true
end
-- History reservations retire clipboard rights, but must retain independently
-- observed source-removal facts. Retirement itself is never a removal receipt.
local function observes_source(piece,op)
 if piece.ambiguous or piece.source_cancelled or piece.source_provenance_invalid then return false end
 return piece.state=='available' or piece.state=='reserved' or piece.state=='delegated'
  or(piece.state=='invalid'and(piece.invalid_reason=='native history restored this ID'
   or(piece.invalid_reason=='ghost placement cancelled'and S().latest[piece.id]==op.id)))
end
-- A whole-batch native ghost removal was independently proved before any
-- destination was pasted. Later destination ambiguity does not erase that fact.
-- Missing/failed legacy proof and every source-lineage failure stay rejected.
local function closed_source_batch(pc)
 if pc.source_kind~='accepted-ghost'and pc.source_kind~='owned-cut-ghost'then return false end
 if pc.source_lineage_unverified or pc.source_provenance_invalid or pc.source_cancelled or pc.source_manually_mined or pc.unraised_body_candidates then return false end
 if not(pc.source_removed and pc.ghost_lifetime_checked and pc.ghost_inventory_key)then return false end
 local op=S().ops[tostring(pc.op)];local b=op and op.ghost_body_inventories and op.ghost_body_inventories[pc.ghost_inventory_key];local key=tostring(pc.index)
 return b and b.finished and not b.failed and b.unknown_count==0 and b.expected>0 and b.closed_count==b.expected and b.members[key]and b.closed[key]~=nil or false
end
-- Saved authoritative action->source binding, including legacy pending saves.
-- No endpoint matching, transport tags, or absent-owner inference grants proof.
function M.history_source_ready(h)
 if M.migrate_legacy_merge_receipts then M.migrate_legacy_merge_receipts()end
 local s=S()
 if not s.history_source_index then
  s.history_source_index={}
  for _,op in pairs(s.ops)do for _,pc in pairs(op.pieces)do if pc.history_action then
   local k=tostring(pc.history_action);local old=s.history_source_index[k]
   if old then old.duplicate=true else s.history_source_index[k]={op=op.id,piece=tostring(pc.index)}end
  end end end
 end
 local ptr=s.history_source_index[tostring(h.id)]
 if not ptr then return {state='ready',reason='not a delegated cut source action'}end
 local op=s.ops[tostring(ptr.op)];local pc=op and op.pieces[tostring(ptr.piece)]
 if not ptr.duplicate and pc and pc.source_kind~='owned-cut-ghost'and pc.source_kind~='engine-death-ghost'and pc.source_kind~='accepted-ghost'then return{state='ready'}end
 local function result(state,why)return{state=state,reason=why,operation=ptr.op,piece=ptr.piece}end
 if ptr.duplicate or not pc or pc.history_action~=h.id or pc.id~=h.logical_id or op.player~=h.player
  or pc.selected_tick~=h.event_tick or pc.marked_tick~=h.event_tick then return result('invalid','delegated history source binding invalid or nonunique')end
 local seen={};local child=pc
 while child do
  if seen[child]or child.id~=h.logical_id or(child.ambiguous and not closed_source_batch(child))or child.source_lineage_unverified or child.source_cancelled or child.source_provenance_invalid or child.source_manually_mined then return result('invalid','upstream cut source ambiguous, cancelled, or unverified')end
  seen[child]=true
  if child.source_kind=='owned-cut-ghost'or child.source_kind=='engine-death-ghost'or child.source_kind=='accepted-ghost'then
   if not child.source_removed or not child.ghost_removal_tick or child.pre_marked or child.marked_tick~=child.selected_tick then return result('invalid','native ghost source removal receipt missing')end
   if not ghost_source_closed(child)or(not closed_source_batch(child)and not owned_ghost_closed(child))then return result('invalid','ghost lifetime proof failed')end
   if child.source_kind=='engine-death-ghost'then return result('ready','verified engine death ghost source closed')end
   if child.source_kind=='accepted-ghost'then local proof=child.ghost_proof;if not(proof and proof.id==child.id and proof.ghost_unit==child.source_unit and proof.receipt)then return result('invalid','accepted ghost lacks exact delegated receipt')end;return result('ready','verified accepted generic ghost source closed')end
   local proof=child.ghost_proof;local parentop=proof and s.ops[tostring(proof.op)];local parent=parentop and parentop.pieces[tostring(proof.piece)]
   local pl=proof and s.places[tostring(proof.placement)]
   if not parent or not pl or parentop.player~=h.player or pl.op~=parentop.id or tostring(pl.piece)~=tostring(parent.index)
    or not pl.approved or type(pl.merge_guard_version)~='number'or pl.merge_guard_version<80 or pl.ghost_unit~=child.source_unit or parent.id~=child.id or parent.delegated_to~=child.op then return result('invalid','upstream exact cut placement binding missing')end
   if not native_birth(pl)then return result('waiting','upstream destination native birth action not yet proven')end
   child=parent
  else
   if child.source_removed and child.mined_tick and child.marked_tick==child.selected_tick and not child.pre_marked then return result('ready','verified upstream source robot removal')end
   local live=get(child.source_unit);local row=live and entry(live)
   if live and known(row)and row.id==child.id and live.to_be_deconstructed()then return result('waiting','upstream original source still awaiting verified robot removal')end
   return result('invalid','upstream original source disappeared without verified robot removal')
  end
 end
 return result('invalid','missing upstream source')
end
native_birth=function(pl)
 local b=pl and pl.native_action_birth
 return b and pl.native_action_guard_version==99 and b.receipt_version==96 and b.action==pl.history_action and b.player==pl.player and b.receipt_unit==(pl.ghost_unit or pl.dest_unit)and b.event_tick==pl.tick or false
end
local function awaiting_birth(pl,pc)
 pl.awaiting_native_birth=true
 for _,unit in pairs{pl.ghost_unit,pl.dest_unit}do local en=get(unit);if en and unresolved_candidate then unresolved_candidate(en,pc,'Clipboard destination awaiting exact native undo-action birth receipt; no ID claimed')end end
end
finish_copy=function(pl,op)
 if not native_birth(pl)then awaiting_birth(pl,op.pieces[tostring(pl.piece)]);return end
 pl.awaiting_native_birth=nil;local en=pl.dest_unit and get(pl.dest_unit);if en then fresh(en,'extraction '..op.id..' replay/copy')end
end
local function try_transfer(piece)
 if piece.state~='reserved' or piece.delegated_to or not piece.source_removed then return end
 if not ghost_source_closed(piece)or not owned_ghost_closed(piece)or not upstream_closed(piece)then return end
 local pl=S().places[tostring(piece.placement)];if not pl or not pl.approved or not pl.dest_unit or (pl.ghost_unit and not pl.ghost_destroyed)then return end
 if pl.ghost_unit and (not pl.built_tick or math.abs(pl.ghost_destroyed_tick-pl.built_tick)>2)then invalidate(piece,'stale ghost receipt');return end
 local e=get(pl.dest_unit);if not e then invalidate(piece,'destination disappeared');return end
 if not native_birth(pl)then awaiting_birth(pl,piece);return end
 pl.awaiting_native_birth=nil
 local r=entry(e)
 if not r or known(r) then invalidate(piece,'destination already assigned or accepted');return end
 if S().latest[piece.id]~=piece.op or get(piece.source_unit) then invalidate(piece,'source provenance changed or still live');return end
 if A.owner then local owner=A.owner(piece.id,e.unit_number);if owner then invalidate(piece,'logical ID already live elsewhere');return end
 else
 for _,surface in pairs(game.surfaces)do local sc=A.scope(surface);for _,other in pairs(surface.find_entities())do local row=other.unit_number and runtime_row(other);if other~=e and other.type~='entity-ghost' and known(row) and row.id==piece.id then invalidate(piece,'logical ID already live elsewhere');return end end end
 end
 -- The original ID is free after exact destruction plus verified robot mining,
 -- or an authoritative pending ghost removed by the exact native cut gesture.
 r.id=piece.id;r.reason='cut-transfer';r.operation=piece.op
 piece.state='transferred';piece.dest_unit=e.unit_number;piece.transferred_tick=game.tick;pl.state='transferred'
 if A.history_continued then A.history_continued(e.unit_number,piece.id,'verified native cut transfer')end
 if pl.upgrade_count and A.ghost_upgrade_claim then A.ghost_upgrade_claim(pl.ghost_unit,e,piece.id)end
 log('transferred',{op=piece.op,piece=piece.index,id=piece.id,source=piece.source_unit,destination=entity(e)})
 S().status='Cut '..piece.op..': moved '..piece.id..'. Further pastes are fresh copies; native history experimental; unsupported actions unresolved.'
end
local function revalidate_manual_source(op,pc)
 if op.mode~='cut'or S().latest[pc.id]~=op.id or pc.source_removed or pc.source_manually_mined or pc.state=='transferred'or pc.state=='copy'then return end
 for _,pool in pairs(storage.fabric_mined_items and storage.fabric_mined_items.sources or{})do local source=pool[pc.id]
  if source and source.actor~='robot'and source.unit==pc.source_unit and type(source.tick)=='number'and type(pc.selected_tick)=='number'and source.tick>=pc.selected_tick then
   pc.ambiguous=true;pc.source_manually_mined={unit=source.unit,player=source.player,tick=source.tick,retained_ledger=true};invalidate(pc,'selected cut source manually mined; retained material lineage unresolved');log('retained-manual-cut-source-revalidated',{op=op.id,piece=pc.index,id=pc.id,source=source.unit,tick=source.tick});return
  end
 end
end
function M.source_manually_mined(e)
 local en=e.entity;if not(en and en.valid and en.unit_number and en.type~='entity-ghost')then return end
 local row=entry(en);if not known(row)then return end
 local s=S();for _,op in pairs(s.ops)do if op.mode=='cut'then for _,pc in pairs(op.pieces)do
  if pc.source_unit==en.unit_number and pc.id==row.id and s.latest[pc.id]==op.id and(pc.state=='selected'or pc.state=='available'or pc.state=='reserved')then
   pc.ambiguous=true;pc.source_manually_mined={unit=en.unit_number,player=e.player_index,tick=game.tick};invalidate(pc,'selected cut source manually mined; material lineage unresolved')
   log('cut-source-manually-mined',{op=op.id,piece=pc.index,id=pc.id,source=en.unit_number,player=e.player_index})
  end
 end end end
end
unresolved_candidate=function(en,pc,why)
 local row=entry(en);if not row or known(row)then return end
 if type(pc.id)=='string'and pc.id:sub(1,1)=='F'then row.identity_candidates={pc.id};row.identity_candidate_count=1 end;row.operation=why
end
-- Earlier saves could approve an API-born ghost before a native same-input
-- merge. Absence of a retained event log is NOT proof that no merge occurred.
-- Retire outstanding permissions, preserving known live rows and accepted aliases.
local function migrate_copy_merge_receipts()
 local st=S();if st.copy_merge_migration_v91 then return end
 local report={version=91,tick=game.tick,retired=0}
 for _,pl in pairs(st.places or{})do
  local op=st.ops and st.ops[tostring(pl.op)];local pc=op and op.pieces[tostring(pl.piece)]
  if pc and not pl.copy_merge_guard_version and(pl.state=='copy'or(pl.state=='pending-receipt'and(op.mode=='copy'or pc.state=='transferred'or pc.state=='copy')))and get(pl.ghost_unit)then
   pl.state='ambiguous';pl.approved=false;pl.native_merge_legacy_copy=true
   unresolved_candidate(get(pl.ghost_unit),pc,'legacy pending copy lacks guarded creation/merge proof; identity unresolved')
   if A.history_cancel and not known(entry(get(pl.ghost_unit)))then A.history_cancel(pl.ghost_unit,'legacy pending copy birth unverified')end
   report.retired=report.retired+1
  end
 end
 st.copy_merge_migration_v91=report
end
function M.migrate_legacy_merge_receipts()
 migrate_copy_merge_receipts()
 local st=S();if st.merge_guard_migration_v81 then return end
 local report={version=81,tick=game.tick,retired_receipts=0,retired_source_dependencies=0,samples={}}
 local function active(pc)return pc and(pc.state=='selected'or pc.state=='available'or pc.state=='reserved'or pc.state=='delegated')end
 local function modern(pl)return pl and type(pl.merge_guard_version)=='number'and pl.merge_guard_version>=80 end
 local function annotate(unit,pc,why)
  local en=unit and get(unit);if en and type(pc.id)=='string'then
   local row=entry(en)
   if not row and A.register and A.eligible(en)then A.register(en,'legacy-receipt-unresolved');row=entry(en)end
   if row and not known(row)then
    local ids={};local seen={};for _,id in ipairs(row.identity_candidates or{})do if not seen[id]then seen[id]=true;ids[#ids+1]=id end end
    if not seen[pc.id]then ids[#ids+1]=pc.id end;table.sort(ids)
    row.identity_candidates=ids;row.identity_candidate_count=math.max(row.identity_candidate_count or 0,#ids);row.operation=why
   end
  end
 end
 local function cancel_history(unit,pc,why)
  if type(unit)~='number'or not A.history_cancel then return end
  local en=get(unit);local row=en and entry(en)
  if not(known(row)and row.id~=pc.id)then A.history_cancel(unit,why)end
 end
 local function sample(pc,pl,why)
  if #report.samples<32 then report.samples[#report.samples+1]={op=pc.op,piece=pc.index,id=pc.id,placement=pl and pl.id,reason=why}end
 end
 for _,pl in pairs(st.places or{})do
  local op=st.ops and st.ops[tostring(pl.op)];local pc=op and op.pieces[tostring(pl.piece)]
  if pc and not modern(pl)and(pl.state=='pending-receipt'or pl.state=='reserved'or pl.state=='delegated'or(pl.state=='copy'and get(pl.ghost_unit)))then
   local live_right=active(pc)and not copy_recipient(op,pc,pl.player,pl)
   if live_right or pl.state=='copy'then
    local why='legacy pending receipt lacks same-input creation/merge observation; identity unresolved'
    pl.state='ambiguous';pl.native_merge_legacy_unverified=true;pl.lineage_ambiguous=true
    if live_right then pc.ambiguous=true;invalidate(pc,why)end
    annotate(pl.ghost_unit,pc,why);annotate(pl.dest_unit,pc,why);cancel_history(pl.ghost_unit,pc,why)
    report.retired_receipts=report.retired_receipts+1;sample(pc,pl,why)
   end
  end
 end
 -- A selected child ghost can inherit an old unverified parent even when it
 -- has not yet been pasted. Never launder that old source via a new receipt.
 for _,op in pairs(st.ops or{})do for _,pc in pairs(op.pieces or{})do
  if active(pc)and pc.source_kind=='owned-cut-ghost'then
   local proof=type(pc.ghost_proof)=='table'and pc.ghost_proof;local parent=proof and st.places[tostring(proof.placement)]
   if not modern(parent)then
    local why='legacy owned ghost source lacks guarded parent creation proof'
    pc.source_lineage_unverified=true;pc.ambiguous=true;invalidate(pc,why)
    local pl=pc.placement and st.places[tostring(pc.placement)]
    if pl then pl.state='ambiguous';pl.lineage_ambiguous=true;annotate(pl.ghost_unit,pc,why);annotate(pl.dest_unit,pc,why)end
    annotate(pc.source_unit,pc,why);cancel_history(pc.source_unit,pc,why)
    report.retired_source_dependencies=report.retired_source_dependencies+1;sample(pc,pl,why)
   end
  end
 end end
 st.merge_guard_migration_v81=report
 if report.retired_receipts+report.retired_source_dependencies>0 then log('legacy-merge-permissions-retired',report)end
end
function M.ghost_deconstructed(e)
 M.migrate_legacy_merge_receipts()
 local ghost=e.ghost;if not(ghost and ghost.valid and ghost.unit_number)then return false end
 local s=S();local ptr=s.sources[tostring(ghost.unit_number)];local op=ptr and s.ops[tostring(ptr.op)];local pc=op and op.pieces[ptr.piece]
 if not(pc and pc.state=='selected'and pc.selected_tick==game.tick and op.player==e.player_index and get(pc.source_unit)==ghost)then return false end
 if pc.source_kind=='engine-death-ghost'then
  if not(A.delegate_ghost and A.delegate_ghost(ghost,pc.ghost_proof,op.id))then return false end
 elseif pc.source_kind=='owned-cut-ghost'or pc.source_kind=='accepted-ghost'then
  if pc.source_kind=='owned-cut-ghost'then
  local proof=pc.ghost_proof;local parent_op=proof and s.ops[tostring(proof.op)];local parent=parent_op and parent_op.pieces[tostring(proof.piece)];local pl=proof and s.places[tostring(proof.placement)]
  if not(parent and pl and parent.state=='reserved'and not parent.ambiguous and not parent.delegated_to and parent.id==pc.id and parent.placement==pl.id and pl.state=='reserved'and pl.approved and pl.ghost_unit==ghost.unit_number and not pl.dest_unit)then return false end
  parent.delegated_to=op.id;parent.state='delegated';pl.state='delegated'
  elseif not(A.delegate_accepted_ghost and A.delegate_accepted_ghost(ghost,pc.ghost_proof,op.id))then return false end
  op.ghost_body_inventories=op.ghost_body_inventories or{};local b=op.ghost_body_inventories[pc.name]
  if not b then
   local units,n=unit_set(pc.name);b={name=pc.name,tick=game.tick,units=units,before_count=n,expected=0,closed_count=0,closed={},members={}}
   for index,member in pairs(op.pieces)do if(member.source_kind=='owned-cut-ghost'or member.source_kind=='accepted-ghost')and member.name==pc.name then b.members[tostring(index)]=true;b.expected=b.expected+1 end end
   op.ghost_body_inventories[pc.name]=b
   s.pending_ghost_batches=s.pending_ghost_batches or{};s.pending_ghost_batches[tostring(op.id)..':'..pc.name]={op=op.id,name=pc.name}
  end
  pc.ghost_inventory_key=pc.name;pc.before_body_count=b.before_count
 else return false end
 pc.marked_tick=game.tick;pc.ghost_removal_tick=game.tick;pc.removal_kind='verified native '..pc.source_kind..' cut';pc.state='available'
 if A.ghost_removed_history then A.ghost_removed_history(e.player_index,ghost,pc.id)end
 log('native-ghost-source-removed',{op=op.id,piece=pc.index,id=pc.id,ghost=ghost.unit_number,player=e.player_index,proof=pc.ghost_proof});return true
end
function M.finalize_ghost_batches()
 local st=S();for key,ptr in pairs(st.pending_ghost_batches or{})do local op=st.ops[tostring(ptr.op)];local b=op and op.ghost_body_inventories and op.ghost_body_inventories[ptr.name]
  if not b or b.finished then st.pending_ghost_batches[key]=nil
  elseif game.tick-b.tick>2 then
   -- Deadline only rejects missing proof; elapsed time NEVER grants permission.
   b.finished=true;b.failed='not all selected native ghost lifetimes closed';b.units=nil;st.pending_ghost_batches[key]=nil
   for index in pairs(b.members)do local pc=op.pieces[index];pc.ambiguous=true;invalidate(pc,'owned ghost batch incomplete: exact native removal receipt missing')end
   log('owned-ghost-batch-incomplete',{op=op.id,name=b.name,closed=b.closed_count,expected=b.expected})
  end
 end
end
function M.pre_ghost_upgrade(e)
 local ghost=e.ghost;if not(ghost and ghost.valid and ghost.unit_number and e.target and e.quality)then return end
 for _,pl in pairs(S().places)do
  local op=S().ops[tostring(pl.op)];local pc=op and op.pieces[tostring(pl.piece)];local ex=pl.expected
  if pc and pc.state=='reserved'and not pc.ambiguous and pc.placement==pl.id and pl.state=='reserved'and pl.approved and pl.ghost_unit==ghost.unit_number and get(pl.ghost_unit)==ghost and not pl.dest_unit and ex and ex.name==ghost.ghost_name and ex.quality==ghost.quality.name then
   storage.vanilla_cut_upgrade_refs=storage.vanilla_cut_upgrade_refs or{};storage.vanilla_cut_upgrade_refs[tostring(pl.id)]=ghost
   pl.pending_upgrade={tick=game.tick,player=e.player_index,from=ghost.ghost_name,from_quality=ghost.quality.name,to=e.target.name,to_quality=e.quality.name}
   local st=S();st.pending_ghost_upgrades=st.pending_ghost_upgrades or{};st.pending_ghost_upgrades[tostring(pl.id)]=true
   if A.ghost_upgrade_frame then A.ghost_upgrade_frame{entity=ghost,player_index=e.player_index,target=e.target}end
   log('owned-ghost-upgrade-intent',{placement=pl.id,ghost=ghost.unit_number,transition=pl.pending_upgrade});return
  end
 end
end
function M.finalize_ghost_upgrades()
 local st=S();for key in pairs(st.pending_ghost_upgrades or{})do local pl=st.places[key];local u=pl and pl.pending_upgrade
  if not u then st.pending_ghost_upgrades[key]=nil
  elseif game.tick>u.tick then
   local ghost=get(pl.ghost_unit);local op=st.ops[tostring(pl.op)];local pc=op and op.pieces[tostring(pl.piece)];local ex=pl.expected
   if pc and pc.state=='reserved'and not pc.ambiguous and ghost and storage.vanilla_cut_upgrade_refs and storage.vanilla_cut_upgrade_refs[key]==ghost and ghost.type=='entity-ghost'and ghost.ghost_name==u.to and ghost.quality.name==u.to_quality and ghost.surface.index==ex.surface and ghost.position.x==ex.position.x and ghost.position.y==ex.position.y then
    ex.name=u.to;ex.quality=u.to_quality;pl.upgrade_count=(pl.upgrade_count or 0)+1;pl.last_upgrade=u;log('owned-ghost-upgrade-confirmed',{placement=pl.id,ghost=ghost.unit_number,transition=u})
   elseif pc and pc.state~='transferred'then pc.ambiguous=true;invalidate(pc,'pending ghost upgrade lacks exact post-event object confirmation')end
   pl.pending_upgrade=nil;st.pending_ghost_upgrades[key]=nil;if storage.vanilla_cut_upgrade_refs then storage.vanilla_cut_upgrade_refs[key]=nil end
  end
 end
end
-- An untagged template has no old identity to continue. Mint only copy-only
-- operation labels at the actual observed native build input. Stale Fabric tags
-- are not converted into permission; destination birth still needs full guards.
function M.prepare_new_blueprint(p,bp,model)
 if not ISSUER or not bp or not model or not next(model.entities or{})or next(model.tiles or{})then return false end
 for _,be in pairs(model.entities)do local tags=be.tags or{};if tags[TAG]~=nil or tags.fabric_pg_entity_v1~=nil or tags.fabric_pg_history_v1~=nil then return false end end
 local st=S();st.next_op=st.next_op+1;local n=st.next_op
 local op={id=n,issuer=ISSUER,issuer_required=true,player=p.index,mode='copy',tick=game.tick,input_tick=game.tick,pieces={},introduced_by='observed native untagged template input',input_serial=st.next_input}
 st.ops[tostring(n)]=op
 for _,be in pairs(model.entities)do
  local idx=tostring(be.entity_number);local label='new-template:'..n..':'..idx
  local pc={op=n,index=be.entity_number,id=label,source_kind='new-template',source_unit=0,source_surface=p.surface.index,name=be.name,quality=be.quality or'normal',state='copy',selected_tick=game.tick}
  op.pieces[idx]=pc;local tags=bp.get_blueprint_entity_tags(be.entity_number)or{};tags[TAG]={world=st.namespace,issuer=ISSUER,op=n,piece=be.entity_number,source=0,id=label};bp.set_blueprint_entity_tags(be.entity_number,tags)
 end
 log('new-template-copy-operation',{op=n,player=p.index,input=st.next_input,pieces=#model.entities});return true
end
function M.init(api)
 A=api
 script.on_event(defines.events.on_pre_ghost_upgraded,M.pre_ghost_upgrade)
 script.on_event(defines.events.on_pre_ghost_deconstructed,function(e)if not M.ghost_deconstructed(e)then M.invalidate_unit(e.ghost.unit_number,'ghost placement cancelled')end;if A.history_cancel then A.history_cancel(e.ghost.unit_number,'ghost placement cancelled')end end)
 for _,c in ipairs({'cut','copy','paste','clear-cursor','build','build-ghost','super-forced-build'})do script.on_event('fabric-pg-'..c,function(e)
  local s=S();local p=game.get_player(e.player_index)
  log('linked-'..c,{player=e.player_index,in_gui=e.in_gui,cursor={x=e.cursor_position.x,y=e.cursor_position.y},display=e.cursor_display_location and {x=e.cursor_display_location.x,y=e.cursor_display_location.y}or nil})
  if e.in_gui or not p or p.controller_type~=defines.controllers.character then return end
  if A.history_input then A.history_input(p.index,c)end
  if c=='cut' or c=='copy'then
   s.arms[p.index]={kind=c,tick=game.tick}
  elseif c=='clear-cursor'then s.arms[p.index]=nil;log('cursor-cleared',{player=p.index,transfer_tokens_retained=true})
  elseif c=='build'or c=='build-ghost'or c=='super-forced-build'then local cs=p.cursor_stack;local tool=cs and cs.valid_for_read and cs.name or nil;if not tool and p.cursor_record then tool='record:'..p.cursor_record.type end;s.cursor_epochs=s.cursor_epochs or {};s.next_input=(s.next_input or 0)+1;local bp=blueprint(p);local model,fingerprint=Geometry.capture(bp);if (tool=='blueprint'or tool=='blueprint-book'or tool=='record:blueprint'or tool=='record:blueprint-book')and M.prepare_new_blueprint(p,bp,model)then model,fingerprint=Geometry.capture(bp)end;local source_tags={};for _,be in pairs(model and model.entities or{})do local tag=be.tags and be.tags[TAG];if tag and tagpiece(tag)then source_tags[#source_tags+1]=tag end end;s.inputs[p.index]={serial=s.next_input,tick=game.tick,tool=tool,item_number=cs and cs.valid_for_read and cs.item_number or nil,kind=c,cursor={x=e.cursor_position.x,y=e.cursor_position.y},epoch=s.cursor_epochs[p.index]or 0,fingerprint=fingerprint,source_tags=source_tags};if tool=='cut-paste-tool'or tool=='copy-paste-tool'then local mode=tool=='cut-paste-tool'and'cut'or'copy';if not s.arms[p.index]or s.arms[p.index].kind~=mode then s.arms[p.index]={kind=mode,tick=game.tick,proof='observed native selection tool'}end end;log('build-tool',{player=p.index,tool=tool})
  end
 end)end
 script.on_event(defines.events.on_player_cursor_stack_changed,function(e)local s=S();s.cursor_epochs=s.cursor_epochs or {};s.cursor_epochs[e.player_index]=(s.cursor_epochs[e.player_index]or 0)+1 end)
 -- This callback follows installed Things' tag edits and captures its final mapping.
 -- The runtime blueprint reference is only local during the nested native event, never storage/logged.
 if script.active_mods['0-things']then script.on_event('cooperative-blueprinting-v1-on_post_extract',function(e)
  local map={};for index,v in pairs(e.mapping or {})do if v.valid then map[tostring(index)]={unit=v.unit_number,name=v.name,surface=v.surface.index}end end
  post={tick=game.tick,blueprint=e.blueprint,mapping=map}
  log('post-extract',{mapping=map})
 end)end
 script.on_event(defines.events.on_player_setup_blueprint,function(e)
  local s=S();local p=game.get_player(e.player_index);local arm=s.arms[e.player_index];s.arms[e.player_index]=nil
  local bp=p and blueprint(p,e.record,e.stack)
  local input=s.inputs[e.player_index]
  local ordinary_blueprint=input and (input.tool=='blueprint'or input.tool=='blueprint-book'or input.tool=='record:blueprint'or input.tool=='record:blueprint-book')
  if ordinary_blueprint then arm={kind='copy',tick=input.tick}end
  local tool_verified=arm and input and input.tick>=arm.tick and (ordinary_blueprint or input.tool==arm.kind..'-paste-tool')
  local eligible_profile=true;local allowed={base=true,quality=true,['elevated-rails']=true,['space-age']=true,recycler=true,['fabric-playground']=true,['fabric-adversary']=true,['fabric-undo']=true,['fabric-spike']=true}
  for name in pairs(script.active_mods)do if not allowed[name]then eligible_profile=false end end
  local direct_mapping={};local mapping_source
  if post and post.tick==game.tick and post.blueprint==bp then direct_mapping=post.mapping;mapping_source='cooperative post-extract'
  elseif not script.active_mods['0-things']and eligible_profile and e.mapping and e.mapping.valid then
   for index,v in pairs(e.mapping.get()or{})do if v.valid and v.unit_number then direct_mapping[tostring(index)]={unit=v.unit_number,name=v.name,surface=v.surface.index}end end
   mapping_source='native mapping in audited minimal profile'
  end
  local valid=tool_verified and bp and mapping_source and e.item=='blueprint' and (arm.kind=='cut' or arm.kind=='copy')
  local mapping=valid and direct_mapping or {};post=nil
  log('extraction-mapping-source',{source=mapping_source or 'unverified profile/mapping',minimal_profile=eligible_profile})
  log('native-selection',{player=e.player_index,alt=e.alt,selection_tool=input and input.tool or nil,observed=valid and arm.kind or 'unverified',mapping=mapping})
  if not valid then return end
  if not ISSUER then s.status='New cut/copy lineage unresolved: controlled launch issuer is missing.';log('issuer-unavailable',{player=p.index});return end
  local native={};if e.mapping and e.mapping.valid then for _,v in pairs(e.mapping.get() or {})do if v.valid and v.unit_number then native[v.unit_number]=v end end end
  local bps=bp.get_blueprint_entities() or {};local byindex={};for _,be in pairs(bps)do byindex[tostring(be.entity_number)]=be end
  s.next_op=s.next_op+1;local n=s.next_op;local op={id=n,issuer=ISSUER,issuer_required=true,player=p.index,mode=arm.kind,tick=game.tick,input_tick=arm.tick,pieces={}};s.ops[tostring(n)]=op
  for index,m in pairs(mapping)do
   local src=native[m.unit];local be=byindex[index]
   if src and src.valid and be and be.name==(src.type=='entity-ghost'and src.ghost_name or src.name) and A.eligible(src)then
    A.register(src,'unobserved');local r=entry(src);local ghost_proof=arm.kind=='cut'and src.type=='entity-ghost'and((A.ghost_source and A.ghost_source(src))or owned_ghost_source(src,p.index))
    if (src.type~='entity-ghost'and known(r))or ghost_proof or arm.kind=='copy'then
     local logical_id=ghost_proof and ghost_proof.id or r.id
     local old=s.latest[logical_id];if old and s.ops[tostring(old)]then for _,x in pairs(s.ops[tostring(old)].pieces)do if x.id==logical_id and not(ghost_proof and ghost_proof.kind=='owned-cut-ghost'and ghost_proof.op==old and tostring(x.index)==tostring(ghost_proof.piece))then invalidate(x,'new extraction of same logical piece')end end end
     local piece={op=n,index=tonumber(index),id=logical_id,source_kind=ghost_proof and ghost_proof.kind,ghost_proof=ghost_proof or nil,source_unit=src.unit_number,source_surface=src.surface.index,name=src.type=='entity-ghost'and src.ghost_name or src.name,quality=src.quality.name,state=arm.kind=='cut' and 'selected' or 'copy',pre_marked=src.to_be_deconstructed(),selected_tick=game.tick}
     op.pieces[index]=piece
     if arm.kind=='cut'then s.latest[logical_id]=n;s.sources[tostring(src.unit_number)]={op=n,piece=index}end
     ref(src)
     local tags=bp.get_blueprint_entity_tags(tonumber(index))or {};if arm.kind=='copy'then tags.fabric_pg_entity_v1=nil;tags.fabric_pg_history_v1=nil end;tags[TAG]={world=s.namespace,issuer=ISSUER,op=n,piece=tonumber(index),source=src.unit_number,id=logical_id};bp.set_blueprint_entity_tags(tonumber(index),tags)
     log('token-written',{op=n,piece=piece.index,id=piece.id,source=entity(src),mode=op.mode,other_tag_keys=(function()local keys={}for k in pairs(tags)do if k~=TAG then keys[#keys+1]=k end end;table.sort(keys);return keys end)()})
    end
   end
  end
  s.status='Extraction '..n..' ('..op.mode..'): waiting for verified deconstruction / paste.'
 end)
 script.on_event(defines.events.on_marked_for_deconstruction,function(e)
  if A.history_marked then A.history_marked(e)end
  local ptr=e.entity and S().sources[tostring(e.entity.unit_number)];local op=ptr and S().ops[tostring(ptr.op)];local piece=op and op.pieces[ptr.piece]
  if not piece then return end
  local ok=piece.state=='selected' and not piece.pre_marked and op.player==e.player_index and piece.selected_tick==game.tick
  log('source-marked',{op=op.id,piece=piece.index,unit=e.entity.unit_number,player=e.player_index,verified=ok})
  if ok then piece.marked_tick=game.tick;piece.state='available'else invalidate(piece,'mark lacked matching native cut selection')end
 end)
 script.on_event(defines.events.on_cancelled_deconstruction,function(e)if e.entity then
  local ptr=S().sources[tostring(e.entity.unit_number)];local op=ptr and S().ops[tostring(ptr.op)];local pc=op and op.pieces[ptr.piece];if pc then pc.source_cancelled=true end
  M.invalidate_unit(e.entity.unit_number,'deconstruction cancelled')
 end end)
 script.on_event(defines.events.on_robot_mined_entity,function(e)
  local ptr=S().sources[tostring(e.entity.unit_number)];local op=ptr and S().ops[tostring(ptr.op)];local piece=op and op.pieces[ptr.piece]
  if not piece then return end
  local r=entry(e.entity)
  if observes_source(piece,op)and piece.marked_tick and e.entity.to_be_deconstructed() and e.entity.force.name=='player' and e.robot.force==e.entity.force and r and r.id==piece.id then
   piece.mined_tick=game.tick;log('source-robot-mined',{op=op.id,piece=piece.index,source=entity(e.entity),robot=e.robot.unit_number})
  else invalidate(piece,'removal not matching verified robot cut')end
 end)
 script.on_event(defines.events.on_object_destroyed,function(e)
  if A.history_destroyed then A.history_destroyed(e)end
  local unit=S().objects[tostring(e.registration_number)];if not unit then return end;S().objects[tostring(e.registration_number)]=nil
  -- A destroyed object's queued callback can arrive after revival reused its
  -- unit number. A currently valid reference is a different living object.
  local current=storage.vanilla_cut_refs[unit]
  if current and current.valid then log('stale-object-destroyed',{unit=unit,registration=e.registration_number});return end
  storage.vanilla_cut_refs[unit]=nil
  log('object-destroyed',{unit=unit,registration=e.registration_number})
  local ptr=S().sources[tostring(unit)];local op=ptr and S().ops[tostring(ptr.op)];local piece=op and op.pieces[ptr.piece]
  if piece and observes_source(piece,op)then
   local removal_tick=piece.ghost_removal_tick or piece.mined_tick
   if removal_tick and game.tick-removal_tick<=2 then if ghost_source_closed(piece)and owned_ghost_closed(piece)then piece.source_removed=true;piece.removed_tick=game.tick;try_transfer(piece)end
   else piece.source_provenance_invalid=true;invalidate(piece,'source disappeared without verified cut robot removal')end
  end
  for _,pl in pairs(S().places)do if pl.ghost_unit==unit then pl.ghost_destroyed=true;pl.ghost_destroyed_tick=game.tick;local o=S().ops[tostring(pl.op)];local pc=o and o.pieces[tostring(pl.piece)];if pc then try_transfer(pc)end end end
 end)
 script.on_event(defines.events.on_tick,function()
  M.migrate_legacy_merge_receipts()
  M.finalize_ghost_batches()
  M.finalize_ghost_upgrades()
  M.finalize_receipts()
  for _,op in pairs(S().ops)do for _,piece in pairs(op.pieces)do
   if piece.state=='reserved'then try_transfer(piece)
   elseif piece.state=='invalid'and piece.ambiguous and not piece.ambiguity_readout_refreshed then invalidate(piece,piece.invalid_reason or 'saved ambiguous cut lineage')
   elseif piece.state=='selected' and game.tick>piece.selected_tick then invalidate(piece,'native selection did not mark source')end
  end end
  if A.history_tick then A.history_tick()end
 end)
end
local function token_key(tag)
 if type(tag)~='table'then return '<invalid-token>'end
 local legacy=tostring(tag.world)..'/'..tostring(tag.op)..'/'..tostring(tag.piece)..'/'..tostring(tag.source)..'/'..tostring(tag.id)
 return tag.issuer and legacy..'@'..tostring(tag.issuer)or legacy
end
function M.verify_prebuild(input,e,tick,epoch)
 if not input then return false end
 local t=input.tool;local supported=t=='blueprint'or t=='blueprint-book'or t=='record:blueprint'or t=='record:blueprint-book'
 local modes={build=0,['build-ghost']=1,['super-forced-build']=2}
 if not supported or modes[input.kind]~=e.build_mode or input.epoch~=epoch then return false end
 if e.created_by_moving==true then return true end
 if tick<input.tick or tick-input.tick>1 or not input.cursor then return false end
 return math.abs(input.cursor.x-e.position.x)<=1/256 and math.abs(input.cursor.y-e.position.y)<=1/256
end
local function ambiguous_input(player,serial,why)
 local s=S();local input=s.inputs[player];if input and input.serial==serial then for _,tag in pairs(input.source_tags or{})do local op,pc=tagpiece(tag);if pc and op.mode=='cut'and not copy_recipient(op,pc,player,{tick=game.tick})then pc.ambiguous=true;invalidate(pc,why)end end end
 for _,pl in pairs(s.places)do if pl.player==player and pl.input_serial==serial and pl.state=='pending-receipt'then
  pl.input_ambiguity=true;local op=s.ops[tostring(pl.op)];local pc=op and op.pieces[tostring(pl.piece)]
  if pc and op.mode=='cut'and not copy_recipient(op,pc,player,pl)then pc.ambiguous=true;invalidate(pc,why)end
 end end
 s.ambiguous_input=s.ambiguous_input or{};s.ambiguous_input[player]=serial
 log('native-input-unresolved',{player=player,serial=serial,reason=why})
end
function M.pre(e)
 local s=S();s.prebuild=s.prebuild or {};s.cursor_epochs=s.cursor_epochs or {};local input=s.inputs[e.player_index];local p=game.get_player(e.player_index);local bp=blueprint(p)
 local model,fingerprint=Geometry.capture(bp)
 local frame={tick=game.tick,surface=p.surface.index,position={x=e.position.x,y=e.position.y},build_mode=e.build_mode,tokens={},expected={},created_by_moving=e.created_by_moving,direction=e.direction or 0,flip_horizontal=e.flip_horizontal or false,flip_vertical=e.flip_vertical or false,input_serial=input and input.serial}
 local base=M.verify_prebuild(input,e,game.tick,s.cursor_epochs[e.player_index]or 0)
 frame.template_matches=input and input.fingerprint~=nil and input.fingerprint==fingerprint or false
 frame.input_verified=base and frame.template_matches
 if base and not frame.template_matches then ambiguous_input(e.player_index,input.serial,'clipboard model changed after linked input')end
 frame.geometry=Geometry.project(model,e)
 if bp and frame.input_verified then for _,be in pairs(model.entities)do
  local tags=bp.get_blueprint_entity_tags(be.entity_number);local tag=tags and tags[TAG]
  if tag and tagpiece(tag)then local k=token_key(tag);frame.tokens[k]=(frame.tokens[k]or 0)+1;frame.expected[k]=frame.geometry.supported and frame.geometry.entities[tostring(be.entity_number)]or nil end
 end end
 s.next_frame=(s.next_frame or 0)+1;frame.id=s.next_frame
 local previous=s.prebuild[e.player_index]
 if previous and previous.tick==game.tick and previous.input_verified and previous.input_serial==frame.input_serial and (not e.created_by_moving or(previous.position.x==frame.position.x and previous.position.y==frame.position.y))then
  ambiguous_input(e.player_index,frame.input_serial,'additional non-moving or same-anchor pre-build callback for one observed native input; conflicting API prebuild cannot borrow the retained frame');frame.input_ambiguity=true
 end
 if frame.input_verified and previous and previous.tick==game.tick and previous.input_verified and previous.input_serial==frame.input_serial and (previous.direction~=frame.direction or previous.flip_horizontal~=frame.flip_horizontal or previous.flip_vertical~=frame.flip_vertical)then
  ambiguous_input(e.player_index,frame.input_serial,'conflicting pre-build transforms for one observed native input');frame.input_ambiguity=true
 end
 if frame.input_verified or not(previous and previous.tick==game.tick and previous.input_verified)then s.prebuild[e.player_index]=frame end
 for key,count in pairs(frame.tokens)do if count>1 then for _,be in pairs(model.entities)do local ts=bp.get_blueprint_entity_tags(be.entity_number);local tag=ts and ts[TAG];if tag and token_key(tag)==key then local op,pc=tagpiece(tag);if pc and not copy_recipient(op,pc,e.player_index,{tick=game.tick})then pc.ambiguous=true;invalidate(pc,'unconsumed piece token duplicated within native blueprint')end end end end end
 local sample={};local n=0;for k,v in pairs(frame.tokens)do n=n+1;if n<=32 then sample[k]=v end end
 log('prebuild-receipt',{player=e.player_index,input=input and {serial=input.serial,tick=input.tick,tool=input.tool,kind=input.kind,cursor=input.cursor,epoch=input.epoch,fingerprint_length=input.fingerprint and #input.fingerprint},frame={tick=frame.tick,id=frame.id,position=frame.position,build_mode=frame.build_mode,tokens=sample,token_count=n,created_by_moving=frame.created_by_moving,input_verified=frame.input_verified,template_matches=frame.template_matches,direction=frame.direction,flip_horizontal=frame.flip_horizontal,flip_vertical=frame.flip_vertical,geometry_supported=frame.geometry.supported,geometry_reason=frame.geometry.reason}})
end
function M.built(e)
 M.migrate_legacy_merge_receipts()
 if not A.eligible(e.entity)then return false end
 local tags=e.entity.type=='entity-ghost' and e.entity.tags or e.tags
 local tag=tags and tags[TAG];if tag==nil then return false end
 if type(tag)~='table'then A.register(e.entity,'recreated-or-blueprint');if e.entity.type=='entity-ghost'then tags[TAG]=nil;e.entity.tags=tags end;log('malformed-cut-metadata',{unit=e.entity.unit_number,value_type=type(tag)});return true end
 if e.entity.type=='entity-ghost' and tag.placement then local clean={};for k,v in pairs(tag)do if k~='placement'then clean[k]=v end end;tags[TAG]=clean;e.entity.tags=tags;tag=clean end
 local op,piece=tagpiece(tag);A.register(e.entity,'recreated-or-blueprint')
 log('tagged-built',{entity=entity(e.entity),tag=tag,player=e.player_index,known_token=piece~=nil})
 if not piece then return true end
 revalidate_manual_source(op,piece)
 if piece.ambiguous then log('placement-unresolved',{reason='prior ambiguous lineage requires inspection; collecting native receipt without claiming',unit=e.entity.unit_number})end
 local input=S().inputs[e.player_index];-- Native input precedes the built callback by zero or one tick in measured 2.1.24.
 local frame=S().prebuild and S().prebuild[e.player_index]
 local expected=frame and frame.expected and frame.expected[token_key(tag)];local logical=e.entity.type=='entity-ghost'and e.entity.ghost_name or e.entity.name
 local native=frame and frame.tick==game.tick and frame.input_verified and not frame.input_ambiguity and not(S().ambiguous_input and S().ambiguous_input[e.player_index]==frame.input_serial) and frame.tokens[token_key(tag)]==1 and expected and expected.name==logical and expected.quality==e.entity.quality.name and expected.position.x==e.entity.position.x and expected.position.y==e.entity.position.y
 if not native and frame and frame.tick==game.tick and frame.input_verified and frame.geometry and not frame.geometry.supported and op.mode=='cut'and piece.state=='available'and not copy_recipient(op,piece,e.player_index,{tick=game.tick})then piece.ambiguous=true;invalidate(piece,'native clipboard placement geometry unsupported: '..tostring(frame.geometry.reason))end
 if not native then log('placement-unverified',{reason='no matching position/mode/template prebuild receipt',unit=e.entity.unit_number});return true end
 local logical_name=e.entity.type=='entity-ghost'and e.entity.ghost_name or e.entity.name
 if M.can_reserve(op,piece,e.player_index,S().latest[piece.id])and (piece.name~=logical_name or piece.quality~=e.entity.quality.name)then
  piece.ambiguous=true;invalidate(piece,'clipboard prototype/quality differs from selected source without causal upgrade proof')
  log('placement-unresolved',{unit=e.entity.unit_number,reason='edited source template',source_name=piece.name,destination_name=logical_name,source_quality=piece.quality,destination_quality=e.entity.quality.name})
  -- Keep the exact native ghost receipt ONLY as unresolved evidence. This
  -- already-invalidated piece can never reserve/transfer; its candidate must
  -- survive construction, including cross-prototype edits, without a guess.

 end
 S().next_place=S().next_place+1;local num=S().next_place
 local pl={id=num,op=op.id,piece=piece.index,player=e.player_index,tick=game.tick,state='pending-receipt',merge_guard_version=80,copy_merge_guard_version=91,native_action_guard_version=99,native_moving_pre=frame.created_by_moving==true,lineage_ambiguous=piece.ambiguous or false,frame=frame.id,input_serial=frame.input_serial,token=token_key(tag),expected={name=e.entity.type=='entity-ghost'and e.entity.ghost_name or e.entity.name,quality=e.entity.quality.name,surface=e.entity.surface.index,position={x=e.entity.position.x,y=e.entity.position.y}}};S().places[tostring(num)]=pl;S().native_birth_index=nil
 -- Do not consume provenance until the entire engine callback tick has completed.
 -- A second exact token receipt in this batch is ambiguity, not a second proven copy.
 if e.entity.type=='entity-ghost'then
  pl.ghost_unit=e.entity.unit_number;ref(e.entity)
  local tags=e.entity.tags or {};local receipt={world=tag.world,issuer=tag.issuer,op=tag.op,piece=tag.piece,source=tag.source,id=tag.id,placement=num};tags[TAG]=receipt;e.entity.tags=tags
 else
  pl.dest_unit=e.entity.unit_number;ref(e.entity)
  -- Approval is deferred; direct builds cannot claim an ID mid-callback batch.
 end
 if piece.ambiguous then unresolved_candidate(e.entity,piece,'native placement with unresolved source lineage')end
 log('placement',{id=num,op=op.id,piece=piece.index,mode=pl.state,entity=entity(e.entity)})
 return true
end
function M.observe_merge(e)
 local en=e.entity;if not(en and en.valid)then return end
 local s=S();local frame=s.prebuild and s.prebuild[e.player_index]
 if not(frame and frame.tick==game.tick and frame.input_verified)then return end
 local bp=blueprint(game.get_player(e.player_index));if not bp then return end
 local name=en.type=='entity-ghost'and en.ghost_name or en.name
 for _,be in pairs(bp.get_blueprint_entities()or{})do local ts=bp.get_blueprint_entity_tags(be.entity_number);local tag=ts and ts[TAG];local op,pc=tagpiece(tag)
  local expected=pc and frame.expected and frame.expected[token_key(tag)]
  local at_destination=expected and frame.surface==en.surface.index and expected.name==name and expected.quality==en.quality.name and expected.position.x==en.position.x and expected.position.y==en.position.y
  if pc and pc.name==name and pc.quality==en.quality.name and (at_destination or not(frame.geometry and frame.geometry.supported))then
   local own=false;local same_input_birth=false
   for _,pl in pairs(s.places)do if pl.op==op.id and pl.piece==pc.index and pl.ghost_unit==en.unit_number and not pl.ghost_destroyed then
    own=true
    -- An API can emit built AFTER our pre-build listener, then vanilla merges
    -- into that already-existing ghost. Its earlier callback is not proof of
    -- native birth. Older / independently pressed own plans remain unaffected.
    if pl.tick==game.tick and pl.player==e.player_index and pl.input_serial==frame.input_serial and pl.state=='pending-receipt'then same_input_birth=true end
   end end
   if not own or same_input_birth then
    frame.merged_tokens=frame.merged_tokens or{};frame.merged_tokens[token_key(tag)]=true
    for _,pl in pairs(s.places)do if pl.tick==game.tick and pl.player==e.player_index and pl.token==token_key(tag)and pl.state=='pending-receipt'then pl.native_merge_ambiguity=true;local moving=pl.native_moving_pre and frame.created_by_moving==true;pl.moving_merge_observed=pl.moving_merge_observed or moving;pl.native_merge_requires_strict=pl.native_merge_requires_strict or not moving end end
    local why=same_input_birth and'native merge into same-input pending ghost cannot prove its creation origin'or'native clipboard merged into an existing entity without a new-piece receipt'
    if op.mode=='cut'and not copy_recipient(op,pc,e.player_index,{tick=game.tick})and(pc.state=='available'or same_input_birth)then pc.ambiguous=true;invalidate(pc,why)end
    unresolved_candidate(en,pc,why)
    log('native-merge-unresolved',{op=op.id,piece=pc.index,target=entity(en),frame=frame.id,same_input_birth=same_input_birth})
   end
  end
 end
end
function M.settings_pasted(e)
 local en=e.entity;if not(en and en.valid and en.type=='entity-ghost')then return end
 local s=S();local found={}
 for _,pl in pairs(s.places)do if pl.ghost_unit==en.unit_number and get(pl.ghost_unit)==en and not pl.dest_unit and not pl.ghost_destroyed and (pl.state=='pending-receipt'or pl.state=='reserved'or pl.state=='copy'or pl.state=='ambiguous')then found[#found+1]=pl end end
 local tags=en.tags or{};local incoming=tags[TAG]
 if incoming~=nil and type(incoming)~='table'then tags[TAG]=nil
 elseif incoming and incoming.placement then local clean={};for k,v in pairs(incoming)do if k~='placement'then clean[k]=v end end;tags[TAG]=clean end
 if #found==1 then
  local pl=found[1];local op=s.ops[tostring(pl.op)];local pc=op and op.pieces[tostring(pl.piece)];local v=pl.expected
  -- An ambiguous receipt carries candidate readout only. Its saved state
  -- remains ambiguous; robot construction cannot grant transfer rights.
  if pc and v and v.name==en.ghost_name and v.quality==en.quality.name and v.surface==en.surface.index and v.position.x==en.position.x and v.position.y==en.position.y then
   tags[TAG]={world=s.namespace,issuer=op.issuer,op=op.id,piece=pc.index,source=pc.source_unit,id=pc.id,placement=pl.id}
   log('ghost-receipt-restored-after-settings-paste',{ghost=en.unit_number,placement=pl.id,op=op.id,piece=pc.index})
  end
 end
 en.tags=tags
end
function M.robot_built(e,job)
 M.migrate_legacy_merge_receipts()
 if not A.eligible(e.entity)then return false end
 local tag=e.tags and e.tags[TAG];if not tag then return false end
 A.register(e.entity,'robot-recreated');if type(tag)~='table'then log('malformed-robot-cut-metadata',{unit=e.entity.unit_number,value_type=type(tag)});return true end;local op,piece=tagpiece(tag);local pl=tag.placement and S().places[tostring(tag.placement)]
 log('robot-built',{entity=entity(e.entity),tag=tag,robot=e.robot.unit_number})
 if piece then revalidate_manual_source(op,piece)end
 if not piece or not pl or pl.op~=op.id or pl.piece~=piece.index or not pl.ghost_unit or pl.dest_unit then return true end
 -- Receipt is minted on this exact native-created ghost, then carried by engine revival.
 local expected=pl.expected;if not expected or expected.name~=e.entity.name or expected.quality~=e.entity.quality.name or expected.surface~=e.entity.surface.index or expected.position.x~=e.entity.position.x or expected.position.y~=e.entity.position.y then if Jobs.matches(job,pl.ghost_unit)then if not copy_recipient(op,piece,pl.player,pl)then piece.ambiguous=true;invalidate(piece,'exact owned ghost robot receipt changed prototype/quality without confirmed upgrade')end;pl.approved=false;pl.state='ambiguous';pl.lineage_ambiguous=true;unresolved_candidate(e.entity,piece,'exact ghost robot receipt: unconfirmed prototype/quality transition')end;log('revival-mismatch',{placement=pl.id,entity=entity(e.entity)});return true end
 local job_ok,job_reason=Jobs.matches(job,pl.ghost_unit);if not job_ok then log('revival-job-rejected',{placement=pl.id,reason=job_reason});return true end
 local ghost=get(pl.ghost_unit);if ghost then log('ghost-still-valid',{placement=pl.id});return true end
 pl.dest_unit=e.entity.unit_number;pl.built_tick=game.tick;ref(e.entity)
 if piece.ambiguous or pl.state=='ambiguous'then unresolved_candidate(e.entity,piece,'exact native ghost robot receipt; source identity unresolved')end
 if pl.state=='reserved' and piece.state=='reserved' and piece.placement==pl.id then try_transfer(piece)
 elseif pl.approved and pl.state=='copy'then finish_copy(pl,op)
 end
 return true
end
function M.finalize_receipts()
 M.migrate_legacy_merge_receipts()
 local s=S();local counts={}
 -- Upgrade saved pre-v15 ambiguous batches without resurrecting permission.
 for _,pl in pairs(s.places)do if pl.state=='ambiguous'then local o=s.ops[tostring(pl.op)];local pc=o and o.pieces[tostring(pl.piece)];if pc and not copy_recipient(o,pc,pl.player,pl)then pc.ambiguous=true;invalidate(pc,'saved ambiguous receipt batch')end end end
 for _,pl in pairs(s.places)do if pl.state=='pending-receipt' and pl.tick<game.tick then local k=pl.tick..'/'..pl.player..'/'..pl.token;counts[k]=(counts[k]or 0)+1 end end
 for _,pl in pairs(s.places)do if pl.state=='pending-receipt' and pl.tick<game.tick then
  local k=pl.tick..'/'..pl.player..'/'..pl.token
  local op=s.ops[tostring(pl.op)];local pc=op and op.pieces[tostring(pl.piece)]
  if pc then revalidate_manual_source(op,pc)end
  -- Fresh copies do not compete for an old logical ID. Each still waits for
  -- its own exact native built-action receipt; one API-only birth stays unknown.
  -- Multiple unconsumed cut destinations must never pick a first callback.
  local copy_only=copy_recipient(op,pc,pl.player,pl)
  local merge_unverified=pl.native_merge_ambiguity and not(copy_only and pl.native_moving_pre and pl.moving_merge_observed and not pl.native_merge_requires_strict)
  if (counts[k]~=1 and not copy_only)or not pc or pc.ambiguous or pl.lineage_ambiguous or merge_unverified or pl.input_ambiguity then local why=pc and pc.ambiguous and(pc.invalid_reason or 'source lineage already ambiguous')or'multiple independent receipts or conflicting input in one native batch';pl.state='ambiguous';if pc and not copy_only then pc.ambiguous=true;invalidate(pc,why)end;log('receipt-ambiguous',{placement=pl.id,count=counts[k],op=pl.op,piece=pl.piece,reason=why});s.status='Ambiguous clipboard receipts: identity unresolved; no first-callback claim.'
  else
   pl.approved=true
   if M.can_reserve(op,pc,pl.player,s.latest[pc.id])then pc.state='reserved';pc.placement=pl.id;pl.state='reserved';try_transfer(pc)
   else pl.state='copy';finish_copy(pl,op)end
   log('receipt-approved',{placement=pl.id,state=pl.state,op=pl.op,piece=pl.piece})
  end
 end end
end
function M.can_reserve(op,piece,player,latest)
 return op.mode=='cut' and op.player==player and piece.state=='available' and latest==op.id and piece.marked_tick~=nil and piece.marked_tick==piece.selected_tick and not piece.pre_marked
end
-- Attach native history only through the original exact unit and callback tick.
function M.history_bound(h)
 if h.type=='built-entity'and h.frame_receipt_version==96 and h.current_unit and h.event_tick and h.event_tick<game.tick then
  local st=S();local index=st.native_birth_index
  if not index then index={};st.native_birth_index=index;for _,pl in pairs(st.places)do local unit=pl.ghost_unit or pl.dest_unit;if unit then local key=pl.player..'/'..pl.tick..'/'..unit;local list=index[key]or{};index[key]=list;list[#list+1]=pl.id end end end
  local unit=h.ghost_unit or h.current_unit;local list=index[h.player..'/'..h.event_tick..'/'..unit]or{}
  if #list==1 then local pl=st.places[tostring(list[1])]
   if pl and pl.native_action_guard_version==99 and pl.approved and(pl.state=='reserved'or pl.state=='copy'or pl.state=='delegated')and not pl.native_action_birth then
    pl.history_action=h.id;pl.native_action_birth={action=h.id,player=h.player,receipt_unit=unit,event_tick=h.event_tick,kind='exact native stack built-action binding',receipt_version=96};pl.awaiting_native_birth=nil
    local op=st.ops[tostring(pl.op)];local pc=op and op.pieces[tostring(pl.piece)]
    if pl.state=='reserved'or pl.state=='delegated'then h.cut_placement=pl.id;if pc then try_transfer(pc)end elseif op then finish_copy(pl,op)end
    log('clipboard-native-birth-bound',{action=h.id,placement=pl.id,receipt_unit=unit})
   end
  end
 end
 if h.type~='removed-entity' or not h.current_unit or not h.event_tick then return end
 local s=S();local ptr=s.sources[tostring(h.current_unit)];local op=ptr and s.ops[tostring(ptr.op)];local pc=op and op.pieces[ptr.piece]
 if pc and not pc.history_action and op.player==h.player and pc.id==h.logical_id and pc.selected_tick==h.event_tick and pc.marked_tick==h.event_tick then pc.history_action=h.id;if s.history_source_index then local k=tostring(h.id);if s.history_source_index[k]then s.history_source_index[k].duplicate=true else s.history_source_index[k]={op=op.id,piece=tostring(pc.index)}end end;log('cut-history-bound',{op=op.id,piece=pc.index,action=h.id,unit=h.current_unit})end
end
function M.retire_unverified_legacy_births()
 local st=S();if st.native_birth_migration_v99 then return end
 local report={tick=game.tick,retired=0,settled_not_reclassified=0,reason='Saved pending birth lacks stable exact runtime plus non-conflicting pre-build receipt version99; old callback correlation cannot be retroactively proved'}
 for _,pl in pairs(st.places)do if pl.approved and(pl.state=='reserved'or pl.state=='copy'or pl.state=='delegated')and not native_birth(pl)then
  local dest=get(pl.dest_unit);local row=dest and entry(dest)
  if known(row)and dest.type~='entity-ghost'then report.settled_not_reclassified=report.settled_not_reclassified+1
  else
   pl.approved=false;pl.state='ambiguous';pl.native_birth_legacy_unverified=true;report.retired=report.retired+1
   if pl.history_action and A.history_reject_birth then A.history_reject_birth(pl.history_action,report.reason)end
   local op=st.ops[tostring(pl.op)];local pc=op and op.pieces[tostring(pl.piece)]
   if pc then if not copy_recipient(op,pc,pl.player,pl)then pc.ambiguous=true;invalidate(pc,report.reason)end;for _,unit in pairs{pl.ghost_unit,pl.dest_unit}do local en=get(unit);if en then unresolved_candidate(en,pc,report.reason)end end end
  end
 end end
 st.native_birth_migration_v99=report
end
function M.native_birth_scan_complete(player,tick)
 local st=S()
 for _,pl in pairs(st.places)do if pl.player==player and pl.tick==tick and pl.approved and(pl.state=='reserved'or pl.state=='copy'or pl.state=='delegated')and not native_birth(pl)then
  pl.approved=false;pl.state='ambiguous';pl.native_action_missing={scanned_tick=game.tick,event_tick=tick};pl.awaiting_native_birth=nil
  local op=st.ops[tostring(pl.op)];local pc=op and op.pieces[tostring(pl.piece)]
  if pc then if not copy_recipient(op,pc,pl.player,pl)then pc.ambiguous=true;invalidate(pc,'destination has no unique native built action in completed engine stack scan')end;for _,unit in pairs{pl.ghost_unit,pl.dest_unit}do local en=get(unit);if en then unresolved_candidate(en,pc,'Destination birth unresolved: no unique matching native built action after completed stack scan')end end end
  log('clipboard-native-birth-missing',{placement=pl.id,player=player,event_tick=tick})
 end end
end
-- History must prove exact tagged native redo and a unique creation callback.
function M.history_recreated(h,en,kind)
 M.migrate_legacy_merge_receipts()
 if kind~='redo'or en.type~='entity-ghost'or not A.eligible(en)or not h.cut_placement then return false end
 local s=S();local old=s.places[tostring(h.cut_placement)];local op=old and s.ops[tostring(old.op)];local pc=op and op.pieces[tostring(old.piece)]
 if not pc or not native_birth(old)or old.history_action~=h.id or op.player~=h.player or h.current_unit~=old.ghost_unit or not old.approved or old.state~='reserved'or pc.placement~=old.id or pc.ambiguous or pc.source_cancelled or pc.source_provenance_invalid or s.latest[pc.id]~=op.id then return false end
 if pc.state~='invalid'or pc.invalid_reason~='ghost placement cancelled'or not old.ghost_destroyed or get(old.ghost_unit)or old.dest_unit then return false end
 local row=entry(en);if not row or known(row)then return false end
 local src=get(pc.source_unit);local sr=src and entry(src)
 if not pc.source_removed and not(src and known(sr)and sr.id==pc.id and src.to_be_deconstructed())then return false end
 local ex=old.expected
 if not ex or ex.surface~=en.surface.index or ex.name~=en.ghost_name or ex.quality~=en.quality.name or ex.position.x~=en.position.x or ex.position.y~=en.position.y then return false end
 s.next_place=s.next_place+1;local n=s.next_place
 local pl={id=n,op=op.id,piece=pc.index,player=op.player,tick=game.tick,state='reserved',approved=true,ghost_unit=en.unit_number,expected=ex,history_action=h.id,history_predecessor=old.id,merge_guard_version=80,birth_path='native-history-redo',native_action_guard_version=99,native_action_birth={action=h.id,player=h.player,receipt_unit=en.unit_number,event_tick=game.tick,kind='verified applied native redo',receipt_version=96}}
 s.places[tostring(n)]=pl;s.native_birth_index=nil;pc.state='reserved';pc.invalid_reason=nil;pc.placement=n;h.cut_placement=n
 local tags=en.tags or{};tags[TAG]={world=s.namespace,issuer=op.issuer,op=op.id,piece=pc.index,source=pc.source_unit,id=pc.id,placement=n};en.tags=tags;ref(en)
 old.state='history-superseded';log('cut-destination-native-redo-receipt',{action=h.id,old_placement=old.id,placement=n,ghost=en.unit_number,source=pc.source_unit});return true
end
function M.history_redeconstructed(h,en,kind)
 local s=S();local ptr=s.sources[tostring(en.unit_number)];local op=ptr and s.ops[tostring(ptr.op)];local pc=op and op.pieces[ptr.piece];local r=entry(en)
 if kind~='redo' or not pc or pc.history_action~=h.id or h.current_unit~=en.unit_number or h.logical_id~=pc.id or op.player~=h.player or s.latest[pc.id]~=op.id then return end
 if pc.state=='invalid'and pc.invalid_reason=='ghost placement cancelled'and pc.source_cancelled and not pc.source_provenance_invalid and not pc.ambiguous and not pc.source_removed and not pc.mined_tick and known(r)and r.id==pc.id and en.to_be_deconstructed()then
  pc.source_cancelled=nil;pc.remarked_tick=game.tick;pc.remarked_action=h.id;log('cut-source-native-redo-reverified-awaiting-destination',{op=op.id,piece=pc.index,action=h.id,unit=en.unit_number});return
 end
 if pc.state~='invalid'or pc.invalid_reason~='deconstruction cancelled'or pc.ambiguous or pc.source_removed or pc.mined_tick or not known(r)or r.id~=pc.id or not en.to_be_deconstructed()then return end
 pc.state='available';pc.invalid_reason=nil;pc.source_cancelled=nil;pc.remarked_tick=game.tick;pc.remarked_action=h.id
 log('cut-history-rearmed',{op=op.id,piece=pc.index,action=h.id,unit=en.unit_number})
end
function M.invalidate_id(id,why)for _,op in pairs(S().ops)do for _,piece in pairs(op.pieces)do if piece.id==id then invalidate(piece,why)end end end end
function M.test_tag(tag)return tagpiece(tag)~=nil end
function M.status()return S().status end
function M.issuer()return ISSUER end
function M.input(player)return S().inputs[player]end
function M.cursor_epoch(player)return(S().cursor_epochs or{})[player]or 0 end
function M.snapshot()return S()end
return M
