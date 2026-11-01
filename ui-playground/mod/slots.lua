-- Slot definitions belong to a template; assignments belong to each reference.
-- Anchors are geometry, never a persistent entity-ID scheme.
local S=require('__fabric-ui-playground__/snapshots')
local ghosts=require('__fabric-ui-playground__/ghosts')
local C=require('__fabric-ui-playground__/components')
local M={}
local R,clear_preview
function M.bind_preview(fn) clear_preview=fn end
function M.bind(value) R=value end
local function runtime() return R end
function M.has_slots(t,seen)
  if #(t.slot_definitions or {})>0 then return true end
  seen=seen or {};if seen[t.id] then return false end;seen[t.id]=true
  for _,ref in ipairs(t.committed_refs or {}) do
    if not ref.preview_only and M.has_slots(runtime().template(ref.template_id),seen) then return true end
  end
  return false
end
function M.anchor_exists(t,anchor)
  if not anchor then return false end
  for _,e in ipairs(t.snapshot.entities or {}) do
    if e.name==anchor.name and e.position.x==anchor.position.x and e.position.y==anchor.position.y and (e.direction or 0)==(anchor.direction or 0) then return true end
  end
  return false
end
function M.compatible(host,slot,filler)
  if not slot or not M.anchor_exists(host,slot.anchor) then return false end
  if not filler or not filler.slot_eligible or not M.anchor_exists(filler,filler.slot_anchor) or M.has_slots(filler) then return false end
  local a,b=prototypes.entity[slot.anchor.name],prototypes.entity[filler.slot_anchor.name]
  return a and b and a.type==b.type and ((slot.anchor.direction or 0)-(filler.slot_anchor.direction or 0))%4==0
end
function M.transform(slot,filler)
  local rotation=((slot.anchor.direction or 0)-(filler.slot_anchor.direction or 0))%16
  local point=S.point(filler.slot_anchor.position,{direction=rotation})
  return {direction=rotation,x=slot.anchor.position.x-point.x,y=slot.anchor.position.y-point.y}
