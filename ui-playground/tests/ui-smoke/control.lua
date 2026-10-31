local world_areas=require("__fabric-ui-playground__/world_areas")
local metadata=require("__fabric-ui-playground__/metadata")
local placement=require("__fabric-ui-playground__/placement")
local navigation=require("__fabric-ui-playground__/navigation")
local library=require("__fabric-ui-playground__/library")
local workspaces=require("__fabric-ui-playground__/workspaces")
local ui=require("__fabric-ui-playground__/ui")
local world=require("__fabric-ui-playground__/world")
local overrides=require("__fabric-ui-playground__/overrides")
local validation_surface
script.on_event(defines.events.on_tick,function()
  if validation_surface then
    assert(game.get_player(1).force.is_chunk_charted(validation_surface,{x=0,y=0}))
    script.finish_test(true)
    return
  end
  local p=game.get_player(1)
  if not p then return end
  local s={items={{id=101,name="Iron Plate Pickup"},{id=102,name="Steel Dropoff"}}}
  ui.build(p,s)
  local footer=p.gui.screen[ui.root.."_footer"]
  assert(footer and footer.add_template)
  assert(footer.parent==p.gui.screen and footer.add_template.parent~=p.gui.screen[ui.root])
  local original_root=p.gui.screen[ui.root]
  local original_row=p.gui.screen[ui.root.."_row_101"]
  local original_index=original_row.index
  s.items[#s.items+1]={id=103,name="New Template"}
  ui.refresh_rows(p,s)
  assert(original_root.valid and original_row.valid and footer.valid)
  assert(p.gui.screen[ui.root.."_row_101"].index==original_index)
  assert(p.gui.screen[ui.root.."_row_103"])
  table.remove(s.items,3)
  ui.refresh_rows(p,s)
  assert(original_row.valid and not p.gui.screen[ui.root.."_row_103"])
  ui.show_tuning(p,s)
  local panel=p.gui.screen[ui.root.."_tuning"]
  assert(panel and panel.valid)
  assert(#panel.highlight_style_picker.items==6)
  local count=0
  for _,line in pairs(panel.children) do
    if line.type=="flow" then
      for _,button in pairs(line.children) do
        if button.tags.action=="tune" then
          ui.adjust(p,s,button)
          assert(line.tuning_value.caption==tostring(s.tuning[button.tags.key]))
          count=count+1
        end
      end
    end
  end
  assert(count==10)
  ui.show_tuning(p,s)
  assert(not p.gui.screen[ui.root.."_tuning"])
  ui.build(p,s)
  local previous_surface=p.surface
  world.open(p,s)
  assert(p.surface==s.world_demo.surface)
  assert(#s.world_demo.groups[101].entities>=18)
  assert(p.gui.screen[ui.root.."_row_101"].contents.item_name.raise_hover_events)
  world.set_style(p,s,1)
  world.highlight(p,s,101)
  assert(world.focus(p,s,101))
  assert(p.surface==s.world_demo.surface)
  local n=#s.world_demo.groups[101].entities
  assert(#s.highlight_objects==n)
  local expected={n,n,2*n,2,n,n}
  for mode=1,6 do
    world.set_style(p,s,mode)
    assert(#s.highlight_objects==expected[mode],"Wrong object count for highlight mode "..mode)
    world.tick(s,30)
  end
  local saved=s.items[1]
  table.remove(s.items,1)
  assert(world.restore_rows(s)==1)
  assert(s.items[#s.items].id==saved.id and s.items[#s.items].name==saved.name)
  assert(world.restore_rows(s)==0)
  world.set_style(p,s,1)
  local outline=s.highlight_objects[1]
  world.highlight(p,s,102)
  assert(not outline.valid and #s.highlight_objects==#s.world_demo.groups[102].entities)
  s.world_demo.groups[102].entities[1].destroy()
  world.clear(s)
  world.highlight(p,s,102)
  assert(#s.highlight_objects==#s.world_demo.groups[102].entities-1)
  world.open(p,s)
  assert(p.surface==previous_surface and not s.highlight_id)
  world.open(p,s)
  assert(#s.world_demo.groups[101].entities>=18)
  world.clear(s)
  log("WORLD_HOVER_PASS: fixture, outlines, switching, deleted entity, return and reuse")
  local item=s.items[1]
  local other=s.items[2]
  local clean={id=1001,name="Clean demo"}
  assert(overrides.count(clean)==0)
  local changed={id=1002,name="Changed demo"}
  assert(overrides.count(changed)==3)
  overrides.seed(item); overrides.seed(other)
  assert(overrides.count(item)==3 and overrides.count(other)==3)
  overrides.show(p,s,item.id)
  local detail=p.gui.screen[overrides.panel_name]
  assert(detail and detail.valid)
  for _,change in ipairs(item.overrides) do
    assert(overrides.preview(p,s,item.id,change.id,true))
    assert(#s.highlight_objects>=3)
    local object=s.highlight_objects[1]
    local ghost=s.preview_ghosts[1]
    assert(ghost.valid)
    world.clear(s)
    assert(not object.valid and not ghost.valid)
  end
  local kept=p.gui.screen[ui.root.."_row_"..item.id]
  overrides.act(s,item.id,1,"override_apply")
  ui.refresh_rows(p,s)
  overrides.show(p,s,item.id)
  assert(overrides.count(item)==2 and kept.valid and detail.valid)
  assert(string.find(kept.contents.item_name.caption,"•",1,true))
  overrides.act(s,item.id,2,"override_reset")
  assert(overrides.count(item)==1)
  overrides.act(s,item.id,nil,"override_reset")
  assert(overrides.count(item)==0 and overrides.count(other)==3)
  overrides.act(s,item.id,nil,"override_seed")
  assert(overrides.count(item)==3)
  overrides.act(s,item.id,nil,"override_apply")
  overrides.show(p,s,item.id)
  assert(overrides.count(item)==0)
  log("OVERRIDES_PASS: panel, individual apply/reset, bulk actions, fixture reset, isolated state, retained rows")
  overrides.seed(item)
  overrides.edit(p,s,item.id,nil,"edit_start")
  assert(s.editing_id==item.id and #item.edit_draft.overrides==4)
  for _,change in ipairs(item.edit_draft.overrides) do
    assert(overrides.preview(p,s,item.id,change.id,true))
    world.clear(s)
  end
  overrides.edit(p,s,item.id,1,"edit_reset")
  assert(#item.edit_draft.overrides==3 and overrides.count(item)==3)
  local retained_draft=item.edit_draft
  overrides.edit(p,s,item.id,nil,"edit_exit")
  assert(not p.gui.screen[overrides.panel_name])
  assert(not s.override_selected and not s.editing_id and not s.reviewing_parent)
  assert(item.edit_draft==retained_draft)
  assert(not s.editing_id and #item.edit_draft.overrides==3)
  overrides.edit(p,s,item.id,nil,"edit_start")
  overrides.edit(p,s,item.id,nil,"edit_commit")
  assert(item.edit_version==2 and #item.edit_draft.overrides==0)
  assert(overrides.count(item)==3)
  overrides.edit(p,s,item.id,nil,"edit_seed")
  overrides.edit(p,s,item.id,nil,"edit_discard")
  assert(#item.edit_draft.overrides==0 and item.edit_version==2)
  local retained_draft=item.edit_draft
  overrides.edit(p,s,item.id,nil,"edit_exit")
  assert(not p.gui.screen[overrides.panel_name])
  assert(not s.override_selected and not s.editing_id and not s.reviewing_parent)
  assert(item.edit_draft==retained_draft)
  log("EDIT_PASS: separate draft, preview, undo, exit/resume, commit version, discard")
  workspaces.init(s)
  local original_items=s.items
  p.teleport({64,64},s.world_demo.surface)
  assert(workspaces.select_camera(p,s))
  assert(s.camera_area.generated_name and s.items==original_items)
  assert(p.surface.get_tile(64,64).name=="refined-concrete")
  assert(p.surface.get_tile(32,32).name~="out-of-map")
  assert(not workspaces.select_camera(p,s))
  metadata.show(p,s)
  p.gui.screen[metadata.name].template_name.text="My Voyager"
  assert(metadata.save(p,s))
  assert(s.camera_area.name=="My Voyager" and s.camera_area.label.text=="My Voyager")
  world_areas.ensure(p,s)
  assert(s.camera_area.name=="My Voyager")
  ui.build(p,s)
  local visible_rows=0
  for _,element in ipairs(p.gui.screen.children) do
    if element.tags.fabric_ui_row then visible_rows=visible_rows+1 end
  end
  assert(visible_rows==10)
  local reference=world_areas.items(s)[1]
  assert(world.preview_change(p,s,reference.id,{id=1,category="Moved"},false))
  local fixture=s.world_demo.override_examples["world-"..reference.id]
  assert(fixture.moved==s.world_demo.groups[reference.id].entities[1])
  assert(fixture.moved.position.x>30)
  assert(#s.highlight_objects>0)
  world.clear(s)
  p.teleport({64,0},s.world_demo.surface)
  assert(workspaces.select_camera(p,s))
  assert(#world_areas.items(s)==1)
  p.teleport({32,32},s.world_demo.surface)
  assert(workspaces.select_camera(p,s) and not s.camera_area)
  assert(s.items==original_items)
  ui.build(p,s)
  for _,element in ipairs(p.gui.screen.children) do assert(not element.tags.fabric_ui_row) end
  log("WORLD_CAMERA_PASS: blocks with 10 and 1 instances, stable focus, empty gaps")
  local world_surface=s.world_demo.surface
  workspaces.switch(p,s,"collection")
  assert(s.parent_template)
  assert(p.surface.get_tile(0,0).name=="out-of-map")
  assert(p.surface.get_tile(p.position).name~="out-of-map")
  local first=s.parent_template
  assert(not workspaces.select_camera(p,s))
  p.teleport({0,0},p.surface)
  assert(workspaces.select_camera(p,s) and not s.parent_template)
  assert(workspaces.focus_template(p,s,first.id))
  assert(s.parent_template==first)
  ui.build(p,s)
  assert(p.gui.screen[ui.root.."_review"].review_changes)
  library.show(p,s)
  assert(#workspaces.catalog(p,s)==50)
  assert(p.gui.screen[library.name].valid)
  library.close(p)
  s.reviewing_parent=true
  overrides.edit(p,s,first.id,nil,"edit_start")
  ui.select_tuning(p,s,2)
  local adjust_count=0
  for _,line in ipairs(p.gui.screen[ui.root.."_tuning"].children) do
    for _,button in ipairs(line.children) do
      if button.tags.action=="tune" then ui.adjust(p,s,button); adjust_count=adjust_count+1 end
    end
  end
  assert(adjust_count==22)
  ui.show_tuning(p,s)
  metadata.show(p,s,true)
  local form=p.gui.screen[metadata.name]
  form.template_name.text="New sewn test"
  form.template_icon.elem_value={type="item",name="copper-plate"}
  metadata.new_category(p)
  p.gui.screen[metadata.category_name].category_name.text="Sewn samples"
  assert(metadata.create_category(p,s))
  local saved,created=metadata.save(p,s)
  assert(saved and created and s.parent_template.category=="Sewn samples")
  assert(s.parent_template.icon=="item/copper-plate")
  metadata.show(p,s)
  p.gui.screen[metadata.name].template_name.text="Renamed test"
  p.gui.screen[metadata.name].template_icon.elem_value={type="fluid",name="water"}
  assert(metadata.save(p,s) and s.parent_template.name=="Renamed test")
  assert(s.parent_template.icon=="fluid/water")
  ui.build(p,s)
  placement.show(p,s)
  assert(placement.confirm(p,s))
  placement.show(p,s)
  local popup=p.gui.screen[placement.name]
  popup.position_picker.selected_index=4
  placement.refresh(p,s)
  assert(not placement.confirm(p,s))
  assert(p.cursor_stack.valid_for_read and p.cursor_stack.name=="blueprint" and p.cursor_stack.is_blueprint_setup())
  assert(placement.finish(p,s,p.position))
  p.clear_cursor()
  navigation.close(p,s)
  ui.build(p,s)
  assert(not p.gui.screen.fabric_ui_controls)
  navigation.toggle(p,s)
  ui.select_tuning(p,s,3)
  adjust_count=0
  for _,line in ipairs(p.gui.screen[ui.root.."_tuning"].children) do
    for _,button in ipairs(line.children) do
      if button.tags.action=="tune" then ui.adjust(p,s,button); adjust_count=adjust_count+1 end
    end
  end
  assert(adjust_count==10)
  ui.close(p)
  assert(p.gui.screen.fabric_ui_controls)
  log("FABRIC_UI_SMOKE_PASS: world squares, camera, collection, metadata/create/category, blueprint cursor, live tuning")
  validation_surface=world_surface
end)
