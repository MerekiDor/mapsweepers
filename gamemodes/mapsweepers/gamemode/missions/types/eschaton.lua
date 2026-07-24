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

--"Mega Hell isn't a cool enough name" OK MERKEI HOW ABOUT NOW HAIS THIS GOIOD ENOUGHF RO YOU ARE YOY HAPPY
jcms.missions.eschaton = {
	faction = "everyone",
	pvpAllowed = false,
	bossMission = true,
	
	phrasesOverride = {
		["ambient/explosions/exp1.wav"] = 1,
		["ambient/explosions/exp2.wav"] = 1,
		["ambient/explosions/exp3.wav"] = 1,
		["ambient/explosions/exp4.wav"] = 1
	},

	musicOverride = {
		"jcms/missionstart.mp3"
	},
	
	generate = function(data, missionData)
		jcms.mapgen_PlaceNaturals( jcms.mapgen_AdjustCountForMapSize(20) )
		jcms.mapgen_SpreadPrefabs("eschaton_remains", math.max(20, jcms.mapgen_AdjustCountForMapSize(5)), 100, false)
		
		--Prefabs from all factions
		for k, commander in pairs(jcms.npc_commanders) do 
			if commander.placePrefabs then
				commander:placePrefabs(missionData)
			end
		end

		local diffMult = math.sqrt(jcms.runprogress_GetDifficulty())
		missionData.progress = 0
		missionData.duration = 60*4 * diffMult

		-- // Evac Gen {{{
			--Intent: Generate in partially covered areas, but not indoors or in super exposed ones
			local evacWeightedAreas = {}
			for i, area in ipairs(jcms.mapdata.zoneList[jcms.mapdata.largestZone]) do --Only largest zone (i.e. must be accessible)
				if area:GetSizeX() < 250 or area:GetSizeY() < 250 then continue end --Normal evac check

				--Strongly avoid putting us in the middle of open fields.
				evacWeightedAreas[area] = 1 / (jcms.mapdata.areaDepths[area]+1)^2

				--Prefer visible (Avoids fully indoor spaces)
				evacWeightedAreas[area] = evacWeightedAreas[area] * math.sqrt(#area:GetVisibleAreas())
			end

			local chosenArea = jcms.util_ChooseByWeight(evacWeightedAreas)

			missionData.evacEnt = jcms.mission_DropEvac(chosenArea:GetCenter(), 5)
			missionData.evacEnt:SetMaxCharge(missionData.duration)
			missionData.evacEnt:SetMaterial("models/jcms/jcorp_evac_old")

			missionData.evacEnt.jcms_evacPreventCharge = true
		-- // }}}

		-- // Defences {{{
			local exposureFac = math.sqrt( (#chosenArea:GetVisibleAreas() * (jcms.mapdata.areaDepths[chosenArea]+1)^2) / 500)
			local defCount = math.min(math.floor(exposureFac * 3), 6)

			--Try placing defCount emplacements/ammocrates within 750u of the evac
			local defAreas = jcms.director_GetAreasAwayFrom(jcms.mapdata.validAreas, {missionData.evacEnt:GetPos()}, 0, 750)
			jcms.mapgen_PlacePrefabs(defCount, {
				["emplacement"] = 2.5,
				["ammocrate"] = 1,
			}, defAreas)
		-- // }}}

		-- // Optimisation for nuke pos picking {{{
			missionData.nukeAreas = jcms.director_GetAreasAwayFrom(jcms.mapdata.validAreas, {missionData.evacEnt:GetPos()}, jcms.radSphereSize + 250, math.huge)
			missionData.nukeAreaVectors = {}
			for i, area in ipairs(missionData.nukeAreas) do 
				missionData.nukeAreaVectors[area] = area:GetCenter()
			end
			missionData.nukeAreaDefaultWeights = {}
			for i, area in ipairs(missionData.nukeAreas) do
				if area:GetSizeX() < 20 or area:GetSizeY() < 20 then continue end --This is just to cut down the number we need to check more for perf w/ the reason that areas this thin *probably* aren't that important.

				missionData.nukeAreaDefaultWeights[area] = math.sqrt(area:GetSizeX() * area:GetSizeY())
			end
		-- // }}}
		missionData.nextNuke = CurTime() + 120
	end,
	
	getObjectives = function(missionData)
		local time = jcms.director_GetMissionTime() or 0
		
		if time < 60 then
			return {
				{ type = "prep", progress = 60 - math.floor(time), style = 1, completed = true },
			}
		else
			local progress = math.floor( missionData.evacEnt:GetCharge() / missionData.evacEnt:GetMaxCharge() )

			if progress >= 100 then --Don't stop new spawns until we're charged 
				missionData.evacuating = true
			end

			return jcms.mission_GenerateEvacObjective("#jcms.gotoevac_eschaton")
		end
	end,

	npcTypeQueueCheck = function(director, swarmCost, dangerCap, npcType, npcData, basePassesCheck)
		local npcTypeBlacklist = {
			["zombie_spewer"] = true,
			["zombie_creeper"] = true,
		}
		return (npcData.danger <= dangerCap) and (not npcData.check or npcData.check(director)) and not npcTypeBlacklist[npcType]
	end,
	
	swarmCalcCost = function(director, baseCost)
		local missionData = director.missionData
		
		if missionData.evacuating then
			return baseCost
		else
			local time = jcms.director_GetMissionTime()
			
			if time >= 60 then
				return baseCost + 4 + 3*math.floor( (time-60)/60 )
			else
				return 0
			end
		end
	end,

	swarmCalcDanger = function(d, swarmCost) 
		return d.swarmDanger + 1
	end,

	think = function(director)
		director.totalWar = true
		local missionData = director.missionData
		
		if not director.swarmNext or director.swarmNext < 60 then
			director.swarmNext = 60
		else
			local missionTime = jcms.director_GetMissionTime()
			if missionTime >= 70 then
				director.swarmNext = math.min( director.swarmNext, missionTime + #director.npcs*2 )
			end
		end
		
		for i, npc in ipairs(director.npcs) do
			if math.random() < 0.25 then
				jcms.npc_GetRowdy(npc)
			end
		end

		if jcms.director_GetMissionTime() > 60 then
			missionData.evacEnt.jcms_evacPreventCharge = false

			missionData.progress = missionData.progress + 1

			if jcms.director_GetMissionTime() > 120 and #director.npcs < 15 then
				missionData.progress = missionData.progress + (missionData.duration / (60 * 4.5))
			end

			--Nuking
			if missionData.nextNuke < CurTime() then
				local chosenArea

				local radSpheres = ents.FindByClass("jcms_radsphere")
				if #radSpheres < 12 then --This is n^2 complexity so having it run indefinitely is probably a very bad idea (And it doesn't matter much beyond a certain point anyway)
					local radVecs = {}
					for i, ent in ipairs(radSpheres) do 
						table.insert(radVecs, ent:GetPos())
					end

					--Avoid nuking already nuked spots
					local areaWeights = {}
					for area, weight in pairs(missionData.nukeAreaDefaultWeights) do
						areaWeights[area] = weight

						for i, vec in ipairs(radVecs) do
							if missionData.nukeAreaVectors[area]:DistToSqr(vec) < jcms.radSphereSize^2 then 
								areaWeights[area] = areaWeights[area] * 0.1
							end
						end
					end

					chosenArea = jcms.util_ChooseByWeight(areaWeights)
				else
					chosenArea = jcms.util_ChooseByWeight(missionData.nukeAreaDefaultWeights)
				end

				jcms.util_skyNuke(chosenArea:GetCenter())

				missionData.nextNuke = CurTime() + 60
			end
		end
	end
}