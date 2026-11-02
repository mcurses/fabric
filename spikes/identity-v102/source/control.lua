local RobotJobs=require('robot-jobs')
local LoadedBuild=require('loaded-build')
-- Experimental snapshot UI. Unit continuity is evidence only within a living entity.
-- Namespaced clipboard/ghost receipts extend native cut; other mods' tags are preserved.
local G={}
local Wires=require('wires')
local BlueprintArea=require('blueprint-area')
local PlacementGeometry=require('placement-geometry')
remote.add_interface('fabric-placement-geometry',{project=function(model,pre)return PlacementGeometry.project(model,pre)end})
local function state()
 storage.playground=storage.playground or {next_id=0,surfaces={},pages={}}
 return storage.playground
end
local function sid(surface) return tostring(surface.index) end
local Eligibility=require('eligibility')
local eligible=Eligibility.test
remote.add_interface('fabric-blueprint-eligibility',{report=Eligibility.report})
local function alloc(prefix)
 local s=state();s.next_id=s.next_id+1;return prefix..s.next_id
end
local function scope(surface)
 local st=state();local k=sid(surface)
 if not st.surfaces[k] then st.surfaces[k]={surface=surface.index,name=surface.name,revision=0,baseline={},units={},last={title='Initial baseline; no commits yet.',lines={}},initialized=false} end
 return st.surfaces[k]
