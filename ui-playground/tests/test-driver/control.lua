script.on_event(defines.events.on_tick,function(e)
  if storage.finished then return end
  local mode=script.test_arg
  if (mode~='persistence' and mode~='handover' and mode~='handover-check') or e.tick%30~=0 then return end
  local p=game.get_player(1);if not p or remote.call('fabric-ui-test','busy') then return end
  if mode=='handover' and not storage.prepared then
    remote.call('fabric-ui-test','prepare_handover',p.index)
    storage.prepared=true;return
  end
  if mode=='handover' and storage.saved_tick and e.tick<=storage.saved_tick+60 then return end
  local state=remote.call('fabric-ui-test','inspect',p.index)
  local names={};for _,t in ipairs(state.catalog) do names[t.name]=t end
  assert(names['The Grid'] and names['The Grid'].is_origin)
  assert(names['Bayspine Requester'] and names['Bayspine Provider'] and names['Bay spine'])
  assert(p.controller_type==defines.controllers.editor,'Starter opens in editor mode')
  if mode=='handover' or mode=='handover-check' then
    assert(#state.cells==1 and #state.cells[1].items==1 and state.cells[1].items[1].origin,'Only one grid-only instance')
    for _,t in ipairs(state.catalog) do
      assert(not t.slot_anchor and not t.slot_eligible and t.preview_refs==0)
      for _,slot in ipairs(t.slot_definitions or {}) do assert(not slot.anchor) end
      local sf=game.surfaces['Fabric Templates']
      if not p.force.is_chunk_charted(sf,{math.floor(t.center.x/32),math.floor(t.center.y/32)}) then
        if mode=='handover' then return else error('Template not explored: '..t.name) end
      end
    end
    if mode=='handover' and not storage.saved_tick then storage.saved_tick=e.tick;if script.test_arg then game.auto_save('fabric-handover') else game.server_save('fabric-handover') end;return end
    log('CLEAN_HANDOVER_PASS')
  end
  log('SAVE_RELOAD_PASS');if script.test_arg then script.finish_test(true) else storage.finished=true;helpers.write_file('handover-ready.txt','ready',false) end
end)
