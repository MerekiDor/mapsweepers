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

        local startPos = (self.Owner:WorldSpaceCenter() + self.Owner:EyePos())/2
		local bomb = ents.Create("jcms_firebomb")
		bomb:SetPos(startPos)
		bomb:SetOwner(self.Owner)
        bomb:SetAngles(AngleRand())
		bomb:Spawn()
		bomb.Damage = damage
		bomb.Attacker = self.Owner

        local distToEnemy = 600
        local addedZ = 4
        local target = self.Owner:GetEnemy()
        if IsValid(target) then
            local enemyPos = target:BodyTarget(startPos)
            distToEnemy = startPos:Distance( enemyPos )

            local zDiff = enemyPos.z - startPos.z
            
            if zDiff > 0 then
                addedZ = math.min(300, zDiff) + 48
            else
                distToEnemy = distToEnemy - zDiff*0.2
                addedZ = math.abs(zDiff)^0.8 + 32
            end
        end

        local normal = self.Owner:GetAimVector()
        normal:Rotate( AngleRand(-aimcone, aimcone) )
        normal:Mul(distToEnemy * 0.7 + 100)
        normal.z = normal.z + addedZ
		bomb:GetPhysicsObject():SetVelocity(normal)
		
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
        return math.Rand(Lerp(goodFactor, 1.3, 0), Lerp(goodFactor, 11.8, 1.4))
    end

    function SWEP:CanBePickedUpByNPCs()
        return true 
    end

-- // }}}
