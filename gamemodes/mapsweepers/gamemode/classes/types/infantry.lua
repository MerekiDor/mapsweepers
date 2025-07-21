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
class.orderIndex = 2
jcms.class_Add("infantry", class, true)

-- Infantry Armor
class.mdl = "models/player/riot.mdl"
class.footstepSfx = "NPC_MetroPolice.RunFootstep"

class.health = 100
class.shield = 75
class.shieldRegen = 7
class.shieldDelay = 7

class.damage = 1.25 -- This unit deals 25% more damage than others
class.hurtMul = 1
class.hurtReduce = 1
class.speedMul = 1

class.matOverrides = {
	["models/cstrike/ct_gsg9"] = "models/jcms/player/infantry"
}

function class.Think(ply)
	if CLIENT and ply ~= LocalPlayer() then return end

	local wep = ply:GetActiveWeapon()

	if not IsValid(wep) then return end

	if not wep:IsScripted() then
		-- Vanilla weapons
		if wep:GetMaxClip1() > 0 then
			local clip = wep:Clip1()

			if not wep.lastClip1 then
				wep.lastClip1 = clip
			else
				local restored = 0
				for i=clip, wep.lastClip1-1 do
					if util.SharedRandom("InfantryAmmoRestore", 0, 1) >= 0.5 then
						restored = restored + 1
					end
				end

				wep:SetClip1( clip + restored )
				wep.lastClip1 = wep:Clip1()
			end
		end
	elseif not wep.jcms_infantryOwner then
		wep.jcms_infantryOwner = ply

		if wep.IsTFAWeapon then
			-- TFA workaround. Was a real bitch to deal with, cause the guy
			-- relies on TakePrimaryAmmo for some weird-ass calculations.

			local originalFunction = wep.TakePrimaryAmmo
			wep.TakePrimaryAmmo = function(self, num, pool)
				local owner = self:GetOwner()
				if owner == self.jcms_infantryOwner then
					if (num > 0 and not pool) then
						if util.SharedRandom("InfantryAmmoRestore", 0, 1) >= 0.5 then
							if self:GetMaxClip1() < 10 then --not helpful for high-capacity weapons.
								timer.Simple(0, function()
									if IsValid(self) then
										self:EmitSound("buttons/lever6.wav", 75, 150, 1, CHAN_STATIC)
										self:EmitSound("buttons/lever7.wav", 75, 100, 1, CHAN_STATIC)
									end
								end)
							end
							return originalFunction(self, num, pool)
						end
					else
						return originalFunction(self, num, pool)
					end
				else
					originalFunction(self, num, pool)
					wep.TakePrimaryAmmo = originalFunction
					return 0
				end
			end
		elseif wep.TakeAmmo then
			-- Serious Sam 2 weapons workaround
			local originalFunction = wep.TakeAmmo
			wep.TakeAmmo = function(self, count, ...)
				local owner = self:GetOwner()
				if owner == self.jcms_infantryOwner then
					local consumed = 0
					if util.SharedRandom("InfantryAmmoRestore", 0, 1) >= 0.5 then
						consumed = originalFunction(self, count, ...)

						if self:GetMaxClip1() < 10 then --not helpful for high-capacity weapons.
							timer.Simple(0, function()
								if IsValid(self) then
									self:EmitSound("buttons/lever6.wav", 75, 150, 1, CHAN_STATIC)
									self:EmitSound("buttons/lever7.wav", 75, 100, 1, CHAN_STATIC)
								end
							end)
						end
					end
					return consumed -- I don't remember why this line is needed, I think I was trying to get TFA fixed months ago?
				else
					originalFunction(self, count)
					wep.TakeAmmo = originalFunction
					return 0
				end
			end
		else
			local originalFunction = wep.TakePrimaryAmmo
			wep.TakePrimaryAmmo = function(self, count, ...)
				local owner = self:GetOwner()
				if owner == self.jcms_infantryOwner then
					local consumed = 0
					if util.SharedRandom("InfantryAmmoRestore", 0, 1) >= 0.5 then
						consumed = originalFunction(self, count, ...)

						if self:GetMaxClip1() < 10 then --not helpful for high-capacity weapons.
							timer.Simple(0, function()
								if IsValid(self) then
									self:EmitSound("buttons/lever6.wav", 75, 150, 1, CHAN_STATIC)
									self:EmitSound("buttons/lever7.wav", 75, 100, 1, CHAN_STATIC)
								end
							end)
						end
					end
					return consumed
				else
					originalFunction(self, count, ...)
					wep.TakePrimaryAmmo = originalFunction
					return 0
				end
			end
		end
	end
end

if CLIENT then
	class.stats = {
		offensive = "2",
		resistance = "0",
		mobility = "0"
	}
end
