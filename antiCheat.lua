----------------------------------------
------   Anticheat by Гильгамеш   ------
------        Versin: 0.02        ------
------         For TES3MP         ------
----------------------------------------
------   Configs (true/false):    ------
local config = {}                 ------
config.logMessage = true          ------
config.globalMessage = true       ------
----------------------------------------
config.language = "En" -- ("Ru")  ------
----------------------------------------
config.kickPlayer = false         ------
config.banPlayer = false          ------
----------------------------------------
config.allSync = true             ------
----------------------------------------

local vanillaSand = "#CAA560"
local playerData = {}
local lang = {
    En = {
        anticheatPrefix = "[Anticheat]:",
        kickMessage = "Player %s has been kicked for using cheats.",
        banMessage = "Player %s has been banned for using cheats.",
        caughtMessage = "Player %s has been caught trying to use cheats.",
        logKickMessage = "Player %s has been kicked for using cheats",
        logBanMessage = "Player %s has been banned for using cheats",
        logItemNotExist = "Player %s tried to place item that doesn't exist in inventory: \"%s\" x%d",
        logMoreItems = "Player %s placed more items than you have in inventory: \"%s\" x%d",
        logSellMoreItems = "Player %s tried to sell more items to the NPC than I had: \"%s\", sold: %d, had: %d, cheated: %d",
        logContainerMoreItems = "Player %s tried to put an item in a container with more items than I had: \"%s\", sold: %d, had: %d, cheated: %d"
    },
    Ru = {
        anticheatPrefix = "[Античит]:",
        kickMessage = "Игрок %s был кикнут за использование читов.",
        banMessage = "Игрок %s был забанен за использование читов.",
        caughtMessage = "Игрок %s был замечен за попыткой использования читов.",
        logKickMessage = "Игрок %s был кикнут за использование читов",
        logBanMessage = "Игрок %s был забанен за использование читов",
        logItemNotExist = "Игрок %s попытался разместить предмет, которого нет в инвентаре: \"%s\" x%d",
        logMoreItems = "Игрок %s разместил больше предметов, чем есть в инвентаре: \"%s\" x%d",
        logSellMoreItems = "Игрок %s попытался продать больше предметов NPC, чем у него было: \"%s\", продано: %d, было: %d, чит: %d",
        logContainerMoreItems = "Игрок %s попытался положить предмет в контейнер больше, чем у него было: \"%s\", продано: %d, было: %d, чит: %d"
    }
}

local function punishment(pid, object, count)
	local currentLang = lang[config.language] or lang.En  -- Default to English if language not found
	local playerName = Players[pid].accountName
	
	if config.globalMessage then
		local message
		if config.kickPlayer then
			message = currentLang.kickMessage:format(playerName)
		elseif config.banPlayer then
			message = currentLang.banMessage:format(playerName)
		else
			message = currentLang.caughtMessage:format(playerName)
		end
		tes3mp.SendMessage(pid, color.Red .. currentLang.anticheatPrefix .. vanillaSand .. " " .. message .. "\n", true)
	end
	
	-- Log messages if enabled
	if config.logMessage then
		if count == 1 then
			tes3mp.LogMessage(1, currentLang.anticheatPrefix .. " " .. currentLang.logItemNotExist:format(playerName, object.refId, object.count or 0))
		elseif count == 2 then
			tes3mp.LogMessage(1, currentLang.anticheatPrefix .. " " .. currentLang.logMoreItems:format(playerName, object.refId, object.count or 0))
		elseif count == 3 then
			if object and #object > 0 then
				for _, invalid in ipairs(object) do
					tes3mp.LogMessage(1, currentLang.anticheatPrefix .. " " .. currentLang.logSellMoreItems:format(playerName, invalid.refId, invalid.soldCount, invalid.hadCount, invalid.difference))
				end
			end
		elseif count == 4 then
			if object and #object > 0 then
				for _, invalid in ipairs(object) do
					tes3mp.LogMessage(1, currentLang.anticheatPrefix .. " " .. currentLang.logContainerMoreItems:format(playerName, invalid.refId, invalid.soldCount, invalid.hadCount, invalid.difference))
				end
			end
		end
		
		if config.kickPlayer then
			tes3mp.LogMessage(1, currentLang.anticheatPrefix .. " " .. currentLang.logKickMessage:format(playerName))
		elseif config.banPlayer then
			tes3mp.LogMessage(1, currentLang.anticheatPrefix .. " " .. currentLang.logBanMessage:format(playerName))
		end
	end
	
	if config.banPlayer then
		tes3mp.BanAddress(tes3mp.GetIP(pid))
	elseif config.kickPlayer then
		tes3mp.Kick(pid)
	end