end
local function registry()
 local st=state();if st.global_units and storage.fabric_runtime_refs then return st.global_units end
 local prior=st.global_units;local rows=prior or{};local refs={}
 st.registrations=st.registrations or{};st.registry_conflicts=st.registry_conflicts or{}
 -- One complete live-world migration populates exact runtime references,
 -- including known rows moved to another force/surface. The engine unit lookup
 -- API is insufficient: many blueprintable prototypes lack its required flag.
 for _,sf in pairs(game.surfaces)do for _,en in pairs(sf.find_entities())do
  if en.unit_number then local key=tostring(en.unit_number);local row=prior and prior[key]
   if not prior then local labels={};local n=0
    for _,other in pairs(st.surfaces)do local r=other.units[key];if r then row=row or r;if not labels[r.id]then labels[r.id]=true;n=n+1 end end end
    if row and n>1 then st.registry_conflicts[#st.registry_conflicts+1]={unit=en.unit_number,labels=labels};row.id=alloc('U');row.reason='registry-conflict'end
   end
   if row then rows[key]=row;refs[key]=en end
  end
 end end
 st.global_units=rows;storage.fabric_runtime_refs=refs
 return rows
end
local function runtime_row(e)return e and e.unit_number and registry()[tostring(e.unit_number)]end
local Registration=require('runtime-registration')
Registration.init{state=state,registry=registry,scope=scope,alloc=alloc,eligible=eligible}
local Death
local function register(e,reason)local row=Registration.register(e,reason);if row and Death then Death.observed(e)end;return row end

local RuntimeOwners=require('runtime-owners');RuntimeOwners.init(registry,function()return storage.fabric_runtime_refs end)
local function live_ids()return RuntimeOwners.live_ids()end
local Cut=require('cut')
local History=require('history')
Death=require('death-ghost')
local Direct=require('direct-placement')
local MinedItems=require('mined-items');MinedItems.init{scope=scope,register=register,eligible=eligible,live_ids=live_ids,input=Cut.input,direct_ready=Direct.ready,direct_pending_birth=Direct.pending_birth,direct_fresh_birth=Direct.fresh_birth,on_transfer=function(source,en,id)Cut.invalidate_id(id,'unique mined item receipt consumed');History.claimed(en.unit_number,id)end}
local Replace=require('replacement');Replace.init{owner=RuntimeOwners.find,row=runtime_row,scope=scope,register=register,eligible=eligible,input=Cut.input,upgraded=History.upgraded,continued=function(unit,id,why)History.continued(unit,id,why);local en=storage.fabric_runtime_refs and storage.fabric_runtime_refs[tostring(unit)];if en and en.valid then MinedItems.engine_continued(id,en)end end}
History.init{source_ready=Cut.history_source_ready,owner=RuntimeOwners.find,row=runtime_row,scope=scope,register=register,eligible=eligible,world=function()return Cut.snapshot().namespace end,on_bound=function(h)Cut.history_bound(h)end,on_birth_scan=Cut.native_birth_scan_complete,on_redeconstruct=function(h,en,kind)Cut.history_redeconstructed(h,en,kind)end,on_ghost_recreated=function(h,en,kind)return Cut.history_recreated(h,en,kind)end,on_restore_claimed=function(id,unit,action,en)MinedItems.history_claimed(id,unit,action,en);Death.continued(unit,id,"proven native history restoration")end,on_continued=Death.continued,on_restore=function(id,en)Cut.invalidate_id(id,'native history restored this ID');return Death.history_reserved(id,en)end}
Cut.init{owner=RuntimeOwners.find,row=runtime_row,scope=scope,register=register,eligible=eligible,alloc=alloc,state=state,ghost_source=function(en)return Death.ghost_source(en)or History.accepted_ghost_source(en)end,delegate_accepted_ghost=History.delegate_accepted_ghost,delegate_ghost=function(en,proof,op)return Death.delegate_ghost(en,proof,op)end,ghost_removed_history=History.proven_ghost_removed,ghost_upgrade_frame=History.upgrade,ghost_upgrade_claim=History.ghost_upgraded_claim,history_input=History.interrupted,history_continued=function(unit,id,why)History.continued(unit,id,why);local en=storage.fabric_runtime_refs and storage.fabric_runtime_refs[tostring(unit)];if en and en.valid then MinedItems.engine_continued(id,en)end end,history_reject_birth=History.reject_birth,history_tick=function()Direct.tick();MinedItems.tick();History.tick();Cut.retire_unverified_legacy_births();Death.tick()end,history_marked=History.marked,history_destroyed=History.destroyed,history_cancel=function(unit,why)History.invalidate_unit(unit,why);Death.invalidate_unit(unit,why)end}
Death.init{row=runtime_row,reference=function(unit)return storage.fabric_runtime_refs and storage.fabric_runtime_refs[tostring(unit)]end,eligible=eligible,register=Registration.register,owner=RuntimeOwners.find,history_conflicts=History.pending_conflict,history_inflight=History.inflight_restore,history_ambiguous=History.ambiguous,invalidate_cut=Cut.invalidate_id,on_claim=function(id,en)Cut.invalidate_id(id,'engine-contained death revival');History.continued(en.unit_number,id,'engine-contained death revival');MinedItems.engine_continued(id,en)end,on_manual_alias=function(unit)Cut.invalidate_unit(unit,'manual accepted engine ghost');History.invalidate_unit(unit,'manual accepted engine ghost')end}
local function json_canonical(x)
 if type(x)~='table' then return helpers.table_to_json({value=x}) end
 local keys={} for k in pairs(x)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local r={} for _,k in ipairs(keys)do r[#r+1]=tostring(k)..'='..json_canonical(x[k])end;return '{'..table.concat(r,',')..'}'
end
local ModSettings=require('mod-settings')
local function settings(e)
 -- Engine blueprint export captures supported recipe/control/filter/settings fields.
 -- Narrow area mapping selects exactly the observed entity, never identity by position.
 local inv=game.create_inventory(1);inv[1].set_stack{name='blueprint'}
 local ok,ret=pcall(function()
  local pos=e.position
  local map=inv[1].create_blueprint{surface=e.surface,force=e.force,area=BlueprintArea(e),include_station_names=true,include_trains=true}
  local index
  for i,v in pairs(map)do if v==e then index=i end end
  if not index then return nil end
  for _,b in pairs(inv[1].get_blueprint_entities() or {})do if b.entity_number==index then
   b.entity_number=nil;b.position=nil;b.direction=nil;b.tags=nil;b.connections=nil;b.neighbours=nil;b.wires=nil
   return ModSettings.attach(b,e)
  end end
 end)
 inv.destroy();return ok and ret or nil
end
local function snapshot(surface,force_settings)
 local s=scope(surface);local live={};local entities=surface.find_entities_filtered{force='player'}
 -- Register all endpoints first so iteration order cannot change wire labels.
 for _,en in pairs(entities)do if eligible(en)then register(en,s.initialized and 'unobserved'or'initial')end end
 for _,e in pairs(entities)do if eligible(e) then
  register(e,s.initialized and 'unobserved' or 'initial')
  local r=s.units[tostring(e.unit_number)];local ghost=e.type=='entity-ghost'
  s.settings_cache=s.settings_cache or {};local key=tostring(e.unit_number)
  if force_settings or not s.settings_cache[key] then local data=settings(e);if data then s.settings_cache[key]={data=data,verified_tick=game.tick,unavailable=false}else local previous=s.settings_cache[key]or{};s.settings_cache[key]={data=previous.data,verified_tick=previous.verified_tick,unavailable=true}end end
  local wire_data=Wires.snapshot(e,scope)
  live[r.id]={id=r.id,unit=e.unit_number,name=ghost and e.ghost_name or e.name,ghost=ghost,reason=r.reason,operation=r.operation,identity_candidates=r.identity_candidates,identity_candidate_count=r.identity_candidate_count,identity_candidate_count_lower_bound=r.identity_candidate_count_lower_bound,domain_unresolved=Eligibility.contextual(e),unresolved=Eligibility.contextual(e) or r.reason~='accepted-new' and ((r.reason~='initial' and r.reason~='direct' and r.reason~='cut-transfer' and r.reason~='clipboard-copy' and r.reason~='engine-clone-copy' and r.reason~='item-receipt' and r.reason~='history-restored'and r.reason~='death-restored') or ghost),position={x=e.position.x,y=e.position.y},direction=e.direction,quality=e.quality.name,wires=wire_data,wires_unverified=wire_data.unsupported==true,settings_unverified=s.settings_cache[key].unavailable or false,settings=s.settings_cache[key].data}
 end end
 return live
end
local function initialize(surface)
 local s=scope(surface)
 if not s.initialized then s.baseline=snapshot(surface);s.initialized=true end
 return s
end
local function pos(r)return string.format('(%.1f, %.1f)',r.position.x,r.position.y)end
local function describe(r)return r.id..' '..r.name..' '..pos(r)..' [runtime '..r.unit..']'end
local function diff(s,live)
 local d={Added={},Removed={},Moved={},Changed={},Unresolved={},blocked=false,tick=game.tick}
 local by_name={};for oid,o in pairs(s.baseline)do by_name[o.name]=by_name[o.name]or{};by_name[o.name][#by_name[o.name]+1]=oid end;for _,ids in pairs(by_name)do table.sort(ids)end
 for id,r in pairs(live)do
  local old=s.baseline[id]
  if r.wires_unverified then d.Unresolved[#d.Unresolved+1]=describe(r)..'; wire readout unavailable; baseline retained';d.blocked=true;d.readout_unverified=true end
  local ghost_settings_gap=old and old.ghost and old.settings==nil
  if ghost_settings_gap then d.Unresolved[#d.Unresolved+1]=describe(r)..'; historical ghost snapshot lacks settings coverage; baseline retained';d.blocked=true;d.readout_unverified=true end
  local mod_gap=old and ModSettings.coverage_gap(old.settings,r.settings)
  local wire_gap=old and Wires.coverage_gap(old.wires,r.wires)
  if wire_gap then d.Unresolved[#d.Unresolved+1]=describe(r)..'; historical wire snapshot lacks declared helper roles; baseline retained';d.blocked=true;d.readout_unverified=true end
  if mod_gap then d.Unresolved[#d.Unresolved+1]=describe(r)..'; old/current snapshot lacks Things settings coverage; historical settings delta unavailable; baseline retained';d.blocked=true;d.readout_unverified=true end
  if r.settings_unverified then d.Unresolved[#d.Unresolved+1]=describe(r)..'; settings export unavailable in current engine state; baseline retained';d.blocked=true end
  if r.unresolved then
   local c={};local ids=r.identity_candidates or by_name[r.name]or{};for i=1,math.min(#ids,12)do local oid=ids[i];c[#c+1]=oid..(live[oid]and' (still live)'or' (absent)')end;if (r.identity_candidate_count or #ids)>12 then c[#c+1]=(r.identity_candidate_count_lower_bound and'at least +'or'+')..((r.identity_candidate_count or #ids)-12)..' more candidates; none correlated'end
   d.Unresolved[#d.Unresolved+1]=describe(r)..'; candidates: '..(#c>0 and table.concat(c,', ') or 'unknown provenance / fresh piece possible')
   d.blocked=true
  elseif not old then d.Added[#d.Added+1]=describe(r)..' (provisional new ID)'
  else
   if old.position.x~=r.position.x or old.position.y~=r.position.y then d.Moved[#d.Moved+1]=describe(r)..' from '..pos(old)..(old.unit==r.unit and ' (same live runtime)' or ' (verified operation/history ledger)') end
   if old.name~=r.name or old.direction~=r.direction or old.quality~=r.quality or (not ghost_settings_gap and not r.settings_unverified and json_canonical(mod_gap and ModSettings.engine_fields(old.settings)or old.settings)~=json_canonical(mod_gap and ModSettings.engine_fields(r.settings)or r.settings)) or (old.wires~=nil and not wire_gap and not r.wires_unverified and json_canonical(old.wires)~=json_canonical(r.wires))then d.Changed[#d.Changed+1]=describe(r)..' direction/settings/prototype/wires changed' end
  end
 end
 for id,r in pairs(s.baseline)do if not live[id] then d.Removed[#d.Removed+1]=describe(r) end end
 for _,k in ipairs({'Added','Removed','Moved','Changed','Unresolved'})do table.sort(d[k])end
 return d
end
local function lines(d)
 local r={};for _,k in ipairs({'Added','Removed','Moved','Changed','Unresolved'})do
  r[#r+1]=k..': '..#d[k];for _,v in ipairs(d[k])do r[#r+1]='  '..v end
 end
 return r
end
local function commit(surface)
 local s=initialize(surface);local live=snapshot(surface,true);local d=diff(s,live)
 if d.blocked then s.last={title='Preview — Commit blocked: unresolved identity/readout. Baseline unchanged.',lines=lines(d),diff=d};return d end
 local n=#d.Added+#d.Removed+#d.Moved+#d.Changed
 if n==0 then s.last={title='No changes. Revision '..s.revision..' unchanged.',lines=lines(d),diff=d};return d end
 s.revision=s.revision+1;s.baseline=live;s.last={title='Committed revision '..s.revision..' at tick '..game.tick,lines=lines(d),diff=d};return d
end
-- Explicit human acceptance resets uncertain lineage; it never proves a move.
local function accept_unresolved(surface,player_index)
 local s=initialize(surface);local before=snapshot(surface,true);local preview=diff(s,before)
 if not preview.blocked then return commit(surface) end
 if preview.readout_unverified then s.last={title='Preview — historical mod settings were not captured. Baseline unchanged; no baseline-reset policy selected.',lines=lines(preview),diff=preview};return preview end
 for _,r in pairs(before)do if r.settings_unverified or r.domain_unresolved then s.last={title='Preview — current engine state cannot verify settings/domain. Baseline unchanged.',lines=lines(preview),diff=preview};return preview end end
 local accepted={};local keys={}
 for id,r in pairs(before)do if r.unresolved then keys[#keys+1]=id end end
 table.sort(keys)
 for _,id in ipairs(keys)do
  local r=before[id];Cut.invalidate_unit(r.unit,'manual acceptance as fresh ID');History.invalidate_unit(r.unit,'manual acceptance as fresh ID');Death.invalidate_unit(r.unit,'manual acceptance as fresh ID');local entry=s.units[tostring(r.unit)];local newid=alloc('F')
  accepted[#accepted+1]={previous_label=id,new_id=newid,unit=r.unit,name=r.name,position=r.position,ghost=r.ghost}
  entry.id=newid;entry.reason='accepted-new';entry.identity_candidates=nil;entry.identity_candidate_count=nil;entry.identity_candidate_count_lower_bound=nil;entry.fabric_material_candidate_set=nil;entry.fabric_uncertain_set=nil;entry.operation='Explicitly accepted as new at revision '..(s.revision+1)
  if r.ghost then for _,en in pairs(surface.find_entities_filtered{type='entity-ghost'})do if en.unit_number==r.unit then Death.accept_ghost(en,newid);History.accept_ghost(en,newid);break end end end
 end
 local live=snapshot(surface,true);local d=diff(s,live)
 assert(not d.blocked,'Acceptance left unresolved entries')
 s.revision=s.revision+1;s.baseline=live
 s.acceptance_history=s.acceptance_history or {}
 s.acceptance_history[#s.acceptance_history+1]={tick=game.tick,player_index=player_index,revision=s.revision,unresolved_preview=preview,accepted=accepted,diff=d}
 local text=lines(d)
 table.insert(text,1,'Manual acceptance: unresolved pieces received NEW IDs; missing old pieces are removed. No move identity proven.')
 s.last={title='Accepted revision '..s.revision..' — unresolved treated as new',lines=text,diff=d}
 return d
end
local function label(parent,text)
 local l=parent.add{type='label',caption=text};l.style.single_line=false;l.style.maximal_width=560;if parent.type=='scroll-pane' then l.style.width=530 end;return l
end
local function render(p)
 local s=initialize(p.surface);local live=snapshot(p.surface);local d=diff(s,live)
 if p.gui.left.fabric_identity_debug then p.gui.left.fabric_identity_debug.destroy()end
 local old=p.gui.left.fabric_playground
 local undo_count=p.undo_redo_stack.get_undo_item_count();local redo_count=p.undo_redo_stack.get_redo_item_count()
 local sig=json_canonical({undo_count=undo_count,redo_count=redo_count,live=live,last=s.last,revision=s.revision,page=state().pages[p.index] or 1,cut_status=Cut.status(),history_status=History.status(),death_status=Death.status()})
 state().rendered=state().rendered or {}
 if old and state().rendered[p.index]==sig then return end
 state().rendered[p.index]=sig
 if old then old.destroy()end
 local f=p.gui.left.add{type='frame',name='fabric_playground',caption='Fabric playground',direction='vertical'};f.style.width=590
 label(f,'EXPERIMENT • native cut/history and unique mined-item receipts; anonymous item lineage remains unresolved.')
 label(f,Cut.status())
 label(f,History.status())
 label(f,'Undo '..undo_count..' • Redo '..redo_count..' • vanilla history; identity support experimental')
 label(f,Death.status())
 label(f,'Scope: '..p.surface.name..' / entire surface / player-force engine-blueprintable entities + ghosts')
 label(f,'Revision '..s.revision..' • F = local logical ID; runtime = engine unit. Initial adoption is not historical proof.')
 local readout_blocked=d.readout_unverified or false;for _,r in pairs(live)do if r.settings_unverified or r.domain_unresolved then readout_blocked=true end end
 local flow=f.add{type='flow'};local b=flow.add{type='button',name='fabric_pg_commit',caption=d.blocked and 'Commit blocked' or 'Commit'};b.enabled=not d.blocked
 flow.add{type='button',name='fabric_pg_refresh',caption='Refresh / preview'}
 if d.blocked then local accept=f.add{type='button',name='fabric_pg_accept',caption='Accept unresolved as new'};accept.enabled=not readout_blocked;accept.tooltip=readout_blocked and 'Current or historical settings/domain coverage is unavailable. Assigning a new ID does not recover missing settings.'or'Accept this entire diff. Unresolved pieces get new IDs; missing old pieces count as removed. This does not preserve move identity.' end
 label(f,readout_blocked and 'Current/historical settings or wire coverage unavailable. Baseline retained; assigning new IDs cannot recover missing settings.'or d.blocked and 'Unresolved candidates below. Commit is blocked; you may explicitly accept them as new pieces.' or 'Direct placements get provisional new IDs. Commit accepts only unambiguous changes.')
 local ids={} for id in pairs(live)do ids[#ids+1]=id end;table.sort(ids,function(a,b)return tonumber(a:sub(2))<tonumber(b:sub(2))end)
 local page=state().pages[p.index] or 1;local total=math.max(1,math.ceil(#ids/8));page=math.min(page,total);state().pages[p.index]=page
 local nav=f.add{type='flow'};nav.add{type='button',name='fabric_pg_prev',caption='‹'};label(nav,'Live buildings '..#ids..' • page '..page..'/'..total);nav.add{type='button',name='fabric_pg_next',caption='›'}
 for i=(page-1)*8+1,math.min(page*8,#ids)do
  local r=live[ids[i]];local status=r.unresolved and 'IDENTITY UNRESOLVED' or (s.baseline[r.id] and 'TRACKED' or 'NEW / provisional')
  local l=label(f,status..' • '..describe(r)..((r.settings_unverified or(not r.ghost and not r.settings)) and ' • settings unavailable in current state' or ''));l.style.font_color=r.unresolved and {1,.7,.25} or {.65,1,.7}
  if type(r.operation)=='string'then local op=label(f,'  '..r.operation);op.style.single_line=true;op.tooltip=r.operation end
 end
 local scroll=f.add{type='scroll-pane',direction='vertical'};scroll.style.width=560;scroll.style.height=200
 label(scroll,s.last.title)
 for i,v in ipairs(s.last.lines)do if i>120 then label(scroll,'Additional diff lines omitted from this panel; full diff retained in snapshot.');break end;label(scroll,v)end
 if d.blocked then label(scroll,'Current unresolved preview:');for i,v in ipairs(lines(d))do if i>120 then label(scroll,'Additional preview lines omitted; full diff retained in snapshot.');break end;label(scroll,v)end end
 label(f,'Settings: engine blueprint fields + read-only Things/CS2 tag settings + position/direction/prototype/quality. Wire endpoints include exact declared Things helper roles; helper roles are not Fabric IDs. Legacy missing settings/wire coverage blocks Commit. Inventory contents, tiles, vehicle color/data outside blueprint fields & transient circuit state excluded. Observed unresolved mining material stays unresolved. Settings refreshed on Commit/Refresh.')
end
script.on_init(function()for _,p in pairs(game.players)do initialize(p.surface)end end)
script.on_configuration_changed(function()state().rendered={};for _,p in pairs(game.players)do initialize(p.surface);render(p)end end)
script.on_event(defines.events.on_player_joined_game,function(e)render(game.get_player(e.player_index))end)
script.on_event(defines.events.on_player_changed_surface,function(e)render(game.get_player(e.player_index))end)
script.on_nth_tick(60,function()for _,p in pairs(game.connected_players)do render(p)end end)
local function history(p)return p and state().history and state().history[p] == game.tick end
for _,name in ipairs({'undo','redo'})do
 script.on_event('fabric-pg-'..name,function(e)state().history=state().history or {};state().history[e.player_index]=game.tick;History.linked(name,e) end)
 -- The independent probe has linked controls. Applied events mark construction this tick too.
 script.on_event(defines.events['on_'..name..'_applied'],function(e)state().history=state().history or {};state().history[e.player_index]=game.tick;History.applied(name,e) end)
end
Direct.init{eligible=eligible,row=runtime_row,register=register,alloc=alloc,input=Cut.input,epoch=Cut.cursor_epoch,mined=MinedItems.built}
script.on_event(defines.events.on_pre_build,function(e)
 Cut.pre(e);Replace.pre(e);MinedItems.pre(e);Direct.pre(e)
end)
script.on_event(defines.events.on_built_entity,function(e)
 if History.built(e)then return end
 if Replace.built(e)then return end
 if Cut.built(e)then return end
 if not history(e.player_index)and Direct.built(e)then return end
 register(e.entity,'recreated-or-blueprint')
end)
script.on_event(defines.events.on_blueprint_settings_pasted,function(e)Cut.observe_merge(e);Cut.settings_pasted(e);History.settings_pasted(e)end)
script.on_event(defines.events.on_entity_died,Death.died)
script.on_event(defines.events.on_post_entity_died,Death.post)
script.on_event(defines.events.on_player_mined_entity,function(e)if e.entity and e.entity.valid and e.entity.type=='entity-ghost'then Death.invalidate_unit(e.entity.unit_number,'player mined exact engine death ghost')end;local replacement=Replace.mined(e);if not replacement then Cut.source_manually_mined(e);MinedItems.mined(e)end;History.mined(e)end)
script.on_event(defines.events.on_robot_built_entity,function(e)local job=RobotJobs.take(e.robot);if History.pending_robot_receipt(e,job)and History.robot_built(e,job)then return end;if Death.observed(e.entity)then return end;if Replace.robot_built(e)then return end;if History.robot_built(e,job)then return end;if not Cut.robot_built(e,job)then register(e.entity,'robot-recreated')end end)
script.on_event(defines.events.script_raised_built,function(e)History.observe_new_ghost(e.entity);register(e.entity,'script-unresolved')end)
script.on_event(defines.events.script_raised_revive,function(e)if not Death.observed(e.entity)then register(e.entity,'script-recreated')end end)
script.on_event(defines.events.on_gui_click,function(e)
 if not(e.element and e.element.valid)then return end
 local n=e.element.name;local p=game.get_player(e.player_index)
 if n=='fabric_pg_commit' then commit(p.surface);render(p)
 elseif n=='fabric_pg_accept' then accept_unresolved(p.surface,p.index);render(p)
 elseif n=='fabric_pg_refresh' then local s=initialize(p.surface);local d=diff(s,snapshot(p.surface,true));s.last={title='Preview — baseline unchanged',lines=lines(d),diff=d};render(p)
 elseif n=='fabric_pg_prev' then state().pages[p.index]=math.max(1,(state().pages[p.index] or 1)-1);render(p)
 elseif n=='fabric_pg_next' then state().pages[p.index]=(state().pages[p.index] or 1)+1;render(p)end
end)
remote.add_interface('fabric-playground',{
 loaded_build=function()return LoadedBuild end,
 runtime_context=function()local mods={};for n,v in pairs(script.active_mods)do mods[n]=v end;return {active_mods=mods,mod_name=script.mod_name,current_cut_issuer=Cut.issuer(),issuer_contract='Controlled server launches refresh issuer for NEW operations; manual loads bypassing launcher are not fork-protected.'}end,
 robot_jobs=function()return RobotJobs.snapshot()end,
 mined_items=function()return MinedItems.snapshot()end,
 cut_snapshot=Cut.snapshot,
 direct_snapshot=Direct.snapshot,
 history_snapshot=History.snapshot,
 death_snapshot=Death.snapshot,
 replacement_snapshot=Replace.snapshot,
 fixture_register=function(unit,reason) local sf=game.surfaces['fabric-playground-scratch'];assert(sf,'scratch only');for _,e in pairs(sf.find_entities())do if e.unit_number==unit then register(e,reason);return end end end,
 snapshot=function(surface)local sf=game.surfaces[surface or 1];local s=initialize(sf);return {state=s,live=snapshot(sf,true),preview=diff(s,snapshot(sf,true))}end,
 commit=function(surface)return commit(game.surfaces[surface or 1])end,
 accept_unresolved=function(surface,player_index)return accept_unresolved(game.surfaces[surface or 1],player_index)end,
 refresh=function()for _,p in pairs(game.connected_players)do render(p)end end
})

local Tests=require('campaign-tests')
Tests.init{scope=scope,register=register,snapshot=snapshot,initialize=initialize,diff=diff,commit=commit,accept=accept_unresolved}
remote.add_interface('fabric-campaign-tests',{core=Tests.core,engine=Tests.engine})

local Range=require('range-tests');Range.init{eligible=eligible,scope=scope,initialize=initialize,register=register,snapshot=snapshot,diff=diff,commit=commit,accept=accept_unresolved};remote.add_interface('fabric-coverage-range',{run=Range.run})

local Probe=require('coverage-probe');remote.add_interface('fabric-coverage-probe',{snapshot=Probe.snapshot})

local old_robot_mined=script.get_event_handler(defines.events.on_robot_mined_entity);script.on_event(defines.events.on_robot_mined_entity,function(e)Replace.robot_mined(e);MinedItems.mined(e);if old_robot_mined then old_robot_mined(e)end end)
script.on_event(defines.events.on_marked_for_upgrade,History.upgrade)

Probe.init()

local Perf=require('perf-tests');Perf.init{initialize=initialize,snapshot=snapshot,diff=diff,scope=scope,commit=commit};remote.add_interface('fabric-coverage-perf',{run=Perf.run,wires=Perf.wires})

-- Surface indices are reused by the engine. Cached per-surface baselines must not leak.
script.on_event(defines.events.on_surface_created,function(e)state().surfaces[tostring(e.surface_index)]=nil end)
script.on_event(defines.events.on_surface_deleted,function(e)
 state().surfaces[tostring(e.surface_index)]=nil
 History.invalidate_surface(e.surface_index)
 Death.invalidate_surface(e.surface_index)
end)
local EngineClone=require('engine-clone');EngineClone.init{eligible=eligible,register=register,row=runtime_row,alloc=alloc}
local prior_cloned=script.get_event_handler(defines.events.on_entity_cloned)
script.on_event(defines.events.on_entity_cloned,function(e)if prior_cloned then prior_cloned(e)end;EngineClone.cloned(e)end)

local previous_destroyed=script.get_event_handler(defines.events.on_object_destroyed)
script.on_event(defines.events.on_object_destroyed,function(e)
 if previous_destroyed then previous_destroyed(e)end
 Direct.destroyed(e)
 Death.destroyed(e)
 Registration.destroyed(e)
end)

remote.add_interface('fabric-coverage-maintenance',{flag_counterexample=function(unit,expected_id,why)
 for _,sf in pairs(game.surfaces)do if sf.name:find('^coverage%-')then for _,en in pairs(sf.find_entities_filtered{force='player'})do if en.unit_number==unit then
  local row=scope(sf).units[tostring(unit)];assert(row and row.id==expected_id,'label changed; refuse');Cut.invalidate_unit(unit,why);History.invalidate_unit(unit,why);local before=row.id;row.id=alloc('U');row.reason='counterexample-invalidated';row.withdrawn_id=before;row.explanation=why;return {unit=unit,previous=before,unresolved_label=row.id,reason=why}
 end end end end;error('only fresh coverage fixtures may be flagged')
end})

script.on_event(defines.events.on_surface_renamed,function(e)local sc=state().surfaces[tostring(e.surface_index)];if sc then sc.name=e.new_name end;for _,p in pairs(game.connected_players)do if p.surface.index==e.surface_index then state().rendered[p.index]=nil;render(p)end end end)
