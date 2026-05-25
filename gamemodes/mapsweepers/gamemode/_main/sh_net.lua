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

local bits_ply, bits_ent, bits_wld = 2, 2, 4

-- // Message IDs {{{

	-- // SERVER {{{
		local PLY_NOTIF = 0
		local PLY_VOTE = 1
		local PLY_DOUBLEJUMP = 2
		
		local ENT_AMMORECYCLE = 0
		local ENT_MARKSHIELDED = 1

		local WLD_OBJECTIVES_AND_DAMAGE = 0
		local WLD_ORDERS = 1
		local WLD_MISSIONTOGGLE = 2
		local WLD_CUE = 3
		local WLD_GUNS = 4
		local WLD_EARN = 5
		local WLD_ORDERDATA = 6
		local WLD_ANNOUNCER = 7
		local WLD_FOG = 8
		local WLD_ANNOUNCER_UPDATE = 9
		local WLD_WEAPON_PRICES = 10
		local WLD_NUKE = 11
		local WLD_SPAWNEFFECTS = 12
		local WLD_PVPVOTE = 13
		local WLD_LEADERBOARD = 14

	-- // }}}

	-- // CLIENT {{{
		local CL_WLD_MAPVOTE = 0
		local CL_WLD_AFKPING = 1
		local CL_WLD_PVPVOTE = 2

		local CL_PLY_ = 0

		local CL_ENT_TERMINAL = 0
	-- // }}}

-- // }}}

