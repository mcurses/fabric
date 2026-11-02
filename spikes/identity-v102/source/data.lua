for _,c in ipairs({'undo','redo','cut','copy','paste','clear-cursor','build','build-ghost','super-forced-build'})do data:extend{{type='custom-input',name='fabric-pg-'..c,key_sequence='',linked_game_control=c,consuming='none'}}end

for _,c in ipairs({'copy-entity-settings','paste-entity-settings','debug-reset-zoom','debug-reset-zoom-2x'})do data:extend{{type='custom-input',name='fabric-probe-'..c,key_sequence='',linked_game_control=c,consuming='none'}}end
