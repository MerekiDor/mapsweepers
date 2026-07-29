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

-- // Types {{{

	-- If you want to make an addon for Map Sweepers and add custom mission types:
	-- Use a "MapSweepersReady" hook in your addon and make a jcms.missions.<your_mission_name> table from there.
	-- You should do it both on server and on client - for logic and pre-mission information for players, respectively.
	-- Example:
	--[[
	
		if SERVER then
			hook.Add("MapSweepersReady", "CustomMission", function()
				jcms.missions.custom = {
					...
				}
			end)
		end
		
		if CLIENT then
			hook.Add("MapSweepersReady", "CustomMission", function()
				jcms.missions.custom = {
					tags = { ... },
					faction = "antlion"
				}
			end)
		end
	
	--]]
	
	-- [!!!] IMPORTANT [!!!]
	-- Do NOT put underscores in your mission key names. They're strictly lowercase latin characters.
	
	jcms.missions = {}
	function jcms.mission_IsBossMission(winstreak)
		return jcms.runprogress.winstreak > 0 and jcms.runprogress.winstreak % 5 == 0
	end

	function jcms.mission_GetWeightedTypes(pvpOnly, isBoss) --Gets weights for all missions based on previous missions/factions
		local misHistoryWeights, facHistoryWeights = jcms.runprogress_GetMissionHistoryWeights()
		
		local finalMisWeights = {}
		for mission in pairs(jcms.missions) do 
			local missionData = jcms.missions[ mission ]
			if (not pvpOnly or missionData.pvpAllowed ) and ((not not isBoss) == (not not missionData.bossMission)) then
				--Combined weight based on mission weight & faction weight.
				--"Any" will never be in this table, so it'll always be 1.
				finalMisWeights[mission] = (misHistoryWeights[mission] or 1) * (facHistoryWeights[missionData.faction] or 1)
			end
		end

		if table.Count(finalMisWeights) == 0 then --Fall-back if no valid missions (no boss missions)
			local missionData = jcms.missions[ mission ]
			if (not pvpOnly or missionData.pvpAllowed ) and not missionData.bossMission then
				finalMisWeights[mission] = (misHistoryWeights[mission] or 1) * (facHistoryWeights[missionData.faction] or 1)
			end
		end

		return finalMisWeights
	end

	--DEPRECATED
	function jcms.mission_GetRandomType(except, pvpOnly, isBoss)
		local keys = {}

		for mission in pairs(jcms.missions) do
			--Not our exclude mission (unless this is a boss round), out of pvp or a pvp-allowed mission, is a boss mission if we're looking for it, not a boss mission otherwise
			if (mission ~= except or isBoss) and (not pvpOnly or jcms.missions[ mission ].pvpAllowed ) and ((not not isBoss) == (not not jcms.missions[ mission ].bossMission)) then --not not ensures both are bools (they can be nil)
				table.insert(keys, mission)
			end
		end

		if #keys == 0 then --Fall-back if no valid missions (no boss, no except, still respect pvp) 
			for mission in pairs(jcms.missions) do
				if (not pvpOnly or jcms.missions[ mission ].pvpAllowed ) and not jcms.missions[ mission ].bossMission then
					table.insert(keys, mission)
				end
			end
		end
		
		return keys[ math.random(1, #keys) ]
	end

-- // }}}

-- // Logic {{{

	function jcms.mission_Start(missionType, factionType)
		jcms.mission_generating = true
		local co = coroutine.create( function()
			math.randomseed( os.time() - CurTime() * ( math.pi / 4 ) )

			local data = assert(jcms.missions[ missionType ], "invalid mission type: " .. tostring(missionType))
			
			if data.faction == "any" then
				assert(jcms.factions[ factionType ], "invalid faction: " .. tostring(factionType))
			else
				factionType = data.faction
			end

			game.CleanUpMap()
			jcms.RecolorAllDollies()
			jcms.ReplaceAllCrates()
			jcms.DisableThumpers()
			jcms.SetDoorReturns()
			jcms.ForceOpenFuncDoors()
			if jcms.cvar_performanceMode:GetBool() then 
				jcms.ClearTinyProps()
				jcms.ClearWindows()
			end
			
			game.GetWorld():SetNWString("jcms_missiontype", missionType)
			game.GetWorld():SetNWString("jcms_missionfaction", factionType)

			jcms.director_Prepare( factionType )
			jcms.director.missionType = missionType
			jcms.director.encounterTriggerLast = jcms.director.missionStartTime + 10
			jcms.director.phrasesOverride = data.phrasesOverride
		
			local success, genRtn = pcall(jcms.mapgen_FromMission, data)
			if success then
				jcms.runprogress_SetLastMission()
				jcms.director.fullyInited = true

				if jcms.util_IsPVP() then
					for teamId=1, 2 do
						for i=1, math.ceil(player.GetCount()/2) do --TODO: jcms.util_getUsedTeams
							jcms.director_InsertRespawnVector(jcms.director_PvpDynamicRespawn, teamId)
						end
					end

					for k, order in pairs(jcms.orders) do
						if order.pvpBlacklisted then
							jcms.net_RemoveOrder(k)
						elseif order.pvpExclusive then
							jcms.net_SendOrder(k, order)
						end
					end
				else
					--Suboptimal, but this works I guess.
					for k, order in pairs(jcms.orders) do
						if order.pvpBlacklisted then
							jcms.net_SendOrder(k, order)
						elseif order.pvpExclusive then
							jcms.net_RemoveOrder(k)
						end
					end
				end
				
				-- // Mission-Specific Orders {{{
					for k, order in pairs(jcms.orders) do 
						if order.missionSpecific then 
							jcms.orders[k] = nil
							jcms.net_RemoveOrder(k)
						end
					end

					if data.orders then
						for k, order in pairs(data.orders) do 
							jcms.orders[k] = order
							jcms.net_SendOrder(k, order)
						end
					end
				-- // }}}

				if jcms.director.commander and jcms.director.commander.placePrefabs then 
					jcms.director.commander:placePrefabs(data)
				end
				
				jcms.orders_ClearAllCooldowns()
				jcms.net_SendMissionBeginning()
				
				if not jcms.validMapOptions then
					jcms.validMapOptions = jcms.generateValidMapOptions()
				end
				
				if data.orders and table.Count(data.orders) > 0 then
					timer.Simple(10, function()
						for i, ply in ipairs(jcms.GetLobbySweepers()) do
							jcms.director_TryShowTip(ply, jcms.HINT_UNIQUEORDERS)
						end
					end)
				end
			else
				jcms.director = nil
				ErrorNoHalt("Mission generation failed!\n"..tostring(genRtn))
				PrintMessage(HUD_PRINTTALK, "[Map Sweepers] Mission failed to generate, switching mission as a fall-back.")
				jcms.mission_Randomize()
			end

			game.GetWorld():SetNWFloat("jcms_mapgen_progress", 1)
			game.GetWorld():SetNWFloat("jcms_missionStartTime", CurTime())
			return true
		end)

		timer.Create( "jcms_mission_run", 0.01, 0, function()
			local success, shouldEnd = coroutine.resume(co)
			if not success then 
				ErrorNoHalt(shouldEnd) --"shouldEnd" is actually the error string in this context, the variable's just named with the other case in-mind.
				jcms.mission_generating = false
			end

			if shouldEnd then 
				jcms.mission_generating = false
				timer.Remove("jcms_mission_run")
				game.GetWorld():SetNWFloat("jcms_mapgen_progress", 1)

				game.GetWorld():SetNWFloat("jcms_difficulty", jcms.runprogress_GetDifficulty())
				game.GetWorld():SetNWInt("jcms_winstreak", jcms.util_IsPVP() and 0 or jcms.runprogress.winstreak)
			end
		end)
	end

	function jcms.mission_StartFromCVar() -- Artifact name of the function.
		jcms.mission_Start( jcms.util_GetMissionType(),  jcms.util_GetMissionFaction() )
	end

	function jcms.mission_Clear()
		game.GetWorld():SetNWFloat("jcms_mapgen_progress", -1)
		jcms.director = nil

		for i, ply in ipairs(player.GetAll()) do
			jcms.playerspawn_RespawnAs(ply)
			ply:SetNWInt("jcms_desiredteam", 0)
			ply:SetNWBool("jcms_evacuated", false)
			ply:SetNWBool("jcms_ready", false)
			ply:SendLua("local o=jcms.offgame if IsValid(o) then o:Remove() end")
			ply.jcms_classAtEvac = nil
			ply.jcms_isNPC = nil
		end
		
		jcms.mission_Randomize()
		jcms.mission_ResetStartTimer()
		game.CleanUpMap()

		local goodForPVP = jcms.util_IsPVPAllowed()
		local pvpAllowed = jcms.cvar_pvpallowed:GetInt()

		if pvpAllowed == 0 then
			jcms.pvp_SetEnabled(false)
		elseif pvpAllowed == 2 then
			jcms.pvp_SetEnabled(true)
		elseif pvpAllowed == 1 then
			if goodForPVP then
				jcms.pvp_StartVote(30)
			elseif jcms.util_IsPVP() then
				jcms.pvp_SetEnabled(false)
			end
		end
	end

	function jcms.mission_Randomize()
		local missionWeights = jcms.mission_GetWeightedTypes(jcms.util_IsPVP(), jcms.mission_IsBossMission())

		local newType = jcms.util_ChooseByWeight(missionWeights)
		local data = assert(jcms.missions[ newType ], "error randomizing mission type, picked an invalid one: '" .. tostring(newType) .. "'")

		game.GetWorld():SetNWString("jcms_missiontype", newType)
		if data.faction == "any" then --Choose a random faction for universals
			local misHistoryWeights, facHistoryWeights = jcms.runprogress_GetMissionHistoryWeights() --unnecessary duplicate work but this runs rarely so idc
			
			local finalFacWeights = {}
			for i, faction in ipairs(jcms.factions_GetOrder()) do
				finalFacWeights[ faction ] = facHistoryWeights[faction] or 1 
			end

			local newFaction = jcms.util_ChooseByWeight(finalFacWeights)
			game.GetWorld():SetNWString("jcms_missionfaction", newFaction)
		else
			game.GetWorld():SetNWString("jcms_missionfaction", data.faction)
		end
	end

	function jcms.mission_GenerateVoteOptions()
		local maps = {}

		local excludeCurrent = jcms.cvar_map_excludecurrent:GetBool()
		local numberOfOptions = math.Clamp(jcms.cvar_map_votecount:GetInt(), 1, 15)

		if not excludeCurrent then
			maps[game.GetMap()] = false
		end

		local mapDict = {}
		local isWhitelist = jcms.cvar_map_iswhitelist:GetBool()
		for i, map in ipairs(jcms.cvar_map_list:GetString():Split(",")) do
			local trimmed = map:Trim():lower()
			if trimmed ~= "" then
				mapDict[ trimmed ] = true
			end
		end

		local weightedMaps = {}
		for i, map in ipairs(jcms.validMapOptions) do
			if isWhitelist == (not not mapDict[map]) then -- Both are true, or both are false.
				weightedMaps[map] = jcms.mapWeights[map] or 1
			end
		end

		for i=1, numberOfOptions do 
			local chosenMap = jcms.util_ChooseByWeight(weightedMaps)
			if not chosenMap then break end

			weightedMaps[chosenMap] = nil
			maps[chosenMap] = false
		end

		if (table.Count(maps) == 0) then -- Failsafe
			maps[game.GetMap()] = false
		end

		-- Get WSID of the maps
		if not game.SinglePlayer() then
			for _, addon in ipairs( engine.GetAddons() ) do
				if addon.wsid and addon.mounted and addon.title then
					local files = file.Find( "maps/*.bsp", addon.title )
					for _, fil in ipairs( files ) do
						local mapName = string.StripExtension(fil)
						if maps[mapName] ~= nil then
							maps[mapName] = addon.wsid
						end
					end
				end
			end
		end

		return maps
	end

	function jcms.mission_End(victory, aliveTeams)
		if jcms.specialmap_HandleMissionEnd then
			local performNormalEnding = jcms.specialmap_HandleMissionEnd(victory, aliveTeams)

			if not performNormalEnding then
				return
			end
		end

		jcms.leaderboard_RoundEnd(jcms.util_IsPVP(), victory, aliveTeams)

		-- Voting {{{
			jcms.director.votes = {}
			
			if game.SinglePlayer() then
				jcms.director.vote_time = CurTime() + 604800
			else
				jcms.director.vote_time = CurTime() + 25
			end
			
			jcms.director.vote_maps = jcms.mission_GenerateVoteOptions()
		-- }}}

		-- Sending info {{{
			local postMissionStats = jcms.director_GetPostMissionStats()
			if jcms.util_IsPVP() then
				for teamId, alive in ipairs(aliveTeams) do
					jcms.net_SendMissionEnding(alive, nil, teamId)
				end
			else
				jcms.net_SendMissionEnding(victory)
			end
		-- }}}

		-- Rewards & Progress {{{
			if victory and not(jcms.serverExtension_forcedEvac or jcms.util_IsPVP()) then
				jcms.runprogress_Victory()

				for i, pd in ipairs( postMissionStats.players ) do
					local sid64 = pd.sid64

					local bonuses = {}
					if pd.wasSweeper then
						table.insert(bonuses, {
							name = "victory", cash = jcms.cvar_cash_victory:GetInt()
						})
						
						if pd.evacuated then
							table.insert(bonuses, {
								name = "evac", cash = jcms.cvar_cash_evac:GetInt()
							})
						end

						if jcms.director.npcrecruits and jcms.director.npcrecruits > 0 then
							table.insert(bonuses, {
								name = "clerks", cash = math.min( jcms.director.npcrecruits, jcms.cvar_cash_maxclerks:GetInt() ), format = jcms.director.npcrecruits
							})
						end
					end

					local reward = jcms.cash_CashFromBonuses(bonuses)
					local oldStartingCash = jcms.runprogress_GetStartingCash(sid64)
					jcms.runprogress_AddStartingCash(sid64, reward)
					local newStartingCash = jcms.runprogress_GetStartingCash(sid64)

					local ply = player.GetBySteamID64(sid64)
					if IsValid(ply) then
						jcms.net_SendCashBonuses(ply, bonuses, oldStartingCash, newStartingCash)
					end
				end
			elseif not(jcms.serverExtension_forcedEvac and victory) and not jcms.util_IsPVP() then
				for i, pd in ipairs( postMissionStats.players ) do
					local sid64 = pd.sid64

					local oldStartingCash = jcms.runprogress_GetStartingCash(sid64)
					local newStartingCash = jcms.cvar_cash_start:GetInt()

					local bonuses = {}
					if oldStartingCash ~= newStartingCash then
						bonuses[1] = { name = "failure", cash = newStartingCash - oldStartingCash }
					end

					local ply = player.GetBySteamID64(sid64)
					if IsValid(ply) then
						jcms.net_SendCashBonuses(ply, bonuses, oldStartingCash, newStartingCash)
					end
				end

				jcms.runprogress_Reset()
			end
		-- }}}

		-- Updating players {{{
			for i, ply in ipairs(player.GetAll()) do
				ply:SetNWInt("jcms_desiredteam", 0)
				ply:SetNWBool("jcms_ready", false)
				ply:SetNWInt("jcms_pvpTeam", -1)

				if victory then
					jcms.statistics_AddMissionStatus(ply, jcms.director.missionType, jcms.director.faction, true)
				end
			end
		-- }}}

		-- Announcer {{{
			if not jcms.util_IsPVP() then
				timer.Simple(2, function()
					if victory then 
						jcms.announcer_Speak(jcms.ANNOUNCER_VICTORY)
					else
						jcms.announcer_Speak(jcms.ANNOUNCER_FAILED)
					end
				end)
			end
		-- }}}
		
		jcms.serverExtension_forcedEvac = false
		jcms.serverExtension_suddenDeath = false
		
		jcms.leaderboard_UpdateCanUseWinstreakToken()
	end

	function jcms.mission_SetStartDelay(delay)
		game.GetWorld():SetNWFloat("jcms_missionStartTime", math.ceil(CurTime()) + math.max(0, tonumber(delay) or 0))
	end

	function jcms.mission_ResetStartTimer()
		game.GetWorld():SetNWFloat("jcms_missionStartTime", 0)
	end

	hook.Add("Think", "jcms_PreGameLogic", function()
		local isOngoing = (jcms.director and jcms.director.fullyInited) or false

		if game.GetWorld():GetNWBool("jcms_ongoing", false) ~= isOngoing then
			game.GetWorld():SetNWBool("jcms_ongoing", isOngoing)
		end

		if isOngoing then
			-- The game is ongoing. We can spawn the players.
			game.GetWorld():SetNWFloat("jcms_mapgen_progress", -1)

			if not jcms.director.gameover then
				for i, ply in player.Iterator() do
					if ply:GetObserverMode() == OBS_MODE_FIXED then
						local desiredTeam = ply:GetNWInt("jcms_desiredteam", 0)
						local ready = ply:GetNWBool("jcms_ready", false) or game.SinglePlayer()

						if ready then
							if desiredTeam == 1 then
								jcms.playerspawn_RespawnAs(ply, "sweeper")
								jcms.statistics_AddMissionStatus(ply, jcms.director.missionType, jcms.director.faction, false)
								if not jcms.util_IsPVP() then
									ply.jcms_isNPC = nil
								else
									ply.jcms_isNPC = true
								end

								jcms.director_stats_SetLockedState(jcms.director, ply, "sweeper", ply:GetNWInt("jcms_pvpTeam", -1))
								if jcms.director_GetMissionTime() > 8 then
									jcms.net_SendRespawnEffect(ply)
									jcms.announcer_Speak(jcms.ANNOUNCER_JOIN)
								end

								jcms.leaderboard_PlayerDeployed(ply)
							elseif desiredTeam == 2 then
								jcms.playerspawn_RespawnAs(ply, "spectator")
								ply.jcms_isNPC = true

								jcms.director_stats_SetLockedState(jcms.director, ply, "npc")
								if jcms.director_GetMissionTime() > 8 then
									jcms.net_SendRespawnEffect(ply)
								end

								jcms.leaderboard_PlayerDeployed(ply)
							end
						end
					end
				end
			end

		else
			-- No ongoing mission

			local potentialMaxPlayers = 0
			local readySweepers = 0

			for i, ply in ipairs( player.GetAll() ) do
				local desiredTeam = ply:GetNWInt("jcms_desiredteam", 0)
				local ready = ply:GetNWBool("jcms_ready", false)

				if isnumber(desiredTeam) and desiredTeam <= 1 then
					potentialMaxPlayers = potentialMaxPlayers + 1
				end

				if isnumber(desiredTeam) and desiredTeam == 1 and ready then
					readySweepers = readySweepers + 1
				end
			end

			local startTime = jcms.util_GetMissionStartTime()
			local remainingTime = jcms.util_GetTimeUntilStart()
			local timerIsGoing = jcms.util_IsGameTimerGoing()

			if readySweepers >= potentialMaxPlayers and remainingTime > 0 then
				jcms.mission_SetStartDelay(0) -- Instantly start
			elseif readySweepers >= math.max(2, math.ceil(potentialMaxPlayers/2)) and (remainingTime > 10 or not timerIsGoing) then
				jcms.mission_SetStartDelay(10)
			elseif readySweepers > 0 and not timerIsGoing then
				jcms.mission_SetStartDelay(60 + 30) -- 1:30
			elseif timerIsGoing and remainingTime > 5 and readySweepers == 0 then
				jcms.mission_ResetStartTimer()
			end

			if timerIsGoing and CurTime() >= startTime and not jcms.mission_generating then
				game.GetWorld():SetNWFloat("jcms_mapgen_progress", 0.01)
				jcms.mission_StartFromCVar()
			end
		end
	end)

-- // }}}

-- // Info {{{

	function jcms.mission_GetObjectives()
		if jcms.serverExtension_forcedEvac then 
			return jcms.mission_GenerateEvacObjective()
		end

		local d = jcms.director
		if d then
			local data = assert(jcms.missions[ d.missionType ], "invalid mission type: " .. tostring(arg))
			return data.getObjectives(d.missionData)
		else
			return {}    
		end
	end
	
	function jcms.mission_GenerateEvacObjective(overrideGoToEvacMessage)
		local d = jcms.director
		
		if jcms.util_IsPVP() then
			local missionData = d.missionData
			if missionData and not missionData.evacTip then
				jcms.net_SendTip("all", true, overrideGoToEvacMessage or "#jcms.gotoevac_pvp", 1)
				missionData.evacTip = 0
			end

			return {
				{type = "j", 0,0},
				{type = "die", 0,0}
			}
		end

		local totalCount = 0
		local evacCount = 0
		local evacChargePercent = 1
		local evacIsCharging = false

		local secondsUntilSuddenDeath = d.suddenDeathTime and math.max(0, d.suddenDeathTime - jcms.director_GetMissionTime() )
		
		for ply, evacuated in pairs(d.evacuated) do
			if IsValid(ply) then
				totalCount = totalCount + 1
				evacCount = evacCount + 1
			end
		end
		
		for i, ply in ipairs(team.GetPlayers(1)) do
			if ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE and not d.evacuated[ply] then
				totalCount = totalCount + 1
			end
		end
		
		local missionData = d.missionData
		if missionData then
			if IsValid(d.evacEnt) then
				evacChargePercent = d.evacEnt:GetCharge() / d.evacEnt:GetMaxCharge()
				evacIsCharging = d.evacEnt:GetCanCharge()
			end

			if not missionData.evacTip then
				jcms.net_SendTip("all", true, overrideGoToEvacMessage or "#jcms.gotoevac", 1)
				missionData.evacTip = 0
			elseif (missionData.evacTip == 0) and evacChargePercent >= 1 then
				jcms.net_SendTip("all", true, "#jcms.evaccharged", 1)
				missionData.evacTip = true
			end
		end

		local objectives = {}

		if evacChargePercent >= 1 then
			objectives[1] = { type = "evac", progress = evacCount, total = totalCount, completed = evacCount > 0  }
		else
			objectives[1] = { type = "evaccharge", progress = evacChargePercent*100, total = 100, percent = true, completed = evacIsCharging }
		end

		if secondsUntilSuddenDeath then
			if secondsUntilSuddenDeath > 0 then
				objectives[2] = { type = "suddendeath", progress = secondsUntilSuddenDeath, style = 1 }
			else
				objectives[2] = { type = "die" }

				if missionData and not missionData.suddenDeathTip then
					jcms.net_SendTip("all", true, "#jcms.suddendeathtip", 1)
					missionData.suddenDeathTip = true
				end
			end
		end

		return objectives
	end

-- // }}}

-- // Events {{{

	function jcms.mission_PickEvacLocation()
		local points = {}

		local zone = jcms.mapdata.zoneList[jcms.mapdata.largestZone]
		table.Shuffle(zone)

		for i, area in ipairs(zone) do 
			if not jcms.mapgen_ValidArea(area) then continue end
			if not IsValid(area) or area:GetSizeX() < 250 or area:GetSizeY() < 250 then continue end

			local center = area:GetCenter()
			local ply, dist = jcms.director_PickClosestPlayer(center)
			if dist < 500 then continue end
			table.insert(points, center)
		end

		return points[ math.random(1, #points) ] or Vector(0, 0, 0)
	end

	function jcms.mission_DropEvac(pos, timeToWaitOverride)
		local d = jcms.director
		if d and not jcms.util_IsPVP() then
			if IsValid(d.evacEnt) then
				d.evacEnt:Remove()
			end

			local evac = ents.Create("jcms_evac")
			evac:SetPos(pos)
			--evac:DropToFloor()
			evac:Spawn()

			if timeToWaitOverride then
				evac:SetMaxCharge(math.floor(timeToWaitOverride))
			end
			
			d.evacEnt = evac
			return evac
		else
			return false
		end
	end

	function jcms.mission_PlayerEvac(ply)
		if jcms.director then
			jcms.director.evacuated[ply] = true
			ply:SetNWBool("jcms_evacuated", true)
			jcms.director_stats_SetLockedState(jcms.director, ply, "evacuated")
		end

		if jcms.director or jcms.inSpecialMap then
			local position = ply:GetPos()
			ply:KillSilent()
			ply.jcms_justSpawned = true
				GAMEMODE:PlayerSpawnAsSpectator(ply)
				ply:Spectate(OBS_MODE_ROAMING)
				ply:SetObserverMode(OBS_MODE_ROAMING)
				ply:GodEnable()
				ply:Freeze(true)
				ply:SetTeam(0)
			ply.jcms_justSpawned = false
			
			jcms.net_NotifyEvac(ply)
		end

		if jcms.director then
			local suddenDeathDelay = jcms.cvar_suddendeathtimer:GetInt()

			if suddenDeathDelay > 0 and not jcms.director.suddenDeathTime then
				jcms.director.suddenDeathTime = math.ceil( jcms.director_GetMissionTime() + suddenDeathDelay )

				local filter = RecipientFilter()
				filter:AddAllPlayers()

				EmitSound("ambient/levels/labs/teleport_winddown1.wav", vector_origin, 0, CHAN_STATIC, 1, 140, 0, 100, 0, filter)
				jcms.net_SendTip("all", true, "#jcms.suddendeathsoon", 1)
			end
		end
	end

-- // }}}
