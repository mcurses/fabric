-- Shared runtime GUI primitives; use Factorio's native title/action styles.
local M={icons={stitch="fabric-ui-stitch",submit="utility/export_slot",reset="utility/reset",reset_white="utility/reset_white",apply_white="utility/check_mark_white"}}
function M.titlebar(frame,options)
  local bar=frame.add{type="flow",name="titlebar",direction="horizontal",raise_hover_events=true}
  bar.style.height=28
  bar.style.vertical_align="center"
  bar.style.horizontal_spacing=4
  bar.style.horizontally_stretchable=true
  local title=bar.add{type="label",caption=options.title,style="frame_title"}
  title.drag_target=frame
  local drag=bar.add{type="empty-widget",style="draggable_space_header",raise_hover_events=true}
  drag.style.horizontally_stretchable=true
  drag.style.height=24
  drag.drag_target=frame
  for _,action in ipairs(options.icon_actions or {}) do
    bar.add{type="sprite-button",name=action.name,sprite=action.sprite,
      style="frame_action_button",tags=action.tags,tooltip=action.tooltip}
  end
  bar.add{type="sprite-button",name="close_window",sprite="utility/close",
    style="close_button",tags=options.close_tags,
    tooltip=options.close_tooltip or "Close"}
  return bar
end
-- Both template commits and instance bulk actions use these exact controls.
function M.action_stack(parent,id,actions,enabled)
  local stack=parent.add{type="flow",direction="vertical",name="bulk_actions"}
  stack.style.vertical_spacing=4
  for _,spec in ipairs(actions) do
    local button=stack.add{type="button",
      caption="[img="..M.icons[spec.icon].."]  "..spec.caption,
      tags={action=spec.action,id=id},enabled=enabled}
    button.style.width=388; button.style.height=36; button.style.padding=4
  end
  return stack
end
-- Session navigation stays outside content windows, including when they close.
function M.meta_bar(player)
  local existing=player.gui.top.fabric_ui_meta
  if existing and existing.tags.version==3 then return existing end
  if existing then existing.destroy() end
  local bar=player.gui.top.add{type="frame",name="fabric_ui_meta",direction="horizontal",tags={version=3}}
  bar.style.padding=4
  for _,spec in ipairs({
    {"World","world"},{"Template Collection","collection"},{"Library","library"},{"Tune","tuning"},{"Reload","reload"},
  }) do
    local button=bar.add{type="button",caption=spec[1],tags={action=spec[2]}}
    button.style.height=28
    button.style.padding=4
  end
  local sample=bar.add{type="button",name="sample_edits",caption="Add sample edits",visible=false}
  sample.style.height=28; sample.style.padding=4
  return bar
end
function M.sample_action(player,spec)
  local button=M.meta_bar(player).sample_edits
  button.visible=spec~=nil
  if spec then
    button.caption=spec.caption
    button.tags={action=spec.action,id=spec.id}
  end
end
return M
