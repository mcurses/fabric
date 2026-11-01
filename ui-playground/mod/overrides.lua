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
local S=require('__fabric-ui-playground__/snapshots')
local D=require('__fabric-ui-playground__/diff')
local G=require('__fabric-ui-playground__/ghosts')
function M.apply_tuning(player,state) end
function M.count(item) return #(item.patches or {}) end
function M.changes(t,force)
  if t.review_cache and not force then return t.review_cache end
  local current=R.capture(t)
  t.draft_dirty=t.area and R.signature(current)~=t.area.baseline or false
  local changes=D.compare(t.snapshot,current)
  local ref_change=#t.children~=#t.committed_refs
  for i,r in ipairs(t.children) do local old=t.committed_refs[i];if not old or old.id~=r.id or old.x~=r.x or old.y~=r.y or old.preview_only~=r.preview_only then ref_change=true end end
  if ref_change then changes[#changes+1]={kind='References',reference=true} end
  t.review_cache=changes
  return changes
end
function M.pending_count(template) return #(template.review_cache or {}) end
function M.close(player,state)
  local panel=player.gui.screen[M.panel_name];if panel then panel.destroy() end
  state.override_selected=nil;state.editing_id=nil;state.reviewing_parent=nil;state.review_changes=nil
  components.sample_action(player,nil);world.clear(state)
end
local function source_for(state,id)
  if id<0 and state.camera_area then return R.neighbor_group(state.camera_area),false end
  if state.reviewing_parent and state.parent_template and state.parent_template.id==id then return state.parent_template,true end
  for _,ref in ipairs(state.items) do if ref.id==id then return ref,false end end
end
function M.show(player,state,id)
  local source,editing=source_for(state,id);if not source then return end
  if editing then M.changes(source,true) elseif state.workspace=='world' then R.scan_patches() end
  state.override_selected=id
  state.review_changes=editing and M.changes(source) or source.patches or {}
  local panel=player.gui.screen[M.panel_name]
  if not panel then
    panel=player.gui.screen.add{type='frame',name=M.panel_name,direction='vertical'};panel.style.width=420
    local root=player.gui.screen.fabric_ui_playground;local scale=player.display_scale
    local origin=root and root.location or {x=0,y=50};local edge=player.display_resolution.width-452*scale
    panel.location={x=math.max(0,math.min((origin.x+420*scale+edge)/2,player.display_resolution.width-420*scale)),y=math.max(0,origin.y)}
  end
  panel.clear()
  components.titlebar(panel,{title=editing and 'Template Changes' or 'Patches',close_tags={action=editing and 'edit_exit' or 'overrides_close',id=id}})
  local subject=panel.add{type='flow',direction='horizontal',name='patch_subject'};subject.style.vertical_align='center'
  subject.add{type='label',caption=source.name,style='bold_label'}.style.maximal_width=340
  if not editing and source.template_id then
    subject.add{type='sprite-button',name='go_to_template',sprite='utility/export_slot',style='mini_button_aligned_to_text_vertically_when_centered',tags={action='patch_template',id=id},tooltip='Edit source template in collection'}
  end
  local list=panel.add{type='scroll-pane',name='change_list',horizontal_scroll_policy='never',vertical_scroll_policy='auto'}
  list.style.width=388;list.style.maximal_height=300
  if #state.review_changes==0 then list.add{type='label',caption='No changes'} end
  for i,c in ipairs(state.review_changes) do
    local row=list.add{type='frame',direction='horizontal',style='train_schedule_station_frame',tags={override_change=true,id=id,change=i}}
    row.style.width=374;row.style.height=40;row.style.padding=4;row.style.vertical_align='center'
    row.add{type='label',caption=c.kind,style='bold_label'}.style.width=78
    local function icon(e)
      if e then row.add{type='sprite',sprite=(c.tile and 'tile/' or 'entity/')..e.name}.style.size=26 end
    end
    icon(c.before)
    if c.before and c.after then row.add{type='label',caption='→'} end
    icon(c.after)
    local e=c.after or c.before
    if e then row.add{type='label',caption='('..e.position.x..', '..e.position.y..')'}.style.font_color={.7,.7,.7} end
    local gap=row.add{type='empty-widget'};gap.style.horizontally_stretchable=true
    if not editing and not source.neighbor then row.add{type='sprite-button',sprite='utility/check_mark',style='tool_button',tags={action='patch_accept',id=id,change=i},tooltip='Stitch this change into the source template'} end
    row.add{type='sprite-button',sprite='utility/reset',style='tool_button',tags={action='change_reset',id=id,change=i},tooltip='Discard this change'}
    local function hover(el) el.raise_hover_events=true;for _,child in ipairs(el.children) do hover(child) end end;hover(row)
  end
  components.action_stack(panel,id,{{caption='Stitch into Template',icon='stitch',action=editing and 'edit_commit' or 'patch_commit'},
    {caption='Discard Changes',icon='reset',action=editing and 'edit_discard' or 'patch_discard'}},#state.review_changes>0 and not source.neighbor)
  panel.bring_to_front()
  M.preview(player,state,id)
end
function M.edit(player,state,id,change,action)
  local source,editing=source_for(state,id);if not source then return end
  if action=='edit_exit' then M.close(player,state);return end
  local changes=state.review_changes or {}
  local selected=change and {changes[change]} or changes
  world.clear(state)
  if editing then
    if action=='edit_commit' then R.commit(player,source)
    elseif action=='edit_discard' then R.discard(player,source)
    elseif action=='change_reset' then
      if selected[1].reference then source.children=S.copy(source.committed_refs)
      else R.render_editor(player,source,D.apply(R.capture(source),selected,true)) end
      R.check_dirty(source)
    end
  elseif state.workspace=='world' then
    R.patch_action(player,state.camera_area,source,selected,action=='patch_commit' or action=='patch_accept')
  end
  if not storage.fabric_job then M.show(player,state,id) end
end
function M.preview(player,state,id,index,focus)
  local source,editing=source_for(state,id)
  if not source then return end
  world.clear(state)
  local center=editing and source.area.center or state.camera_area.center
  local changes=index and {state.review_changes[index]} or state.review_changes or {}
  local snapshot=S.empty();state.highlight_objects={}
  for _,c in ipairs(changes) do if not c.reference then
    local color=c.kind=='Deleted' and {1,.25,.2} or (c.kind=='Added' and {.25,1,.4} or {1,.75,.2})
    for _,e in ipairs({c.after or c.before,c.after and c.before or nil}) do
      local pos={x=center.x+e.position.x,y=center.y+e.position.y}
      local real=not c.tile and S.find(player.surface,e,center)
      local proto=not c.tile and prototypes.entity[e.name]
      local b=real and real.bounding_box
      local sb=proto and proto.selection_box or {left_top={x=-.5,y=-.5},right_bottom={x=.5,y=.5}}
      local lt=b and b.left_top or {x=pos.x+sb.left_top.x,y=pos.y+sb.left_top.y}
      local rb=b and b.right_bottom or {x=pos.x+sb.right_bottom.x,y=pos.y+sb.right_bottom.y}
      state.highlight_objects[#state.highlight_objects+1]=rendering.draw_rectangle{surface=player.surface,left_top=lt,right_bottom=rb,color=color,width=index and 5 or 3,draw_on_ground=false,players={player.index}}
      if not real and not c.tile then snapshot.entities[#snapshot.entities+1]=e end
    end
  end end
  state.preview_ghosts=G.show(player.surface,snapshot,center)
  if focus and changes[1] and not changes[1].reference then local e=changes[1].after or changes[1].before;player.teleport({center.x+e.position.x,center.y+e.position.y}) end
end
return M
