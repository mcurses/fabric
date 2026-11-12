local P={};local A
function P.init(api)A=api end
function P.run(n)
 assert(n>=1 and n<=2000);local sf=game.create_surface('coverage-perf-'..game.tick..'-'..n,{width=512,height=256});sf.request_to_generate_chunks({0,0},2);sf.force_generate_chunk_requests();for _,e in pairs(sf.find_entities())do e.destroy()end
 local entities={};for i=1,n do local e=sf.create_entity{name='wooden-chest',position={x=(i%80)*2-80,y=math.floor(i/80)*2-20},force='player'};entities[#entities+1]=e end
 local function measure(phase,fn)local p=helpers.create_profiler();local result=fn();p.stop();rcon.print({'','FABRIC_PROFILE|',n,'|',phase,'|',p});return 'see raw PROFILE line',result end
 local initial=measure('initial',function()return A.initialize(sf)end)
 local cached,live=measure('cached',function()return A.snapshot(sf,false)end)
 local forced=measure('forced',function()return A.snapshot(sf,true)end)
 local equal=measure('unchanged-diff',function()return A.diff(A.scope(sf),live)end)
 -- Actual engine replacement without proof, maximal same-prototype candidate set.
 for i,e in ipairs(entities)do local pos=e.position;e.destroy{raise_destroy=true};entities[i]=sf.create_entity{name='wooden-chest',position=pos,force='player',raise_built=true}end
 local unresolved=A.snapshot(sf,false);local ambiguous,d=measure('ambiguous-diff',function()return A.diff(A.scope(sf),unresolved)end)
 local out={kind='actual-engine-performance-fixture',count=n,initial=initial,cached=cached,forced_settings=forced,unchanged_diff=equal,ambiguous_diff=ambiguous,unresolved=#d.Unresolved,blocked=d.blocked,first_candidate_text=d.Unresolved[1]and #d.Unresolved[1],total_candidate_text=0}
 for _,line in pairs(d.Unresolved)do out.total_candidate_text=out.total_candidate_text+#line end
 -- Only this freshly created unoccupied performance surface is removed.
 game.delete_surface(sf);return out
end
function P.wires()
 local sf=game.create_surface('coverage-wire-engine-'..game.tick,{width=64,height=64});sf.request_to_generate_chunks({0,0},1);sf.force_generate_chunk_requests();for _,e in pairs(sf.find_entities())do e.destroy()end
 local a=sf.create_entity{name='constant-combinator',position={0,0},force='player'};local b=sf.create_entity{name='constant-combinator',position={2,0},force='player'};local s=A.initialize(sf);local out={kind='actual-engine-wire-connector-scripted',cases={}}
 local function check(n,w,g)out.cases[#out.cases+1]={name=n,expected=w,actual=g,pass=w==g}end
 local function d()return A.diff(s,A.snapshot(sf,true))end
 for _,color in ipairs({'circuit_red','circuit_green'})do
  local ac=a.get_wire_connector(defines.wire_connector_id[color],true);local bc=b.get_wire_connector(defines.wire_connector_id[color],true)
  ac.connect_to(bc);check(color..' both endpoints Changed',2,#d().Changed);A.commit(sf);check(color..' empty commit net0',0,#d().Changed);ac.disconnect_from(bc);check(color..' removal both Changed',2,#d().Changed);A.commit(sf)
 end
 check('same IDs, no Adds or Removes',0,#d().Added+#d().Removed);out.surface=sf.name;return out
end
return P
