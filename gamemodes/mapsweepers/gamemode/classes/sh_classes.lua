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

jcms.classes = {}
jcms.classesOrder = jcms.classesOrder or {}
jcms.classesOrderIndices = jcms.classesOrderIndices or {}
table.Empty(jcms.classesOrder)
table.Empty(jcms.classesOrderIndices)

-- // Functions {{{

	function jcms.class_Apply(ply, class)
		local data = assert(jcms.classes[ class ], "unknown player class")
		ply:SetNWString("jcms_class", class)

		-- Visual
		ply:SetModel(data.mdl)
		ply:SetSkin(data.skin or 0)
		ply:SetPlayerColor(data.playerColorVector or Vector(0.44, 0, 0))

		-- Speed
		ply:SetLadderClimbSpeed(130 * data.speedMul)
		ply:SetSlowWalkSpeed(75 * data.speedMul)
		
		data.walkSpeed = data.walkSpeed or (160 * data.speedMul)
		data.runSpeed = data.runSpeed or (250 * data.speedMul)
		ply:SetWalkSpeed(data.walkSpeed)
		ply:SetRunSpeed(data.runSpeed)

		ply:SetJumpPower( data.jumpPower or 200 )
		ply:SetCrouchedWalkSpeed(0.5)
		if data.sprintHack then
			ply:SprintDisable()
		else
			ply:SprintEnable()
		end
		
		-- Other
		ply:ResetHull()
		ply:SetGravity( data.gravity or 1 )
		ply:SetBodyGroups( string.rep("0", 32) )
		ply.jcms_bounty = nil
		ply.jcms_damageShare = nil
		ply.jcms_faction = data.faction
		ply.jcms_damageEffect = nil
		ply.jcms_dmgMult = data.damage
		ply.jcms_EntityFireBullets = nil
		ply.jcms_incendiaryUpgrade = nil
    	ply.jcms_explosiveUpgrade = nil
		hook.Run("MapSweepersClassApplied", ply, class, data)

		-- Stats
		ply:SetMaxHealth( data.health )
		ply:SetHealth( ply:GetMaxHealth() )
		ply:SetMaxArmor( data.shield )
		ply:SetArmor( ply:GetMaxArmor() )

		-- Giving weapons
		if data.jcorp then
			ply:Give("weapon_stunstick")

			if ply.jcms_pendingLoadout then
				-- TODO jcms.spawnmenu_GetValidatedLoadout(ply, loadout, gunPriceMul, ammoPriceMul)
				jcms.spawnmenu_PurchaseLoadout(ply, ply.jcms_pendingLoadout, jcms.util_GetLobbyWeaponCostMultiplier(), 1)
				ply.jcms_pendingLoadout = nil
				ply:SetNWInt("jcms_pendingLoadoutCost", 0)
			end
		end

		-- Shield
		local timerIdentifier = "jcms_ShieldRegen" .. ply:EntIndex()

		timer.Create(timerIdentifier, 1 / data.shieldRegen, 0, function()
			if IsValid(ply) and ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE then

				if (ply:Armor() < ply:GetMaxArmor()) and (not ply.jcms_lastDamaged or CurTime()-ply.jcms_lastDamaged > data.shieldDelay) then
					local newValue = ply:Armor() + 1
					ply:SetArmor(newValue)

					if newValue == ply:GetMaxArmor() then
						local ed = EffectData()
						ed:SetEntity(ply)
						ed:SetFlags(2)
						ed:SetColor(jcms.util_colorIntegerSweeperShield)
						util.Effect("jcms_shieldeffect", ed)
						ply:EmitSound("items/suitchargeok1.wav", 50, 130, 0.5)
					end
				end

			else
				timer.Remove(timerIdentifier)
			end
		end)

		-- Post
		if data.OnSpawn then
			data.OnSpawn(ply, data)
		end
	end

	function jcms.class_Get(ply) --This isn't used anywhere.
		if IsValid(ply) then
			return ply:GetNWString("jcms_class", "infantry")
		end
	end

	if SERVER then
		function jcms.class_GetData(ply)
			return jcms.classes[ ply:GetNWString("jcms_class", "infantry") ]
		end
	elseif CLIENT then --Optimisation, the GetNW calls can get expensive here so we cache it.
		function jcms.class_GetData(ply)
			return jcms.classes[ ply:GetNWString("jcms_class", "infantry") ] --TODO: Temporary revert. 
			--return jcms.classes[ jcms.cachedValues.playerClass ] --I'm assuming we're only getting our own data on client. This should always be true but keep it in mind - j
		end
	end

	function jcms.class_GetCostMultipliers(data, orderData)
		local costMult, coolDownMult = 1, 1
		if data then
			if data.getCostMult then
				costMult = data.getCostMult(orderData)
			end
			if data.getCoolDownMult then
				coolDownMult = data.getCoolDownMult(orderData)
			end
		end
		return costMult, coolDownMult
	end

	function jcms.class_Add(name, data, jcorp)
		jcms.classes[ name ] = data
		data.jcorp = not not jcorp
		
		if CLIENT and not data.stats then
			data.stats = {
				offensive = "0",
				resistance = "0",
				mobility = "0"
			}
		end
		
		if data.jcorp then
			jcms.classesOrderIndices[ name ] = (data.orderIndex or 10)
			table.insert(jcms.classesOrder, name)
		end
	end

-- // }}}

hook.Add("PlayerPostThink", "jcms_ClassThink", function(ply)
	local data = jcms.class_GetData(ply)
	if data and data.Think then
		data.Think(ply)
	end
end)