end

local function OnObjectPlace(eventStatus, pid, cellDescription, objects)
    for _, object in pairs(objects) do
        local totalCountInInventory = 0
        local isGold = string.match(object.refId, "^gold_")
        local originalItem = nil
        local itemFound = false
        for _, item in pairs(Players[pid].data.inventory) do
            if item then
                if isGold and string.match(item.refId, "^gold_") then
                    totalCountInInventory = totalCountInInventory + item.count
                    originalItem = {refId = item.refId, count = item.count, charge = item.charge, enchantmentCharge = item.enchantmentCharge, soul = item.soul}
                    itemFound = true
                elseif item.refId == object.refId then
                    local chargeMatch = (item.charge == object.charge) or (item.charge == -1 and object.charge == -1)
                    local enchantMatch = (item.enchantmentCharge == object.enchantmentCharge) or (item.enchantmentCharge == -1 and object.enchantmentCharge == -1)
                    if chargeMatch and enchantMatch then
                        totalCountInInventory = totalCountInInventory + item.count
                        originalItem = {refId = item.refId, count = item.count, charge = item.charge, enchantmentCharge = item.enchantmentCharge, soul = item.soul}
                        itemFound = true
                    end
                end
            end
        end
        if not itemFound then
			if isGold then
				object.refId, object.count = "gold_001", object.goldValue
			end
            punishment(pid, object, 1)
            return customEventHooks.makeEventStatus(false, false)
        elseif (isGold and object.goldValue or object.count) > totalCountInInventory then
            if isGold then
                object.goldValue = totalCountInInventory
            else
                object.count = totalCountInInventory
            end
            local inventory = Players[pid].data.inventory
            for i = #inventory, 1, -1 do
                local item = inventory[i]
                if item and ((isGold and string.match(item.refId, "^gold_")) or item.refId == object.refId) then
                    table.remove(inventory, i)
                end
            end
            if totalCountInInventory > 0 then
                inventoryHelper.addItem(inventory, object.refId, totalCountInInventory, object.charge or -1, object.enchantmentCharge or -1, object.soul or "")
            end
            Players[pid]:Save()
            Players[pid]:LoadInventory()
            Players[pid]:LoadEquipment()
            punishment(pid, object, 2)
        end
    end
end

-- EN: Function to compare items for barter and container
-- RU: Функция сравнения предметов для бартера и контейнера
local function compareItemsExceptCount(item1, item2)
	if not item1 or not item2 then return false end
	if item1.refId ~= item2.refId then return false end
	local charge1 = item1.charge or -1
	local charge2 = item2.charge or -1
	if charge1 ~= charge2 then return false end
	local enchant1 = item1.enchantmentCharge or -1
	local enchant2 = item2.enchantmentCharge or -1
	if enchant1 ~= enchant2 then return false end
	return true
end

