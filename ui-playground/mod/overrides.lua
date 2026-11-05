local components=require("__fabric-ui-playground__/components")
-- UI fixtures only. Actions resolve sample entries; no world/template writes.
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
function M.apply_tuning(player,state)
  local panel=player.gui.screen[M.panel_name]
  if not panel or not panel.change_list then return end
  local t=M.tuning(state)
  local function offset(element,n)
    element.style.top_margin=n; element.style.bottom_margin=-n
  end
  for _,row in ipairs(panel.change_list.children) do
    row.style.height=t.row_height
    row.style.right_padding=t.reset_inset
    local content=row.contents
    offset(content,t.row_offset)
    content.style.horizontal_spacing=t.gap
    for _,child in ipairs(content.children) do
      if child.type=="label" then
        offset(child,t.text_offset)
        if child.name=="category" then child.style.width=t.category_width end
      elseif child.name=="glyphs" then
        for _,glyph in ipairs(child.children) do
          if glyph.type=="flow" then
            offset(glyph,t.icon_offset)
            glyph.style.width=t.icon_size
            glyph.children[1].style.size=t.icon_size
          elseif glyph.type=="label" then
            offset(glyph,t.text_offset)
            glyph.style.left_margin=t.before_arrow
            glyph.style.right_margin=t.after_arrow
          end
        end
      elseif child.type=="sprite-button" then offset(child,t.control_offset) end
    end
  end
  panel.change_list.style.height=math.min(240,math.max(1,#panel.change_list.children*(t.row_height+4)))
end
local categories={"Moved","Replaced","Deleted"}
function M.seed(item)
  item.override_fixture_v2=true
  item.overrides={
    {id=1,category="Moved",title="Electric furnace",detail="Moved 2 tiles east",icon="electric-furnace"},
    {id=2,category="Replaced",title="Transport belt → Fast transport belt",detail="Yellow belt replaced with red belt",icon="fast-transport-belt"},
    {id=3,category="Deleted",title="Inserter",detail="Removed from this instance",icon="inserter"},
  }
  item.override_message=nil
end
local function seed_draft(source)
  local draft={id=source.id,name=source.name,fixture_version=2}
  M.seed(draft)
  if source.id==1 then
    draft.overrides={{id=1,category="Moved",title="Electric furnace",detail="Moved 2 tiles east",icon="electric-furnace"}}
  elseif source.id==2 then
    draft.overrides={}
  else
    local added=source.id==3 and 10 or source.id==4 and 15 or 1
    for i=1,added do
      draft.overrides[#draft.overrides+1]={id=3+i,category="Added",title="Steel chest "..i,
        detail="Added to this template",icon="steel-chest",caption="Chest "..i}
    end
  end
  return draft
end
function M.pending_count(template)
  local draft=template.edit_draft
  if not draft or (not draft.fixture_version and not draft.override_message and #draft.overrides==4) then
    template.edit_draft=seed_draft(template)
  end
  return #template.edit_draft.overrides
end
function M.count(item)
  if not item.override_fixture_v2 then
    -- Mix clean and changed demo rows; preserve any actions already tried.
    if not item.override_message and item.id%3~=0 then item.overrides={}
    elseif not item.overrides then M.seed(item) end
    item.override_fixture_v2=true
  end
  item.overrides=item.overrides or {}
  return #item.overrides
end
local function find(state,id)
  if state.reviewing_parent and state.parent_template and state.parent_template.id==id then return state.parent_template end
  for _,item in ipairs(state.items) do if item.id==id then return item end end
end
function M.close(player,state)
  components.sample_action(player,nil)
  local panel=player.gui.screen[M.panel_name]
  if panel then panel.destroy() end
  world.clear(state)
  state.override_selected=nil
end
local function button(parent,caption,action,item,change)
  local b=parent.add{type="button",caption=caption,tags={action=action,id=item.id,change=change}}
  b.style.height=28
  b.style.padding=4
  return b
end
function M.show(player,state,id)
  local item=find(state,id)
  if not item then M.close(player,state); return end
  M.count(item)
  local source=item
  local editing=state.editing_id==id
  if editing then
    if source.edit_draft and not source.edit_draft.fixture_version
      and not source.edit_draft.override_message and #source.edit_draft.overrides==4 then
      source.edit_draft=seed_draft(source)
    end
    item=source.edit_draft
  end
  for _,change in ipairs(item.overrides) do
    if change.category=="Moved" then
      change.icon=({"electric-furnace","assembling-machine-2","steel-chest"})[id%3+1]
      change.title=change.icon
    end
  end
  state.override_selected=id
  local panel=player.gui.screen[M.panel_name]
  if not panel then
    panel=player.gui.screen.add{type="frame",name=M.panel_name,direction="vertical"}
    panel.style.width=420
    local root=player.gui.screen.fabric_ui_playground
    local scale=player.display_scale
    -- Leave half the available gap between the editor and the right-side position.
    local right_edge=player.display_resolution.width-(420+32)*scale
    local x=(root.location.x+420*scale+right_edge)/2
    if x<root.location.x+432*scale then
      local left=32*scale
      if left+432*scale<=root.location.x then x=left
      else x=math.max(0,player.display_resolution.width-420*scale) end
    end
    panel.location={x=math.max(0,x),y=math.max(0,math.min(root.location.y,player.display_resolution.height-300*scale))}
  end
  panel.clear()
  components.titlebar(panel,{
    title=editing and "Editing template" or "Patches",
    close_tags={action=editing and "edit_exit" or "overrides_close",id=item.id},
    close_tooltip=editing and "Exit editing · keep draft" or "Close",
  })
  local subject=panel.add{type="flow",direction="horizontal",name="patch_subject"}
  subject.style.vertical_align="center"
  local name=subject.add{type="label",caption=item.name,style="bold_label"}
  name.style.single_line=false; name.style.maximal_width=350
  if not editing then
    subject.add{type="sprite-button",name="go_to_template",sprite="utility/export_slot",
      style="mini_button_aligned_to_text_vertically_when_centered",
      tooltip="Go to template in collection",tags={action="patch_template",id=source.id}}
  end
  if editing then
    panel.add{type="label",caption="Version "..(source.edit_version or 1).."  ·  "..#item.overrides.." pending changes",style="caption_label"}
  end
  if #item.overrides==0 then
    panel.add{type="label",caption=editing and "No pending changes" or "No patches · matches the base template"}
  end
  local changes=panel.add{type="scroll-pane",name="change_list",
    horizontal_scroll_policy="never",vertical_scroll_policy="always"}
  changes.style.width=388
  changes.style.height=math.min(240,math.max(1,#item.overrides*40))
  changes.style.padding=0
  for _,change in ipairs(item.overrides) do
    local row=changes.add{type="frame",direction="horizontal",style="train_schedule_station_frame",
      tags={override_change=true,id=item.id,change=change.id},
      tooltip=change.title.."\n"..change.detail.."\nHover to preview · click to locate (sample)"}
    row.style.vertical_align="center"; row.style.width=370; row.style.height=36; row.style.padding=4
    row.style.left_padding=8; row.style.right_padding=8
    local content=row.add{type="flow",name="contents",direction="horizontal"}
    content.style.vertical_align="center"; content.style.horizontal_spacing=8
    content.style.height=28; content.style.margin=0; content.style.padding=0
    local category=content.add{type="label",name="category",caption=change.category,style="bold_label"}
    category.style.width=72; category.style.height=28; category.style.vertical_align="center"
    local glyphs=content.add{type="flow",name="glyphs",direction="horizontal"}
    glyphs.style.height=28; glyphs.style.horizontal_spacing=0; glyphs.style.vertical_align="center"
    local function icon(name)
      local slot=glyphs.add{type="flow",direction="horizontal"}
      slot.style.size=28
      slot.style.vertical_align="center"; slot.style.horizontal_align="center"
      slot.style.margin=0; slot.style.padding=0
      local sprite=slot.add{type="sprite",sprite="item/"..name}
      sprite.style.size=24; sprite.style.margin=0; sprite.style.stretch_image_to_widget_size=true
    end
    local function text(caption)
      local label=glyphs.add{type="label",caption=caption}
      label.style.height=28; label.style.vertical_align="center"
      label.style.margin=0
      return label
    end
    if change.category=="Replaced" then
      icon("transport-belt")
      text("→")
      icon(change.icon)
    else
      icon(change.icon)
    end
    local position=world.change_position(state,item.id,change,true)
    local coordinates=content.add{type="label",name="coordinates",
      caption=string.format("(%g, %g)",position.x,position.y),
      tooltip="Template-relative position · center = (0, 0)"}
    coordinates.style.height=28; coordinates.style.vertical_align="center"
    coordinates.style.font_color={0.75,0.75,0.75}
    local space=content.add{type="empty-widget"}
    space.style.horizontally_stretchable=true
    content.style.horizontally_stretchable=true
    for _,spec in ipairs(editing and {
      {components.icons.reset_white,"edit_reset","Undo this pending change (sample)"},
    } or {
      {components.icons.apply_white,"override_apply","Stitch into Template · apply this patch (sample)"},
      {components.icons.reset_white,"override_reset","Discard this patch · reset to template (sample)"},
    }) do
      local action=content.add{type="sprite-button",style="frame_action_button",sprite=spec[1],tooltip=spec[3],
        tags={action=spec[2],id=item.id,change=change.id}}
      action.style.size=28
    end
    local function hover(element)
      element.raise_hover_events=true
      for _,child in pairs(element.children) do hover(child) end
    end
    hover(row)
  end
  components.action_stack(panel,item.id,editing and {
    {caption="Stitch into Template",action="edit_commit",icon="stitch"},
    {caption="Discard Changes",action="edit_discard",icon="reset"},
  } or {
    {caption="Stitch into Template",action="override_apply",icon="stitch"},
    {caption="Discard Changes",action="override_reset",icon="reset"},
  },#item.overrides>0)
  if item.override_message then
    local notice=panel.add{type="label",caption=item.override_message}
    notice.style.single_line=false; notice.style.maximal_width=388
  end
  components.sample_action(player,{
    caption=editing and "Add sample edits" or "Restore sample changes",
    action=editing and "edit_seed" or "override_seed",id=item.id,
  })
  local location=panel.location
  local estimated_height=math.min(240,#item.overrides*40)+220
  panel.location={x=location.x,y=math.max(0,math.min(location.y,player.display_resolution.height-estimated_height*player.display_scale))}
  M.apply_tuning(player,state)
  panel.bring_to_front()
end
function M.preview(player,state,id,change_id,focus)
  local item=find(state,id)
  if not item then return end
  if state.editing_id==id then item=item.edit_draft end
  for _,change in ipairs(item.overrides or {}) do
    if change.id==change_id then return world.preview_change(player,state,id,change,focus) end
  end
end
function M.edit(player,state,id,change_id,action)
  local item=find(state,id)
  if not item then return end
  world.clear(state)
  if action=="edit_start" or action=="edit_seed" then
    if not item.edit_draft or action=="edit_seed" then
      item.edit_draft=seed_draft(item)
    end
    state.editing_id=id
    if not state.world_demo or player.surface~=state.world_demo.surface then world.open(player,state) end
  elseif action=="edit_exit" then
    state.editing_id=nil -- keep an unfinished draft for reopening
    state.reviewing_parent=nil
    M.close(player,state)
    return
  elseif item.edit_draft then
    local draft=item.edit_draft
    if action=="edit_commit" and #draft.overrides>0 then
      item.edit_version=(item.edit_version or 1)+1
      draft.overrides={}
      draft.override_message="Committed draft · version "..item.edit_version.." (prototype)"
    elseif action=="edit_discard" then
      draft.overrides={}
      draft.override_message="Draft discarded"
    elseif action=="edit_reset" then
      for i=#draft.overrides,1,-1 do
        if draft.overrides[i].id==change_id then table.remove(draft.overrides,i) end
      end
      draft.override_message=nil
    end
  end
  M.show(player,state,id)
end
function M.act(state,id,change_id,action)
  local item=find(state,id)
  if not item then return false end
  M.count(item)
  if action=="override_seed" then M.seed(item); return true end
  local affected=0
  for i=#item.overrides,1,-1 do
    if not change_id or item.overrides[i].id==change_id then table.remove(item.overrides,i); affected=affected+1 end
  end
  item.override_message="Mock: "..affected.." change(s) "..(action=="override_apply" and "applied to the base template." or "reset to the base template.")
  return true
end
return M
