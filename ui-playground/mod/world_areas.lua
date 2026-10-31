-- World blocks share camera selection and the existing instance-row renderer.
local M={}
local adjectives={"Amber","Silent","Silver","Wandering","Crimson","Distant","Golden","Velvet","Starlit","Copper","Midnight","Solar"}
local nouns={"Voyager","Sparrow","Horizon","Pioneer","Comet","Weaver","Aurora","Nomad","Kestrel","Odyssey","Lantern","Drifter"}
function M.rename(demo,area,name)
  local previous=area.name
  area.name=name
  if area.label and area.label.valid then area.label.text=name
  else
    for _,object in pairs(rendering.get_all_objects()) do
      if object.valid and object.type=="text" and object.surface==demo.surface and object.text==previous then
        object.text=name; area.label=object; break
      end
    end
  end
end
local function assign_names(demo)
  local used={}
  for _,area in ipairs(demo.world_areas) do if area.generated_name then used[area.name]=true end end
  for _,area in ipairs(demo.world_areas) do
    if not area.generated_name then
      local name
      repeat name=adjectives[math.random(#adjectives)].." "..nouns[math.random(#nouns)] until not used[name]
      M.rename(demo,area,name)
      area.generated_name=true; used[name]=true
    end
  end
end
local function ensure_land(demo)
  if demo.land_around_islands_v2 then return end
  local tiles={}
  for _,area in ipairs(demo.world_areas) do
    for x=area.left_top.x,area.right_bottom.x-1 do
      for y=area.left_top.y,area.right_bottom.y-1 do
        tiles[#tiles+1]={name="refined-concrete",position={x,y}}
      end
    end
  end
  -- Fill old finite-surface edges left behind by the initial demo.
  for chunk in demo.surface.get_chunks() do
    for _,tile in ipairs(demo.surface.find_tiles_filtered{area={{chunk.x*32,chunk.y*32},{(chunk.x+1)*32,(chunk.y+1)*32}},name="out-of-map"}) do
      tiles[#tiles+1]={name="grass-1",position=tile.position}
    end
  end
  demo.surface.set_tiles(tiles,false,false,true,false)
  demo.land_around_islands_v2=true
end
function M.ensure(player,state)
  local demo=state.world_demo
  if not demo or not demo.surface.valid then return end
  if demo.world_areas then assign_names(demo); ensure_land(demo); return end
  local surface=demo.surface
  local settings=surface.map_gen_settings
  settings.width=0; settings.height=0; surface.map_gen_settings=settings
  surface.request_to_generate_chunks({64,32},4); surface.force_generate_chunk_requests()
  demo.world_areas={}
  local specs={{0,0,0,"Main Instance"},{64,0,1,"Single Template Instance"},{128,0,5,"Production Instance"},{64,64,10,"Busy Instance"},{128,64,0,"Empty Instance"}}
  for i,spec in ipairs(specs) do
    local x,y=spec[1],spec[2]
    local area={id=i,name=spec[4],center={x=x,y=y},left_top={x=x-24,y=y-24},right_bottom={x=x+24,y=y+24}}
    demo.world_areas[i]=area
    local tiles={}
    for tx=x-24,x+23 do for ty=y-24,y+23 do tiles[#tiles+1]={name="refined-concrete",position={tx,ty}} end end
    surface.set_tiles(tiles)
    area.border=rendering.draw_rectangle{surface=surface,left_top=area.left_top,right_bottom=area.right_bottom,
      color={0.5,0.5,0.5},width=2,players={player.index}}
    area.label=rendering.draw_text{visible=false,surface=surface,target={x=x,y=y-22},text=area.name,color={1,1,1},alignment="center",players={player.index}}
    if i==1 then
      for _,item in ipairs(state.items) do item.world_area=1 end
    else
      for j=1,spec[3] do
        local id=state.next_id; state.next_id=id+1
        local names={"Iron Plate Pickup","Copper Plate Pickup","Steel Dropoff"}
        local icons={"iron-plate","copper-plate","steel-plate"}
        local variant=(j-1)%3+1
        local px=x-17+((j-1)%5)*8; local py=y-10+math.floor((j-1)/5)*18
        local item={id=id,name=names[variant].." "..j,icon="item/"..icons[variant],world_area=i,position={x=px,y=py}}
        state.items[#state.items+1]=item
        local group={name=item.name,icon=item.icon,entities={}}
        demo.groups[id]=group
        for _,part in ipairs({{"assembling-machine-2",0,0},{"inserter",2,0},{"steel-chest",3,0},{"transport-belt",0,3},{"transport-belt",1,3}}) do
          local entity=surface.create_entity{name=part[1],position={px+part[2],py+part[3]},force=player.force}
          if entity then group.entities[#group.entities+1]=entity end
        end
      end
    end
  end
  assign_names(demo)
  ensure_land(demo)
  surface.always_day=true; surface.daytime=0
  player.force.chart(surface,{{-48,-48},{160,96}})
end
function M.at(demo,position)
  for _,area in ipairs(demo and demo.world_areas or {}) do
    if position.x>=area.left_top.x and position.x<area.right_bottom.x and position.y>=area.left_top.y and position.y<area.right_bottom.y then return area end
  end
end
function M.select(player,state)
  M.ensure(player,state)
  local demo=state.world_demo
  if not demo or player.surface~=demo.surface then return false end
  local area=M.at(demo,player.position)
  if state.world_camera_mode and state.camera_area==area then return false end
  if state.instance_border and state.instance_border.valid then state.instance_border.destroy() end
  state.camera_instance=nil; state.camera_area=area; state.world_camera_mode=true
  for _,cell in ipairs(demo.world_areas) do
    cell.border.color=cell==area and {0.2,0.9,1} or {0.5,0.5,0.5}
    cell.border.width=cell==area and 3 or 2
  end
  state.override_selected=nil; state.editing_id=nil; state.reviewing_parent=nil; state.drag=nil
  return true
end
function M.items(state)
  local items={}
  for _,item in ipairs(state.items) do
    if state.camera_area and item.world_area==state.camera_area.id then items[#items+1]=item end
  end
  return items
end
return M
