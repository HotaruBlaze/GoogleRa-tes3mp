--[[
=======================================
| Author: Гильгамеш // Gilgamesh      |
| GitHub: https://github.com/GoogleRa |
=================================================================================================================
| Description: This script implements dice rolls with flight animation and outputting a message to the chat.    |
| Описание: Этот скрипт реализует броски кубиков с анимацией полета и выводом сообщения в чат.                  |
| Installation:                                                                                                 |
|   1. Download "dices.lua";                                                                                    |
|   4. Place this script in the path:                                                                           |
|      TES3MP\server\scripts\custom\dices.lua                                                                   |
|   3. Open "customScripts.lua" and add there the following line:                                               |
|      require("custom.dices")                                                                                  |
|   4. Save "customScripts.lua" and launch the server.                                                          |
|                                                                                                               |
|   P.S.: You need to add "Tamriel_Data.esm" in the OpenMW Launcher.                                            |
===================================================================================================------========
]]

-- Настройки // Settings
local animationDuration = 0.8 -- длительность анимации в секундах // animation duration in seconds
local animationSteps = 50 -- количество шагов анимации // number of animation steps
local maxStackThrow = 3 -- максимальное количество кубиков для индивидуального броска // maximum number of dice for an individual roll
local minDistance = 5 -- минимальное расстояние между кубиками // minimum distance between dices
local maxDistance = 10 -- максимальное расстояние между кубиками // maximum distance between dices
local spinSpeed  = 70 -- скорость вращения кубиков // rotation speed dices
local height = 50 -- максимальная высота подъема кубиков // maximum lift height dices

local throwCube = {}
local playerThrows = {}

local offRight
local offUp
local offForward

local function getRace(pid)
	local race = tes3mp.GetRace(pid) or ""
	local scale = tes3mp.GetScale(pid) or 1
	if race == "Dark Elf" or race == "breton" or race == "redguard" then
		offRight = 15
		offUp = 70
		offForward = 0
	elseif race == "argonian" then
		offRight = 18
		offUp = 73
		offForward = 5
	elseif race == "imperial" then
		offRight = 18
		offUp = 70
		offForward = 0
	elseif race == "nord" then
		offRight = 18
		offUp = 71
		offForward = 0
	elseif race == "high elf" then
		offRight = 15
		offUp = 76
		offForward = 0
	elseif race == "wood elf" then
		offRight = 13
		offUp = 63
		offForward = 0
	elseif race == "khajiit" then
		offRight = 16
		offUp = 73
		offForward = 3
	elseif race == "orc" then
		offRight = 19
		offUp = 73
		offForward = 0
	else
		tes3mp.SendMessage(pid, color.red .. "[ОШИБКА]:" .. color.White .. " Ваша расса не определена! Сообщите об этом создателю сервера.\n", false)
		offRight = 0
		offUp = 0
		offForward = 0
	end
	
	offRight = offRight * scale
	offUp = offUp * scale
	offForward = offForward * scale
end

local function getRandomCubeRotation()
    local rotations = {
        {rotX = math.rad(0), rotY = math.rad(0), rotZ = math.rad(0)},
        {rotX = math.rad(90), rotY = math.rad(0), rotZ = math.rad(0)},
        {rotX = math.rad(0), rotY = math.rad(90), rotZ = math.rad(0)},
        {rotX = math.rad(0), rotY = math.rad(-90), rotZ = math.rad(0)},
        {rotX = math.rad(0), rotY = math.rad(180), rotZ = math.rad(0)},
        {rotX = math.rad(-90), rotY = math.rad(0), rotZ = math.rad(0)}
    }
    return rotations[math.random(1, 6)]
end

