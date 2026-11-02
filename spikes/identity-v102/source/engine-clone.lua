-- Engine clone events identify two distinct live objects. This proves a fresh
-- independent body copy, never movement or restoration of the source ID.
local M={};local A
function M.init(api)A=api end
function M.cloned(event)
 local src,dst=event.source,event.destination
 if not(src and src.valid and dst and dst.valid and src~=dst and src.unit_number and dst.unit_number and src.unit_number~=dst.unit_number)then return false end
 if dst.type=='entity-ghost'or not A.eligible(dst)then return false end
 A.register(dst,'script-unresolved')
 local row=A.row(dst);if not row then return false end
 row.id=A.alloc('F');row.reason='engine-clone-copy';row.identity_candidates=nil;row.identity_candidate_count=nil
 row.operation='engine clone from runtime '..src.unit_number..'; fresh independent copy'
 row.clone_source_unit=src.unit_number;row.clone_tick=game.tick
 return true
end
return M
