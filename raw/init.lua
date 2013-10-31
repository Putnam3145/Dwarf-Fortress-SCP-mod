local function checkAllDeadBodiesFor447()
	local scp_447_index=dfhack.matinfo.find("SCP_447_2").index
	for _,corpse in ipairs(df.global.world.items.other.ANY_CORPSE) do
		if not (corpse.flags.in_inventory or corpse.flags.in_building) then 
			if corpse.contaminants then
				for k,contaminant in ipairs(corpse.contaminants) do
					if contaminant.mat_type==0 and contaminant.mat_index==scp_447_index then return true end
				end
			end
			local block_events = dfhack.maps.getTileBlock(corpse.pos).block_events
			for k,event in ipairs(block_events) do
				if df.block_square_event_material_spatterst:is_instance(event) then
					if event.amount[corpse.pos.x%16][corpse.pos.y%16]>0 then return true end
				end
			end
		end
	end
	return false
end

local function forceGameOver()
	df.global.ui.game_over = true
end

local function SCP_init_repeat()
	if checkAllDeadBodiesFor447() then
		dfhack.gui.showPopupAnnouncement("SCP-447-2 has been detected on a dead body. Immediate destruction of site authorized by O5s.",12)
		dfhack.timeout(1,'ticks',forceGameOver)
	end
	dfhack.timeout(1,'days',SCP_init_repeat)
end

dfhack.timeout(1,'ticks',SCP_init_repeat)