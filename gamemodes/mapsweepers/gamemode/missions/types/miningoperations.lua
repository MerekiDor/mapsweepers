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

jcms.missions.miningoperations = {
	faction = "antlion",
	pvpAllowed = false,
	
	generate = function(data, missionData)
		--Place refineries / Difficulty calculations
		local pvpMode = jcms.util_IsPVP()

		local refineries_main, refineries_main_areas = jcms.mapgen_SpreadPrefabs("refinery_main", pvpMode and 2 or 1, 250, true)
		local refineries_secondary, refineries_secondary_areas = jcms.mapgen_SpreadPrefabs("refinery_secondary", jcms.mapgen_AdjustCountForMapSize(3), 180, false)

		missionData.refineries_main = refineries_main
		missionData.refineries_secondary = refineries_secondary

		local diffMult = jcms.runprogress_GetDifficulty() ^ (1/2)
		missionData.totalToRefine = math.ceil((jcms.util_IsPVP() and 900 or 1750) * diffMult)

		--Pvp Mode
		if pvpMode then
			refineries_main[1]:SetNWInt("jcms_pvpTeam", 1)

			refineries_main[2]:SetMaterial("models/jcms/mafia_orerefinery")
			refineries_main[2]:SetNWInt("jcms_pvpTeam", 2)

			local function onRefineMain(ref, ore, miner, bringer, obtain)
				ref.jcms_pvpOreAccumulator = (ref.jcms_pvpOreAccumulator or 0) + obtain

				if ref.jcms_pvpOreAccumulator > missionData.totalToRefine/3 then
					ref.jcms_pvpOreAccumulator = 0
					jcms.director_PvpObjectiveCompletedTeam(ref:GetNWInt("jcms_pvpTeam", -1), ref:GetPos(), true)
				end
			end

			for i, ref in ipairs(refineries_main) do
				ref.OnRefine = onRefineMain
			end
		end

		do
			local function onRefineSecondary(ref, ore, miner, bringer, obtain)
				if not jcms.director_IsSuddenDeath() then
					if miner ~= bringer then
						local half = math.ceil(obtain/2)
						jcms.giveCash(miner, half)
						jcms.giveCash(bringer, half)
					else
						jcms.giveCash(miner, obtain)
					end
				end
			end
			
			for i, ref in ipairs(refineries_secondary) do
				ref.OnRefine = onRefineSecondary
			end
		end

		--Points of interest to avoid for the spreadprefabs function
		local avoidAreas = refineries_main_areas
		table.Add(avoidAreas, refineries_secondary_areas)

		local areaMult, volumeMult, densityMult, avgAreaMult, spanMult = jcms.mapgen_GetMapSizeMultiplier()
		local sizeScaling = math.sqrt(spanMult)

		local mainZoneSeeds = 7
		local unrestrictedSeeds = 4
		local totalOres = 100

		-- // Plant "Seed" ore veins {{{
			local seedOres, seedOreAreas = jcms.mapgen_SpreadPrefabs("miningops_orevein", mainZoneSeeds, 200, true, avoidAreas)

			table.Add(avoidAreas, seedOreAreas)
			local seedOresUnrestricted, seedOreAreasUnrestricted = jcms.mapgen_SpreadPrefabs("miningops_orevein", unrestrictedSeeds, 200, true, avoidAreas)

			table.Add(seedOres, seedOresUnrestricted)
			table.Add(seedOreAreas, seedOreAreasUnrestricted)
		-- // }}}

		-- // Calculate weights {{{
			local oreVectors = {} 
			for i, ore in ipairs(seedOres) do
				table.insert(oreVectors, ore:WorldSpaceCenter())
			end

			local oreAreaWeights = {}
			for i, area in ipairs(jcms.mapdata.validAreas) do
				oreAreaWeights[area] = math.sqrt(area:GetSizeX() * area:GetSizeY())

				local areaCentre = area:GetCenter()

				local closestDist = math.huge
				for i, otherVec in ipairs(oreVectors) do
					local dist = areaCentre:Distance( otherVec )
					closestDist = (closestDist < dist and closestDist) or dist
				end

				if not(closestDist == math.huge) then  
					oreAreaWeights[area] = oreAreaWeights[area] / closestDist
				end
			end
		-- // }}}

		-- // Place Remaining Ores {{{
			local spawned = mainZoneSeeds + unrestrictedSeeds
			local allOres = {}

			for i=1, totalOres do 
				--local wallspots = jcms.prefab_GetWallSpotsFromArea(area, 48, 500)
				--TODO: Try to place us on walls first, stamp on area otherwise.

				local area = jcms.util_ChooseByWeight(oreAreaWeights)
				oreAreaWeights[area] = oreAreaWeights[area] * 0.00000001

				local succeeded, ore = jcms.prefab_TryStamp("miningops_orevein", area)

				if succeeded then
					spawned = spawned + 1
					table.insert(allOres, ore)
				end
			end
		-- // }}}


		-- // Set Types {{{
			local refineryVectors = {}
			for i, ref in ipairs(refineries_main) do
				local pos = ref:WorldSpaceCenter()
				table.insert(refineryVectors, pos)
			end

			table.Add(allOres, seedOres)
			for i, ore in ipairs(allOres) do
				local orePos = ore:WorldSpaceCenter()
				-- // Closest POI {{{
					local closestDist = math.huge
					for i, refVec in ipairs(refineryVectors) do
						local dist = orePos:Distance( refVec )
						closestDist = (closestDist < dist and closestDist) or dist
					end
					if closestDist == math.huge then closestDist = 0 end
				-- // }}}

				// Calculate Weights {{{
					local validOres = {}
					for k, oreData in pairs(jcms.oreTypes) do
						validOres[k] = oreData.weight or 1

						--Probably not optimal but my brain isn't working right now. 
						local proxMin, proxMax = sizeScaling * oreData.proxMin, sizeScaling * oreData.proxMax
						if closestDist < proxMin then
							validOres[k] = validOres[k] / math.sqrt(proxMin - closestDist)
						elseif closestDist > proxMax then
							validOres[k] = validOres[k] / math.sqrt(closestDist - proxMax)
						end
					end
				-- // }}}
				
				ore:SetOreType(jcms.util_ChooseByWeight(validOres))
			end
		-- }}}
		
		missionData.totalOres = spawned
		missionData.oreProgress = 0

		--Naturals
		jcms.mapgen_PlaceNaturals( jcms.mapgen_AdjustCountForMapSize(10) )
		jcms.mapgen_PlaceEncounters()
	end,
	
	tagEntities = function(director, missionData, tags)
		for i, refinery  in ipairs(missionData.refineries_main) do 
			if IsValid(refinery) then
				tags[refinery] = { name = "#jcms.refinery", moving = false, active = not missionData.evacuating }
			end
		end

		for i, ref in ipairs(missionData.refineries_secondary) do
			if IsValid(ref) then
				tags[ref] = { name = "#jcms.refinery_secondary", moving = false, active = not missionData.evacuating, locatorIgnore = true }
			end
		end
	end,

	getObjectives = function(missionData)
		local totalValid = 0
		local totalComplete = 0
		for i, refinery in ipairs(missionData.refineries_main) do
			if IsValid(refinery) then
				totalValid = totalValid + 1

				if refinery:GetValueInside() >= missionData.totalToRefine then
					totalComplete = totalComplete + 1
				end
			end
		end

		if totalValid > 0 and totalComplete == 0 then --totalComplete == 0 means pvp mode will start nuking as soon as the first refinery is finished.
			local objectives =  {
				{ type = "jantlion" },
				{ type = "mineore" },
				{ type = "bringore" },
			}

			local thresholds = {
				0.25,
				0.5,
				0.75,
				0.9
			}

			for i, refinery in ipairs(missionData.refineries_main) do
				if not IsValid(refinery) then continue end

				local valueInside = refinery:GetValueInside()
				local valueTotal = missionData.totalToRefine
				local fraction = math.Clamp(valueInside / valueTotal, 0, 1)

				local passedThreshold = false
				local lastFrac = refinery.lastRefinedFraction or 0
				for j, threshold in ipairs(thresholds) do
					if (fraction >= threshold) and (threshold > lastFrac) then
						refinery.lastRefinedFraction = threshold
						passedThreshold = true
					end
				end

				if passedThreshold then
					local refineryTeam = refinery:GetNWInt("jcms_pvpTeam", -1)
					
					local sameTeam, notSameTeam = {}, {}
					for j, ply in ipairs(jcms.GetAliveSweepers()) do
						if jcms.team_pvpSameTeam_optimised(refineryTeam, ply:GetNWInt("jcms_pvpTeam", -1)) then
							table.insert(sameTeam, ply)
						else
							table.insert(notSameTeam, ply)
						end
					end

					if #sameTeam > 0 then
						jcms.net_SendTip(sameTeam, true, "#jcms.miningoperations_completion", fraction)
					end

					if #notSameTeam > 0 then
						jcms.net_SendTip(notSameTeam, true, "#jcms.miningoperations_completion_enemy", fraction)
					end
				end
				
				table.insert(objectives, 
					{ type = "refineore", progress = valueInside, total = valueTotal, format = { valueTotal } }
				)
			end

			return objectives
		else
			missionData.evacuating = true
		
			if not IsValid(missionData.evacEnt) then
				missionData.evacEnt = jcms.mission_DropEvac(jcms.mission_PickEvacLocation())
			end
			
			return jcms.mission_GenerateEvacObjective()
		end
	end,

	think = function(director, missionData)
		local oresRightNow = 0
		for i, ent in ipairs( ents.FindByClass("jcms_*") ) do
			if not IsValid(ent) then continue end

			local entTbl = ent:GetTable()
			if ent:GetClass() == "jcms_orevein" then
				oresRightNow = oresRightNow + math.Clamp( ent:Health() / ent:GetMaxHealth(), 0, 1 )
			end
		end

		missionData.oreProgress = 1 - oresRightNow / missionData.totalOres
	end,

	swarmCalcCost = function(director, swarmCost)
		return swarmCost + (director.missionData.oreProgress^2)*2 
	end,

	npcTypeQueueCheck = function(director, swarmCost, dangerCap, npcType, npcData, basePassesCheck)
		local md = director.missionData
		if npcType == "antlion_mineralguard" and (md.oreProgress > 0 or jcms.director_GetMissionTime() > (60*5)) then
			return basePassesCheck, (md.oreProgress * 1.43) + jcms.director_GetMissionTime() / (60*5)
		else
			return basePassesCheck
		end
	end,
	
	orders = { --mission-specific call-ins
		--TODO: Too much repeated code in the funcs, separate out.
		mo_smallcrate = {
			category = jcms.SPAWNCAT_MISSION,
			cost = 500,
			cooldown = 120,
			slotPos = 1,
			argparser = "orbital_fixed",

			missionSpecific = true,

			func = function(ply, pos, angle)
				local faction = "jcorp"
				if IsValid(ply) then
					faction = jcms.util_GetFactionNamePVP(ply)
				end
				
				local col
				if faction == "mafia" then
					col = Color(238, 255, 0)
				else
					col = Color(255, 0, 0)
				end

				local crate, flare = jcms.spawnmenu_Airdrop(pos, "jcms_orecrate", 10, "#jcms.orecrate", col, ply)
				crate.CrateType = 1

				if IsValid(ply) then
					crate:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(crate)

				if CPPI then
					crate:CPPISetOwner( game.GetWorld() )
				end
			end
		},
		
		mo_mediumcrate = {
			category = jcms.SPAWNCAT_MISSION,
			cost = 1500,
			cooldown = 120,
			slotPos = 2,
			argparser = "orbital_fixed",

			missionSpecific = true,

			func = function(ply, pos, angle)
				local faction = "jcorp"
				if IsValid(ply) then
					faction = jcms.util_GetFactionNamePVP(ply)
				end
				
				local col
				if faction == "mafia" then
					col = Color(238, 255, 0)
				else
					col = Color(255, 0, 0)
				end

				local crate, flare = jcms.spawnmenu_Airdrop(pos, "jcms_orecrate", 10, "#jcms.orecrate", col, ply)
				crate.CrateType = 2

				if IsValid(ply) then
					crate:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(crate)

				if CPPI then
					crate:CPPISetOwner( game.GetWorld() )
				end
			end
		},
		
		mo_largecrate = {
			category = jcms.SPAWNCAT_MISSION,
			cost = 3500,
			cooldown = 120,
			slotPos = 3,
			argparser = "orbital_fixed",

			missionSpecific = true,

			func = function(ply, pos, angle)
				local faction = "jcorp"
				if IsValid(ply) then
					faction = jcms.util_GetFactionNamePVP(ply)
				end
				
				local col
				if faction == "mafia" then
					col = Color(238, 255, 0)
				else
					col = Color(255, 0, 0)
				end

				local crate, flare = jcms.spawnmenu_Airdrop(pos, "jcms_orecrate", 10, "#jcms.orecrate", col, ply)
				crate.CrateType = 3

				if IsValid(ply) then
					crate:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(crate)

				if CPPI then
					crate:CPPISetOwner( game.GetWorld() )
				end
			end
		},
	}


}

