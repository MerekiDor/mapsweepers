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
DEFINE_BASECLASS("gamemode_base")

include "sh_debugtools.lua"

include "sh_bspReader.lua" --Data from the BSP. We probably(?) want to use this in mapgen and missions, so I put it at the top. - J
do
	local bspReadStart = SysTime()
	bspReader.readLeafData()
	bspReader.readNodeData()
	bspReader.readPlaneData()
	bspReader.readPVSData()
	bspReader.readBrushData(CONTENTS_PLAYERCLIP)
	print("[MapSweepers] BSP Data read in: " .. tostring( math.Round(SysTime() - bspReadStart, 3) ) .. " seconds")
end

include "sh_ainReader.lua" --i like eating binrary numbrs- j
ainReader.readNodeData()

include "shared.lua"
include "sh_net.lua"
include "sh_hints.lua"
include "sv_director.lua"
include "sh_controls.lua"
include "sv_terminal.lua"
include "sv_spawnmenu.lua"
include "sv_mapgen.lua"
include "sv_addoncompatibility.lua"
include "sh_announcer.lua"
include "sh_factions.lua"
include "sh_statistics.lua"

-- // Mission Includes {{{
	do 
		include "missions/sv_missions.lua"
		local missionFiles, _ = file.Find( "mapsweepers/gamemode/missions/types/*.lua", "LUA")
		for i, v in ipairs(missionFiles) do 
			include("missions/types/" .. v)
		end
		include "prefabs/sv_prefabs.lua"
	end
-- // }}}

-- // Class Includes {{{
	do
		include "classes/sh_classes.lua"
		AddCSLuaFile "classes/sh_classes.lua"
		local classFiles, _ = file.Find( "mapsweepers/gamemode/classes/types/*.lua", "LUA")
		for i, v in ipairs(classFiles) do 
			include("classes/types/" .. v)
			AddCSLuaFile("classes/types/" .. v)
		end

		table.sort(jcms.classesOrder, function(first, last)
			local idFirst, idLast = jcms.classesOrderIndices[first] or 10, jcms.classesOrderIndices[last] or 10
			return idFirst < idLast
		end)
	end
-- // }}}

-- // NPC Includes {{{
	do
		include "npcs/sv_pathfinder.lua"
		include "npcs/sv_npcs.lua"
		local npcFiles, _ = file.Find( "mapsweepers/gamemode/npcs/types/*.lua", "LUA")
		for i, v in ipairs(npcFiles) do 
			include("npcs/types/" .. v)
		end

		--precache files
		local pcacheFiles, _ = file.Find( "mapsweepers/gamemode/npcs/precache/*.lua", "LUA")
		for i, v in ipairs(pcacheFiles) do
			include("npcs/precache/" .. v)
			AddCSLuaFile("npcs/precache/" .. v)
		end 
	end
-- // }}}

AddCSLuaFile "shared.lua"
AddCSLuaFile "sh_controls.lua"
AddCSLuaFile "sh_net.lua"
AddCSLuaFile "sh_hints.lua"
AddCSLuaFile "sh_announcer.lua"
AddCSLuaFile "sh_factions.lua"
AddCSLuaFile "cl_hud.lua"
AddCSLuaFile "cl_hud_npc.lua"
AddCSLuaFile "cl_flashlights.lua"
AddCSLuaFile "cl_terminal.lua"
AddCSLuaFile "cl_objectives.lua"
AddCSLuaFile "cl_spawnmenu.lua"
AddCSLuaFile "cl_paint.lua"
AddCSLuaFile "cl_offgame.lua"
AddCSLuaFile "missions/cl_missions.lua"
AddCSLuaFile "sh_statistics.lua"
AddCSLuaFile "cl_codex.lua"
AddCSLuaFile "npcs/cl_bestiary.lua"
AddCSLuaFile "cl_addoncompatibility.lua"

if jcms.inTutorial then
	include "sv_tutorial.lua"
	AddCSLuaFile "cl_tutorial.lua"
end

-- // Resources {{{

	resource.AddSingleFile("resource/fonts/jcms_regular.ttf")
	resource.AddSingleFile("resource/fonts/jcms_light.ttf")
	resource.AddSingleFile("resource/fonts/jcms_semibold.ttf")

-- // }}}

-- // Sounds {{{

	sound.Add( {
		name = "jcms_shield_broken",
		channel = CHAN_STATIC,
		volume = 1.0,
		level = 100,
		pitch = 100,
		sound = {
			"jcms/shieldbreak01.wav",
			"jcms/shieldbreak02.wav"
		}
	} )

	sound.Add( {
		name = "jcms_shield_broken_npc",
		channel = CHAN_STATIC,
		volume = 1.0,
		level = 75,
		pitch = 80,
		sound = {
			"jcms/shieldbreak01.wav",
			"jcms/shieldbreak02.wav"
		}
	} )
	
	sound.Add( {
		name = "jcms_jetby",
		channel = CHAN_STATIC,
		volume = 1.0,
		level = 200,
		pitch = 100,
		sound = {
			"@jcms/jet1.wav",
			"@jcms/jet2.wav",
			"@jcms/jet3.wav"
		}
	} )

-- // }}}

-- // General {{{

	-- These are areas through which turrets cannot see.
	jcms.smokeScreens = {} -- Format of a smoke screen: { pos = Vector, rad = number, expires = <CurTime-like timestamp> }
	
	hook.Add("InitPostEntity", "jcms_InitPostEnt", function()
		RunConsoleCommand("ai_disabled", "0")
		RunConsoleCommand("ai_ignoreplayers", "0")
		--Skill should never be anything other than 1, but I guess other addons fuck with it, because Mereki had it at 3.
		game.SetSkillLevel( 1 ) -- TODO Maybe warn the player.
		--This will fucking annihilate performance if it's 1. It's saved from sandbox, so playtesters have repeatedly had issues with this.
		RunConsoleCommand("ai_serverragdolls", "0")
		timer.Create( "jcms_disableragdolls_bruteforce", 0, 2, function() --People are *STILL* having issues with this, so I guess we're going to try doing it this way.
			RunConsoleCommand("ai_serverragdolls", "0")
			game.ConsoleCommand("ai_serverragdolls 0\n")
		end)

		timer.Simple(0, function() --Needed so that our runprogress can be loaded first
			jcms.mission_Randomize()
		end)

		team.SetColor(0, Color(180, 180, 180))
		team.SetColor(1, Color(255, 16, 16))
		team.SetColor(2, Color(16, 183, 255))
	end)

	hook.Add("PlayerSwitchFlashlight", "jcms_Flashlight", function(ply, enabled)
		local newState = not ply:GetNWBool("jcms_flashlight", false)
		if newState==false or (ply:Alive() and ply:GetObserverMode("jcms") == OBS_MODE_NONE and not IsValid(ply:GetVehicle()) and not IsValid(ply:GetNWEntity("jcms_vehicle"))) then
			ply:SetNWBool("jcms_flashlight", newState)
			ply:EmitSound("items/flashlight1.wav", 50, newState and 120 or 110, 0.8)
		end
		return enabled == false
	end)
	
	hook.Add("EntityTakeDamage", "jcms_Adjustments", function(ent, dmg)
		local attacker = dmg:GetAttacker()
		local inflictor = dmg:GetInflictor()
		local dmgType = dmg:GetDamageType()

		if ent:IsNPC() then
			ent.jcms_lastDamageType = dmgType
		end

		if (inflictor == attacker) and attacker:IsPlayer() and bit.band(dmgType, bit.bor(DMG_BUCKSHOT, DMG_BULLET)) > 0 then
			-- This is really shitty, but neither M9K nor ArcCW properly set up their inflictors, which is why this is necessary.
			local wep = attacker:GetActiveWeapon()
			if IsValid(wep) then
				dmg:SetInflictor(wep)
				inflictor = wep
			end
		end

		local isEntAndAttackerSameTeam = jcms.team_SameTeam(attacker, ent)

		if isEntAndAttackerSameTeam then
			if attacker:IsPlayer() and jcms.team_NPC(attacker) then
				dmg:ScaleDamage(0) -- NPC-players can't do friendly fire damage to NPCs
				return
			else
				dmg:ScaleDamage( jcms.cvar_ffmul:GetFloat() )
			end
		end

		local shield = ent:GetNWInt("jcms_shield", 0)
		if shield > 0 and bit.band(dmgType, bit.bor(DMG_CRUSH, DMG_FALL)) == 0 and dmg:GetDamage() > 0 then 
			ent:SetNWInt("jcms_shield", math.max(shield - 1, 0))
			dmg:SetDamage(0)
			return 0
		elseif ent:IsPlayer() then
			ent.jcms_lastDamaged = CurTime()
			jcms.net_SendDamage(ent, dmginfo)
		end

		local swpShield = ent:GetNWInt("jcms_sweeperShield", 0)
		if swpShield > 0 and bit.band(dmgType, DMG_CRUSH) == 0 then
			local dmgAmnt = dmg:GetDamage()
			
			local shieldDmg = math.min(swpShield, dmgAmnt)
			local newDmg = dmgAmnt - shieldDmg
			dmg:SetDamage(newDmg)
			ent:SetNWInt("jcms_sweeperShield", math.floor(swpShield - shieldDmg))
			if swpShield == shieldDmg then --Shield Break
				local ed = EffectData()
				ed:SetFlags(1)
				ed:SetColor(ent:GetNWInt("jcms_sweeperShield_colour", 255))
				ed:SetEntity(ent)
				util.Effect("jcms_shieldeffect", ed)
			
				ent:EmitSound("jcms_shield_broken_npc")
			else
				jcms_util_shieldDamageEffect(dmg, shieldDmg)
			end
		end

		if ent:IsPlayer() and bit.band(dmg:GetDamageType(), DMG_CRUSH) > 0 then --Prevent us from being instakilled by physics objects.
			local dmgAmnt = dmg:GetDamage()
			dmgAmnt = math.min(dmgAmnt, 35)
			dmg:SetDamage(dmgAmnt)
		end

		if not dmg:IsFallDamage() then
			if IsValid(inflictor) and IsValid(inflictor.jcms_owner) then
				dmg:SetAttacker(inflictor.jcms_owner)
				attacker = inflictor.jcms_owner
			elseif IsValid(attacker.jcms_owner) then
				dmg:SetAttacker(attacker.jcms_owner)
				dmg:SetInflictor(attacker)
				attacker = attacker.jcms_owner
				inflictor = attacker
			end

			if attacker:IsPlayer() then
				local data = jcms.class_GetData(attacker)

				if ent:IsPlayer() and isEntAndAttackerSameTeam then
					local dmgAmnt = dmg:GetDamage()
					local dmgCap = (ent:GetMaxHealth() + ent:GetMaxArmor()) * 0.75
					dmg:SetDamage( math.Clamp(dmgAmnt, 0, dmgCap) )
				end

				if inflictor:IsWeapon() and not inflictor.Base then -- Scale damage done by all engine weapons
					dmg:ScaleDamage(2.5)
				end

				if attacker.jcms_dmgMult then
					dmg:ScaleDamage(attacker.jcms_dmgMult)
				end				

				if data then
					if data.OnDealDamage then
						data.OnDealDamage(attacker, ent, dmg, data)
					end
					
					if not data.jcorp then
						dmg:ScaleDamage(jcms.npc_GetScaledDamage(jcms.director and jcms.director.livingPlayers))
					end
				end
			else
				dmg:ScaleDamage(attacker.jcms_dmgMult or 1)
				if not attacker.jcms_dontScaleDmg then
					dmg:ScaleDamage(jcms.npc_GetScaledDamage(jcms.director and jcms.director.livingPlayers))
				end
				if attacker.jcms_maxScaledDmg then 
					dmg:SetDamage( math.min(attacker.jcms_maxScaledDmg, dmg:GetDamage()) )
				end
			end
			
			if jcms.team_JCorp(ent) then
				local hp, hpMax = ent:Health(), ent:GetMaxHealth()
				local fraction = math.Clamp(math.Remap(hp, hpMax*0.1, hpMax*0.9, 0, 1), 0, 1)
				local scale = Lerp(fraction, 0.5, 1.0)
				dmg:ScaleDamage(scale)
			end

			if ent:IsPlayer() and ent:GetNWEntity("jcms_vehicle") then
				local veh = ent:GetNWEntity("jcms_vehicle")
				if veh.RedirectDamage then
					veh:RedirectDamage(ent, dmg)
				end
			end
			
			if attacker.jcms_damageEffect then 
				attacker:jcms_damageEffect(ent, dmg)
			end
			
			if ent.jcms_TakeDamage then
				ent:jcms_TakeDamage(dmg, attacker)
			end

			if ( (attacker:IsPlayer() and attacker.jcms_faction) or (inflictor:IsPlayer() and inflictor.jcms_faction) ) and ( jcms.team_GoodTarget(ent) and jcms.team_JCorp(ent) ) then
				local armorDamage = 0
				local healthDamage = dmg:GetDamage()

				if ent:IsPlayer() then
					armorDamage = math.min( ent:Armor(), healthDamage )
					healthDamage = healthDamage - armorDamage
				end

				if armorDamage > 0 then
					jcms.net_SendNPCDamageReport(attacker, ent, true, armorDamage)
				end

				if healthDamage > 0 then
					jcms.net_SendNPCDamageReport(attacker, ent, false, healthDamage)
				end
			end
		end

		if IsValid(attacker) and (attacker:GetClass() == "npc_headcrab_poison" or attacker:GetClass() == "npc_headcrab_black") then
			--Their default behaviour seems to be hardcoded in hl2, and messing with the damageinfo breaks it (causes them to instakill).
			--This is a bandaid solution to that. 

			local hp = ent:Health()
			if ent:IsPlayer() then
				dmg:SetDamage( math.min(hp-5, dmg:GetDamage()) )
			else
				dmg:SetDamage(math.min(math.max(0, hp-1), 5))
			end
		end
	end)
	
	hook.Add("ScaleNPCDamage", "jcms_NpcDamage" , function(npc, hitGroup, dmgInfo)
		local npcTbl = npc:GetTable()
		if npcTbl.jcms_ScaleDamage then
			npcTbl.jcms_ScaleDamage(npc, hitGroup, dmgInfo)
		end
	end)
	
	hook.Add("PostEntityTakeDamage", "jcms_Adjustments", function(ent, dmg)
		local entTbl = ent:GetTable()
		if entTbl.jcms_PostTakeDamage then
			entTbl.jcms_PostTakeDamage(ent, dmg)
		end
	end)
	
	hook.Add("PostEntityTakeDamage", "jcms_DamageShare", function(ent, dmg)
		local damageShare = ent.jcms_damageShare
		if damageShare then
			local attacker = dmg:GetAttacker()
			
			if (attacker ~= ent) and jcms.team_JCorp(attacker) then
				damageShare[ attacker ] = (damageShare[ attacker ] or 0) + dmg:GetDamage()
			end
		end
	end)

	hook.Add("EntityFireBullets", "jcms_dmgOverride", function(ent, bulletData)
		local entTbl = ent:GetTable()
		if entTbl.jcms_EntityFireBullets then 
			entTbl.jcms_EntityFireBullets(ent, bulletData)
		end
	
		local callBack = bulletData.Callback
		bulletData.Callback = function(attacker, tr, dmgInfo)
			if isfunction(callBack) then callBack(attacker, tr, dmgInfo) end
			local target = tr.Entity
			if IsValid(target) and target.jcms_ignoreDefaultDamageEffects then
				target:TakeDamageInfo(dmgInfo)
			end
		end

		return true
	end)

	hook.Add("jcms_PlayerNetReady", "jcms_OnActivate", function(ply)
		local sid64 = ply:SteamID64()
		if jcms.director and jcms.director.persisting_loadout then
			ply.jcms_lastLoadout = jcms.director.persisting_loadout[ sid64 ]
			ply:SetNWString("jcms_desiredclass", jcms.director.persisting_class[ sid64 ] or "infantry")
			ply:SetNWInt("jcms_cash", jcms.director.persisting_cash[ sid64 ] or jcms.runprogress_GetStartingCash(ply))
			jcms.printf("Restoring loadout, class and cash for player " .. tostring(ply))
		end

		local count = 0
		for i, ent in ents.Iterator() do
			if ent.jcms_owner_sid64 == sid64 then
				ent.jcms_owner = ply
				ent.jcms_owner_sid64 = nil
				count = count + 1
			end
		end
		if count > 0 then
			jcms.printf("%s joined back, %d of their owned entities have been restored", ply, count)
		end

		if ply:IsBot() then return end
		jcms.net_NotifySquadChange(ply, true)
		jcms.net_SendFogData(ply) --Currently doesn't update/assumes the fog stays static. Might cause weird behaviour on maps that edit their fog. 
		jcms.net_SendManyOrders(jcms.orders, ply)
		jcms.net_SendWeaponPrices(jcms.weapon_prices, ply)

		local currentObjectives = jcms.mission_GetObjectives()
		if #currentObjectives > 0 then
			jcms.net_ShareMissionData(currentObjectives, ply)
		end
	end)

	hook.Add("PlayerDisconnected", "jcms_OnDisconnect", function(ply)
		jcms.net_NotifySquadChange(ply, false)
		
		if jcms.director then
			jcms.director.persisting_loadout = jcms.director.persisting_loadout or {}
			jcms.director.persisting_class = jcms.director.persisting_class or {}
			jcms.director.persisting_cash = jcms.director.persisting_cash or {}
			
			local sid64 = ply:SteamID64()
			if type(sid64) == "string" and #sid64 > 0 then
				if ply.jcms_lastLoadout then
					jcms.director.persisting_loadout[ sid64 ] = ply.jcms_lastLoadout
				elseif ply:GetObserverMode() == OBS_MODE_NONE then
					local loadout = {}
					
					for i, wep in ipairs(ply:GetWeapons()) do
						local class = wep:GetClass()
						if class ~= "weapon_stunstick" and class ~= "weapon_physcannon" then
							loadout[ class ] = 1
						end
					end

					jcms.director.persisting_loadout[ sid64 ] = loadout
				end

				jcms.director.persisting_class[ sid64 ] = ply:GetNWString("jcms_desiredclass", "infantry")
				jcms.director.persisting_cash[ sid64 ] = ply:GetNWInt("jcms_cash", 0)
			end
		end

		if ply:GetObserverMode() == OBS_MODE_NONE and ply:Alive() then
			ply:EmitSound("ambient/machines/teleport4.wav")
			
			local ed = EffectData()
			ed:SetOrigin(ply:GetPos())
			ed:SetFlags(1)
			util.Effect("jcms_evacbeam", ed)
		end
	end)

	hook.Add("PlayerDisconnected", "jcms_SaveOwnership", function(ply)
		local sid64 = ply:SteamID64()
		local count = 0
		for i, ent in ipairs(ents.GetAll()) do
			if ent.jcms_owner == ply then
				ent.jcms_owner = nil
				ent.jcms_owner_sid64 = sid64
				count = count + 1
			end
		end
		if count > 0 then
			jcms.printf("%s left the server, %d of their owned entities have been reassigned", ply, count)
		end
	end)

	hook.Add("PlayerLeaveVehicle", "jcms_preventStuck", function(ply, vehicle)
		local plyPos = ply:GetPos()

		local tr = util.TraceEntity({
			start = plyPos,
			endpos = plyPos,
			mask = MASK_PLAYERSOLID_BRUSHONLY
		}, ply)

		if tr.Hit then --We're stuck in something, try to put us in a valid navarea.
			local bounds = Vector(500, 500, 500)
			for i, area in ipairs(navmesh.FindInBox( plyPos - bounds, plyPos + bounds )	) do 
				if area:GetSizeX() > 50 and area:GetSizeY() > 50 and jcms.mapgen_ValidArea(area) then 
					ply:SetPos(area:GetCenter())
					break
				end
			end
		end
	end)

	hook.Add("PlayerDroppedWeapon", "jcms_weaponDrop", function(owner, wep)
		if IsValid(owner) and IsValid(wep) and owner:IsPlayer() then
			timer.Simple(0, function()
				if IsValid(owner) and IsValid(wep) then
					if jcms.util_IsStunstick(wep) then
						owner:PickupWeapon(wep)
					else
						wep.jcms_canPickup = true -- So that we can pick it back up.
					end
				end
			end)
		end
	end)