function throw(uniqueIndex)
    if not throwCube[uniqueIndex] then return end

    local data = throwCube[uniqueIndex]
    local object = data.object
    local cellDescription = data.cellDescription
    local startPos = data.playerLocation
    local endPos = data.cubeLocation
    local currentStep = data.currentStep or 0
    local pid = data.pid

    if currentStep > animationSteps then
        local finalNumber = 1
        if data.finalRotation then
            local rotX = math.deg(data.finalRotation.rotX) % 360
            local rotY = math.deg(data.finalRotation.rotY) % 360
            
            if rotX == 0 and rotY == 0 then finalNumber = 5
            elseif rotX == 90 then finalNumber = 6
            elseif rotY == 90 then finalNumber = 2
            elseif rotY == 270 then finalNumber = 4
            elseif rotY == 180 then finalNumber = 1
            elseif rotX == 270 then finalNumber = 3
            end
        end

        if not playerThrows[pid] then
            playerThrows[pid] = {count = 0, cubes = {}, total = 0}
        end

        playerThrows[pid].count = playerThrows[pid].count + 1
        playerThrows[pid].cubes[uniqueIndex] = finalNumber
        playerThrows[pid].total = playerThrows[pid].total + finalNumber

        local expectedCount = data.throwCount or 1
        if playerThrows[pid].count >= expectedCount then
            local playerName = tes3mp.GetName(pid)
            local message

            if expectedCount == 1 then
                message = color.White .. "Игрок " .. color.Green .. playerName .. color.White .. 
                         " бросает " .. color.Yellow .. "1 " .. color.White .. "кубик и выпадает " .. color.Yellow .. finalNumber .. color.White .. "!\n"
            else
                local cubesText = ""
                for cubeIndex, number in pairs(playerThrows[pid].cubes) do
                    cubesText = cubesText .. color.Yellow .. number .. color.White .. ", "
                end
                cubesText = cubesText:sub(1, -3)
                
                message = color.White .. "Игрок " .. color.Green .. playerName .. color.White .. 
                         " бросает " .. color.Yellow .. expectedCount .. color.White .. " кубика и выпадает: " .. 
                         cubesText .. " (сумма: " .. color.Yellow .. playerThrows[pid].total .. color.White .. ")!\n"
            end

            tes3mp.SendMessage(pid, message, true)
            playerThrows[pid] = nil
        end

        throwCube[uniqueIndex] = nil
        return
    end

    local progress = currentStep / animationSteps
    local easeProgress = progress * progress

    local interpX = startPos.posX + (endPos.posX - startPos.posX) * easeProgress
    local interpY = startPos.posY + (endPos.posY - startPos.posY) * easeProgress
    local interpZ = startPos.posZ + (endPos.posZ - startPos.posZ) * easeProgress
    local parabola = 4 * height * (easeProgress - easeProgress * easeProgress)
    local finalZ = interpZ + parabola
    local rotX, rotY, rotZ

    if progress < 0.8 then
        rotX = startPos.rotX + math.rad(spinSpeed * 360 * progress)
        rotY = startPos.rotY + math.rad(spinSpeed * 360 * progress)
        rotZ = startPos.rotZ + math.rad(spinSpeed * 360 * progress)
    else
        local finalRot = data.finalRotation or getRandomCubeRotation()
        local transitionProgress = (progress - 0.8) / 0.2
        data.finalRotation = finalRot
        rotX = startPos.rotX + (finalRot.rotX - startPos.rotX) * transitionProgress
        rotY = startPos.rotY + (finalRot.rotY - startPos.rotY) * transitionProgress
        rotZ = startPos.rotZ + (finalRot.rotZ - startPos.rotZ) * transitionProgress
    end

    if LoadedCells[cellDescription] then
        tes3mp.ClearObjectList()
        tes3mp.SetObjectListPid(pid)
        tes3mp.SetObjectListCell(cellDescription)
        local splitIndex = uniqueIndex:split("-")
        tes3mp.SetObjectRefNum(tonumber(splitIndex[1]))
        tes3mp.SetObjectMpNum(tonumber(splitIndex[2]))
        tes3mp.SetObjectPosition(interpX, interpY, finalZ)
        tes3mp.SetObjectRotation(rotX, rotY, rotZ)
        tes3mp.AddObject()
        tes3mp.SendObjectMove(true)
        tes3mp.SendObjectRotate(true)
    else
        throwCube[uniqueIndex] = nil
        return
    end

    data.currentStep = currentStep + 1
    throwCube[uniqueIndex] = data

    local frameDuration = (animationDuration / animationSteps)
    tes3mp.StartTimer(tes3mp.CreateTimerEx("throw", time.seconds(frameDuration), "s", uniqueIndex))
