local components=require("__fabric-ui-playground__/components")
-- Whole-snapshot review for the functional prototype.
local R=require("__fabric-ui-playground__/runtime")
local world=require("__fabric-ui-playground__/world")
local M={panel_name="fabric_ui_overrides"}
M.tuning_fields={
  {key="row_offset",label="Whole row ↑ / ↓",default=-10,min=-12,max=12},
  {key="icon_offset",label="Icons ↑ / ↓",default=6,min=-12,max=12},
  {key="text_offset",label="Text ↑ / ↓",default=7,min=-12,max=12},
  {key="control_offset",label="Actions ↑ / ↓",default=6,min=-12,max=12},
  {key="icon_size",label="Icon size",default=24,min=16,max=64},
  {key="gap",label="Column gap",default=6,min=0,max=32},
  {key="category_width",label="Category width",default=74,min=60,max=100},
  {key="before_arrow",label="Icon → gap",default=8,min=0,max=32},
  {key="after_arrow",label="→ Icon gap",default=8,min=0,max=32},
  {key="reset_inset",label="Reset button inset",default=1,min=0,max=40},
  {key="row_height",label="Row height",default=36,min=32,max=80},
}
function M.tuning(state)
  state.change_tuning=state.change_tuning or {}
  if not state.change_tuning_v2 then
    state.change_tuning={row_offset=-10,icon_offset=6,text_offset=7,control_offset=6,
      icon_size=24,gap=6,category_width=74,row_height=36,before_arrow=8,after_arrow=8}
    state.change_tuning_v2=true
  end
  for _,field in ipairs(M.tuning_fields) do
    if state.change_tuning[field.key]==nil then state.change_tuning[field.key]=field.default end
  end
  return state.change_tuning
end
function M.apply_tuning(player,state) end
function M.count(item) return 0 end
function M.pending_count(template) return R.dirty(template) and 1 or 0 end
function M.close(player,state)
  local panel=player.gui.screen[M.panel_name];if panel then panel.destroy() end
  state.override_selected=nil;state.editing_id=nil;state.reviewing_parent=nil
  components.sample_action(player,nil);world.clear(state)
end
function M.show(player,state,id)
  local editing=state.reviewing_parent and state.parent_template and state.parent_template.id==id
  local source
  if editing then source=state.parent_template else
    for _,ref in ipairs(state.items) do if ref.id==id then source=ref;break end end
  end
  if not source then return end
  if editing then R.check_dirty(source) end
  state.override_selected=id
  local panel=player.gui.screen[M.panel_name]
  if not panel then
    panel=player.gui.screen.add{type='frame',name=M.panel_name,direction='vertical'}
    panel.style.width=420
    local root=player.gui.screen.fabric_ui_playground
    local scale=player.display_scale
    local origin=root and root.location or {x=0,y=50}
    local edge=player.display_resolution.width-452*scale
    local x=(origin.x+420*scale+edge)/2
    panel.location={x=math.max(0,math.min(x,player.display_resolution.width-420*scale)),y=math.max(0,origin.y)}
  end
  panel.clear()
  components.titlebar(panel,{title=editing and 'Template Changes' or 'Reference',close_tags={action=editing and 'edit_exit' or 'overrides_close',id=id}})
  local subject=panel.add{type='flow',direction='horizontal',name='patch_subject'};subject.style.vertical_align='center'
  subject.add{type='label',caption=source.name,style='bold_label'}.style.maximal_width=340
  if not editing and source.template_id then
    subject.add{type='sprite-button',name='go_to_template',sprite='utility/export_slot',style='mini_button_aligned_to_text_vertically_when_centered',
      tags={action='patch_template',id=id},tooltip='Edit source template in collection'}
  end
  local list=panel.add{type='scroll-pane',name='change_list',horizontal_scroll_policy='never',vertical_scroll_policy='always'}
  list.style.width=388;list.style.height=editing and 150 or 100
  local message
  if editing then
    local captured=R.capture(source)
    message='Version '..source.version..' → '..(source.version+1)..'\n'..
      (#(source.snapshot.entities or {}))..' → '..(#(captured.entities or {}))..' own entities\n'..
      #source.committed_refs..' → '..#source.children..' references\n\n'..
      (R.dirty(source) and 'Replace snapshot and immediately rebuild all usages.' or 'No pending changes.')
  elseif source.neighbor then message='Neighbor contribution. Its contents are clipped to this instance. Reorder this row to change application precedence.'
  else message='Uses the committed template snapshot. Edit its source template to make changes. World patches are not retained in this prototype.' end
  local label=list.add{type='label',caption=message};label.style.single_line=false;label.style.maximal_width=352
  if editing then
    components.action_stack(panel,id,{{caption='Stitch into Template',icon='stitch',action='edit_commit'},
      {caption='Discard Changes',icon='reset',action='edit_discard'}},R.dirty(source))
  elseif state.workspace=='world' then
    components.action_stack(panel,id,{{caption='Rebuild instance',icon='reset',action='rebuild_instance'}},true)
  end
  local note=panel.add{type='label',caption='Rebuilding World discards manual edits in its cells.'}
  note.style.single_line=false;note.style.maximal_width=388
  panel.bring_to_front()
end
function M.edit(player,state,id,change,action)
  local t=state.parent_template
  if not t or t.id~=id then return end
  if action=='edit_exit' then M.close(player,state);return end
  if action=='edit_commit' then R.commit(player,t)
  elseif action=='edit_discard' then R.discard(player,t) end
  state.reviewing_parent=true;state.editing_id=id
  M.show(player,state,id)
end
function M.preview() end
return M
