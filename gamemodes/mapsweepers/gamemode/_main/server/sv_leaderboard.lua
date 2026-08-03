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


-- // Main {{{
	jcms.leaderboard_roundPlayers = {} --[side64] = pvpTeam (-1 for pve)
	jcms.leaderboard_roundLeaveTimes = {} --[sid64] = Curtime()
	jcms.leaderboard_roundLeaveReasons = {} --[sid64] = reason (e.g. timed out) --NOTE: Should be treated as less reliable than roundLeaveTimes

	-- // Player Tracking {{{
		function jcms.leaderboard_PlayerDeployed(ply) --Player is now part of the match
			if ply:IsBot() then return end

			jcms.leaderboard_roundPlayers[ply:SteamID64()] = ply:GetNWInt("jcms_pvpTeam", -1)
		end

		function jcms.leaderboard_PlayerLeft(ply) --Disconnected early
			if ply:IsBot() then return end
			
			local sid64 = ply:SteamID64()
			jcms.leaderboard_roundLeaveTimes[sid64] = CurTime()
		end

		gameevent.Listen("player_disconnect")
		hook.Add("player_disconnect", "jcms_leaderboard_playerDisconnect", function( data )
			if data.bot == 1 then return end

			jcms.leaderboard_roundLeaveReasons[ util.SteamIDTo64(data.networkid) ] = data.reason
		end)
	-- // }}}

	-- // Disconnect forgiveness {{{
		function jcms.leaderboard_GetForgivenessTime( sid64 )
			local reason = jcms.leaderboard_roundLeaveReasons[sid64] or "Disconnect by user."

			if not(reason == "Disconnect by user.") then
				return 5*60 --5 Minutes of forgiveness if they timed out or got kicked for any reason (e.g. any of the weird steam stuff)
			end

			return 60 --1 minute if they left
		end

		function jcms.leaderboard_VictoryEligble( sid64 )
			if IsValid(player.GetBySteamID64(sid64)) then return true end --Still here!

			local disconnectTime = jcms.leaderboard_roundLeaveTimes[sid64] or CurTime()
			local disconnectedFor = CurTime() - disconnectTime

			return disconnectedFor - jcms.leaderboard_GetForgivenessTime(sid64) < 0
		end
	-- // }}}

	-- // Update stats on round end {{{
		function jcms.leaderboard_RoundEnd(isPVP, victory, aliveTeams)
			if not jcms.leaderboard_Enabled() then return end

			if isPVP then
				for teamID, alive in ipairs(aliveTeams) do
					if alive then
						jcms.leaderboard_PVPRoundEnd(teamID)
						break
					end
				end
			else
				jcms.leaderboard_PVERoundEnd(victory)
			end

			--Clear Data
			jcms.leaderboard_roundPlayers = {}
			jcms.leaderboard_roundLeaveTimes = {} 
			jcms.leaderboard_roundLeaveReasons = {}
		end

		function jcms.leaderboard_PVERoundEnd(victory)
			local playerStats = {}
			for sid64, _ in pairs(jcms.leaderboard_roundPlayers) do 
				playerStats[sid64] = jcms.leaderboard_GetStatsPVE(sid64)
			end

			local postMissionStats = jcms.director_GetPostMissionStats()
			local playerSid64Stats = {}
			for i, pd in ipairs(postMissionStats.players) do 
				playerSid64Stats[pd.sid64] = pd
			end

			--rt(playercount) rounded up max of 4
			local eligbleWinstreakTokens = math.min(math.ceil(math.sqrt(player.GetCount())), 4)
			if victory and jcms.mission_IsBossMission() then --winstreak tokens being granted
				--Separation of concern? What's that?
				jcms.util_playSoundGlobal("garrysmod/ui_click.wav", 1, 120)
			end

			table.Shuffle(playerStats)
			for sid64, stats in pairs(playerStats) do
				if victory then --If we won and are present or forgiven we get positive increases
					if jcms.leaderboard_VictoryEligble(sid64) then 
						stats.wins = stats.wins + 1
						stats.highestWinstreak = math.max(stats.highestWinstreak, jcms.runprogress.winstreak)

						if jcms.leaderboard_WinstreakTokenEligble(playerSid64Stats[sid64]) and eligbleWinstreakTokens > 0 then
							stats.winstreakTokens = stats.winstreakTokens + 1
							eligbleWinstreakTokens = eligbleWinstreakTokens - 1
							
							local ply = player.GetBySteamID64(sid64)
							if IsValid(ply) then
								PrintMessage( HUD_PRINTTALK, "[MapSwepeers] " .. ply:Nick() .. " earned a winstreak token" )
							end
						end
					end
				else --If we lost and were here at all we lose
					stats.losses = stats.losses + 1
				end

				jcms.leaderboard_SaveStats(stats, sid64, false)
			end

			jcms.leaderboard_RecalculateTopPlayers( playerStats, false )

			for i, ply in player.Iterator() do
				jcms.leaderboard_UpdatePlayerWinstreakTokens(ply) --A little wasteful but the perf impact is tiny so who cares
			end
		end

		function jcms.leaderboard_PVPRoundEnd(winningTeam)
			local playerStats = {}
			local playerTeams = {}
			for sid64, plyTeam in pairs(jcms.leaderboard_roundPlayers) do 
				playerStats[sid64] = jcms.leaderboard_GetStatsPVP(sid64)
				playerTeams[sid64] = plyTeam
			end

			-- {{{ Calculate average ELO of each team.
				--This could probably be made more sophisticated but this is good enough.
				local winners = 0
				local losers = 0

				local winnerELOAvg = 0
				local loserELOAvg = 0

				for sid64, stats in pairs(playerStats) do
					if playerTeams[sid64] == winningTeam then --TODO: How does forgiveness factor in? If at all. 
						winners = winners + 1
						winnerELOAvg = winnerELOAvg + playerStats[sid64].elo
					else
						losers = losers + 1
						loserELOAvg = loserELOAvg + playerStats[sid64].elo
					end
				end

				if winners > 0 then 
					winnerELOAvg = winnerELOAvg / winners
				else
					winnerELOAvg = 500
				end

				if losers > 0 then
					loserELOAvg = loserELOAvg / losers
				else
					loserELOAvg = 500
				end
			-- // }}}

			for sid64, stats in pairs(playerStats) do
				local change = 50 --Set pretty high for now. Might adapt / make more complex later?

				--TODO: Randomised or anonymous teams might be needed, people *will* try to game this by only joining high skill teams if we give them the option.

				--If you leave at any point during the match, you lose. No cheating the system.
				if playerTeams[sid64] == winningTeam and jcms.leaderboard_VictoryEligble(sid64) then
					local eloChange = jcms.leaderboard_CalcELOChange( stats.elo, loserELOAvg, 1, change )
					stats.elo = stats.elo + eloChange

					stats.wins = stats.wins + 1
				else
					local eloChange = jcms.leaderboard_CalcELOChange( stats.elo, winnerELOAvg, 0, change )
					stats.elo = stats.elo + eloChange

					stats.losses = stats.losses + 1
				end

				jcms.leaderboard_SaveStats(stats, sid64, true)
			end

			jcms.leaderboard_RecalculateTopPlayers( playerStats, true )
		end
	-- // }}}

	-- // Misc {{{
		function jcms.leaderboard_Enabled()
			return not game.SinglePlayer()
		end
	-- // }}}
-- // }}}

-- // PVP Ranking {{{
		function jcms.leaderboard_CalcELOChange( p1ELO, p2ELO, score, change ) --Change is for p1,
			--https://www.omnicalculator.com/sports/elo#what-is-the-elo-rating-system
			local expectedScore = 1 / (10^((p2ELO - p1ELO)/400) + 1)
			return (score - expectedScore) * change
		end
-- // }}}

-- // Top tracking {{{
		function jcms.leaderboard_RecalculateTopPlayers( playerStats, isPVP ) --PlayerStats is the table of statsTbls for joined players.
			local topPlayerIDs = jcms.leaderboard_LoadTopPlayers(isPVP)

			-- Merge top players into the playerStats table
			for i, sid64 in ipairs(topPlayerIDs) do 
				playerStats[sid64] = isPVP and jcms.leaderboard_GetStatsPVP( sid64 ) or jcms.leaderboard_GetStatsPVE( sid64 )
			end

			--Get a table of all of our current player sid64s and the top players. 
			topPlayerIDs = {}
			for sid64, _ in pairs(playerStats) do 
				table.insert(topPlayerIDs, sid64)
			end

			--Sort the list so the new top players are earliest.
			local sortFunction
			if isPVP then 
				sortFunction = function(sid64A, sid64B)
					return playerStats[sid64A].elo > playerStats[sid64B].elo
				end
			else
				sortFunction = function(sid64A, sid64B)
					return playerStats[sid64A].wins > playerStats[sid64B].wins
				end
			end
			table.sort(topPlayerIDs, sortFunction)


			--Trim to 10 to get the final list
			local finalTopPlayerIDs = {}
			for i=1, 10, 1 do 
				finalTopPlayerIDs[i] = topPlayerIDs[i]
			end

			--Save the new table
			jcms.leaderboard_SaveTopPlayers(finalTopPlayerIDs, isPVP)

			jcms.net_SendLeaderboard("all", isPVP)
		end
-- // }}}

-- // Winstreak Tokens {{{
	hook.Add("PlayerInitialSpawn", "jcms_WinstreakTokens_Restore", function(ply)
		jcms.leaderboard_UpdatePlayerWinstreakTokens(ply)
		jcms.leaderboard_RecalculateHighestWinstreak()
	end)
	
	hook.Add("PlayerDisconnected", "jcms_WinstreakTokens_PlayerLeft", function(ply)
		jcms.leaderboard_RecalculateHighestWinstreak()
	end)

	jcms.leaderboard_highestWinstreak = jcms.leaderboard_highestWinstreak or 0
	function jcms.leaderboard_RecalculateHighestWinstreak()
		local highest = 0

		for i, ply in player.Iterator() do 
			local stats = jcms.leaderboard_GetStatsPVE(ply:SteamID64())
			highest = math.max(highest, stats.highestWinstreak)
		end

		jcms.leaderboard_highestWinstreak = highest
		jcms.leaderboard_UpdateCanUseWinstreakToken()
	end

	function jcms.leaderboard_CanUseWinstreakToken()
		return game.IsDedicated() and not jcms.mission_IsBossMission(jcms.runprogress.winstreak) and jcms.runprogress.winstreak < jcms.leaderboard_highestWinstreak
	end

	function jcms.leaderboard_WinstreakTokenEligble( playerPostMissionStats )
		return playerPostMissionStats and playerPostMissionStats.evacuated and jcms.mission_IsBossMission()
	end


	--Net stuff
	function jcms.leaderboard_UpdateCanUseWinstreakToken()
		game.GetWorld():SetNWBool("jcms_canUseWinstreakTokens", jcms.leaderboard_CanUseWinstreakToken())
	end

	function jcms.leaderboard_UpdatePlayerWinstreakTokens(ply)
		local stats = jcms.leaderboard_GetStatsPVE(ply:SteamID64())
		ply:SetNWInt("jcms_winstreakTokens", stats.winstreakTokens)
	end

	function jcms.leaderboard_TakeWinstreakToken(ply)
		local sid64 = ply:SteamID64()
		local pveStats = jcms.leaderboard_GetStatsPVE(sid64)

		pveStats.winstreakTokens = pveStats.winstreakTokens - 1
		jcms.leaderboard_SaveStats(pveStats, sid64, false)
	end

	function jcms.leaderboard_GiveWinstreakToken(ply)
		local sid64 = ply:SteamID64()	
		local pveStats = jcms.leaderboard_GetStatsPVE(sid64)

		pveStats.winstreakTokens = pveStats.winstreakTokens + 1
		jcms.leaderboard_SaveStats(pveStats, sid64, false)
	end
-- // }}}


-- // Filesystem {{{
	file.CreateDir("mapsweepers")
	file.CreateDir("mapsweepers/server")

	local pveDir = "mapsweepers/server/leaderboard/pve"
	local pvpDir = "mapsweepers/server/leaderboard/pvp"
	file.CreateDir( pveDir )
	file.CreateDir( pvpDir )


	-- // Stats Save/Load (Player) {{{
		local function getNameByID(sid64)
			local name = ""
			local ply = player.GetBySteamID64(sid64)
			if IsValid(ply) then 
				name = ply:GetName()
			end

			return name
		end
		
		function jcms.leaderboard_GetStatsPVE(sid64)
			local statsTbl = {
				lastUsedName = getNameByID(sid64),	--empty str or the player's name if they're on the server
				highestWinstreak = 0,
				wins = 0,
				losses = 0,
				winstreakTokens = 0
			}
			
			jcms.leaderboard_TryLoadStats(statsTbl, sid64, false)

			return statsTbl
		end

		function jcms.leaderboard_GetStatsPVP(sid64)
			local statsTbl = {
				lastUsedName = getNameByID(sid64),	--empty str or the player's name if they're on the server
				elo = 500,							--Arbitrary leaderboard ranking value
				wins = 0,
				losses = 0,
			}

			jcms.leaderboard_TryLoadStats(statsTbl, sid64, true)

			return statsTbl
		end


		function jcms.leaderboard_TryLoadStats(statsTbl, sid64, isPVP) --steamID, isPVP, and table to merge into.
			local dir = isPVP and pvpDir or pveDir
			local filePath = dir .. "/" .. sid64 .. ".json"
			if file.Exists(filePath, "DATA") then
				local fileTbl = util.JSONToTable(file.Read(filePath))
				table.Merge(statsTbl, fileTbl)
			end
			--Results affect statsTabl
		end

		function jcms.leaderboard_SaveStats(statsTbl, sid64, isPVP)
			local dir = isPVP and pvpDir or pveDir
			local filePath = dir .. "/" .. sid64 .. ".json"

			file.Write(filePath, util.TableToJSON(statsTbl))
		end
	-- // }}}

	-- // Stats Save/Load (Top) {{{
		function jcms.leaderboard_SaveTopPlayers(topTbl, isPVP)
			local dir = isPVP and pvpDir or pveDir
			local filePath = dir .. "/top_players.json"

			file.Write(filePath, util.TableToJSON(topTbl))
		end

		function jcms.leaderboard_LoadTopPlayers(isPVP)
			local dir = isPVP and pvpDir or pveDir
			local filePath = dir .. "/top_players.json"

			if file.Exists(filePath, "DATA") then
				return util.JSONToTable(file.Read(filePath))
			else
				return {} --No top players yet
			end
		end
	-- // }}}
-- // }}}