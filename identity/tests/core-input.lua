package.path=arg[1]..'/?.lua;'..package.path
local handlers={}
script={active_mods={},on_event=function(k,f)handlers[k]=f end,register_on_object_destroyed=function()return 1 end}
defines={events=setmetatable({},{__index=function(_,k)return k end}),controllers={character=1,remote=2}}
storage={};game={tick=100}
local p={index=1,controller_type=2,surface={index=1},cursor_stack={valid_for_read=false}}
game.get_player=function()return p end
local C=require('cut');C.init{}
handlers['fabric-pg-cut']{player_index=1,cursor_position={x=0,y=0}}
assert(C.snapshot().arms[1] and C.snapshot().arms[1].kind=='cut','remote cut input must be tracked')
-- A prior blueprint press must not relabel a newer cut selection as copy.
p.cursor_stack={valid_for_read=true,is_blueprint=true,get_blueprint_entities=function()return{}end}
C.snapshot().inputs[1]={tool='blueprint',tick=1}
handlers.on_player_setup_blueprint{player_index=1,item='blueprint',mapping={valid=true,get=function()return{}end}}
assert(C.snapshot().next_op==0,'stale blueprint input minted a false copy operation')
local readonly={object_name='LuaRecord',valid_for_write=false,get_blueprint_entity_tags=function()return{}end,set_blueprint_entity_tags=function()error('read-only write attempted')end}
assert(C.prepare_new_blueprint(p,readonly,{entities={{entity_number=1,name='iron-chest'}}})==false,'library record must fail closed without writes')
local R=require('replacement');local rows={['1']={id='F1',reason='direct'}}
local old={valid=true,unit_number=1,name='transport-belt',type='transport-belt',position={x=.5,y=.5},prototype={fast_replaceable_group='belt'}}
local sf={index=1,find_entities_filtered=function()return{old}end};old.surface=sf;p.surface=sf
p.cursor_stack={valid_for_read=true,name='fast-transport-belt',prototype={place_result={name='fast-transport-belt',fast_replaceable_group='belt'}}}
local input={tick=1,tool='fast-transport-belt',epoch=4}
R.init{input=function()return input end,epoch=function()return 4 end,eligible=function()return true end,scope=function()return{units=rows}end,register=function(en,why)rows[tostring(en.unit_number)]={id='U2',reason=why}end,owner=function()return nil end}
R.pre{player_index=1,position={x=.5,y=.5},created_by_moving=true}
assert(R.mined{player_index=1,entity=old},'held build must retain exact replacement candidate')
old.valid=false
local new={valid=true,unit_number=2,name='fast-transport-belt',type='transport-belt',position={x=.5,y=.5},surface=sf}
assert(R.built{player_index=1,entity=new},'replacement claimed')
assert(rows['2'].id=='F1','drag replacement must preserve identity')
input.epoch=3;old.valid=true
R.pre{player_index=1,position={x=.5,y=.5},created_by_moving=true}
assert(not R.mined{player_index=1,entity=old},'changed cursor rejects stale held input')
input.epoch=4
R.pre{player_index=1,position={x=.5,y=.5},created_by_moving=false}
assert(not R.mined{player_index=1,entity=old},'late API prebuild cannot borrow held input')
print('PASS remote input, read-only library, held replacement, stale-input rejection')
