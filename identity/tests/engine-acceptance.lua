-- Scripted real-engine acceptance isolation fixture; not native Undo proof.
local sf=game.create_surface('identity-acceptance-'..game.tick,{width=64,height=64})
sf.request_to_generate_chunks({0,0},1);sf.force_generate_chunk_requests()
for _,en in pairs(sf.find_entities())do en.destroy()end
remote.call('fabric-playground','snapshot',sf.index)
local ghost=sf.create_entity{name='entity-ghost',inner_name='iron-chest',position={.5,.5},force='player'}
local a=sf.create_entity{name='iron-chest',position={2.5,.5},force='player'}
local b=sf.create_entity{name='iron-chest',position={4.5,.5},force='player'}
local before=remote.call('fabric-playground','snapshot',sf.index)
local h=storage.fabric_history
h.restores['acceptance-test']={id='acceptance-test',state='pending',ghost_unit=ghost.unit_number,logical_id='FTEST',tick=game.tick}
local d=remote.call('fabric-playground','accept_unresolved',sf.index,1,{a.unit_number})
assert(d.blocked and #d.accepted==1 and d.accepted[1].unit==a.unit_number,'only selected body accepted')
local mid=remote.call('fabric-playground','snapshot',sf.index)
assert(mid.state.revision==0 and next(mid.state.baseline)==nil,'partial acceptance must retain baseline')
d=remote.call('fabric-playground','accept_unresolved',sf.index,1)
assert(d.blocked and #d.accepted==1 and d.accepted[1].unit==b.unit_number,'idle body accepted')
assert(#d.protected==1 and d.protected[1].unit==ghost.unit_number,'pending restore must remain protected')
assert(h.restores['acceptance-test'].state=='pending','pending receipt untouched')
h.restores['acceptance-test'].state='invalid'
d=remote.call('fabric-playground','accept_unresolved',sf.index,1,{ghost.unit_number})
assert(not d.blocked and #d.accepted==1,'idle ghost explicitly accepted')
local final=remote.call('fabric-playground','snapshot',sf.index)
assert(final.state.revision==1,'only fully resolved revision committed')
helpers.write_file('identity/acceptance.json',helpers.table_to_json({pass=true,kind='scripted-engine',checks=7,revision=final.state.revision,accepted=d.accepted}),false)
rcon.print('PASS 7 scoped acceptance checks')
