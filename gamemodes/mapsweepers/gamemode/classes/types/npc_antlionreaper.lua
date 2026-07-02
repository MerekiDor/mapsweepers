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
jcms.class_Add("npc_antlionreaper", class)

class.faction = "antlion"
class.mdl = "models/antlion.mdl"
class.footstepSfx = "NPC_Antlion.FootstepHeavy"
class.footstepSfxNoPostfix = true

class.health = 200
class.shield = 0
class.shieldRegen = 0
class.shieldDelay = 64

class.damage = 1
class.hurtMul = 1
class.hurtReduce = 1
class.speedMul = 1
class.jumpPower = 300

class.playerColorVector = Vector(1, 1, 0)
class.noFallDamage = true
class.gravity = 1.1

function class.OnSpawn(ply)
	ply:Give("weapon_jcms_playernpc", false)
	ply.jcms_bounty = 80

	ply:SetMaterial("metal2")
	ply:SetColor(Color(math.random(190, 200), math.random(148, 152), math.random(36, 42)))
end

if SERVER then

	function class.MakeBeam(ply, wep, dmg)
		local count = 0
		if not wep.beams then
			wep.beams = {}
		end

		for i, beam in pairs(wep.beams) do
			if not IsValid(beam) then
				wep.beams[i] = nil
			else
				count = count + 1
			end
		end

		if count < 2 then
			local beam = ents.Create("jcms_beam")

			local fromPos = ply:WorldSpaceCenter()
			local goal = ply:GetEyeTrace().HitPos

			local ang = ply:GetAngles()
			ang.p = 0
			fromPos:Add( ang:Right()*(ply.beamDir or 1)*8 )

			beam:SetPos(fromPos)
			beam:SetBeamAttacker(ply)
			beam:Spawn()
			beam.Damage = dmg or 20
			beam.friendlyFireCutoff = 100
			beam:SetBeamLength(1250)

			beam:SetParent(ply)
			ply:EmitSound("ambient/energy/weld"..math.random(1,2)..".wav", 140, 105, 1)

			table.insert(wep.beams, beam)
			return beam, goal
		end
	end
	
	function class.PrimaryAttack(ply, wep)
		ply.beamDir = -(ply.beamDir or 1)
		local beam, goal = class.MakeBeam(ply, wep, 15)
		if beam then
			beam:FireBeamSweep(goal, math.Rand(-0.15, 0.15), 10*ply.beamDir, 3)
		end
	end

	function class.SecondaryAttack(ply, wep)
		ply.beamDir = -(ply.beamDir or 1)
		local beam, goal = class.MakeBeam(ply, wep, 25)
		if beam then
			beam:FireBeamSweep(goal, math.Rand(0.85, 1.15), 4*ply.beamDir, 2)
		end
	end

	function class.OnDeath(ply)
		local ed = EffectData()
		ed:SetOrigin(ply:WorldSpaceCenter())
		ed:SetRadius(120)
		ed:SetNormal(VectorRand(-1, 1))
		ed:SetMagnitude(1.75)
		ed:SetFlags(1)
		util.Effect("jcms_blast", ed)

		ply:EmitSound("NPC_Vortigaunt.Explode")
		ply:EmitSound("NPC_Antlion.RunOverByVehicle")

		for i=1, math.random(5, 8) do
			local epos = ply:WorldSpaceCenter()
			timer.Simple( (math.random()^2)*0.15, function()
				local ed = EffectData()
				local gibpos = epos + VectorRand(-16, 16)
				ed:SetOrigin(gibpos)
				ed:SetMagnitude(3)
				ed:SetScale(1)
				ed:SetNormal( (gibpos - epos):GetNormalized() )
				util.Effect(math.random()<0.5 and "StriderBlood" or "AntlionGib", ed)
			end)
		end

		timer.Simple(0.04, function()
			if IsValid(ply) and IsValid(ply:GetRagdollEntity()) then
				ply:GetRagdollEntity():Remove()
			end
		end)
	end

end

if CLIENT then
	
	class.color = Color(255, 252, 83)
	class.colorAlt = Color(255, 41, 41)

	function class.Render(ply) 
		--Lua-error prevention. Would be better if they faced where the player was looking or something.
		ply.EyeAnglePitch = ply.EyeAnglePitch or { 0, 0, 0, 0 }
		ply.EyeAngleYaw = ply.EyeAngleYaw or { 0, 0, 0, 0 }

		local eyeFunc = scripted_ents.GetMember("npc_jcms_reaper", "DrawEyes")
		if type(eyeFunc) == "function" then
			eyeFunc(ply, scripted_ents.GetMember("npc_jcms_reaper", "MatGlow"))
		end
	end

	function class.HUDOverride(ply)
		local col = class.color
		local colAlt = class.colorAlt
		local sw, sh = ScrW(), ScrH()

		local weapon = ply:GetActiveWeapon()
		cam.Start2D()
			jcms.hud_npc_DrawTargetIDs(col, colAlt)
			jcms.hud_npc_DrawHealthbars(ply, col, colAlt)
			jcms.hud_npc_DrawCrosshair(ply, weapon, col, colAlt)
			jcms.hud_npc_DrawSweeperStatus(col, colAlt)
			jcms.hud_npc_DrawObjectives(col, colAlt)
			jcms.hud_npc_DrawDamage(col, colAlt)
		cam.End2D()
		surface.SetAlphaMultiplier(1)
	end

	function class.TranslateActivity(ply, act)
		if ply:IsOnGround() then
			local myvector = ply:GetVelocity()
			local speed = myvector:Length()
			
			if speed > 10 then
				myvector.z = 0
				myvector:Normalize()
				local myangle = ply:GetAngles()
				
				ply:SetPoseParameter("move_yaw", math.AngleDifference( myvector:Angle().yaw, myangle.yaw))
				if ply:IsSprinting() then
					return ACT_RUN
				else
					return ACT_WALK
				end
			else
				return ACT_IDLE
			end
		else
			return ACT_GLIDE
		end
	end
	
	function class.ColorMod(ply, cm)
		jcms.colormod["$pp_colour_addr"] = 0.11
		jcms.colormod["$pp_colour_addg"] = 0.09
		jcms.colormod["$pp_colour_addb"] = 0

		jcms.colormod["$pp_colour_mulr"] = 0
		jcms.colormod["$pp_colour_mulg"] = 0
		jcms.colormod["$pp_colour_mulb"] = 0
		
		jcms.colormod["$pp_colour_contrast"] = 1.13
		jcms.colormod["$pp_colour_brightness"] = -0.01
		
		jcms.colormod[ "$pp_colour_colour" ] = 0.6
	end
	
end

