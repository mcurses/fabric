-- Regression runner uses production modules. Engine fixtures are scoped to new test surfaces.
local T={};local A;local Cut=require('cut');local H=require('history');local Jobs=require('robot-jobs')
function T.init(api)A=api end
function T.core()
 local out={kind='production-predicate-unit-tests',cases={}};local function check(n,want,got)out.cases[#out.cases+1]={name=n,expected=want,actual=got,pass=want==got}end
 -- Synthetic saved samples exercise the production consumption primitive only.
 local saved_jobs=storage.fabric_robot_jobs;local robot={valid=true,unit_number=987654321}
 storage.fabric_robot_jobs={tick=game.tick,robots={['987654321']={target=101,surface=1}}}
 local first=Jobs.take(robot);check('robot callback first exact job accepted',true,Jobs.matches(first,101))
 check('robot job mismatched ghost rejected',false,Jobs.matches(first,102))
 check('second callback cannot reuse consumed sample',false,Jobs.matches(Jobs.take(robot),101))
 storage.fabric_robot_jobs={tick=game.tick,robots={['987654321']={target=101,surface=1}}};Jobs.take(robot)
 check('untagged first callback still exhausts sample',false,Jobs.matches(Jobs.take(robot),101))
 storage.fabric_robot_jobs={tick=game.tick-1,robots={['987654321']={target=101,surface=1}}}
 check('previous tick sample never accepted',false,Jobs.matches(Jobs.take(robot),101))
 check('missing current job never inferred by geometry',false,Jobs.matches(nil,101))
 storage.fabric_robot_jobs=saved_jobs
 local function piece(state)return {id='F-test',state=state or 'available',selected_tick=50,marked_tick=50,pre_marked=false}end
 local op={id=10,player=1,mode='cut'}
 check('verified cut may reserve before robot removal',true,Cut.can_reserve(op,piece(),1,10))
 for _,state in ipairs({'selected','reserved','transferred','invalid','copy'})do check('nonavailable state '..state..' cannot reserve',false,Cut.can_reserve(op,piece(state),1,10))end
 check('another player cannot consume cut',false,Cut.can_reserve(op,piece(),2,10))
 check('older extraction cannot consume new generation',false,Cut.can_reserve(op,piece(),1,11))
 check('copy plus same-tick deletion is never cut',false,Cut.can_reserve({id=10,player=1,mode='copy'},piece(),1,10))
 local p=piece();p.marked_tick=nil;check('source without verified mark rejected',false,Cut.can_reserve(op,p,1,10))
 p=piece();p.marked_tick=51;check('unrelated later deconstruction rejected',false,Cut.can_reserve(op,p,1,10))
 p=piece();p.pre_marked=true;check('pre-marked source rejected',false,Cut.can_reserve(op,p,1,10))
 local a={type='removed-entity',surface_index=1,target={name='constant-combinator',position={x=1,y=2}}}
 local v={surface=1,name='constant-combinator',position={x=1,y=2}}
 check('observed history event qualifies exact action',true,H.test_matches(a,v))
 check('other prototype at endpoint rejected',false,H.test_matches(a,{surface=1,name='inserter',position={x=1,y=2}}))
 check('other surface rejected',false,H.test_matches(a,{surface=2,name=v.name,position=v.position}))
 check('other endpoint rejected',false,H.test_matches(a,{surface=1,name=v.name,position={x=2,y=2}}))
 check('history inverse required',true,H.test_same(a,{type='built-entity',surface_index=1,target=a.target},true))
 check('same-direction action is not inverse',false,H.test_same(a,a,true))
 local input={tick=50,tool='blueprint',kind='build',epoch=4,cursor={x=1,y=2}}
 local pre={position={x=1,y=2},build_mode=0,created_by_moving=false}
 check('receipt exact native press',true,Cut.verify_prebuild(input,pre,50,4))
 check('receipt measured one-tick delay',true,Cut.verify_prebuild(input,pre,51,4))
 check('API target differs from actual input',false,Cut.verify_prebuild(input,{position={x=11,y=2},build_mode=0},50,4))
 check('API build mode differs from actual input',false,Cut.verify_prebuild(input,{position=pre.position,build_mode=2},50,4))
 check('old press without moving proof rejected',false,Cut.verify_prebuild(input,pre,52,4))
 check('native engine drag repeat allowed',true,Cut.verify_prebuild(input,{position={x=11,y=2},build_mode=0,created_by_moving=true},100,4))
 check('cursor template changed while held rejects drag',false,Cut.verify_prebuild(input,{position=pre.position,build_mode=0,created_by_moving=true},100,5))
 check('forged truthy nonboolean moving flag rejected',false,Cut.verify_prebuild(input,{position=pre.position,build_mode=0,created_by_moving=1},100,4))
 local ops=Cut.snapshot().ops;for _,o in pairs(ops)do for _,pc in pairs(o.pieces)do
  local tag={world=Cut.snapshot().namespace,op=o.id,piece=pc.index,source=pc.source_unit,id=pc.id}
  check('saved ledger token recognized',true,Cut.test_tag(tag))
  tag.source=tag.source+999999;check('token cannot name arbitrary source',false,Cut.test_tag(tag))
  tag.source=pc.source_unit;tag.id='F-forged';check('token cannot claim arbitrary Fabric ID',false,Cut.test_tag(tag))
  tag.id=pc.id;tag.world='another-save';check('foreign namespace rejected',false,Cut.test_tag(tag))
  out.passed=0;for _,c in pairs(out.cases)do if c.pass then out.passed=out.passed+1 end end;out.failed=#out.cases-out.passed;return out
 end end
 return out
end
function T.engine()
 local out={kind='actual-engine-scripted-fixtures-not-GUI',cases={}};local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
 local function check(n,want,got)out.cases[#out.cases+1]={name=n,expected=want,actual=got,pass=want==got}end
 local sf=game.create_surface('campaign-engine-'..game.tick,{width=64,height=64});sf.request_to_generate_chunks({0,0},1);sf.force_generate_chunk_requests();for _,e in pairs(sf.find_entities())do e.destroy()end
 local tiles={};for x=-16,16 do for y=-16,16 do tiles[#tiles+1]={name='refined-concrete',position={x,y}}end end;sf.set_tiles(tiles)
 local scope=A.initialize(sf);local function diff()return A.diff(scope,A.snapshot(sf,true))end
 check('empty commit has no net changes',0,#A.commit(sf).Added)
 local e=sf.create_entity{name='constant-combinator',position={.5,.5},force='player'};A.register(e,'direct')
 check('explicit direct fixture is Added',1,#diff().Added);local id=A.scope(sf).units[tostring(e.unit_number)].id;A.commit(sf)
 e.combinator_description='settings-only actual blueprint export';check('same runtime settings-only Changed',1,#diff().Changed);A.commit(sf)
 e.direction=defines.direction.east;check('same runtime rotation Changed',1,#diff().Changed);A.commit(sf)
 e.teleport({2.5,.5});check('same runtime teleport is Moved',1,#diff().Moved);A.commit(sf)
 e.destroy{raise_destroy=true};check('actual removal Removed',1,#diff().Removed);A.commit(sf)
 local t=sf.create_entity{name='inserter',position={4.5,.5},force='player'};A.register(t,'direct');t.destroy{raise_destroy=true};check('added then removed net zero',0,#diff().Added+#diff().Removed+#diff().Changed+#diff().Unresolved)
 e=sf.create_entity{name='constant-combinator',position={2.5,.5},force='player',raise_built=true};check('recreated at old endpoint stays unresolved',true,diff().blocked);local rev=scope.revision;A.commit(sf);check('unresolved commit retains baseline',rev,scope.revision)
 A.accept(sf,1);local new=A.scope(sf).units[tostring(e.unit_number)].id;check('manual acceptance allocates fresh ID',true,new~=id and new:sub(1,1)=='F');check('acceptance history retained',1,#scope.acceptance_history);check('accepted uncertainty clears blocking',false,diff().blocked)
 local before=Cut.snapshot().next_op;for _=1,3 do A.snapshot(sf,true)end;check('settings exports cannot mint operations',before,Cut.snapshot().next_op)
 local inv=game.create_inventory(1);inv[1].set_stack{name='blueprint'};if remote.interfaces['cooperative-blueprinting-v1']then remote.call('cooperative-blueprinting-v1','create_blueprint',inv[1],{surface=sf,force='player',area={{2,0},{3,1}}})else inv[1].create_blueprint{surface=sf,force='player',area={{2,0},{3,1}}}end
 local bes=inv[1].get_blueprint_entities()or{};local tagged=false;for _,be in pairs(bes)do if be.tags and be.tags.fabric_playground_cut_v1 then tagged=true end end
 e.destroy{raise_destroy=true};check('API copy + deletion same tick mints no cut token',false,tagged);check('API copy + deletion mints no cut operation',before,Cut.snapshot().next_op)
 local ghosts=inv[1].build_blueprint{surface=sf,force='player',position={6.5,2.5},build_mode=defines.build_mode.forced,raise_built=true}or{};check('actual API blueprint creates ghosts',true,#ghosts>0)
 local live=A.snapshot(sf,true);local stole=false;for _,r in pairs(live)do if r.id==new then stole=true end end;check('API copy+delete never steals old ID',false,stole);check('unobserved scripted replay explicit unresolved',true,A.diff(scope,live).blocked)
 inv.destroy();out.surface=sf.name;out.passed=0;for _,c in pairs(out.cases)do if c.pass then out.passed=out.passed+1 end end;out.failed=#out.cases-out.passed;return out
end
return T
