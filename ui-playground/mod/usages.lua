local R=require('__fabric-ui-playground__/runtime')
local S=require('__fabric-ui-playground__/snapshots')
local W=require('__fabric-ui-playground__/workspaces')
local C=require('__fabric-ui-playground__/components')
local M={name='fabric_usages'}
function M.close(player) local panel=player.gui.screen[M.name];if panel then panel.destroy() end end
-- Return each physical placement, preserving the reference chain and transform.
local function paths(id,target,seen)
  seen=seen or {};if seen[id] then return {} end
  if id==target then return {{position={x=0,y=0},via={}}} end
  seen[id]=true
  local result={}
  for _,ref in ipairs(R.template(id).committed_refs) do if not ref.preview_only then
    for _,path in ipairs(paths(ref.template_id,target,seen)) do
      local position=S.point(path.position,ref)
      local via={R.template(id).name};for _,name in ipairs(path.via) do via[#via+1]=name end
      result[#result+1]={position=position,via=via}
    end
  end end
  seen[id]=nil;return result
end
function M.list(target)
  local result={};local db=R.store()
  for _,t in ipairs(R.catalog()) do if t.id~=target then
    for _,path in ipairs(paths(t.id,target)) do
      -- The containing template is already the row title.
      table.remove(path.via,1)
      result[#result+1]={name=t.name,icon=t.icon,template=t.id,position=path.position,via=path.via,kind='Templates'}
    end
  end end
  for _,cell in ipairs(db.cells) do
    for _,ref in ipairs(cell.items) do if not ref.neighbor then
      for _,path in ipairs(paths(ref.template_id,target)) do
        local position=S.point(path.position,ref)
        result[#result+1]={name=cell.name,icon=R.template(ref.template_id).icon,cell=cell.id,position=position,via=path.via,kind='World instances'}
      end
    end end
  end
  return result
end
function M.show(player,state)
  if not state.parent_template then return end
  M.close(player);state.usages=M.list(state.parent_template.id)
  local panel=player.gui.screen.add{type='frame',name=M.name,direction='vertical'};panel.style.width=440
  C.titlebar(panel,{title='Show Usages',close_tags={action='usages_close'}})
  panel.add{type='label',caption=state.parent_template.name,style='bold_label'}
  local list=panel.add{type='scroll-pane',horizontal_scroll_policy='never',vertical_scroll_policy='auto'};list.style.width=408;list.style.maximal_height=420
  local category
  for i,entry in ipairs(state.usages) do
    if category~=entry.kind then category=entry.kind;list.add{type='label',caption=category,style='caption_label'}.style.top_margin=12 end
    local caption='[img='..entry.icon..']  '..entry.name
    if #entry.via>0 then caption=caption..' (Via '..table.concat(entry.via,' → ')..')' end
    local button=list.add{type='button',caption=caption,tags={action='usage_focus',index=i},tooltip=caption..'\nLocate this usage'}
    button.style.width=386;button.style.horizontal_align='left'
  end
  if #state.usages==0 then list.add{type='label',caption='No usages yet'} end
  panel.auto_center=true
end
function M.focus(player,state,index)
  local entry=(state.usages or {})[index];if not entry then return end
  local db=R.store();local center,surface
  if entry.template then local area=R.ensure_area(player,R.template(entry.template));center=area.center;surface=db.collection_surface
  else center=db.cells[entry.cell].center;surface=db.world_surface end
  M.close(player)
  player.teleport({x=center.x+entry.position.x,y=center.y+entry.position.y},surface);player.zoom=.5
  W.select_camera(player,state)
end
return M