function endTradeCheck(pid)
	local cellDescription = tes3mp.GetCell(pid)
	local npcGoldPool = LoadedCells[cellDescription].data.objectData[playerData[pid].uniqueIndex].goldPool
	local npcInventory = LoadedCells[cellDescription].data.objectData[playerData[pid].uniqueIndex].inventory
    if playerData[pid] and playerData[pid].npcInventoryBefore and npcInventory then
		-- EN: Table of items sold by NPC
		-- RU: Таблица проданных предметов НПС
		local soldItems = {} 
		local goldCheat = false

		-- EN: Track processed items from "BEFORE"
		-- RU: Отслеживаем обработанные предметы из "ДО"
		local processedBefore = {} 

		for i, itemBefore in ipairs(playerData[pid].npcInventoryBefore) do
			if itemBefore and itemBefore.refId ~= "gold_001" and not processedBefore[i] then
				local totalCountBefore = 0
				local totalCountAfter = 0
				-- EN: Count total number of items "BEFORE"
				-- RU: Считаем общее количество предметов "ДО"
				for k, item in ipairs(playerData[pid].npcInventoryBefore) do
					if item and compareItemsExceptCount(itemBefore, item) then
						totalCountBefore = totalCountBefore + item.count
						-- EN: Processed
						-- RU: Обработанные
						processedBefore[k] = true 
					end
				end

				-- EN: Count total number of items "AFTER"
				-- RU: Считаем общее количество предметов "ПОСЛЕ"
				for _, itemAfter in ipairs(npcInventory) do
					if itemAfter and compareItemsExceptCount(itemBefore, itemAfter) then
						totalCountAfter = totalCountAfter + itemAfter.count
					end
				end

				-- EN: Identify sold items by increase
				-- RU: Идентифицируем проданные предметы по увеличению
				local countDifference = totalCountAfter - totalCountBefore

				if countDifference > 0 then
					table.insert(soldItems, {refId = itemBefore.refId, count = countDifference, charge = itemBefore.charge or -1, enchantmentCharge = itemBefore.enchantmentCharge or -1})
				end
			end
		end

		-- EN: Search for new items in NPC that weren't there "BEFORE"
		-- RU: Поиск новых предметов у НПС, которых не было "ДО"
		for _, itemAfter in ipairs(npcInventory) do
			if itemAfter and itemAfter.refId ~= "gold_001" then
				local foundInBefore = false

				for _, itemBefore in ipairs(playerData[pid].npcInventoryBefore) do
					if itemBefore and compareItemsExceptCount(itemBefore, itemAfter) then
						foundInBefore = true
						break
					end
				end

				if not foundInBefore then
					table.insert(soldItems, {refId = itemAfter.refId, count = itemAfter.count, charge = itemAfter.charge or -1, enchantmentCharge = itemAfter.enchantmentCharge or -1})
				end
			end
		end

		-- EN: Gold calculation
		-- RU: Расчет золота
		if npcGoldPool - playerData[pid].npcGoldPool > 0 then
			local playerGoldBefore = 0
			if playerData[pid].playerInventoryBefore then
				for _, playerItem in pairs(playerData[pid].playerInventoryBefore) do
					if playerItem.refId == "gold_001" then
						playerGoldBefore = playerItem.count
						break
					end
				end
			end
			if npcGoldPool - playerData[pid].npcGoldPool > playerGoldBefore then
				goldCheat = true
			end
		end

		-- EN: Check player for validity
		-- RU: Проверка игрока на валидность
		if #soldItems > 0 or goldCheat then
			local invalidSales = {}

			for _, soldItem in ipairs(soldItems) do
				local playerHadCount = 0
				if playerData[pid].playerInventoryBefore then
					for _, playerItem in pairs(playerData[pid].playerInventoryBefore) do
						if playerItem and compareItemsExceptCount(playerItem, soldItem) then
							playerHadCount = playerHadCount + playerItem.count
						end
					end
				end
				if soldItem.count > playerHadCount then
                    table.insert(invalidSales, {refId = soldItem.refId,soldCount = soldItem.count, hadCount = playerHadCount, difference = soldItem.count - playerHadCount})
                end
            end

			if #invalidSales > 0 or goldCheat then
				Players[pid].data.inventory = playerData[pid].playerInventoryBefore
				Players[pid]:Save()
				Players[pid]:LoadInventory()
				Players[pid]:LoadEquipment()

				LoadedCells[cellDescription].data.objectData[playerData[pid].uniqueIndex].inventory = playerData[pid].npcInventoryBefore
				LoadedCells[cellDescription].data.objectData[playerData[pid].uniqueIndex].goldPool = playerData[pid].npcGoldPool
				LoadedCells[cellDescription]:Save()

				-- EN: Synchronization of rolled back NPC
				-- RU: Синхранизация откатанного НПС
				for pid, player in pairs(Players) do
					if player:IsLoggedIn() and player.data.location.cell == cellDescription then
						LoadedCells[cellDescription]:LoadActorPackets(pid, LoadedCells[cellDescription].data.objectData, {playerData[pid].uniqueIndex})
					end
				end

				punishment(pid, invalidSales, 3)
            end
        end

		if playerData[pid] and playerData[pid].positionTimer then
			for otherPid, otherData in pairs(playerData) do
				if playerData[otherPid].uniqueIndex == playerData[pid].uniqueIndex and otherPid ~= pid then
					playerData[otherPid].npcInventoryBefore = tableHelper.deepCopy(LoadedCells[cellDescription].data.objectData[playerData[pid].uniqueIndex].inventory)
					playerData[otherPid].npcGoldPool = tableHelper.deepCopy(LoadedCells[cellDescription].data.objectData[playerData[pid].uniqueIndex].goldPool)
				end
			end
			tes3mp.StopTimer(playerData[pid].positionTimer)
			playerData[pid] = nil
		end
	end
