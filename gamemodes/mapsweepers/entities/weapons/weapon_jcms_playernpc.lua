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

SWEP.PrintName = "Player NPC Weapon"
SWEP.Author = "Octantis Addons"
SWEP.Purpose = "Map Sweepers"
SWEP.Instructions = "Kill"
SWEP.Spawnable = false
SWEP.AdminOnly = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Damage = 0
SWEP.Primary.NumBullets = 1
SWEP.Primary.Spread = 0
SWEP.Primary.Delay = 1 / 10

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom	= false

SWEP.Slot = 1
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.ViewModel = "models/hunter/plates/plate.mdl"
SWEP.WorldModel = "models/hunter/plates/plate.mdl"

SWEP.m_bPlayPickupSound = false

-- // Attack {{{

    function SWEP:CanPrimaryAttack()
		return true
    end
    
    function SWEP:PrimaryAttack()
        if not IsValid(self.Weapon) then return end
		local user = self:GetOwner()
		if IsValid(user) and user:IsPlayer() then
			local classData = jcms.class_GetData(user)
			
			if classData.PrimaryAttack then
				classData.PrimaryAttack(user, self.Weapon)
			end
		end
    end
    
    function SWEP:CanSecondaryAttack()
        return true
    end
    
    function SWEP:SecondaryAttack()
        if not IsValid(self.Weapon) then return end
		local user = self:GetOwner()
		if IsValid(user) and user:IsPlayer() then
			local classData = jcms.class_GetData(user)
			
			if classData.SecondaryAttack then
				classData.SecondaryAttack(user, self.Weapon)
			end
		end
	end

-- // }}}

-- // NPCs {{{

	function SWEP:CanBePickedUpByNPCs()
		return false
	end

-- // }}}

if CLIENT then
	function SWEP:DrawWorldModel()
		-- NOTHING. NOTHING HAPPENS. NOTHING EVER HAPPENS!!!!!!!!!!!!!
	end

	function SWEP:ShouldDrawViewModel()
		return false
	end
end
