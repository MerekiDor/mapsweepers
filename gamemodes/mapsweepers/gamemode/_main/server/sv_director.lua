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

-- // Director {{{

	-- Basics {{{

		jcms.director = jcms.director or nil

		function jcms.director_Prepare(faction)
			if jcms.director then
				jcms.director_End()
			end

			local commander = jcms.npc_commanders[faction]
			if commander and commander.start then 
				commander:start()
			end

			jcms.director = {
				faction = faction,
				commander = commander,
				playerAreas = {},
				zonePopulations = {},
				evacuated = {},
				npcs = {},
				npcs_inCombat = 0,
				npcs_alarm = 0,
				livingPlayers = 0,
				deadPlayers = 0,
				npcrecruits = 0,
				respawnBeacons = {},
				respawnVectors = {},
				encounters = {},
				encounterTriggerLast = 0,
				dispensedTips = {},
				dispensedTipsTimes = {},
				tags_entdict = {},
				tags_perplayer = {},
				nukesDropped = 0,
				teamRespawnWaves = {},

				-- Steam ID stats {{{
					cachedNicknames = {},
					lockstates = {}, -- "sweeper", "evacuated", "npc". Doesn't let player cheat by re-joining.
					lockpvpteams = {},
					deathtimes = {},

					-- As sweeper:
					kills_direct = {},
					kills_defenses = {},
					kills_explosions = {},
					kills_friendly = {},
					kills_pvp = {},
					deaths_sweeper = {},
					ordersUsedCounts = {},

					-- As NPC:
					kills_sweepers = {},
					kills_turrets = {},
					deaths_npc = {}
				-- }}}
			}

			jcms.director.missionStartTime = CurTime()
			jcms.director_PlaceSpawnpoints()
		end

		function jcms.director_End()
			if jcms.director then
				for i, npc in ipairs(jcms.director.npcs) do
					if IsValid(npc) then
						npc:Remove()
					end
				end

				jcms.director = nil
			end
		end
	
	-- }}}

	-- Spawnpoints {{{

		function jcms.director_ChooseSpawnpointLocations_PVP()
			-- Pre-generate spawns to be spaced out a bit
			local locs = {}

			local defaultWeights = {}
			local areaPositions = {}
			for i, area in ipairs( jcms.mapgen_MainZone() ) do 
				defaultWeights[area] = math.sqrt(area:GetSizeX() * area:GetSizeY()) / math.max(#area:GetVisibleAreas(), 1)
				areaPositions[area]  = area:GetCenter()
			end
			local avoidVectors = {}

			for i, ply in player.Iterator() do 
				local areaWeights = {}
				for i, area in ipairs(jcms.mapgen_MainZone()) do
					--Default weight
					areaWeights[area] = defaultWeights[area] 

					--Get closest avoidVec
					local closestDist = math.huge
					for i, otherPos in ipairs(avoidVectors) do
						local dist = areaPositions[area]:Distance( otherPos )
						closestDist = (closestDist < dist and closestDist) or dist
					end
					
					--Avoid avoidVecs
					if not(closestDist == math.huge) then 
						areaWeights[area] = areaWeights[area] * closestDist
					end
				end

				local area = jcms.util_ChooseByWeight(areaWeights)
				table.insert(locs, areaPositions[area])
				table.insert(avoidVectors, areaPositions[area])
			end

			return locs
		end

		function jcms.director_ChooseSpawnpointLocations_PVE()
			if not jcms.mapdata then return end -- No point in any of this, then. Use the default algorithm.
			local locs = {}

			-- Distributing people into squads of 2-4 {{{
				local remainingCount = player.GetCount()
				local squadCounts = {}

				local squadSizePatterns = {
					[1] = { {1} },
					[2] = { {2} },
					[3] = { {3} },
					[4] = { {4}, {2,2} },
					[5] = { {3,2} },
					[6] = { {3,3}, {4,2}, {2,2,2} },
					[7] = { {4,3}, {2,2,3} },
					[8] = { {4,4}, {2,2,4}, {3,3,2}, {2,2,2,2} }
				}

				while remainingCount > #squadSizePatterns do
					local n = math.random() < 0.66 and math.random(3, 4) or 2 -- stronger preference for 3-4 sweeper squads
					table.insert(squadCounts, n)
					remainingCount = remainingCount - n
				end

				local patterns = squadSizePatterns[ remainingCount ]
				if patterns then
					local pattern = patterns[ math.random(1, #patterns) ]
					table.Add(squadCounts, pattern)
				else
					table.insert(squadCounts, remainingCount) -- failsafe, shouldn't actually happen ever
				end
			-- }}}

			-- Picking areas that aren't too exposed if possible {{{
				local largestZoneAreas = jcms.mapdata.zoneList[jcms.mapdata.largestZone]
				if #largestZoneAreas <= #squadCounts then return end -- Fuck it.
				local goodAreas = {} 
				
				-- TODO Jonah I need to use your brain and improve the goodAreas list. 

				local visdata = jcms.mapgen_GetVisData()
				for i, area in ipairs(largestZoneAreas) do
					if #area:GetVisibleAreas() <= visdata.avg then
						table.insert(goodAreas, area)
					end
				end

				if #goodAreas <= #squadCounts then
					goodAreas = table.Copy(largestZoneAreas)
				end

				table.Shuffle(goodAreas)
			-- }}}

			-- Try to pick squad locations {{{
				local function try(squadSize, area)
					for attempt = 1, 4 do
						local vectors, allFit = jcms.director_PackSquadVectors(jcms.mapgen_AreaPointAwayFromEdges(area, 96), squadSize, 120)
						if type(vectors) == "table" and allFit then
							local allClear = true
							for i, v in ipairs(vectors) do
								local _, isClear = jcms.util_GetSky(v)
								if not isClear then
									allClear = false
									break
								end
							end

							if allClear then
								return vectors
							end
						end
					end
				end

				local squadLocations = {}
				for attempt = 1, 2 do
					for i, area in ipairs(goodAreas) do
						local currentSquadIndex = #squadLocations + 1
						local currentSquadSize = squadCounts[ currentSquadIndex ]
						if not currentSquadSize then break end

						local vectors = try(currentSquadSize, area)
						if vectors then
							table.insert(squadLocations, vectors)
							--jcms.printf("found %d vectors for a squad size of %d (attempt=%d)", #vectors, currentSquadSize, attempt)
						end
					end
				end

				if #squadLocations ~= #squadCounts then return end -- Use the default algorithm

				for i, vectors in ipairs(squadLocations) do
					table.Add(locs, vectors)
				end

			-- }}}

			return locs
		end

		function jcms.director_ChooseSpawnpointLocations()
			local locs

			if jcms.util_IsPVP() then
				locs = jcms.director_ChooseSpawnpointLocations_PVP()
			else
				locs = jcms.director_ChooseSpawnpointLocations_PVE()
			end

			hook.Run("MapSweepersChooseSpawnpointLocations", locs)

			return locs
		end

		function jcms.director_PlaceSpawnpoints()
			jcms.director.sweeperSpawnpoints = {}

			local locs = jcms.director_ChooseSpawnpointLocations()
			
			if type(locs) ~= "table" then
				jcms.printf("'jcms.director_ChooseSpawnpointLocations' did not return a table - using default algorithm instead")
				jcms.director.sweeperSpawnpoints = nil
				return
			end

			for i=1, math.min( #locs, player.GetCount() ) do
				table.insert(jcms.director.sweeperSpawnpoints, locs[i])
			end

			hook.Run("MapSweepersPlaceSpawnpoints", jcms.director.sweeperSpawnpoints)
		end

	-- }}}

	-- Big Swarm Phrases {{{
	
		jcms.director_bigSwarmPhrases = {
			antlion = {
				["npc/antlion/rumble1.wav"] = 3,
				["ambient/levels/prison/inside_battle_antlion1.wav"] = 1,
				["ambient/levels/prison/inside_battle_antlion2.wav"] = 1,
				["ambient/levels/prison/inside_battle_antlion4.wav"] = 1,
				["ambient/levels/prison/inside_battle_antlion5.wav"] = 1,
				["ambient/levels/prison/inside_battle_antlion6.wav"] = 1,
				["ambient/levels/prison/inside_battle_antlion7.wav"] = 1,
				["ambient/levels/prison/inside_battle_antlion8.wav"] = 1,
				["ambient/levels/coast/antlion_hill_ambient4.wav"] = 0.5
			},
			
			combine = {
				["npc/overwatch/cityvoice/f_localunrest_spkr.wav"] = 2,
				["npc/overwatch/cityvoice/fprison_interfacebypass.wav"] = 1,
				["npc/overwatch/cityvoice/f_anticivil1_5_spkr.wav"] = 1,
				["npc/overwatch/cityvoice/f_protectionresponse_1_spkr.wav"] = 1,
				["npc/overwatch/cityvoice/f_anticivilevidence_3_spkr.wav"] = 1,
				["npc/overwatch/cityvoice/f_citizenshiprevoked_6_spkr.wav"] = 0.5,
				["npc/overwatch/cityvoice/f_confirmcivilstatus_1_spkr.wav"] = 0.75
			},
			
			rebel = {
				["ambient/levels/streetwar/marching_distant2.wav"] = 1
			},
			
			zombie = {
				["ambient/levels/prison/inside_battle_zombie1.wav"] = 2,
				["ambient/levels/prison/inside_battle_zombie2.wav"] = 2,
				["ambient/creatures/town_zombie_call1.wav"] = 2,
				["npc/fast_zombie/fz_alert_far1.wav"] = 1,
				["npc/zombie_poison/pz_call1.wav"] = 1,
				["ambient/creatures/town_scared_sob2.wav"] = 1,
				["ambient/creatures/town_moan1.wav"] = 1,
				["ambient/creatures/town_scared_breathing1.wav"] = 0.25,
				["ambient/creatures/town_scared_breathing2.wav"] = 0.25,
				["ambient/creatures/town_scared_sob1.wav"] = 0.25
			}
		}
	
	-- }}}
	
	-- Helpers {{{
		function jcms.director_GetIntroMusicOverride()
			local d = jcms.director
			if d and d.missionType and jcms.missions[d.missionType] and jcms.missions[d.missionType].musicOverride then 
				local musicOverride = jcms.missions[d.missionType].musicOverride
				return musicOverride[math.random(#musicOverride)]
			end

			return ""
		end

		function jcms.director_GetMissionTime()
			return CurTime() - (jcms.director.missionStartTime or 0)
		end

		function jcms.director_GetBountyMul()
			local d = jcms.director
			if d and d.missionType and jcms.missions[d.missionType] and jcms.missions[d.missionType].calcBountyMul then 
				return jcms.missions[d.missionType].calcBountyMul(d, d.missionData)
			end

			return 1
		end

		function jcms.director_GetRecallPoint()
			local d = jcms.director
			if d and d.missionType and jcms.missions[d.missionType] and jcms.missions[d.missionType].calcBountyMul then 
				return jcms.missions[d.missionType].getRecallPoint(d, d.missionData)
			end
		end

		function jcms.director_IsSuddenDeath()
			return jcms.director and jcms.director.suddenDeathTime and jcms.director_GetMissionTime() > jcms.director.suddenDeathTime
		end

		function jcms.director_PvpObjectiveCompleted(ply, pos, nonLocal) --Player who completed, objective position, whether we should spawn completely randomly or nearby
			if not IsValid(ply) then return end

			local teamId = ply:GetNWInt("jcms_pvpTeam", -1)
			teamId = not(teamId==-1) and teamId or 1

			jcms.director_PvpObjectiveCompletedTeam(teamId, pos, nonLocal)
		end

		function jcms.director_PvpObjectiveCompletedTeam(teamId, pos, nonLocal) --Skips getting player team 
			if not jcms.util_IsPVP() then return end
			local teamRespWaves = jcms.director.teamRespawnWaves[teamId] or 0 
			jcms.director.teamRespawnWaves[teamId] = teamRespWaves + 1

			local weightedAreas = {}
			if not nonLocal then
				for i, area in ipairs(jcms.director_GetAreasAwayFrom(jcms.mapgen_MainZone(), {pos}, 100, 1250)) do
					weightedAreas[area] = area:GetSizeX() * area:GetSizeY()
				end
			end

			if jcms.cvar_pvprespawnmode:GetInt() == 0 then
				local respCount = math.ceil(player.GetCount()/((teamRespWaves/2) +2)) --half the server in Respawns, decreasing each wave this team gets

				for i=1, respCount, 1 do
					if nonLocal then
						jcms.director_InsertRespawnVector(jcms.director_PvpDynamicRespawn, teamId)
					else
						local area = jcms.util_ChooseByWeight(weightedAreas) --TODO: account for no areas? Although that should be impossible.
						jcms.director_InsertRespawnVector(area:GetCenter(), teamId)
					end
				end
			elseif jcms.cvar_pvprespawnmode:GetInt() == 1 then 
				for i, ply in ipairs(jcms.PVPGetTeamPlayers(teamId)) do 
					if nonLocal then
						jcms.director_GiveRespawnVector(jcms.director_PvpDynamicRespawn, ply)
					else
						local area = jcms.util_ChooseByWeight(weightedAreas)
						jcms.director_GiveRespawnVector(area:GetCenter(), ply)
					end
				end
			end
		end
		
		function jcms.director_GetAreasAwayFrom(zoneAreas, origins, minDist, maxDist)
			local areas = {}
			
			minDist = minDist*minDist
			maxDist = maxDist*maxDist
			
			for i, area in ipairs(zoneAreas) do
				if IsValid(area) and not (area:IsUnderwater() or area:IsDamaging()) then
					local bad = false
					for j, origin in ipairs(origins) do
						local d1, d2, d3, d4, d5 = area:GetCorner(0):DistToSqr(origin), area:GetCorner(1):DistToSqr(origin), area:GetCorner(2):DistToSqr(origin), area:GetCorner(3):DistToSqr(origin), area:GetCenter():DistToSqr(origin)
						
						local distClosest, distFarthest = math.min(d1, d2, d3, d4, d5), math.max(d1, d2, d3, d4, d5)
						if (distClosest < minDist) or (not (distClosest <= maxDist and distFarthest >= minDist)) then
							bad = true
							break
						end
					end
					
					if not bad then
						table.insert(areas, area)
					end
				end
			end
			
			return areas
		end
		
		function jcms.director_GetHiddenAreas(zoneAreas, minDist, maxDist)
			local origins = {}
			
			local sweepers = jcms.GetAliveSweepers()
			for i, sweeper in ipairs(sweepers) do
				table.insert(origins, sweeper:EyePos())
			end
			
			local areas = jcms.director_GetAreasAwayFrom(zoneAreas, origins, minDist, maxDist)
			if #sweepers >= 1 and jcms.director then
				for i=#areas, 1, -1 do
					local area = areas[i]
					if IsValid(area) then
						for j, sweeper in ipairs(sweepers) do
							local plyArea = jcms.director.playerAreas[ sweeper ]
							if IsValid(plyArea) and area:IsPotentiallyVisible(plyArea) then
								table.remove(areas, i)
								break
							end
						end
					end
				end
			end
			
			return areas
		end

		function jcms.director_PickClosestPlayer(v, fromList)
			local best, mindist
			for i, ply in ipairs( fromList or player.GetAll() ) do
				local dist = ply:WorldSpaceCenter():DistToSqr(v)
				if not best or dist < mindist then
					best = ply
					mindist = dist
				end
			end
			return best, mindist
		end

		function jcms.director_RecalculateRespawnCounts()
			local d = jcms.director
			if not d then return end

			local teamCounts = {}
			local teamCountsNoPersonal = {}

			--Respawn Beacons
			for i, beacon in ipairs(d.respawnBeacons) do
				if not IsValid(beacon) then continue end

				local teamId = beacon:GetNWInt("jcms_pvpTeam", -1)
				teamId = (not(teamId==-1) and teamId or 1)
				teamCounts[teamId] = (teamCounts[teamId] or 0) + 1
				teamCountsNoPersonal[teamId] = teamCounts[teamId]
			end
			

			--Respawn Vectors
			for i, vecTbl in pairs(d.respawnVectors) do --Could technically be discontinuous.
				teamCounts[i] = (teamCounts[i] or 0) + #vecTbl
				teamCountsNoPersonal[i] = teamCounts[i]
			end


			for i, ply in player.Iterator() do 
				if ply.jcms_playerRespawnVectors then
					local plyTeam = ply:GetNWInt("jcms_pvpTeam", -1)
					if plyTeam == -1 then plyTeam = 1 end

					teamCounts[plyTeam] = (teamCounts[plyTeam] or 0) + #ply.jcms_playerRespawnVectors
					ply:SetNWInt("jcms_playerRespawns", #ply.jcms_playerRespawnVectors)
				end
			end

			--Total
			--for i, count in ipairs(teamCounts) do
			for i=1, 8 do --Needed to update vars in-case we have no data (e.g. mission just started)
				local count = teamCountsNoPersonal[i] or 0
				game.GetWorld():SetNWInt("jcms_respawncount_"..tostring(i), count)
			end

			return teamCounts
		end
		
		function jcms.director_FindRespawnBeacon(evenBusyOnes, ply)
			local teamId = ply:GetNWInt("jcms_pvpTeam", -1)

			local d = jcms.director
			if not jcms.director then return end
			if jcms.director_IsSuddenDeath() then return end

			if ply.jcms_playerRespawnVectors and #ply.jcms_playerRespawnVectors > 0 then 
				table.Shuffle(ply.jcms_playerRespawnVectors)
				return ply.jcms_playerRespawnVectors[1], true
			end
			
			local beacons = d.respawnBeacons
			if not beacons then return end
			
			for i=#beacons, 1, -1 do
				if not IsValid(beacons[i]) then
					table.remove(beacons, i)
				end
			end

			--Beacons
			if #beacons > 0 then
				table.Shuffle(d.respawnBeacons)
				for i, beacon in ipairs(d.respawnBeacons) do
					if not IsValid(beacon) then continue end
					
					if (evenBusyOnes or not beacon:GetRespawnBusy()) and (not teamId or jcms.team_pvpSameTeam_optimised(teamId, beacon:GetNWInt("jcms_pvpTeam", -1))) then
						return beacon, false
					end
				end
			end

			--Respawn vectors
			teamId = not(teamId==-1) and teamId or 1

			if d.respawnVectors[teamId] and #d.respawnVectors[teamId] > 0 then
				table.Shuffle(d.respawnVectors[teamId]) --I did this because it's done to beacons but do we actually want a random order?
				return d.respawnVectors[teamId][1], false
			end 
		end

		function jcms.director_InsertRespawnVector(vec, teamId)
			if not jcms.director then return end
			if teamId == -1 or not teamId then teamId = 1 end

			jcms.director.respawnVectors[teamId] = jcms.director.respawnVectors[teamId] or {}
			
			table.insert(jcms.director.respawnVectors[teamId], vec)
		end

		function jcms.director_GiveRespawnVector(vec, ply)
			ply.jcms_playerRespawnVectors = ply.jcms_playerRespawnVectors or {} 
			table.insert(ply.jcms_playerRespawnVectors, vec)
		end

		function jcms.director_PvpDynamicRespawn(ply) --TODO: Prefer outside of radiation.
			local plyPos = ply:WorldSpaceCenter()
			local plyTeam = ply:GetNWInt("jcms_pvpTeam", -1)

			--Get enemy positions
			local enemyVecs = {}
			for i, otherPly in ipairs(team.GetPlayers(1)) do 
				if not jcms.team_pvpSameTeam_optimised(plyTeam, otherPly:GetNWInt("jcms_pvpTeam", -1)) then 
					table.insert(enemyVecs, otherPly:WorldSpaceCenter())
				end
			end

			--Calculate weights
			local areaWeights = {}

			for i, area in ipairs(jcms.mapgen_MainZone()) do 
				--Limit impact of differently sized areas, avoid very open / visible areas.
				areaWeights[area] = math.sqrt(area:GetSizeX() * area:GetSizeY()) /math.sqrt(math.max(#area:GetVisibleAreas(), 1))

				local closest = math.huge
				for i, vec in ipairs(enemyVecs) do
					local dist = plyPos:Distance(vec)
					closest = math.min(closest, dist)
				end

				if not(closest == math.huge) then --Avoid enemies.
					areaWeights[area] = areaWeights[area] * math.sqrt(closest)
				end
			end

			--Pick final area / vec
			local area = jcms.util_ChooseByWeight(areaWeights)
			return area:GetCenter()
		end

		function jcms.director_InvalidateRespawnBeacon(beacon)
			if not jcms.director or not IsValid(beacon) then return end
			local beacons = jcms.director.respawnBeacons
			if not beacons or #beacons <= 0 then return end
			
			for i=#beacons, 1, -1 do
				local b = beacons[i]
				if not IsValid(b) then
					table.remove(beacons, i)
				elseif beacon == b then
					table.remove(beacons, i)
					break
				end
			end
		end

		function jcms.director_InvalidateRespawnVector(vec, teamId)
			if not jcms.director then return end
			if teamId == -1 or not teamId then teamId = 1 end

			local vectorTbl = jcms.director.respawnVectors[teamId]
			
			table.RemoveByValue(vectorTbl, vec)
		end

		function jcms.director_InvalidatePlayerRespawnVector(ply, vec) 
			table.RemoveByValue(ply.jcms_playerRespawnVectors, vec)
		end
		
		function jcms.director_GetSubdivisionsCount(length)
			if length <= 3 then
				return 1
			elseif length <= 9 then
				return math.random() < 0.9 and 1 or 2
			elseif (length <= 16) or (length <= 35 and math.random() < 0.25) then
				return math.random(3, 6)
			else
				return math.Round(length/math.random(3, 6))
			end
		end

		function jcms.director_ShouldForceSpawnNPCPlayers()
			local d = jcms.director
			if not(#d.npcs > jcms.cvar_softcap:GetInt()) then return false end

			local cTime = CurTime()
			for i, v in ipairs(jcms.npc_GetPlayersToRespawn()) do
				if (d.npcPlayerSlowRespawnTimes and d.npcPlayerSlowRespawnTimes[ply] or 0) < cTime then
					return true
				end
			end
			return false
		end

		local spectateClasses = {
			["jcms_respawnbeacon"] = true
		}
		function jcms.director_CanSpectate(spectator, target) --Is a valid target class or is a valid target player.
			return IsValid(target) and spectator~=target and (spectateClasses[target:GetClass()] or (target:Alive() and (not target.GetObserverMode or target:GetObserverMode() == OBS_MODE_NONE) and jcms.team_pvpSameTeam(spectator, target)))
		end
	-- }}}

	-- Swarm-related {{{
	
		function jcms.director_SpawnSwarm(d, fullQueue)
			local time = CurTime()

			local aggroChance = 1
			if jcms.cvar_patrollingnpcs:GetBool() then
				-- "Patrolling NPCs" setting. NPCs don't know where the player is until we're evacuating.
				aggroChance = 0
			else
				-- Aggro chance scales to 100% over 30 mins, w/ the baseline scaling by difficulty. (Eventually reaching 100% at 10x)
				aggroChance = math.min( (jcms.director_GetMissionTime() / (60*30))^(1/3) + math.log( jcms.runprogress_GetDifficulty(), 1), d.npcs_alarm * 0.6 + 0.1)
			end

			local zoneList = jcms.mapgen_ZoneList()
			local difficulty_warn = math.Clamp(jcms.cvar_swarm_warning:GetFloat(), 0, 30)
			
			if d.missionData.evacuating then
				aggroChance = (aggroChance + 0.95)/2
			end
			
			local totalPopulation = 0
			for zoneId, population in pairs(d.zonePopulations) do
				totalPopulation = totalPopulation + population
			end
			
			local zoneWeights = {}
			for zoneId, population in pairs(d.zonePopulations) do
				if population > 0 then
					zoneWeights[zoneId] = population / totalPopulation
				end
			end

			if isInitialSwarm then
				totalPopulation = 1
				zoneWeights[1] = 1
			end
			
			local playerOrigins = {}
			local zoneDict = jcms.mapgen_ZoneDict()

			if not isInitialSwarm then
				for i, ply in ipairs(team.GetPlayers(1)) do
					if ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE then
						local plyarea = jcms.director.playerAreas[ ply ]
						if plyarea and zoneDict[plyarea] == 1 then
							table.insert(playerOrigins, ply:GetPos())
						end
					end
				end
			end
			
			local subdivisions = {}
			local subdivisionsCount = jcms.director_GetSubdivisionsCount(#fullQueue)
			
			for i=1, subdivisionsCount do
				subdivisions[i] = {}
			end
			
			for i, enemyType in ipairs(fullQueue) do
				local subdivisionIndex = math.random() < 0.97 and ((i-1) % subdivisionsCount) + 1 or math.random(1, subdivisionsCount)
				table.insert(subdivisions[ subdivisionIndex ], enemyType)
			end
			
			local zonesInRangeBuffer = {}
			for subdivisionIndex, queue in ipairs(subdivisions) do
				local zoneChosen = jcms.util_ChooseByWeight(zoneWeights) or 1
				local zoneAreas = zoneList[zoneChosen]
				
				local zoneAreasInRange = zonesInRangeBuffer[ zoneChosen ]
				if not zoneAreasInRange then
					zoneAreasInRange = jcms.director_GetAreasAwayFrom(zoneAreas, playerOrigins, 256, 3500)
					zonesInRangeBuffer[ zoneChosen ] = zoneAreasInRange
				end
				local zonesTable = #zoneAreasInRange >= 1 and zoneAreasInRange or zoneAreas

				local weightedAreas = {}
				for i, area in ipairs(zonesTable) do
					weightedAreas[area] = math.sqrt(jcms.mapdata.areaAreasUnrestricted[area])
				end
				
				for safeRepeat=1, 64 do
					if #queue <= 0 then break end
					if safeRepeat == 64 then jcms.printf("Can't spawn a full squad of NPCs after 64 tries. Map might be too small?") end
					
					local areaChoice = jcms.util_ChooseByWeight(weightedAreas)
					local vectors, allFit = jcms.director_PackSquadVectors( jcms.mapgen_AreaPointAwayFromEdges(areaChoice, 72), #queue, math.Rand(90, 105) + math.sqrt(#queue)*1.2 )
					local patrolArea = zoneAreas[math.random(1, #zoneAreas)]
					
					local giveAwayPlayer = nil
					if math.random() < aggroChance then
						-- Go to a random player's area
						local ply, plyArea = next(jcms.director.playerAreas)
						if IsValid(ply) and plyArea and zoneDict[plyArea] == zoneChosen then
							patrolArea = plyArea
							giveAwayPlayer = ply
						end
					end
					
					local vectori = 0
					for i=#queue, 1, -1 do
						vectori = vectori + 1
						local pos = vectors[vectori]
						if not pos then
							break
						end
						
						local enemyType = queue[i]
						if pos then
							table.remove(queue, i)
						end

						local enemyData = jcms.npc_types[ enemyType ]

						if enemyData then
							if enemyData.aerial then
								local nearestNode = jcms.pathfinder.getNearestNode(pos)
								if nearestNode then 
									pos = nearestNode.pos
								end
							elseif enemyData.hullSize then 
								local nearestNode = jcms.pathfinder_ain_nearestHullNode(pos, enemyData.hullSize)
								if nearestNode then 
									pos = ainReader.nodePositions[nearestNode]
								end
							end
						else
							-- This is caused by "enemyType" being a table (see a few lines below) which means its a player
							--jcms.printf("(weird?) enemyType has no enemyData: %s", tostring(enemyType))
						end
						
						if type(enemyType) == "table" then
							if isInitialSwarm then continue end
							-- Respawn an NPC-player
							
							-- We're giving players a higher delay before spawn so that
							-- the rest of the NPCs can potentially act as meatshields.
							local delay = 2.1 + i*0.23
							
							local colorInt = jcms.factions_GetColorInteger(enemyType.faction)
							local ed = EffectData()
							ed:SetColor(colorInt)
							ed:SetFlags(1)
							ed:SetOrigin(pos + Vector(0, 0, 256))
							ed:SetStart(pos + Vector(0, 0, 40))
							ed:SetMagnitude(delay)
							ed:SetScale(1)
							util.Effect("jcms_spawneffect", ed)
							
							timer.Simple(delay, function()
								if IsValid(enemyType.ply) and (not enemyType.ply:Alive() or not(enemyType.ply:GetObserverMode() == OBS_MODE_NONE)) then
									jcms.playerspawn_RespawnAs(enemyType.ply, "npc", pos, enemyType.class or "npc_combineelite")
									local ed2 = EffectData()
									ed2:SetColor(colorInt)
									ed2:SetFlags(0)
									ed2:SetEntity(enemyType.ply)
									util.Effect("jcms_spawneffect", ed2)
								end
							end)
						else
							-- Spawn a regular NPC
							local delay = difficulty_warn + 1 + (i + math.random()*0.5)*0.23
							if isInitialSwarm then
								local spawned = jcms.npc_Spawn(enemyType, pos, false)
								spawned.jcms_ignoreStraggling = true
							else
								jcms.npc_SpawnFancy(enemyType, pos, delay, giveAwayPlayer, patrolArea)
							end
						end
					end
				end
			end
			table.Empty(zonesInRangeBuffer)
		
			if d.commander and d.commander.postWaveSpawn then
				d.commander:postWaveSpawn(fullQueue, d.swarmCount, d.swarmDanger )
			end
		end
		
		function jcms.director_MakeQueue(d, totalCost, dangerCap)
			local validTypes = {}
			
			local missionTypeData = jcms.missions[ d.missionType ]
			local hasEpisodes = jcms.HasEpisodes()
			
			for npcType, data in pairs(jcms.npc_types) do
				if (not hasEpisodes and data.episodes) then continue end
				
				local passesCheck = (data.faction == d.faction or data.faction == "any") and (data.danger <= dangerCap) and ((data.swarmLimit or 1) > 0)
				if data.check then 
					passesCheck = passesCheck and data.check(d)
				end

				local weightOverride
				if missionTypeData and missionTypeData.npcTypeQueueCheck then
					passesCheck, weightOverride = missionTypeData.npcTypeQueueCheck(d, totalCost, dangerCap, npcType, data, passesCheck)
				end

				if data.missionSpecific and data.missionSpecific ~= d.missionType then
					passesCheck = false
				end
				
				if passesCheck then
					if weightOverride and (not data.secretNPC) then
						validTypes[ npcType ] = weightOverride
					else
						validTypes[ npcType ] = jcms.npc_GetScaledSwarmWeight(data)
					end
				end
			end
			
			local queue = {}
			local typeCounts = {}

			local function addToQueue(spawnType, data, cost)
				totalCost = totalCost - cost
				table.insert(queue, spawnType)
				typeCounts[spawnType] = (typeCounts[spawnType] or 0) + 1

				if data.swarmLimit and typeCounts[spawnType] >= data.swarmLimit then
					validTypes[spawnType] = nil
				end
			end

			local function spawnBoss(dangerComp)
				for i=1, d.swarmBossCount or 0 do 
					local shuffled = jcms.util_GetShuffledByWeight(validTypes)
					for j, spawnType in ipairs(shuffled) do
						local data = jcms.npc_types[ spawnType ]
						local cost = jcms.npc_GetScaledCost(data)
	
						if data.danger == dangerComp and (cost <= totalCost) then
							addToQueue(spawnType, data, cost)
							break
						end
					end
				end
			end

			spawnBoss(jcms.NPC_DANGER_BOSS)
			if dangerCap >= jcms.NPC_DANGER_RAREBOSS then 
				spawnBoss(jcms.NPC_DANGER_RAREBOSS)
			end
			
			for i=1, 75 do
				local shuffled = jcms.util_GetShuffledByWeight(validTypes)
				
				local spawned = false
				for j, spawnType in ipairs(shuffled) do
					local data = jcms.npc_types[ spawnType ]
					local cost = jcms.npc_GetScaledCost(data)

					if ( (#queue == 0) or (cost <= totalCost) and not(data.danger == jcms.NPC_DANGER_BOSS)) then --Spawn non-boss enemies
						addToQueue(spawnType, data, cost)
						spawned = true
						break
					end
				end
				
				if (totalCost <= 0) or (not spawned) then
					break
				end
			end
			
			if missionTypeData and missionTypeData.finalizeQueue then
				missionTypeData.finalizeQueue(queue, d, totalCost, dangerCap, validTypes)
			end
			
			if not d.npcPlayerRespawnTimes then
				d.npcPlayerRespawnTimes = {} -- In theory should prevent the same player from spawning in 2 different swarms
			end
			
			local npcPlayers = jcms.npc_GetPlayersToRespawn()
			
			if #npcPlayers > 0 then
				for i, ply in ipairs(npcPlayers) do
					table.insert(queue, jcms.npc_GeneratePlayerRespawnTable(ply))
					d.npcPlayerRespawnTimes[ply] = CurTime() + 5
				end
			end
			
			return queue
		end

		--npc hull checks
		local hullMins = Vector(-32, -32, 0)
		local hullMaxs = Vector(32, 32, 50)
		local hullMaxsZ = Vector(0,0, hullMaxs.z)
		--Hex Trace offsets
		local downVec = Vector(0,0,-32768)
		local upVec = Vector(0,0,15)
		function jcms.director_PackSquadVectors(startingVector, count, spacing, parameterOverrides)
			local dotTolerance = 0.1
			hullMins:SetUnpacked(-32, -32, 0)
			hullMaxs:SetUnpacked(32, 32, 50)
			hullMaxsZ.z = hullMaxs.z

			local filter = nil
			if parameterOverrides then
				filter = parameterOverrides.filter

				if parameterOverrides.dotTolerance then
					dotTolerance = parameterOverrides.dotTolerance
				end

				if parameterOverrides.hullMins and parameterOverrides.hullMaxs then
					hullMins:SetUnpacked( parameterOverrides.hullMins:Unpack() )
					hullMaxs:SetUnpacked( parameterOverrides.hullMaxs:Unpack() )
				end
			end

			local vectors = {}
			local openDict = {}
			local chunks, chunksize, getChunkId, getChunkTable, getAllNearbyNodes = jcms.util_ChunkFunctions(512)

			local traceRes = {}
			local traceData = { mask = bit.bor(MASK_NPCSOLID_BRUSHONLY, MASK_WATER), filter = filter, output = traceRes, mins = hullMins, maxs = hullMaxs }

			local spacingIterations = {}
			local minSpacing
			if type(spacing) == "table" then
				for i, s in ipairs(spacing) do
					minSpacing = math.min(minSpacing or s, s)
					spacingIterations[i] = s
				end
			else
				spacingIterations[1] = spacing
				minSpacing = spacing
			end

			local function vectorFits(v)
				local spacing2 = minSpacing*minSpacing - 1
				for i, ov in ipairs(getAllNearbyNodes(v.x, v.y, v.z)) do
					if ov:DistToSqr(v) < spacing2 then
						return false
					end
				end
				return true
			end

			local spreadShape = 6
			local ceiling = 256
			if parameterOverrides then
				spreadShape = tonumber(parameterOverrides.spreadShape) or spreadShape
				ceiling = tonumber(parameterOverrides.ceiling) or ceiling
			end

			local function hexSpread(v)
				for adaptStep, adaptSpacing in ipairs(spacingIterations) do
					local worked = false
					for i=1, spreadShape do
						if #vectors >= count then -- Don't keep going if we're already full.
							break
						end

						local a = math.Remap(i, 0, spreadShape, 0, math.pi*2)
						local cos, sin = math.cos(a), math.sin(a)

						--Bring us to ceiling/get out from underneath any displacements.
						traceData.mask = bit.bor(MASK_NPCSOLID_BRUSHONLY, MASK_WATER)
						traceData.start = v + upVec
						traceData.endpos = v + Vector(cos*adaptSpacing, sin*adaptSpacing, ceiling)
						util.TraceHull(traceData)

						if traceRes.StartSolid or traceRes.HitNoDraw then
							continue
						end

						--Bring us to the floor
						traceData.mask = bit.bor(MASK_NPCSOLID, MASK_WATER)
						traceData.start = traceRes.HitPos
						traceData.endpos = traceRes.HitPos + downVec
						util.TraceLine(traceData)
						
						--Are we on a valid surface?
						if traceRes.HitSky or traceRes.HitNoDraw or not(traceRes.Hit and (traceRes.MatType ~= MAT_SLOSH) and traceRes.HitNormal:Dot(jcms.vectorUp) >= dotTolerance) then
							continue
						end
						
						--Check if we're obstructed
						traceData.start = traceRes.HitPos + hullMaxsZ
						traceData.endpos = traceRes.HitPos
						local nv = traceRes.HitPos

						util.TraceHull(traceData)
						if IsValid(traceRes.Entity) then --traceRes.Hit ?
							continue
						end

						--We've passed all checks
						worked = true

						if not vectorFits(nv) then
							--debugoverlay.Cross(nv, 4, 4, Color( 255, 0, 0 ), true)
							continue
						end

						--debugoverlay.Line(nv, nv + norm * 128, 1, Color(255, 255, 0), true)
						--debugoverlay.Cross(nv, 8, 4, Color( 0, 255, 0 ), true)
						
						openDict[nv] = true
						table.insert(vectors, nv)
						table.insert(getChunkTable(nv.x, nv.y, nv.z), nv)
					end

					if worked then break end
				end
				
				openDict[v] = nil
			end
			
			openDict[ startingVector ] = true
			while (#vectors < count) and next(openDict) do
				local v = next(openDict)
				hexSpread(v)
			end
			
			return vectors, #vectors == count
		end
	
	-- }}}
	
	-- Dispensing tips {{{

		jcms.director_tipsConds = {
			[ jcms.HINT_FIRSTAID ] = function(d, ply)
				if ply:Health() / ply:GetMaxHealth() <= 0.5 then
					return true
				end
			end,

			[ jcms.HINT_AMMO ] = function(d, ply)
				local wep = ply:GetActiveWeapon()
				if IsValid(wep) and wep:GetPrimaryAmmoType()>0 and ply:GetAmmoCount( wep:GetPrimaryAmmoType() ) <= 0 then
					return true
				end
			end,

			[ jcms.HINT_TURRETREP ] = function(d, ply)
				local trent = ply:GetEyeTrace().Entity
				if IsValid(trent) and trent:GetClass() == "jcms_turret" and trent:Health() < trent:GetMaxHealth()*0.8 then
					return true
				end
			end,

			[ jcms.HINT_RESPAWN ] = function(d, ply)
				if jcms.orders.respawnbeacon then
					if game.SinglePlayer() then
						return (ply:Health() <= ply:GetMaxHealth()*0.2) and (ply:GetNWInt("jcms_cash") >= jcms.orders.respawnbeacon.cost*0.95)
					else
						return d.deadPlayers > 0 and not jcms.util_IsPVP()
					end
				end
			end,

			[ jcms.HINT_ANTIAIR ] = function(d, ply)
				if jcms.orders.antiairmissile and ply:GetNWInt("jcms_cash") >= jcms.orders.antiairmissile.cost*0.9 then
					for i, npc in ipairs(d.npcs) do
						if IsValid(npc) and jcms.team_flyingEntityClasses[npc] then
							return true
						end
					end
				end
			end,

			[ jcms.HINT_LEECHES ] = function(d, ply)
				return ply.jcms_leechesBuildup and ply.jcms_leechesBuildup >= 2
			end
		}

		timer.Create("jcms_DirectorTips", 0.2, 0, function()
			local d = jcms.director
			if d and not d.gameover and d.dispensedTips and jcms.director_GetMissionTime() > 10 then
				local sweepers = jcms.GetAliveSweepers()
				for tip, cond in pairs(jcms.director_tipsConds) do
					for i, sweeper in ipairs(sweepers) do
						if not d.dispensedTips[sweeper] then
							d.dispensedTips[sweeper] = {}
						end

						if not d.dispensedTips[sweeper][tip] and cond(d, sweeper) then
							jcms.director_TryShowTip(sweeper, tip)
						end
					end
				end
			end
		end)

		function jcms.director_TryShowTip(ply, tip)
			local d = jcms.director

			if d and d.dispensedTips then
				if not IsValid(ply) then return end
				local time = CurTime()

				for pl, tipTable in pairs(d.dispensedTips) do
					if not IsValid(pl) then
						d.dispensedTips[pl] = nil
						d.dispensedTipsTimes[pl] = nil
					end
				end

				if not d.dispensedTips[ply] then
					d.dispensedTips[ply] = { [tip] = true }
					d.dispensedTipsTimes[ply] = time
				elseif d.dispensedTips[ply][tip] then
					return
				else
					local cooldown = 7.8
					d.dispensedTipsTimes[ply] = d.dispensedTipsTimes[ply] or 0
					local elapsed = time - d.dispensedTipsTimes[ply]
					if time - d.dispensedTipsTimes[ply] > cooldown then
						d.dispensedTips[ply][tip] = true
						d.dispensedTipsTimes[ply] = time
					else
						d.dispensedTips[ply][tip] = true

						timer.Simple(cooldown - elapsed, function()
							if IsValid(ply) and d == jcms.director then
								jcms.net_SendTip(ply, false, tip)
							end
						end)

						d.dispensedTipsTimes[ply] = d.dispensedTipsTimes[ply] + cooldown
						return true
					end
				end

			end

			jcms.net_SendTip(ply, false, tip)
		end

	-- }}}

	-- Tags {{{

		function jcms.director_TagGetId(tagData, key)
			return tagData.id or (isentity(key) and "!"..key:EntIndex()) or tostring(key)
		end

		function jcms.director_TagIsVisible(key, tagData, ply)
			local trace = ply:GetEyeTrace()
			if tagData.alwaysVisible then
				return true
			elseif tagData.visFunc then
				return not not tagData.visFunc(key, tagData, ply)
			elseif isentity(key) and IsValid(key) then
				if trace.Entity == key or (ply:Visible(key) and trace.Normal:Dot( key:WorldSpaceCenter() ) > 0) then
					return true
				end
			elseif tagData.pos then
				if ply:VisibleVec( tagData.pos ) and trace.Normal:Dot( tagData.pos ) > 0 then
					return true
				end
			end

			return false
		end

	-- }}}

	-- Main Methods, Thinking {{{
		jcms.director_debrisPropNames = {
			["models/gibs/manhack_gib01.mdl"] = 7.5,
			["models/gibs/manhack_gib02.mdl"] = 7.5,
			["models/gibs/manhack_gib03.mdl"] = 7.5,
			["models/gibs/manhack_gib04.mdl"] = 7.5,
			["models/gibs/manhack_gib05.mdl"] = 7.5,
			["models/gibs/manhack_gib06.mdl"] = 7.5,

			["models/gibs/antlion_gib_large_1.mdl"] = 7.5,
			["models/gibs/antlion_gib_large_2.mdl"] = 7.5,
			["models/gibs/antlion_gib_large_3.mdl"] = 7.5,
			["models/gibs/antlion_gib_medium_1.mdl"] = 7.5,
			["models/gibs/antlion_gib_medium_2.mdl"] = 7.5,
			["models/gibs/antlion_gib_medium_3.mdl"] = 7.5,
			["models/gibs/antlion_gib_medium_3a.mdl"] = 7.5,
			["models/gibs/antlion_gib_small_1.mdl"] = 7.5,
			["models/gibs/antlion_gib_small_2.mdl"] = 7.5,
			["models/gibs/antlion_gib_small_3.mdl"] = 7.5,

			["models/gibs/antlion_worker_gibs_head.mdl"] = 7.5, --The rest of the worker gibs are ragdolls.
			
			["models/gunship.mdl"] = 25,
			["models/crashedgunship.mdl"] = 45
		}


		jcms.director_debrisClasses = {
			["helicopter_chunk"] = 60,
			["gib"] = 7.5,
		}

		jcms.director_debrisClasses_important = {
			["item_ammo_ar2_altfire"] = true,
			["item_battery"] = true, --Leaving health-kits alone because they're more important. Suit batteries basically only matter to sentinel
		}
		
		jcms.director_debrisFadeClasses = { --classes to fade with instead of dissolving.
			["prop_physics"] = true,
			["gib"] = true
		}

		function jcms.director_DebrisClear(d) --NOTE: This is primarily to reduce *render lag* rather than physics/anything like that. Most of this stuff is stationary.
			local npcCount = #jcms.director.npcs
			local reduce = math.max(npcCount - 60, 0) --Don't do anything until >60, then clear more aggressively with each npc after.

			local impDelay = math.min(reduce, 90)
			local impNearbyDist = math.max(600 - reduce * 5, 150)

			for i, ent in ents.Iterator() do
				local isWeapon = ent:IsWeapon()
				local entClass = ent:GetClass()
				local isImportant = jcms.director_debrisClasses_important[entClass]
				local isProp = entClass == "prop_physics" or entClass == "prop_ragdoll"

				if not (isWeapon or jcms.director_debrisClasses[entClass] or isImportant or isProp) then continue end --Only our entities
				if IsValid(ent:GetOwner()) or ent:CreatedByMap() or ent.jcms_canPickup then continue end  --Don't kill map-entities or ones in an inventory
				local model = ent:GetModel() 
				if isProp and not jcms.director_debrisPropNames[model] then continue end

				local dissolveDelay = (isWeapon or isImportant) and (110 - impDelay) or jcms.director_debrisClasses[entClass] or jcms.director_debrisPropNames[model]

				local entTbl = ent:GetTable() 
				entTbl.jcms_weaponDieTime = entTbl.jcms_weaponDieTime or (CurTime() + dissolveDelay) --Set our timer if we don't have one

				if entTbl.jcms_weaponDieTime < CurTime() or not ent:IsInWorld() then -- If our time's up, (or we're outside the map? Somehow?)
					if (isWeapon or isImportant) and #jcms.GetSweepersInRange(ent:GetPos(), impNearbyDist) > 0 then -- Give us more if a sweeper's nearby
						entTbl.jcms_weaponDieTime = CurTime() + 20
					else
						if jcms.director_debrisFadeClasses[entClass] then 
							if not(ent:GetRenderFX() == kRenderFxFadeSlow) then
								ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
								ent:SetRenderFX(kRenderFxFadeSlow)
								timer.Simple(2.5, function() 
									if IsValid(ent) then
										ent:Remove()
									end
								end)
							end
						else
							ent:Dissolve() -- Clean us up
						end
					end
				end
			end
		end

		function jcms.director_PlayersAnalyze(d)
			for zoneId, zoneAreas in ipairs( jcms.mapgen_ZoneList() ) do
				d.zonePopulations[ zoneId ] = 0
			end
		
			local zoneDict = jcms.mapgen_ZoneDict()
			local livingCount, evacCount = 0, 0
			local teamAlivePlayers = {} --dict for pvp teams
			local deadPlayers = {}

			for i, ply in player.Iterator() do
				jcms.director_stats_Ensure(d, ply)
				if d.evacuated[ply] then
					evacCount = evacCount + 1
					
					if ply.jcms_isNPC and not ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE then
						if CurTime() - ply:GetNWFloat("jcms_lastDeathTime", 0) > 6 then
							jcms.playerspawn_RespawnAs(ply, "spectator")
						end
					end
				else
					if ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE and jcms.team_JCorp_player(ply) then
						livingCount = livingCount + 1
						local pvpTeam = ply:GetNWInt("jcms_pvpTeam", -1)
						if pvpTeam == -1 then pvpTeam = 1 end --Default 1 to work with normal mode.
						teamAlivePlayers[pvpTeam] = (teamAlivePlayers[pvpTeam] or 0) + 1

						local area = navmesh.GetNavArea(ply:GetPos(), 200)

						if area then
							d.playerAreas[ ply ] = area
							
							local zoneId = zoneDict[ area ]
							if zoneId then
								d.zonePopulations[ zoneId ] = d.zonePopulations[ zoneId ] + 1
							end
						end

						if not (d and IsValid(d.strongestPlayer)) or (d.strongestPlayer:Health() < ply:Health()) then
							d.strongestPlayer = ply
						end
					elseif not ply:Alive() and (ply:GetObserverMode() == OBS_MODE_NONE or ply:GetObserverMode() == OBS_MODE_CHASE) then
						if ply:GetNWInt("jcms_desiredteam", 0) == 1 or jcms.util_IsPVP() then
							table.insert(deadPlayers, ply)
						end

						if CurTime() - ply:GetNWFloat("jcms_lastDeathTime", 0) > 6 then
							jcms.playerspawn_RespawnAs(ply, "spectator")
						end
						
					elseif ply:Alive() and ply:GetObserverMode() == OBS_MODE_CHASE then
						local ent = ply:GetObserverTarget()
						
						if not jcms.director_CanSpectate(ply, ent) then
							for i, oply in ipairs(team.GetPlayers(1)) do
								if jcms.director_CanSpectate(ply, oply) then
									ply:SpectateEntity(oply)
									break
								end
							end

							local target = ply:GetObserverTarget()
							if not IsValid(target) or target == ply then 
								ply:SpectateEntity(jcms.director.npcs[math.random(#jcms.director.npcs)])
							end
						end

						
						if ply:GetNWInt("jcms_desiredteam", 0) == 1 or jcms.util_IsPVP() then
							table.insert(deadPlayers, ply)
						end
					elseif jcms.util_IsPVP() and jcms.team_NPC(ply) then
						table.insert(deadPlayers, ply)
					end
				end
			end

			if #deadPlayers > 0 then
				table.sort(deadPlayers, function(first, last)
					return first:GetNWFloat("jcms_lastDeathTime", 0) < last:GetNWFloat("jcms_lastDeathTime", 0)
				end)

				local ct = CurTime()
				for i, ply in ipairs(deadPlayers) do
					ply:SetNWInt("jcms_respawnQueuePos", i)
					local respawnDelay = (game.SinglePlayer() or #jcms.PVPGetTeamAlivePlayers(ply:GetNWInt("jcms_pvpTeam", -1)) == 0) and 5 or 22.5
					local respawnInterval = 5

					local timeSinceDeath = ct - ply:GetNWFloat("jcms_lastDeathTime", 0)
					local timeSinceRespawnAttempt = ply.jcms_lastRespawnTime and ct - ply.jcms_lastRespawnTime or respawnInterval + 1
					local timeTabbedOut = ply:IsBot() and 0 or (CurTime() - ((jcms.playerAfkPings and jcms.playerAfkPings[ply]) or 0))

					if (timeSinceDeath >= respawnDelay) and (timeSinceRespawnAttempt >= respawnInterval) and timeTabbedOut < 20 then
						local beacon, playerOriented = jcms.director_FindRespawnBeacon(false, ply)

						if isentity(beacon) and IsValid(beacon) then
							ply.jcms_lastRespawnTime = CurTime()
							local delay = 3
							
							beacon:SetRespawnBusy(true)
							beacon:DoPreRespawnEffect(ply, delay)
							if ply:GetObserverMode() == OBS_MODE_CHASE then
								ply:SpectateEntity(beacon)
							end
							
							timer.Simple(delay, function()
								if IsValid(ply) and IsValid(beacon) then
									local respawnPos, respawnAngle

									if beacon.GetRespawnPosAng then
										respawnPos, respawnAngle = beacon:GetRespawnPosAng(ply)
									end

									if not isvector(respawnPos) then
										respawnPos = beacon:WorldSpaceCenter()
										respawnPos.z = respawnPos.z + 16
									end

									jcms.playerspawn_RespawnAs(ply, "sweeper", respawnPos, true)

									if not isangle(respawnAngle) then
										respawnAngle = beacon:GetAngles()
									end
									
									respawnAngle.r = 0
									ply:SetAngles(respawnAngle)

									beacon:DoPostRespawnEffect(ply)
									
									jcms.director_InvalidateRespawnBeacon(beacon)
								end

								if IsValid(beacon) then 
									beacon:SetRespawnBusy(false)
								end
							end)
						elseif isvector(beacon) or isfunction(beacon) then
							ply.jcms_lastRespawnTime = CurTime()

							local vec = beacon
							if isfunction(beacon) then --Dynamic respawns
								vec = beacon(ply)
							end
							
							--Instantly droppod us in.
							jcms.playerspawn_RespawnAs(ply, "sweeper", vec) 

							local pvpTeam = ply:GetNWInt("jcms_pvpTeam", -1)
							if pvpTeam == -1 then pvpTeam = 1 end --Default 1 to work with normal mode.
							
							if playerOriented then 
								jcms.director_InvalidatePlayerRespawnVector(ply, beacon)
							else
								jcms.director_InvalidateRespawnVector(beacon, pvpTeam)
							end

							livingCount = livingCount + 1 --Needed because otherwise we check this on the same frame and think everyone's dead. 
							teamAlivePlayers[pvpTeam] = (teamAlivePlayers[pvpTeam] or 0) + 1
						end
					end
				end
			end

			return livingCount, #deadPlayers, evacCount, teamAlivePlayers
		end

		function jcms.director_AnalyzeNPCs(d)
			local npcs = d.npcs
			local total, combat = 0, 0
			local sweepers = jcms.GetAliveSweepers()
			local time = CurTime()

			local sweeperPositions = {} --Reduce repeated work
			for i, sweeper in ipairs(sweepers) do --This will be in the same order as sweepers 
				sweeperPositions[i] = sweeper:GetPos()
			end

			local stragglers = {}
			
			for i=#npcs, 1, -1 do
				local npc = npcs[i]
				if not (IsValid(npc) and npc:Health() > 0) then
					table.remove(npcs, i)
				elseif npc:GetPos().z < -32000 then --NOTE: Bandaid, remove invalids. Ideally we want to prevent this happening in the first place.
					npc:Remove()
					table.remove(npcs, i)
				else
					local npcTbl = npc:GetTable() 
					local npcpos --Messy

					local confirmedStraggler = false
					local state = npc:GetNPCState()

					if not npcTbl.jcms_ignoreStraggling then
						if not npc:IsInWorld() or npc:GetInternalVariable("startburrowed") then 
							confirmedStraggler = true
						end
						if not confirmedStraggler then 
							npcpos = npc:WorldSpaceCenter()
							local npcArea = navmesh.GetNearestNavArea(npcpos, false, 250, false)
							if not IsValid(npcArea) or not jcms.mapgen_ValidArea(npcArea) or (npcArea:GetZ( npcpos ) - npcpos.z > 85) then
								confirmedStraggler = true
							end
						end

					end

					total = total + 1
					if state == NPC_STATE_COMBAT and not confirmedStraggler then
						combat = combat + 1
					elseif not npcTbl.jcms_ignoreStraggling and not confirmedStraggler then
						confirmedStraggler = true

						local maxDist2 = 6000^2
						local pvsDist2 = 1000^2
						for j, sweeper in ipairs(sweepers) do
							local dist2 = sweeperPositions[j]:DistToSqr(npcpos)
							if not((dist2 > maxDist2) or (dist2 > pvsDist2 and not sweeper:TestPVS(npc))) then
								confirmedStraggler = false
								break
							end
						end
					end
					
					if confirmedStraggler then
						if npcTbl.jcms_npcIsStraggler and npcTbl.jcms_npcStragglerTime then
							-- This NPC has been a straggler for a while. Let's give it time.
							if (time - npcTbl.jcms_npcStragglerTime) > 8 then
								table.insert(stragglers, npc)
							end
						else
							-- This NPC just got deemed a straggler. Store current time.
							npcTbl.jcms_npcStragglerTime = time
						end
					else
						-- This NPC has been rediscovered. Invalidate the time.
						npcTbl.jcms_npcStragglerTime = nil
					end
	
					if IsValid(npc) then
						npcTbl.jcms_npcIsStraggler = confirmedStraggler
						
						if jcms.npc_idleSchedules[npc:GetCurrentSchedule()] then
							local count = npc:GetKnownEnemyCount()

							if count > 0 then
								npc:SetSchedule(math.random() < 0.8 and SCHED_IDLE_WANDER or SCHED_PATROL_WALK)
							else
								npc:SetSchedule(math.random() < 0.8 and SCHED_PATROL_RUN or SCHED_COMBAT_PATROL)
							end
						end
						
						if npcTbl.jcms_Think then
							npcTbl.jcms_Think(npc, state)
						end
					else
						table.remove(npcs, i)
					end
				end
			end

			if #stragglers > 0 then
				jcms.npc_HandleStragglers(stragglers)
			end

			d.npcs_inCombat = combat
			d.npcs_alarm = total > 0 and combat / total or 0
		end

		function jcms.director_ThinkMission(d)
			local data = assert(jcms.missions[ d.missionType ], "invalid mission type: " .. tostring(arg))
			local missionData = d.missionData
			
			if data.think then
				data.think(d, missionData)
			end
		end

		function jcms.director_ThinkPvp(d)
			if jcms.util_IsPVP() and d.missionData.evacuating then 
				--DESTROY EVERYTHING
				-- So true jonahsoldier -M
				local cTime = CurTime()

				d.nukeStart = d.nukeStart or cTime
				d.nextNuke = d.nextNuke or cTime + 60

				if d.nextNuke < cTime then
					local weightedAreas = jcms.mapgen_BorderWeights( jcms.mapdata.validAreas )

					local timeNuking = cTime - d.nukeStart
					local exp = 1/math.sqrt((timeNuking-50)/300)
					for area, weight in pairs(weightedAreas) do 
						weightedAreas[area] = weight ^ exp --Flatten as time goes on.
					end
					
					local targetArea = jcms.util_ChooseByWeight(weightedAreas)

					local targetPos = targetArea:GetCenter()
					local nearestSwp = jcms.GetNearestSweeper(targetPos) 
					if not nearestSwp:InVehicle() and not IsValid(nearestSwp:GetNWEntity("jcms_vehicle", NULL)) then --Don't match Z-level of players in VTOLs
						targetPos.z = nearestSwp:GetPos().z
					end

					jcms.util_skyNuke(targetPos)

					d.nextNuke = cTime + Lerp(timeNuking/(10*60), 55, 25)
				end
			end
		end

		function jcms.director_ThinkTags(d)
			local data = assert(jcms.missions[ d.missionType ], "invalid mission type: " .. tostring(arg))
			local players = jcms.GetAliveSweepers()
			
			if IsValid(d.evacEnt) then
				jcms.net_SendLocator("all", "Evac", "", d.evacEnt:WorldSpaceCenter(), jcms.LOCATOR_WARNING, 3, "evac")
			end

			-- Processing what must be marked fist {{{
				local dict = d.tags_entdict
				if data.tagEntities then
					data.tagEntities(d, d.missionData, dict)
				end
				
				for i, shop in ipairs( ents.FindByClass("jcms_shop") ) do
					if IsValid(shop) then
						if not dict[ shop ] then
							dict[ shop ] = { name = "#jcms.shop_locator", moving = false, active = true, landmarkIcon = "shop" }
						end
					else
						dict[ shop ] = nil
					end
				end
			-- }}}
			
			local known = d.tags_perplayer
			for i, ply in ipairs(players) do
				known[ ply ] = known[ ply ] or {}
			end
			
			-- Removing invalid ents & cleaning up {{{
				for key, tagData in pairs(dict) do
					if (isentity(key) and not IsValid(key)) or (not tagData.active) then

						for i, ply in ipairs(players) do
							local knownKeys = known[ply]
							if knownKeys[ key ] then
								local tagId = jcms.director_TagGetId(tagData, key)
								knownKeys[ key ] = nil
							end
						end

						dict[key] = nil
					end
				end
			-- }}}

			-- Sharing known tags {{{
				for key, tagData in pairs(dict) do
					local tagname = tagData.name or "#jcms.objective"
					
					local mustShare = false
					local discoveredBy = nil

					for i, ply in ipairs(players) do
						local knownKeys = known[ply]
						if ply:GetObserverMode() == OBS_MODE_NONE and ply:Alive() and jcms.team_JCorp_player(ply) then
							if not knownKeys[ key ] and jcms.director_TagIsVisible(key, tagData, ply) then
								knownKeys[ key ] = true

								if not discoveredBy then
									local classData = jcms.classes[ ply:GetNWString("jcms_class", "infantry") ]
									if classData and classData.shareObjectiveMarkers then
										mustShare = true
										discoveredBy = ply
									end
								end
							end
						end
					end

					if mustShare then
						jcms.net_NotifyGeneric(discoveredBy, jcms.NOTIFY_LOCATED, tagname)

						for i, ply in ipairs(players) do
							if jcms.team_pvpSameTeam(discoveredBy, ply) then
								local knownKeys = known[ply]
								knownKeys[ key ] = true
							end
						end
					end
				end
			-- }}}

			-- Sending known locators {{{
				for ply, knownKeys in pairs(known) do
					for key in pairs(knownKeys) do
						local tagData = dict[key]
						
						if tagData then
							local tagId = jcms.director_TagGetId(tagData, key)
							local tagname = tagData.name or "#jcms.objective"
							
							local ent = isentity(key) and IsValid(key) and key
							local locatorType = tagData.type or jcms.LOCATOR_GENERIC

							if ent then
								jcms.net_SendLocator(ply, tagId, tagname, tagData.moving and ent or ent:WorldSpaceCenter(), locatorType, 1.5, tagData.landmarkIcon)
							elseif tagData.pos and tagData.id then
								jcms.net_SendLocator(ply, tagId, tagname, tagData.pos, locatorType, 1.5, tagData.landmarkIcon)
							end
						end
					end
				end
			-- }}}
		end
		
		function jcms.director_SayWarn(d)
			local phrases = d.phrasesOverride or jcms.director_bigSwarmPhrases[ d.faction ]
			if phrases then
				local path = jcms.util_ChooseByWeight(phrases)
				if type(path) == "string" then
					for i, ply in ipairs(player.GetAll()) do
						ply:SendLua("surface.PlaySound\"" .. path .. "\"")
					end
				end
			end
		end
		
		function jcms.director_ThinkSwarm(d)
			if not d then return end

			local missionTime = jcms.director_GetMissionTime()
			local softcap = jcms.cvar_softcap:GetInt()
			local softcap_slowdown = softcap * 0.8

			if #d.npcs > softcap then
				d.swarmNext = missionTime + 3
				--return 
			end

			local missionTypeData = jcms.missions[ d.missionType ]
			
			d.swarmCount = d.swarmCount or 0
			d.swarmNext = d.swarmNext or 15
			d.swarmDanger = d.swarmDanger or jcms.NPC_DANGER_FODDER
			d.swarmBossCount = 0

			if missionTime >= d.swarmNext then
				d.swarmCount = d.swarmCount + 1
				local swarmCost = math.Round(2.5 + math.sqrt(missionTime/50), 1) - math.max(0, #d.npcs - softcap_slowdown) + d.livingPlayers
				local cooldownAdd = 0 --Lulls have extra delay

				-- // Calculate "Danger Score" based on how many waves we've sent. Up the danger every 3rd/6th wave. {{{
					local dangerScale = math.min(d.swarmCount / 20, 3) --Don't scale to the point where every wave is a boss
					local danger2 = (1 - math.min(d.swarmCount%2, 1))/2 --Add a bit of noise/variation based on wave.

					local danger3 = (1 - math.min(d.swarmCount%3, 1)) --STRONG on 3rds
					local danger5 = (1 - math.min(d.swarmCount%5, 1)) * (3.5) --BOSS on 5ths
					local dangerScore = 1 + dangerScale + danger3 + danger5 + danger2

					if dangerScale >= 3 and d.swarmCount % 8 == 0 then 
						--After we hit max danger, introduce lulls every now and then so players have an opportunity to get out and do things.
						dangerScore = 1
						swarmCost = swarmCost - 20
						cooldownAdd = 45
					end
					
					if dangerScore >= 3.5 then
						d.swarmDanger = jcms.NPC_DANGER_BOSS
						d.swarmBossCount = 1
					elseif dangerScore >= 2 then
						d.swarmDanger = jcms.NPC_DANGER_STRONG
					else
						d.swarmDanger = jcms.NPC_DANGER_FODDER
					end
				-- // }}}

				if missionTypeData then
					if missionTypeData.swarmCalcCost then 
						swarmCost = missionTypeData.swarmCalcCost(d, swarmCost) or swarmCost
					end
					if missionTypeData.swarmCalcDanger then
						d.swarmDanger = missionTypeData.swarmCalcDanger(d, swarmCost) or d.swarmDanger
					end
					if missionTypeData.swarmCalcBossCount then
						d.swarmBossCount = missionTypeData.swarmCalcBossCount(d, swarmCost) or d.swarmBossCount
					end
				end
				
				if swarmCost <= 0 then
					d.swarmNext = missionTime + 10
					return
				end

				if d.swarmCount % 5 == 0 then
					swarmCost = (swarmCost + 5)*1.5
					jcms.director_SayWarn(d)
				end
				
				local cooldown = (swarmCost^(7/8))*0.75 + (15 * (d.swarmDanger/3 + 1)) + cooldownAdd
				
				if d.missionData.evacuating then
					if swarmCost > 1 then
						swarmCost = swarmCost + 4
					end
					
					local cooldownDiv = 1.6
					if d.commander and d.commander.evacCooldownOverride then
						cooldownDiv = d.commander.evacCooldownOverride
					end
					cooldown = cooldown / cooldownDiv
				end

				
				if missionTypeData and missionTypeData.swarmCalcCooldown then
					cooldown = missionTypeData.swarmCalcCooldown(d, cooldown, swarmCost)
				end

				local difficulty_freq = math.Clamp(jcms.cvar_swarm_frequency:GetFloat(), 0.001, 5)
				local difficulty_size = math.Clamp(jcms.cvar_swarm_size:GetFloat(), 0, 5)

				d.swarmNext = missionTime + cooldown/difficulty_freq
				swarmCost = swarmCost * difficulty_size
				
				if swarmCost >= 20 then
					jcms.announcer_SpeakChance(0.75,jcms.ANNOUNCER_SWARM_BIG)
				elseif d.npcs_inCombat > 0 then
					jcms.announcer_SpeakChance(0.45, jcms.ANNOUNCER_SWARM)
				end

				local missionTimeThrottle = missionTime / 10
				if swarmCost > missionTimeThrottle then
					-- local str = string.format("Throttling swarm cost from %.2f to %.2f", swarmCost, missionTimeThrottle)
					-- jcms.printf(str)
					-- PrintMessage(HUD_PRINTCENTER, str)
					swarmCost = missionTimeThrottle
				end
				
				local queue = jcms.director_MakeQueue(d, swarmCost, d.swarmDanger)
				jcms.director_SpawnSwarm(d, queue)
			elseif jcms.director_ShouldForceSpawnNPCPlayers() then
				local npcPlayers = jcms.npc_GetPlayersToRespawn()

				if not d.npcPlayerRespawnTimes then
					d.npcPlayerRespawnTimes = {} -- In theory should prevent the same player from spawning in 2 different swarms
				end
				if not d.npcPlayerSlowRespawnTimes then --Ditto for softcap specifically. 
					d.npcPlayerSlowRespawnTimes = {}
				end

				local queue = {}
				for i, ply in ipairs(npcPlayers) do
					d.npcPlayerSlowRespawnTimes[ply] = d.npcPlayerSlowRespawnTimes[ply] or CurTime()

					if d.npcPlayerSlowRespawnTimes[ply] < CurTime() then
						table.insert(queue, jcms.npc_GeneratePlayerRespawnTable(ply))
						d.npcPlayerRespawnTimes[ply] = CurTime() + 5
						d.npcPlayerSlowRespawnTimes[ply] = CurTime() + 30 --softcap spawn delay is 30s
					end
				end

				jcms.director_SpawnSwarm(d, queue)
			end
		end
		
		function jcms.director_ThinkEncounters(d)
			if d.encounters then
				local patrollingNPCs = jcms.cvar_patrollingnpcs:GetBool()

				local difficulty_freq = math.Clamp(jcms.cvar_swarm_frequency:GetFloat(), 0.001, 5)
				local difficulty_size = math.Clamp(jcms.cvar_swarm_size:GetFloat(), 0, 5)

				local curNpcCount = #d.npcs
				
				if curNpcCount > jcms.cvar_softcap:GetInt() then
					return
				end
				
				if (CurTime() - d.encounterTriggerLast) >= ((patrollingNPCs and 2.75 or 6)/difficulty_freq) then
					local sweepers = jcms.GetAliveSweepers()
					
					-- for i, enc in ipairs(d.encounters) do
					-- 	debugoverlay.Sphere(enc.pos, enc.rad, 0.5, Color(200*(enc.danger-1), 255, 0))
					-- end
					
					for i=#d.encounters, 1, -1 do
						local enc = d.encounters[i]
						if curNpcCount + math.max(enc.npcCount*difficulty_size) >= 77 then
							continue
						end
						
						local encPos = enc.pos
						
						local mustTrigger = false
						if patrollingNPCs then
							-- Encounters are triggered from further away and the player isn't revealed to the NPCs
							for j, ply in ipairs(sweepers) do
								local rad = enc.rad
								local dist2 = encPos:DistToSqr(ply:WorldSpaceCenter())

								if (dist2 <= (enc.rad*3)^2 and not ply:VisibleVec(encPos)) then
									local inPVS = ply:TestPVS(encPos)
									if inPVS then
										mustTrigger = true
										break
									elseif dist2 <= (enc.rad*1.25)^2 then
										mustTrigger = true
										break
									end
								end
							end
						else
							-- Classic encounters
							for j, ply in ipairs(sweepers) do
								local rad = enc.rad
								local dist2 = encPos:DistToSqr(ply:WorldSpaceCenter())
								if (dist2 <= rad^2)
								or (dist2 <= (rad*1.5)^2 and ply:TestPVS(encPos)) 
								or (dist2 <= (rad*2.5)^2 and ply:VisibleVec(encPos)) then
									mustTrigger = true
									break
								end
							end
						end

						if mustTrigger then
							local worked = jcms.director_TriggerEncounter(d, enc)
							table.remove(d.encounters, i)
						end
					end
				end
			end
		end
		
		function jcms.director_TriggerEncounter(d, enc)
			local difficulty_size = math.Clamp(jcms.cvar_swarm_size:GetFloat(), 0, 5)
			local difficulty_warn = math.Clamp(jcms.cvar_swarm_warning:GetFloat(), 0, 30)

			d.encounterTriggerLast = CurTime()
			d.swarmNext = (d.swarmNext or 0) + 2
			
			local areas = navmesh.Find(enc.pos, enc.rad + 100, 128, 128)
			local npcCount = math.ceil( (tonumber(enc.npcCount) or 0)*difficulty_size )
			local npcCountRemaining = npcCount
			
			local allVectors = {}
			if npcCount > 0 then
				if #areas > 3 then
					table.Shuffle(areas)
					for i=1, 3 do
						local area = areas[i]
						local usingCount = math.min(npcCountRemaining, math.ceil(npcCount / 3))
						table.Add( allVectors, jcms.director_PackSquadVectors(jcms.mapgen_AreaPointAwayFromEdges(area, 80), usingCount, 100) )
						npcCountRemaining = npcCountRemaining - usingCount
						if npcCountRemaining <= 0 then
							break
						end
					end
				elseif #areas > 0 then
					for i, area in ipairs(areas) do
						local area = areas[i]
						local usingCount = math.min(npcCountRemaining, math.ceil(npcCount / 3))
						table.Add( allVectors, jcms.director_PackSquadVectors(jcms.mapgen_AreaPointAwayFromEdges(area, 72), usingCount, 95) )
						npcCountRemaining = npcCountRemaining - usingCount
						if npcCountRemaining <= 0 then
							break
						end
					end
				else
					-- Shitty encounter position
					table.Add( allVectors, jcms.director_PackSquadVectors(enc.pos, npcCount, 92) )
				end
			end
			
			local queue = jcms.director_MakeQueue(d, tonumber(enc.cost) or npcCount + 2.5, enc.danger or jcms.NPC_DANGER_FODDER)
			local delay = (tonumber(enc.delay) or 5) + difficulty_warn
			
			for i=1, math.min(#queue, #allVectors) do
				local enemyType, pos = queue[i], allVectors[i]
				if isstring(enemyType) then
					jcms.npc_SpawnFancy(enemyType, pos, delay + i * 0.1)
				end
			end
			
			return #queue >= 1 and #allVectors >= 1
		end

		function jcms.director_Loop()
			local d = jcms.director

			if d and d.fullyInited then
				if d.gameover then return end
				local livingPlayers, deadPlayers, evacCount, teamAlivePlayers = jcms.director_PlayersAnalyze(d)
				jcms.director.livingPlayers = livingPlayers
				jcms.director.deadPlayers = deadPlayers
				local teamRespawns = jcms.director_RecalculateRespawnCounts() --Set the NW integer for each team's respawn count

				local aliveTeams = {} --Which team is alive (*only* useful if there's one, otherwise returns highest index team) 
				local aliveTeamCount = 0
				for pvpTeam=1, 8, 1 do
					if (not jcms.director_IsSuddenDeath() and teamRespawns[pvpTeam] or 0) + (teamAlivePlayers[pvpTeam] or 0) > 0 and #jcms.PVPGetTeamPlayers( pvpTeam ) > 0 then --Has respawns or alive players, has actual members.
						aliveTeamCount = aliveTeamCount + 1
						aliveTeams[pvpTeam] = true
					else
						aliveTeams[pvpTeam] = false
					end
				end

				--Everyone dead or everyone evacuated
				if (not d.debug) and ( (aliveTeamCount <= ( (jcms.util_IsPVP() and not jcms.cvar_pvpdebug:GetBool()) and 1 or 0)) or (livingPlayers == 0 and deadPlayers == 0) ) then
					local victory = evacCount > 0

					local missionTime = jcms.director_GetMissionTime()
					local grace = missionTime < ( game.SinglePlayer() and 5 or 60 )

					if (not d.gameover) and (victory or not grace) then
						d.gameover = true
						d.victory = victory
						jcms.mission_End(victory, aliveTeams)
					end
				else
					jcms.director_AnalyzeNPCs(d)
					
					local objectives = jcms.mission_GetObjectives()
					local newHash = util.SHA256( objectives and util.TableToJSON(objectives) or "" )
					
					if newHash ~= d.objectivesHash then
						d.objectivesHash = newHash
						
						if objectives then
							jcms.net_ShareMissionData(objectives)
						end
					end

					if d.commander and d.commander.think then 
						d.commander:think()
					end
					
					jcms.director_ThinkMission(d)
					jcms.director_ThinkEncounters(d)
					jcms.director_ThinkSwarm(d)
					jcms.director_ThinkTags(d)
					jcms.director_ThinkPvp(d) --Doesn't do anything unless pvpMode is on

					jcms.director_DebrisClear(d)
				end
			else
				game.GetWorld():SetNWInt("jcms_respawncount", 0)
			end
		end

		timer.Create("jcms_Director", 1, 0, function()

			local s, err = xpcall( jcms.director_Loop, function(err)
				--If we error this gets called.
				if debug.traceback then --Wiki lists traceack as deprecated, but the non-deprecated function doesn't do what I want. This is in-case they ever remove it.
					return err .. "\n" .. debug.traceback()
				end
				return err
			end)

			if not s then
				if type(err) == "string" then
					local msg = "Director LUA error! See server console for details."
					PrintMessage(HUD_PRINTTALK, "[Map Sweepers] " .. msg)
					ErrorNoHaltWithStack(msg .. "\n" .. err)
				else
					local msg = "Unknown director LUA error!"
					PrintMessage(HUD_PRINTTALK, "[Map Sweepers] " .. msg)
					ErrorNoHalt(msg)
				end
			end
		end)
	
	-- }}}

	-- Stats {{{

		function jcms.director_GetPostMissionStats()
			local d = jcms.director
			assert(d, "Can't build post-mission stats outside of any mission")

			if not d.postMissionStats then
				local t = {}

				t.missionTime = jcms.director_GetMissionTime()
				t.players = {}

				local plyCount = table.Count(d.cachedNicknames)
				for sid64, nickname in pairs(d.cachedNicknames) do
					local ply = player.GetBySteamID64(sid64)
					if not ply then continue end
					
					local pd = {}

					pd.sid64 = sid64
					pd.nickname = nickname
					pd.evacuated = IsValid(ply) and d.evacuated[ply] or d.lockstates[sid64] == "evacuated"
					
					pd.wasSweeper = pd.evacuated or d.lockstates[sid64] == "sweeper" or d.kills_direct[sid64]>0 or d.kills_defenses[sid64]>0 or d.kills_explosions[sid64]>0 or d.deaths_sweeper[sid64]>0 or d.ordersUsedCounts[sid64]>0
					pd.wasNPC = d.lockstates[sid64] == "npc" or d.kills_sweepers[sid64]>0 or d.kills_turrets[sid64]>0 or d.deaths_npc[sid64]>0

					pd.class = ply:GetNWString("jcms_desiredclass", "infantry")
					pd.pvpTeam = ply:GetNWInt("jcms_pvpTeam", -1)
					if pd.wasSweeper then
						pd.kills_direct = d.kills_direct[sid64]
						pd.kills_defenses = d.kills_defenses[sid64]
						pd.kills_explosions = d.kills_explosions[sid64]
						pd.kills_friendly = d.kills_friendly[sid64]
						pd.kills_pvp = d.kills_pvp[sid64]
						pd.deaths_sweeper = d.deaths_sweeper[sid64]
						pd.ordersUsedCounts = d.ordersUsedCounts[sid64]
					end

					if pd.wasNPC then
						pd.kills_sweepers = d.kills_sweepers[sid64]
						pd.kills_turrets = d.kills_turrets[sid64]
						pd.deaths_npc = d.deaths_npc[sid64]
					end

					table.insert(t.players, pd)
				end

				d.postMissionStats = t
			end

			return d.postMissionStats
		end

		function jcms.director_stats_Ensure(d, ply)
			if d and IsValid(ply) then
				local sid64 = ply:IsBot() and ("BOT_" .. ply:Nick()) or ply:SteamID64()
				
				d.cachedNicknames[ sid64 ] = ply:Nick()
				if d.kills_direct[ sid64 ] == nil then
					d.kills_direct[ sid64 ] = 0
					d.kills_defenses[ sid64 ] = d.kills_defenses[ sid64 ] or 0
					d.kills_explosions[ sid64 ] = d.kills_explosions[ sid64 ] or 0
					d.kills_friendly[ sid64 ] = d.kills_friendly[ sid64 ] or 0
					d.kills_pvp[ sid64 ] = d.kills_pvp[ sid64 ] or 0
					d.deaths_sweeper[ sid64 ] = d.deaths_sweeper[ sid64 ] or 0
					d.ordersUsedCounts[ sid64 ] = d.ordersUsedCounts[ sid64 ] or 0

					d.kills_sweepers[ sid64 ] = d.kills_sweepers[ sid64 ] or 0
					d.kills_turrets[ sid64 ] = d.kills_turrets[ sid64 ] or 0
					d.deaths_npc[ sid64 ] = d.deaths_npc[ sid64 ] or 0
				end

				return true, sid64
			else
				return false
			end
		end

		function jcms.director_stats_SetLockedState(d, ply, state, pvpTeam)
			if d and (not d.gameover) and IsValid(ply) then
				local sid64 = ply:IsBot() and ("BOT_" .. ply:Nick()) or ply:SteamID64()
				-- "sweeper": We spawned in at least once. Upon rejoining we'll be dead, but will be able to respawn as a sweeper or an NPC.
				-- "evacuated": We are still a sweeper, but we can't respawn. We can go NPC and still be credited as a sweeper.
				-- "npc": We've chosen to be an NPC. We can't respawn as a sweeper, and we won't be credited as one.
				d.lockstates[ sid64 ] = state
				if pvpTeam then
					d.lockpvpteams[ sid64 ] = pvpTeam
				end

				jcms.director_stats_Ensure(d, ply)
			end
		end

		function jcms.director_stats_ClassifyKill(attacker, inflictor, dmgType)
			if IsValid(inflictor) then
				if attacker == inflictor then
					return (dmgType and bit.band(dmgType, DMG_BLAST) > 0) and 2 or 0 -- Explosive kill or direct kill
				else
					local inflictorClass = inflictor:GetClass()

					if inflictor:IsWeapon() then
						return 0 -- Direct kill
					elseif dmgType and bit.band(dmgType, DMG_BLAST) > 0 then
						return 2 -- Explosive kill
					elseif inflictor.jcms_owner == attacker then
						return 1 -- Defenses kill
					end
				end
			end

			return 0 -- Direct kill anyway.
		end

		function jcms.director_stats_GetLockedState(d, ply)
			if d and IsValid(ply) then
				local sid64 = ply:IsBot() and ("BOT_" .. ply:Nick()) or ply:SteamID64()
				return d.lockstates[ sid64 ], d.lockpvpteams[ sid64 ]
			end
		end

		function jcms.director_stats_AddKillForSweeper(ply, type)
			-- type=1: Defenses
			-- type=2: Explosives
			-- type=3: Friendly Kill
			-- type=4: PVP
			-- Anything else: Direct kill
			local works, sid64 = jcms.director_stats_Ensure(jcms.director, ply)

			if works then
				local key = "kills_direct"
				if type == 1 then
					key = "kills_defenses"
				elseif type == 2 then
					key = "kills_explosions"
				elseif type == 3 then
					key = "kills_friendly"
				elseif type == 4 then
					key = "kills_pvp"
				end

				jcms.director[key][sid64] = (tonumber(jcms.director[key][sid64]) or 0) + 1
			end
		end

		function jcms.director_stats_AddDeathForSweeper(ply)
			local works, sid64 = jcms.director_stats_Ensure(jcms.director, ply)
			if works then
				jcms.director.deaths_sweeper[sid64] = (tonumber(jcms.director.deaths_sweeper[sid64]) or 0) + 1
			end
		end

		function jcms.director_stats_AddOrdersUsed(ply)
			local works, sid64 = jcms.director_stats_Ensure(jcms.director, ply)
			if works then
				jcms.director.ordersUsedCounts[sid64] = (tonumber(jcms.director.ordersUsedCounts[sid64]) or 0) + 1
			end
		end

		function jcms.director_stats_AddKillForNPC(ply, type)
			-- type=1: Turret kill
			-- Anything else: Sweeper kill
			local works, sid64 = jcms.director_stats_Ensure(jcms.director, ply)
			if works then
				local key = "kills_sweepers"
				if type == 1 then
					key = "kills_turrets"
				end

				jcms.director[key][sid64] = (tonumber(jcms.director[key][sid64]) or 0) + 1
			end
		end

		function jcms.director_stats_AddDeathForNPC(ply)
			local works, sid64 = jcms.director_stats_Ensure(jcms.director, ply)
			if works then
				jcms.director.deaths_npc[sid64] = (tonumber(jcms.director.deaths_npc[sid64]) or 0) + 1
			end
		end

	-- }}}

-- // }}}