end

function checkPlayerPosition(pid)
	-- EN: Stop timer for sequential restart
	-- RU: Останавливаем таймер для последовательного перезапуска
	if playerData[pid] and playerData[pid].positionTimer then
        tes3mp.StopTimer(playerData[pid].positionTimer)
	else
		return 
		-- EN: For safety
		-- RU: Для безопасности
    end

	local x = tes3mp.GetPosX(pid)
	local y = tes3mp.GetPosY(pid)
	local z = tes3mp.GetPosZ(pid)
	local grx = tes3mp.GetRotX(pid)
	local grz = tes3mp.GetRotZ(pid)

	if playerData[pid].x ~= x or playerData[pid].y ~= y or playerData[pid].z ~= z or
		playerData[pid].grx ~= grx or playerData[pid].grz ~= grz then
		if playerData[pid].positionTimer then
            tes3mp.StopTimer(playerData[pid].positionTimer)
			playerData[pid] = nil
        end
		return
    end

	playerData[pid].x = x
    playerData[pid].y = y
    playerData[pid].z = z
    playerData[pid].grx = grx
    playerData[pid].grz = grz

    playerData[pid].positionTimer  = tes3mp.CreateTimerEx("checkPlayerPosition", time.seconds(0.25), "i", pid)
    tes3mp.StartTimer(playerData[pid].positionTimer)
end

local function OnObjectDialogueChoice(eventStatus, pid, cellDescription)
	if tes3mp.GetObjectDialogueChoiceType(0) == enumerations.dialogueChoice.BARTER then
        playerData[pid] = {}
		playerData[pid].isTrading = true

		playerData[pid].x = tes3mp.GetPosX(pid)
        playerData[pid].y = tes3mp.GetPosY(pid)
        playerData[pid].z = tes3mp.GetPosZ(pid)
        playerData[pid].grx = tes3mp.GetRotX(pid)
        playerData[pid].grz = tes3mp.GetRotZ(pid)

		tes3mp.ReadReceivedObjectList()
		if tes3mp.GetObjectListSize() then
			local uniqueIndex = tes3mp.GetObjectRefNum(0) .. "-" .. tes3mp.GetObjectMpNum(0)

			playerData[pid].uniqueIndex = uniqueIndex
			playerData[pid].npcInventoryBefore = tableHelper.deepCopy(LoadedCells[cellDescription].data.objectData[uniqueIndex].inventory)
			playerData[pid].playerInventoryBefore = tableHelper.deepCopy(Players[pid].data.inventory)
			playerData[pid].npcGoldPool = LoadedCells[cellDescription].data.objectData[uniqueIndex].goldPool
		end

		playerData[pid].positionTimer = tes3mp.CreateTimerEx("checkPlayerPosition", time.seconds(0.25), "i", pid)
		tes3mp.StartTimer(playerData[pid].positionTimer)
	end
	
	if config.allSync then
		if tes3mp.GetObjectDialogueChoiceType(0) == enumerations.dialogueChoice.PERSUASION then
			Players[pid]:LoadInventory()
			Players[pid]:LoadEquipment()
		elseif tes3mp.GetObjectDialogueChoiceType(0) == enumerations.dialogueChoice.SPELLS then
			Players[pid]:LoadInventory()
			Players[pid]:LoadEquipment()
		elseif tes3mp.GetObjectDialogueChoiceType(0) == enumerations.dialogueChoice.TRAVEL then
			Players[pid]:LoadInventory()
			Players[pid]:LoadEquipment()
		elseif tes3mp.GetObjectDialogueChoiceType(0) == enumerations.dialogueChoice.SPELLMAKING then
			Players[pid]:LoadInventory()
			Players[pid]:LoadEquipment()
		elseif tes3mp.GetObjectDialogueChoiceType(0) == enumerations.dialogueChoice.ENCHANTING then
			Players[pid]:LoadInventory()
			Players[pid]:LoadEquipment()
		elseif tes3mp.GetObjectDialogueChoiceType(0) == enumerations.dialogueChoice.TRAINING then
			Players[pid]:LoadInventory()
			Players[pid]:LoadEquipment()
		elseif tes3mp.GetObjectDialogueChoiceType(0) == enumerations.dialogueChoice.REPAIR then
			Players[pid]:LoadInventory()
			Players[pid]:LoadEquipment()
		end
	end
