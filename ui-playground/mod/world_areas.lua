local R=require('__fabric-ui-playground__/runtime')
local S=require('__fabric-ui-playground__/snapshots')
local M={}
function M.items(state) return state.items or {} end
function M.at(demo,position)
  for _,cell in ipairs(R.store().cells) do if S.inside(position,cell.bounds) then return cell end end
end
function M.rename(demo,area,name) area.name=name end
return M
