eventful=require("plugins.eventful")

----------------------------------
----------- Batteries ------------
----------------------------------

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
eventful.registerReaction("LUA_HOOK_ELECTROWINNING",drainBattery)
eventful.registerReaction("LUA_HOOK_ELECTROPLATING_LEAD",drainBattery)
eventful.registerReaction("LUA_HOOK_CHECK_BATTERY_POWER_P",getCharge)
eventful.registerReaction("LUA_HOOK_RECHARGE_BATTERY_117",chargeBattery)

----------------------------------------
--------------- SCP-447 ----------------
----------------------------------------

local scp_447_index=dfhack.matinfo.find("SCP_447_2").index

local corpsesToCheck={}

local function forceGameOver(message)
    if message then dfhack.gui.showPopupAnnouncement(message,12) end
    dfhack.timeout(1,'ticks',function() df.global.ui.game_over = true end)
end

local function initializeCorpseCheck(corpse,ArgDelayTicks)
    corpsesToCheck[corpse.id]={delayTicks=2,corpseID=corpse.id}
    corpsesToCheck[corpse.id].checkFor447=function(self)
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
                    if event.amount[corpse.pos.x%16][corpse.pos.y%16]>0 and dfhack.matinfo.decode(mat_type,mat_index)==dfhack.matinfo.find('SCP_447_2') then forceGameOver("SCP-447-2 has been detected on a dead body. Immediate destruction of site authorized by O5s.") end
                end
            end
        end
        self.delayTicks=self.delayTicks<1024 and self.delayTicks*2 or self.delayTicks
        dfhack.timeout(self.delayTicks,'ticks',function() self:checkFor447() end)
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

eventful.onUnitDeath.SCP_447=function(unit_id)
    initializeCorpseCheck(findCorpseGivenID(unit_id),8)
end

initializeCorpseChecks()

----------------------------------------
--------------- SCP-294 ----------------
----------------------------------------

-- this section of script makes me feel like I'm violating these strings

function cleanString(str)
    if not str then return '' end
    return str:lower():gsub('%W','')
end

function desperatelyAttemptToMatchStrings(str1,str2)
    if not str1 or not str2 then return false end
    return cleanString(str1):find(cleanString(str2)) or cleanString(str2):find(cleanString(str1))
end

function findPlant(str,desparate)
    --ugly ugly function, but this whole script is ugly
    if desparate then
        for k,v in ipairs(df.global.world.raws.plants.all) do
            if desperatelyAttemptToMatchStrings(str,v.id) or desperatelyAttemptToMatchStrings(str,v.name) then return {v,'plant'} end
        end
    else
        for k,v in ipairs(df.global.world.raws.plants.all) do
            if cleanString(str)==cleanString(v.id) or cleanString(v.name)==cleanString(str) then return {v,'plant'} end
        end
    end
    return {false,nil}
end

function findCreature(str,desparate)
    if desparate then
        for k,v in ipairs(df.global.world.raws.creatures.all) do
            if desperatelyAttemptToMatchStrings(str,v.creature_id) or desperatelyAttemptToMatchStrings(str,v.name[0]) then return {v,'creature'} end
        end
    else
        for k,v in ipairs(df.global.world.raws.creatures.all) do
            if cleanString(str)==cleanString(v.creature_id) then return {v,'creature'} end --the name equality is handled by the binsearch
        end
    end
    return {false,nil}
end

function findMaterialGivenPlainLanguageString(str)
    --not going to include odd substances :I
    local str=str:gsub("'",''):gsub('"','')
    local tokenStr=string.upper(str:gsub(' ','_'))
    local moddedString=tokenStr:gsub('_',':')
    for i=1,2 do
        if i==1 then
            moddedString='CREATURE:'..moddedString
        else
            moddedString='PLANT:'..moddedString
        end
        local find=dfhack.matinfo.find(tokenStr) or dfhack.matinfo.find(moddedString)
        if find then return find.type,find.index end
    end
    str=string.lower(str:gsub('_',' ')) --making sure it's all nice for the ugly part
    --this is the ugly part
    local utils=require('utils')
    local foundMatchingObject={}
    for word in str:gmatch('%a+') do
        --first, we search for an object, starting with a binsearch followed by a plant search followed by a creature search using a different creature identifier followed by a couple of nasty desparate searches.
        local binsearchResult={utils.binsearch(df.global.world.raws.creatures.alphabetic,string.lower(word),'name',utils.compare_field_key(0))}
        foundMatchingObject=foundMatchingObject[1]==true and foundMatchingObject or binsearchResult[2]==true and binsearchResult or findPlant(word) or findCreature(word) or findPlant(word,true) or findCreature(word,true)
        if foundMatchingObject[1]==true then
            for k,v in ipairs(foundMatchingObject[1].material) do --then we desperately try to find a material that matches the object.
                if desperatelyAttemptToMatchStrings(word,v.id) or desperatelyAttemptToMatchStrings(word,v.state_name.Liquid) or desperatelyAttemptToMatchStrings(word,v.state_name.Solid) or 
                desperatelyAttemptToMatchStrings(str,v.id) or desperatelyAttemptToMatchStrings(str,v.state_name.Liquid) or desperatelyAttemptToMatchStrings(str,v.state_name.Solid) then
                    if v.heat.melting_point~=60001 then
                        if foundMatchingObject[2]==true or foundMatchingObject[2]=='creature' then
                            local find = dfhack.matinfo.find('CREATURE:'..foundMatchingObject[1].creature_id..':'..v.id) --splitting the string doesn't work right now
                            return find.type,find.index
                        elseif foundMatchingObject[2]=='plant' then
                            local find = dfhack.matinfo.find('PLANT:'..foundMatchingObject[1].id..':'..v.id)
                            return find.type,find.index
                        else
                        end
                    end
                end
            end
        end
    end
    return false,false