end
function M.layers(host,assignments,seen)
  local R=runtime();local out={}
  for i,slot in ipairs(host.slot_definitions or {}) do
    local id=assignments and assignments[i];local filler=id and R.template(id)
    if M.compatible(host,slot,filler) then
      local transform=M.transform(slot,filler)
      for _,layer in ipairs(R.layers(id,seen)) do out[#out+1]={snapshot=S.transform(layer.snapshot,transform),slot=i} end
    end
  end
  return out
end
function M.choices(host,slot)
  local result={}
  for _,t in ipairs(runtime().catalog()) do if M.compatible(host,slot,t) then result[#result+1]=t end end
  table.sort(result,function(a,b)return a.name:lower()<b.name:lower() end)
  return result
end
function M.can_configure(t,count,eligible)
  if not count or count%1~=0 or count<0 or count>32 then return false,'Choose between 0 and 32 slots.' end
  if count>0 and eligible then return false,'A template with slots cannot itself fill a slot.' end
  if t and (count>0 or not eligible) then
    local function used(refs)
      for _,ref in ipairs(refs or {}) do for _,id in pairs(ref.slot_assignments or {}) do if id==t.id then return true end end end
    end
    local reason='Remove this template from its slots before disabling slot eligibility or adding slots.'
    for _,host in ipairs(runtime().catalog()) do if used(host.children) or used(host.committed_refs) then return false,reason end end
    for _,cell in ipairs(runtime().store().cells) do if used(cell.items) then return false,reason end end
  end
  return true
end
function M.configure(t,count,eligible)
  local ok,reason=M.can_configure(t,count,eligible);assert(ok,reason)
  t.slot_definitions=t.slot_definitions or {}
  for i=#t.slot_definitions,count+1,-1 do table.remove(t.slot_definitions,i) end
  for i=#t.slot_definitions+1,count do t.slot_definitions[i]={name='Slot '..i} end
  t.slot_eligible=eligible or false
  local function prune(refs)
    for _,ref in ipairs(refs or {}) do if ref.template_id==t.id then
      for i in pairs(ref.slot_assignments or {}) do if i>count then ref.slot_assignments[i]=nil end end
    end end
  end
  for _,host in ipairs(runtime().catalog()) do prune(host.children);prune(host.committed_refs) end
  for _,cell in ipairs(runtime().store().cells) do prune(cell.items) end
end
function M.remove(t,index)
  assert(t.slot_definitions[index],'Missing slot')
  table.remove(t.slot_definitions,index)
  for i,slot in ipairs(t.slot_definitions) do slot.name='Slot '..i end
  local function shift(refs)
    for _,ref in ipairs(refs or {}) do if ref.template_id==t.id and ref.slot_assignments then
      local next_assignments={}
      for i,id in pairs(ref.slot_assignments) do if i~=index then next_assignments[i>index and i-1 or i]=id end end
      ref.slot_assignments=next_assignments
    end end
  end
  for _,host in ipairs(runtime().catalog()) do shift(host.children);shift(host.committed_refs) end
  for _,cell in ipairs(runtime().store().cells) do shift(cell.items) end
end
function M.seed()
  local R=runtime();local db=R.store();if db.slots_schema==2 then return end
  for _,t in ipairs(R.catalog()) do
    t.slot_definitions=t.slot_definitions or {}
    if not db.slots_schema and t.source_label=='Bay spine' then M.configure(t,3,false) end
    -- Imported station templates already have an unambiguous physical anchor.
    local station=t.source_label=='HT solid request' or t.source_label=='HT solid provider'
    if not station then t.slot_eligible=false end
    if station and #(t.slot_definitions or {})==0 then
      local stops={}
      for _,e in ipairs(t.snapshot.entities or {}) do local proto=prototypes.entity[e.name];if proto and proto.type=='train-stop' then stops[#stops+1]=e end end
      if #stops==1 then t.slot_eligible=true;t.slot_anchor={name=stops[1].name,position=S.copy(stops[1].position),direction=stops[1].direction or 0} end
    end
  end
  for _,t in ipairs(R.catalog()) do
    if t.source_label=='HT solid request' then t.name='Bayspine Requester';t.icon='item/requester-chest'
    elseif t.source_label=='HT solid provider' then t.name='Bayspine Provider';t.icon='item/passive-provider-chest' end
  end
  db.slots_schema=2
end
function M.picker(player,state,id,index)
  local old=player.gui.screen.fabric_slot_picker;if old then old.destroy() end
  local ref;for _,r in ipairs(state.items) do if r.id==id then ref=r end end
  if not ref then return end
  local host=runtime().template(ref.template_id)
  local panel=player.gui.screen.add{type='frame',name='fabric_slot_picker',direction='vertical'}
  C.titlebar(panel,{title='Slot '..index,close_tags={action='slot_picker_close'}})
  panel.add{type='label',caption='Hover for preview'}
  local function option(t)
    panel.add{type='button',caption=t and ('[img='..t.icon..'] '..t.name) or 'Empty',raise_hover_events=true,
      tags={action='slot_assign',id=id,slot=index,value=t and t.id or 0,preview_slot=t and t.id or nil}}.style.width=310
  end
  option();for _,t in ipairs(M.choices(host,host.slot_definitions[index])) do option(t) end
  panel.auto_center=true
end
function M.preview(player,state,tags)
  clear_preview(state)
  local R=runtime();local db=R.store()
  if tags.preview_create then
    local w,h=db.world_width,db.world_height
    local center={x=math.floor((player.position.x+w/2)/w)*w,y=math.floor((player.position.y+h/2)/h)*h}
    state.preview_ghosts=ghosts.show(player.surface,R.flatten(db.world_origin),center);return
  end
  local ref;for _,r in ipairs(state.items) do if r.id==tags.id then ref=r end end
  if not ref then return end
  local host=R.template(ref.template_id);local filler=R.template(tags.preview_slot)
  local transform=M.transform(host.slot_definitions[tags.slot],filler)
  local snapshot=S.transform(S.transform(R.flatten(filler.id),transform),ref)
  local target=state.parent_template and state.parent_template.area or state.camera_area
  if target then state.preview_ghosts=ghosts.show(player.surface,snapshot,target.center) end
end
function M.pick(player,state,slot)
  local t=state.parent_template;if not t then return end
  state.anchor_pick={template_id=t.id,slot=slot}
  local panel=player.gui.screen.fabric_ui_metadata;if panel then panel.visible=false end
  local old=player.gui.screen.fabric_anchor_prompt;if old then old.destroy() end
  local prompt=player.gui.screen.add{type='frame',name='fabric_anchor_prompt',direction='vertical'}
  C.titlebar(prompt,{title=slot>0 and ('Slot '..slot..' anchor') or 'Template anchor',close_tags={action='anchor_cancel'}})
  prompt.add{type='label',caption='Click an owned entity in this template.'}
  prompt.add{type='button',caption='Cancel',tags={action='anchor_cancel'}}
  prompt.location={x=math.max(0,player.display_resolution.width-380*player.display_scale),y=80*player.display_scale}
end
function M.select(player,state,entity)
  local pick=state.anchor_pick;if not pick then return false end
  local t=runtime().template(pick.template_id)
  if not entity or not entity.valid or entity.type=='entity-ghost' or entity.surface~=runtime().store().collection_surface or not S.inside(entity.position,t.area.edit_bounds) then
    player.print('Choose a real entity inside this template.');return false
  end
  if t.area.excluded[S.entity_key(entity)] then player.print('Choose an entity owned by this template, not a reference.');return false end
  local anchor={name=entity.name,position={x=entity.position.x-t.area.center.x,y=entity.position.y-t.area.center.y},direction=entity.direction}
  if pick.slot==0 then t.slot_anchor=anchor else t.slot_definitions[pick.slot].anchor=anchor end
  state.anchor_pick=nil;player.opened=nil
  local prompt=player.gui.screen.fabric_anchor_prompt;if prompt then prompt.destroy() end
  local panel=player.gui.screen.fabric_ui_metadata;if panel then panel.visible=true;panel.bring_to_front() end
  return t.id
end
function M.cancel(player,state)
  state.anchor_pick=nil
  local prompt=player.gui.screen.fabric_anchor_prompt;if prompt then prompt.destroy() end
  local panel=player.gui.screen.fabric_ui_metadata;if panel then panel.visible=true;panel.bring_to_front() end
end
return M
