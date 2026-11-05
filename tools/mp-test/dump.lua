local tag=TAG
local function ser(v) return serpent.block(v,{sortkeys=true,comment=false,nocode=true}) end
local ok,rep=pcall(function() return remote.call('fabric-blueprint-eligibility','report') end)
helpers.write_file('mp/'..tag..'-storage.txt',ser(storage),false)
helpers.write_file('mp/'..tag..'-elig.txt',ser(ok and rep or {err=tostring(rep)}),false)
rcon.print('dumped '..tag..' tick '..game.tick)