-- // }}}

-- // Run Progress {{{

	jcms.runprogress = jcms.runprogress or {
		difficulty = 0.9,
		winstreak = 0,
		totalWins = 0,
		playerStartingCash = {}, -- key is Steam ID 64, value is starting cash. 

		lastMission = "",
		lastFaction = ""
	}

	function jcms.runprogress_CalculateDifficultyFromWinstreak(winstreak, totalWins)
		local newPlayerScalar = 1 - math.max((6 - totalWins), 0) * 0.06
		return (0.9 + winstreak * 0.175) * newPlayerScalar
		
		--Winstreaks increase difficulty (17.5% per mission).
		--Being new to the game (having fewer than 5 wins) also reduces your difficulty. This scales from 25% to 0% reduction
	end

	function jcms.runprogress_GetDifficulty()
		return jcms.runprogress.difficulty
	end

	function jcms.runprogress_Victory()
		local rp = jcms.runprogress
		rp.winstreak = rp.winstreak + 1
		rp.totalWins = rp.totalWins + 1
		rp.difficulty = jcms.runprogress_CalculateDifficultyFromWinstreak(rp.winstreak, rp.totalWins)
		game.GetWorld():SetNWInt("jcms_winstreak", rp.winstreak)
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
		local sid64 = tostring(ply_or_sid64)
		if type(ply_or_sid64) == "Player" then
			sid64 = ply_or_sid64:SteamID64()
		end
		sid64 = "_" .. sid64 --Stop JSONToTable from obliterating us.

		return jcms.runprogress.playerStartingCash[ sid64 ] or jcms.cvar_cash_start:GetInt()
	end

	function jcms.runprogress_UpdateAllPlayers()
		for i, ply in ipairs(player.GetAll()) do 
			ply:SetNWInt("jcms_cash", jcms.runprogress_GetStartingCash(ply))
			print(jcms.runprogress_GetStartingCash(ply))
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
	end

	function jcms.runprogress_GetLastMissionTypes()
		return jcms.runprogress.lastMission, jcms.runprogress.lastFaction
	end

	function jcms.runprogress_SetLastMission()
		local rp = jcms.runprogress
		rp.lastMission = jcms.util_GetMissionType()
		rp.lastFaction = jcms.util_GetMissionFaction()
	end

-- // }}}

-- // Friendly-Fire Tracking / other player data {{{
	jcms.playerData = jcms.playerData or {
		playerFFKills = {},
		playerLastFFKill = {}
	}


	hook.Add("PlayerSpawn", "jcms_restorePlayerData", function(ply) 
		local lastFFKill = jcms.playerData_lastFriendlyKill(ply)

		if os.time() - lastFFKill > 60 * 60 * 4 then --If our last kill was 4h ago reset
			jcms.playerData_SetFriendlyKills(ply, 0)
			return
		end

		ply:SetNWInt("jcms_friendlyfire_counter", jcms.playerData_GetFriendlyKills(ply))
	end)

	function jcms.playerData_SetFriendlyKills(ply, amount)
		local sid64 = ply:SteamID64()
		sid64 = "_" .. sid64 --Stop JSONToTable from obliterating us.

		jcms.playerData.playerFFKills[sid64] = amount
		ply:SetNWInt("jcms_friendlyfire_counter", amount)
	end

	function jcms.playerData_GetFriendlyKills(ply_or_sid64)
		local sid64 = tostring(ply_or_sid64)
		if type(ply_or_sid64) == "Player" then
			sid64 = ply_or_sid64:SteamID64()
		end
		sid64 = "_" .. sid64 --Stop JSONToTable from obliterating us.

		return jcms.playerData.playerFFKills[sid64] or 0
	end

	function jcms.playerData_AddFriendlyKill(ply)
		local sid64 = ply:SteamID64()
		sid64 = "_" .. sid64 --Stop JSONToTable from obliterating us.

		local newKills = (jcms.playerData.playerFFKills[sid64] or 0) + 1
		jcms.playerData.playerFFKills[sid64] = newKills
		jcms.playerData.playerLastFFKill[sid64] = os.time()

		ply:SetNWInt("jcms_friendlyfire_counter", newKills)
	end

	function jcms.playerData_lastFriendlyKill(ply)
		local sid64 = ply:SteamID64()
		sid64 = "_" .. sid64 --Stop JSONToTable from obliterating us.
		return jcms.playerData.playerLastFFKill[sid64] or 0
	end

	--TODO: Shared/use the NW int instead.
	function jcms.playerData_IsPlayerLiability(ply_or_sid64)
		return jcms.playerData_GetFriendlyKills(ply_or_sid64) > 4
	end
-- // }}}

-- // Cash {{{

	function jcms.cash_CashFromBonuses(bonuses)
		local total = 0

		for i, bonus in ipairs(bonuses) do
			total = total + ( tonumber(bonus.cash) or 0 )
		end

		return math.ceil(total)
	end

-- // }}}