end

local function OnPlayerDisconnect(pid)
	if playerData[pid] and playerData[pid].positionTimer then
		tes3mp.StopTimer(playerData[pid].positionTimer)
	end
	playerData[pid] = nil
end

local function OnContainer(eventStatus, pid, cellDescription)
	if playerData[pid] and playerData[pid].isTrading then
		playerData[pid].isTrading = nil
		playerData[pid].tradeEndTimer = tes3mp.CreateTimerEx("endTradeCheck", time.seconds(0.25), "i", pid)
		tes3mp.StartTimer(playerData[pid].tradeEndTimer)
	elseif playerData[pid] and playerData[pid].isContainer and tes3mp.GetObjectListContainerSubAction() == enumerations.container.REMOVE then
		local containerInventory = LoadedCells[cellDescription].data.objectData[playerData[pid].uniqueIndex].inventory

		if playerData[pid] and playerData[pid].containerBefore and containerInventory then
			local laidOutItems = {}
			local processedBefore = {}
			local invalidOutItems = {}

			for i, itemBefore in ipairs(playerData[pid].containerBefore) do
				if itemBefore and not processedBefore[i] then
					local totalCountBefore = 0
					local totalCountAfter = 0

					for k, item in ipairs(playerData[pid].containerBefore) do
						if item and compareItemsExceptCount(itemBefore, item) then
							totalCountBefore = totalCountBefore + item.count
							processedBefore[k] = true
						end
					end

					for _, itemAfter in ipairs(containerInventory) do
						if itemAfter and compareItemsExceptCount(itemBefore, itemAfter) then
							totalCountAfter = totalCountAfter + itemAfter.count
						end
					end

					local countDifference = totalCountAfter - totalCountBefore

					if countDifference > 0 then
						table.insert(laidOutItems, {refId = itemBefore.refId, count = countDifference, charge = itemBefore.charge or -1, enchantmentCharge = itemBefore.enchantmentCharge or -1})
					end
				end
			end

			for _, itemAfter in ipairs(containerInventory) do
				if itemAfter then
					local foundInBefore = false

					for _, itemBefore in ipairs(playerData[pid].containerBefore) do
						if itemBefore and compareItemsExceptCount(itemBefore, itemAfter) then
							foundInBefore = true
							break
						end
					end

					if not foundInBefore then
						table.insert(laidOutItems, {refId = itemAfter.refId, count = itemAfter.count, charge = itemAfter.charge or -1, enchantmentCharge = itemAfter.enchantmentCharge or -1})
					end
				end
			end

			if #laidOutItems > 0 then
				for _, soldItem in ipairs(laidOutItems) do
					local playerHadCount = 0
					if playerData[pid].playerInventoryBefore then
						for _, playerItem in pairs(playerData[pid].playerInventoryBefore) do
							if playerItem and compareItemsExceptCount(playerItem, soldItem) then
								playerHadCount = playerHadCount + playerItem.count
							end
						end
					end
					if soldItem.count > playerHadCount then
						table.insert(invalidOutItems, {refId = soldItem.refId,soldCount = soldItem.count, hadCount = playerHadCount, difference = soldItem.count - playerHadCount})
					end
				end

				if #invalidOutItems > 0 then
					Players[pid].data.inventory = playerData[pid].playerInventoryBefore
					Players[pid]:Save()
					Players[pid]:LoadInventory()
					Players[pid]:LoadEquipment()

					LoadedCells[cellDescription].data.objectData[playerData[pid].uniqueIndex].inventory = playerData[pid].containerBefore
					LoadedCells[cellDescription]:Save()

					for pid, player in pairs(Players) do
						if player:IsLoggedIn() and player.data.location.cell == cellDescription then
							LoadedCells[cellDescription]:LoadContainers(pid, LoadedCells[cellDescription].data.objectData, {playerData[pid].uniqueIndex})
						end
					end

					-- EN: Synchronization tables with invalid layout
					-- RU: Синронизация таблиц при НЕликвидкой выкладке
					for otherPid, otherData in pairs(playerData) do
						if playerData[otherPid].uniqueIndex == playerData[pid].uniqueIndex then
							LoadedCells[cellDescription].data.objectData[playerData[otherPid].uniqueIndex].inventory = playerData[pid].containerBefore
						end
					end

					punishment(pid, invalidOutItems, 4)
				else
					-- EN: Synchronization tables with valid layout
					-- RU: Синронизация таблиц при ликвидкой выкладке
					for otherPid, otherData in pairs(playerData) do
						if playerData[otherPid].uniqueIndex == playerData[pid].uniqueIndex then
							playerData[otherPid].containerBefore = tableHelper.deepCopy(LoadedCells[cellDescription].data.objectData[playerData[pid].uniqueIndex].inventory)
						end
					end

					playerData[pid].playerInventoryBefore = tableHelper.deepCopy(Players[pid].data.inventory)
				end
			end
		end
    end
