
local utils=require('utils')
local eventful=require('plugins.eventful')
validArgs = validArgs or utils.invert({
 'type',
 'target'
})

local args = utils.processArgs({...}, validArgs)

local function mark_unit_for_death(target,marker)
    if marker=='023' then
		dfhack.persistent.save({key='SCP_MARKED_FOR_DEATH/'..target.id,value='SCP-023'})
	end
end

eventful.enableEvent(eventful.eventType.UNIT_DEATH,5)

eventful.onUnitDeath.marked=eventful.onUnitDeath.marked or function(unit_id)
	if dfhack.persistent.get('SCP_MARKED_FOR_DEATH/'..unit_id) then
		dfhack.gui.makeAnnouncement(df.announcement_type.CITIZEN_DEATH,{D_DISPLAY=true,A_DISPLAY=true},'The death of ' .. dfhack.TranslateName(dfhack.units.getVisibleName(df.unit.find(unit_id)))..' is anomalous in nature, most likely caused by '..v.value..'.',COLOR_RED,true)
	end
end
