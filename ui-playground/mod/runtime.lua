local S=require('__fabric-ui-playground__/snapshots')
local seeds=require('__fabric-ui-playground__/fixtures/library')
local M={}
local function box(center,w,h,pad)
  pad=pad or 0
  return {left_top={x=center.x-w/2-pad,y=center.y-h/2-pad},right_bottom={x=center.x+w/2+pad,y=center.y+h/2+pad}}
end
local function floor(surface,bounds,name)
  local tiles={}
  for x=math.floor(bounds.left_top.x),math.ceil(bounds.right_bottom.x)-1 do
    for y=math.floor(bounds.left_top.y),math.ceil(bounds.right_bottom.y)-1 do
      tiles[#tiles+1]={name=name,position={x,y}}
      if #tiles==8192 then surface.set_tiles(tiles,false,false,true,false);tiles={} end
    end
  end
  if #tiles>0 then surface.set_tiles(tiles,false,false,true,false) end
end
local function generate(surface,bounds)
  local mid={x=(bounds.left_top.x+bounds.right_bottom.x)/2,y=(bounds.left_top.y+bounds.right_bottom.y)/2}
  surface.request_to_generate_chunks(mid,math.ceil(math.max(bounds.right_bottom.x-bounds.left_top.x,bounds.right_bottom.y-bounds.left_top.y)/64)+1)
  surface.force_generate_chunk_requests()
end
local function surface(name)
  return game.surfaces[name] or game.create_surface(name,{width=0,height=0,peaceful_mode=true,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},decorative={treat_missing_as_default=false,settings={}}}})
end
function M.store() return storage.fabric_snapshot end
function M.template(id) return M.store().templates[id] end
function M.ref_name(ref)
  if ref.neighbor then local c=M.store().cells[ref.neighbor];return 'Neighbor · '..c.name end
  local t=M.template(ref.template_id);return t and t.name or 'Missing template'
end
local function prepare_ref(ref)
  ref.name=M.ref_name(ref)
  ref.icon=ref.neighbor and 'utility/expand' or M.template(ref.template_id).icon
  ref.overrides={};ref.override_fixture_v2=true
  return ref
