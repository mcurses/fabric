local M={}
M.fields={
  {key='row_y',label='Contents ↑ / ↓',default=0,min=-10,max=10},
  {key='text_y',label='Label ↑ / ↓',default=0,min=-10,max=10},
  {key='control_y',label='Anchor / Preview ↑ / ↓',default=0,min=-10,max=10},
  {key='remove_x',label='× ← / →',default=-2,min=-24,max=12},
  {key='remove_y',label='× ↑ / ↓',default=0,min=-12,max=12},
  {key='remove_width',label='× width',default=16,min=12,max=32},
  {key='remove_height',label='× height',default=28,min=16,max=36},
  {key='anchor_width',label='Anchor button width',default=130,min=90,max=170,slot_only=true},
  {key='preview_width',label='Preview button width',default=90,min=60,max=110,slot_only=true},
  {key='remove_gap',label='Gap before ×',default=8,min=0,max=24,slot_only=true},
  {key='icon_size',label='Preview icon size',default=24,min=16,max=28},
}
function M.fields_for(kind)
  local out={};for _,f in ipairs(M.fields) do if not f.slot_only or kind=='slots' then out[#out+1]=f end end;return out
end
local defaults={slots={text_y=-2,control_y=-3,remove_x=-4,remove_y=-2,remove_height=31},slot_previews={text_y=-4,remove_x=-5,remove_y=-4}}
function M.values(state,kind)
  state.slot_ui_tuning=state.slot_ui_tuning or {};local t=state.slot_ui_tuning[kind] or {};state.slot_ui_tuning[kind]=t
  for _,f in ipairs(M.fields) do if t[f.key]==nil then t[f.key]=(defaults[kind] or {})[f.key] or f.default end end
  return t
end
local function y(element,value) element.style.top_margin=value;element.style.bottom_margin=-value end
function M.apply(root,state)
  local function visit(el)
    local kind=el.tags.slot_tune_kind
    if kind then
      local t=M.values(state,kind);y(el,t.row_y)
      if el.slot_label then y(el.slot_label,t.text_y) end
      if el.anchor_button then y(el.anchor_button,t.control_y) end
      if el.preview_button then y(el.preview_button,t.control_y) end
      if el.preview_icon then el.preview_icon.style.size=t.icon_size end
      if el.slot_remove then
        local b=el.slot_remove;y(b,t.remove_y);b.style.left_margin=t.remove_x+(kind=='slots' and t.remove_gap or 0);b.style.right_margin=-t.remove_x
        b.style.width=t.remove_width;b.style.height=t.remove_height
        if kind=='slots' and el.slot_label then
          el.slot_label.style.width=math.max(30,130-(t.remove_width-16)-(t.anchor_width-130)-(t.preview_width-90)-t.remove_gap)
          if el.anchor_button then el.anchor_button.style.width=el.preview_button and t.anchor_width or (t.anchor_width+t.preview_width+4) end
          if el.preview_button then el.preview_button.style.width=t.preview_width end
        end
      end
      if kind=='slot_previews' and el.slot_label then el.slot_label.style.width=380-t.icon_size-t.remove_width-8 end
    end
    for _,child in ipairs(el.children or {}) do visit(child) end
  end
  if root then visit(root) end
end
return M
