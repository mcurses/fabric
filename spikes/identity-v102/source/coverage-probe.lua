-- Diagnostic wrapper around real engine callbacks, preserving production handlers.
local P={}
local function plain(v,depth,trust_plain_tags)
 depth=depth or 0;if depth>10 then return '<depth>'end
 local t=type(v)
 if t=='userdata'or(not trust_plain_tags and t=='table'and v.object_name)then
  local ok,r=pcall(function()
   if v.object_name=='LuaEntity'and v.valid then return {object='LuaEntity',unit=v.unit_number,name=v.name,ghost=v.type=='entity-ghost'and v.ghost_name or nil,position={x=v.position.x,y=v.position.y},surface=v.surface.index,direction=v.direction,force=v.force.name}end
   if v.object_name=='LuaInventory'and v.valid then
    local slots={};for i=1,#v do local item=v[i];if item.valid_for_read then
     local row={slot=i,name=item.name,count=item.count,quality=item.quality.name,item_number=item.item_number,type=item.prototype.type}
     if item.prototype.type=='item-with-entity-data'then row.entity_color=plain(item.entity_color,depth+1);row.entity_label=item.entity_label end
     slots[#slots+1]=row
    end end
    return {object='LuaInventory',valid=true,slots=slots}
   end
   return {object=v.object_name,valid=v.valid}
  end);return ok and r or '<runtime-object>'
 end
 if t~='table'then return v end
 local r={};for k,x in pairs(v)do if type(k)=='string'or type(k)=='number'then r[k]=plain(x,depth+1,trust_plain_tags or k=='tags')end end;return r
end
local function S()storage.coverage_probe=storage.coverage_probe or {seq=0,trace={},dropped=0};return storage.coverage_probe end
function P.init()
 for _,control in ipairs{'copy-entity-settings','paste-entity-settings','debug-reset-zoom','debug-reset-zoom-2x'}do script.on_event('fabric-probe-'..control,function(e)
  local p=game.get_player(e.player_index);local s=S();s.seq=s.seq+1;s.trace[#s.trace+1]={seq=s.seq,tick=game.tick,event='linked-'..control,data={event=plain(e),selected=plain(p.selected),source=plain(p.entity_copy_source),cursor=p.cursor_stack.valid_for_read and p.cursor_stack.name or nil}};if #s.trace>8192 then table.remove(s.trace,1);s.dropped=s.dropped+1 end
 end)end
 for _,name in ipairs({'on_pre_ghost_deconstructed','on_pre_build','on_built_entity','on_robot_built_entity','on_player_mined_entity','on_robot_mined_entity','on_pre_player_mined_item','on_marked_for_upgrade','on_cancelled_upgrade','on_pre_ghost_upgraded','on_player_rotated_entity','on_player_flipped_entity','on_entity_settings_pasted','on_blueprint_settings_pasted','on_entity_died','on_post_entity_died','on_entity_cloned','on_player_configured_blueprint','on_player_cursor_stack_changed','on_undo_item_added','on_undo_applied','on_redo_applied'})do
  local id=defines.events[name];if id then local previous=script.get_event_handler(id)
   script.on_event(id,function(e)
    local s=S();s.seq=s.seq+1;s.trace[#s.trace+1]={seq=s.seq,tick=game.tick,event=name,data=plain(e)}
    if #s.trace>8192 then table.remove(s.trace,1);s.dropped=s.dropped+1 end
    if previous then previous(e)end
   end)
  end
 end
end
function P.snapshot()return S()end
return P
