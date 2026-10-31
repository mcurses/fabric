-- Spatial template fixtures. The camera's position is the selection.
local M={}
function M.void_chunk(surface,bounds,areas)
  local tiles={}
  for x=bounds.left_top.x,bounds.right_bottom.x-1 do
    for y=bounds.left_top.y,bounds.right_bottom.y-1 do
      local island=false
      for _,area in ipairs(areas or {}) do
        if x>=area.left_top.x and x<area.right_bottom.x and y>=area.left_top.y and y<area.right_bottom.y then island=true; break end
      end
      if not island then tiles[#tiles+1]={name="out-of-map",position={x,y}} end
    end
  end
  if #tiles>0 then surface.set_tiles(tiles,false,false,true,false) end
end
local function ensure_void(demo)
  if demo.void_islands then return end
  for chunk in demo.surface.get_chunks() do
    M.void_chunk(demo.surface,{left_top={x=chunk.x*32,y=chunk.y*32},right_bottom={x=(chunk.x+1)*32,y=(chunk.y+1)*32}},demo.areas)
  end
  demo.void_islands=true
end
function M.ensure(player,context)
  if context.world_demo and context.world_demo.grid_version==2 and context.world_demo.surface.valid then
    ensure_void(context.world_demo)
    player.force.chart(context.world_demo.surface,{{-48,-48},{48,48}})
    return
  end
  local catalog=context.catalog or (context.parent_template and {context.parent_template}) or context.items
  catalog=catalog or {}
  local names={"Iron Plate Pickup","Copper Plate Pickup","Steel Dropoff","Assembly Cell"}
  local icons={"iron-plate","copper-plate","steel-plate","assembling-machine-2"}
  for i=1,4 do
    catalog[i]=catalog[i] or {id=i,name=names[i],icon="item/"..icons[i],is_template=true}
  end
  context.catalog=catalog
  local old=context.world_demo and context.world_demo.surface
  if old and old.valid and old.name=="Template Collection" then
    old.name="Template Collection - previous "..game.tick
  end
  local surface=game.create_surface("Template Collection",{
    width=96,height=96,peaceful_mode=true,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},
      decorative={treat_missing_as_default=false,settings={}}},
  })
  surface.request_to_generate_chunks({0,0},2)
  surface.force_generate_chunk_requests()
  surface.daytime=0
  surface.always_day=true
  player.force.chart(surface,{{-48,-48},{48,48}})
  local demo={surface=surface,grid_version=2,areas={},groups={}}
  context.world_demo=demo
  for i=1,4 do
    local template=catalog[i]
    local x=((i-1)%2)*32-16
    local y=math.floor((i-1)/2)*32-16
    local area={template=template,center={x=x,y=y},groups={},override_examples={},
      left_top={x=x-12,y=y-12},right_bottom={x=x+12,y=y+12}}
    demo.areas[#demo.areas+1]=area
    if not template.variety_fixture_v1 then
      local counts={1,0,3,5}
      local specs={
        {"Input module","transport-belt"},{"Processing module","assembling-machine-2"},
        {"Output module","steel-chest"},{"Power distribution","medium-electric-pole"},
        {"Overflow storage and spare parts","iron-chest"},
      }
      -- Only replace untouched default fixture rows; retain user-added references.
      local defaults=not template.children or (#template.children==3
        and template.children[1].name=="Input module"
        and template.children[2].name=="Processing module"
        and template.children[3].name=="Output module")
      if defaults then
        template.children={}
        for j=1,counts[i] do
          template.children[j]={id=j,name=specs[j][1],icon="item/"..specs[j][2]}
        end
        template.children_next=counts[i]+1
      end
      template.variety_fixture_v1=true
    end
    local tiles={}
    for tx=x-12,x+11 do for ty=y-12,y+11 do
      tiles[#tiles+1]={name=i%2==0 and "refined-concrete" or "concrete",position={tx,ty}}
    end end
    surface.set_tiles(tiles)
    area.border=rendering.draw_rectangle{color={0.5,0.5,0.5},width=2,filled=false,
      left_top=area.left_top,right_bottom=area.right_bottom,surface=surface,players={player.index}}
    area.label=rendering.draw_text{visible=false,text=template.name,target={x=x,y=y-10},surface=surface,
      color={1,1,1},alignment="center",scale=1.3,players={player.index}}
    for j,item in ipairs(template.children) do
      local group={entities={},name=item.name,icon=item.icon}
      area.groups[item.id]=group
      local function place(name,dx,dy)
        local e=surface.create_entity{name=name,position={x=x+dx,y=y+dy},force=player.force,
          direction=defines.direction.east}
        if e then group.entities[#group.entities+1]=e end
      end
      if j==1 then
        for dx=-8,-3 do place(i==2 and "fast-transport-belt" or "transport-belt",dx,-5) end
        place("inserter",-3,-4)
      elseif j==2 then
        place(i==3 and "electric-furnace" or "assembling-machine-2",0,-4)
        place("medium-electric-pole",3,-6)
      elseif j==3 then
        place("steel-chest",6,-4); place("steel-chest",8,-4)
        place("inserter",5,-4)
      elseif j==4 then
        place("medium-electric-pole",-7,0); place("medium-electric-pole",-3,0)
      else
        place("iron-chest",4,0); place("iron-chest",6,0); place("iron-chest",8,0)
      end
    end
  end
  ensure_void(demo)
end
function M.add(player,context,name,existing)
  M.ensure(player,context)
  local catalog=context.catalog
  local id=0
  for _,template in ipairs(catalog) do id=math.max(id,template.id) end
  id=id+1
  local template=existing or {id=id,name=name,icon="item/blueprint",is_template=true,
    children={},children_next=1,variety_fixture_v1=true,
    edit_draft={id=id,name=name,overrides={},fixture_version=2}}
  if not existing then catalog[#catalog+1]=template end
  local demo=context.world_demo
  local i=#demo.areas
  local x=(i%2)*32-16
  local y=math.floor(i/2)*32-16
  local surface=demo.surface
  local settings=surface.map_gen_settings
  settings.width=0; settings.height=0
  surface.map_gen_settings=settings
  surface.request_to_generate_chunks({x=x,y=y},1)
  surface.force_generate_chunk_requests()
  local tiles={}
  for tx=x-12,x+11 do for ty=y-12,y+11 do
    tiles[#tiles+1]={name="refined-concrete",position={tx,ty}}
  end end
  surface.set_tiles(tiles)
  local area={template=template,center={x=x,y=y},groups={},override_examples={},
    left_top={x=x-12,y=y-12},right_bottom={x=x+12,y=y+12}}
  area.border=rendering.draw_rectangle{color={0.5,0.5,0.5},width=2,filled=false,
    left_top=area.left_top,right_bottom=area.right_bottom,surface=surface,players={player.index}}
  area.label=rendering.draw_text{visible=false,text=name,target={x=x,y=y-10},surface=surface,color={1,1,1},
    alignment="center",scale=1.3,players={player.index}}
  demo.areas[#demo.areas+1]=area
  player.force.chart(surface,{area.left_top,area.right_bottom})
  return template
end
function M.area_at(demo,position)
  for _,area in ipairs(demo.areas) do
    if position.x>=area.left_top.x and position.x<area.right_bottom.x
      and position.y>=area.left_top.y and position.y<area.right_bottom.y then return area end
  end
end
return M
