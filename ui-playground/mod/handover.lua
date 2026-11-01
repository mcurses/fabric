-- Offline preparation only; exposed solely to the disposable test driver.
local R=require('runtime')
local S=require('snapshots')
local M={}
function M.prepare(player)
  assert(script.active_mods['fabric-ui-test-driver'],'Use an isolated preparation profile')
  assert(not storage.fabric_job,'Finish queued work before preparing a starter')
  local db=R.store()
  local holding=game.create_surface('Fabric Handover Holding',{width=32,height=32})
  for _,p in pairs(game.players) do p.set_controller{type=defines.controllers.editor};p.teleport({0,0},holding);p.gui.screen.clear() end
  rendering.clear(script.mod_name)
  for _,t in ipairs(R.catalog()) do
    t.area=nil;t.review_cache=nil;t.draft_dirty=false;t.slot_anchor=nil;t.slot_eligible=false;t.slot_previews=nil
    for _,slot in ipairs(t.slot_definitions or {}) do slot.anchor=nil end
    local refs={}
    for _,ref in ipairs(t.committed_refs or {}) do if not ref.preview_only then
      local copy=S.copy(ref);copy.slot_assignments=nil;copy.patches=nil;refs[#refs+1]=copy
    end end
    t.committed_refs=refs;t.children=S.copy(refs)
  end
  for _,name in ipairs({'Fabric Templates','Fabric World','Fabric Preview Composition'}) do if game.surfaces[name] then local old=game.surfaces[name];old.name='Discarded '..name;game.delete_surface(old) end end
  local function surface(name)
    local sf=game.create_surface(name,{width=0,height=0,peaceful_mode=true,autoplace_settings={entity={treat_missing_as_default=false,settings={}},decorative={treat_missing_as_default=false,settings={}}}})
    sf.always_day=true;return sf
  end
  db.collection_surface=surface('Fabric Templates');db.world_surface=surface('Fabric World')
  db.cells={};db.preview_cache={};db.world_cell_cache_v2=nil;db.world_outer_signature=nil;db.world_outer_regions=nil;db.world_built_regions=nil
  db.test_cleanup_archive=nil;db.catalog_compacted=nil;db.slots_schema=3
  db.test_cleanup_done=true;db.slots_fix_backup=2;db.slots_ui_backup=true;db.responsive_backup=true
  local bounds={left_top={x=0,y=0},right_bottom={x=0,y=0}}
  for _,t in ipairs(R.catalog()) do
    R.ensure_area(player,t)
    local b=t.area.edit_bounds
    bounds.right_bottom.x=math.max(bounds.right_bottom.x,b.right_bottom.x+32)
    bounds.right_bottom.y=math.max(bounds.right_bottom.y,b.right_bottom.y+32)
  end
  player.force.chart(db.collection_surface,bounds);player.force.chart_all(db.collection_surface)
  local cell=R.create_instance(player,{x=0,y=0});cell.name='Starter Grid';cell.icon='item/blueprint'
  R.update_instance_tag(player,cell)
  for _,p in pairs(game.players) do p.teleport(cell.center,db.world_surface) end
  game.delete_surface(holding)
  -- Default planet is unused by this isolated playground; drop its explored chunks.
  local nauvis=game.surfaces.nauvis
  if nauvis then local chunks={};for c in nauvis.get_chunks() do chunks[#chunks+1]={c.x,c.y} end;for _,c in ipairs(chunks) do nauvis.delete_chunk(c) end end
  storage.players={}
  local catalog={}
  for _,t in ipairs(R.catalog()) do
    local stations=0;for _,e in ipairs(t.snapshot.entities or {}) do if prototypes.entity[e.name].type=='train-stop' then stations=stations+1 end end
    catalog[#catalog+1]={id=t.id,name=t.name,category=t.category,entities=#t.snapshot.entities,stations=stations,slots=#(t.slot_definitions or {}),version=t.version}
  end
  helpers.write_file('handover-catalog.json',helpers.table_to_json(catalog),false)
  return catalog
end
return M