end
function M.catalog()
  local out={};for _,id in ipairs(M.store().order) do out[#out+1]=M.template(id) end;return out
end
function M.layers(id,seen)
  seen=seen or {};assert(not seen[id],'Recursive template reference')
  local t=assert(M.template(id),'Missing template');seen[id]=true
  local out={{snapshot=t.snapshot}}
  for _,ref in ipairs(t.committed_refs) do
    for _,layer in ipairs(M.layers(ref.template_id,seen)) do
      out[#out+1]={snapshot=S.transform(layer.snapshot,ref),reference=ref.id}
    end
  end
  seen[id]=nil;return out
end
function M.depends(id,target,seen)
  if id==target then return true end
  seen=seen or {};if seen[id] then return false end;seen[id]=true
  for _,ref in ipairs(M.template(id).children) do if M.depends(ref.template_id,target,seen) then return true end end
  return false
end
function M.flatten(id)
  local layers=M.layers(id)
  if #layers==1 then return S.copy(layers[1].snapshot) end
  -- Resolve overlaps through the same native build rules as the editor before
  -- making a cursor blueprint; concatenation can contain colliding duplicates.
  local sf=surface('Fabric Preview Composition')
  local bounds={left_top={x=0,y=0},right_bottom={x=0,y=0}}
  for _,layer in ipairs(layers) do
    local b=S.bounds(layer.snapshot)
    bounds.left_top.x=math.min(bounds.left_top.x,b.left_top.x-4)
    bounds.left_top.y=math.min(bounds.left_top.y,b.left_top.y-4)
    bounds.right_bottom.x=math.max(bounds.right_bottom.x,b.right_bottom.x+4)
    bounds.right_bottom.y=math.max(bounds.right_bottom.y,b.right_bottom.y+4)
  end
  generate(sf,bounds);S.clear(sf,bounds);floor(sf,bounds,'refined-concrete')
  for _,layer in ipairs(layers) do S.place(sf,game.forces.player,layer.snapshot,{x=0,y=0}) end
  S.settle(sf,game.forces.player)
  local result=S.capture(sf,game.forces.player,bounds,{x=0,y=0})
  S.clear(sf,bounds)
  return result
end
local function stable(v)
  if type(v)~='table' then return tostring(v) end
  local keys={};for k in pairs(v) do keys[#keys+1]=k end
  table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  local parts={};for _,k in ipairs(keys) do parts[#parts+1]=tostring(k)..'='..stable(v[k]) end
  return '{'..table.concat(parts,',')..'}'
end
function M.signature(snapshot)
  local parts={};local names={}
  for _,entity in ipairs(snapshot.entities or {}) do
    local e=S.copy(entity);e.entity_number=nil
    -- Circuit-driven outputs are simulation state, not authored configuration.
    if e.control_behavior and e.control_behavior.circuit_set_filters then e.filters=nil end
    if e.name=='ghost-scanner-ia' then e.control_behavior=nil end
    if e.tags then e.tags['@i']=nil end
    local text=stable(e);names[entity.entity_number]=text;parts[#parts+1]=text
  end
  for _,wire in ipairs(snapshot.wires or {}) do
    local a=(names[wire[1]] or '?')..':'..wire[2];local b=(names[wire[3]] or '?')..':'..wire[4]
    if a>b then a,b=b,a end;parts[#parts+1]='wire:'..a..'>'..b
  end
  for _,tile in ipairs(snapshot.tiles or {}) do parts[#parts+1]='tile:'..stable(tile) end
  table.sort(parts);return table.concat(parts,'\n')
end
function M.capture(t)
  if not t.area or not t.area.built then return S.copy(t.snapshot) end
  return S.capture(M.store().collection_surface,game.forces.player,t.area.edit_bounds,t.area.center,t.area.excluded)
end
local function ref_signature(refs)
  local out={}
  for _,ref in ipairs(refs or {}) do
    out[#out+1]={template_id=ref.template_id,x=ref.x,y=ref.y,direction=ref.direction,
      flip_horizontal=ref.flip_horizontal,flip_vertical=ref.flip_vertical}
  end
  return stable(out)
end
function M.dirty(t)
  if t.draft_dirty or ref_signature(t.children)~=ref_signature(t.committed_refs) then return true end
  return false
end
function M.check_dirty(t)
  if t.area and t.area.built then
    t.draft_dirty=M.signature(M.capture(t))~=t.area.baseline
  end
  return M.dirty(t)
end
local function clear_underlay(area)
  for _,obj in ipairs(area.underlay or {}) do if obj.valid then obj.destroy() end end;area.underlay={}
end
function M.underlay(player,t)
  local area=t.area;if not area then return end
  clear_underlay(area)
  if not t.origin_id or t.show_underlay==false then return end
  -- Rendering sprites have no collision, cannot be mined or captured, and never
  -- become children. They are deliberately below actual editable entities.
  for _,layer in ipairs(M.layers(t.origin_id)) do
    for _,e in ipairs(layer.snapshot.entities or {}) do
      local proto=prototypes.entity[e.name]
      if proto then
        local sprite='entity/'..e.name
        local ok,obj=pcall(rendering.draw_sprite,{sprite=sprite,surface=M.store().collection_surface,
          target={x=area.center.x+e.position.x,y=area.center.y+e.position.y},
          tint={r=0.25,g=0.5,b=0.65,a=0.25},x_scale=0.65,y_scale=0.65,
          render_layer='floor',players={player.index}})
        if ok then area.underlay[#area.underlay+1]=obj end
      end
    end
  end
end
function M.render_editor(player,t,own)
  local area=t.area;if not area then return end
  local sf=M.store().collection_surface
  local was_dirty=own and (t.draft_dirty or (area.baseline and M.signature(own)~=area.baseline)) or false
  S.clear(sf,area.edit_bounds);floor(sf,area.edit_bounds,'refined-concrete')
  area.groups={};area.excluded={}
  S.place(sf,player.force,own or t.snapshot,area.center)
  for _,ref in ipairs(t.children) do
    prepare_ref(ref);local group={name=ref.name,icon=ref.icon,entities={}}
    for _,layer in ipairs(M.layers(ref.template_id)) do
      for _,e in ipairs(S.place(sf,player.force,S.transform(layer.snapshot,ref),area.center)) do
        group.entities[#group.entities+1]=e;area.excluded[S.entity_key(e)]=true
      end
    end
    area.groups[ref.id]=group
  end
  area.built=true
  -- Normalize the original snapshot through the engine once for stable comparison.
  if not own or not area.baseline then area.baseline=M.signature(S.capture(sf,player.force,area.edit_bounds,area.center,area.excluded)) end
  t.draft_dirty=was_dirty
  M.underlay(player,t)
end
function M.ensure_area(player,t)
  if t.area then return t.area end
  local sf=M.store().collection_surface
  local n=t.id-1;local center={x=(n%5)*1536,y=math.floor(n/5)*1536}
  local edit=box(center,t.width,t.height,t.padding)
  local bounds=box(center,t.width,t.height)
  t.area={template=t,center=center,left_top=bounds.left_top,right_bottom=bounds.right_bottom,edit_bounds=edit,groups={}}
  generate(sf,edit);floor(sf,edit,'refined-concrete')
  t.area.border=rendering.draw_rectangle{surface=sf,left_top=bounds.left_top,right_bottom=bounds.right_bottom,color={0.2,0.9,1},width=3}
  t.area.padding_border=rendering.draw_rectangle{surface=sf,left_top=edit.left_top,right_bottom=edit.right_bottom,color={0.35,0.35,0.4},width=1}
  M.render_editor(player,t)
  player.force.chart(sf,edit)
  return t.area
end
local function cell_layers(cell)
  local layers={}
  if M.store().world_origin then
    for _,l in ipairs(M.layers(M.store().world_origin)) do layers[#layers+1]={snapshot=l.snapshot,key='origin'} end
  end
  for _,ref in ipairs(cell.items) do
    if not ref.neighbor then
      for _,l in ipairs(M.layers(ref.template_id)) do layers[#layers+1]={snapshot=S.transform(l.snapshot,ref),key=ref.id} end
    end
  end
  return layers
end
function M.neighbors()
  local db=M.store()
  for _,cell in ipairs(db.cells) do
    local wanted={}
    for _,other in ipairs(db.cells) do
      if other~=cell then
        for _,layer in ipairs(cell_layers(other)) do
          local b=S.shift_bounds(S.bounds(layer.snapshot),other.center)
          if S.intersects(b,cell.bounds) then wanted[other.id]=true;break end
        end
      end
    end
    local keep={};local found={}
    for _,ref in ipairs(cell.items) do
      if not ref.neighbor or wanted[ref.neighbor] then keep[#keep+1]=prepare_ref(ref);if ref.neighbor then found[ref.neighbor]=true end end
    end
    for _,other in ipairs(db.cells) do
      if wanted[other.id] and not found[other.id] then
        keep[#keep+1]=prepare_ref{id=db.next_ref,neighbor=other.id};db.next_ref=db.next_ref+1
      end
    end
    cell.items=keep
  end
end
function M.rebuild_world(player)
  local db=M.store();if not db.world_origin then return end
  M.neighbors()
  local sf=db.world_surface
  local extent={left_top={x=db.cells[1].left_top.x,y=db.cells[1].left_top.y},right_bottom={x=db.cells[1].right_bottom.x,y=db.cells[1].right_bottom.y}}
  for _,cell in ipairs(db.cells) do
    for _,layer in ipairs(cell_layers(cell)) do
      local b=S.shift_bounds(S.bounds(layer.snapshot),cell.center)
      extent.left_top.x=math.min(extent.left_top.x,b.left_top.x);extent.left_top.y=math.min(extent.left_top.y,b.left_top.y)
      extent.right_bottom.x=math.max(extent.right_bottom.x,b.right_bottom.x);extent.right_bottom.y=math.max(extent.right_bottom.y,b.right_bottom.y)
    end
  end
  if db.world_built_bounds then S.clear(sf,db.world_built_bounds) end
  generate(sf,extent);S.clear(sf,extent);floor(sf,extent,'grass-1');db.world_built_bounds=extent
  local function outside(p)
    for _,cell in ipairs(db.cells) do if S.inside(p,cell.bounds) then return false end end
    return true
  end
  -- The outermost cells still have extensions: do not cut off ramp supports or rails.
  for _,cell in ipairs(db.cells) do
    floor(sf,cell.bounds,'refined-concrete');cell.groups={}
    for _,layer in ipairs(cell_layers(cell)) do S.place(sf,player.force,layer.snapshot,cell.center,outside) end
  end
  for _,cell in ipairs(db.cells) do
    for _,layer in ipairs(M.layers(db.world_origin)) do S.place(sf,player.force,layer.snapshot,cell.center,cell.bounds) end
    for _,ref in ipairs(cell.items) do
      local group={name=M.ref_name(ref),icon=ref.icon,entities={}}
      local layers,center
      if ref.neighbor then layers=cell_layers(db.cells[ref.neighbor]);center=db.cells[ref.neighbor].center
      else layers=M.layers(ref.template_id);center=cell.center end
      for _,layer in ipairs(layers) do
        local snapshot=ref.neighbor and layer.snapshot or S.transform(layer.snapshot,ref)
        for _,e in ipairs(S.place(sf,player.force,snapshot,center,cell.bounds)) do group.entities[#group.entities+1]=e end
      end
      cell.groups[ref.id]=group
    end
  end
  -- Rails crossing a cell boundary may need a support from a later cell.
  S.settle(sf,player.force)
  for _,cell in ipairs(db.cells) do
    for _,layer in ipairs(cell_layers(cell)) do S.rewire(sf,layer.snapshot,cell.center) end
    for _,ref in ipairs(cell.items) do
      local group=cell.groups[ref.id];group.entities={}
      local layers=ref.neighbor and cell_layers(db.cells[ref.neighbor]) or M.layers(ref.template_id)
      local center=ref.neighbor and db.cells[ref.neighbor].center or cell.center
      for _,layer in ipairs(layers) do
        local snapshot=ref.neighbor and layer.snapshot or S.transform(layer.snapshot,ref)
        for _,e in ipairs(snapshot.entities or {}) do
          local pos={x=e.position.x+center.x,y=e.position.y+center.y}
          if S.inside(pos,cell.bounds) then
            local real=S.find(sf,e,center);if real then group.entities[#group.entities+1]=real end
          end
        end
      end
    end
  end
end
function M.commit(player,t)
  local own=M.capture(t)
  -- Validate graph before changing the committed snapshot.
  for _,ref in ipairs(t.children) do assert(not M.depends(ref.template_id,t.id),'A template cannot reference itself, even indirectly.') end
  local drafts={}
  for _,other in ipairs(M.catalog()) do if other~=t and other.area and M.depends(other.id,t.id) then drafts[other.id]=M.capture(other) end end
  t.snapshot=own;t.committed_refs=S.copy(t.children);t.version=t.version+1;t.edit_version=t.version;t.draft_dirty=false
  M.render_editor(player,t)
  for _,other in ipairs(M.catalog()) do
    if drafts[other.id] then M.render_editor(player,other,drafts[other.id])
    elseif other.area and other.origin_id==t.id then M.underlay(player,other) end
  end
  M.rebuild_world(player)
end
function M.discard(player,t)
  t.children=S.copy(t.committed_refs);t.draft_dirty=false;M.render_editor(player,t)
end
function M.add_reference(player,state,template_id,position,transform)
  local db=M.store();local source=assert(M.template(template_id))
  local target=state.workspace=='collection' and state.parent_template or state.camera_area
  assert(target,'Move the camera into an instance or template first.')
  if state.workspace=='collection' then assert(not M.depends(template_id,target.id),'This reference would create a template cycle.') end
  local center=state.workspace=='collection' and target.area.center or target.center
  local ref=prepare_ref{id=db.next_ref,template_id=template_id,x=position.x-center.x,y=position.y-center.y,
    direction=transform and transform.direction or 0,flip_horizontal=transform and transform.flip_horizontal or false,flip_vertical=transform and transform.flip_vertical or false}
  db.next_ref=db.next_ref+1
  if state.workspace=='collection' then
    local own=M.capture(target);target.children[#target.children+1]=ref;target.draft_dirty=true
    M.render_editor(player,target,own)
  else target.items[#target.items+1]=ref;M.rebuild_world(player) end
  return ref
end
function M.remove_reference(player,state,id)
  local target=state.workspace=='collection' and state.parent_template or state.camera_area
  if not target then return end
  local list=state.workspace=='collection' and target.children or target.items
  local own=state.workspace=='collection' and M.capture(target)
  for i,ref in ipairs(list) do if ref.id==id and not ref.neighbor then table.remove(list,i);break end end
  if own then target.draft_dirty=true;M.render_editor(player,target,own) else M.rebuild_world(player) end
end
function M.reorder(player,state,id,index)
  local target=state.workspace=='collection' and state.parent_template or state.camera_area
  if not target then return end
  local list=state.workspace=='collection' and target.children or target.items
  local found
  for i,ref in ipairs(list) do if ref.id==id then found=i;break end end
  if not found or found==index then return end
  local own=state.workspace=='collection' and M.capture(target)
  for i,ref in ipairs(list) do if ref.id==id then table.remove(list,i);table.insert(list,math.max(1,math.min(#list+1,index)),ref);break end end
  if own then target.draft_dirty=true;M.render_editor(player,target,own) else M.rebuild_world(player) end
end
function M.create(player,options)
  local db=M.store();local origin=options.origin_id and M.template(options.origin_id)
  assert(not origin or origin.is_origin,'Choose an Origin Template.')
  local w=origin and origin.width or options.width or 160
  local h=origin and origin.height or options.height or 160
  local padding=options.padding or 32
  assert(w>=16 and w<=512 and h>=16 and h<=512 and w%2==0 and h%2==0,'Dimensions must be even numbers between 16 and 512.')
  assert(padding>=0 and padding<=256 and padding%2==0,'Padding must be an even number between 0 and 256.')
  local id=#db.order+1
  local t={id=id,name=options.name,icon=options.icon or 'item/blueprint',category=options.category or 'Other',
    is_template=true,is_origin=options.is_origin or false,origin_id=options.origin_id,width=w,height=h,padding=padding,
    snapshot=S.empty(),children={},committed_refs={},version=1,edit_version=1,show_underlay=true}
  db.templates[id]=t;db.order[#db.order+1]=id
  M.ensure_area(player,t);return t
end
function M.configure_world(player,id)
  local db=M.store();local origin=assert(M.template(id));assert(origin.is_origin,'Select an Origin Template.')
  if db.world_width then assert(origin.width==db.world_width and origin.height==db.world_height,'World dimensions are fixed. Choose an origin with the same dimensions.') end
  db.world_origin=id;db.world_width=origin.width;db.world_height=origin.height
  if #db.cells==0 then
    local names={'Amber Voyager','Starlit Weaver','Copper Horizon','Silent Pioneer'}
    for i=1,4 do
      local center={x=((i-1)%2)*origin.width,y=math.floor((i-1)/2)*origin.height}
      local c={id=i,name=names[i],center=center,items={},groups={},bounds=box(center,origin.width,origin.height)}
      c.left_top=c.bounds.left_top;c.right_bottom=c.bounds.right_bottom
      db.cells[i]=c;generate(db.world_surface,c.bounds)
      c.border=rendering.draw_rectangle{surface=db.world_surface,left_top=c.left_top,right_bottom=c.right_bottom,color={0.5,0.5,0.5},width=2}
    end
    local defaults={{3,4,5,8},{3,7,8},{10},{12,13}}
    for i,ids in ipairs(defaults) do for _,template_id in ipairs(ids) do
      db.cells[i].items[#db.cells[i].items+1]=prepare_ref{id=db.next_ref,template_id=template_id,x=0,y=0};db.next_ref=db.next_ref+1
    end end
  end
  M.rebuild_world(player)
end
function M.ensure(player)
  if storage.fabric_snapshot and storage.fabric_snapshot.ready then
    local db=storage.fabric_snapshot
    if db.placement_revision~=4 then M.rebuild_world(player);db.placement_revision=4 end
    return db
  end
  for _,name in ipairs({'cybersyn2-combinator','ghost-scanner-ia','elevated-straight-rail','turbo-transport-belt'}) do
    assert(prototypes.entity[name],'Restart using play.sh to load the real library dependencies: '..name)
  end
  local db={schema=1,templates={},order={},cells={},next_ref=1,categories={'Base Grid','Requester','Provider','Trash','Gleba','Other'}}
  storage.fabric_snapshot=db
  db.collection_surface=surface('Fabric Templates');db.collection_surface.always_day=true
  db.world_surface=surface('Fabric World');db.world_surface.always_day=true
  for _,seed in ipairs(seeds) do
    local snapshot=S.transform(S.decode(seed.bp),{x=-80,y=-80})
    local b=S.bounds(snapshot)
    local padding=math.ceil(math.max(32,-80-b.left_top.x,-80-b.left_top.y,b.right_bottom.x-80,b.right_bottom.y-80)/2)*2
    local t={id=seed.id,name=seed.name,source_label=seed.source_label,source_version=seed.source_version,
      icon=seed.icon,category=seed.category,is_template=true,is_origin=seed.id==1,origin_id=seed.id~=1 and 1 or nil,
      width=160,height=160,padding=math.max(160,padding),snapshot=snapshot,children={},committed_refs={},
      version=seed.source_version,edit_version=seed.source_version,slots=S.copy(seed.slots),description=seed.description,show_underlay=true}
    db.templates[t.id]=t;db.order[#db.order+1]=t.id
  end
  -- The old mod's uses: declarations were live nested references, not copied content.
  for _,t in ipairs(M.catalog()) do
    local uses=t.description:match('uses:%s*([^\n]+)')
    if uses then
      for name,x,y in uses:gmatch('([^;]+)%s*=%s*([%-%.%d]+),%s*([%-%.%d]+)') do
        name=name:match('^%s*(.-)%s*$')
        for _,source in ipairs(M.catalog()) do if source.source_label==name then
          t.children[#t.children+1]=prepare_ref{id=db.next_ref,template_id=source.id,x=tonumber(x),y=tonumber(y)};db.next_ref=db.next_ref+1;break
        end end
      end
      t.committed_refs=S.copy(t.children)
    end
  end
  M.configure_world(player,1)
  db.placement_revision=4;db.ready=true
  return db
end
function M.on_chunk(surface,bounds)
  local db=M.store();if not db then return end
  if surface==db.world_surface then floor(surface,bounds,'grass-1');return end
  if surface~=db.collection_surface then return end
  floor(surface,bounds,'out-of-map')
  for _,t in ipairs(M.catalog()) do
    if t.area and S.intersects(t.area.edit_bounds,bounds) then
      local a=t.area.edit_bounds
      floor(surface,{left_top={x=math.max(a.left_top.x,bounds.left_top.x),y=math.max(a.left_top.y,bounds.left_top.y)},
        right_bottom={x=math.min(a.right_bottom.x,bounds.right_bottom.x),y=math.min(a.right_bottom.y,bounds.right_bottom.y)}},'refined-concrete')
    end
  end
end
M.box=box
return M
