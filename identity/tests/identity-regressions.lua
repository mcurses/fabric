-- Desired-behavior regression suite against real captured production modules.
-- Engine objects/callback ordering are mocked; no native/GUI proof is claimed.
local source=assert(arg[1],'required module directory')
package.path=source..'/?.lua;'..package.path
local H=require('history');local C=require('cut')
local Mined;local mined_file=io.open(source..'/mined-items.lua','r');if mined_file then mined_file:close();Mined=require('mined-items')end
local results={};local assertions=0
local function equal(case,label,expected,actual)
 assertions=assertions+1
 case.assertions[#case.assertions+1]={label=label,expected=expected,actual=actual,pass=expected==actual}
 if expected~=actual then case.pass=false end
end
local function setup()
 storage={};local reg=0
 script={active_mods={},on_event=function()end,register_on_object_destroyed=function()reg=reg+1;return reg end}
 defines={events=setmetatable({},{__index=function(_,k)return k end}),controllers={character=1}}
 local env={rows={},live={},undo={},redo={}}
 env.surface={index=1,find_entities_filtered=function(filter)if filter and filter.type=='construction-robot'then return{}end;return env.live end,find_entities=function()local live={};for _,en in pairs(env.live)do if en.valid then live[#live+1]=en end end;return live end}
 local stack={get_undo_item_count=function()return #env.undo end,get_redo_item_count=function()return #env.redo end,get_undo_item=function(i)return env.undo[i]end,get_redo_item=function(i)return env.redo[i]end}
 stack.set_undo_tag=function(i,j,k,v)local a=env.undo[i][j];a.tags=a.tags or{};a.tags[k]=v end
 stack.set_redo_tag=function(i,j,k,v)local a=env.redo[i][j];a.tags=a.tags or{};a.tags[k]=v end
 env.player={index=1,undo_redo_stack=stack}
 game={tick=100,surfaces={env.surface},players={env.player},connected_players={env.player},get_player=function()return env.player end}
 local api={world=function()return'world'end,scope=function()return{units=env.rows}end,eligible=function()return true end,alloc=function()return'Fnew'end,register=function(e,reason)env.rows[tostring(e.unit_number)]=env.rows[tostring(e.unit_number)]or{id='U'..e.unit_number,reason=reason}end}
 H.init(api);H.snapshot();C.init(api);C.snapshot()
 function env.entity(unit,id,ghost)
  local e={valid=true,unit_number=unit,type=ghost and'entity-ghost'or'container',name=ghost and'entity-ghost'or'iron-chest',ghost_name=ghost and'iron-chest'or nil,surface=env.surface,position={x=.5,y=.5},quality={name='normal'},tags={}}
  if id then env.rows[tostring(unit)]={id=id,reason='direct'}end
  return e
 end
 return env
end
local function action(typ,tag)
 return{type=typ,surface_index=1,target={name='iron-chest',position={x=.5,y=.5}},tags=tag and{fabric_pg_history_v1=tag}or nil}
end
local function history_tag(a)return a.tags and a.tags.fabric_pg_history_v1 end
local function record(a)local t=history_tag(a);return t and H.snapshot().actions[tostring(t.action)]end
local function count_actions()local n=0;for _ in pairs(H.snapshot().actions)do n=n+1 end;return n end
local function run(id,fn)
 local case={id=id,pass=true,assertions={}};results[#results+1]=case
 local ok,err=pcall(function()fn(case,setup())end)
 if not ok then case.pass=false;case.error=tostring(err)end
end
run('native_observed_shape_same_endpoint_rebuild',function(t,e)
 local a=e.entity(1,'F1');e.live={a};H.built{player_index=1,entity=a};e.undo={{action('built-entity')}};H.tick()
 t.engine_shape_evidence='H-rebuild-same-endpoint-v34-native-failure.json: old build spec loses surface_index after mining'
 local oldbuild=e.undo[1];local old_id=history_tag(oldbuild[1]).action
 equal(t,'initial A binding','F1',record(oldbuild[1]).logical_id)
 game.tick=102;H.mined{player_index=1,entity=a};oldbuild[1].surface_index=nil;e.undo={{action('removed-entity')},oldbuild};H.tick();a.valid=false;local removal=e.undo[1]
 game.tick=104;local b=e.entity(2,'F2');e.live={b};H.built{player_index=1,entity=b};e.undo={{action('built-entity')},removal,oldbuild};H.tick()
 equal(t,'new B action binds its own ID','F2',record(e.undo[1][1])and record(e.undo[1][1]).logical_id or'<unbound>')
 equal(t,'old authoritative ledger record retained','F1',H.snapshot().actions[tostring(old_id)].logical_id)
end)
run('authoritative_action_survives_missing_surface_and_deep_redo',function(t,e)
 t.engine_shape_evidence='v34 deeper native artifacts: old built action temporarily loses surface, returns, then original-build redo loses F6604'
 local a=e.entity(1,'F1');e.live={a};H.built{player_index=1,entity=a};e.undo={{action('built-entity')}};H.tick()
 local oldbuild=e.undo[1];local original_id=history_tag(oldbuild[1]).action
 game.tick=102;H.mined{player_index=1,entity=a};oldbuild[1].surface_index=nil;e.undo={{action('removed-entity')},oldbuild};H.tick();a.valid=false;e.live={}
 equal(t,'authoritative original tag retained while surface absent',original_id,history_tag(oldbuild[1]).action)
 -- Undo the manual removal. Callback destination is direct in this module
 -- fixture to isolate history correlation; actual engine evidence uses a ghost.
 game.tick=104;local mining_action=e.undo[1];H.linked('undo',{player_index=1})
 local restored=e.entity(3);e.live={restored};local mining_tag=history_tag(mining_action[1])
 H.built{player_index=1,entity=restored,tags={fabric_pg_history_v1=mining_tag}}
 oldbuild[1].surface_index=1;e.undo={oldbuild};e.redo={{action('built-entity')}}
 H.applied('undo',{player_index=1,actions=mining_action});H.tick()
 equal(t,'manual removal undo restores A','F1',e.rows['3'].id)
 equal(t,'authoritative original tag retained after surface returns',original_id,history_tag(oldbuild[1]).action)
 -- Undo original build, then redo that action.
 game.tick=106;H.linked('undo',{player_index=1});H.marked{player_index=1,entity=restored}
 e.undo={};e.redo={{action('removed-entity')}};H.applied('undo',{player_index=1,actions=oldbuild});restored.valid=false;e.live={}
 game.tick=108;local redo=e.redo[1];H.linked('redo',{player_index=1});local tag=history_tag(redo[1])
 local final=e.entity(4);e.live={final};H.built{player_index=1,entity=final,tags={fabric_pg_history_v1=tag}}
 e.undo={{action('built-entity')}};e.redo={};H.applied('redo',{player_index=1,actions=redo})
 equal(t,'deep redo of original build restores original A','F1',e.rows['4'].id)
end)
run('synthetic_preserved_old_surface_rebuild',function(t,e)
 t.engine_reachability='UNESTABLISHED: preserves old surface_index unlike observed native trial; this is not a reproduced ordinary native failure'
 local a=e.entity(1,'F1');e.live={a};H.built{player_index=1,entity=a};e.undo={{action('built-entity')}};H.tick()
 local oldbuild=e.undo[1];local old_id=history_tag(oldbuild[1]).action
 equal(t,'initial A binding','F1',record(oldbuild[1]).logical_id)
 game.tick=102;H.mined{player_index=1,entity=a};e.undo={{action('removed-entity')},oldbuild};H.tick();a.valid=false;local removal=e.undo[1]
 game.tick=104;local b=e.entity(2,'F2');e.live={b};H.built{player_index=1,entity=b};e.undo={{action('built-entity')},removal,oldbuild};H.tick()
 equal(t,'new B action binds its own ID','F2',record(e.undo[1][1])and record(e.undo[1][1]).logical_id or'<unbound>')
 equal(t,'old A action correlation unchanged',old_id,history_tag(oldbuild[1]).action)
 equal(t,'old A action identity retained','F1',record(oldbuild[1])and record(oldbuild[1]).logical_id or'<unbound>')
end)
run('stale_removal_tag_does_not_steal_identity',function(t,e)
 local a=e.entity(1,'F1');e.live={a};H.mined{player_index=1,entity=a};e.undo={{action('removed-entity')}};H.tick()
 local old=history_tag(e.undo[1][1]);local old_record=H.snapshot().actions[tostring(old.action)]
 a.valid=false;game.tick=102;local b=e.entity(2,'F2');e.live={b};H.mined{player_index=1,entity=b}
 -- Explicit adversarial metadata injection, not claimed native inheritance.
 e.undo={{action('removed-entity',old)}};H.tick();b.valid=false;e.live={};game.tick=103
 H.linked('undo',{player_index=1})
 local actual=history_tag(e.undo[1][1]);local restored=e.entity(3);e.live={restored}
 H.built{player_index=1,entity=restored,tags={fabric_pg_history_v1=actual}}
 e.redo={{action('built-entity')}};H.applied('undo',{player_index=1,actions=e.undo[1]})
 local row=e.rows['3'];equal(t,'new B restoration never receives old A ID',false,row and row.id=='F1'or false)
 equal(t,'original authoritative record preserved','F1',old_record.logical_id)
 t.observed_restored_id=row and row.id or'<unregistered>'
 t.acceptable_result='F2 with independent causal binding, or explicit unresolved; never F1'
end)
local function endpoint(x)return{entity={name='small-electric-pole',position={x=x,y=.5}},surface_index=1,connector=1}end
local shapes={
 {'built_tile',{type='built-tile',surface_index=1,position={x=0,y=0},new_tile='stone-path',previous_tile='grass-1'}},
 {'removed_tile',{type='removed-tile',surface_index=1,position={x=0,y=0},previous_tile='stone-path'}},
 {'wire_added',{type='wire-added',a=endpoint(.5),b=endpoint(2.5)}},
 {'wire_removed',{type='wire-removed',a=endpoint(.5),b=endpoint(2.5)}},
 {'invalid_targetless_action',{type='built-entity'}},
 {'supported_built_control',action('built-entity')}
}
for _,shape in ipairs(shapes)do for _,side in ipairs{'undo','redo'}do
 run('idle_'..side..'_'..shape[1],function(t,e)
  local a=shape[2];a.tags=nil;e[side]={{a}}
  H.tick();local first_count=count_actions();local first_tag=history_tag(a);local first_id=first_tag and first_tag.action
  for i=1,120 do game.tick=100+i;H.tick()end
  equal(t,'record count stable after initial observation',first_count,count_actions())
  equal(t,'opaque tag remains stable',first_id or'<none>',history_tag(a)and history_tag(a).action or'<none>')
  local r=record(a);equal(t,'no identity manufactured without frame',false,r and r.logical_id~=nil or false)
 end)
end end
local metadata={
 {'number',7},{'true',true},{'false',false},{'string','not-a-receipt'},
 {'array',{1,2,3}},{'empty_object',{}},{'missing_fields',{world='world'}},
 {'nested_fields',{world={nested=true},ghost={id=10},action={id=2},restore={id=3},op={id=1},piece={id=1},source={id=10},id={id='F1'}}},
 {'ghost_boolean',{ghost=true}},{'ghost_number_only',{ghost=10}},
 {'malformed_action',{world='world',action={nested=true},ghost=10}}
}
for _,method in ipairs{'history_observe','history_robot','cut_built','history_migration'}do for _,m in ipairs(metadata)do
 run('metadata_'..method..'_'..m[1],function(t,e)
  local sentinel={nested={a=1,b=false},text='foreign intact'}
  local key=method=='cut_built'and'fabric_playground_cut_v1'or method=='history_migration'and'fabric_pg_history_v1'or'fabric_pg_entity_v1'
  local tags={[key]=m[2],foreign_sentinel=sentinel};local en=e.entity(10,nil,true);en.tags=tags
  local ok,err=pcall(function()
   if method=='history_observe'then H.observe_new_ghost(en)
   elseif method=='history_robot'then en.type='container';en.name='iron-chest';H.robot_built({entity=en,tags=tags,robot={valid=true,unit_number=99}},nil)
   elseif method=='cut_built'then C.built{entity=en,tags=tags,player_index=1}
   else e.undo={{{type='built-tile',surface_index=1,position={x=0,y=0},new_tile='stone-path',tags=tags}}};H.tick()end
  end)
  equal(t,'malformed metadata does not throw',true,ok)
  if not ok then t.observed_error=tostring(err)end
  local s=en.tags.foreign_sentinel
  equal(t,'foreign nested tag preserved',true,s and s.nested and s.nested.a==1 and s.nested.b==false and s.text=='foreign intact'or false)
  local row=e.rows['10'];equal(t,'malformed metadata grants no F identity',false,row and row.id:sub(1,1)=='F'or false)
 end)
end end
-- Mined-pool safety invariants. Candidate retirement after acceptance is an
-- observation, not a blanket-clear requirement or a settled placement policy.
if Mined then
 local function mi(number)return{valid_for_read=true,name='iron-chest',quality={name='normal'},count=1,item_number=number}end
 local function mp(e)
  local function eligible(en)return en.valid and en.unit_number~=nil and en.force and en.force.name=='player'end
  e.live_id_queries=0
  Mined.init{eligible=eligible,scope=function()return{units=e.rows}end,live_ids=function()
   e.live_id_queries=e.live_id_queries+1;local ids={}
   for _,en in pairs(e.live)do local row=en.unit_number and e.rows[tostring(en.unit_number)]
    if en.valid and en.type~='entity-ghost'and row and row.id:sub(1,1)=='F'then ids[row.id]=en.unit_number end
   end
   return ids
  end,register=function(en,reason)
   if eligible(en)then e.rows[tostring(en.unit_number)]=e.rows[tostring(en.unit_number)]or{id='U'..en.unit_number,reason=reason}end
  end}
  game.get_entity_by_unit_number=function(unit)for _,en in pairs(e.live)do if en.valid and en.unit_number==unit then return en end end end
  local function entity(unit,id,force,surface)
   local en=e.entity(unit,id);en.force={name=force or'player'};en.prototype={items_to_place_this={{name='iron-chest'}}}
   if surface then en.surface=surface end;return en
  end
  local function mine(unit,id,number)
   local en=entity(unit,id);e.live={en};Mined.mined{entity=en,player_index=1,buffer={mi(number)}};en.valid=false;e.live={};return en
  end
  local function built(en,number,player)
   return Mined.built{entity=en,player_index=player or 1,consumed_items={mi(number)}}
  end
  return entity,mine,built
 end
 local function candidate(row,id)for _,x in pairs(row and row.identity_candidates or{})do if x==id then return true end end;return false end
 local function old_assigned(row)return row and(row.id=='F1'or row.id=='F2')or false end
 run('mined_empty_pool_not_claimed',function(t,e)
  local entity,_,built=mp(e);local en=entity(10);equal(t,'empty pool leaves ordinary path available',false,built(en));equal(t,'no pool-derived assignment',false,old_assigned(e.rows['10']));t.lifecycle_observation={live_id_queries_with_empty_pool=e.live_id_queries}
 end)
 run('mined_merged_candidates_never_choose_old_id',function(t,e)
  local entity,mine,built=mp(e);mine(1,'F1');mine(2,'F2');local en=entity(10);built(en)
  equal(t,'no FIFO or LIFO old ID assignment',false,old_assigned(e.rows['10']))
  t.lifecycle_observation={candidates=e.rows['10']and e.rows['10'].identity_candidates or{},reason=e.rows['10']and e.rows['10'].reason or'<not-handled>'}
  t.policy_sensitive='Retaining unresolved versus another no-lineage convention is not decided by this test.'
 end)
 run('mined_out_of_scope_force_no_crash',function(t,e)
  local entity,mine,built=mp(e);mine(1,'F1');local en=entity(10,nil,'other');local ok,err=pcall(function()built(en)end)
  equal(t,'other-force direct placement does not throw',true,ok);if not ok then t.observed_error=tostring(err)end
  equal(t,'unsupported entity not registered by pool',true,e.rows['10']==nil)
 end)
 run('mined_no_unit_entity_no_crash',function(t,e)
  local entity,mine,built=mp(e);mine(1,'F1');local en=entity(nil);local ok,err=pcall(function()built(en)end)
  equal(t,'no-unit unsupported entity does not throw',true,ok);if not ok then t.observed_error=tostring(err)end
 end)
 run('mined_restored_live_id_not_transfer_candidate',function(t,e)
  local entity,mine,built=mp(e);mine(1,'F1')
  -- Authoritative current world contains restored F1 at a different runtime.
  -- If lifecycle retirement is wired outside the module, a future adapter must
  -- model that real hook explicitly; do not claim this stub tests the dispatcher.
  local restored=entity(2,'F1');local en=entity(10);e.live={restored,en};built(en)
  equal(t,'already-live F1 is not offered as transferable identity',false,candidate(e.rows['10'],'F1'))
  equal(t,'already-live F1 never assigned twice',false,old_assigned(e.rows['10']))
  t.lifecycle_observation={candidates=e.rows['10']and e.rows['10'].identity_candidates or{}}
 end)
 run('mined_pre_destruction_source_not_mistaken_for_restoration',function(t,e)
  local entity,_,built=mp(e);local source_entity=entity(1,'F1');e.live={source_entity}
  Mined.mined{entity=source_entity,player_index=1,buffer={mi()}}
  -- on_player_mined_entity is before source destruction. Another mod's
  -- immediate build callback may run while the recorded original is valid.
  local nested=entity(10);e.live={source_entity,nested};built(nested)
  local pool=Mined.snapshot().sources['iron-chest/normal']
  equal(t,'same original runtime does not retire its pending candidate',true,pool and pool.F1~=nil or false)
  source_entity.valid=false;local later=entity(11);e.live={nested,later};built(later)
  equal(t,'candidate remains available after actual source destruction',true,candidate(e.rows['11'],'F1'))
  equal(t,'no old-ID assignment in either callback',false,old_assigned(e.rows['10'])or old_assigned(e.rows['11']))
  t.engine_reachability='Actual API-interleaving still to test; official on_player_mined_entity occurs before destruction and LuaPlayer.build_from_cursor raises immediate build events.'
 end)
 run('mined_acceptance_lifecycle_safety',function(t,e)
  local entity,mine,built=mp(e);mine(1,'F1');mine(2,'F2');local first=entity(10);built(first)
  local row=e.rows['10'];if row then row.id='F99';row.reason='accepted-new'end
  local second=entity(11);built(second)
  equal(t,'accepted new label remains unchanged','F99',e.rows['10']and e.rows['10'].id or'<no-row>')
  equal(t,'later placement does not invent old ID',false,old_assigned(e.rows['11']))
  t.lifecycle_observation={later_candidates=e.rows['11']and e.rows['11'].identity_candidates or{},pool=Mined.snapshot()}
  t.policy_sensitive='Direct row transition models accepted-new state, not full commit GUI. No assertion requires pool clearing after one or all Accept operations.'
 end)
 run('mined_cross_player_surface_safety',function(t,e)
  local entity,mine,built=mp(e);mine(1,'F1');local surface={index=2};local en=entity(10,nil,'player',surface);built(en,nil,2)
  equal(t,'cross-domain material possibility does not assign old ID',false,old_assigned(e.rows['10']))
  t.lifecycle_observation={candidate_crosses_player_and_surface=candidate(e.rows['10'],'F1')}
  t.policy_sensitive='Inventory handoff can cross player/surface boundaries; test does not mandate filtering by source location/player.'
 end)
 run('mined_pool_plain_storage_roundtrip',function(t,e)
  local _,mine=mp(e);mine(1,'F1');local function clone(v)
   if type(v)~='table'then assert(type(v)=='number'or type(v)=='string'or type(v)=='boolean'or v==nil,'nonserializable pool value');return v end
   local c={};for k,x in pairs(v)do assert(type(k)=='string'or type(k)=='number');c[k]=clone(x)end;return c
  end
  storage.fabric_mined_items=clone(Mined.snapshot())
  local found=Mined.snapshot().sources['iron-chest/normal'];equal(t,'source logical ID survives plain storage roundtrip','F1',found and found.F1 and found.F1.id or'<missing>')
  t.policy_sensitive='Plain-storage simulation only; an actual saved-ZIP recovery remains an engine test.'
 end)
 run('mined_candidate_display_cap_keeps_true_count',function(t,e)
  local entity,mine,built=mp(e)
  for i=1,100 do mine(i,'F'..i)end
  local en=entity(1000);built(en);local row=e.rows['1000']
  equal(t,'displayed candidate list capped at12',12,row and #row.identity_candidates or 0)
  equal(t,'total candidate count retained',100,row and row.identity_candidate_count or 0)
  equal(t,'large candidate pool never selects old F ID',false,row and row.id:sub(1,1)=='F'or false)
 end)
 run('mined_distinct_item_numbers_disqualify_source',function(t,e)
  local entity,mine,built=mp(e);mine(1,'F1',111);local en=entity(10);built(en,222)
  equal(t,'different known item number not candidate',false,candidate(e.rows['10'],'F1'))
  equal(t,'different known item number never transfers old ID',false,old_assigned(e.rows['10']))
 end)
end
-- Minimal JSON serializer for this plain summary only.
local function quote(s)return '"'..s:gsub('[%z\1-\31\\"]',function(c)local maps={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'};return maps[c]or string.format('\\u%04x',string.byte(c))end)..'"'end
local function json(v)
 local typ=type(v)
 if typ=='nil'then return'null'elseif typ=='boolean'or typ=='number'then return tostring(v)elseif typ=='string'then return quote(v)end
 local n=0;local array=true;for k in pairs(v)do n=n+1;if type(k)~='number'or k<1 or k%1~=0 then array=false end end
 local out={};if array and n==#v then for i=1,n do out[#out+1]=json(v[i])end;return'['..table.concat(out,',')..']'end
 local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys)do out[#out+1]=quote(k)..':'..json(v[k])end;return'{'..table.concat(out,',')..'}'
end
local passed=0;for _,r in ipairs(results)do if r.pass then passed=passed+1 end end
print(json{schema_version=1,kind='production-module-simulation',source_directory=source,mined_pool_module_present=Mined~=nil,tests=#results,passed=passed,failed=#results-passed,assertions=assertions,results=results,limitations={'Mocked engine objects and callback order; no engine or GUI coverage.','Stale-removal test explicitly injects old action metadata.','Idle wire/tile action shapes come from installed official2.1.24 schema.'}})
if passed~=#results then os.exit(1)end
