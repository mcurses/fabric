package.path=arg[1]..'/?.lua;'..package.path
local P=require('player-revival')
local passed=0
local function test(label,change,expected)
 storage={};game={tick=10};local calls={}
 local ghost={valid=true,unit_number=10,type='entity-ghost',ghost_name='iron-chest',quality={name='normal'},surface={index=1},position={x=.5,y=.5}}
 local proto={name='iron-chest',tile_width=1,tile_height=1,build_grid_size=1,collision_box={{-.35,-.35},{.35,.35}},has_flag=function()return false end}
 prototypes={entity={['iron-chest']=proto}}
 local surface={index=1,find_entities_filtered=function()return{ghost}end}
 local p={index=1,surface=surface,force={},cursor_stack={valid_for_read=true,name='iron-chest',quality={name='normal'},prototype={place_result=proto}}}
 game.get_player=function()return p end
 local input={tool='iron-chest',kind='build',tick=10,epoch=1,cursor={x=.5,y=.5}}
 local pre={player_index=1,position={x=.5,y=.5},build_mode=0}
 local en={valid=true,unit_number=20,type='container',name='iron-chest',quality={name='normal'},surface=surface,position={x=.5,y=.5}}
 local event={player_index=1,entity=en,tags={test='kept'},consumed_items={{valid_for_read=true,name='iron-chest',quality={name='normal'}}}}
 P.init{input=function()return input end,epoch=function()return 1 end,register=function()end,revive=function(e,proof)assert(e.tags.test=='kept');assert(P.matches(proof,10));calls[#calls+1]=proof end}
 local ctx={ghost=ghost,input=input,pre=pre,event=event,entity=en}
 if change then change(ctx,'before')end
 P.pre(pre)
 if ctx.extra_pre then P.pre(pre)end
 ghost.valid=ctx.keep_ghost or false
 assert(P.built(event))
 if ctx.extra_body then local copy={};for k,v in pairs(event)do copy[k]=v end;local body={};for k,v in pairs(en)do body[k]=v end;body.unit_number=21;copy.entity=body;P.built(copy)end
 P.tick();assert(#calls==0,'must wait for complete tick')
 if change then change(ctx,'after')end
 game.tick=11;P.tick();assert(#calls==expected,label..': expected '..expected..', got '..#calls)
 passed=passed+1
end
test('exact native revival',nil,1)
test('ghost still alive',function(c)c.keep_ghost=true end,0)
test('duplicate prebuild',function(c)c.extra_pre=true end,0)
test('two bodies',function(c)c.extra_body=true end,0)
test('stale input',function(c)c.input.tick=8 end,0)
test('cursor changed',function(c)c.input.epoch=2 end,0)
test('different click position',function(c)c.input.cursor={x=20,y=20}end,0)
test('different consumed material',function(c)c.event.consumed_items[1].name='steel-chest'end,0)
test('entity moved before finalization',function(c,phase)if phase=='after'then c.entity.position={x=2,y=2}end end,0)
test('held native input',function(c)c.pre.created_by_moving=true;c.input.tick=1 end,1)
print('PASS '..passed..' player revival receipt cases')
