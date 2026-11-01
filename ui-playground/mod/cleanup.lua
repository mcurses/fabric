-- One-time removal requested for the prototype library, with an in-save archive.
local R=require('__fabric-ui-playground__/runtime')
local S=require('__fabric-ui-playground__/snapshots')
local G=require('__fabric-ui-playground__/ghosts')
local M={}
function M.run(player)
  local db=R.store();if db.test_cleanup_done then return end
  local removed={};local archive={templates={},cells=S.copy(db.cells),order=S.copy(db.order),references={}}
  for _,t in ipairs(R.catalog()) do
    local name=t.name:lower():match('^%s*(.-)%s*$')
    if t.id~=db.world_origin and (name:find('test',1,true) or (t.category or ''):lower()=='test' or name=='seppi sep man' or name=='red' or name=='new module 1' or name=='new module 2') then removed[t.id]=true end
  end
  db.test_cleanup_archive=archive
  local function prune(refs)
    local changed=false
    for i=#(refs or {}),1,-1 do
      local ref=refs[i]
      if removed[ref.template_id] then table.remove(refs,i);changed=true else
        for slot,id in pairs(ref.slot_assignments or {}) do if removed[id] then ref.slot_assignments[slot]=nil;changed=true end end
      end
    end
    return changed
  end
  local surviving={}
  for _,t in ipairs(R.catalog()) do
    if removed[t.id] then
      archive.templates[t.id]=t
      if t.area then
        G.clear(t.area.underlay);S.clear(db.collection_surface,t.area.edit_bounds)
        for _,key in ipairs({'border','padding_border'}) do local obj=t.area[key];if obj and obj.valid then obj.destroy() end end
      end
    else
      local own=R.capture(t)
      archive.references[t.id]={children=S.copy(t.children),committed_refs=S.copy(t.committed_refs),origin_id=t.origin_id}
      local changed=prune(t.children);changed=prune(t.committed_refs) or changed
      if removed[t.origin_id] then t.origin_id=nil;changed=true end
      for slot,id in pairs(t.slot_previews or {}) do if removed[id] then t.slot_previews[slot]=nil;changed=true end end
      surviving[#surviving+1]={template=t,own=own,changed=changed}
    end
  end
  local order={};for _,id in ipairs(db.order) do if not removed[id] then order[#order+1]=id else db.templates[id]=nil end end
  db.order=order;db.catalog_compacted=true;db.preview_cache={}
  for _,cell in ipairs(db.cells) do prune(cell.items) end
  for _,entry in ipairs(surviving) do if entry.changed then R.render_editor(player,entry.template,entry.own) end end
  R.rebuild_world(player);db.test_cleanup_done=true
  local names={};for _,t in pairs(archive.templates) do names[#names+1]=t.name end;table.sort(names)
  log('FABRIC_TEMPLATE_CLEANUP: '..table.concat(names,', '))
  player.print('Removed '..#names..' test/placeholder templates. A backup and in-save archive are retained.')
end
return M
