-- Saveable, single-writer queue. Each step is a native blueprint layer or a
-- bounded floor batch; no coroutine or closure is stored in the save file.
local R=require('__fabric-ui-playground__/runtime')
local M={}
function M.start(player,element,data)
  if storage.fabric_job then return false end
  storage.fabric_job={player=player.index,element=element,action=element.tags.action,data=data,tasks={},index=1,started=game.tick,command=true,close_panels={}}
  if element.type=='button' then storage.fabric_job.caption=element.caption;element.enabled=false;element.caption='Working…  0%' end
  if element.type=='button' then
    local parent=element.parent
    if (parent.type=='flow' or parent.type=='frame') and parent.direction=='vertical' then
      local bar=parent.add{type='progressbar',value=0}
      bar.style.width=math.max(32,element.style.minimal_width or 300);bar.style.height=4;bar.style.top_margin=-8;bar.style.color={.2,.8,.3}
      local index;for i,child in ipairs(parent.children) do if child==element then index=i;break end end
      for i=#parent.children,index+2,-1 do parent.swap_children(i,i-1) end
      storage.fabric_job.button_progress=bar
    end
  end
  local old=player.gui.screen.fabric_loading;if old then old.destroy() end
  local panel=player.gui.screen.add{type='frame',name='fabric_loading',direction='vertical'}
  panel.add{type='label',name='status',caption='Preparing…'}
  panel.add{type='progressbar',name='progress',value=0}.style.width=300
  panel.location={x=math.max(0,(player.display_resolution.width-332*player.display_scale)/2),y=math.max(0,player.display_resolution.height-100*player.display_scale)}
  return true
end
function M.tick(dispatch,complete)
  local job=storage.fabric_job;if not job then return end
  local player=game.get_player(job.player);if not player then return end
  local ok,err=pcall(function()
    if job.command then
      job.command=false;job.executing=true
      dispatch{player_index=player.index,element=job.element,data=job.data}
      job.executing=nil
      return
    end
    for _=1,8 do
      local task=job.tasks[job.index]
      if not task then
        job.finishing=true
        if job.button_progress and job.button_progress.valid then job.button_progress.destroy() end
        complete(player,job)
        if job.element and job.element.valid then job.element.enabled=true;if job.caption then job.element.caption=job.caption end end
        local panel=player.gui.screen.fabric_loading;if panel then panel.destroy() end
        storage.fabric_job=nil
        return
      end
      R.run_task(player,task);job.index=job.index+1
      if task.kind~='floor' then break end
    end
    local fraction=(job.index-1)/math.max(1,#job.tasks)
    job.progress=math.max(job.progress or 0,math.min(.99,fraction))
    if job.button_progress and job.button_progress.valid then job.button_progress.value=job.progress end
    local percent=math.floor(job.progress*100)
    if job.element.valid and job.element.type=='button' then job.element.caption={'',job.caption,'  ',percent,'%'} end
    local panel=player.gui.screen.fabric_loading
    if panel then panel.progress.value=job.progress;panel.status.caption='Applying changes · '..percent..'%' end
  end)
  if not ok then
    job.error=tostring(err);job.executing=nil;job.in_task=nil;job.prepared=nil
    log('[Fabric job] '..job.error)
    player.print('[Fabric] Operation stopped: '..job.error..'. Reload to retry the saved step.')
    local panel=player.gui.screen.fabric_loading;if panel then panel.status.caption='Stopped · reload to retry' end
  end
end
return M
