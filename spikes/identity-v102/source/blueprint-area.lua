-- Collision and selection geometry can be displaced from one another (elevated
-- rails). Extraction chooses by selection geometry. Include both secondary boxes.
return function(e)
 local p=e.position;local x1,y1,x2,y2=p.x,p.y,p.x,p.y
 for _,name in ipairs{'bounding_box','selection_box','secondary_bounding_box','secondary_selection_box'}do
  local b=e[name];if b then x1=math.min(x1,b.left_top.x);y1=math.min(y1,b.left_top.y);x2=math.max(x2,b.right_bottom.x);y2=math.max(y2,b.right_bottom.y)end
 end
 return {{x1-.01,y1-.01},{x2+.01,y2+.01}}
end
