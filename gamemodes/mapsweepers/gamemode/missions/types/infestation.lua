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


--[[Mission Description:

	Arm several explosive devices throughout the map, by hacking and then defending them.
	Zombies will attack the devices themselves, and if they are destroyed they will explode and irradiate a large area.

	Periodic polyp-storms that are map-wide. These require that you either hide indoors or use a mission call-in.
--]]

jcms.missions.infestation = {
	faction = "zombie",
	pvpAllowed = true,

	generate = function(data, missionData)
		local count = math.ceil( jcms.runprogress_GetDifficulty() * 3)
		missionData.beacons = jcms.mapgen_SpreadPrefabs("zombiebeacon", count, 300, true)

		missionData.stormController = ents.Create("jcms_stormmanager")
		missionData.stormController:Spawn()
		missionData.stormController:SetEnabled(false)
		
		missionData.nextStorm = CurTime() + 120

		missionData.storming = true
		missionData.stormEnd = 0

		jcms.mapgen_PlaceNaturals( jcms.mapgen_AdjustCountForMapSize(10) )
		jcms.mapgen_PlaceEncounters()

		--Shorter storms if the map is really open. This gets boring way faster on maps like DIPRIP than it does on ones like jcorpdistrict.
		local areaMult, volMult, densityMult, avgSizeMult = jcms.mapgen_GetMapSizeMultiplier()
		local sizeMult = math.min(areaMult, volMult)
		local densityMult = avgSizeMult / densityMult

		missionData.stormMult = math.min(1, 1 / math.sqrt(densityMult * sizeMult))
	end,

	tagEntities = function(director, missionData, tags)
		for i, beacon in ipairs(missionData.beacons) do
			tags[beacon] = { name = "#jcms.zombiebeacon", moving = false, active = IsValid(beacon) and not beacon:GetIsComplete() }
		end
	end,

	getObjectives = function(missionData)
		local beacons = missionData.beacons

		local totalComplete = 0
		for i=#beacons, 1, -1 do 
			local beacon = beacons[i]
			if IsValid(beacon) then 
				if beacon:GetIsComplete() then 
					totalComplete = totalComplete + 1
				end
			else
				table.remove(beacons, i)
			end
		end

		if not missionData.lastTotalObjectiveCount then
			missionData.lastTotalObjectiveCount = #beacons
		end
		
		if (not missionData.lastObjectiveCount or missionData.lastObjectiveCount < totalComplete) then
			jcms.net_SendTip("all", true, "#jcms.infestation_completion", totalComplete / #beacons)
			missionData.lastObjectiveCount = totalComplete
		elseif (missionData.lastTotalObjectiveCount and #beacons < missionData.lastTotalObjectiveCount) then
			if not jcms.util_IsPVP() then
				jcms.net_SendTip("all", true, "#jcms.infestation_completion_failed", totalComplete / #beacons)
			end
			missionData.lastTotalObjectiveCount = #beacons
		end

		if totalComplete < #beacons then 
			local objectives = {
				{ type = "armbombs", progress = totalComplete, total = #beacons },
			} 
			
			for i, beacon in ipairs(beacons) do 
				if beacon:GetActive() then 
					table.insert(objectives, {
						type = "defendbomb", percent = true, progress = beacon:GetCharge() * 100, total = 100 
					})

					local hpFrac = beacon:Health()/beacon:GetMaxHealth()
					table.insert(objectives, {
						type = "defendbomb", style = 2, progress = hpFrac*100, total = 100, completed = hpFrac < 0.4
					})
				end
			end

			table.insert(objectives, { type = "jzombie", progress = 0, total = 0 })
			return objectives
		else
			missionData.evacuating = true 

			if not IsValid(missionData.evacEnt) then
				local areaWeights = {}
				local areaCentres = {}
				local mainZone = jcms.mapgen_MainZone()
				for i, area in ipairs(mainZone) do 
					local sizeX, sizeY = area:GetSizeX(), area:GetSizeY()
					areaWeights[area] = math.sqrt(jcms.mapdata.areaAreas[area] or (sizeX * sizeY))
					areaCentres[area] = area:GetCenter()

					if sizeX < 250 or sizeY < 250 then
						areaWeights[area] = nil 
						continue
					end
					
					local ply, dist = jcms.director_PickClosestPlayer(areaCentres[area])
					if dist < 500 then 
						areaWeights[area] = nil 
					end
				end

				for i, ent in ipairs(ents.FindByClass("jcms_radsphere")) do
					local entPos = ent:GetPos()
					local entRadius = ent:GetCloudRange()^2
					for i, area in ipairs(mainZone) do 
						if areaWeights[area] and areaCentres[area]:DistToSqr(entPos) < entRadius then 
							areaWeights[area] = areaWeights[area] * 0.01
						end
					end
				end

				local chosenArea = jcms.util_ChooseByWeight(areaWeights)
				missionData.evacEnt = jcms.mission_DropEvac(areaCentres[chosenArea], 45)
			end
			
			return jcms.mission_GenerateEvacObjective()
		end
	end,

	think = function(d)
		local md = d.missionData
		if md.nextStorm < CurTime() then 
			local filter = RecipientFilter()
			filter:AddAllPlayers()

			EmitSound( "ambient/levels/labs/teleport_postblast_thunder1.wav", vector_origin, 0, CHAN_STATIC, 1, 140, 0, 100, 0, filter )
			EmitSound( "ambient/levels/labs/teleport_mechanism_windup3.wav", vector_origin, 0, CHAN_STATIC, 1, 140, 0, 100, 0, filter )

			md.storming = true
			md.stormEnd = CurTime() + (75 * md.stormMult)
			md.nextStorm = md.stormEnd + 180
			
			md.stormController:SetEnabled(true)
		elseif md.storming then 
			if md.stormEnd < CurTime() then 
				md.storming = false
				md.stormController:SetEnabled(false)
			end
		end
	end,
	
	orders = { --mission-specific call-ins
		i_umbrella = {
			category = jcms.SPAWNCAT_MISSION,
			cost = 250,
			cooldown = 40,
			slotPos = 1,
			argparser = "turret_static",

			missionSpecific = true,

			func = function(ply, pos, angle, attachEnt)
				local umbrella = ents.Create("jcms_zombieumbrella")
				umbrella:SetPos(pos + Vector(0, 0, -5))
				umbrella:SetAngles(angle)
				umbrella:Spawn()
				
				local ed = EffectData()
				ed:SetColor(jcms.util_colorIntegerJCorp)
				ed:SetFlags(0)
				ed:SetEntity(umbrella)
				util.Effect("jcms_spawneffect", ed)
			end
		}
	}
}