-- // Player Classes {{{

	hook.Add("EntityTakeDamage", "jcms_ClassDamage", function(ent, dmg)
		if ent:IsPlayer() then
			ent.jcms_lastDamageType = dmg:GetDamageType()
			
			local noBypass = dmg:IsFallDamage() or bit.band(dmg:GetDamageType(), bit.bor(DMG_BURN, DMG_SLOWBURN, DMG_DROWN, DMG_DIRECT))
			local data = jcms.class_GetData(ent)

			if data then

				if not noBypass then
					dmg:ScaleDamage(data.hurtMul)

					if data.hurtReduce > 0 then
						dmg:SubtractDamage( math.min(data.hurtReduce, dmg:GetDamage()) )
					elseif data.hurtReduce < 0 then
						dmg:AddDamage(-data.hurtReduce)
					end
				end

				if data.TakeDamage then
					data.TakeDamage(ent, dmg, data)
				end
			end
			
		end
	end)

	hook.Add("PostEntityTakeDamage", "jcms_DamageTracker", function(ent, dmg, took)
		if not took then return end
		if not ent:IsPlayer() then
			ent.jcms_lastDamaged = CurTime()
		end
	end)
	
	hook.Add("OnNPCKilled", "jcms_OnKill", function(npc, attacker, inflictor)
		if IsValid(attacker) and attacker:IsPlayer() then
			if jcms.director and jcms.director.gameover then
				return
			end
			
			local data = jcms.class_GetData(attacker)

			if data and data.OnKill then
				data.OnKill(attacker, npc, inflictor)
			end

			if jcms.team_JCorp_player(attacker) then
				if jcms.director then
					jcms.director_stats_AddKillForSweeper(attacker, jcms.director_stats_ClassifyKill(attacker, inflictor, npc.jcms_lastDamageType))

					if npc.jcms_faction then
						jcms.statistics_AddKills(attacker, npc.jcms_faction, 1)
					end

					local s, rtn = pcall(hook.Run, "MapSweepersDeathNPC", npc, attacker, inflictor, false)
					if not s then ErrorNoHalt(rtn) end
				end
			end
		end
		
		jcms.processBounty(npc, attacker, inflictor)
	end)

	hook.Add("PlayerPostThink", "jcms_PlayerThink", function(ply)
		if ply:IsOnFire() and ply:WaterLevel() > 0 then
			ply:Extinguish()
		end

		ply:SetNoTarget(ply:GetObserverMode() ~= OBS_MODE_NONE)
	end)

	hook.Add("PlayerPostThink", "jcms_Leeches", function(ply)
		local buildupDamagingThreshold = 10 -- This much time in water will start damaging you.
		local timeToRecover = 32 -- This much time outside of water will clear the leeches buildup.

		local time = CurTime()
		local interval = 0.4
		local nextWaterThink = jcms.leechesThinkTime or 0
		if time >= nextWaterThink then
			jcms.leechesThinkTime = time + interval

			if jcms.team_JCorp_player(ply) then
				local wl = ply:WaterLevel()

				if (wl > 0) then
					local leeches = ply.jcms_leechesBuildup or 0
					ply.jcms_leechesLastWaterTime = time

					local vol = math.Remap(leeches, 0, buildupDamagingThreshold, 0.25, 1)
					local pitch = math.Remap(leeches, 0, buildupDamagingThreshold, 89, 100)

					if not ply.jcms_leechSound1 then
						local filter = RecipientFilter()
						filter:AddPlayer(ply) 
						ply.jcms_leechSound1 = CreateSound( ply, "ambient/creatures/leech_water_churn_loop2.wav", filter )
					end

					if not ply.jcms_leechSound1:IsPlaying() then 
						ply.jcms_leechSound1:PlayEx(0, 80)
						ply.jcms_leechSound1:ChangeVolume(vol, 1)
						ply.jcms_leechSound1:ChangePitch(pitch, 1)
					elseif ply.jcms_leechSound1:GetPitch() < pitch then
						ply.jcms_leechSound1:ChangeVolume(vol, 1)
						ply.jcms_leechSound1:ChangePitch(pitch, 1)
					end

					if (leeches >= buildupDamagingThreshold) and (wl >= 1) then
						if not ply.jcms_leechSound2 then
							local filter = RecipientFilter()
							filter:AddPlayer(ply) 
							ply.jcms_leechSound2 = CreateSound( ply, "ambient/creatures/leech_bites_loop1.wav", filter )
						end

						if not ply.jcms_leechSound2:IsPlaying() then 
							ply.jcms_leechSound2:Play()
						elseif ply.jcms_leechSound2:GetPitch() < pitch then
							ply.jcms_leechSound2:ChangeVolume(vol, 1)
							ply.jcms_leechSound2:ChangePitch(pitch, 1)
						end

						local reduction = wl == 1 and ply:IsOnGround()

						local dmg = DamageInfo()
						dmg:SetDamage( (reduction and 0.2 or 1) * (math.max(0, ply.jcms_leechesBuildup - buildupDamagingThreshold)^0.5 + 0.25) )
						dmg:SetDamageType(DMG_GENERIC)
						dmg:SetAttacker(game.GetWorld())
						dmg:SetInflictor(game.GetWorld())
						dmg:SetReportedPosition(ply:WorldSpaceCenter())
						dmg:SetDamagePosition(ply:WorldSpaceCenter())
						dmg:SetDamageForce(jcms.vectorOrigin)
						ply:TakeDamageInfo(dmg)
					end

					if (wl >= 3) or (not ply:IsOnGround() and wl >= 1) then 
						ply.jcms_leechesBuildup = leeches + interval
					end
				elseif ( (ply.jcms_leechesBuildup or 0) > 0) and (time - (ply.jcms_leechesLastWaterTime or 0)) > timeToRecover then
					ply.jcms_leechesBuildup = 0
				else
					if ply.jcms_leechSound1 and ply.jcms_leechSound1:IsPlaying() then
						if ply.jcms_leechSound1:GetVolume() > 0.01 then
							ply.jcms_leechSound1:ChangeVolume(0, 1)
							ply.jcms_leechSound1:ChangePitch(70, 1)
						else 
							ply.jcms_leechSound1:Stop()
						end
					end

					if ply.jcms_leechSound2 and ply.jcms_leechSound2:IsPlaying() then 
						if ply.jcms_leechSound2:GetVolume() > 0.01 then
							ply.jcms_leechSound2:ChangeVolume(0, 0.25)
							ply.jcms_leechSound2:ChangePitch(70, 0.25)
						else
							ply.jcms_leechSound2:Stop()
						end
					end
				end
			else
				ply.jcms_leechesBuildup = nil
				ply.jcms_leechesLastWaterTime = nil

				if ply.jcms_leechSound1 and ply.jcms_leechSound1:IsPlaying() then
					ply.jcms_leechSound1:Stop()
					ply.jcms_leechSound1 = nil
				end
				
				if ply.jcms_leechSound2 and ply.jcms_leechSound2:IsPlaying() then
					ply.jcms_leechSound2:Stop()
					ply.jcms_leechSound2 = nil
				end
			end
		end
	end)

	hook.Add("PlayerPostThink", "jcms_IdleAnnouncer", function(ply)
		if jcms.director and (not jcms.director.gameover) and jcms.team_JCorp_player(ply) and ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE then
			local pos = ply:GetPos()
			local time = CurTime()
			
			if (not ply.jcms_idleLastPos) or (ply.jcms_idleLastPos:DistToSqr(pos) > 4) then
				ply.jcms_idleLastPos = pos
				ply.jcms_idleSince = time
			end

			local timeIdling = (time - ply.jcms_idleSince)
			if timeIdling > 120 and not jcms.director.debug then
				jcms.announcer_Speak(jcms.ANNOUNCER_IDLE, ply)
				ply.jcms_idleSince = time + math.random() * 5
			end
		end
	end)

	hook.Add("PlayerPostThink", "jcms_PlayerMenuThink", function(ply)
		if (ply:GetObserverMode() == OBS_MODE_FIXED or ply:GetObserverMode() == OBS_MODE_CHASE) then
			local eIndex = ply:EntIndex()
			local pos
			if jcms.pathfinder.airNodes[eIndex] then --Airgraph is our best bet for reliability. I should make a better solution later.
				local node = jcms.pathfinder.airNodes[eIndex]
				pos = node.pos
			else
				local spawn = ents.FindByClass("info_player_start")[1]
			
				if IsValid(spawn) then 
					pos = spawn:GetPos()
				else
					pos = Vector(0,0,0)
				end

				pos.z = pos.z + eIndex*72
			end
			
			ply:SetPos(pos)

			if not ply:Alive() then
				ply:Spawn()
				jcms.playerspawn_Menu(ply)
			end
		end
	end)

	hook.Add("Think", "jcms_VoteThink", function()
		if jcms.director and jcms.director.vote_time then
			local counts = {}
			local totalVotes = 0
			
			for player, map in pairs(jcms.director.votes) do
				counts[ map ] = (counts[ map ] or 0) + 1
				totalVotes = totalVotes + 1
			end

			if (game.SinglePlayer() and totalVotes > 0) or (CurTime() >= jcms.director.vote_time) then
				local winningVoteCount, winningMap = -1, nil
				for map in pairs(jcms.director.vote_maps) do
					if (counts[ map ] or 0) > winningVoteCount then
						winningVoteCount = counts[ map ] or 0
						winningMap = map
					end
				end

				if winningMap == game.GetMap() then
					jcms.mission_Clear()
				elseif not jcms.mapChanging then
					jcms.mapChanging = true
					RunConsoleCommand("changelevel", winningMap)
				end
			end
		end
	end)

	hook.Add("PlayerFootstep", "jcms_Footsteps", function(ply, pos, foot, sound, volume, rf)
		local data = jcms.class_GetData(ply)
		
		if data then
			local wl = ply:WaterLevel()
			local postfix = data.footstepSfxNoPostfix and "" or (foot == 0 and "Left" or "Right")
			
			if wl < 2 then
				ply:EmitSound(data.footstepSfx .. postfix, 50, 90, volume * 0.75)
			end
			
			if wl == 1 then
				ply:EmitSound("Water.Step" .. postfix)
			elseif wl == 2 then
				ply:EmitSound("Wade.Step" .. postfix)
			end
			
			return true
		end
	end)
	
	hook.Add("GetFallDamage", "jcms_FallDamage", function(ply, speed)
		local dmg = math.min(speed / 24, ply:GetMaxHealth() * 0.75)

		if ply.noFallDamage then
			local snd = "physics/body/body_medium_impact_soft" .. tostring(math.random(1,7)) .. ".wav"
			ply:EmitSound(snd, 75, 120, dmg/50)
			jcms.net_SendDamage(ply, DMG_FALL, true)
			return 0 
		end 

		local data = jcms.class_GetData(ply)
		if not data then return dmg end

		if data.noFallDamage and dmg > 0 then 
			local snd = "physics/body/body_medium_impact_soft" .. tostring(math.random(1,7)) .. ".wav"
			ply:EmitSound(snd, 75, 120, dmg/50)
			jcms.net_SendDamage(ply, DMG_FALL, true)
			return 0 
		end

		return dmg
	end)

	hook.Add("OnPlayerHitGround", "jcms_playerHitGround", function( ply, inWater, onFloater, speed )
		timer.Simple(0, function()
			if IsValid(ply) then 
				ply.noFallDamage = false
			end
		end)
	end)
	
	hook.Add("PropBreak", "jcms_CustomBlastEffect", function(breaker, prop)
		local kv = prop:GetKeyValues()
		if kv.ExplodeRadius and kv.ExplodeRadius > 0 then
			if prop:GetTable().jcms_customBreakBlastEffect then
				local ed = EffectData()
				ed:SetOrigin(prop:GetPos())
				ed:SetRadius(kv.ExplodeRadius)
				ed:SetNormal(prop:GetAngles():Right())
				ed:SetMagnitude(2.5)
				ed:SetFlags(prop:EntIndex())
				ed:SetFlags(1)
				util.Effect("jcms_blast", ed)
			end

			sound.EmitHint(bit.bor(SOUND_COMBAT, SOUND_DANGER, SOUND_CONTEXT_EXPLOSION), prop:GetPos(), kv.ExplodeRadius*10 + 512, 0.5)
		end
	end)
	
	hook.Add("PlayerUse", "jcms_LockedDoorTip", function(ply, ent)
		if (ent:GetClass() == "prop_door_rotating" or ent:GetClass() == "func_door") and ent:GetSaveTable().m_bLocked and not ent.jcms_breached and (not ent.jcms_lastTipTime or CurTime()-ent.jcms_lastTipTime > 5) then
			jcms.director_TryShowTip(ply, jcms.HINT_BREACH)
			ent.jcms_lastTipTime = CurTime()
		end
	end)

	hook.Add("KeyPress", "jcms_SwitchSpectatingEntity", function(ply, key)
		if jcms.director and ply:GetObserverMode() == OBS_MODE_CHASE and ply:Alive() then
			local switchDir = 0

			if key == IN_ATTACK then
				switchDir = 1
			elseif key == IN_ATTACK2 then
				switchDir = -1
			end

			if switchDir ~= 0 then
				local allTargets = {}
				local currentTarget = ply:GetObserverTarget()
				local currentTargetIndex = 1

				for i, oply in ipairs(team.GetPlayers(1)) do
					if IsValid(oply) and oply~=ply and oply:Alive() and oply:GetObserverMode() == OBS_MODE_NONE then
						table.insert(allTargets, oply)
						
						if currentTarget == oply then
							currentTargetIndex = #allTargets
						end
					end
				end

				local nextTarget = allTargets[ (currentTargetIndex+switchDir-1)%(#allTargets)+1 ]
				if IsValid(nextTarget) and nextTarget ~= currentTarget then
					ply:SpectateEntity(nextTarget)
				end
			end
		end
	end)
	
	hook.Add("CanPlayerEnterVehicle", "jcms_vehicleBlock", function(ply)
		if IsValid( ply:GetNWEntity("jcms_vehicle") ) then
			return false
		end
	end)

	hook.Add("PostEntityFireBullets", "jcms_headshotTracker", function(ent, bulletData)
		if IsValid(ent) and ent:IsPlayer() and jcms.team_JCorp_player(ent) then
			local tr = bulletData.Trace
			local target = tr.Entity

			if IsValid(target) then
				if target:IsNPC() then
					target.jcms_lastHurtTrace = tr
				end

				if target:Health() > 0 then
					if target:IsPlayer() and jcms.team_JCorp_player(target) then
						local time = CurTime()
						ent.jcms_friendlyFireCounter = (ent.jcms_friendlyFireCounter or 0) + 1
						
						if (time - (ent.jcms_lastFriendlyFire or 0) > 5) and ( (ent.jcms_friendlyFireCounter >= 4) or (target:Health() < target:GetMaxHealth() * 0.75 and ent.jcms_friendlyFireCounter >= 1 and target:Armor() <= 5) ) then
							ent.jcms_lastFriendlyFire = time
							ent.jcms_friendlyFireCounter = 0
							jcms.announcer_SpeakChance(0.85, jcms.ANNOUNCER_FRIENDLYFIRE, ent)
						end
					else
						ent.jcms_friendlyFireCounter = 0
					end

					ent.jcms_consecMisses = -2
				end
			else
				-- Misses tracker for the announcer
				local time = CurTime()
				if (not ent.jcms_lastMissTime) or (time - ent.jcms_lastMissTime > 0.75) then
					ent.jcms_consecMisses = (ent.jcms_consecMisses or 0) + 1
					ent.jcms_lastMissTime = time

					if ent.jcms_consecMisses >= math.random(7, 12) then
						ent.jcms_consecMisses = -math.random(4, 5)
						jcms.announcer_Speak(jcms.ANNOUNCER_AMMO_WASTE, ent)
					end
				end
			end
		end
	end)
	
	function GM:PlayerCanPickupItem(ply, item)
		return jcms.team_JCorp_player(ply) and item:IsPlayerHolding()
	end

	function GM:PlayerCanPickupWeapon(ply, wep)
		if (ply.jcms_justSpawned) or (ply.jcms_canGetWeapons) then
			return true
		else
			if jcms.team_JCorp_player(ply) then
				if (wep:CreatedByMap() and wep:IsPlayerHolding()) or (wep.jcms_canPickup) then
					return true
				else
					local ammoType = wep:GetPrimaryAmmoType()
					if ammoType > 0 then
						local hasAmmoType = not jcms.isAmmoTypeUseless(ply, ammoType)

						if hasAmmoType then
							ply:GiveAmmo(wep:Clip1(), ammoType)
						else
							jcms.giveCashForUselessAmmo(ply, ammoType, wep:Clip1())
						end
					end
					
					wep:Remove()
					return false
				end
			else
				return false
			end
		end
	end
	
	function GM:PlayerAmmoChanged(ply, ammoType, old, new)
		local diff = new - old
		if diff > 0 then
			local useless = jcms.isAmmoTypeUseless(ply, ammoType)
			if useless then
				local count = ply:GetAmmoCount(ammoType)
				ply:SetAmmo(0, ammoType)
				jcms.giveCashForUselessAmmo(ply, ammoType, count)
			end
		end
	end

	function GM:PlayerNoClip(ply, flying)
		if not flying then return true end -- Always allow stopping noclip

		if jcms.director and jcms.director.debug then
			return true
		else
			return false
		end
	end
	
	function GM:CanExitVehicle(veh, ply)
		if IsValid(veh.droppod) and veh.droppod._dropping and ply.jcms_dropTime and (CurTime() - ply.jcms_dropTime) < 7 then
			return false
		else
			return true
		end
	end
	
	function GM:SendDeathNotice()
		return false
	end

	function GM:HandlePlayerArmorReduction(ply, dmginfo)
		local dmgType = dmginfo:GetDamageType()
		
		if (ply:Armor() <= 0) or bit.band(dmgType, bit.bor(DMG_FALL, DMG_DROWN)) > 0 then 
			return 
		end

		if bit.band(dmgType, DMG_POISON) > 0 then --Poison enemies drain your shield instead of instakilling you.
			local dmg = dmginfo:GetDamage()
			local armour = ply:Armor()
			armour = math.max(armour - (dmg * 2), 0)

			ply:SetArmor(armour)
			dmginfo:SetDamage(0)
		end

		
		local armor = ply:Armor()
		local armorDmg = math.min(armor, dmginfo:GetDamage())
		local healthDmg = dmginfo:GetDamage() - armorDmg

		local armorDmgMultiplier = 1.0
		if bit.band(dmgType, DMG_SHOCK) > 0 then
			-- Electricity deals less damage to shields
			armorDmgMultiplier = 0.75
		end
		
		if healthDmg <= 0 and armorDmg >= 0 then
			ply:SetViewPunchAngles(Angle(-1, math.Rand(-0.2, 0.2), 0))
		end

		ply:SetArmor( math.max((armor - armorDmg)*armorDmgMultiplier, 0) )
		
		if ply:Armor() <= 0 then
			local ed = EffectData()
			ed:SetFlags(1)
			ed:SetColor(jcms.util_colorIntegerSweeperShield)
			ed:SetEntity(ply)
			util.Effect("jcms_shieldeffect", ed)
			
			ply:ScreenFade(SCREENFADE.IN, Color(4, 56, 255, 24), 0.3, 0.27)
			ply:EmitSound("jcms_shield_broken")
		elseif armorDmg > 0 then
			jcms_util_shieldDamageEffect(dmginfo, armorDmg)
		end

		healthDmg = math.min(healthDmg - 8, 0) --Forgiveness for shots that destroy shield.
		dmginfo:SetDamage(healthDmg)
	end

-- // }}}

-- // Players Death & Respawn {{{
		
	function jcms.playerspawn_RespawnAs(ply, mode, position, arg)
		ply:Freeze(false)
		ply:KillSilent()
		ply.jcms_justSpawned = true
		ply:Spawn()
		if mode == "sweeper" then
			if ply.jcms_lastLoadout then
				jcms.spawnmenu_PurchaseLoadout(ply, ply.jcms_lastLoadout, 0, 0) -- Restore the weapons you used to have for free
				ply.jcms_lastLoadout = nil
			end
			
			jcms.playerspawn_Sweeper(ply, position, arg) -- arg: No Drop Pod
		elseif mode == "npc" then
			ply.jcms_lastLoadout = nil
			ply:SetNWString("jcms_class", arg) -- arg: Player Class
			jcms.playerspawn_NPC(ply, position)
			ply.jcms_damageShare = {}
		elseif mode == "spectator" then
			jcms.playerspawn_Spectator(ply)
		else
			ply.jcms_lastLoadout = nil
			jcms.playerspawn_Menu(ply)
		end
		ply.jcms_justSpawned = nil
	end

	function GM:PlayerSpawn(ply, transition)
		ply.jcms_lastDeathTime = ply.jcms_lastDeathTime or 0
		
		if jcms.inTutorial then
			ply.jcms_justSpawned = true
			ply:SetNWString("class", "infantry")
			jcms.playerspawn_Sweeper(ply, ply:GetPos(), true)
			ply:SetNWInt("jcms_cash", 0)
			ply:SetTeam(1)
			ply.jcms_justSpawned = false
			jcms.net_SendRespawnEffect(ply)
		else
			ply:SetMaterial("")
			ply:SetColor(Color(255, 255, 255))

			if not jcms.mapdata.analyzed then
				jcms.mapgen_AnalyzeMap()
			end
			
			if jcms.mapdata.valid then
				if not ply.jcms_justSpawned then

					local d = jcms.director
					if d then
						if d.gameover then
							-- Send the player into mission end screen.
							jcms.net_SendMissionEnding(d.victory, ply)
						else
							-- Handle the player according to their pre-rejoin session.
							local state = jcms.director_stats_GetLockedState(d, ply)

							if state == "sweeper" then
								-- We've been here before. Now we're considered dead.
								ply:SetNWInt("jcms_desiredteam", 1)
								jcms.playerspawn_RespawnAs(ply, "spectator")
								ply.jcms_lastDeathTime = CurTime()
							elseif state == "evacuated" then
								-- We've evacuated before. Now we're just spectating with the option to be an NPC.
								ply:SetNWInt("jcms_desiredteam", 1)
								ply:SetNWBool("jcms_evacuated", true)
								jcms.playerspawn_RespawnAs(ply, "spectator")
								d.evacuated[ply] = true
							elseif state == "npc" then
								-- We're an NPC player, and we can't go back to sweepers even if we rejoin!
								ply:SetNWInt("jcms_desiredteam", 2)
								jcms.playerspawn_RespawnAs(ply, "spectator")
								ply:SetNWString("jcms_class", jcms.npc_PickPlayerNPCClass(jcms.director.faction))
								ply:SetTeam(2)
								ply.jcms_isNPC = true
							else
								-- We have never joined this game yet.
								if table.Count(d.evacuated) > 0 then
									-- Someone evacuated, we'll be considered evacuated as well
									ply:SetNWInt("jcms_desiredteam", 1)
									ply:SetNWBool("jcms_evacuated", true)
									jcms.playerspawn_RespawnAs(ply, "spectator")
									jcms.director_stats_SetLockedState(d, ply, "evacuated")
									d.evacuated[ply] = true
								else
									-- Take us to the lobby
									jcms.playerspawn_Menu(ply)
								end
							end
						end
					else
						-- Game is not ongoing. Send us to the lobby.
						jcms.playerspawn_Menu(ply)
					end
				end
			else
				jcms.playerspawn_Debug(ply)
			end
		end
	end

	function GM:DoPlayerDeath(ply, attacker, dmg)
		local veh = ply:GetNWEntity("jcms_vehicle", NULL)
		if IsValid(veh) then
			veh:SetDriver()
			ply:SetNWEntity("jcms_vehicle", NULL)
		end

		if not (jcms.director and ( (not ply.jcms_isNPC and jcms.director.evacuated[ply]) or jcms.director.gameover)) then
			local classData = jcms.class_GetData(ply)
			ply.jcms_lastDamageType = dmg:GetDamageType()

			local ct = CurTime()
			if classData and classData.deathSound then
				ply:EmitSound(classData.deathSound)
			end
			
			if jcms.team_JCorp_player(ply) then
				jcms.net_NotifyDeath(ply, ply.jcms_lastDamageType == DMG_GENERIC and attacker == ply)
				
				local overridesModel = false
				if dmg:GetDamage() >= 250 and bit.band(dmg:GetDamageType(), bit.bor(DMG_BLAST, DMG_BLAST_SURFACE, DMG_BURN, DMG_SLOWBURN, DMG_PLASMA)) > 0 then
					ply:SetModel("models/player/charple.mdl")
					overridesModel = true
				elseif dmg:GetDamage() >= 15 and bit.band(dmg:GetDamageType(), DMG_ACID) > 0 then
					ply:SetModel("models/player/skeleton.mdl")
					overridesModel = true
				end
				
				if overridesModel then
					ply:SetMaterial("")
				else
					ply:EmitSound("Player.Death")
				end
				
				ply.jcms_lastLoadout = {}
				for i, wep in ipairs(ply:GetWeapons()) do
					local class = wep:GetClass()
					if class ~= "weapon_stunstick" and class ~= "weapon_physcannon" then
						ply.jcms_lastLoadout[ class ] = 1
					end
				end

				jcms.statistics_AddOther(ply, "deaths", 1)
				jcms.director_stats_AddDeathForSweeper(ply)

				if IsValid(attacker) and attacker:IsPlayer() then
					if jcms.team_JCorp_player(attacker) and attacker ~= ply then
						jcms.statistics_AddOther(attacker, "ffire", 1)
						jcms.director_stats_AddKillForSweeper(attacker, 3)
						if not jcms.playerData_IsPlayerLiability(ply) then
							jcms.playerData_AddFriendlyKill(attacker)
						end
						jcms.announcer_Speak(jcms.ANNOUNCER_FRIENDLYFIRE_KILL)
					elseif jcms.team_NPC(attacker) then
						jcms.director_stats_AddKillForNPC(attacker, 0)
					end
				elseif (not game.SinglePlayer()) and (#jcms.GetAliveSweepers() >= 1) then
					jcms.announcer_Speak(jcms.ANNOUNCER_DEAD)
				end
			elseif jcms.team_NPC(ply) then
				if jcms.director then
					jcms.director_stats_AddDeathForNPC(ply)
					local s, rtn = pcall(hook.Run, "MapSweepersDeathNPC", ply, attacker, dmg:GetInflictor(), true)
					if not s then ErrorNoHalt(rtn) end
				end
				
				if IsValid(attacker) and attacker:IsPlayer() and jcms.team_JCorp_player(attacker) then
					if jcms.director then
						jcms.director_stats_AddKillForSweeper(attacker, jcms.director_stats_ClassifyKill(attacker, dmg:GetInflictor(), dmg:GetDamageType()))
					end

					jcms.processBounty(ply, attacker, dmg:GetInflictor())
				end
			end

			if classData and classData.OnDeath then
				classData.OnDeath(ply, attacker, dmg)
			end

			ply:CreateRagdoll()
			ply.jcms_lastDeathTime = ct
		end
	end

	function GM:PlayerSilentDeath(ply)
		
	end
	
	function GM:PlayerSetHandsModel(ply, ent)
		if ply:Team() == 1 then
			ent:SetModel("models/weapons/c_arms_combine.mdl")
			ent:SetSubMaterial(0, "models/jcms/c_arms_jcorp")
		else
			local classData = jcms.class_GetData(ply)

			if classData.handsModel then
				ent:SetModel(classData.handsModel)
			else
				local info = player_manager.RunClass(ply, "GetHandsModel")
				if not info then
					local playermodel = player_manager.TranslateToPlayerModelName(ply:GetModel())
					info = player_manager.TranslatePlayerHands(playermodel)
				end

				if info then
					ent:SetModel(info.model)
					ent:SetSkin(info.matchBodySkin and ply:GetSkin() or info.skin)
					ent:SetBodyGroups(info.body)
				end
			end
		end
	end

	function GM:PlayerDeathThink(ply)
		-- For handling players who spawned without a director present for some reason.
		-- If this is a valid map, we respawn the player in lobby so that they can start the game proper.
		-- If this is a tutorial map, we do a generic tutorial respawn.
		-- If this is NOT a valid map, we respawn the player in debug mode.
		
		-- NOTE: Will not get called for evacuated players and players in-lobby.
		if not jcms.director then
			if not ply.jcms_lastDeathTime or CurTime() - ply.jcms_lastDeathTime > 5 then
				ply:Spawn()
				if jcms.mapdata.valid then
					jcms.playerspawn_Menu(ply)
				else
					if jcms.inTutorial then
						ply.jcms_justSpawned = true
						ply:SetNWString("class", "infantry")
						jcms.playerspawn_Sweeper(ply, jcms.tutorialPos, true)
						ply:SetTeam(1)
						ply.jcms_justSpawned = false
						
						if jcms.tutorialPhase == 5 then
							ply:SetNWInt("jcms_cash", 500)
						end
					else
						jcms.playerspawn_Debug(ply)
					end
				end
			end
		end
		return true
	end

	function GM:GravGunPunt(ply, ent)
		if ent.GravGunPunt then
			return ent:GravGunPunt(ply)
		end

		return BaseClass.GravGunPunt(self, ply, ent)
	end

	function GM:GravGunOnPickedUp(ply, ent)
		if ent.GravGunOnPickedUp then
			return ent:GravGunOnPickedUp(ply)
		end

		return BaseClass.GravGunOnPickedUp(self, ply, ent)
	end

	function GM:CanPlayerSuicide(ply)
		return ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE
	end

	function jcms.playerspawn_Menu(ply)
		GAMEMODE:PlayerSpawnAsSpectator(ply)
		ply:Spectate(OBS_MODE_FIXED)
		ply:SetObserverMode(OBS_MODE_FIXED)
		ply:GodEnable()
		ply:Lock()

		local pos = ply:GetPos()
		pos.x = ply:EntIndex() * 64 - 2048
		pos.z = math.random(-1024, 1024)
		ply:SetPos(pos)

		ply:SetTeam(0)
		ply.jcms_canGetWeapons = true
		ply:Give("weapon_stunstick")
		ply.jcms_canGetWeapons = false
		
		ply:SetNWInt("jcms_cash", jcms.runprogress_GetStartingCash(ply))
	end
	
	function jcms.playerspawn_Spectator(ply)
		GAMEMODE:PlayerSpawnAsSpectator(ply)
		ply:Spectate(OBS_MODE_CHASE)
		ply:SetObserverMode(OBS_MODE_CHASE)
		ply:GodEnable()

		ply:SetPos(Vector(0,0,0))
		ply:SetTeam(0)
	end

	function jcms.playerspawn_Sweeper(ply, forcedPosition, noDropPod)
		ply:UnSpectate()
		ply:SetObserverMode(OBS_MODE_NONE)
		ply:UnLock()
		ply:GodDisable()

		ply:SetNWBool("jcms_ready", false)
		ply:SetTeam(1)

		local desiredClass = ply:GetNWString("jcms_desiredclass", "infantry")
		if not (jcms.classes[ desiredClass ] and jcms.classes[ desiredClass ].jcorp) then
			desiredClass = "infantry"
		end
		jcms.class_Apply(ply, desiredClass)

		ply:SetNWBool("jcms_flashlight", false)

		local spawnPos = ply:WorldSpaceCenter()
		
		if forcedPosition then
			spawnPos = forcedPosition
		else
			if jcms.director then
				local spawnpoints = jcms.director.sweeperSpawnpoints
				if spawnpoints and #spawnpoints > 0 then
					spawnPos = spawnpoints[ #spawnpoints ]
					spawnpoints[ #spawnpoints ] = nil
				else
					local zone = jcms.mapdata.zoneList[jcms.mapdata.largestZone]
					table.Shuffle(zone)
					
					for i, area in ipairs(zone) do
						if not jcms.mapgen_ValidArea(area) then continue end 
						if area:GetSizeX() < 128 or area:GetSizeY() < 128 then continue end

						local desiredSpawnPos = area:GetCenter() + area:GetRandomPoint()
						desiredSpawnPos:Mul(0.5)

						local upVec = Vector(0,0,5)
						local tr = util.TraceEntityHull({
							start = desiredSpawnPos + upVec,
							endpos = desiredSpawnPos + upVec
						}, ply)
						if tr.Hit then continue end 

						spawnPos = desiredSpawnPos
					end
				end
			end
		end
		
		local skyPos, skyClear = jcms.util_GetSky( spawnPos )
		if skyPos and skyClear and (not noDropPod) then
			local dropPod = ents.Create("jcms_droppod")
			dropPod:Drop(ply, spawnPos, skyPos)
			ply.jcms_dropTime = CurTime()
		else
			ply:SetPos(spawnPos)
			ply:EmitSound("ambient/machines/teleport4.wav")
		end
		
		jcms.npc_UpdateRelations(ply)
		ply:SetupHands()
	end
	
	function jcms.playerspawn_NPC(ply, forcedPosition)
		ply:UnSpectate()
		ply:SetObserverMode(OBS_MODE_NONE)
		ply:UnLock()
		ply:GodDisable()
		ply.jcms_isNPC = true
		
		ply:SetNWBool("jcms_ready", false)
		ply:SetTeam(2)
		ply:SetupHands()
		
		if forcedPosition then
			ply:SetPos(forcedPosition)
		end

		ply:SetEyeAngles( Angle(0, math.random() * 360, 0) )

		jcms.class_Apply(ply, ply:GetNWString("jcms_class", "npc_combineelite"))
		ply:SetNWBool("jcms_flashlight", false)
		
		jcms.npc_UpdateRelations(ply)
	end
	
	function jcms.playerspawn_Debug(ply)
		ply:UnSpectate()
		ply:SetObserverMode(OBS_MODE_NONE)
		ply:UnLock()
		ply:GodEnable()
		
		jcms.class_Apply(ply, "infantry")
		ply:SetNWBool("jcms_flashlight", false)
		
		ply.jcms_canGetWeapons = true
		ply:Give("weapon_stunstick")
		ply:Give("weapon_physcannon")
		ply.jcms_canGetWeapons = false
		
		ply:SetTeam(0)
		ply:SetupHands()
		
		ply:ChatPrint("[Map Sweepers] This map has no NavMesh!")
	end

-- // }}}

-- // Maps {{{
	local map_blacklist = { --CSS and TF2 maps have navmeshes, but they're incompatible with gmod.
		--CSS
			["cs_assault"] = true,
			["cs_compound"] = true,
			["cs_havana"] = true,
			["cs_italy"] = true,
			["cs_militia"] = true,
			["cs_office"] = true,

			["de_aztec"] = true,
			["de_cbble"] = true,
			["de_chateau"] = true,
			["de_dust"] = true,
			["de_dust2"] = true,
			["de_inferno"] = true,
			["de_nuke"] = true,
			["de_piranesi"] = true,
			["de_port"] = true,
			["de_prodigy"] = true,
			["de_tides"] = true,
			["de_train"] = true,

		--TF2
			["arena_badlands"] = true,
			["arena_byre"] = true,
			["arena_granary"] = true,
			["arena_lumberyard"] = true,
			["arena_lumberyard_event"] = true,
			["arena_nucleus"] = true,
			["arena_offblast_final"] = true,
			["arena_arena_perks"] = true,
			["arena_ravine"] = true,
			["arena_sawmill"] = true, --10
			["arena_watchtower"] = true,
			["arena_well"] = true,

			["cp_5gorge"] = true,
			["cp_altitude"] = true,
			["cp_ambush_event"] = true,
			["cp_badlands"] = true,
			["cp_brew"] = true,
			["cp_burghausen"] = true,
			["cp_canaveral_5cp"] = true,
			["cp_carrier"] = true,
			["cp_cloak"] = true,
			["cp_coldfront"] = true, --10
			["cp_darkmarsh"] = true,
			["cp_degrootkeep"] = true,
			["cp_degrootkeep_rats"] = true,
			["cp_dustbowl"] = true,
			["cp_egypt_final"] = true,
			["cp_fastlane"] = true,
			["cp_fortezza"] = true,
			["cp_foundry"] = true,
			["cp_freaky_fair"] = true,
			["cp_freight_final1"] = true, -- 20
			["cp_frostwatch"] = true,
			["cp_gorge"] = true,
			["cp_gorge_event"] = true,
			["cp_granary"] = true,
			["cp_gravelpit"] = true,
			["cp_gravelpit_snowy"] = true,
			["cp_gullywash_final1"] = true,
			["cp_hadal"] = true,
			["cp_hardwood_final"] = true,
			["cp_junction_final"] = true, --30
			["cp_lavapit_final"] = true, 
			["cp_manor_event"] = true,
			["cp_mercenarypark"] = true,
			["cp_metalworks"] = true,
			["cp_mossrock"] = true,
			["cp_mountainlab"] = true,
			["cp_overgrown"] = true,
			["cp_powerhouse"] = true,
			["cp_process_final"] = true,
			["cp_reckoner"] = true, --40
			["cp_snakewater_final1"] = true,
			["cp_snowplow"] = true,
			["cp_spookeyridge"] = true,
			["cp_standin_final"] = true,
			["cp_steel"] = true,
			["cp_sulfur"] = true,
			["cp_sunshine"] = true,
			["cp_sunshine_event"] = true,
			["cp_vanguard"] = true,
			["cp_well"] = true, -- 50
			["cp_yukon_final"] = true,

			["ctf_2fort"] = true,
			["ctf_2fort_invasion"] = true,
			["ctf_applejack"] = true,
			["ctf_crasher"] = true,
			["ctf_doublecross"] = true,
			["ctf_doublecross_snowy"] = true,
			["ctf_foundry"] = true,
			["ctf_frosty"] = true,
			["ctf_gorge"] = true,
			["ctf_haarp"] = true, --10 
			["ctf_hellfire"] = true,
			["ctf_helltrain_event"] = true,
			["ctf_landfall"] = true,
			["ctf_pelican_peak"] = true,
			["ctf_penguin_peak"] = true,
			["ctf_sawmill"] = true,
			["ctf_snowfall_final"] = true,
			["ctf_thundermountain"] = true,
			["ctf_turbine"] = true,
			["ctf_turbine_winter"] = true, --20 
			["ctf_well"] = true,

			["koth_badlands"] = true,
			["koth_bagel_event"] = true,
			["koth_brazil"] = true,
			["koth_cachoeria"] = true,
			["koth_cascade"] = true,
			["koth_harvest_event"] = true,
			["koth_harvest_final"] = true,
			["koth_highpass"] = true,
			["koth_king"] = true,
			["koth_krampus"] = true, --10
			["koth_lakeside_event"] = true,
			["koth_lakeside_final"] = true,
			["koth_lazarus"] = true,
			["koth_los_muertos"] = true,
			["koth_maple_ridge_event"] = true,
			["koth_megalo"] = true,
			["koth_megaton"] = true,
			["koth_moonshine_event"] = true,
			["koth_nucleus"] = true,
			["koth_overcast_final"] = true, --20
			["koth_probed"] = true,
			["koth_rotunda"] = true,
			["koth_sawmill"] = true,
			["koth_sawmill_event"] = true,
			["koth_sharkbay"] = true,
			["koth_slasher"] = true,
			["koth_slaughter_event"] = true,
			["koth_slime"] = true,
			["koth_snowtower"] = true,
			["koth_suijin"] = true, --30
			["koth_synthetic_event"] = true,
			["koth_toxic"] = true,
			["koth_undergrove_event"] = true,
			["koth_viaduct"] = true,
			["koth_viaduct_event"] = true,

			["mvm_bigrock"] = true,
			["mvm_coaltown"] = true,
			["mvm_decoy"] = true,
			["mvm_ghost_town"] = true,
			["mvm_manhattan"] = true,
			["mvm_mannworks"] = true,
			["mvm_rottenburg"] = true,

			["pass_brickyard"] = true,
			["pass_district"] = true,
			["pass_timbertown"] = true,

			["pd_atom_smash"] = true,
			["pd_circus"] = true,
			["pd_cursed_cove_event"] = true,
			["pd_farmaggedon"] = true,
			["pd_galleria"] = true,
			["pd_mannsylvania"] = true,
			["pd_monster_bash"] = true,
			["pd_pit_of_death_event"] = true,
			["pd_selbyen"] = true,
			["pd_snowville_event"] = true, --10
			["pd_watergate"] = true,
			
			["pl_badwater"] = true,
			["pl_barnblitz"] = true,
			["pl_bloodwater"] = true,
			["pl_borneo"] = true,
			["pl_breadspace"] = true,
			["pl_cactuscanyon"] = true,
			["pl_camber"] = true,
			["pl_cashworks"] = true,
			["pl_chilly"] = true,
			["pl_coal_event"] = true, --10
			["pl_corruption"] = true,
			["pl_embargo"] = true,
			["pl_emerge"] = true,
			["pl_enclosure_final"] = true,
			["pl_fifthcurve_event"] = true,
			["pl_frontier_final"] = true,
			["pl_frostcliff"] = true,
			["pl_goldrush"] = true,
			["pl_hasslecastle"] = true,
			["pl_hoodoo_final"] = true, --20
			["pl_millstone_event"] = true,
			["pl_odyssey"] = true,
			["pl_patagonia"] = true,
			["pl_phoenix"] = true,
			["pl_pier"] = true,
			["pl_precipice_event_final"] = true,
			["pl_rubmle_event"] = true,
			["pl_rumford_event"] = true,
			["pl_sludgepit_event"] = true,
			["pl_snowycoast"] = true, --30
			["pl_spineyard"] = true,
			["pl_swiftwater_final1"] = true,
			["pl_terror_event"] = true,
			["pl_thundermountain"] = true,
			["pl_upward"] = true,
			["pl_venice"] = true,
			["pl_wutville_event"] = true,
			
			["plr_barnabay"] = true,
			["plr_cutter"] = true,
			["plr_hacksaw"] = true,
			["plr_hacksaw_event"] = true,
			["plr_hightower"] = true,
			["plr_hightower_event"] = true,
			["plr_nightfall_final"] = true,
			["plr_pipeline"] = true,
			
			["rd_asteroid"] = true,
			
			["sd_doomsday"] = true,
			["sd_doomsday_event"] = true,
			
			["tc_hydro"] = true,

			["tow_dynamite"] = true,
			
			["tr_dustbowl"] = true,
			["tr_target"] = true,
			
			["vsh_distillery"] = true,
			["vsh_maul"] = true,
			["vsh_nucleus"] = true,
			["vsh_outburst"] = true,
			["vsh_skirmish"] = true,
			["vsh_tinyrock"] = true,
			
			["zi_atoll"] = true,
			["zi_blazehattan"] = true,
			["zi_devastation_final1"] = true,
			["zi_murky"] = true,
			["zi_sanitarium"] = true,
			["zi_woods"] = true,
	}

	--[[
		Detecting navmeshes / Nodegraphs is unfortunately highly unreliable.
		As a bandaid I've created a system for bypassing these checks, which can
		be set up manually, or automatically on loading a map.

		This seems to sometimes happen even with default maps sometimes, so I'm just including everything.
	--]]
	jcms.validMaps = {
		--Pre-made list to save people some trouble.
		--Vanilla
		["gm_construct"] = true,
		["jcms_jcorpdistrict"] = true,
		["jcms_mafiadistrict"] = true,
		
		--Recommended collection
		["gm_voidtown"] = true,
		["gm_citygateway"] = true,
		["gm_diprip_refinery"] = true,
		["gm_lair"] = true,
		["gm_born"] = true,				--This one has packed content which means it just outright doesn't show up at all.
		["gm_shattered_reality"] = true,
		["gm_hillfoot_construct"] = true,
	}

	concommand.Add("jcms_addValidMap", function(ply, cmd, args)
		if not(not ply:IsPlayer() or ply:IsAdmin()) then return end
		
		local map = tostring(args[1]) or ""
		jcms.addValidMap(map)
	end, nil, "Manually mark a map as compatible (for maps with packed navmeshes/nodegraphs).")

	function jcms.addValidMap(map)
		jcms.validMaps[map] = true
	end

	function jcms.generateValidMapOptions()
		local validMaps = {}
		
		local maps = file.Find("maps/*.bsp", "GAME")
		table.Shuffle(maps)
		
		for i, map in ipairs(maps) do
			map = map:gsub("%.bsp", "")
			if
				not map_blacklist[map] and
				(jcms.validMaps[map] or --Known as valid
				((map ~= game.GetMap()) --or detected as valid (unreliable)
				and file.Exists("maps/" .. map .. ".nav", "GAME")
				and file.Exists("maps/graphs/" .. map .. ".ain", "GAME")))
			then
				table.insert(validMaps, map)
			end
		end
		
		return validMaps
	end

	function jcms.giveCash(ply, amount)
		if IsValid(ply) and ply:IsPlayer() then
			local added = math.ceil( tonumber(amount) or 0 )
			ply:SetNWInt("jcms_cash", ply:GetNWInt("jcms_cash") + added)
			
			if added > 0 then
				jcms.net_SendCashEarn(ply, added)
			end
		end
	end
-- // }}}
	
-- // Misc {{{
	function jcms.processBounty(npc, attacker, inflictor)
		if jcms.director then
			if jcms.director_IsSuddenDeath() then
				return
			end
		end
		
		local bounty = npc.jcms_bounty or 0
		
		if bounty > 0 then
			bounty = bounty * jcms.cvar_cash_mul_base:GetFloat()

			if IsValid(inflictor) and inflictor:IsWeapon() then
				if jcms.util_IsStunstick(inflictor) then
					bounty = bounty * jcms.cvar_cash_mul_stunstick:GetFloat()
				else
					local ammotype = game.GetAmmoName( inflictor:GetPrimaryAmmoType() )

					if ammotype == "Pistol" or ammotype == "357" then
						bounty = bounty + jcms.cvar_cash_bonus_sidearm:GetInt()
					end
				end
			end

			if not npc:OnGround() then
				bounty = bounty + jcms.cvar_cash_bonus_airborne:GetInt()
			end

			local tr = npc.jcms_lastHurtTrace
			if tr then
				local traceLength = tr.StartPos:Distance( tr.HitPos )

				local headshotDistance = jcms.cvar_distance_headshot:GetInt()
				local headshotCashPerDistance = jcms.cvar_distance_headshot_extralengths:GetInt()
				local headshotBonus = jcms.cvar_cash_bonus_headshot:GetInt()
				local headshotInstakillBonus = jcms.cvar_cash_bonus_headshot_instakill:GetInt()

				local snipingDistance = jcms.cvar_distance_very_far:GetInt()
				local snipingMul = jcms.cvar_cash_mul_very_far:GetFloat()
				
				if traceLength >= headshotDistance then
					bounty = bounty + math.ceil( (traceLength - headshotDistance) / headshotCashPerDistance )
					
					if tr.HitGroup == HITGROUP_HEAD then
						local instakill = (not npc.jcms_damageShare) or next(npc.jcms_damageShare) == nil
						bounty = bounty + (instakill and headshotInstakillBonus or headshotBonus)
					end
				end

				if traceLength >= snipingDistance then
					bounty = math.ceil(bounty * snipingMul)
				end
			end

			bounty = bounty * jcms.cvar_cash_mul_final:GetFloat()
			jcms.spreadContributionBounty(npc, bounty, attacker)
		end
	end
	
	function jcms.spreadContributionBounty(npc, totalBounty, lastAttacker)
		local damageShare = npc.jcms_damageShare
		if damageShare then
			local totalDamage = 0
			local plyCount = 0
			for ply, shareOfDamage in pairs(damageShare) do
				if IsValid(ply) then
					totalDamage = totalDamage + shareOfDamage
					plyCount = plyCount + 1
				end
			end
			
			if plyCount > 1 then
				if totalDamage > 0 then
					for ply, shareOfDamage in pairs(damageShare) do
						local bounty = math.ceil(totalBounty * shareOfDamage / totalDamage)
						jcms.giveCash(ply, bounty)
						jcms.statistics_AddEXP(ply, math.ceil(bounty*0.9 + 10))
					end
				end
			elseif plyCount == 1 then
				local ply = next(damageShare)
				jcms.giveCash(ply, totalBounty)
				jcms.statistics_AddEXP(ply, totalBounty + 20)
			elseif plyCount == 0 and IsValid(lastAttacker) and lastAttacker:IsPlayer() and jcms.team_JCorp_player(lastAttacker) then
				jcms.giveCash(lastAttacker, totalBounty)
				jcms.statistics_AddEXP(lastAttacker, totalBounty)
			end
		end
	end

	function jcms.isAmmoTypeUseless(ply, ammoType)
		if type(ammoType) == "string" then
			if jcms.weapon_allowedAmmoTypes[ ammoType:lower() ] then
				return false
			end

			ammoType = game.GetAmmoID(ammoType)
		elseif type(ammoType) == "number" then
			if jcms.weapon_allowedAmmoTypes[ game.GetAmmoName(ammoType) or "" ] then
				return false
			end
		end
		
		for i, w in ipairs(ply:GetWeapons()) do 
			if w:GetPrimaryAmmoType() == ammoType or w:GetSecondaryAmmoType() == ammoType then
				return false
			end
		end
		
		return true
	end
	
	function jcms.giveCashForUselessAmmo(ply, ammoType, count)
		if tonumber(ammoType) then
			ammoType = game.GetAmmoName(tonumber(ammoType))
		end
		
		if type(ammoType) == "string" then
			local cost = jcms.weapon_ammoCosts[ string.lower(ammoType) ]
			cost = cost or jcms.weapon_ammoCosts._DEFAULT
			
			jcms.giveCash(ply, math.floor(count * cost * 0.25))
			-- todo Play sound
		end
	end

	function jcms.GetSweepersInRange(point, dist)
		local sweepers = jcms.GetAliveSweepers()

		local distSqr = dist^2
		for i=#sweepers, 1, -1 do 
			local ply = sweepers[i]
			if ply:GetPos():DistToSqr(point) > distSqr then 
				table.remove(sweepers, i)
			end
		end
		return sweepers
	end

	function jcms.GetNearestSweeper(pos)
		local sweepers = jcms.GetAliveSweepers()

		local sweeper = NULL
		local closestDist = math.huge
		for i, ply in ipairs(sweepers) do
			local dist = ply:GetPos():Distance(pos)
			if dist < closestDist then
				sweeper = ply
				closestDist = dist
			end
		end

		return sweeper, closestDist
	end

-- // }}}

-- // Console Commands {{{

	concommand.Add("jcms_givecash", function(ply, cmd, args)
		local oldCash = ply:GetNWInt("jcms_cash")
		local giving = math.floor(tonumber(args[1]) or 0)
		ply:SetNWInt("jcms_cash", oldCash + giving)
		print( ("Giving %d cash to %s (%d -> %d)"):format(giving, ply:Nick(), oldCash, oldCash+giving) )
	end, nil, "Give yourself J Corp Cash.", FCVAR_CHEAT)
	
	concommand.Add("jcms_hack", function(ply, cmd, args)
		local terminal = ply:GetEyeTrace().Entity
		if IsValid(terminal) and terminal:GetNWBool("jcms_terminal_locked") then
			jcms.terminal_Unlock(terminal, ply, false)
		end
	end, nil, "Instantly unlocks the terminal you're looking at.", FCVAR_CHEAT)
	
	concommand.Add("jcms_debug_enable", function(ply, cmd, args)
		if not ply:IsPlayer() or ply:IsAdmin() then
			if jcms.director then
				if tostring(args[1]) == "0" then
					jcms.director.debug = false
					
					for i, ply in ipairs( player.GetAll() ) do
						ply:Kill()
					end
					
					jcms.mission_Clear()
				else
					jcms.director.debug = true
					for i, npc in ipairs(jcms.director.npcs) do
						if IsValid(npc) then
							npc:Remove()
						end
					end
					
					jcms.director.swarmNext = math.huge
					table.Empty(jcms.director.encounters)
					
					for i, ent in ipairs( ents.FindByClass("jcms_npcportal") ) do
						ent:Remove()
					end
					
					ply:SetHealth(9999999)
					jcms.printf("Debug mode ON. To revert it, use 'jcms_debug_enable 0'. All NPCs, encounters and NPC portals have been despawned, and swarms will no longer spawn.")
				end
			else
				print(ply:Nick() .. ", you must be in a mission")
			end
		else
			print(ply:Nick() .. ", this command is admin only")
		end
	end, nil, "Remove all NPC portals, delay all swarms and so on.", FCVAR_CHEAT)
	
	concommand.Add("jcms_debug_spawnnpc", function(ply, cmd, args)
		if ply:IsAdmin() then
			jcms.npc_Spawn(args[1], ply:GetEyeTrace().HitPos + Vector(0, 0, 256))
		else
			print(ply:Nick() .. ", this command is admin only")
		end
	end, nil, "Spawns an NPC.", FCVAR_CHEAT)
	
	concommand.Add("jcms_debug_spawnprefab", function(ply, cmd, args)
		if ply:IsAdmin() then
			local worked = jcms.prefab_TryStamp(args[1], navmesh.GetNearestNavArea(ply:GetEyeTrace().HitPos))
			if not worked then
				print(ply:Nick() .. ", can't spawn this structure here!")
			end
		else
			print(ply:Nick() .. ", this command is admin only")
		end
	end, nil, "Spawns a prefab (structures in the world)", FCVAR_CHEAT)

	concommand.Add("jcms_debug_gravgun", function(ply, cmd, args)
		if ply:IsAdmin() then
			local oldValue = ply.jcms_canGetWeapons
			ply.jcms_canGetWeapons = true
			ply:Give("weapon_physcannon")
			ply.jcms_canGetWeapons = oldValue
		else
			print(ply:Nick() .. ", this command is admin only")
		end
	end, nil, "Gives you a gravity gun", FCVAR_CHEAT)
	
	concommand.Add("jcms_ready", function(ply, cmd, args)
		if (ply:GetObserverMode() == OBS_MODE_FIXED) and ply:GetNWInt("jcms_desiredteam", 0) > 0 then
			ply:SetNWBool("jcms_ready", not ply:GetNWBool("jcms_ready"))
		else
			ply:SetNWBool("jcms_ready", false)
		end
	end)
	
	concommand.Add("jcms_forcestart", function(ply, cmd, args)
		if not jcms.director and (not ply:IsPlayer() or ply:IsAdmin()) then
			-- TODO We can force-start the mission even if nobody is ready, which is going to start the mission without anyone at all.
			jcms.mission_StartFromCVar()
		end
	end)

	concommand.Add("jcms_mission", function(ply, cmd, args)
		if not jcms.director and (not ply:IsPlayer() or ply:IsAdmin()) then
			local data = jcms.missions[ args[1] ]

			if data then
				if data.faction == "any" then
					if args[2] and jcms.factions[ args[2] ] then
						game.GetWorld():SetNWString("jcms_missiontype", args[1])
						game.GetWorld():SetNWString("jcms_missionfaction", args[2])
						jcms.printf("Mission type changed to '%s', enemies: %s", args[1], args[2])
					else
						jcms.printf("Specify an enemy faction! jcms_mission %s %s", args[1], table.concat(jcms.factions_GetOrder(), "/"))
					end
				else
					game.GetWorld():SetNWString("jcms_missiontype", args[1])
					game.GetWorld():SetNWString("jcms_missionfaction", data.faction)
					jcms.printf("Mission type changed to '%s'", args[1])
				end
			else
				local missionTypes = table.GetKeys(jcms.missions)
				table.sort(missionTypes)

				if args[1] and #args[1] > 0 then
					jcms.printf("Unknown mission type '%s', valid mission types: %s", args[1], table.concat(missionTypes, ", "))
				else
					jcms.printf("Specify one of the mission types: %s", table.concat(missionTypes, ", "))
				end
			end
		end
	end, function(cmd, args)
		args = string.Split( args:lower():Trim(), " " )

		local missiontypes = {}
		for name in pairs(jcms.missions) do
			if #args[1] <= 0 or name:find(args[1]) == 1 then
				table.insert(missiontypes, cmd .. " " .. name)
			end
		end

		return missiontypes
	end, "Only works in-lobby. Sets the pending mission and enemy (for universal missions) types.")

	concommand.Add("jcms_mission_randomize", function(ply, cmd, args)
		if not jcms.director and (not ply:IsPlayer() or ply:IsAdmin()) then
			jcms.mission_Randomize()
		end
	end, nil, "Only works in-lobby. Randomizes pending mission type.")

	concommand.Add("jcms_jointeam", function(ply, cmd, args)
		local restriction = jcms.cvar_npcteam_restrict:GetInt() -- 0: No restrictions, 1: Only post-evac, 2: Can never be an NPC
		local canJoinNpcs = false
		if restriction == 0 then
			canJoinNpcs = true
		elseif restriction == 1 then
			canJoinNpcs = jcms.director and jcms.director.evacuated[ply]
		end
		
		local team = tonumber(args[1]) or tostring(args[1])

		if ply:GetObserverMode() == OBS_MODE_FIXED then
			if team == 0 or team == "none" then
				-- Leaving the lobby is not as scary as it sounds
				ply:SetNWInt("jcms_desiredteam", 0)
			elseif team == 1 or team == "sweeper" or team == "jcorp" then
				-- Sweeper
				ply:SetNWInt("jcms_desiredteam", 1)
			elseif canJoinNpcs and not game.SinglePlayer() then
				if team == 2 or team == "npc" or team == "enemy" then
					-- NPC
					ply:SetNWInt("jcms_desiredteam", 2)
				end
			end
		end
		
		if jcms.director and not game.SinglePlayer() then
			if (ply:GetObserverMode() == OBS_MODE_CHASE) or (ply:GetObserverMode() == OBS_MODE_NONE and not ply:Alive()) then
				
			if canJoinNpcs and (team == 2 or team == "npc" or team == "enemy") and (ply:GetNWInt("jcms_desiredteam", 0) < 2) then
					ply.jcms_classAtEvac = ply:GetNWString("jcms_class", "infantry")
					ply:SetNWInt("jcms_desiredteam", 2)
					ply:SetNWString("jcms_class", jcms.npc_PickPlayerNPCClass(jcms.director.faction))
					ply:SetTeam(2)
					ply.jcms_isNPC = true
					jcms.net_NotifyJoinedNPCs(ply)

					if not jcms.director.evacuated[ ply ] then
						jcms.director_stats_SetLockedState(jcms.director, ply, "npc")
					end

					local sid64 = ply:SteamID64()
					for i, ent in ipairs(ents.GetAll()) do
						if ent.jcms_owner == ply then
							ent.jcms_owner = nil
						end

						if ent.jcms_owner_sid64 == sid64 then
							ent.jcms_owner_sid64 = nil
						end
					end
				end
			end

		end
	end)
	
	concommand.Add("jcms_setclass", function(ply, cmd, args)
		if (ply:GetObserverMode() == OBS_MODE_FIXED) or (ply:GetObserverMode() == OBS_MODE_CHASE) then
			local classData = jcms.classes[ args[1] ]
			if classData and classData.jcorp then
				ply:SetNWString("jcms_desiredclass", args[1])
			else
				ply:SetNWString("jcms_desiredclass", "infantry")
			end
		end
	end, nil, "Picks the class you wish to play as.")

	concommand.Add("jcms_buyweapon", function(ply, cmd, args)
		if ply:GetObserverMode() == OBS_MODE_FIXED then
			-- We're in lobby, getting a loadout. We may also sell the weapon 
			-- by passing negative number as count, despite the name of the command.

			if args[1] == "allammo" then
				-- Buying maximum clips for every gun that we already own.
				
				local validClasses = table.Copy(ply.jcms_pendingLoadout)
				local changedClasses = {}

				for i=1, 9999 do
					local gotAtLeastOne = false
					for class in pairs(validClasses) do
						local worked = jcms.spawnmenu_PurchaseLoadoutGun(ply, class, 1)
						
						if worked then
							gotAtLeastOne = true
							changedClasses[class] = ply.jcms_pendingLoadout[class]
						else
							validClasses[class] = nil
						end
					end

					if not (gotAtLeastOne and next(validClasses)) then
						break
					end
				end

				for class, count in pairs(changedClasses) do
					jcms.net_SendWeaponInLoadout(class, count, ply)
				end
			else
				-- Buying or selling guns.
				local count = tonumber( args[2] ) or 1

				if count > 0 then
					local worked = jcms.spawnmenu_PurchaseLoadoutGun(ply, args[1], count)

					if worked then
						ply.jcms_canGetWeapons = true
						jcms.net_SendWeaponInLoadout(args[1], ply.jcms_pendingLoadout[ args[1] ], ply)
						ply:Give(args[1], true)
						ply.jcms_canGetWeapons = false
					end
				elseif count < 0 then
					local worked, exhausted = jcms.spawnmenu_SellLoadoutGun(ply, args[1], -count)

					if worked then
						if exhausted then
							ply:StripWeapon(args[1])
							jcms.net_SendWeaponInLoadout(args[1], 0, ply)
						else
							jcms.net_SendWeaponInLoadout(args[1], ply.jcms_pendingLoadout[ args[1] ], ply)
						end
					end
				end
			end

		elseif ply:GetObserverMode() == OBS_MODE_NONE and ply:Alive() and jcms.team_JCorp_player(ply) then
			-- We're in the field. We can buy guns if we are near a shop and we can see it. We can't sell guns here.
			
			local found = false
			local minDist2 = 200^2
			local tr = ply:GetEyeTrace()

			if IsValid(tr.Entity) and tr.Entity:GetClass() == "jcms_shop" and tr.StartPos:DistToSqr(tr.HitPos) < minDist2 then
				found = true
			end

			if found then
				jcms.spawnmenu_PurchaseAndGiveGun(ply, args[1], args[2], 0.5)
			end
		end
	end)

	concommand.Add("jcms_setweaponprice", function(ply, cmd, args)
		if not ply:IsPlayer() or ply:IsAdmin() then
			local class = tostring(args[1])
			
			if jcms.weapon_predefinedPrices[class] or weapons.GetStored(class) or jcms.weapon_prices[class] or jcms.weapon_HL2Prices[class] then
				local price = args[2]
				if tostring(price):lower() == "default" then
					price = -1
				end

				price = math.ceil(tonumber(price))
				local oldPrice = jcms.weapon_prices[ class ]
				
				if price > 0 then
					price = math.min(16777215, price)
					jcms.printf("weapon '%s' custom price set: %d J", class, price)
				elseif price < 0 then
					price = (jcms.weapon_blacklist[class] and 0) or (jcms.weapon_HL2Prices[class] or jcms.weapon_predefinedPrices[class] or jcms.gunstats_CalcWeaponPrice( jcms.gunstats_GetExpensive(class) ))
					jcms.printf("weapon '%s' restored to default price: %d J", class, price)
				else
					--price = nil
					jcms.printf("weapon '%s' has been disabled!", class)
				end

				jcms.weapon_prices[ class ] = price
				
				if oldPrice ~= price then
					jcms.net_SendWeapon(class, price or 0, "all")
				end
			else
				print("weapon class '" .. class .. "' does not exist")
			end
		else
			print(ply:Nick() .. ", this command is admin only")
		end
	end)

	concommand.Add("jcms_setorderdetails", function(ply, cmd, args)
		if not ply:IsPlayer() or ply:IsAdmin() then
			local class = tostring(args[1])
			local orderData = jcms.orders[class]
			
			if orderData then
				local cost = 
					(args[2] == "reset") and orderData.cost
					or (args[2] == "keep") and (orderData.cost_override or orderData.cost) 
					or math.Clamp(tonumber(args[2]) or 0, 0, 16777215)
				
				local cd = 
					(args[3] == "reset") and orderData.cooldown
					or (args[3] == "keep") and (orderData.cooldown_override or orderData.cooldown) 
					or math.Clamp(tonumber(args[3]) or 0, 0, 4095)
				
				local time = string.FormattedTime(cd)
				local formatted = string.format("%02i:%02i:%02i", time.h, time.m, time.s)
				jcms.printf("updated cost & cooldown for order '" .. class .. "': %s J, %s", jcms.util_CashFormat(cost), formatted)

				orderData.cost_override = cost ~= orderData.cost and cost or nil
				orderData.cooldown_override = cd ~= orderData.cooldown and cd or nil
				
				if cost == 0 then
					jcms.net_RemoveOrder(class)
				else
					jcms.net_SendOrder(class, orderData)
				end
			else
				print("order '" .. class .. "' does not exist")
			end
		else
			print(ply:Nick() .. ", this command is admin only")
		end
	end)

-- // }}}

-- // Weapons {{{

	jcms.weapon_predefinedPrices = {
		-- Toybox Classics
		weapon_burnmaster6000 = 8499,
		weapon_electrocannon = 9999,
		weapon_song22horn = 29299,
		weapon_freezeray = 13999,
		weapon_autofists = 14999,
		weapon_rapidrail = 17599,
		weapon_gunstrumental = 15799,

		-- Hunt Down The Freeman
		hdtf_hl2_pistol = 349,
		hdtf_pistol = 349,
		hdtf_1911 = 299,
		hdtf_wrench = 199,
		hdtf_m16 = 899,
		hdtf_minigun = 19699, -- infinite ammo??
		hdtf_skorpion = 549,
		hdtf_doublebarrel = 799,
		hdtf_ar2 = 699,
		hdtf_knife = 189,
		hdtf_machete = 199, -- ah yes functionally identical melee weapons
		hdtf_shotgun = 679,
		hdtf_mp5 = 539,
		hdtf_tmp = 539,
		hdtf_oneshotgun = 699,
		hdtf_axe = 219,
		hdtf_ak47 = 729,
		hdtf_awp = 999,
		hdtf_sigxi = 869,
		hdtf_magnum = 469,
		hdtf_m67 = 219,
		hdtf_molotov = 199,
		hdtf_rem700 = 989,
		hdtf_kar98 = 1099,
		hdtf_grenade = 259,
		hdtf_claymore = 649,

		-- HL2 Beta Weapons Pack
		weapon_bp_irifle = 629,
		weapon_bp_flaregun = 139,
		weapon_bp_alyxgun = 379,
		weapon_bp_radio = 7999,
		weapon_bp_taucannon  = 5499,
		weapon_bp_ar1 = 699,
		weapon_bp_smg3 = 529,
		weapon_bp_oicw = 819,
		weapon_bp_rtboicw = 819,
		weapon_bp_smg2 = 529,
		weapon_bp_stickylauncher = 3399,
		weapon_bp_annabelle = 759,
		weapon_bp_shotgun = 659,
		weapon_bp_hmg1 = 999,
		weapon_bp_sniper = 1299,
		weapon_bp_immolator = 1199,
		weapon_bp_cocktail = 229,
		weapon_bp_hopwire = 399,
		weapon_cp_hopwire = 399,
		weapon_bp_launcher = 1399,
		weapon_bp_rlauncher = 1199,
		weapon_bp_guardgun = 3899,
		weapon_bp_flamethrower = 1499,

		-- L4D2 weapon pack
		weapon_l4d2_chainsaw = 3599,

		-- Serious Sam
		weapon_ss2_seriousbomb = 12499,
		weapon_ss2_zapgun = 2999,
		weapon_ss2_colt = 3299,
		weapon_ss2_colt_dual = 3699,

		-- M9K
		m9k_davy_crockett = 17000,
		m9k_orbital_strike = 8000,
		m9k_nitro = 1600,
		m9k_m61_frag = 800,
		m9k_ied_detonator = 1000,
		m9k_m79gl = 2800,
		m9k_sticky_grenade = 1100,
		m9k_suicide_bomb = 2000,
		
		-- DOOM 3
		weapon_doom3_chainsaw = 1199,
		weapon_doom3_grenade = 799,
		weapon_doom3_bfg = 3199,
		-- Darken217's SciFi Armory
		sfw_eblade = 329,
		sfw_hornet = 699,
		sfw_stinger = 1899,
		sfw_dartgun = 559,
		sfw_pulsar = 6299, -- Deals damage to helicopters, infinite ammo, decent alt firing mode.
		sfw_lapis = 199,
		sfw_vapor = 3999, -- Extremely strong, deals damage to helis, nuke altfire that can also instakill gunships and medium-sized hordes.
		sfw_fallingstar = 1999,
		sfw_storm = 629, -- Requires no reloads, otherwise decent shotgun.
		sfw_phasma = 349,
		sfw_zeala = 5999, -- Black hole gun. Has infinite ammo.
		sfw_astra = 3999, -- Infinite ammo but otherwise a very niche pick.
		sfw_prisma = 3599, -- Infinite ammo. Quite miserable against hordes.
		sfw_supra = 5599, -- Infinite ammo grenade launcher.
		sfw_vectra = 3599, -- Infinite ammo. Miserable against, well, most things.
		sfw_alchemy = 4999, -- Infinite ammo. Useful elements.
		sfw_helios = 1299, -- Chain-explosive revolver.
		sfw_phoenix = 699,
		sfw_ember = 449,
		sfw_seraphim = 849,
		sfw_pyre = 1699,
		sfw_hwave = 699,
		sfw_saphyre = 2399, -- Heals user
		sfw_pandemic = 799,
		sfw_draco = 759,
		sfw_aquamarine = 829,
		sfw_umbra = 4999, -- Short-range weapon that heals user and has nigh-infinite ammo
		sfw_neutrino = 1799,
		sfw_hellfire = 699, -- Good altfire.
		sfw_grinder = 1099, -- Powerful against hordes.
		sfw_corruptor = 1999, -- Self-sustaining.
		sfw_behemoth = 1299,
		sfw_trace = 899,
		sfw_blizzard = 699,
		sfw_cryon = 699,
		sfw_jotunn = 299, -- probably the worst pick for this gamemode.
		sfw_thunderbolt = 499,
		sfw_acidrain = 999,
		sfw_fathom = 319,
		sfw_meteor = 1799,
		sfw_vk21 = 519,

		-- Sanctum 2
		sanctum2_bc = 1199,
		sanctum2_sg = 669,
		sanctum2_tr = 899,

		-- DOOM 2 Weapons
		doom_weapon_plasmagun = 899,

		-- Laser Guns
		weapon_lasermgun = 9599,
		weapon_laserrpg = 9999,
		weapon_laserrifle1 = 49999,

		-- Robotboy655's Weapons
		weapon_lightsaber = 7999,
		weapon_nyangun = 6999,

		-- DOOM 2016/Eternal Weapons
		weapon_dredux_d2016_bfg = 4599,
		weapon_dredux_d2016_chaingun = 569,
		weapon_dredux_d2016_double_barrel = 699,
		weapon_dredux_d2016_gauss = 789,
		weapon_dredux_d2016_heavy_ar = 499,
		weapon_dredux_d2016_pistol = 249,
		weapon_dredux_d2016_plasma = 459,
		weapon_dredux_d2016_rocketlauncher = 2799,
		weapon_dredux_d2016_shotgun = 489,
		weapon_dredux_d2016mp_boltrifle = 599,
		weapon_dredux_d2016mp_pistol = 259,
		weapon_dredux_de_bfg = 4599,
		weapon_dredux_de_chaingun = 579,
		weapon_dredux_de_crucible = 2999,
		weapon_dredux_de_gauss = 789,
		weapon_dredux_de_hammer = 1499,
		weapon_dredux_de_heavy_ar = 519,
		weapon_dredux_de_pistol = 249,
		weapon_dredux_de_plasma = 459,
		weapon_dredux_de_rocketlauncher = 2799,
		weapon_dredux_de_shotgun = 489,
		weapon_dredux_de_supershotgun = 699,
		weapon_dredux_de_unmaker = 1999,

		-- Other
		ultra_rail_gun = 1999,
		weapon_undertale_sans = 3799,
		nature_staff = 3099,
		weapon_catgun = 489,
		["super nuke"] = 16999
	}

	jcms.weapon_prices = jcms.weapon_prices or table.Copy(jcms.weapon_HL2Prices)
	
	jcms.weapon_blacklist = {
		["none"] = true,
		["weapon_medkit"] = true, 
		["weapon_flechettegun"] = true, 
		["weapon_fists"] = true,
		["weapon_physcannon"] = true,
		["sfw_custom"] = true,
		["weapon_undertale_sans_admin"] = true,
		["weapon_l4d2_first_aid_kit"] = true,
		["weapon_vj_controller"] = true
	}

	jcms.weapon_allowedAmmoTypes = {
		-- These ammo types will never count as useless and will always be added to the player.
		["doom_freezegrenade"] = true,
		["doom_grenade"] = true,
		["doom_flamebelch"] = true,
		["doom_bloodpunch"] = true
	}
	
	if not jcms.inTutorial then
		local weaponPricesFile = "mapsweepers/server/weapon_prices.json"
		hook.Add("InitPostEntity", "jcms_WeaponPrices", function(ply)

			table.Empty(jcms.weapon_prices)
			if file.Exists(weaponPricesFile, "DATA") then
				local json = file.Read(weaponPricesFile, "DATA")

				if json then
					local success, rtn = pcall(util.JSONToTable, json)
					if success and type(rtn) == "table" then
						for class, price in pairs(rtn) do
							if type(class) == "string" and type(price) == "number" and (weapons.GetStored(class) or jcms.default_weapons_datas[class]) then
								jcms.weapon_prices[ class ] = math.ceil( math.Clamp(price, 0, 16777215) )
							end
						end
						
					jcms.printf("Loaded weapon prices from '%s'.", weaponPricesFile)
					end
				end
			end

			for class, price in pairs(jcms.weapon_predefinedPrices) do
				if not weapons.GetStored(class) then continue end -- Doesn't exist
				jcms.weapon_prices[class] = jcms.weapon_prices[class] or price
			end

			for class, price in pairs(jcms.weapon_HL2Prices) do 
				jcms.weapon_prices[class] = jcms.weapon_prices[class] or price
			end
			
			for i, data in ipairs( weapons.GetList() ) do
				if data.Spawnable then
					local class = data.ClassName
					if jcms.weapon_blacklist[ class ] then continue end
					if jcms.weapon_prices[ class ] then continue end
					
					local success, rtn = pcall(jcms.gunstats_GetExpensive, class)
					local stats
					if not success then
						jcms.printf("Weapon: '%s' caused an error/contains garbage data.", class)
						ErrorNoHaltWithStack(rtn)
					else
						stats = rtn
					end

					if stats then
						jcms.weapon_prices[ class ] = jcms.gunstats_CalcWeaponPrice(stats)
					end
				end
			end
		end)

		hook.Add("ShutDown", "jcms_SaveWeaponPrices", function()
			local success, rtn = pcall(util.TableToJSON, jcms.weapon_prices, true)
			if success and rtn then
				success = file.Write(weaponPricesFile, rtn)

				if success then
					jcms.printf("Saving weapon prices to '%s'.", weaponPricesFile)
				else
					jcms.printf("Failed to save weapon prices. Error: %s", tostring(rtn))
				end
			else
				jcms.printf("Failed to save weapon prices, bad data inside jcms.weapon_prices table!")
			end
		end)
	end

-- // }}}

-- // Util {{{

	function jcms.util_JetSound(v)
		local allPlayers = RecipientFilter()
		allPlayers:AddAllPlayers()
		
		EmitSound("jcms_jetby", v, 0, CHAN_AUTO, 1, 100, 0, 100, 22, allPlayers)
	end

	function jcms.util_PerformRepairs(ent, ply, repairValue)
		if jcms.director_IsSuddenDeath() then
			return
		end
		
		repairValue = tonumber(repairValue) or 7
		if jcms.isPlayerEngineer(ply) then
			repairValue = repairValue * 2.5
		end
		
		local oldValue = ent:Health()
		local newValue = math.min(ent:Health() + repairValue, ent:GetMaxHealth())
		
		if oldValue < newValue then
			if newValue == ent:GetMaxHealth() then
				ply:EmitSound("buttons/button9.wav", 100)
			else
				ply:EmitSound("buttons/lever7.wav", 100)
			end
			ent:SetHealth(newValue)
		end
	end

	function jcms.util_UnHack(ent)
		ent:SetHackedByRebels(false)
		ent:EmitSound("weapons/stunstick/alyx_stunner" .. math.random(1,2) .. ".wav", 75, 200)

		local ed = EffectData()
		ed:SetEntity(ent)
		ed:SetFlags(1)
		ed:SetColor(jcms.util_colorIntegerJCorp) -- Red effect
		util.Effect("jcms_shieldeffect", ed)

		if ent.nextAttack then
			ent.nextAttack = CurTime() + 0.25
		end

		if ent.NextSlowThink and ent.TurretSlowThink then
			ent.NextSlowThink = CurTime() - 0.1
			ent:TurretSlowThink()
		end
	end

	function jcms_util_shieldDamageEffect(dmginfo, shieldDmg)
		local attacker = dmginfo:GetAttacker()
		if not IsValid(attacker) then return end

		local origin = dmginfo:GetDamagePosition()
		local normal = attacker:WorldSpaceCenter()
		normal:Mul(-1)
		normal:Add(origin)
		normal:Normalize()
		
		local addedScale = 0
		if bit.band(dmginfo:GetDamageType(), bit.bor(DMG_SLASH, DMG_BLAST, DMG_BLAST_SURFACE, DMG_CRUSH, DMG_CLUB)) > 0 then
			addedScale = 1
		end

		local ed = EffectData()
		ed:SetFlags(0)
		ed:SetColor(jcms.util_colorIntegerSweeperShield)
		ed:SetOrigin(origin)
		ed:SetNormal(normal)
		ed:SetScale(Lerp(1 - 4/(shieldDmg+4), 0.5, 1.3) + math.random()*0.2 + addedScale)
		util.Effect("jcms_shieldeffect", ed)
	end

-- // }}}

-- // Filesystem {{{
	file.CreateDir("mapsweepers")
	file.CreateDir("mapsweepers/server")

	--TODO: These should probably have a standardised set-up function at this point, it's mostly duplicate code here.

	do 
		local runProgFile = "mapsweepers/server/runprogress_" .. (game.SinglePlayer() and "solo" or "multiplayer") .. ".dat"
		hook.Add("InitPostEntity", "jcms_RestorePreviousRun", function()
			if file.Exists(runProgFile, "DATA") then
				local dataTxt = file.Read(runProgFile, "DATA")
				local dataTbl = util.JSONToTable(util.Decompress(dataTxt))

				table.Merge(jcms.runprogress, dataTbl, true)
				jcms.runprogress_UpdateAllPlayers()
			end
		end)

		hook.Add("ShutDown", "jcms_SaveRunData", function()
			if jcms.director and not jcms.director.gameover then
				jcms.runprogress_Reset()
				--Resets our run if we're in a mission. Prevents save-scumming.
			end

			local dataStr = util.Compress(util.TableToJSON(jcms.runprogress))
			file.Write(runProgFile, dataStr)
		end)
	end

	do
		local playerDataFile = "mapsweepers/server/playerData.dat"
		hook.Add("InitPostEntity", "jcms_RestorePlayerData", function()
			if file.Exists(playerDataFile, "DATA") then
				local dataTxt = file.Read(playerDataFile, "DATA")
				local dataTbl = util.JSONToTable(util.Decompress(dataTxt))

				table.Merge(jcms.playerData, dataTbl, true)
			end
		end)

		hook.Add("ShutDown", "jcms_SavePlayerData", function()
			local dataStr = util.Compress(util.TableToJSON(jcms.playerData))
			file.Write(playerDataFile, dataStr)
		end)
	end

	do
		local validMapsFile = "mapsweepers/server/validMaps.json"
		hook.Add("InitPostEntity", "jcms_RestorePlayerData", function()
			if file.Exists(validMapsFile, "DATA") then
				local dataTxt = file.Read(validMapsFile, "DATA")
				local dataTbl = util.JSONToTable(dataTxt)

				table.Merge(jcms.validMaps, dataTbl, true)
			end
		end)

		hook.Add("ShutDown", "jcms_SavePlayerData", function()
			local dataStr = util.TableToJSON(jcms.validMaps)
			file.Write(validMapsFile, dataStr)
		end)
	end

-- // }}}

-- // Post {{{

	function jcms.RecolorAllDollies()
		-- this is EXTREMELY important
		for i, ent in ipairs(ents.GetAll()) do
			if ent.GetModel and ent:GetModel() == "models/maxofs2d/companion_doll.mdl" then
				ent:SetColor(Color(255, 0, 0))
			end
		end
	end

	function jcms.ReplaceAllCrates()
		-- TODO Account for hammer names and I/O
		for i, oldcrate in ipairs(ents.FindByClass("item_ammo_crate")) do
			local newcrate = ents.Create("jcms_ammo_crate")
			newcrate:SetPos(oldcrate:GetPos())
			newcrate:SetAngles(oldcrate:GetAngles())
			oldcrate:Remove()
			newcrate:Spawn()
		end
	end

	hook.Run("MapSweepersReady") -- If you want to make an addon that adds new content into Map Sweepers, use this hook.

-- // }}}