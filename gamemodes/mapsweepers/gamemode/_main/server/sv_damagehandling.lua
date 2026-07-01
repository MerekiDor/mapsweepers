
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


--General damage adjustment hook
hook.Add("EntityTakeDamage", "jcms_Adjustments", function(ent, dmg) --TODO: This hook has become a bit of a mess. 
	local attacker = dmg:GetAttacker()
	local inflictor = dmg:GetInflictor()
	local dmgType = dmg:GetDamageType()

	local entTbl = ent:GetTable()
	local isPlayer = ent:IsPlayer()

	--Damage immunity (completely suppress dmg). Used by poison headcrabs for their 0.1s grace
	entTbl.jcms_damageImmunityEnd = entTbl.jcms_damageImmunityEnd or 0
	if entTbl.jcms_damageImmunityEnd > CurTime() then 
		dmg:ScaleDamage(0)
		return true
	end

	--Damage Tracking
	if ent:IsNPC() then
		entTbl.jcms_lastDamageType = dmgType
	end

	--Radiation invulnerability
	if isPlayer and bit.band(dmgType, DMG_RADIATION) > 0 and ent:GetNWInt("jcms_antirad", 0) > 0 then
		dmg:ScaleDamage(0)
		return true
	end

	--Weapon inflictor hack-fix
	if (inflictor == attacker) and attacker:IsPlayer() and bit.band(dmgType, bit.bor(DMG_BUCKSHOT, DMG_BULLET)) > 0 then
		-- This is really shitty, but neither M9K nor ArcCW properly set up their inflictors, which is why this is necessary.
		local wep = attacker:GetActiveWeapon()
		if IsValid(wep) then
			dmg:SetInflictor(wep)
			inflictor = wep
		end
	end

	--Friendly-fire
	local isEntAndAttackerSameTeam = IsValid(attacker) and jcms.team_SameTeam(attacker, ent)
	if isEntAndAttackerSameTeam then
		if attacker:IsPlayer() and jcms.team_NPC(attacker) and not (IsValid(inflictor) and inflictor.jcms_canHurtSelfAsNPC) then
			dmg:ScaleDamage(0) -- NPC-players can't do friendly fire damage to NPCs
			return
		else
			dmg:ScaleDamage( jcms.cvar_ffmul:GetFloat() )
		end
	end

	--Bubble shields (and damage tracking?)
	local shield = ent:GetNWInt("jcms_shield", 0)
	if shield > 0 and bit.band(dmgType, bit.bor(DMG_CRUSH, DMG_FALL)) == 0 and dmg:GetDamage() > 0 then 
		ent:SetNWInt("jcms_shield", math.max(shield - 1, 0))
		dmg:SetDamage(0)
		return 0
	elseif isPlayer then
		entTbl.jcms_lastDamaged = CurTime()
		jcms.net_SendDamage(ent, dmg)
	end

	--Sweeper shields
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

	--Prevent us from being instakilled by physics objects.
	if isPlayer and bit.band(dmg:GetDamageType(), DMG_CRUSH) > 0 then
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

			if isPlayer then
				if isEntAndAttackerSameTeam then 
					local dmgAmnt = dmg:GetDamage()
					local dmgCap = (ent:GetMaxHealth() + ent:GetMaxArmor()) * 0.75
					dmg:SetDamage( math.Clamp(dmgAmnt, 0, dmgCap) )
				elseif (not jcms.team_pvpSameTeam(attacker, ent)) and jcms.team_JCorp_player(attacker) and jcms.team_JCorp_player(ent) then 
					dmg:ScaleDamage(0.75) --Slight dmg reduction for PvP players.
				end
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
					dmg:ScaleDamage(jcms.npc_GetScaledDamage())
				end
			end
		else
			dmg:ScaleDamage(attacker.jcms_dmgMult or 1)
			if attacker:IsNPC() then
				if not attacker.jcms_dontScaleDmg then
					dmg:ScaleDamage(jcms.npc_GetScaledDamage())
				end
				if attacker.jcms_maxScaledDmg then 
					dmg:SetDamage( math.min(attacker.jcms_maxScaledDmg, dmg:GetDamage()) )
				end
			end
		end
		
		if jcms.team_JCorp(ent) then
			local hp, hpMax = ent:Health(), ent:GetMaxHealth()
			local fraction = math.Clamp(math.Remap(hp, hpMax*0.1, hpMax*0.9, 0, 1), 0, 1)
			local scale = Lerp(fraction, 0.5, 1.0)
			dmg:ScaleDamage(scale)
		end

		if isPlayer and ent:GetNWEntity("jcms_vehicle") then
			local veh = ent:GetNWEntity("jcms_vehicle")
			if veh.RedirectDamage then
				veh:RedirectDamage(ent, dmg)
			end
		end
		
		if attacker.jcms_damageEffect then 
			attacker:jcms_damageEffect(ent, dmg)
		end
		
		if entTbl.jcms_TakeDamage then
			ent:jcms_TakeDamage(dmg, attacker)
		end

		if ( (attacker:IsPlayer() and attacker.jcms_faction) or (inflictor:IsPlayer() and inflictor.jcms_faction) ) and ( jcms.team_GoodTarget(ent) and jcms.team_JCorp(ent) ) then
			local armorDamage = 0
			local healthDamage = dmg:GetDamage()

			if isPlayer then
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


	--Poisonous stuff
	if IsValid(attacker) then
		--Their default behaviour seems to be hardcoded in hl2, and messing with the damageinfo breaks it (causes them to instakill).
		--This is a bandaid solution to that. 

		local attkClass = attacker:GetClass()
		local isCrab = attkClass == "npc_headcrab_poison" or attkClass == "npc_headcrab_black"
		local isCavernGuard = attkClass == "npc_antlionguard" and attacker:GetInternalVariable("m_bCavernBreed")
		local isWorker = attkClass == "npc_antlion" and attacker:HasSpawnFlags( 262144 ) -- 262144 = worker spawnflags

		if isCrab then
			local hp = ent:Health()
			if isPlayer then
				dmg:SetDamage( math.min(hp-5, dmg:GetDamage()) )

				--Sudden death prevention
				if ent:Health() > 20 then
					entTbl.jcms_damageImmunityEnd = math.max(entTbl.jcms_damageImmunityEnd, CurTime() + 0.1)
					--Human reaction times range from 100-200ms (ish). One perceptual cycle is something like 70ms (on the high end, it can be lower). 
					--100ms of delay gives you at least a bit of time to respond if you notice just before it hits, and ensures you at least *perceive* what happened before you die. 
				end
			else
				dmg:SetDamage(math.min(math.max(0, hp-1), 15))
			end
		elseif isCavernGuard or isWorker then 
			if isPlayer then 
				dmg:SetDamage( math.min( dmg:GetDamage(), ent:GetMaxHealth() * 0.7 ) )
			end
		end
	end
end)