if SERVER then
	util.AddNetworkString "jcms_msg"

	hook.Add( "PlayerInitialSpawn", "jcms_netReady", function( initPly )
		if initPly:IsBot() then
			-- Bots don't need to wait for net messages, they are always ready.
			hook.Run( "jcms_PlayerNetReady", initPly )
			return
		end

		local hookName = "jcms_netReady_" .. tostring( initPly )

		hook.Add( "SetupMove", hookName, function( setupPly, _, cmd )
			if initPly ~= setupPly then return end
			if cmd:IsForced() then return end

			hook.Remove( "SetupMove", hookName )
			hook.Run( "jcms_PlayerNetReady", setupPly )
		end )
	end )

	local ply_messages = {
		--Nothing here for now
	}

	local ent_messages = {
		[CL_ENT_TERMINAL] = function(ply, ent)
			if jcms.team_NPC(ply) then
				return -- NPCs can't interact with terminals
			end
			
			local mode = jcms.terminal_modeTypes[ ent:GetNWString("jcms_terminal_modeType") ]
			if mode then
				-- Interacting
				local cmd = net.ReadUInt(8)
				local worked, newdata = mode.command(ent, cmd, ent:GetNWString("jcms_terminal_modeData"), ply)

				if worked then
					ent:SetNWString("jcms_terminal_modeData", newdata)
					ent:EmitSound("buttons/button15.wav", 70, 115, 0.86)
				else
					ent:EmitSound("buttons/button16.wav", 70, 115, 0.86)
				end
			end
		end
	}

	local wld_messages = {
		[CL_WLD_MAPVOTE] = function(ply)
			if jcms.director and jcms.director.votes then
				local mapname = net.ReadString()
				
				if jcms.director.vote_maps[mapname] ~= nil then
					jcms.director.votes[ply] = mapname
				end

				jcms.net_SendPlayerVote(ply, mapname)
			end
		end,
		
		[CL_WLD_AFKPING] = function(ply)
			jcms.playerAfkPings = jcms.playerAfkPings or {}
			jcms.playerAfkPings[ply] = CurTime()
		end,

		[CL_WLD_PVPVOTE] = function(ply)
			if jcms.director then return end
			if not jcms.pvp_vote_IsOngoing() then return end
			if jcms.pvp_vote and jcms.pvp_vote.processed then return end
			if jcms.cvar_pvpallowed:GetInt() ~= 1 then return end
			if not jcms.util_IsPVPAllowed() then return end

			local option = net.ReadUInt(2)
			
			jcms.printf("%s voted %s", ply, ({ "YES", "NO", "ANY", "NONE" })[option + 1])
			jcms.pvp_vote_InsertPlayerByOption(ply, option)
			
			jcms.net_SendPlayerPVPVote(ply, option)
		end
	}
	
	for i = 1, 2^bits_ply do ply_messages[i-1] = ply_messages[i-1] or function() end end
	for i = 1, 2^bits_ent do ent_messages[i-1] = ent_messages[i-1] or function() end end
	for i = 1, 2^bits_wld do wld_messages[i-1] = wld_messages[i-1] or function() end end
	
	net.Receive("jcms_msg", function(len, ply)
		local target = net.ReadEntity()

		if not(IsValid(target) or target == game.GetWorld()) then 
			jcms.printf("Invalid target " .. tostring(target) .. " in net message from " .. tostring(ply))
			return
		end

		if target:IsWorld() then 
			local msgid = net.ReadUInt(bits_wld)
			wld_messages[ msgid ](ply)
		elseif target:IsPlayer() then 
			local msgid = net.ReadUInt(bits_ply)
			ply_messages[ msgid ](ply, target)
		else
			local msgid = net.ReadUInt(bits_ent)
			ent_messages[ msgid ](ply, target)
		end
	end)

	function jcms.net_BroadcastToTeam(teamId)
		local allTeamPlys = {}
		for i, recipient in ipairs(player.GetAll()) do
			if jcms.team_pvpSameTeam_optimised(recipient:GetNWInt("jcms_pvpTeam", -1), teamId) then
				table.insert(allTeamPlys, recipient)
			end
		end

		net.Send(allTeamPlys)
	end

	function jcms.net_NotifyDeath(ply, suicide)
		if IsValid(ply) then
			local damageType = tonumber(ply.jcms_lastDamageType) or 0

			net.Start("jcms_msg")

			net.WriteBool(true)
			net.WritePlayer(ply)
			net.WriteUInt(PLY_NOTIF, 2)
			net.WriteUInt(0, 3)
			if suicide then
				net.WriteUInt(6, 4)
			else
				if damageType then
					local n = 0
					-- Ordered by priority
					if bit.band(DMG_FALL, damageType) ~= 0 then
						n = 5
					elseif bit.band(DMG_ACID, damageType) ~= 0 then
						n = 15
					elseif bit.band(DMG_BLAST, damageType) ~= 0 or bit.band(DMG_BLAST_SURFACE, damageType) ~= 0 then
						n = 3
					elseif bit.band(DMG_DROWN, damageType) ~= 0 then
						n = 4
					elseif bit.band(DMG_CRUSH, damageType) ~= 0 then
						n = 13
					elseif bit.band(DMG_RADIATION, damageType) ~= 0 then
						n = 12
					elseif bit.band(DMG_NERVEGAS, damageType) ~= 0 then
						n = 14
					elseif bit.band(DMG_BURN, damageType) ~= 0 or bit.band(DMG_SLOWBURN, damageType) ~= 0 then
						n = 2
					elseif bit.band(DMG_BULLET, damageType) ~= 0 or bit.band(DMG_BUCKSHOT, damageType) ~= 0 then
						n = 1
					end

					net.WriteUInt(n, 4)
				else
					net.WriteUInt(0, 4)
				end
			end

			net.Broadcast() -- net.SendOmit(ply)
		end
	end
	
	function jcms.net_NotifyEvac(ply)
		if IsValid(ply) and ply:IsPlayer() then
			net.Start("jcms_msg")
				net.WriteBool(true)
				net.WritePlayer(ply)
				net.WriteUInt(PLY_NOTIF, bits_ply)
				net.WriteUInt(0, 3)
				net.WriteUInt(11, 4)
			net.Broadcast()
		end
	end
	
	function jcms.net_NotifyGeneric(ply, activity, thing)
		if IsValid(ply) and ply:IsPlayer() then
			net.Start("jcms_msg")
				net.WriteBool(true)
				net.WritePlayer(ply)
				net.WriteUInt(PLY_NOTIF, bits_ply)
				net.WriteUInt(activity, 3)
				net.WriteString(thing)
			jcms.net_BroadcastToTeam(ply:GetNWInt("jcms_pvpTeam", -1))
		end
	end

	function jcms.net_NotifySquadChange(ply, state)
		if IsValid(ply) and ply:IsPlayer() then
			net.Start("jcms_msg")
				net.WriteBool(true)
				net.WritePlayer(ply)
				net.WriteUInt(PLY_NOTIF, bits_ply)
				net.WriteUInt(0, 3)
				net.WriteUInt(state and 10 or 9, 4)
			net.Broadcast()
		end
	end

	function jcms.net_NotifyJoinedNPCs(ply)
		if IsValid(ply) and ply:IsPlayer() then
			net.Start("jcms_msg")
				net.WriteBool(true)
				net.WritePlayer(ply)
				net.WriteUInt(PLY_NOTIF, bits_ply)
				net.WriteUInt(0, 3)
				net.WriteUInt(8, 4)
			net.Broadcast()
		end
	end

	function jcms.net_ShareMissionData(objectives, ply)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity( game.GetWorld() )
			net.WriteUInt(WLD_OBJECTIVES_AND_DAMAGE, bits_wld)
			net.WriteBool(true)
			net.WriteString( (jcms.director and jcms.director.missionType) or "tutorialmission" )
			
			net.WriteUInt(#objectives, 4)
			for i, obj in ipairs(objectives) do
				net.WriteString(obj.type)
				net.WriteUInt(obj.progress or 0, 16)
				net.WriteUInt(obj.total or 0, 16)
				net.WriteBool(obj.percent)
				net.WriteBool(obj.completed)
				net.WriteUInt(tonumber(obj.style) or 0, 3)

				local formatCount = math.min(31, obj.format and #obj.format or 0)
				net.WriteUInt(formatCount, 5)
				for i=1, formatCount do
					net.WriteString(tostring(obj.format[i]))
				end
			end
		if ply then
			net.Send(ply)
		else
			net.Broadcast()
		end
	end
	
	function jcms.net_SendDamage(ply, arg, isNegated)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity( game.GetWorld() )
			net.WriteUInt(WLD_OBJECTIVES_AND_DAMAGE, bits_wld)
			net.WriteBool(false)
			
			local dmgType = 0
			if type(arg) == "CTakeDamageInfo" then
				dmgType = arg:GetDamageType()
				isNegated = arg:GetDamage() <= 0
			else
				dmgType = tonumber(arg) or 0
				isNegated = not not isNegated
			end

			local compressedDmgType = jcms.util_dmgTypeCompress(dmgType)
			net.WriteUInt(compressedDmgType, #jcms.util_dmgTypesCompression)
			net.WriteBool(isNegated)
		net.Send(ply)
	end
	
	function jcms.net_SendOrder(orderId, orderData, onlyToPlayer)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_ORDERS, bits_wld)
			net.WriteBool(true) -- true: Sending, false: Removing
			net.WriteString(orderId)
			net.WriteUInt(orderData.category or jcms.SPAWNCAT_UTILITY, 3)
			net.WriteUInt(orderData.cost_override or orderData.cost or 0, 24)
			net.WriteUInt(orderData.cooldown_override or orderData.cooldown or 0, 12)
			net.WriteUInt(orderData.slotPos or 1, 4)

		if IsValid(onlyToPlayer) and onlyToPlayer:IsPlayer() then
			net.Send(onlyToPlayer)
		else
			net.Broadcast()
		end
	end
	
	function jcms.net_SendManyOrders(orders, onlyToPlayer)
		local delay = 0.015
		local count = table.Count(orders)
		local i = 0
		
		local isPvp = jcms.util_IsPVP() 

		for orderId, orderData in pairs(orders) do
			local _i =  i + 1
			timer.Simple(i*delay, function()
				if (isPvp and not orderData.pvpBlacklisted) or (not isPvp and not orderData.pvpExclusive) then
					jcms.net_SendOrder(orderId, orderData, onlyToPlayer)
				end
			end)
			i = i + 1
		end
	end
	
	function jcms.net_RemoveOrder(orderId)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_ORDERS, bits_wld)
			net.WriteBool(false) -- true: Sending, false: Removing
			net.WriteString(orderId)
		net.Broadcast()
	end
	
	function jcms.net_RemoveManyOrders(orders)
		local delay = 0.0275
		local count = #orders
		
		for i, orderId in ipairs(orders) do
			local _i = i
			timer.Simple((i-1)*delay, function()
				jcms.net_RemoveOrder(orderId)
			end)
			i = i + 1
		end
	end
	
	function jcms.net_SendMissionBeginning()
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_MISSIONTOGGLE, bits_wld)
			net.WriteBool(true)
			net.WriteBool(true)
		net.Broadcast()
	end
	
	function jcms.net_SendRespawnEffect(ply)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_MISSIONTOGGLE, bits_wld)
			net.WriteBool(true)
			net.WriteBool(false)
		net.Send(ply)
	end
	
	function jcms.net_SendMissionEnding(jCorpWon, lateToThePartyPlayer, teamId)
		local isPVP = jcms.util_IsPVP()

		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_MISSIONTOGGLE, bits_wld)
			net.WriteBool(false)

			net.WriteBool(false)
			net.WriteBool(jCorpWon) -- Did we win?
			net.WriteBool(isPVP)
			net.WriteBool(not not lateToThePartyPlayer) -- Is this a late mission end screen? (don't show animations)

			if jcms.util_IsPVP() then
				net.WriteUInt(jcms.director.nukesDropped or 0, 12)
			else
				local winstreak = jcms.runprogress.winstreak or 0 -- Winstreak before getting incremented
				if jCorpWon then
					net.WriteUInt(winstreak + 1, 12)
				else
					net.WriteUInt(winstreak, 12) -- Our old winstreak
				end
			end

			local stats = jcms.director_GetPostMissionStats()
			net.WriteUInt(stats.missionTime, 32) -- Mission time

			net.WriteUInt(#stats.players, 8)
			for i, pd in ipairs(stats.players) do
				net.WriteString(pd.sid64)
				net.WriteString(pd.nickname)
				net.WriteBool(pd.evacuated)

				if isPVP then
					net.WriteUInt(math.max(0, tonumber(pd.pvpTeam) or 0), 3)
				end

				net.WriteBool(not not pd.wasSweeper)
				if pd.wasSweeper then
					net.WriteString(pd.class)
					net.WriteUInt(pd.kills_direct, 24)
					net.WriteUInt(pd.kills_defenses, 24)
					net.WriteUInt(pd.kills_explosions, 24)
					net.WriteUInt(pd.kills_friendly, 14)
					if isPVP then
						net.WriteUInt(pd.kills_pvp, 14)
					end
					net.WriteUInt(pd.deaths_sweeper, 14)
					net.WriteUInt(pd.ordersUsedCounts, 16)
				end

				net.WriteBool(not not pd.wasNPC)
				if pd.wasNPC then
					net.WriteUInt(pd.kills_sweepers, 14)
					net.WriteUInt(pd.kills_turrets, 14)
					net.WriteUInt(pd.deaths_npc, 16)
				end
			end

			net.WriteUInt(jcms.director.vote_time or 0, 32)
			if jcms.director.vote_maps then
				net.WriteUInt(table.Count(jcms.director.vote_maps), 4)
				for map, wsid in pairs(jcms.director.vote_maps) do
					net.WriteString(map)
					if wsid then
						net.WriteBool(true)
						net.WriteString(wsid) -- Workshop ID
					else
						net.WriteBool(false)
					end
				end
			else
				net.WriteUInt(0, 4)
			end
		
		if lateToThePartyPlayer then
			net.Send(lateToThePartyPlayer)
		elseif teamId then 
			jcms.net_BroadcastToTeam(teamId)
		else
			net.Broadcast()
		end
	end

	function jcms.net_SendCashBonuses(ply, bonuses, oldCash, newCash)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_MISSIONTOGGLE, bits_wld)
			net.WriteBool(false)

			net.WriteBool(true)
			net.WriteUInt(oldCash, 16)
			net.WriteUInt(newCash, 16)
			net.WriteUInt(#bonuses, 4)
			for i, bonus in ipairs(bonuses) do
				net.WriteString(tostring(bonus.name))
				net.WriteInt(bonus.cash, 16)
				net.WriteString(tostring(bonus.format or ""))
			end
		net.Send(ply)
	end

	function jcms.net_SendLocator(to, id, name, at, locatorType, timeout, landmarkIcon, fromPly) --fromPly's for pvpTeam stuff, will usually be nil
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_CUE, bits_wld)
			net.WriteBool(false)
			if isentity(at) then
				net.WriteBool(true)
				net.WriteEntity(at)
				net.WriteVector(at:GetPos())
			elseif isvector(at) then
				net.WriteBool(false)
				net.WriteVector(at)
			else
				return false
			end

			if type(name) == "table" and #name == 2 then
				net.WriteBool(true)
				net.WriteString(tostring(name[1] or id or "???"))
				net.WriteString(tostring(name[2] or id or "???"))
			else
				net.WriteBool(false)
				net.WriteString(tostring(name or id or "???"))
			end

			net.WriteUInt(locatorType or 0, 2)
			
			if timeout and timeout > 0 then
				net.WriteBool(true)
				net.WriteDouble(timeout)
			else
				net.WriteBool(false)
			end

			if id then
				net.WriteBool(true)
				net.WriteString(id)
			else
				net.WriteBool(false)
			end

			if landmarkIcon then
				net.WriteBool(true)
				net.WriteString(landmarkIcon)
			else
				net.WriteBool(false)
			end

			local writePly = IsValid(fromPly)
			net.WriteBool(writePly)
			if writePly then
				net.WritePlayer(fromPly)
			end

		if to == "all" then
			if not IsValid(fromPly) then
				net.Broadcast()
			else
				jcms.net_BroadcastToTeam(fromPly:GetNWInt("jcms_pvpTeam", -1))
			end
		else
			net.Send(to)
		end
	end

	function jcms.net_SendTip(to, isMission, cue, progress)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_CUE, bits_wld)
			net.WriteBool(true)
			net.WriteBool(isMission)

			if isMission then --Missions cues still have unknown data
				net.WriteString(cue)
				net.WriteFloat( math.Clamp(tonumber(progress) or 0, 0, 1) )
			else --Hint cues are predefined.
				net.WriteBool(false)
				net.WriteUInt(cue, 7)
			end
		if to == "all" then
			net.Broadcast()
		else
			net.Send(to)
		end
	end

	function jcms.net_SendOrderMessage(to, type, format)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_CUE, bits_wld)
			net.WriteBool(true)
			net.WriteBool(false)
			net.WriteBool(true)
			net.WriteUInt(type, 3)
			net.WriteString(tostring(format or ""))
		net.Send(to)
	end
	
	function jcms.net_SendWeapon(class, cost, to)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_GUNS, bits_wld)
			net.WriteBool(false)
			net.WriteString(class)
			if cost > 0 then
				net.WriteBool(true)
				net.WriteUInt(cost, 24)
			else
				net.WriteBool(false) -- not available
			end
		if to == "all" then
			net.Broadcast()
		else
			net.Send(to)
		end
	end
	
	function jcms.net_SendWeaponPrices(weapons, to)
		local weaponsData = util.TableToJSON(weapons)
		local compressed = util.Compress(weaponsData)

		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_WEAPON_PRICES, bits_wld)
			net.WriteUInt(#compressed, 16)
			net.WriteData(compressed, #compressed)
		net.Send(to)
	end

	function jcms.net_SendWeaponInLoadout(class, n, to)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_GUNS, bits_wld)
			net.WriteBool(true)
			net.WriteString(class)
			net.WriteUInt(n, 12)
		if to == "all" then
			net.Broadcast()
		else
			net.Send(to)
		end
	end

	function jcms.net_SendPlayerVote(ply, mapname)
		net.Start("jcms_msg")
			net.WriteBool(true)
			net.WritePlayer(ply)
			net.WriteUInt(PLY_VOTE, bits_ply)
			net.WriteString(mapname)
		net.Broadcast()
	end

	function jcms.net_SendCashEarn(ply, n)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_EARN, bits_wld)
			net.WriteBool(false)
			net.WriteBool(false)
			net.WriteUInt(math.Round(tonumber(n) or 0), 23)
		net.Send(ply)
	end

	function jcms.net_SendNPCDamageReport(ply, dmgEntity, isShield, n)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_EARN, bits_wld)
			net.WriteBool(false)
			net.WriteBool(true)

			net.WriteEntity(dmgEntity)
			net.WriteBool(isShield)
			net.WriteUInt(math.min(math.Round(tonumber(n) or 0), 65535), 16)
		net.Send(ply)
	end

	function jcms.net_SendPlayStatistics(ply, stats)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_EARN, bits_wld)
			net.WriteBool(true)

			net.WriteUInt(stats.exp or 0, 18)
			net.WriteString(stats.class or ply:GetNWString("jcms_class", "infantry"))
			
			local factionKills = stats.factionKills
			if factionKills then
				net.WriteUInt(table.Count(factionKills), 4)

				for faction, kills in pairs(factionKills) do
					net.WriteString(faction)
					net.WriteUInt(kills, 10)
				end
			else
				net.WriteUInt(0, 4)
			end

			net.WriteUInt(table.Count(stats.missionStatuses), 2)
			for misType, status in pairs(stats.missionStatuses) do
				net.WriteString(misType)
				net.WriteBool(status)
			end

			if stats.other then
				local otherCount = table.Count(stats.other)
				net.WriteUInt(otherCount, 4)
				for stat, count in pairs(stats.other) do
					net.WriteString(stat)
					net.WriteUInt(count, 8)
				end
			else
				net.WriteUInt(0, 4)
			end
		net.Send(ply)
	end
	
	function jcms.net_SendOrderCooldown(ply, orderId, cd)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_ORDERDATA, bits_wld)
			net.WriteUInt(0, 2)
			net.WriteString(orderId)
			net.WriteDouble(CurTime() + cd)
		net.Send(ply)
	end
	
	function jcms.net_SendOrderClearCooldowns(ply)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_ORDERDATA, bits_wld)
			net.WriteUInt(1, 2)
		net.Send(ply)
	end

	function jcms.net_SendAnnouncerSpeak(id, index, ply)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_ANNOUNCER, bits_wld)
			net.WriteUInt(id, 8)
			net.WriteUInt(index, 8)
		if not IsValid(ply) then 
			net.Send( team.GetPlayers(1) )
		else
			net.Send(ply)
		end
	end

	function jcms.net_SendFogData(ply)
		if IsValid(ply) and ply:IsPlayer() then
			local fogController = ents.FindByClass("env_fog_controller")[1]
			if IsValid(fogController) then 
				local col = fogController:GetInternalVariable("fogcolor")
				local intensity = fogController:GetInternalVariable("fogmaxdensity")

				local fogStart = fogController:GetInternalVariable("fogstart")
				local fogEnd = fogController:GetInternalVariable("fogend")

				net.Start("jcms_msg")
					net.WriteBool(false)
					net.WriteEntity(game.GetWorld())
					net.WriteUInt(WLD_FOG, bits_wld)

					local col = string.Explode( " ", col )
					local r, g, b = col[1], col[2], col[3]
						net.WriteUInt(tonumber(r), 8)
						net.WriteUInt(tonumber(g), 8)
						net.WriteUInt(tonumber(b), 8)
					
					net.WriteFloat(intensity)
					net.WriteFloat(fogStart)
					net.WriteFloat(fogEnd)
				net.Send(ply)
			end
		end
	end

	function jcms.net_SendNewAnnouncer(name)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_ANNOUNCER_UPDATE, bits_wld)
			net.WriteString(name)
		net.Broadcast()
	end
	
	function jcms.net_SendNuke(pos)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_NUKE, bits_wld)
			net.WriteVector(pos)
		net.Broadcast()
	end

	function jcms.net_SendCanDoubleJump(ply, state)
		net.Start("jcms_msg")
			net.WriteBool(true)
			net.WritePlayer(ply)
			net.WriteUInt(PLY_DOUBLEJUMP, bits_ply)
			net.WriteBool(state)
		net.Broadcast()
	end

	function jcms.net_SendNPCSpawnEffects(spawneffectCategory)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_SPAWNEFFECTS, bits_wld)

			local count = math.Clamp(#spawneffectCategory, 0, 63)
			net.WriteUInt(tonumber(spawneffectCategory.colorInt) or 0, 8)
			net.WriteFloat(tonumber(spawneffectCategory.scale) or 1)
			net.WriteUInt(count, 6)
			for i=1, count do
				local e = spawneffectCategory[i]

				local vec = e[1]
				local delay = e[2]

				net.WriteInt(math.Round(vec.x/2), 14) -- Writes a vector rounded to nearest 2 units
				net.WriteInt(math.Round(vec.y/2), 14)
				net.WriteInt(math.Round(vec.z/2), 14)
				net.WriteUInt(math.min(2047, math.floor(delay*8)), 11) -- Writes delay multiplied by 8.
			end
		net.Broadcast()
	end

	function jcms.net_SendPVPVoteStart(toWhom)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_PVPVOTE, bits_wld)

			net.WriteUInt(0, 2)
			net.WriteUInt(jcms.pvp_vote.endsAt, 32)
		if IsValid(toWhom) then
			net.Send(toWhom)
		else
			net.Broadcast()
		end
	end

	function jcms.net_SendPlayerPVPVote(ply, option, toWhom)
		-- Option 0: Yes, Option 1: No, Option 2: Any
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_PVPVOTE, bits_wld)

			net.WriteUInt(1, 2)
			net.WritePlayer(ply)
			net.WriteUInt(option, 2)
		if IsValid(toWhom) then
			net.Send(toWhom)
		else
			net.Broadcast()
		end
	end

	function jcms.net_SendEndPVPVote()
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_PVPVOTE, bits_wld)

			net.WriteUInt(2, 2)
		net.Broadcast()
	end

	function jcms.net_SendLeaderboard(to, isPVP)
		local tbl = jcms.leaderboard_LoadTopPlayers(isPVP)
		local sendingTbl = {}
		for i, sid64 in ipairs(tbl) do
			if isPVP then
				sendingTbl[i] = jcms.leaderboard_GetStatsPVP(sid64)
			else
				sendingTbl[i] = jcms.leaderboard_GetStatsPVE(sid64)
			end
			sendingTbl[i].sid64 = sid64
		end

		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_LEADERBOARD, bits_wld)

			net.WriteBool(isPVP)
			net.WriteUInt(#sendingTbl, 4)
			for i, data in ipairs(sendingTbl) do
				net.WriteUInt64(data.sid64)
				net.WriteString(data.lastUsedName)
				net.WriteUInt(data.wins, 24)
				net.WriteUInt(data.losses, 24)
				if isPVP then
					net.WriteUInt(data.elo, 12)
				else
					net.WriteUInt(data.highestWinstreak, 16)
				end
			end
		if to == "all" then
			net.Broadcast()
		else
			net.Send(to)
		end
	end

	function jcms.net_SendBothLeaderboardsIfNeeded(to)
		if jcms.leaderboard_Enabled() then
			jcms.net_SendLeaderboard(to, false)
			jcms.net_SendLeaderboard(to, true)
		end
	end

	function jcms.net_SendAmmoRecycle(to, weapon)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(weapon)
			net.WriteUInt(ENT_AMMORECYCLE, bits_ent)
		net.Send(to)
	end
	
	function jcms.net_SendSweeperShieldMark(ent, max, colInt)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(ent)
			net.WriteUInt(ENT_MARKSHIELDED, bits_ent)

			net.WriteBool(true) --Is Sweeper Shield

			--Reliable networking for cached values
			net.WriteUInt(max, 8)
			net.WriteUInt(colInt, 16)
		net.SendPVS(ent:GetPos()) --Non-PVS shields handled by the shield system itself.
	end
	
	function jcms.net_SendBubbleShieldMark(ent)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(ent)
			net.WriteUInt(ENT_MARKSHIELDED, bits_ent)

			net.WriteBool(false) --Is Bubble Shield
		net.SendPVS(ent:GetPos()) --Non-PVS shields handled by the shield system itself.
	end
end

if CLIENT then

	local ply_messages = {
		[ PLY_NOTIF ] = function(ply)
			local type = net.ReadUInt(3)

			local message, good
			if type == 0 then
				-- Generic
				local subtype = net.ReadUInt(4)
				
				if (subtype == 9 or subtype == 10) and (ply == LocalPlayer()) then
					return
				end
				
				if subtype == 10 or subtype == 11 then
					good = true
				end
				
				message = language.GetPhrase("jcms.plynotif" .. subtype)
				if message then
					message = message:gsub( "PLAYER", ply:Nick() )
				end
			else
				good = type ~= 4

				message = language.GetPhrase("jcms.plynotif_alt" .. type)
				if message then
					message = message:gsub( "PLAYER", ply:Nick() ):gsub( "THING", language.GetPhrase(net.ReadString()) )
				end
			end

			jcms.hud_AddNotif(message, good)
		end,

		[ PLY_VOTE ] = function(ply)
			if jcms.aftergame and jcms.aftergame.vote then
				local mapname = net.ReadString()
				jcms.aftergame.vote.votes[ply] = mapname
				surface.PlaySound("friends/friend_join.wav")
			end
		end,

		[ PLY_DOUBLEJUMP ] = function(ply)
			ply.jcms_CanJump = net.ReadBool()
		end
	}

	local ent_messages = {
		[ ENT_AMMORECYCLE ] = function(ent)
			local curWeapon = jcms.locPly:GetActiveWeapon()

			if curWeapon == ent then
				jcms.hud_DoAmmoConservationEffect()
			end
		end,
		
		[ ENT_MARKSHIELDED ] = function(ent)
			if IsValid(ent) then 
				if net.ReadBool() then		--SWEEPER SHIELDS
					--NWInts aren't sent by this point usually so manually grab them instead.
					local max = net.ReadUInt(8) --Probably never gonna need >60k max shield
					local colInt = net.ReadUInt(16)

					jcms.sweeperShield_MarkShielded(ent, max, colInt)
				else						--BUBBLE SHIELDS
					jcms.bubbleShield_MarkShielded(ent)
				end
			end
		end
	}

	local wld_messages = {
		[ WLD_OBJECTIVES_AND_DAMAGE ] = function()
			local isObjectives = net.ReadBool()
			if isObjectives then
				-- Update mission objectives
				local missionName = net.ReadString()
				local objectiveCount = net.ReadUInt(4)

				local objectives = {}
				for i=1, objectiveCount do
					local objectivetype = net.ReadString()
					local x, n = net.ReadUInt(16), net.ReadUInt(16)
					local perc = net.ReadBool()
					local completed = net.ReadBool()
					local style = net.ReadUInt(3)
					local formatCount = net.ReadUInt(5)

					local fmt = {}

					for j=1, formatCount do
						table.insert(fmt, net.ReadString())
					end

					if #fmt > 0 then
						objectivetype = jcms.objective_Localize(objectivetype)
						local s, rtn = pcall(string.format, objectivetype, unpack(fmt))
						objectivetype = tostring(s and rtn or objectivetype)
					end

					table.insert(objectives, {
						type = objectivetype,
						progress = x, 
						n = n,
						percent = perc,
						completed = completed,
						style = style
					})
				end
				
				jcms.objective_UpdateEverything(missionName, objectives)
			else
				local compressedDmgType = net.ReadUInt( #jcms.util_dmgTypesCompression )
				jcms.hud_DispatchDamage( jcms.util_dmgTypeDecompress( compressedDmgType ), net.ReadBool() )
			end
		end,
		
		[ WLD_ORDERS ] = function()
			local adding = net.ReadBool()
			local orderId = net.ReadString()
			
			if adding then
				local category = net.ReadUInt(3)
				local cost = net.ReadUInt(24)
				local cooldown = net.ReadUInt(12)
				local slotPos = net.ReadUInt(4) --For sorting
				
				local nextUse = nil
				if jcms.orders[ orderId ] then
					nextUse = jcms.orders[ orderId ].nextUse
				end

				jcms.orders[ orderId ] = {
					id = orderId,
					category = category,
					cost = cost,
					cooldown = cooldown,
					slotPos = slotPos,
					nextUse = nextUse
				}
				
				jcms.printf("Order '%s' added", orderId)
			else
				jcms.orders[ orderId ] = nil
				jcms.printf("Order '%s' removed", orderId)
			end
			
			jcms.orders_RebuildLists()
		end,
		
		[ WLD_MISSIONTOGGLE ] = function()
			local beginning = net.ReadBool()
			if beginning then
				local isNewMission = net.ReadBool()
				jcms.aftergame = nil
				jcms.aftergame_bonuses = nil

				if isNewMission and jcms.shouldPlayMusic() then -- Disable music if we have Nombat or DOOM music addons
					jcms.playRandomSong()
				end
				
				jcms.hud_BeginningSequence()

				if CustomChat then 
					CustomChat:Enable()
				end
			else
				local isBonuses = net.ReadBool()
				if isBonuses then
					local bonuses = {}

					local oldCash = net.ReadUInt(16)
					local newCash = net.ReadUInt(16)
					local bonusCount = net.ReadUInt(4)
					for i=1, bonusCount do
						local name = net.ReadString()
						local cash = net.ReadInt(16)
						local format = net.ReadString()

						table.insert(bonuses, { name = name, cash = cash, format = format })
					end

					bonuses.oldCash = oldCash
					bonuses.newCash = newCash
					jcms.aftergame_bonuses = bonuses
				else
					local victory = net.ReadBool()
					local isPVP = net.ReadBool()
					local isLate = net.ReadBool()
					
					jcms.aftergame = { victory = victory }
					jcms.aftergame.statistics = {}
					jcms.aftergame.vote = { choices = {}, votes = {} }
					
					local winstreak_or_nukes = net.ReadUInt(12)
					if isPVP then
						jcms.aftergame.winstreak = 0
						jcms.aftergame.nukes = winstreak_or_nukes
					else
						jcms.aftergame.winstreak = winstreak_or_nukes
						jcms.aftergame.nukes = 0
					end
					
					local missionTime = net.ReadUInt(32)
					jcms.aftergame.missionTime = missionTime

					local plyCount = net.ReadUInt(8)
					for i=1, plyCount do
						local stat = {}
						
						stat.sid64 = net.ReadString()
						stat.nickname = net.ReadString()
						stat.evacuated = net.ReadBool()
						if isPVP then
							stat.pvpTeam = net.ReadUInt(3)
						else
							stat.pvpTeam = 0
						end
						stat.ply = player.GetBySteamID64(stat.sid64)

						stat.wasSweeper = net.ReadBool()
						if stat.wasSweeper then -- Stats as a Sweeper
							stat.class = net.ReadString()
							stat.kills_direct = net.ReadUInt(24)
							stat.kills_defenses = net.ReadUInt(24)
							stat.kills_explosions = net.ReadUInt(24)
							stat.kills_friendly = net.ReadUInt(14)
							if isPVP then
								stat.kills_pvp = net.ReadUInt(14)
							else
								stat.kills_pvp = 0
							end
							stat.deaths_sweeper = net.ReadUInt(14)
							stat.ordersUsedCounts = net.ReadUInt(16)
						end

						stat.wasNPC = net.ReadBool()
						if stat.wasNPC then -- Stats as an NPC
							stat.kills_sweepers = net.ReadUInt(14)
							stat.kills_turrets = net.ReadUInt(14)
							stat.deaths_npc = net.ReadUInt(16)
						end

						table.insert(jcms.aftergame.statistics, stat)
					end

					jcms.aftergame.voteTime = net.ReadUInt(32)
					local voteOptionsCount = net.ReadUInt(4)
					for i=1, voteOptionsCount do
						local mapname = net.ReadString()
						local wsid = net.ReadBool() and net.ReadString() or false -- Workshop ID
						jcms.aftergame.vote.choices[mapname] = wsid
					end

					jcms.hud_EndingSequence(victory, isLate)
				end
			end
		end,
		
		[ WLD_CUE ] = function()
			local isTip = net.ReadBool()

			if isTip then
				local isMission = net.ReadBool()
				local text 
				if isMission then 
					text = net.ReadString()
					jcms.hud_UpdateTip(isMission, text, net.ReadFloat())
				else
					local isOrderMessage = net.ReadBool()
					if isOrderMessage then
						local type = net.ReadUInt(3)
						local format = net.ReadString()
						jcms.hud_ShowOrderMessage(type, format)
					else
						text = jcms.hints[net.ReadUInt(7)]
						jcms.hud_UpdateTip(isMission, text)
					end
				end
			else
				local isEntity = net.ReadBool()
				local at
				if isEntity then
					at = net.ReadEntity()
					if IsValid(at) then
						at:SetPos( net.ReadVector() )
					else
						at = net.ReadVector() 
					end
				else
					at = net.ReadVector()
				end

				local formatted = net.ReadBool()
				local name = net.ReadString()
				local useBiggerFont = false

				if name:sub(1, 1) == "^" then
					name = name:sub(2, -1)
					useBiggerFont = true
				end

				if formatted then
					name = language.GetPhrase(name):format( language.GetPhrase(net.ReadString()) )
				end
				
				local locatorType = net.ReadUInt(2)

				local isTemporary = net.ReadBool()
				local timeout
				if isTemporary then
					timeout = net.ReadDouble()
				end

				local hasId = net.ReadBool()
				local id
				if hasId then
					id = net.ReadString()
				end

				local hasLandmarkIcon = net.ReadBool()
				local landmarkIcon
				if hasLandmarkIcon then
					landmarkIcon = net.ReadString()
				end

				local loc = jcms.hud_AddLocator(id, name, at, locatorType, timeout, landmarkIcon)

				if useBiggerFont then
					loc.biggerFont = true
				end

				local hasPlayerWritten = net.ReadBool()
				if hasPlayerWritten then
					local sender = net.ReadPlayer()
					if IsValid(sender) then
						loc.toptext = sender:Nick() or "???"
					end
				end
			end
		end,
		
		[ WLD_GUNS ] = function()
			local isLoadout = net.ReadBool()
			if not isLoadout then
				-- Fetching gun prices
				local class = net.ReadString()
				local available = net.ReadBool()
				if available then
					jcms.weapon_prices[ class ] = net.ReadUInt(24)
				else
					jcms.weapon_prices[ class ] = nil
				end
			else
				-- Fetching loadout count
				local class = net.ReadString()
				local count = net.ReadUInt(12)
				if count > 0 then
					jcms.weapon_loadout[class] = count
				else
					jcms.weapon_loadout[class] = nil
				end
			end
		end,

		[ WLD_WEAPON_PRICES ] = function()
			local compressedSize = net.ReadUInt(16)
			local compressedData = net.ReadData(compressedSize)
			local weaponsData = util.Decompress(compressedData)
			local wepsPrices = util.JSONToTable(weaponsData)

			for class, price in pairs(wepsPrices) do
				jcms.weapon_prices[ class ] = price
			end
		end,

		[ WLD_EARN ] = function()
			local isStatistics = net.ReadBool()

			if isStatistics then
				local expEarned = net.ReadUInt(18)
				local myClass = net.ReadString()
				local factionCount = net.ReadUInt(4)
				
				jcms.statistics_AddEXP(expEarned)
				for i=1, factionCount do
					local factionName = net.ReadString()
					local factionKills = net.ReadUInt(10)
					jcms.statistics_AddKillCount(factionName, myClass, factionKills)
				end

				local missionCount = net.ReadUInt(2)
				for i=1, missionCount do
					local misType = net.ReadString()
					local isCompleted = net.ReadBool()
					jcms.statistics_AddMissionCount(misType, myClass, isCompleted, 1)
				end

				local otherCount = net.ReadUInt(4)
				for i=1, otherCount do
					local statName = net.ReadString()
					local count = net.ReadUInt(8)
					jcms.statistics_AddOther(statName, myClass, count)
				end
			else
				local isNpcDamageReport = net.ReadBool()

				if isNpcDamageReport then
					local ent = net.ReadEntity()
					local isShields = net.ReadBool()
					local dmg = net.ReadUInt(16)
					jcms.hud_npc_AddDamage(ent, isShields, dmg)
				else
					local count = net.ReadUInt(23)
					jcms.hud_AddCash(count)
				end
			end
		end,
		
		[ WLD_ORDERDATA ] = function()
			local signal = net.ReadUInt(2)
			
			if signal == 0 then
				-- set individual cooldown
				local orderId = net.ReadString()
				local nextUse = net.ReadDouble()
				if jcms.orders[ orderId ] then
					jcms.orders[ orderId ].nextUse = nextUse
				end
			elseif signal == 1 then
				-- clear all cooldowns
				for orderId, orderData in pairs(jcms.orders) do
					orderData.nextUse = nil
				end
			end
		end,

		[ WLD_ANNOUNCER ] = function()
			local id = net.ReadUInt(8)
			local index = net.ReadUInt(8)
			jcms.announcer_Speak(id, index)
		end,
		
		[ WLD_FOG ] = function()
			local r, g, b = net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)
			jcms.mapFog.fogCol = Color(r, g, b) 

			jcms.mapFog.fogIntensity = net.ReadFloat()
			jcms.mapFog.fogStart = net.ReadFloat()
			jcms.mapFog.fogEnd = net.ReadFloat()
		end,

		[ WLD_ANNOUNCER_UPDATE ] = function()
			jcms.announcer_Set(net.ReadString())
		end,

		[WLD_NUKE] = function()
			jcms.effect_skyNuke(net.ReadVector(), 3)
		end,

		[ WLD_SPAWNEFFECTS ] = function()
			local colorInteger = net.ReadUInt(8)
			local scale = net.ReadFloat()
			local count = net.ReadUInt(6)
			
			local ed = EffectData()
			ed:SetFlags(1)
			ed:SetColor(colorInteger)
			ed:SetScale(scale)

			--print("Receiving portals", count, scale, jcms.util_ColorFromInteger(colorInteger))
			local pos = Vector(0, 0, 0)
			for i=1, count do
				local x_2 = net.ReadInt(14)
				local y_2 = net.ReadInt(14)
				local z_2 = net.ReadInt(14)
				local _8_delay = net.ReadUInt(11)
				
				pos:SetUnpacked(x_2*2, y_2*2, z_2*2 - 40)
				ed:SetOrigin(pos)
				pos:SetUnpacked(x_2*2, y_2*2, z_2*2 + 40)
				ed:SetStart(pos)

				ed:SetMagnitude(_8_delay/8)
				util.Effect("jcms_spawneffect", ed)
			end
		end,

		[ WLD_PVPVOTE ] = function()
			local vote = jcms.pvp_vote
			
			local action = net.ReadUInt(2)

			if action == 0 then
				-- Start vote
				vote.endsAt = net.ReadUInt(32)
				table.Empty( vote.yes )
				table.Empty( vote.no )
				table.Empty( vote.any )
			elseif action == 1 then
				-- Someone voted
				local ply = net.ReadPlayer()
				local option = net.ReadUInt(2) -- Yes, No, Any
				local hadEffect = jcms.pvp_vote_InsertPlayerByOption(ply, option)

				if hadEffect and jcms.offgame and IsValid(jcms.offgame) and (not jcms.pvp_vote.lastSoundFrame or FrameNumber() > jcms.pvp_vote.lastSoundFrame) then

					if option == 0 then
						surface.PlaySound("friends/friend_join.wav")
					elseif option == 1 then
						surface.PlaySound("buttons/button10.wav")
					end

					jcms.pvp_vote.lastSoundFrame = FrameNumber()
				end
			elseif action == 2 then
				-- End vote
				vote.endsAt = CurTime() + 0.5
			end
		end,

		[ WLD_LEADERBOARD ] = function()
			local isPVP = net.ReadBool()
			local count = net.ReadUInt(4)

			local key = isPVP and "leaderboard_data_pvp" or "leaderboard_data_pve"
			if not jcms[key] then
				jcms[key] = {}
			else
				table.Empty(jcms[key])
			end

			local tbl = jcms[key]
			
			for i=1, count do
				local tblPly = {}

				tblPly.sid64 = net.ReadUInt64()
				tblPly.name = net.ReadString()
				tblPly.wins = net.ReadUInt(24)
				tblPly.losses = net.ReadUInt(24)
				if isPVP then
					tblPly.elo = net.ReadUInt(12)
				else
					tblPly.highestWinstreak = net.ReadUInt(16)
				end

				tbl[i] = tblPly
			end
			
			if isPVP then
				table.sort(tbl, function(first, last)
					return first.elo > last.elo
				end)
			else
				table.sort(tbl, function(first, last)
					return first.wins > last.wins
				end)
			end
		end
	}

	for i = 1, 2^bits_ply do ply_messages[i-1] = ply_messages[i-1] or function() end end
	for i = 1, 2^bits_ent do ent_messages[i-1] = ent_messages[i-1] or function() end end
	for i = 1, 2^bits_wld do wld_messages[i-1] = wld_messages[i-1] or function() end end

	net.Receive("jcms_msg", function(len)
		local plyOriented = net.ReadBool()

		if plyOriented then
			local ply = net.ReadPlayer()
			if not IsValid(ply) then jcms.printf("invalid player in a net message") return end

			local msgid = net.ReadUInt(bits_ply)
			ply_messages[ msgid ](ply)
		else
			local ent = net.ReadEntity()
			if (not IsValid(ent) and ent ~= game.GetWorld()) then jcms.printf("invalid entity in a net message") end --TODO: This triggers under normal/correct operation (bulletshields), should probably be removed to prevent console spam?

			if ent:IsWorld() then
				local msgid = net.ReadUInt(bits_wld)
				wld_messages[ msgid ]()
			else
				local msgid = net.ReadUInt(bits_ent)
				ent_messages[ msgid ](ent)
			end
		end
	end)

	function jcms.net_SendVote(mapName)
		net.Start("jcms_msg")
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(CL_WLD_MAPVOTE, bits_wld)

			net.WriteString(mapName)
		net.SendToServer()
	end

	function jcms.net_SendTerminalInput(ent, output)
		net.Start("jcms_msg")
			net.WriteEntity(ent)
			net.WriteUInt(CL_ENT_TERMINAL, bits_ent)

			net.WriteUInt(output, 8)
		net.SendToServer()
	end
	
	function jcms.net_SendAfkPing()
		net.Start("jcms_msg")
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(CL_WLD_AFKPING, bits_wld)
		net.SendToServer()
	end

	function jcms.net_SendPVPVote(option)
		net.Start("jcms_msg")
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(CL_WLD_PVPVOTE, bits_wld)

			net.WriteUInt(tonumber(option) or 0, 2)
		net.SendToServer()
	end
end