end

local function OnObjectPlace(eventStatus, pid, cellDescription, objects)
    for _, object in pairs(objects) do
        if object.refId and object.refId == "t_com_die_01" then
            
            if throwCube[object.uniqueIndex] then
                return
            end

            local rotZ = tes3mp.GetRotZ(pid)
            local fwdX, fwdY = math.sin(rotZ), math.cos(rotZ)
            local rightX, rightY = math.cos(rotZ), -math.sin(rotZ)
            local px, py, pz = tes3mp.GetPosX(pid), tes3mp.GetPosY(pid), tes3mp.GetPosZ(pid)
			
			getRace(pid)
			
            local playerLocation = {
				posX = px + fwdX * offForward + rightX * offRight,
				posY = py + fwdY * offForward + rightY * offRight,
                posZ = pz + offUp,
                rotX = object.location.rotX,
                rotY = object.location.rotY,
                rotZ = rotZ
            }

            local cubeLocation = {
                posX = object.location.posX,
                posY = object.location.posY,
                posZ = object.location.posZ,
                rotX = object.location.rotX,
                rotY = object.location.rotY,
                rotZ = object.location.rotZ
            }

            if object.count > 1 and object.count <= maxStackThrow then
                logicHandler.DeleteObjectForEveryone(cellDescription, object.uniqueIndex)

                local createdCubes = {}
                for i = 1, object.count do
                    local angle = math.random() * 2 * math.pi
                    local distance = minDistance + math.random() * (maxDistance - minDistance)

                    local individualCubeLocation = {
                        posX = cubeLocation.posX + (math.cos(angle) * distance),
                        posY = cubeLocation.posY + (math.sin(angle) * distance),
                        posZ = cubeLocation.posZ,
                        rotX = cubeLocation.rotX,
                        rotY = cubeLocation.rotY,
                        rotZ = cubeLocation.rotZ
                    }

                    local objectData = {refId = object.refId, charge = -1, enchantmentCharge = -1, count = 1, soul = ""}
                    local uniqueIndex = logicHandler.CreateObjectAtLocation(cellDescription, playerLocation, objectData, "place")

                    if uniqueIndex then
                        throwCube[uniqueIndex] = {
                            object = {refId = object.refId, count = 1, uniqueIndex = uniqueIndex},
                            cellDescription = cellDescription, 
                            cubeLocation = individualCubeLocation, 
                            playerLocation = playerLocation, 
                            currentStep = 0,
                            pid = pid,
                            finalRotation = nil,
							throwCount = object.count
                        }
                    end
                end

                for uniqueIndex, _ in pairs(throwCube) do
                    if throwCube[uniqueIndex].pid == pid then
                        tes3mp.StartTimer(tes3mp.CreateTimerEx("throw", time.seconds(0.2), "s", uniqueIndex))
                    end
                end
                
            else
                tes3mp.ClearObjectList()
                tes3mp.SetObjectListPid(pid)
                tes3mp.SetObjectListCell(cellDescription)
                local splitIndex = object.uniqueIndex:split("-")
                tes3mp.SetObjectRefNum(tonumber(splitIndex[1]))
                tes3mp.SetObjectMpNum(tonumber(splitIndex[2]))
                tes3mp.SetObjectPosition(playerLocation.posX, playerLocation.posY, playerLocation.posZ)
                tes3mp.SetObjectRotation(playerLocation.rotX, playerLocation.rotY, playerLocation.rotZ)
                tes3mp.AddObject()
                tes3mp.SendObjectMove(true)
                tes3mp.SendObjectRotate(true)

                throwCube[object.uniqueIndex] = {
                    object = object, 
                    cellDescription = cellDescription, 
                    cubeLocation = cubeLocation, 
                    playerLocation = playerLocation, 
                    currentStep = 0,
                    pid = pid,
                    finalRotation = nil,
					throwCount = 1
                }

                tes3mp.StartTimer(tes3mp.CreateTimerEx("throw", time.seconds(0.2), "s", object.uniqueIndex))
            end
        end
    end
end

customEventHooks.registerHandler("OnObjectPlace", OnObjectPlace)