end

local script=require('gui/script')

function SCP_294(reaction,unit,input_items,input_reagents,output_items,call_native)
    script.start(function()
        local mattype,matindex
        repeat
            local tryAgain
            local ok,matString=script.showInputPrompt('SCP-294','Select your drink.',COLOR_LIGHTGREEN)
            if ok then
                mattype,matindex=findMaterialGivenPlainLanguageString(matString)
            end
            if not mattype then
                script.showMessage('SCP-294','OUT OF RANGE',COLOR_LIGHTGREEN)
                tryAgain=script.showYesNoPrompt('SCP-294','TRY AGAIN?',COLOR_LIGHTGREEN)
            end
        until not tryAgain or mattype
        if mattype then
            for k,v in ipairs(df.global.world.raws.reactions) do
                if v.code:find('SCP_294_DISPENSE') then
                    for _,product in ipairs(v.products) do
                        if product.product_to_container=='container' then
                            product.mat_type=mattype
                            product.mat_index=matindex
                        end
                    end
                end
            end
        end
    end)
end
eventful.registerReaction('LUA_HOOK_SCP_294_SELECT_LIQUID_FOR_DISPENSING',SCP_294)
--[[
----------------------------------------
--------------- SCP-963 ----------------
----------------------------------------

function getFoundationRace()
	local race,ok=utils.binsearch(df.global.world.raws.creatures.alphabetic,'foundation member','name',utils.compare_field_key(0))
	return ok and df.global.world.raws.creatures.list_creature[race.caste[0].index] or 0
end

function jackBrightHistFig()
	i=#df.global.world.history.figures-1,0,-1 do
		local fig = df.global.world.history.figures[i]
		if fig.name.first_name=="dr. jack" then return fig,fig.id end
	end
	local brightFig=df.global.world.history.figures:insert('#',{new=df.historical_figure,profession=68,race=getFoundationRace(),caste=5,sex=1,appeared_year=df.global.cur_year-30,born_year=df.global.cur_year-30,born_seconds=0,old_year=-1,id=df.global.hist_figure_next_id})
	df.global.hist_figure_next_id=df.global.hist_figure_next_id+1
	brightFig.name.first_name='dr. jack'
	local brightWord={utils.binsearch(df.global.world.raws.language.words,'BRIGHT','word')}
	brightWord=brightWord[3]
	brightFig.name.words[0]=brightWord
	brightFig.name.parts_of_speech[0]=2
	brightFig.info=df.historical_figure_info:new()
	brightFig.info.skills=df.historical_figure_info.T_skills:new()
	brightFig.info.skills.skills:insert('#',15)
	brightFig.info.skills.points:insert('#',50000)
	return brightFig,brightFig.id
end

function doctorBrightTakeOver(unit)
	local oldFig=df.historical_figure.find(unit.hist_figure_id)
	fig,unit.hist_figure_id=jackBrightHistFig()
	fig.civ_id=oldFig.civ_id
	fig.population_id=oldFig.population_id -- yeah, not right, but necessary
	local allUnitNames={
	unit.name,
	unit.status.current_soul.name
	}
	local brightWord={utils.binsearch(df.global.world.raws.language.words,'BRIGHT','word')} --BRIGHT is within the sorted words, so it's good.
	brightWord=brightWord[3]
	for k,v in ipairs(allUnitNames) do
		for kk,vv in ipairs(v.words) do
			vv=-1
			v.parts_of_speech[kk]=-1
		end
		v.words[0]=brightWord
		v.parts_of_speech[0]=2
		v.first_name="dr. jack"
	end
end
]]