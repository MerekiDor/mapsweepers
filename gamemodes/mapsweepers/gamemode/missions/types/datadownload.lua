--[[
	Map Sweepers - Co-op NPC Shooter Gamemode for Garry's Mod by "Octantis Addons" (consisting of MerekiDor & JonahSoldier)
    Copyright (C) 2025-2026 MerekiDor

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

	See the full GNU GPL v3 in the LICENSE file.
	Contact E-Mail: merekidorian@gmail.com
--]]


jcms.missions.datadownload = {
	faction = "combine",
	pvpAllowed = false,

	generate = function(data, missionData)
		missionData.uploadsRequired = jcms.util_IsPVP() and 3 or 1
		missionData.uploadsCompleted = 0

		-- Defense phase {{{
			missionData.defenseOngoing = false
			missionData.defenseCompleted = false
			missionData.defenseAttempts = 0
			missionData.defenseProgress = 0
			missionData.lastPillarCount = 0
			missionData.totalIncome = 0
		-- }}}

		-- Finding preliminary area for the computer {{{
			-- // Area Weights {{{
				local weightedAreas = {}
				for i, area in ipairs(jcms.mapgen_MainZone()) do --Prioritise outdoor areas, ignore too small ones.
					weightedAreas[area] = math.max(#area:GetVisibleAreas(), 1)
					if area:GetSizeX() < 250 or area:GetSizeY() < 250 then
						weightedAreas[area] = nil
					elseif not jcms.mapgen_AreaFlat(area) then
						weightedAreas[area] = nil
					end
				end
			-- // }}}

			local computerArea = jcms.util_ChooseByWeight(weightedAreas)
			assert(computerArea, "Can't place down the main computer. This map sucks, find a better one")
		-- }}}

		-- // The Pillars {{{
			-- // Prioritise areas near the computer {{{
				--Outside the loop for optimisation
				local computerPos = computerArea:GetCenter()
				local defaultWeightedAreas = {}
				for i, area in ipairs(jcms.mapgen_MainZone()) do
					if area:GetSizeX() < 50 or area:GetSizeY() < 50 then
						defaultWeightedAreas[area] = nil
						continue
					end

					local dist = area:GetCenter():Distance(computerPos) 
					if dist > 350 then --Not too close/on-top of us
						defaultWeightedAreas[area] = 1 / math.sqrt(dist) --Close to the main computer
					end
				end
			-- // }}}

			-- // Generate Pillars {{{
				local pillarCount = math.ceil(2 * jcms.runprogress_GetDifficulty() * (2/3))
				local pillars = {}
				local pillarPositions = {} --Optimisation

				-- Note / TODO: We *could* make this like spreadprefabs & try to make them unable to see each-other.
				for i=1, pillarCount do --Generate pillars
					local weightedAreas = {}
					for i, area in ipairs(jcms.mapgen_MainZone()) do --Try to spread pillars out
						weightedAreas[area] = defaultWeightedAreas[area]
						if not weightedAreas[area] then continue end

						local centre = area:GetCenter()
						local closestDist = math.huge
		
						for i, pillarPos in ipairs(pillarPositions) do --Don't spawn too close to others.
							local dist = pillarPos:Distance(centre)
							closestDist = (closestDist < dist and closestDist) or dist
						end
						
						if not(closestDist == math.huge) then  
							weightedAreas[area] = weightedAreas[area] * math.sqrt( math.min(closestDist, 1250) ) --doesn't matter after 1250u
						end
					end

					local chosenArea = jcms.util_ChooseByWeight(weightedAreas)
					assert(chosenArea, "Can't place down any computer pillars. This map sucks, find a better one")

					local _, pillar = jcms.prefab_TryStamp("datadownload_pillar", chosenArea)
					table.insert(pillars, pillar)
					table.insert(pillarPositions, chosenArea:GetCenter()) 
				end
			-- // }}}

		-- // }}}

		-- // Actually placing down the computer and finalizing things {{{
			-- Weighing final areas {{{
				-- {{{ Calculate average pos of pillars (centre)
					local pillarAveragePos = Vector(0,0,0)
					for i, v in ipairs(pillarPositions) do
						pillarAveragePos:Add(v) 
					end
					pillarAveragePos:Div(pillarCount)
				-- // }}}

				-- // Calculate min/max distance from average position {{{
					local pillarDistFromAverageMin, pillarDistFromAverageMax = math.huge, 0 
					for i, v in ipairs(pillarPositions) do
						local dist = v:Distance(pillarAveragePos)
						pillarDistFromAverageMin = math.min(dist, pillarDistFromAverageMin)
						pillarDistFromAverageMax = math.max(dist, pillarDistFromAverageMax)
					end
				-- // }}}

				-- Reusing weightedAreas here for the final weights.
				for area, oldWeight in pairs(weightedAreas) do
					local areaCenter = area:GetCenter()
					if areaCenter:DistToSqr(pillarAveragePos) >= (pillarDistFromAverageMax + 100)^2 then --Really unlikely to spawn beyond the furthest pillar from the average.
						weightedAreas[area] = math.min(oldWeight/2, 0.1)
					else
						local closestDist
						for i, v in ipairs(pillarPositions) do
							local dist = v:Distance(areaCenter)
							if not closestDist or dist < closestDist then
								closestDist = dist
							end
						end

						if closestDist <= 350 then --Prevent computer from spawning directly next to a pillar.
							weightedAreas[area] = nil
						elseif closestDist <= pillarDistFromAverageMin then
							weightedAreas[area] = oldWeight/4
						elseif closestDist >= pillarDistFromAverageMax then
							weightedAreas[area] = oldWeight/8
						else
							local distanceFraction = (closestDist - pillarDistFromAverageMin)/(pillarDistFromAverageMax - pillarDistFromAverageMin)
							local parabolic = math.max(0, -4*distanceFraction^2 + 4*distanceFraction)
							weightedAreas[area] = oldWeight*0.8 + 2 + parabolic*20
						end
					end

					if weightedAreas[area] and weightedAreas[area] > 0 then
						local hasSkyAtAll, isUnderSky = jcms.util_GetSky(areaCenter)
						if not hasSkyAtAll then
							weightedAreas[area] = weightedAreas[area] / 5
						elseif not isUnderSky then
							weightedAreas[area] = weightedAreas[area] / 3
						end
					end
				end
			-- }}}

			-- // Placing the computer(s) {{{
				local computers = {}
				for i=1, (jcms.util_IsPVP() and 2 or 1) do
					local finalComputerArea = jcms.util_ChooseByWeight(weightedAreas) or computerArea
					if finalComputerArea == computerArea then
						jcms.printf("Data Download computerArea (preliminary) equals to finalComputerArea!")
					end

					local _, computer = jcms.prefab_TryStamp("datadownload_computer", finalComputerArea)

					computer:SetNWBool("jcms_terminal_locked", false)
					jcms.terminal_ToPurpose(computer)

					computer.jcms_datadownload_cost = jcms.util_IsPVP() and 1000 or 0
				
					function computer:jcms_terminal_Callback(cmd, data, ply)
						if tonumber(data) and not missionData.defenseOngoing and not missionData.defenseCompleted then
							local plyPvpTeam = ply:GetNWInt("jcms_pvpTeam", -1)
							missionData.defenseOngoing = true

							if missionData.defenseAttempts == 0 then
								missionData.defenseProgress = 0
							end
							
							missionData.defenseAttempts = missionData.defenseAttempts + 1

							for i, pillar in ipairs(missionData.pillars) do
								pillar:SetIsDisrupted(false)
								pillar:SetHealth( pillar:GetMaxHealth() )
								pillar:SetHealthFraction(1)
								pillar:SetNWInt("jcms_pvpTeam", plyPvpTeam)
							end

							self:EmitSound("ambient/alarms/klaxon1.wav", 150, 108, 1)
							util.ScreenShake(self:GetPos(), 3, 50, 1, 2048, true)

							for j, comp in ipairs(missionData.computers) do
								if comp.soundDownload then
									comp.soundDownload:Stop()
									comp.soundDownload = nil
								end
	
								comp.soundDownload = CreateSound(comp, "ambient/alarms/combine_bank_alarm_loop1.wav")
								comp.soundDownload:PlayEx(1, 107)
	
								if comp.soundHum then
									comp.soundHum:Stop()
									comp.soundHum = nil
								end
	
								comp.soundHum = CreateSound(comp, "ambient/machines/combine_terminal_loop1.wav")
								comp.soundHum:PlayEx(1, 107)

								comp:SetNWString("jcms_terminal_modeData", "upload")
								comp:SetNWInt("jcms_pvpTeam", plyPvpTeam)
							end

							local sameTeam, notSameTeam = {}, {}
							for j, otherPly in ipairs(jcms.GetAliveSweepers()) do
								if jcms.team_pvpSameTeam_optimised(plyPvpTeam, otherPly:GetNWInt("jcms_pvpTeam", -1)) then
									table.insert(sameTeam, ply)
								else
									table.insert(notSameTeam, ply)
								end
							end

							if #sameTeam > 0 then
								jcms.net_SendTip(sameTeam, true, "#jcms.datadownload_started", tonumber(missionData.defenseProgress) or 0)
							end

							if #notSameTeam > 0 then
								jcms.net_SendTip(notSameTeam, true, "#jcms.datadownload_started_enemy", tonumber(missionData.defenseProgress) or 0)
							end

							return true, "upload"
						end
					end

					computer.pillars = pillars

					table.insert(computers, computer)
				end
			-- // }}}

			-- // Setting Pillar Symbols {{{
				local function getSymbol(i, totalCount)
					if totalCount > 26 then
						local letter = string.char(65 + (i-1)%26)
						local loops = math.floor((i-1)/26)
						return letter..loops
					else
						local letter = string.char(65 + (i-1)%26)
						return letter
					end
				end

				for i, pillar in ipairs(pillars) do
					pillar:SetLabelSymbol( getSymbol(i, #pillars) )
					
					local health = 500 --TODO: We *could* make this reduce based on difficulty.
					pillar:SetMaxHealth(health)
					pillar:SetHealth(health)
				end
				

				missionData.computers = computers
				missionData.pillars = pillars
			-- // }}} 
		-- // }}}

		--Nothing relating to resource collection (i.e. mafia lockers, cash caches). Don't want people to spend ages searching.
		local allowedPrefabs = {
			["emplacement"] = true,
			["wall_charger"] = true,
			["gambling"] = true,
			["oil"] = true
		}
		
		local function weightOverride(name, ogWeight)
			return (allowedPrefabs[name] and ogWeight) or 0
		end

		jcms.mapgen_PlaceNaturals(jcms.mapgen_AdjustCountForMapSize(12), weightOverride)
		--jcms.mapgen_PlaceEncounters()
	end,

	tagEntities = function(director, missionData, tags)
		local tagsActive = missionData.phase > 0

		for i, computer in ipairs(missionData.computers) do
			if IsValid(computer) then
				tags[computer] = { 
					name = "#jcms.obj_datadownloadcomputer", 
					alwaysVisible = true,
					moving = false, 
					active = tagsActive, 
					landmarkIcon = "computer" }
			end
		end

		for i, pillar in ipairs(missionData.pillars) do
			if IsValid(pillar) then
				tags[pillar] = { 
					name = "^" .. pillar:GetLabelSymbol(),
					alwaysVisible = true,
					moving = false, 
					active = tagsActive, 
					locatorIgnore = true,
					type = pillar:GetIsDisrupted() and jcms.LOCATOR_WARNING or jcms.LOCATOR_GENERIC
				}
			end
		end
	end,

	getObjectives = function(missionData)
		local phase = 0 -- Evacuating

		local computerValid = false
		for i, computer in ipairs(missionData.computers) do
			if IsValid(computer) then
				computerValid = true
				if not missionData.computerWasLocated then
					for ply, knownTags in pairs(jcms.director.tags_perplayer) do
						if knownTags[computer] then
							missionData.computerWasLocated = true
							break
						end
					end
				end
			end
		end

		if computerValid then
			if missionData.defenseCompleted then
				phase = 0 -- Evac
			elseif missionData.defenseOngoing then
				phase = 2 -- Combat
			else
				phase = 1 -- Preparing for defense
			end
		end
		missionData.phase = phase

		if phase == 1 then
			local objectives = {}
			if jcms.util_IsPVP() then
				table.insert(objectives, { type = "completedownloads", completed = false, progress = missionData.uploadsCompleted, total = missionData.uploadsRequired })
			end

			table.insert(objectives, { type = "locatecomputer", completed = missionData.computerWasLocated })
			table.insert(objectives, { type = "prepfordefense" })
			table.insert(objectives, { type = "activatedownload" })

			return objectives
		elseif phase == 2 then
			local objectives = {}
			if jcms.util_IsPVP() then
				table.insert(objectives, { type = "completedownloads", completed = false, progress = missionData.uploadsCompleted, total = missionData.uploadsRequired })
			end

			table.insert(objectives, { type = "uploadingatspeed", format = { jcms.util_CashFormat(missionData.totalIncome) }, progress = missionData.defenseProgress*100, total = 100, percent = true })

			if #missionData.pillars <= 5 then
				for i, pillar in ipairs(missionData.pillars) do 
					if not IsValid(pillar) then continue end

					local isDisrupted = pillar:GetIsDisrupted()
					table.insert(objectives, { type = isDisrupted and "repairpillarx" or "defendpillarx", format = { pillar:GetLabelSymbol() } })
					table.insert(objectives, { type = "defendpillarx", style = 2, progress = math.ceil(pillar:Health() / pillar:GetMaxHealth() * 100), total = 100, completed = isDisrupted })
				end
			else
				local pillarCount = 0
				local disruptedCount = 0

				for i, pillar in ipairs(missionData.pillars) do 
					if not IsValid(pillar) then continue end
					pillarCount = pillarCount + 1
					if pillar:GetIsDisrupted() then
						disruptedCount = disruptedCount + 1
					end
				end

				table.insert(objectives, { type = "defendpillars", progress = pillarCount - disruptedCount, total = pillarCount })
				if disruptedCount > 0 then
					missionData.maxDisruptedCount = math.max(missionData.maxDisruptedCount or disruptedCount, disruptedCount)
					table.insert(objectives, { type = "repairpillars", progress = missionData.maxDisruptedCount - disruptedCount, total = missionData.maxDisruptedCount, completed = true })
				else
					missionData.maxDisruptedCount = nil
				end
			end

			table.insert(objectives, { type = "timeestimate", progress = missionData.timeEstimate, style = 1 })

			return objectives
		else
			missionData.evacuating = true
		
			if not IsValid(missionData.evacEnt) then
				missionData.evacEnt = jcms.mission_DropEvac(jcms.mission_PickEvacLocation(), 20)
			end
			
			return jcms.mission_GenerateEvacObjective()
		end
	end,

	think = function(d)
		local md = d.missionData
		md.timeEstimate = 0

		--Make sure people always have at least 1J so they can order a recall beacon (hacky way to get around 0-value call-ins being impossible).
		for i, ply in ipairs(team.GetPlayers(1)) do 
			if ply:GetNWInt("jcms_cash", -1) < 1 then
				jcms.giveCash(ply, 1)
			end
		end

		--No waves until we start the defense
		if md.phase ~= 2 and not md.evacuating then
			d.swarmNext = jcms.director_GetMissionTime() + 2
		end
		
		--Clean up invalid / destroyed pillars
		for i=#md.pillars, 1, -1 do
			local pillar = md.pillars[i]
			if not IsValid(pillar) then
				table.remove(md.pillars, i)
			end
		end

		local pillarsShouldBeActive = false
		local downloadSucceeded = false
		if md.defenseCompleted then
			md.defenseProgress = 1
			md.lastPillarCount = 0
			md.totalIncome = 0
		else
			if md.defenseOngoing then
				pillarsShouldBeActive = true

				--Swarm Accel
				if #d.npcs < 30 then 
					d.swarmNext = (d.swarmNext or jcms.director_GetMissionTime()) - 1
				end

				--NPCs Target Pillars
				for i, npc in ipairs(d.npcs) do
					if not IsValid(npc) or not npc.GetEnemy then continue end

					--Prioritise hunting pillars instead of players
					local enemy = npc:GetEnemy()
					local shouldReassign = true
					if IsValid(enemy) and enemy:IsPlayer() and CurTime() - npc:GetEnemyLastTimeSeen() < 10 then
						shouldReassign = false
					end

					if shouldReassign then
						--Find Closest pillar
						local npcPos = npc:GetPos()
						local nearest = NULL
						local nearestDist = math.huge
						for i, pillar in ipairs(md.pillars) do 
							local dist = pillar:GetPos():DistToSqr(npcPos)
							if dist < nearestDist then
								nearest = pillar
								nearestDist = dist
							end
						end

						--Attack it
						if IsValid(nearest) then
							local choice = nearest.bullseyes[math.random(#nearest.bullseyes)]
							npc:SetEnemy(choice)
							npc:UpdateEnemyMemory(choice, choice:GetPos())
						end
					end
				end

				--Count active Pillars 
				local totalPillars = 0
				local activePillars = 0
				for i, pillar in ipairs(md.pillars) do 
					totalPillars = totalPillars + 1
					if not pillar:GetIsDisrupted() then 
						activePillars = activePillars + 1 
					end
				end

				--Give cash for each active pillar
				local totalIncome = activePillars * 10
				for i, ply in player.Iterator() do 
					jcms.giveCash(ply, totalIncome)
				end

				md.totalIncome = totalIncome
				local totalIncomeFormatted = jcms.util_CashFormat(totalIncome)

				--Are we ongoing or not
				if activePillars > 0 then
					--4 Minutes at max power, scaling with difficulty
					local pillarFraction = math.Clamp(activePillars / totalPillars, 0, 1)

					if md.lastPillarCount ~= 0 and md.lastPillarCount ~= activePillars then
						if activePillars < md.lastPillarCount then
							-- Lost power
							jcms.net_SendTip("all", true, "#jcms.datadownload_destroyed", pillarFraction, totalIncomeFormatted)
						else
							-- Gained power (pillars repaired)
							if activePillars >= totalPillars then
								jcms.net_SendTip("all", true, "#jcms.datadownload_allrepaired", pillarFraction, totalIncomeFormatted)
							else
								jcms.net_SendTip("all", true, "#jcms.datadownload_repaired", pillarFraction, totalIncomeFormatted)
							end
						end
					end
					
					md.lastPillarCount = activePillars

					local scalar = (#d.npcs > 15) and jcms.runprogress_GetDifficulty() or 0.5
					local progressPower = 1/((60*4) * (scalar^(3/4)) ) * (jcms.util_IsPVP() and 3.25 or 1)

					md.defenseProgress = math.Clamp(md.defenseProgress + progressPower, 0, 1)
					md.timeEstimate = math.ceil( (1 - md.defenseProgress) / progressPower )

					-- Completed the defense
					if md.defenseProgress >= 1 then
						md.uploadsCompleted = md.uploadsCompleted + 1 

						md.defenseOngoing = false
						pillarsShouldBeActive = false
						if md.uploadsCompleted >= md.uploadsRequired then
							md.defenseCompleted = true
							downloadSucceeded = true
						else
							for i, pillar in ipairs(md.pillars) do
								pillar:SetIsDisrupted(false)
								pillar:SetHealth( pillar:GetMaxHealth() )
								pillar:SetHealthFraction(1)
							end
							md.defenseProgress = 0
							downloadSucceeded = true
						end

						for i, computer in ipairs(md.computers) do
							if IsValid(computer) and computer.soundHum then
								computer.soundHum:Stop()
								computer.soundHum = nil
							end
						end
					end
				else
					pillarsShouldBeActive = false

					for i, pillar in ipairs(md.pillars) do
						pillar:SetIsDisrupted(false)
						pillar:SetHealth( pillar:GetMaxHealth() )
						pillar:SetHealthFraction(1)
					end

					md.defenseOngoing = false

					for i, computer in ipairs(md.computers) do
						if IsValid(computer) and computer.soundHum then
							computer.soundHum:Stop()
							computer.soundHum = nil
						end
					end
				end
			else
				md.lastPillarCount = 0
				md.totalIncome = 0
			end

			for i, pillar in ipairs(md.pillars) do 
				pillar:SetIsActive(pillarsShouldBeActive) 
				pillar:SetChargeFraction(md.defenseProgress)
			end
		end
		
		local pvpRespawnGiven = false
		table.Shuffle(md.computers)
		for i, computer in ipairs(md.computers) do
			if IsValid(computer) then
				if computer:GetNWString("jcms_terminal_modeData") == "upload" and not md.defenseOngoing then
					local pvpTeam = computer:GetNWInt("jcms_pvpTeam", -1)

					-- Resetting
					if md.defenseProgress < 1 then
						if not(downloadSucceeded) then
							local sameTeam, notSameTeam = {}, {}
							for j, otherPly in ipairs(jcms.GetAliveSweepers()) do
								if jcms.team_pvpSameTeam_optimised(pvpTeam, otherPly:GetNWInt("jcms_pvpTeam", -1)) then
									table.insert(sameTeam, ply)
								else
									table.insert(notSameTeam, ply)
								end
							end

							if #sameTeam > 0 then
								jcms.net_SendTip(sameTeam, true, "#jcms.datadownload_failed", tonumber(md.defenseProgress) or 0)
							end

							if #notSameTeam > 0 then
								jcms.net_SendTip(notSameTeam, true, "#jcms.datadownload_failed_enemy", tonumber(md.defenseProgress) or 0)
							end

							if jcms.util_IsPVP() then --Resets in PvP
								md.defenseProgress = 0
							end
						else
							--TODO: Datadownload succeeded tip.
						end

						computer:SetNWString("jcms_terminal_modeData", tostring(computer.jcms_datadownload_cost))
					else
						computer:SetNWString("jcms_terminal_modeData", "done")
					end
					
					if not(pvpTeam == -1) and downloadSucceeded and not pvpRespawnGiven then
						jcms.director_PvpObjectiveCompletedTeam(pvpTeam, computer:GetPos(), true)
						pvpRespawnGiven = true 
					end
					computer:SetNWInt("jcms_pvpTeam", -1)

					if computer.soundDownload then
						computer.soundDownload:Stop()
						computer.soundDownload = nil
					end
				end
			end
		end
	end,
	
	calcBountyMul = function(d, missionData) --No bounty until evac
		return missionData.evacuating and 1 or 0 --((missionData.phase == 2 and not missionData.evacuating) and 0) or 1
	end,
	
	getRecallPoint = function(d, missionData)
		local comp =  missionData.computers[1]
		return comp:GetPos() + comp:GetAngles():Forward() * 35
	end,
	
	swarmCalcCost = function(director, baseCost)
		local missionData = director.missionData
		
		if missionData.phase == 2 or missionData.evacuating then
			return baseCost + 4
		end

		return 0
	end,
	
	npcTypeQueueCheck = function(d, swarmCost, dangerCap, npcType, npcData, basePassesCheck)
		local weightMul

		-- More hunters, less BS enemies during the defense
		weightMul = ({
			["combine_metrocop"] = 1.66,
			["combine_hunter"] = 2.5,
			["combine_suppressor"] = 0.5,
			["combine_sniper"] = 0.75,
			["combine_gunship"] = 0.5 --This isn't going to do anything because boss-spawns are guaranteed and combine only have one type - J
		})[npcType]

		if weightMul then
			return basePassesCheck, jcms.npc_GetScaledSwarmWeight(npcData) * weightMul
		else
			return basePassesCheck
		end
	end,
	
	orders = { --mission-specific call-ins
		dd_rb = {
			category = jcms.SPAWNCAT_MISSION,
			cost = 1,
			cooldown = 90,
			slotPos = 1,
			argparser = "respawn_beacon", 

			func = function(ply, pos, angle)
				local beacon = ents.Create("jcms_recallbeacon")
				beacon:SetPos(pos)
				beacon:SetAngles(angle)
				beacon:Spawn()
				
				local ed = EffectData()
				ed:SetColor(jcms.util_GetColorIntegerPvP(ply))
				ed:SetFlags(0)
				ed:SetEntity(beacon)
				util.Effect("jcms_spawneffect", ed)
				
				beacon:EmitSound("npc/roller/blade_cut.wav", 75, 100)

				if CPPI then
					beacon:CPPISetOwner( game.GetWorld() )
				end
			end
		}
	}
}
