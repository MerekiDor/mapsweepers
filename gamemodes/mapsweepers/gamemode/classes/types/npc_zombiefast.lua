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
jcms.class_Add("npc_zombiefast", class)

class.faction = "zombie"
class.mdl = "models/zombie/fast.mdl"
class.deathSound = "NPC_FastZombie.Die"
class.footstepSfx = "NPC_FastZombie.Footstep"

class.health = 50
class.shield = 0
class.shieldRegen = 0
class.shieldDelay = 64

class.damage = 0.5
class.hurtMul = 0.9
class.hurtReduce = 1
class.speedMul = 1
class.walkSpeed = 80
class.runSpeed = 250
class.jumpPower = 350

class.playerColorVector = Vector(0.6, 0, 0)
class.noFallDamage = true

function class.OnSpawn(ply)
	ply:Give("weapon_jcms_playernpc", false)
	ply.jcms_bounty = 20
	ply:SetBodygroup(1, 1)

	local timerId = "jcms_pNPCRegen" .. ply:EntIndex()
	timer.Create(timerId, 1, 0, function()
		if IsValid(ply) and ply:Alive() and ply:GetNWString("jcms_class") == "npc_zombiefast" then
			if ply:Health() < ply:GetMaxHealth() then
				ply:SetHealth( ply:Health() + 1 )
			end
		else
			timer.Remove(timerId)
		end
	end)
end

function class.PrimaryAttack(ply, wep)
	if ply.zombieFrenzy then return end

	wep.Primary.Automatic = true
	wep:SetNextPrimaryFire(CurTime() + 1/5)

	local tr = util.TraceHull {
		start = ply:EyePos(), endpos = ply:EyePos() + ply:EyeAngles():Forward() * 48,
		mask = MASK_PLAYERSOLID, filter = { ply, wep }, mins = Vector(-8, -8, -12), maxs = Vector(8, 8, 12)
	}

	if (CurTime() - (wep.lastFrenzySound or 0) > 1.8) then
		ply:EmitSound("NPC_FastZombie.Frenzy")
		wep.lastFrenzySound = CurTime()
	end

	if tr.Hit then
		ply:ViewPunch( AngleRand(-2, 2) )
		ply:EmitSound("NPC_FastZombie.AttackHit")

		if IsValid(tr.Entity) and tr.Entity:Health() > 0 then
			local dmg = DamageInfo()
			dmg:SetAttacker(ply)
			dmg:SetInflictor(ply)
			dmg:SetDamageType(DMG_SLASH)
			dmg:SetReportedPosition(ply:GetPos())
			dmg:SetDamagePosition(tr.HitPos)
			dmg:SetDamageForce(tr.Normal * 10000)
			dmg:SetAmmoType(-1)
			dmg:SetDamage(18)

			if tr.Entity.DispatchTraceAttack then 
				tr.Entity:DispatchTraceAttack(dmg, tr, tr.Normal)
			elseif tr.Entity.TakeDamageInfo then
				tr.Entity:TakeDamageInfo(dmg)
			end

			if tr.Entity.TakePhysicsDamage then
				tr.Entity:TakePhysicsDamage(dmg)
			end

			if jcms.team_JCorp(tr.Entity) then
				if ply:Health() < ply:GetMaxHealth() then
					ply:SetHealth( ply:Health() + 1 )
				end
			end
		end

		local start = ply:EyePos()
		start.x = start.x + math.Rand(-8, 8)
		start.y = start.y + math.Rand(-8, 8)
		start.z = start.z + math.Rand(-2, 8)
		util.Decal("Blood", start, tr.HitPos + tr.Normal * 5, ply)
	else
		ply:ViewPunch( AngleRand(-5, 5) )
		ply:EmitSound("NPC_FastZombie.AttackMiss")
	end
end

