
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


-- // Mission randomisation {{{
	jcms.runprogress_factionHistoryWeights = {
		0.01, --Almost never double-up factions
		0.35,
		0.65,
		0.9,
	}

	jcms.runprogress_missionHistoryWeights = {
		0.25,	--Getting VFP or payload twice should be unlikely, but not as big of a problem as same fac twice.
		0.65,
		0.85
	}
-- // }}}

jcms.runprogress = jcms.runprogress or {
	difficulty = 0.9,
	winstreak = 0,
	totalWins = 0,
	playerStartingCash = {}, -- key is Steam ID 64, value is starting cash. 

	lastMission = "", --DEPRECATED
	lastFaction = "", --DEPRECATED

	previousMissions = {}, --up to 4 prior missions.
	previousFactions = {} --ditto
}

function jcms.runprogress_CalculateDifficultyFromWinstreak(winstreak, totalWins)
	local newPlayerScalar = 1 - math.max((6 - totalWins), 0) * 0.06
	local final = (0.9 + winstreak * 0.175) * newPlayerScalar
	game.GetWorld():SetNWFloat("jcms_difficulty", final)
	return final
	
	--Winstreaks increase difficulty (17.5% per mission).
	--Being new to the game (having fewer than 5 wins) also reduces your difficulty. This scales from 25% to 0% reduction
end

function jcms.runprogress_GetDifficulty()
	if jcms.specialmap_GetDifficulty then
		return tonumber( jcms.specialmap_GetDifficulty() ) or 1
	else
		if jcms.util_IsPVP() then
			return 1
		else
			return tonumber(jcms.runprogress.difficulty) or 1
		end
	end
end

function jcms.runprogress_Victory()
	local rp = jcms.runprogress
	rp.winstreak = rp.winstreak + 1
	rp.totalWins = rp.totalWins + 1
	rp.difficulty = jcms.runprogress_CalculateDifficultyFromWinstreak(rp.winstreak, rp.totalWins)
	game.GetWorld():SetNWInt("jcms_winstreak", rp.winstreak)
	game.GetWorld():SetNWInt("jcms_difficulty", rp.difficulty)
end

function jcms.runprogress_AddStartingCash(ply_or_sid64, amount)
	local sid64 = tostring(ply_or_sid64)
	if type(ply_or_sid64) == "Player" then
		sid64 = ply_or_sid64:SteamID64()
	end
	sid64 = "_" .. sid64 --Stop JSONToTable from obliterating us.

	local startingCashTable = jcms.runprogress.playerStartingCash
	if startingCashTable[ sid64 ] then
		startingCashTable[ sid64 ] = math.ceil( startingCashTable[ sid64 ] + ( tonumber(amount) or 0 ) )
	else
		startingCashTable[ sid64 ] = math.ceil( jcms.cvar_cash_start:GetInt() + ( tonumber(amount) or 0 ) )
	end
end

function jcms.runprogress_ResetStartingCash(ply_or_sid64)
	local sid64 = tostring(ply_or_sid64)
	if type(ply_or_sid64) == "Player" then
		sid64 = ply_or_sid64:SteamID64()
	end
	sid64 = "_" .. sid64 --Stop JSONToTable from obliterating us.

	jcms.runprogress.playerStartingCash[ sid64 ] = jcms.cvar_cash_start:GetInt()
end

function jcms.runprogress_GetStartingCash(ply_or_sid64)
	if jcms.util_IsPVP() then return jcms.cvar_cash_start:GetInt() end

	local sid64 = tostring(ply_or_sid64)
	if type(ply_or_sid64) == "Player" then
		sid64 = ply_or_sid64:SteamID64()
	end
	sid64 = "_" .. sid64 --Stop JSONToTable from obliterating us.

	return jcms.runprogress.playerStartingCash[ sid64 ] or (jcms.cvar_cash_start:GetInt() + jcms.runprogress.winstreak * jcms.cvar_cash_victory:GetInt())
end

function jcms.runprogress_UpdateAllPlayers()
	for i, ply in player.Iterator() do 
		ply:SetNWInt("jcms_cash", jcms.runprogress_GetStartingCash(ply))
		--print(jcms.runprogress_GetStartingCash(ply))
	end
end

function jcms.runprogress_Reset()
	local rp = jcms.runprogress

	if not rp.highScore or rp.highScore.winstreak < rp.winstreak then
		--Save the highest winstreak the server's had, including all runprogress data (players / winstreak / etc)
		rp.highScore = nil
		rp.highScore = table.Copy(rp)
	end

	rp.winstreak = 0
	rp.difficulty = jcms.runprogress_CalculateDifficultyFromWinstreak(rp.winstreak, rp.totalWins)
	table.Empty(jcms.runprogress.playerStartingCash)
	game.GetWorld():SetNWInt("jcms_winstreak", rp.winstreak)
	game.GetWorld():SetNWInt("jcms_difficulty", rp.difficulty)
end

function jcms.runprogress_GetLastMissionTypes()
	return jcms.runprogress.lastMission, jcms.runprogress.lastFaction
end

function jcms.runprogress_GetMissionHistoryWeights()
	local missionWeights = {}
	local factionWeights = {}

	local prevMissions = jcms.runprogress.previousMissions
	for i, mis in ipairs(prevMissions) do
		missionWeights[mis] = jcms.runprogress_missionHistoryWeights[#prevMissions - i + 1] --Our history tables are stored in reverse order (oldest first, newest last) so this iterates them in reverse.
	end

	local prevFactions = jcms.runprogress.previousFactions
	for i, fac in ipairs(prevFactions) do
		factionWeights[fac] = jcms.runprogress_factionHistoryWeights[#prevFactions - i + 1] --Ditto
	end
	
	return missionWeights, factionWeights
end

function jcms.runprogress_SetLastMission()
	local rp = jcms.runprogress
	local mis = jcms.util_GetMissionType()
	local fac = jcms.util_GetMissionFaction()

	rp.lastMission = mis
	rp.lastFaction = fac

	table.insert(rp.previousMissions, mis)
	if #rp.previousMissions > #jcms.runprogress_missionHistoryWeights then 
		table.remove(rp.previousMissions, 1)
	end

	table.insert(rp.previousFactions, fac)
	if #rp.previousFactions > #jcms.runprogress_factionHistoryWeights then 
		table.remove(rp.previousFactions, 1)
	end
end


do -- Saving / Loading
	local runProgFile = "mapsweepers/server/runprogress_" .. (game.SinglePlayer() and "solo" or "multiplayer") .. ".dat"
	hook.Add("InitPostEntity", "jcms_RestorePreviousRun", function()
		if file.Exists(runProgFile, "DATA") then
			local dataTxt = file.Read(runProgFile, "DATA")
			local dataTbl = util.JSONToTable(util.Decompress(dataTxt))

			table.Merge(jcms.runprogress, dataTbl, true)
			jcms.runprogress_UpdateAllPlayers()
			game.GetWorld():SetNWInt("jcms_winstreak", jcms.runprogress.winstreak)
			game.GetWorld():SetNWInt("jcms_difficulty", jcms.runprogress.difficulty)
		end
	end)

	hook.Add("ShutDown", "jcms_SaveRunData", function()
		if not jcms.fullyLoaded then return end

		if jcms.director and not jcms.director.gameover then
			jcms.runprogress_Reset()
			--Resets our run if we're in a mission. Prevents save-scumming.
		end

		local dataStr = util.Compress(util.TableToJSON(jcms.runprogress))
		file.Write(runProgFile, dataStr)
	end)
end