end

local function OnObjectActivate(eventStatus, pid, cellDescription, objects)
	local isContainer = nil
	local uniqueIndex = nil
	for _, object in pairs(objects) do	
		for _, containerId in ipairs(LoadedCells[cellDescription].data.packets.container) do
			if containerId == object.uniqueIndex then
				isContainer = true
				uniqueIndex = object.uniqueIndex
				break
			end
		end
		for _, containerId in ipairs(LoadedCells[cellDescription].data.packets.actorList) do
			if containerId == object.uniqueIndex then
				isContainer = nil
				break
			end
		end
	end

	if isContainer then
		if not playerData[pid] then
            playerData[pid] = {}
        end
		playerData[pid].isContainer = true

		playerData[pid].x = tes3mp.GetPosX(pid)
        playerData[pid].y = tes3mp.GetPosY(pid)
        playerData[pid].z = tes3mp.GetPosZ(pid)
        playerData[pid].grx = tes3mp.GetRotX(pid)
        playerData[pid].grz = tes3mp.GetRotZ(pid)
		
		playerData[pid].uniqueIndex = uniqueIndex
		playerData[pid].containerBefore = tableHelper.deepCopy(LoadedCells[cellDescription].data.objectData[uniqueIndex].inventory)
		playerData[pid].playerInventoryBefore = tableHelper.deepCopy(Players[pid].data.inventory)
		playerData[pid].positionTimer = tes3mp.CreateTimerEx("checkPlayerPosition", time.seconds(0.25), "i", pid)
		tes3mp.StartTimer(playerData[pid].positionTimer)
	end
end

customEventHooks.registerValidator("OnObjectDialogueChoice", OnObjectDialogueChoice)
customEventHooks.registerValidator("OnPlayerDisconnect", OnPlayerDisconnect)
customEventHooks.registerValidator("OnObjectPlace", OnObjectPlace)

customEventHooks.registerHandler("OnObjectActivate", OnObjectActivate)
customEventHooks.registerHandler("OnContainer", OnContainer)


