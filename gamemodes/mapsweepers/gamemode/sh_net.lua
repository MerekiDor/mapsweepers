--[[
	Map Sweepers - Co-op NPC Shooter Gamemode for Garry's Mod by "Octantis Addons" (consisting of MerekiDor & JonahSoldier)
    Copyright (C) 2025  MerekiDor

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
		
		local ENT_ = 0

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
	-- // }}}

	-- // CLIENT {{{
		local CL_WLD_MAPVOTE = 0
		local CL_WLD_AFKPING = 1

		local CL_PLY_ = 0

		local CL_ENT_TERMINAL = 0
	-- // }}}

-- // }}}

if SERVER then 
	util.AddNetworkString "jcms_msg"
	
	net.inited_players = {}
	
	hook.Add("PlayerDisconnected", "jcms_netDisconnect", function(ply)
		net.inited_players[ply] = nil
	end)

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
				
				if table.HasValue(jcms.director.vote_maps, mapname) then
					jcms.director.votes[ply] = mapname
				end

				jcms.net_SendPlayerVote(ply, mapname)
			end
		end,
		
		[CL_WLD_AFKPING] = function(ply)
			jcms.playerAfkPings = jcms.playerAfkPings or {}
			jcms.playerAfkPings[ply] = CurTime()
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
			net.Broadcast()
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

	function jcms.net_ShareMissionData(objectives)
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity( game.GetWorld() )
			net.WriteUInt(WLD_OBJECTIVES_AND_DAMAGE, bits_wld)
			net.WriteBool(true)
			net.WriteString( (jcms.director and jcms.director.missionType) or "tutorialmission" )
			
			net.WriteUInt(#objectives, 4)
			for i, obj in ipairs(objectives) do
				net.WriteString(obj.type)
				net.WriteUInt(obj.progress, 10)
				net.WriteUInt(obj.total, 10)
				net.WriteBool(obj.percent)
				net.WriteBool(obj.completed)
			end
		net.Broadcast()
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
	
	function jcms.net_SendOrder(orderId, orderData)
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
		net.Broadcast()
	end
	
	function jcms.net_SendManyOrders(orders)
		local delay = 0.015
		local count = table.Count(orders)
		local i = 0
		
		for orderId, orderData in pairs(orders) do
			local _i =  i + 1
			timer.Simple(i*delay, function()
				jcms.net_SendOrder(orderId, orderData)
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
	
	function jcms.net_SendMissionEnding(jCorpWon, lateToThePartyPlayer) -- TODO Send a faster end-screen to those who had just joined.
		net.Start("jcms_msg")
			net.WriteBool(false)
			net.WriteEntity(game.GetWorld())
			net.WriteUInt(WLD_MISSIONTOGGLE, bits_wld)
			net.WriteBool(false)

			net.WriteBool(false)
			net.WriteBool(jCorpWon) -- Did we win?
			net.WriteBool(not not lateToThePartyPlayer) -- Is this a late mission end screen? (don't show animations)

			local winstreak = jcms.runprogress.winstreak or 0 -- Winstreak before getting incremented
			if jCorpWon then
				net.WriteUInt(winstreak + 1, 12)
			else
				net.WriteUInt(winstreak, 12) -- Our old winstreak
			end

			local stats = jcms.director_GetPostMissionStats()
			net.WriteUInt(stats.missionTime, 32) -- Mission time

			net.WriteUInt(#stats.players, 8)
			for i, pd in ipairs(stats.players) do
				net.WriteString(pd.sid64)
				net.WriteString(pd.nickname)
				net.WriteBool(pd.evacuated)

				net.WriteBool(not not pd.wasSweeper)
				if pd.wasSweeper then
					net.WriteUInt(pd.kills_direct, 24)
					net.WriteUInt(pd.kills_defenses, 24)
					net.WriteUInt(pd.kills_explosions, 24)
					net.WriteUInt(pd.kills_friendly, 14)
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
				net.WriteUInt(#jcms.director.vote_maps, 4)
				for i, map in ipairs(jcms.director.vote_maps) do
					net.WriteString(map)
				end
			else
				net.WriteUInt(0, 4)
			end
		
		if lateToThePartyPlayer then
			net.Send(lateToThePartyPlayer)
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

	function jcms.net_SendLocator(to, id, name, at, locatorType, timeout, landmarkIcon)
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

			net.WriteString(tostring(name or id or "???"))
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
		if to == "all" then
			net.Broadcast()
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
	
	function jcms.net_SendManyWeapons(weapons, to)
		local delay = 0.028
		local count = table.Count(weapons)
		local i = 0
		
		for weaponClass, weaponCost in pairs(weapons) do
			local _i =  i + 1
			timer.Simple(i*delay, function()
				jcms.net_SendWeapon(weaponClass, weaponCost, to)
				--jcms.printf("Sending weapon %d/%d", _i, count)
			end)
			i = i + 1
		end
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
		end
	}

	local ent_messages = {
		[0] = function(ent)
		end
	}

	local wld_messages = {
		[ WLD_OBJECTIVES_AND_DAMAGE ] = function()
			local isObjectives = net.ReadBool()
			if isObjectives then
				-- Update mission objectives
				local dataString = net.ReadString() .. ":"
				local objectiveCount = net.ReadUInt(4)
				for i=1, objectiveCount do
					local type, x, n, perc, completed = net.ReadString(), net.ReadUInt(10), net.ReadUInt(10), net.ReadBool(), net.ReadBool()
					dataString = dataString .. ("%s-%d-%d-%s%s%s"):format(type,x,n,perc and "1" or "0",completed and "1" or "0",i==objectiveCount and "" or ",")
				end
				
				jcms.objective_UpdateEverything(dataString)
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
				
				jcms.orders[ orderId ] = {
					id = orderId,
					category = category,
					cost = cost,
					cooldown = cooldown,
					slotPos = slotPos
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

				if isNewMission and not (NOMBAT or MUSIC_SYSTEM or jcms.cvar_nomusic:GetBool()) then -- Disable music if we have Nombat or DOOM music addons
					jcms.playRandomSong()
				end
				
				jcms.hud_BeginningSequence()
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
					local isLate = net.ReadBool()
					
					jcms.aftergame = { victory = victory }
					jcms.aftergame.statistics = {}
					jcms.aftergame.vote = { choices = {}, votes = {} }
					
					local winstreak = net.ReadUInt(12)
					jcms.aftergame.winstreak = winstreak
					
					local missionTime = net.ReadUInt(32)
					jcms.aftergame.missionTime = missionTime

					local plyCount = net.ReadUInt(8)
					for i=1, plyCount do
						local stat = {}
						
						stat.sid64 = net.ReadString()
						stat.nickname = net.ReadString()
						stat.evacuated = net.ReadBool()
						stat.ply = player.GetBySteamID64(stat.sid64)

						stat.wasSweeper = net.ReadBool()
						if stat.wasSweeper then -- Stats as a Sweeper
							stat.kills_direct = net.ReadUInt(24)
							stat.kills_defenses = net.ReadUInt(24)
							stat.kills_explosions = net.ReadUInt(24)
							stat.kills_friendly = net.ReadUInt(14)
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
						local map = net.ReadString()
						table.insert(jcms.aftergame.vote.choices, map)
					end

					-- todo Skip the animations if we're late
					jcms.hud_EndingSequence(victory)
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
				local name = net.ReadString()
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
			
				jcms.hud_AddLocator(id, name, at, locatorType, timeout, landmarkIcon)
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
			if (not IsValid(ent) and ent ~= game.GetWorld()) then jcms.printf("invalid entity in a net message") end

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
end
