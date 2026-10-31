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
	
jcms.missions.thumpersabotage = {
	faction = "combine",
	pvpAllowed = true,

	generate = function(data, missionData)
		local difficulty = jcms.runprogress_GetDifficulty()
		local count = math.ceil(difficulty * 4)
		local thumpers = jcms.mapgen_SpreadPrefabs("thumpersabotage", count, 125, true)

		if #thumpers == 0 then
			error("Couldn't place enough thumpers. This map sucks, find a bigger one.")
		end
		
		missionData.thumperCount = #thumpers
		missionData.thumpers = thumpers

		local function weightOverride(name, ogWeight)
			return ((name == "oil") and 1) or ogWeight
		end

		jcms.mapgen_PlaceNaturals(jcms.mapgen_AdjustCountForMapSize(24), weightOverride)
		jcms.mapgen_PlaceEncounters()
	end,

	tagEntities = function(director, missionData, tags)
		for i, thumper in ipairs(missionData.thumpers) do
			tags[thumper] = { id = "Obj"..i, name = "#jcms.thumper", moving = false, active = IsValid(thumper) and thumper:Health() > 0 }
		end
	end,

	getObjectives = function(missionData)
		local workingThumpers = 0
		for i, thumper in ipairs(missionData.thumpers) do
			if IsValid(thumper) and thumper:Health() > 0 then
				workingThumpers = workingThumpers + 1
			end
		end
		missionData.workingThumpers = workingThumpers
		
		if (missionData.workingThumpers > 0) or (CurTime() - jcms.director.missionStartTime) < 10 then
			
			if (not missionData.lastObjectiveCount or missionData.lastObjectiveCount > missionData.workingThumpers) then
				local progress = 1 - missionData.workingThumpers / #missionData.thumpers

				if progress > 0 then
					jcms.net_SendTip("all", true, "#jcms.thumpersabotage_completion", progress)
				end
				
				missionData.lastObjectiveCount = missionData.workingThumpers
			end

			return {
				{ type = "jcombine", progress = 0, total = 0 },
				{ 
					type = "thumpersabotage", 
					progress = #missionData.thumpers - workingThumpers, 
					total = #missionData.thumpers, 
					completed = #missionData.thumpers == 0
				}
			}
			
		else
			missionData.evacuating = true
			
			if not IsValid(missionData.evacEnt) then
				missionData.evacEnt = jcms.mission_DropEvac(jcms.mission_PickEvacLocation())
			end
			
			return jcms.mission_GenerateEvacObjective()
		end
	end,

	swarmCalcCost = function(director, swarmCost)
		local missionData = director.missionData
		if not missionData.workingThumpers then return swarmCost end 
			
		local completion = missionData.workingThumpers / missionData.thumperCount
		combineRatio = Lerp(completion*completion, 0.25, 1)
		return swarmCost / combineRatio --Comb count doesn't go down, ant count just goes up. They infight so this should roughly maintain difficulty level.
	end,

	swarmCalcCooldown = function(director, baseCooldown, swarmCost)
		local missionData = director.missionData
		
		if missionData.workingThumpers then
			return Lerp(1 - (missionData.workingThumpers / #missionData.thumpers), baseCooldown, baseCooldown/2)
		else
			return baseCooldown
		end
	end,

	npcTypeQueueCheck = function(director, swarmCost, dangerCap, npcType, npcData, basePassesCheck)
		if (npcData.danger <= dangerCap) and (not npcData.check or npcData.check(director)) then
			local missionData = director.missionData
			local combineRatio = 1
			
			if missionData.workingThumpers then
				local completion = missionData.workingThumpers / missionData.thumperCount
				combineRatio = Lerp(completion*completion, 0.25, 1)
				
				if npcData.faction == "any" then
					return true
				else
					if (math.random() < combineRatio) then
						return npcData.faction == "combine"
					else
						return npcData.faction == "antlion"
					end
				end
			end
		end

		return false
	end,

	orders = { --mission-specific call-ins
		sapper = {
			category = "mission",
			cost = 75,
			cooldown = 40,
			slotPos = 1,
			argparser = "mine",

			func = function(ply, pos, angle, attachEnt)
				local device = ents.Create("jcms_sapper")
				angle:RotateAroundAxis(angle:Right(), 90 + math.Rand(-0.5, 0.5)*20)
				local norm = angle:Forward()
				device:SetPos(pos + (norm * 6))
				device:SetAngles(angle)
				device.jcms_owner = ply
				device:Spawn()
				device:SetupDevice("sapper", attachEnt, false)
				constraint.Weld(device, attachEnt, 0, 0)
				jcms.util_TryUpdateForPVP(device)
				if IsValid(ply) then
					device:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
			end
		}
	}
}