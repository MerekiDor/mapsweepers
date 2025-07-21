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
local class = {}
jcms.class_Add("npc_rebelodessa", class)

class.faction = "rebel"
class.mdl = "models/player/odessa.mdl"
class.deathSound = "npc_citizen.die"
class.footstepSfx = "NPC_Citizen.RunFootstep"

class.health = 50
class.shield = 0
class.shieldRegen = 0
class.shieldDelay = 64

class.damage = 0.25
class.hurtMul = 1
class.hurtReduce = 1
class.speedMul = 0.75

class.playerColorVector = Vector(0.6, 0, 1.0)

function class.OnSpawn(ply)
	local weapon = ply:Give("weapon_jcms_rpg", false)
	ply:GiveAmmo(9999, weapon:GetPrimaryAmmoType())
	ply.jcms_bounty = 50
end

if SERVER then
	
	function class.TakeDamage(ply, dmg)
		if dmg:GetAttacker() == ply and bit.band( dmg:GetDamageType(), DMG_BLAST ) > 0 then
			local v
			if IsValid(dmg:GetInflictor()) then
				v = ply:EyePos() - dmg:GetInflictor():WorldSpaceCenter()
			else
				v = dmg:GetDamagePosition() - dmg:GetReportedPosition()
			end
			v:Normalize()
			v.z = v.z + 0.1
			v:Mul( dmg:GetDamage() * 16 )

			ply:SetVelocity(v)
			dmg:ScaleDamage(0.01)
			ply.jcms_odessaRocketJumped = 0 -- Time spent airborne

			ply:EmitSound("weapons/iceaxe/iceaxe_swing1.wav")
		end

		if dmg:IsFallDamage() and ply.jcms_odessaRocketJumped then
			dmg:ScaleDamage(0.15)
			ply.jcms_odessaRocketJumped = nil
		end
	end

	function class.Think(ply)
		if CLIENT then return end

		if ply.jcms_odessaRocketJumped then
			if ply:OnGround() then
				ply.jcms_odessaRocketJumped = nil
			else
				ply.jcms_odessaRocketJumped = ply.jcms_odessaRocketJumped + FrameTime()

				if ply.jcms_odessaRocketJumped > 0.6 and (not ply.jcms_odessaCheered or CurTime() - ply.jcms_odessaCheered > 10) then
					-- If we spent more than 1 second in the air, cheer
					ply.jcms_odessaCheered = CurTime()

					local randomSounds = {
						"vo/coast/odessa/male01/nlo_cheer01.wav",
						"vo/coast/odessa/male01/nlo_cheer02.wav",
						"vo/coast/odessa/male01/nlo_cheer03.wav",
						"vo/coast/odessa/male01/nlo_cheer04.wav",
						"vo/coast/odessa/nlo_cub_service.wav",
						"vo/coast/odessa/nlo_cub_thatsthat.wav",
						"vo/coast/odessa/nlo_cub_wherewasi.wav",
						"vo/coast/odessa/nlo_cub_carry.wav"
					}

					local randomSound = randomSounds[ math.random(1, #randomSounds) ]
					ply:EmitSound(randomSound)
				end
			end
		end
	end

end

if CLIENT then
	
	function class.HUDOverride(ply)
		local col = Color(106, 91, 247)
		local colAlt = Color(220, 25, 238)
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
	
	function class.ColorMod(ply, cm)
		jcms.colormod["$pp_colour_addr"] = 0.04
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
