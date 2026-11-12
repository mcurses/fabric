-- Intended geometry is derived from the observed clipboard and actual pre-build
-- transform. This qualifies a causal receipt; geometry alone never assigns IDs.
local G={}
local function fixed(n)return(n>=0 and math.floor(n*256)or math.ceil(n*256))/256 end
local function rotate(x,y,d)
 if d==0 then return x,y elseif d==4 then return -y,x elseif d==8 then return -x,-y elseif d==12 then return y,-x end
end
local function canonical(v)
 local t=type(v)
 if t~='table'then if t=='userdata'or t=='function'or t=='thread'then error('nonplain blueprint field')end;return helpers.table_to_json({value=v})end
 local keys={};for k in pairs(v)do keys[#keys+1]=k end
 table.sort(keys,function(a,b)return type(a)..':'..tostring(a)<type(b)..':'..tostring(b)end)
 local out={};for _,k in ipairs(keys)do out[#out+1]=type(k)..':'..tostring(k)..'='..canonical(v[k])end
 return '{'..table.concat(out,',')..'}'
end
function G.capture(bp)
 if not bp then return nil,nil end
 local ok,model=pcall(function()return {entities=bp.get_blueprint_entities()or{},tiles=bp.get_blueprint_tiles()or{},grid=bp.blueprint_snap_to_grid,absolute=bp.blueprint_absolute_snapping,relative=bp.blueprint_position_relative_to_grid}end)
 if not ok then return nil,nil end
 local valid,fingerprint=pcall(canonical,model);return model,valid and fingerprint or nil
end
function G.project(model,e)
 local function unsupported(reason)return {supported=false,reason=reason}end
 if not model then return unsupported('clipboard model unavailable')end
 if model.grid then return unsupported('custom blueprint grid pending engine validation')end
 if next(model.tiles or{})then return unsupported('blueprint tile anchor pending engine validation')end
 local d=e.direction or 0;if d~=0 and d~=4 and d~=8 and d~=12 then return unsupported('non-cardinal blueprint transform')end
 local list=model.entities or{};if #list==0 then return unsupported('no entities in clipboard')end
 local minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge;local grid=0;local offgrid=false
 for _,b in pairs(list)do
  local p=prototypes.entity[b.name];if not p or not b.position then return unsupported('unknown entity geometry')end
  local dir=b.direction or 0;if dir%4~=0 then return unsupported('diagonal source footprint pending engine validation')end
  local w,h=p.tile_width,p.tile_height;if dir%8==4 then w,h=h,w end
  if not w or not h or w<=0 or h<=0 then return unsupported('missing tile footprint')end
  if p.has_flag('placeable-off-grid')then
   offgrid=true
   -- Vehicle blueprint bounds use the prototype collision box; stored vehicle
   -- orientation does not rotate this clipboard anchor box in measured 2.1.24.
   local box=p.collision_box
   for _,corner in ipairs{{box.left_top.x,box.left_top.y},{box.left_top.x,box.right_bottom.y},{box.right_bottom.x,box.left_top.y},{box.right_bottom.x,box.right_bottom.y}}do local x,y=rotate(corner[1],corner[2],dir);minx=math.min(minx,b.position.x+x);maxx=math.max(maxx,b.position.x+x);miny=math.min(miny,b.position.y+y);maxy=math.max(maxy,b.position.y+y)end
  else
   local g=p.build_grid_size;if g~=1 and g~=2 then return unsupported('special entity grid pending engine validation')end;grid=math.max(grid,g)
   minx=math.min(minx,b.position.x-w/2);maxx=math.max(maxx,b.position.x+w/2);miny=math.min(miny,b.position.y-h/2);maxy=math.max(maxy,b.position.y+h/2)
  end
 end
 if grid>0 and offgrid then return unsupported('mixed grid/off-grid anchor has measured counterexamples; identity transfer disabled')end
 if grid>0 then
  -- In a gridded blueprint the engine uses source tile origins for the anchor
  -- box, including an off-grid vehicle's containing tile. Preserve the original
  -- fractional entity positions when later applying the resulting translation.
  minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge
  for _,b in pairs(list)do local p=prototypes.entity[b.name];local w,h=p.tile_width,p.tile_height;if (b.direction or 0)%8==4 then w,h=h,w end;local x=math.floor(b.position.x)+(w%2)/2;local y=math.floor(b.position.y)+(h%2)/2;minx=math.min(minx,x-w/2);maxx=math.max(maxx,x+w/2);miny=math.min(miny,y-h/2);maxy=math.max(maxy,y+h/2)end
 end
 local cx,cy=(minx+maxx)/2,(miny+maxy)/2;if grid==0 then cx,cy=fixed(cx),fixed(cy)end
 local align_x,align_y=cx,cy;if grid==2 then align_x,align_y=math.floor(cx+.5),math.floor(cy+.5)end
 if e.flip_horizontal then align_x=-align_x end;if e.flip_vertical then align_y=-align_y end;align_x,align_y=rotate(align_x,align_y,d)
 local phase_x,phase_y=cx,cy;if e.flip_horizontal then phase_x=-phase_x end;if e.flip_vertical then phase_y=-phase_y end;phase_x,phase_y=rotate(phase_x,phase_y,d)
 local px,py=fixed(e.position.x),fixed(e.position.y)
 local ax,ay=px,py
 if grid>0 then ax=math.floor((px-align_x)/grid+.5)*grid+phase_x;ay=math.floor((py-align_y)/grid+.5)*grid+phase_y end
 local out={supported=true,entities={},grid=grid,source_center={x=cx,y=cy},anchor={x=ax,y=ay},entity_count=#list}
 for _,b in pairs(list)do local x,y=b.position.x-cx,b.position.y-cy;if e.flip_horizontal then x=-x end;if e.flip_vertical then y=-y end;x,y=rotate(x,y,d)
  out.entities[tostring(b.entity_number)]={name=b.name,quality=b.quality or'normal',position={x=fixed(ax+x),y=fixed(ay+y)}}
 end
 return out
end
return G
