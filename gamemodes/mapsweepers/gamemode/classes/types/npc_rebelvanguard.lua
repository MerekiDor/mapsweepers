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
local class = {}
jcms.class_Add("npc_rebelvanguard", class)

class.faction = "rebel"
class.mdl = "models/barney.mdl"
class.deathSound = "npc_citizen.die"
class.footstepSfx = "NPC_Citizen.RunFootstep"

class.health = 65
class.shield = 0
class.shieldRegen = 0
class.shieldDelay = 64

class.damage = 0.4
class.hurtMul = 0.2
class.hurtReduce = 0
class.speedMul = 0.75

class.playerColorVector = Vector(0.6, 0, 1.0)

function class.OnSpawn(ply)
	local weapon = ply:Give("weapon_jcms_igl", false)
	ply:GiveAmmo(9999, weapon:GetPrimaryAmmoType())
	ply:Give("weapon_frag", false)
	ply.jcms_bounty = 45
	ply.jcms_EntityFireBullets = class.EntityFireBullets

	if IsValid(ply.jcms_vanguardnpc_backpack) then
		ply.jcms_vanguardnpc_backpack:Remove()
	end

	local backpack = ents.Create("jcms_vanguard_backpack")
	ply.jcms_vanguardnpc_backpack = backpack

	local attch = ply:GetAttachment(3)
	backpack:SetPos(attch.Pos - attch.Ang:Forward() * 11 - attch.Ang:Up() * 20)
	backpack:SetAngles(attch.Ang)
	backpack:SetParent(ply, 3)
	backpack:Spawn()
	backpack.jcms_owner = ply
	backpack.jcms_fireproof = true

	backpack:SetPreventTransmit(ply, true)
end

if SERVER then

	function class.TakeDamage(ply, dmg)
		local backpack = ply.jcms_vanguardnpc_backpack
		if IsValid(backpack) and not backpack.jcms_exploded then
			if bit.band( dmg:GetDamageType(), bit.bor(DMG_BURN, DMG_SLOWBURN) ) > 0 then
				dmg:ScaleDamage(0.01)
			end
		else
			dmg:ScaleDamage(1.37) -- easier to kill with the backpack exploded
		end
	end

	function class.OnDeath(ply)
		local backpack = ply.jcms_vanguardnpc_backpack
		if IsValid(backpack) and not backpack.jcms_exploded then
			backpack:FallOff()
			backpack:SetPreventTransmit(ply, false)
		end
	end

end

if CLIENT then
	
	function class.HUDOverride(ply)
		local col = Color(173, 46, 231)
		local colAlt = Color(255, 203, 30)
		local sw, sh = ScrW(), ScrH()

		local weapon = ply:GetActiveWeapon()
		cam.Start2D()
			jcms.hud_npc_DrawTargetIDs(col, colAlt)
			jcms.hud_npc_DrawHealthbars(ply, col, colAlt)
			jcms.hud_npc_DrawCrosshair(ply, weapon, col, colAlt, colAlt)
			jcms.hud_npc_DrawSweeperStatus(col, colAlt)
			jcms.hud_npc_DrawObjectives(col, colAlt)
			jcms.hud_npc_DrawDamage(col, colAlt)
		cam.End2D()
		surface.SetAlphaMultiplier(1)
	end

	function class.TranslateActivity(ply, act)
		if act == 1001 then
			return ACT_JUMP
		end

		if ply:IsOnGround() then
			local myvector = ply:GetVelocity()
			local speed = myvector:Length()

			myvector.z = 0
			myvector:Normalize()
			local myangle = ply:GetAngles()
			ply:SetPoseParameter("move_yaw", math.AngleDifference( myvector:Angle().yaw, myangle.yaw))

			if speed <= 10 then
				if act == 1025 then
					return 380
				end
		
				if act == 1028 then
					return 377
				end
			end

			if speed > 10 then
				return ply:Crouching() and 361 or 362
			else
				return ply:Crouching() and 298 or 287
			end
		else
			return ACT_GLIDE
		end
	end
	
	function class.ColorMod(ply, cm)
		jcms.colormod["$pp_colour_addr"] = 0.08
		jcms.colormod["$pp_colour_addg"] = 0
		jcms.colormod["$pp_colour_addb"] = 0.11

		jcms.colormod["$pp_colour_mulr"] = 0
		jcms.colormod["$pp_colour_mulg"] = 0
		jcms.colormod["$pp_colour_mulb"] = 0
		
		jcms.colormod["$pp_colour_contrast"] = 1.05
		jcms.colormod["$pp_colour_brightness"] = -0.02
		
		jcms.colormod[ "$pp_colour_colour" ] = 0.89
	end
	
end
