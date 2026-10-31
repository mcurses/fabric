local R=require('__fabric-ui-playground__/runtime')
local components=require('__fabric-ui-playground__/components')
local M={name='fabric_settings'}
function M.close(player) local p=player.gui.screen[M.name];if p then p.destroy() end end
function M.show(player)
  M.close(player)
  local panel=player.gui.screen.add{type='frame',name=M.name,direction='vertical'}
  panel.style.width=420
  components.titlebar(panel,{title='Fabric Settings',close_tags={action='settings_close'}})
  panel.add{type='label',caption='World Origin Template',style='caption_label'}
  local names,ids={},{};local index=1
  for _,t in ipairs(R.catalog()) do if t.is_origin then
    names[#names+1]=t.name;ids[#ids+1]=t.id;if t.id==R.store().world_origin then index=#names end
  end end
  panel.add{type='drop-down',name='origin_picker',items=names,selected_index=index,tags={ids=ids}}.style.width=388
  local size=R.store()
  panel.add{type='label',caption='World cells: '..size.world_width..' × '..size.world_height..' (fixed)'}
  local note=panel.add{type='label',caption='Rebuilding replaces cell contents. Manual World edits are discarded.'}
  note.style.single_line=false;note.style.maximal_width=388
  local button=panel.add{type='button',caption='Apply and rebuild World',tags={action='settings_apply'}}
  button.style.width=388;button.style.height=36
  panel.auto_center=true
end
function M.apply(player)
  local panel=player.gui.screen[M.name]
  R.configure_world(player,panel.origin_picker.tags.ids[panel.origin_picker.selected_index])
  M.close(player)
end
return M
