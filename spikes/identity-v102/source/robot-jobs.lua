-- Read-only, current-tick engine construction job observation. Tags/geometry
-- alone do not prove which overlapping runtime ghost the robot constructed.
local J={}
function J.poll()
 local surfaces={}
 for _,refs in ipairs{storage.fabric_history_refs or{},storage.vanilla_cut_refs or{}}do
  for _,g in pairs(refs)do if g.valid and g.type=='entity-ghost'then surfaces[g.surface.index]=true end end
 end
 local frame={tick=game.tick,robots={},surface_count=0}
 for si in pairs(surfaces)do local sf=game.surfaces[si];if sf then frame.surface_count=frame.surface_count+1
  for _,robot in pairs(sf.find_entities_filtered{type='construction-robot'})do
   local orders=robot.robot_order_queue;local first=orders[1];local target=first and first.target
   if first and first.type==defines.robot_order_type.construct and target and target.valid and target.type=='entity-ghost'then frame.robots[tostring(robot.unit_number)]={target=target.unit_number,surface=si}end
  end
 end end
 storage.fabric_robot_jobs=frame
end
function J.take(robot)
 local s=storage.fabric_robot_jobs;if not(s and robot and robot.valid)then return end
 local key=tostring(robot.unit_number);local job=s.robots[key];s.robots[key]=nil
 s.callbacks=(s.callbacks or 0)+1
 if job then return {tick=s.tick,robot=robot.unit_number,target=job.target,surface=job.surface}end
end
function J.matches(proof,ghost)
 if not(proof and proof.tick==game.tick and proof.target==ghost)then return false,{sample_tick=proof and proof.tick,callback_tick=game.tick,robot=proof and proof.robot,observed_target=proof and proof.target,required_target=ghost}end
 return true
end
function J.snapshot()return storage.fabric_robot_jobs or{}end
return J
