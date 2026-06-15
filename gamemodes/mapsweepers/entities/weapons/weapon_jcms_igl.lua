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
AddCSLuaFile()

SWEP.PrintName = "Incendiary Grenade Launcher"
SWEP.Author = "Octantis Addons"
SWEP.Purpose = "Map Sweepers"
SWEP.Instructions = "Kill"
SWEP.Spawnable = false
SWEP.AdminOnly = true

SWEP.Primary.ClipSize = 4
SWEP.Primary.DefaultClip = 4
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1_Grenade"
SWEP.Primary.Damage = 10
SWEP.Primary.NumBullets = 1
SWEP.Primary.Spread = 2.1
SWEP.Primary.Delay = 1

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom	= false

SWEP.Slot = 4
SWEP.SlotPos = 2
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/weapons/v_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_smg_p90.mdl"

SWEP.ShootSound = Sound("Weapon_XM1014.Single")

function SWEP:Initialize()
	self:SetHoldType("shotgun")
end

-- // Attack {{{

	function SWEP:CanPrimaryAttack()
		if self.Weapon:Clip1() <= 0 then
			self:EmitSound("Weapon_Pistol.Empty")
			self:SetNextPrimaryFire(CurTime() + 1)
			return false
		else
			return true
		end
	end
	
	function SWEP:PrimaryAttack()
		if not IsValid(self.Weapon) then return end
		
		if self:CanPrimaryAttack() then
			self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
			self.Weapon:EmitSound(self.ShootSound)
			self.Weapon:ShootEffects()
			
			local spread = self.Primary.Spread
			if self.Owner:IsNPC() then
				spread = self:GetNPCBulletSpread(self.Owner:GetCurrentWeaponProficiency())
			end

			self:ShootBullet(self.Primary.Damage, self.Primary.NumBullets, math.rad(spread), self.Primary.Ammo, 4, 1)
			self:TakePrimaryAmmo(1)
		end
	end

	function SWEP:ShootBullet(damage, numbullets, aimcone, ammotype, force, tracerX)
		if not (IsValid(self) and IsValid(self.Owner) and IsValid(self:GetOwner())) then return end

		self:ShootEffects()

		--Spawning
		local startPos = (self.Owner:WorldSpaceCenter() + self.Owner:EyePos())/2
		local bomb = ents.Create("jcms_firebomb")
		bomb:SetPos(startPos)
		bomb:SetOwner(self.Owner)
		bomb:SetAngles(AngleRand())
		bomb:Spawn()
		bomb.Damage = damage
		bomb.Attacker = self.Owner
	
		--Targeting
		local firingAng = math.pi/4 --Designer value (Radians), could be made to get harsher at a distance

		local aimVec = self.Owner:GetAimVector()
		local target = self.Owner:GetEnemy()
		if IsValid(target) then
			local targetPos = target:GetPos() --We want their feet, not their body.
			--target:BodyTarget(startPos)

			--Project targetpos onto plane that goes through up + aimNormal (Basically get the point closest to the target in our current aim direction). 
			local planeNormal = aimVec:Cross(jcms.vectorUp)

			local d = jcms.util_PlaneOffsFromPointNormal(startPos, planeNormal) --plane offset / 'd' value, I don't like single-letter variable names but I think it's clearest in this context.
			local closestPoint = jcms.util_ClosestPointOnPlane(planeNormal, d, targetPos) --Closest point
			
			-- Calculating Velocity needed to hit our target at the given angle {{{
				local cos = math.cos(firingAng)
				local sin = math.sin(firingAng)
				local tan = sin/cos
				local g = physenv.GetGravity().z

				--x direction and displacement
				local dir = closestPoint - startPos
				dir.z = 0
				local groundLen = dir:Length()
				dir:Normalize()

				--y displacement
				local height = closestPoint.z - startPos.z

				--Starting velocity needed to hit target
				local startVel = (((g/2)*groundLen^2)/(height - (tan*groundLen)*cos^2))^(1/2)

				--Final Vector (split it back into vertical and horizontal components)
				local velocityVector = (startVel*cos*dir) + (startVel*sin*jcms.vectorUp)
			-- // }}}

			velocityVector:Rotate(AngleRand(-aimcone, aimcone))
			bomb:GetPhysicsObject():SetVelocity(velocityVector)
		else 
			aimVec:Mul(600)
			aimVec:Rotate(AngleRand(-aimcone, aimcone))

			bomb:GetPhysicsObject():SetVelocity(aimVec)
		end
		
		--MuzzleFlash
		local ed = EffectData()
		ed:SetEntity(self)
		ed:SetFlags(3)
		ed:SetAttachment(1)
		util.Effect("MuzzleFlash", ed)
	end

	function SWEP:GetTracerOrigin()
		local att = self:GetAttachment(self:LookupAttachment("muzzle")) or self:GetAttachment(self:LookupAttachment("1"))
		return (att and att.Pos or self:GetPos())
	end
	
	function SWEP:CanSecondaryAttack()
		return false
	end
	
	function SWEP:SecondaryAttack()
		return false
	end

-- // }}}

-- // NPCs {{{

	function SWEP:GetNPCBurstSettings()
		return 1, 1, self.Primary.Delay
	end

	function SWEP:GetNPCRestTimes()
		return 1.5, 2.5
	end

	function SWEP:GetNPCBulletSpread(prof)
		local goodFactor = math.Remap(prof, WEAPON_PROFICIENCY_POOR, WEAPON_PROFICIENCY_PERFECT, 0, 1)^2
		return math.Rand(Lerp(goodFactor, 2.6, 0), Lerp(goodFactor, 23.4, 2.8))
	end

	function SWEP:CanBePickedUpByNPCs()
		return true 
	end

-- // }}}
