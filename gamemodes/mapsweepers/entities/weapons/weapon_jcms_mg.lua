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

SWEP.PrintName = "Machinegun"
SWEP.Author = "Octantis Addons"
SWEP.Purpose = "Map Sweepers"
SWEP.Instructions = "Kill"
SWEP.Spawnable = false
SWEP.AdminOnly = true

SWEP.Primary.ClipSize = 100
SWEP.Primary.DefaultClip = 100
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Damage = 5
SWEP.Primary.NumBullets = 1
SWEP.Primary.Spread = 2.8
SWEP.Primary.Delay = 1 / 10

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

SWEP.ViewModel = "models/weapons/cstrike/c_mach_m249para.mdl"
SWEP.WorldModel = "models/weapons/w_mach_m249para.mdl"
SWEP.UseHands = true

if SERVER then
	sound.Add( {
		name = "Weapon.jcms_mg",
		channel = CHAN_WEAPON,
		volume = 1.0,
		level = 140,
		pitch = 100,
		sound = "jcms/machinegun.wav"
	} )
end

SWEP.ShootSound = Sound("Weapon.jcms_mg")

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
        if not (IsValid(self) and IsValid(self.Owner) and IsValid(self:GetOwner())) then return end -- Muzzleflash errors if we get called without an owner

        local bullet = {
            Damage = damage or 1,
            Force = force or 0,
            AmmoType = ammotype,

            Num = numbullets or 1,
            Spread = Vector(aimcone or 0, aimcone or 0, 0),

            TracerName = "Tracer",
            Tracer = tracerX,

            Src = self.Owner:GetShootPos(),
            Dir = self.Owner:GetAimVector()
        }

        self.Owner:FireBullets(bullet)
        self:ShootEffects()
        
        if not self.Owner:IsPlayer() then
            local ed = EffectData()
            ed:SetEntity(self)
            ed:SetFlags(7)
            ed:SetAttachment(1)
            util.Effect("MuzzleFlash", ed)
        end
    end

    function SWEP:GetTracerOrigin()
        if IsValid(self.Owner) and self.Owner:IsPlayer() then return end
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
        return 25, 50, self.Primary.Delay
    end

    function SWEP:GetNPCRestTimes()
        return 0.5, 1.25
    end

    function SWEP:GetNPCBulletSpread(prof)
        local goodFactor = math.Remap(prof, WEAPON_PROFICIENCY_POOR, WEAPON_PROFICIENCY_PERFECT, 0, 1)^2
        return math.Rand(Lerp(goodFactor, 1.3, 0), Lerp(goodFactor, 11.8, 1.4))
    end

    function SWEP:CanBePickedUpByNPCs()
        return true 
    end

-- // }}}

-- // Animations and activities {{{

    local actTrans = {
        [ACT_MP_RELOAD_STAND] = ACT_HL2MP_GESTURE_RELOAD_AR2,
        [ACT_MP_STAND_IDLE] = ACT_HL2MP_IDLE_SHOTGUN,
        [ACT_MP_WALK] = ACT_HL2MP_WALK_SHOTGUN,
        [ACT_MP_RUN] = ACT_HL2MP_RUN_SHOTGUN,
        [ACT_MP_ATTACK_STAND_PRIMARYFIRE] = ACT_HL2MP_GESTURE_RANGE_ATTACK_AR2,
        [ACT_MP_ATTACK_CROUCH_PRIMARYFIRE] = ACT_HL2MP_GESTURE_RANGE_ATTACK_AR2,
        [ACT_MP_JUMP] = ACT_HL2MP_JUMP_CROSSBOW,
        [ACT_MP_AIRWALK] = ACT_HL2MP_JUMP_AR2,
        [ACT_MP_SWIM] = ACT_HL2MP_SWIM_AR2,
        [ACT_MP_RELOAD_CROUCH] = ACT_HL2MP_GESTURE_RELOAD_AR2,
        [ACT_MP_CROUCH_IDLE] = ACT_HL2MP_IDLE_CROUCH_AR2,
        [ACT_MP_CROUCHWALK] = ACT_HL2MP_WALK_CROUCH_AR2,
        [ACT_MP_SWIM_IDLE] = ACT_HL2MP_SWIM_AR2
    }

    local actTransNPC = {
        [ACT_IDLE] = ACT_IDLE_SMG1_STIMULATED,
        [ACT_IDLE_STIMULATED] = ACT_IDLE_SMG1_STIMULATED,
        [ACT_IDLE_ANGRY] = ACT_IDLE_ANGRY_SMG1,
        [ACT_IDLE_AGITATED] = ACT_IDLE_ANGRY_SMG1,
        [ACT_IDLE_RELAXED] = ACT_IDLE_SMG1_RELAXED,
        [ACT_RANGE_ATTACK1] = ACT_RANGE_ATTACK_AR2,
        [ACT_RANGE_ATTACK1_LOW] = ACT_RANGE_ATTACK_AR2_LOW,
        [ACT_WALK] = ACT_WALK_RIFLE,
        [ACT_WALK_AIM] = ACT_WALK_AIM_RIFLE,
        [ACT_RUN] = ACT_RUN_RIFLE,
        [ACT_RUN_AIM] = ACT_WALK_AIM_RIFLE,
        [ACT_RUN_AIM_RIFLE] = ACT_WALK_AIM_RIFLE,
        [ACT_RUN_RELAXED] = ACT_RUN_AIM_RIFLE_STIMULATED,
        [ACT_RUN_AGITATED] = ACT_RUN_AIM_RIFLE_STIMULATED,
        [ACT_RELOAD] = ACT_RELOAD_SMG1
    }

    function SWEP:TranslateActivity(act)
        if self:GetOwner():IsNPC() then
            return actTransNPC[act] or actTrans[act] or act
        elseif self:GetOwner():IsPlayer() then
            return actTrans[act] or act
        end
        return -1
    end

-- // }}}
