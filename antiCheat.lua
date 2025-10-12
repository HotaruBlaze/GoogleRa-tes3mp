----------------------------------------
------   Anticheat by Гильгамеш   ------
------        Versin: 0.01        ------
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

local function punishment(pid)
	if config.globalMessage then
		if config.kickPlayer and config.language == "Ru" then
			tes3mp.SendMessage(pid, color.Red .. "[Античит]:" .. vanillaSand .. " Игрок " .. Players[pid].accountName .. " был кикнут за использование читов.\n", true)
		elseif config.kickPlayer and config.language == "En" then
			tes3mp.SendMessage(pid, color.Red .. "[Anticheat]:" .. vanillaSand .. " Player " .. Players[pid].accountName .. " has been kicked for using cheats.\n", true)
		elseif config.banPlayer and config.language == "Ru" then
			tes3mp.SendMessage(pid, color.Red .. "[Античит]:" .. vanillaSand .. " Игрок " .. Players[pid].accountName .. " был забанен за использование читов.\n", true)
		elseif config.banPlayer and config.language == "En" then
			tes3mp.SendMessage(pid, color.Red .. "[Anticheat]:" .. vanillaSand .. " Player " .. Players[pid].accountName .. " has been banned for using cheats.\n", true)
		elseif not config.kickPlayer and not config.banPlayer and config.language == "Ru" then
			tes3mp.SendMessage(pid, color.Red .. "[Античит]:" .. vanillaSand .. " Игрок " .. Players[pid].accountName .. " был замечен за попыткой использования читов.\n", true)
		elseif not config.kickPlayer and not config.banPlayer and config.language == "En" then
			tes3mp.SendMessage(pid, color.Red .. "[Anticheat]:" .. vanillaSand .. " Player " .. Players[pid].accountName .. " has been caught trying to use cheats.\n", true)
		end
	end
	if config.logMessage and config.kickPlayer then
		tes3mp.LogMessage(1, "[Anticheat]: Player " .. Players[pid].accountName .. " has been kicked for using cheats")
	elseif config.logMessage and config.banPlayer then
		tes3mp.LogMessage(1, "[Anticheat]: Player " .. Players[pid].accountName .. " has been banned for using cheats")
	elseif not config.kickPlayer and not config.banPlayer then
		tes3mp.LogMessage(1, "[Anticheat]: Player " .. Players[pid].accountName .. " has been caught trying to use cheats")
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
        for _, item in pairs(Players[pid].data.inventory) do
            if item then
                if isGold and string.match(item.refId, "^gold_") then
                    totalCountInInventory = totalCountInInventory + item.count
					originalItem = {refId = item.refId, count = item.count, charge = item.charge, enchantmentCharge = item.enchantmentCharge, soul = item.soul}
                elseif item.refId == object.refId then
                    local chargeMatch = (item.charge == object.charge) or (item.charge == -1 and object.charge == -1)
                    local enchantMatch = (item.enchantmentCharge == object.enchantmentCharge) or (item.enchantmentCharge == -1 and object.enchantmentCharge == -1)
                    if chargeMatch and enchantMatch then
                        totalCountInInventory = totalCountInInventory + item.count
						originalItem = {refId = item.refId, count = item.count, charge = item.charge, enchantmentCharge = item.enchantmentCharge, soul = item.soul}
                    end
                end
            end
        end
		if originalItem and (isGold and object.goldValue or object.count) > totalCountInInventory then
			if isGold then
				object.goldValue = originalItem.count
			else
				object.count = originalItem.count
			end
			local inventory = Players[pid].data.inventory
			for i = #inventory, 1, -1 do
				local item = inventory[i]
				if item and item.refId == originalItem.refId then
					table.remove(inventory, i)
					Players[pid]:LoadItemChanges({originalItem}, enumerations.inventory.REMOVE)
					break
				end
			end
			Players[pid]:Save()
			Players[pid]:LoadInventory()
			Players[pid]:LoadEquipment()

			punishment(pid)
		end
    end
end

-- Функция сравнения предметов для бартера и контейнера
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
		local soldItems = {} -- Таблица проданных предметов НПС
		local goldCheat = false
		local processedBefore = {} -- Отслеживаем обработанные предметы из "ДО"

		for i, itemBefore in ipairs(playerData[pid].npcInventoryBefore) do
			if itemBefore and itemBefore.refId ~= "gold_001" and not processedBefore[i] then
				local totalCountBefore = 0
				local totalCountAfter = 0
				-- Считаем общее количество предметов "ДО"
				for k, item in ipairs(playerData[pid].npcInventoryBefore) do
					if item and compareItemsExceptCount(itemBefore, item) then
						totalCountBefore = totalCountBefore + item.count
						processedBefore[k] = true -- Обработанные
					end
				end

				-- Считаем общее количество предметов "ПОСЛЕ"
				for _, itemAfter in ipairs(npcInventory) do
					if itemAfter and compareItemsExceptCount(itemBefore, itemAfter) then
						totalCountAfter = totalCountAfter + itemAfter.count
					end
				end

				-- Идентифицируем проданные предметы по увеличению
				local countDifference = totalCountAfter - totalCountBefore

				if countDifference > 0 then
					table.insert(soldItems, {refId = itemBefore.refId, count = countDifference, charge = itemBefore.charge or -1, enchantmentCharge = itemBefore.enchantmentCharge or -1})
				end
			end
		end

		-- Поиск новых предметов у НПС, которых не было "ДО"
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

		-- Расчет золота
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
		-- Проверка игрока на валидность
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

				-- Синхранизация откатанного НПС
				for pid, player in pairs(Players) do
					if player:IsLoggedIn() and player.data.location.cell == cellDescription then
						LoadedCells[cellDescription]:LoadActorPackets(pid, LoadedCells[cellDescription].data.objectData, {playerData[pid].uniqueIndex})
					end
				end

				punishment(pid)
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
	-- Останавливаем таймер для последовательного перезапуска
	if playerData[pid] and playerData[pid].positionTimer then
        tes3mp.StopTimer(playerData[pid].positionTimer)
	else
		return -- Для безопасности
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

					-- Синронизация таблиц при НЕликвидкой выкладке
					for otherPid, otherData in pairs(playerData) do
						if playerData[otherPid].uniqueIndex == playerData[pid].uniqueIndex then
							LoadedCells[cellDescription].data.objectData[playerData[otherPid].uniqueIndex].inventory = playerData[pid].containerBefore
						end
					end

					punishment(pid)
				else
					-- Синронизация таблиц при ликвидкой выкладке
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