function class.SecondaryAttack(ply, wep)
	if ply:OnGround() and ply:WaterLevel() <= 1 then
		ply.zombieFrenzy = true
		wep:SetNextSecondaryFire(CurTime() + 2)

		if (CurTime() - (wep.lastLeapSound or 0) > 2) then
			ply:EmitSound("NPC_FastZombie.Scream")
			wep.lastLeapSound = CurTime()
		end

		ply:ViewPunch( Angle(4, 0, 0) )

		local vel = ply:EyeAngles():Forward()
		vel.z = math.max(vel.z, 0.249)
		vel:Mul(1000)
		ply:SetVelocity(vel)
	end
end

function class.Think(ply)
	if CLIENT then return end

	if ply:OnGround() and ply.zombieFrenzy then
		ply.zombieFrenzy = nil
	end

	if ply.zombieFrenzy then
		local tr = util.TraceHull {
			start = ply:WorldSpaceCenter(), endpos = ply:WorldSpaceCenter() + ply:GetVelocity(),
			mask = MASK_PLAYERSOLID, filter = ply, mins = Vector(-12, -12, -32), maxs = Vector(12, 12, 24)
		}

		if tr.Hit and IsValid(tr.Entity) and tr.Entity:Health() > 0 then
			ply.zombieFrenzy = false
			local dmg = DamageInfo()
			dmg:SetAttacker(ply)
			dmg:SetInflictor(ply)
			dmg:SetDamageType(bit.bor(DMG_SLASH, DMG_CRUSH))
			dmg:SetReportedPosition(ply:GetPos())
			dmg:SetDamagePosition(tr.HitPos)
			dmg:SetDamageForce(tr.Normal * 15000)
			dmg:SetAmmoType(-1)
			dmg:SetDamage(50)

			if tr.Entity.DispatchTraceAttack then 
				tr.Entity:DispatchTraceAttack(dmg, tr, tr.Normal)
			elseif tr.Entity.TakeDamageInfo then
				tr.Entity:TakeDamageInfo(dmg)
			end

			if tr.Entity.TakePhysicsDamage then
				tr.Entity:TakePhysicsDamage(dmg)
			end

			tr.Entity:EmitSound("physics/flesh/flesh_squishy_impact_hard3.wav")

			if jcms.team_JCorp(tr.Entity) then
				if ply:Health() < ply:GetMaxHealth() then
					ply:SetHealth( ply:Health() + 3 )
				end
			end
		end
	end
end

function class.OnDeath(ply)
	ply.zombieFrenzy = nil

	local crab = ents.Create("npc_headcrab_fast")
	if IsValid(crab) then
		ply:SetBodygroup(1, 0)
		crab:SetPos(ply:EyePos())
		crab.jcms_owner = ply
		crab:Spawn()
	end
end

if CLIENT then

	class.color = Color(255, 83, 83)
	class.colorAlt = Color(255, 183, 100)

	function class.HUDOverride(ply)
		local col = Color(255, 83, 83)
		local colAlt = Color(255, 183, 100)
		local sw, sh = ScrW(), ScrH()

		local weapon = ply:GetActiveWeapon()
		cam.Start2D()
			jcms.hud_npc_DrawTargetIDs(col, colAlt)
			jcms.hud_npc_DrawHealthbars(ply, col, colAlt)
			jcms.hud_npc_DrawCrosshairMelee(ply, weapon, col)
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
			
			if ply:KeyDown(IN_ATTACK) then
				return ACT_MELEE_ATTACK1
			end

			if speed > 40 then
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
			ply:SetCycle(1)
			return ACT_RANGE_ATTACK1
		end
	end
	
	function class.ColorMod(ply, cm)
		jcms.colormod["$pp_colour_addr"] = 0.11
		jcms.colormod["$pp_colour_addg"] = 0
		jcms.colormod["$pp_colour_addb"] = 0

		jcms.colormod["$pp_colour_mulr"] = 0
		jcms.colormod["$pp_colour_mulg"] = -0.5
		jcms.colormod["$pp_colour_mulb"] = -0.5
		
		jcms.colormod["$pp_colour_contrast"] = 1.04
		jcms.colormod["$pp_colour_brightness"] = -0.01
		
		jcms.colormod[ "$pp_colour_colour" ] = 0.6
	end
	
end

