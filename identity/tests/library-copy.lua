-- Real production Cut + Geometry modules, mocked engine objects/input ordering.
package.path=arg[1]..'/?.lua;'..package.path
local handlers={};storage={}
script={active_mods={},on_event=function(k,f)handlers[k]=f end,register_on_object_destroyed=function()return 1 end}
defines={events=setmetatable({},{__index=function(_,k)return k end}),controllers={character=1,remote=2}}
helpers={table_to_json=function(v)return tostring(v.value)end}
prototypes={entity={['iron-chest']={tile_width=1,tile_height=1,build_grid_size=1,has_flag=function()return false end}}}
local sf={index=1};game={tick=100,surfaces={sf}}
local p={index=1,controller_type=1,surface=sf,cursor_stack={valid_for_read=false}};game.get_player=function()return p end
local C=require('cut');local rows={};local serial=0
C.init{eligible=function()return true end,scope=function()return{units=rows}end,alloc=function()serial=serial+1;return'F'..serial end,register=function(e,why)rows[tostring(e.unit_number)]=rows[tostring(e.unit_number)]or{id='U'..e.unit_number,reason=why}end}
local original={world=C.snapshot().namespace,issuer=C.issuer(),op=77,piece=1,source=9,id='FOLD'}
local oldpiece={id='FOLD',source_unit=9,state='available'}
C.snapshot().ops['77']={id=77,player=1,issuer=C.issuer(),mode='cut',pieces={['1']=oldpiece}}
local tags={fabric_playground_cut_v1=original,another_mod={value='preserve'}}
local record={object_name='LuaRecord',type='blueprint',valid_for_write=false,is_preview=false,blueprint_absolute_snapping=false,
 get_blueprint_entities=function()return{{entity_number=1,name='iron-chest',position={x=.5,y=.5},tags=tags}}end,
 get_blueprint_tiles=function()return{}end,get_blueprint_entity_tags=function()return tags end,
 set_blueprint_entity_tags=function()error('library mutation forbidden')end}
p.cursor_record=record
local function paste(unit,x)
 handlers['fabric-pg-build']{player_index=1,cursor_position={x=x,y=.5},in_gui=false}
 local input=C.input(1);assert(input.virtual_op and #input.source_tags==0,'old library tags must not confer or revoke move rights')
 C.pre{player_index=1,position={x=x,y=.5},build_mode=0,direction=0}
 local en={valid=true,unit_number=unit,type='container',name='iron-chest',surface=sf,position={x=x,y=.5},quality={name='normal'}}
 assert(C.built{player_index=1,entity=en,tags=tags},'virtual receipt collected')
 local birth=game.tick;game.tick=game.tick+1;C.finalize_receipts()
 C.history_bound{id=unit,player=1,type='built-entity',frame_receipt_version=96,current_unit=unit,event_tick=birth}
 assert(rows[tostring(unit)].reason=='clipboard-copy','native born virtual recipient must become a copy')
 assert(oldpiece.state=='available','library copy must not consume source move')
 assert(tags.fabric_playground_cut_v1==original and tags.another_mod.value=='preserve','source library unchanged')
 return rows[tostring(unit)].id
end
local first=paste(10,.5);local second=paste(11,2.5);assert(first~=second and first~='FOLD'and second~='FOLD')
-- A virtual record does not relax exact native destination surface matching.
game.tick=110;handlers['fabric-pg-build']{player_index=1,cursor_position={x=.5,y=.5},in_gui=false}
C.pre{player_index=1,position={x=.5,y=.5},build_mode=0,direction=0}
local n=C.snapshot().next_place
C.built{player_index=1,entity={valid=true,unit_number=12,type='container',name='iron-chest',surface={index=2},position={x=.5,y=.5},quality={name='normal'}},tags={}}
assert(C.snapshot().next_place==n,'other surface cannot borrow virtual receipt')
print('PASS library copy: immutable record, stale move tags isolated, repeated fresh IDs, cross-surface rejection')
-- Corrupt/duplicated source labels must not give first/last extraction ownership.
game.tick=120;p.cursor_record=nil;p.cursor_stack={valid_for_read=true,name='cut-paste-tool'}
handlers['fabric-pg-cut']{player_index=1,cursor_position={x=0,y=0}}
handlers['fabric-pg-build']{player_index=1,cursor_position={x=0,y=0}}
local src={};for i=1,2 do src[i]={valid=true,unit_number=20+i,type='container',name='iron-chest',surface=sf,position={x=i+.5,y=.5},quality={name='normal'},to_be_deconstructed=function()return false end};rows[tostring(20+i)]={id='FDUP',reason='direct'}end
p.cursor_stack={valid_for_read=true,is_blueprint=true,object_name='LuaItemStack',get_blueprint_entities=function()return{{entity_number=1,name='iron-chest'},{entity_number=2,name='iron-chest'}}end,get_blueprint_entity_tags=function()return{}end,set_blueprint_entity_tags=function()end}
handlers.on_player_setup_blueprint{player_index=1,item='blueprint',mapping={valid=true,get=function()return src end}}
local op=C.snapshot().ops[tostring(C.snapshot().next_op)]
assert(op.pieces['1'].state=='invalid'and op.pieces['2'].state=='invalid','no arbitrary winner for duplicate source ID')
print('PASS duplicate logical ID selection: all claimants invalidated')