--Allow NPCs to define custom limb damage scaling (used by zombine, breacher. Also antlion-guard technically even though it doesn't really have to). 
hook.Add("ScaleNPCDamage", "jcms_NpcDamage" , function(npc, hitGroup, dmgInfo)
	local npcTbl = npc:GetTable()
	if npcTbl.jcms_ScaleDamage then
		npcTbl.jcms_ScaleDamage(npc, hitGroup, dmgInfo)
	end
end)

--Allow entities to do something after taking damage. (used by thumpers) --TODO: Most NPCs currently do this using 1 tick timers, would be a good idea to make this available to them instead.
hook.Add("PostEntityTakeDamage", "jcms_Adjustments", function(ent, dmg)
	local entTbl = ent:GetTable()
	if entTbl.jcms_PostTakeDamage then
		entTbl.jcms_PostTakeDamage(ent, dmg)
	end
end)

--Track damage dealt for bounty handling
hook.Add("PostEntityTakeDamage", "jcms_DamageShare", function(ent, dmg)
	local damageShare = ent.jcms_damageShare
	if damageShare then
		local attacker = dmg:GetAttacker()
		
		if (attacker ~= ent) and jcms.team_JCorp(attacker) then
			damageShare[ attacker ] = (damageShare[ attacker ] or 0) + dmg:GetDamage()
		end
	end
end)

--Allow entities to define custom bullet behaviours (e.g. explosive ammo), 
--allows in-engine dmg suppression to be bypassed (used for helis)
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