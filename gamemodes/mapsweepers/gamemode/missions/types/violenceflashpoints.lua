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

-- Violence Flashpoints {{{

	jcms.missions.violenceflashpoints = {
		faction = "any",
		pvpAllowed = true,

		generate = function(data, missionData)
			local difficulty = jcms.runprogress_GetDifficulty()
			local fpCount = math.min(math.floor((math.random(4, 5) + jcms.mapgen_AdjustCountForMapSize( math.random(4, 6) ))/2), 8) 
			local flashpoints = jcms.mapgen_SpreadPrefabs("flashpoint", fpCount, 75, true)

			local chargePerPoint = math.ceil( (0.9 * 4000 * jcms.runprogress_GetDifficulty() ^ (2/3) ) /  #flashpoints ) + 100

			for i, flashpoint in ipairs(flashpoints) do 
				flashpoint.faction = jcms.util_GetMissionFaction()
				flashpoint:SetMaxCharge(chargePerPoint)
			end

			missionData.flashpoints = flashpoints
			jcms.mapgen_PlaceNaturals( jcms.mapgen_AdjustCountForMapSize(14) )
			jcms.mapgen_PlaceEncounters()
		end,

		tagEntities = function(director, missionData, tags)
			for i, fp in ipairs(missionData.flashpoints) do
				if IsValid(fp) then
					tags[fp] = { name = "#jcms.flashpoint", moving = false, active = not fp:GetIsComplete() }
				end
			end
		end,

		swarmCalcCooldown = function(director, baseCooldown, swarmCost)
			if director.missionData.evacuating then
				-- 100% charged flashpoints during evac was WAY too brutal (used to be 0.5x of the already-accelerated base cooldown)
				return baseCooldown * 0.8
			else
				local flashpoints = director.missionData.flashpoints

				local totalCharge, totalMaxCharge = 0, 0
				for i, fp in ipairs(flashpoints) do
					if IsValid(fp) then
						local charge, maxcharge = fp:GetCharge(), fp:GetMaxCharge()
						totalCharge = totalCharge + charge
						totalMaxCharge = totalMaxCharge + maxcharge
					end
				end

				return Lerp(totalCharge/totalMaxCharge, baseCooldown, baseCooldown/2)
			end
		end,
		
		getObjectives = function(missionData)
			local flashpoints = missionData.flashpoints
			local chargedCount = 0
			local totalCount = 0

			for i, fp in ipairs(flashpoints) do
				if IsValid(fp) then
					totalCount = totalCount + 1
					if fp:GetIsComplete() then
						chargedCount = chargedCount + 1
					end
				end
			end

			if chargedCount < totalCount then
				local objectives = {}

				if (not missionData.lastObjectiveCount or missionData.lastObjectiveCount < chargedCount) then
					jcms.net_SendTip("all", true, "#jcms.flashpoint_completion", chargedCount / #flashpoints)
					missionData.lastObjectiveCount = chargedCount
				end

				for i, fp in ipairs(flashpoints) do
					if IsValid(fp) then
						local charge, maxcharge = fp:GetCharge(), fp:GetMaxCharge()

						table.insert(objectives, { type = "flashpoint", progress = charge/maxcharge*500, total = 500, percent = true, completed = charge >= maxcharge })
					end
				end

				return objectives
			else
				missionData.evacuating = true
			
				if not IsValid(missionData.evacEnt) then
					missionData.evacEnt = jcms.mission_DropEvac(jcms.mission_PickEvacLocation(), 45)
				end
				
				return jcms.mission_GenerateEvacObjective()
			end
		end,

		think = function(director)
			local missionData = director.missionData

			local missionTime = jcms.director_GetMissionTime()
			if missionTime >= 60 and (not director.debug) and (not missionData.evacuating) then
				director.swarmNext = math.min( director.swarmNext, missionTime + #director.npcs*3 )
			end
		end
	}

-- }}}
