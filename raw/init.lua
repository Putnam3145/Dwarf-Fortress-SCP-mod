eventful=require("plugins.eventful")

function itemIsBattery(item)
    return (df.item_toolst:is_instance(item) and string.find(string.lower(item.subtype.name[0]),"battery"))
end

function getBattery(itemList)
    for k,v in ipairs(itemList) do
        if itemIsBattery(v) then return v end
    end
    return nil
end

function getDrainAmount(products)
    for k,product in ipairs(products) do
        local toolType=dfhack.items.getSubtypeDef(product.item_type,product.item_subtype)
        if toolType and string.find(toolType.id,"BATTERY_DRAIN") then return product.product_dimension end
    end
    return nil
end

function itemIsRechargeableBattery(item)
    return (itemIsBattery(item) and string.find(string.lower(item.subtype.name[0]),"recharge"))
end

function getBatteryCharge(battery)
    if not itemIsBattery(battery) then return nil else return dfhack.items.getGeneralRef(battery,56).race end
end

function chargeBattery(reaction,unit,input_items,input_reagents,output_items,call_native)
    local power=dfhack.items.getGeneralRef(getBattery(input_items),56) --df.general_ref_creaturest
    power.race=10000
    call_native.value=false
end

function getCharge(reaction,unit,input_items,input_reagents,output_items,call_native)
    dfhack.gui.showAnnouncement("Battery is at " .. dfhack.items.getGeneralRef(getBattery(input_items),56).race/100 .. "% power!")
end

function drainBattery(reaction,unit,input_items,input_reagents,output_items,call_native)
    local power = dfhack.items.getGeneralRef(getBattery(input_items),56)
    local drain = getDrainAmount(reaction.products)
    power.race=power.race-drain
    if power.race<0 then
        power.race=0
        call_native.value=false
        dfhack.gui.showAnnouncement(dfhack.TranslateName(unit.name) .. "cancels job: battery needs recharging",COLOR_RED,true)
    end
end

eventful.registerReaction("LUA_HOOK_RECHARGE_BATTERY",chargeBattery)
eventful.registerReaction("LUA_HOOK_RECHARGE_BATTERY_FUEL",chargeBattery)
eventful.registerReaction("LUA_HOOK_ELECTROWINNING_NON",drainBattery)
eventful.registerReaction("LUA_HOOK_ELECTROWINNING_RE",drainBattery)
eventful.registerReaction("LUA_HOOK_ELECTROPLATING_LEAD_NON",drainBattery)
eventful.registerReaction("LUA_HOOK_ELECTROPLATING_LEAD_RE",drainBattery)
eventful.registerReaction("LUA_HOOK_CHECK_BATTERY_POWER_P",getCharge)

local scp_447_index=dfhack.matinfo.find("SCP_447_2").index

local corpsesToCheck={}

local function forceGameOver(message)
    if message then dfhack.gui.showPopupAnnouncement(message,12) end
    dfhack.timeout(1,'ticks',function() df.global.ui.game_over = true end)
end

local function initializeCorpseCheck(corpse,ArgDelayTicks)
    corpsesToCheck[corpse.id]={delayTicks=2,corpseID=corpse.id}
    function corpsesToCheck[corpse.id].checkFor447(self)
        local corpse=df.item.find(self.corpseID)
        if not (corpse.flags.in_inventory or corpse.flags.in_building) then 
            if corpse.contaminants then
                for k,contaminant in ipairs(corpse.contaminants) do
                    if contaminant.mat_type==0 and contaminant.mat_index==scp_447_index then forceGameOver("SCP-447-2 has been detected on a dead body. Immediate destruction of site authorized by O5s.") end
                end
            end
            local block_events = dfhack.maps.getTileBlock(corpse.pos).block_events
            for k,event in ipairs(block_events) do
                if df.block_square_event_material_spatterst:is_instance(event) then
                    if event.amount[corpse.pos.x%16][corpse.pos.y%16]>0 then forceGameOver("SCP-447-2 has been detected on a dead body. Immediate destruction of site authorized by O5s.") end
                end
            end
        end
        self.delayTicks=self.delayTicks<1024 and self.delayTicks*2 or self.delayTicks
        dfhack.timeout(self.delayTicks,'ticks',function() self:checkFor447 end)
        return false
    end
    dfhack.timeout(ArgDelayTicks,'ticks',function() corpsesToCheck[corpse.id]:checkFor447() end)
end

local function initializeCorpseChecks()
    local totalDelayTicks=1
    for _,corpse in ipairs(df.global.world.items.other.ANY_CORPSE) do
        initializeCorpseCheck(corpse,totalDelayTicks)
        totalDelayTicks=totalDelayTicks+2
    end
end

local function findCorpseGivenID(unit_id)
	for i=#df.global.world.items.other.ANY_CORPSE-1,0,-1 do
		local corpse = df.global.world.items.other.ANY_CORPSE[i]
		if corpse.unit_id==unit_id then return corpse end
	end
	return nil
end

eventful.enableEvent(eventful.eventType.UNIT_DEATH,5)

eventful.onUnitDeath.SCP=function(unit_id)
	initializeCorpseCheck(findCorpseGivenID(unit_id),1)
end

initializeCorpseChecks()
