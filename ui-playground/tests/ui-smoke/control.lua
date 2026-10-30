local ui=require("__fabric-ui-playground__/ui")
local world=require("__fabric-ui-playground__/world")
local overrides=require("__fabric-ui-playground__/overrides")
script.on_event(defines.events.on_tick,function()
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
  ui.close(p)
  assert(not detail.valid)
  assert(not footer.valid)
  log("FABRIC_UI_SMOKE_PASS: build, panel, all ten adjustment buttons, close, rebuild")
  script.finish_test(true)
end)
