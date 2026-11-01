script.on_event(defines.events.on_tick,function(e)
  if script.test_arg~='persistence' or e.tick%30~=0 then return end
  local p=game.get_player(1);if not p then return end
  if remote.call('fabric-ui-test','busy') then return end
  local state=remote.call('fabric-ui-test','inspect',p.index)
  assert(#state.catalog>=20 and #state.cells==4)
  assert(state.catalog[1].name=='The Grid' and state.catalog[1].is_origin)
  assert(state.catalog[5].name=='Universal request' and state.catalog[8].name=='Trash sender')
  assert(game.surfaces['Fabric World'].count_entities_filtered{type='straight-rail'}>100)
  log('SAVE_RELOAD_PASS');script.finish_test(true)
end)
