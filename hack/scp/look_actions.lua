local utils = require 'utils'
validArgs = validArgs or utils.invert({
 'looker',
 'lookee'
})

local args = utils.processArgs({...}, validArgs)

function run(looker,lookee)
    if df.creature_raw.find(lookee.race).creature_id=='SCP_023' and looker.relations.old_year>df.global.cur_year+1 then
		looker.relations.old_year=df.global.cur_year+1
		dfhack.run_script('scp/mark_for_death','-target',looker.id,'-type','023')
	end
	if df.creature_raw.find(lookee.race).creature_id=='SCP_173' then
		dfhack.run_script('modtools/add-syndrome','-syndrome','scp 173 stopped','-resetPolicy','ResetDuration','-target',lookee.id,'-skipImmunities')
	end
end

run(df.unit.find(args.looker),df.unit.find(args.lookee))