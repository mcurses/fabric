-- Re-loading the module simulates a joining Lua VM; persisted storage is shared.
package.path=arg[1]..'/?.lua;'..package.path
storage={playground={surfaces={['1']={baseline={F1={name='iron-chest',settings={name='iron-chest'}}},settings_cache={}}}}}
game={tick=100}
local function load()package.loaded.eligibility=nil;return require('eligibility')end
local m=load();m.report()
local exact={proof='exact unmarked engine mapping',unit=12,surface=1,tick=100}
storage.fabric_blueprint_domain.positive['iron-chest']=exact
load().report()
assert(storage.fabric_blueprint_domain.positive['iron-chest']==exact,'late join overwrote authoritative domain evidence')
-- Migration may fill gaps but must never weaken already recorded proof.
storage.fabric_blueprint_domain.seeded=nil
load().report()
assert(storage.fabric_blueprint_domain.positive['iron-chest']==exact,'migration overwrote authoritative domain evidence')
assert(storage.fabric_blueprint_domain.seeded==true,'migration marker must be persistent')
print('PASS eligibility reload and migration')
