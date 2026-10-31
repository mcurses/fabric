local review=require('__fabric-ui-playground__/overrides')
local R=require('__fabric-ui-playground__/runtime')
local S=require('__fabric-ui-playground__/snapshots')
local W=require('__fabric-ui-playground__/workspaces')
local ui=require('__fabric-ui-playground__/ui')
local done=false
local initialized=false
script.on_event(defines.events.on_tick,function()
  if done then return end
  local p=game.get_player(1);if not p then return end
  local db=R.ensure(p)
  assert(#R.catalog()==20)
  assert(db.world_width==160 and db.world_height==160)
  assert(R.template(1).is_origin and R.template(5).source_version==7 and R.template(8).source_version==6)
  local s={};W.init(s);W.attach(p,s);W.select_camera(p,s);ui.build(p,s)
  if not initialized then
  log('REAL_LIBRARY_PASS')
  for _,source in ipairs(R.catalog()) do
    local area=R.ensure_area(p,source)
    local missing=0
    for _,e in ipairs(source.snapshot.entities or {}) do
      local pos={x=area.center.x+e.position.x,y=area.center.y+e.position.y}
      local found=false
      for _,real in ipairs(db.collection_surface.find_entities_filtered{name=e.name,position=pos,radius=0.05}) do
        if real.direction==(e.direction or 0) then found=true;break end
      end
      if not found then
        missing=missing+1
        local ghost=false
        for _,g in ipairs(db.collection_surface.find_entities_filtered{type='entity-ghost',position=pos,radius=.05}) do
          if g.ghost_name==e.name and g.direction==(e.direction or 0) then ghost=true end
        end
        assert(ghost,'Source piece must exist as real entity or supported blueprint ghost: '..source.name..'/'..e.name)
      end
    end
    log('SOURCE_BUILD '..source.name..' missing='..missing..' total='..#source.snapshot.entities)
  end
  initialized=true;return
  end
  done=true
  local captured=R.capture(R.template(2))
  assert(#captured.entities==455,'Unsupported CS2 rail ghosts must survive capture')
  local request=R.capture(R.template(5));local metadata_ok=false
  for _,e in ipairs(request.entities) do
    if e.name=='cybersyn2-combinator' then
      assert(e.tags and e.tags['@t'] and e.tags['@t'].pr==2 and e.tags['@t'].order_primary_network=='signal-A','Cybersyn settings must round-trip')
      metadata_ok=true
    end
  end
  assert(metadata_ok)
  assert(not R.check_dirty(R.template(5)), 'Fresh template must remain clean after mod registration')
  log('COOPERATIVE_METADATA_PASS')
  local initial={}
  for _,cell in ipairs(db.cells) do initial[cell.id]=cell.items;cell.items={} end
  R.rebuild_world(p)
  local grid_missing=0
  for _,cell in ipairs(db.cells) do
    for _,e in ipairs(R.template(1).snapshot.entities) do
      local pos={x=cell.center.x+e.position.x,y=cell.center.y+e.position.y}
      local inside=false
      for _,receiver in ipairs(db.cells) do if S.inside(pos,receiver.bounds) then inside=true end end
      if inside and not S.find(db.world_surface,e,cell.center) then grid_missing=grid_missing+1;if grid_missing<=20 then log('GRID_MISSING '..e.name..' '..pos.x..','..pos.y) end end
    end
  end
  log('WORLD_GRID_MISSING '..grid_missing)
  local baseline=game.create_surface('Native grid comparison',{autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
  baseline.request_to_generate_chunks({80,80},14);baseline.force_generate_chunk_requests()
  local floor={}
  for x=-256,511 do for y=-256,511 do floor[#floor+1]={name='refined-concrete',position={x,y}} end end
  baseline.set_tiles(floor)
  for _,cell in ipairs(db.cells) do S.place(baseline,p.force,R.template(1).snapshot,cell.center) end
  S.settle(baseline,p.force)
  local mismatch=0
  for _,real in ipairs(baseline.find_entities_filtered{force=p.force}) do
    local inside=false;for _,cell in ipairs(db.cells) do if S.inside(real.position,cell.bounds) then inside=true end end
    if inside and real.type~='entity-ghost' and not S.find(db.world_surface,{name=real.name,position=real.position,direction=real.direction},{x=0,y=0}) then
      mismatch=mismatch+1
      if mismatch<15 then
        local at={};for _,v in ipairs(db.world_surface.find_entities_filtered{position=real.position,radius=.05}) do at[#at+1]=v.name..':'..v.direction end
        log('NATIVE_MISMATCH '..real.name..' '..real.position.x..','..real.position.y..' dir='..real.direction..' actual='..table.concat(at,','))
      end
    end
  end
  log('NATIVE_GRID_MISMATCH '..mismatch)
  assert(mismatch==0,'Grid must match native full-snapshot placement across boundaries')
  -- Compare our stored transform with native blueprint cursor placement, including chiral rails.
  local original=R.template(1).snapshot
  local former_surface,former_position=p.surface,p.position
  p.teleport({0,0},baseline)
  for _,direction in ipairs({0,4,8,12}) do
    for _,flip in ipairs({{h=false,v=false},{h=true,v=false},{h=false,v=true},{h=true,v=true}}) do
      S.clear(baseline,{left_top={x=-512,y=-512},right_bottom={x=512,y=512}})
      local plan=S.copy(original);plan['snap-to-grid']={x=2,y=2};plan['absolute-snapping']=true
      p.cursor_stack.set_stack{name='blueprint'};p.cursor_stack.import_stack(S.encode(plan))
      p.build_from_cursor{position={0,0},direction=direction,flip_horizontal=flip.h,flip_vertical=flip.v,build_mode=defines.build_mode.forced}
      S.settle(baseline,p.force)
      local rotation={direction=direction,flip_horizontal=flip.h,flip_vertical=flip.v}
      local pivot=S.point({x=1,y=1},rotation)
      rotation.x=1-pivot.x;rotation.y=1-pivot.y
      local transformed=S.transform(original,rotation)
      local missing=0
      for _,item in ipairs(transformed.entities) do
        local exists=S.find(baseline,item,{x=0,y=0})
        if not exists then
          for _,g in ipairs(baseline.find_entities_filtered{type='entity-ghost',position=item.position,radius=.05}) do
            if g.ghost_name==item.name and g.direction==item.direction then exists=true end
          end
        end
        if not exists then
          missing=missing+1
          if missing<4 then
            local actual={}
            for _,v in ipairs(baseline.find_entities_filtered{name=item.name,position=item.position,radius=3}) do log('NEAR '..v.name..' '..v.position.x..','..v.position.y..' expected='..item.position.x..','..item.position.y..' direction='..v.direction) end
            for _,v in ipairs(baseline.find_entities_filtered{position=item.position,radius=.05}) do actual[#actual+1]=v.name..':'..v.direction end
            log('TRANSFORM_DIFF '..direction..' h='..tostring(flip.h)..' v='..tostring(flip.v)..' '..item.name..':'..item.direction..' actual='..table.concat(actual,','))
          end
        end
      end
      log('TRANSFORM_MISSING '..direction..' h='..tostring(flip.h)..' v='..tostring(flip.v)..' '..missing)
      assert(missing==0,'Stored transform must match native blueprint rotation and flip')
    end
  end
  p.clear_cursor();p.teleport(former_position,former_surface)
  log('NATIVE_TRANSFORMS_PASS')
  for _,cell in ipairs(db.cells) do cell.items=initial[cell.id] end
  R.rebuild_world(p)
  local t=R.create(p,{name='Test snapshot',width=32,height=32,padding=8})
  local pos=t.area.center
  local sf=db.collection_surface
  local chest=sf.create_entity{name='steel-chest',position={pos.x+3.5,pos.y+3.5},force=p.force}
  assert(chest)
  R.check_dirty(t);assert(R.dirty(t))
  R.commit(p,t);assert(#t.snapshot.entities==1)
  local rebuilt=sf.find_entity('steel-chest',{pos.x+3.5,pos.y+3.5})
  assert(rebuilt,'Snapshot positions must be preserved exactly')
  log('SNAPSHOT_COORDINATES_PASS')
  local nested=R.create(p,{name='Nested',width=32,height=32,padding=8})
  W.focus_template(p,s,nested.id)
  R.add_reference(p,s,t.id,{x=nested.area.center.x+6,y=nested.area.center.y})
  R.commit(p,nested)
  assert(#nested.snapshot.entities==0,'References must not be baked into own snapshot')
  assert(#nested.committed_refs==1)
  local own_origin=R.create(p,{name='Test Origin',width=160,height=160,padding=8,is_origin=true})
  R.configure_world(p,own_origin.id)
  for _,cell in ipairs(db.cells) do cell.items={} end
  R.rebuild_world(p)
  W.switch(p,s,'world');p.teleport(db.cells[1].center,db.world_surface);W.select_camera(p,s)
  R.add_reference(p,s,nested.id,db.cells[1].center)
  assert(db.world_surface.find_entity('steel-chest',{9.5,3.5}),'Nested placement')
  local leaf_pos=t.area.center
  sf.find_entity('steel-chest',{leaf_pos.x+3.5,leaf_pos.y+3.5}).destroy()
  sf.create_entity{name='iron-chest',position={leaf_pos.x+3.5,leaf_pos.y+3.5},force=p.force}
  R.commit(p,t)
  assert(db.world_surface.find_entity('iron-chest',{9.5,3.5}),'Commit must propagate through nested templates immediately')
  assert(not db.world_surface.find_entity('steel-chest',{9.5,3.5}))
  assert(sf.find_entity('iron-chest',{nested.area.center.x+9.5,nested.area.center.y+3.5}),'Nested editor updates too')
  local saved_snapshot=nested.snapshot
  nested.snapshot=S.empty();nested.snapshot.entities={{entity_number=1,name='steel-chest',position={x=9.5,y=3.5}}}
  local flattened=R.flatten(nested.id)
  assert(#flattened.entities==1 and flattened.entities[1].name=='iron-chest','Cursor composition resolves overlapping layers last-wins')
  assert(flattened.entities[1].position.x==9.5)
  nested.snapshot=saved_snapshot
  log('CURSOR_COMPOSITION_PASS')
  local manual=db.world_surface.create_entity{name='small-lamp',position={20.5,20.5},force=p.force}
  R.rebuild_world(p);assert(not manual.valid,'World manual edits are explicitly discarded')
  local draft=sf.create_entity{name='small-lamp',position={leaf_pos.x+10.5,leaf_pos.y+10.5},force=p.force}
  R.check_dirty(t);assert(R.dirty(t));R.discard(p,t);assert(not draft.valid and not R.dirty(t))
  assert(not pcall(function() W.focus_template(p,s,t.id);R.add_reference(p,s,nested.id,t.area.center) end),'Cycle rejected')
  local tiny=R.create(p,{name='Wrong size origin',width=32,height=32,padding=0,is_origin=true})
  assert(not pcall(function() R.configure_world(p,tiny.id) end),'World dimensions must stay fixed')
  log('NESTING_PROPAGATION_DISCARD_PASS')
  -- Underlays are rendering only: their content never appears in a new snapshot.
  local under=R.create(p,{name='Underlay child',origin_id=own_origin.id,padding=12})
  assert(under.width==160 and under.padding==12 and #under.children==0)
  R.commit(p,under);assert(#under.snapshot.entities==0)
  -- Neighbor precedence is local to the receiving cell; last row wins.
  local other=R.create(p,{name='Other chest',width=32,height=32,padding=8})
  sf.create_entity{name='steel-chest',position={other.area.center.x+3.5,other.area.center.y+3.5},force=p.force}
  R.commit(p,other)
  for _,cell in ipairs(db.cells) do cell.items={} end
  W.switch(p,s,'world');p.teleport(db.cells[1].center,db.world_surface);W.select_camera(p,s)
  R.add_reference(p,s,t.id,{x=80,y=0})
  p.teleport(db.cells[2].center,db.world_surface);W.select_camera(p,s)
  R.add_reference(p,s,other.id,{x=80,y=0})
  -- Newly added own row is last and wins over the already-present neighbor.
  assert(db.world_surface.find_entity('steel-chest',{83.5,3.5}))
  local neighbor
  for _,ref in ipairs(db.cells[2].items) do if ref.neighbor==1 then neighbor=ref end end
  assert(neighbor)
  R.reorder(p,s,neighbor.id,#db.cells[2].items)
  assert(db.world_surface.find_entity('iron-chest',{83.5,3.5}),'Neighbor last wins inside receiving cell')
  local before=#db.cells[2].items;R.remove_reference(p,s,neighbor.id);assert(#db.cells[2].items==before)
  log('NEIGHBOR_PRECEDENCE_PASS')
  W.focus_template(p,s,t.id);ui.build(p,s)
  local tileonly=R.create(p,{name='Tiles',width=16,height=16,padding=0})
  sf.set_tiles{{name='stone-path',position=tileonly.area.center}}
  R.commit(p,tileonly)
  assert(#tileonly.snapshot.entities==0 and #tileonly.snapshot.tiles==1,'Tile-only snapshot retained')
  assert(sf.get_tile(tileonly.area.center).name=='stone-path')
  W.focus_template(p,s,t.id);s.reviewing_parent=true
  review.show(p,s,t.id);review.apply_tuning(p,s);review.close(p,s)
  assert(not p.gui.screen[review.panel_name] and not s.reviewing_parent,'Review closes once')
  log('FUNCTIONAL_SMOKE_PASS')
  script.finish_test(true)
end)
