-- Object destruction registrations belong to one runtime object, even when a
-- death ghost retains its contained entity's unit number across revival.
local R={};local A
function R.init(api)A=api end
local function uncertain(old,reason)
 local row={id=A.alloc('U'),reason=reason}
 if old and type(old.id)=='string'and old.id:sub(1,1)=='F'then row.identity_candidates={old.id};row.identity_candidate_count=1;row.operation='engine unit retained across different object lifetime; causal revival proof required'end
 return row
end
local function clear_cache(st,key)
 for _,scope in pairs(st.surfaces)do if scope.settings_cache then scope.settings_cache[key]=nil end end
end
function R.register(e,reason,retained)
 if not A.eligible(e)and not retained then return end
 local st=A.state();local global=A.registry();local scope=A.scope(e.surface);local key=tostring(e.unit_number)
 local row=global[key]or scope.units[key];local previous=storage.fabric_runtime_refs[key]
 local changed=previous and previous~=e
 local registration
 if changed or not previous or not row or not row.object_registration or row.registration_version~=60 then registration=script.register_on_object_destroyed(e)end
 if changed then row=uncertain(row,'runtime-incarnation-unresolved');clear_cache(st,key)
 elseif row and row.object_registration and registration and row.object_registration~=registration then row=uncertain(row,'runtime-registration-migration-unresolved');clear_cache(st,key)
 elseif not row then row={id=A.alloc((reason=='initial'or reason=='direct')and'F'or'U'),reason=reason}end
 if registration then row.object_registration=registration;row.registration_version=60;st.registrations=st.registrations or{};st.registrations[tostring(registration)]=e.unit_number end
 global[key]=row;scope.units[key]=row;storage.fabric_runtime_refs[key]=e
 assert(type(row.id)=='string','invalid id');return row
end
function R.destroyed(event)
 local st=A.state();local registration=event.registration_number;local unit=st.registrations and st.registrations[tostring(registration)]
 if not unit then return end
 local key=tostring(unit);local current=storage.fabric_runtime_refs and storage.fabric_runtime_refs[key]
 -- A pre-upgrade row may still carry the old registration while pointing at
 -- a newer live object. Revalidate before processing its queued old callback.
 if current and current.valid then R.register(current,'runtime-incarnation-unresolved',true)end
 st.registrations[tostring(registration)]=nil
 local row=st.global_units and st.global_units[key]
 if row and row.object_registration==registration then st.global_units[key]=nil;if storage.fabric_runtime_refs then storage.fabric_runtime_refs[key]=nil end end
 for _,scope in pairs(st.surfaces)do local old=scope.units[key];if old and old.object_registration==registration then scope.units[key]=nil;if scope.settings_cache then scope.settings_cache[key]=nil end end end
 if storage.fabric_replace_refs then local old=storage.fabric_replace_refs[unit];if old and not old.valid then storage.fabric_replace_refs[unit]=nil end end
end
return R
