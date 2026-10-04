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

-- // Basics {{{

	function jcms.cash_Get(ply)
		return ply:GetNWInt("jcms_cash", 0)
	end

	if SERVER then
	
		function jcms.cash_Set(ply, value)
			ply:SetNWInt("jcms_cash", math.floor( tonumber(value) or 0))
		end

		function jcms.cash_Add(ply, amount, silent)
			if IsValid(ply) and ply:IsPlayer() then
				local added = math.ceil( tonumber(amount) or 0 )
				jcms.cash_Set( ply, jcms.cash_Get(ply) + added )

				if (added > 0) and (not silent) then
					jcms.net_SendCashEarn(ply, added)
				end
			end
		end

	end

-- // }}}

-- // Specific {{{
if SERVER then

	function jcms.cash_EnsureMinimum(ply, amount) -- if player has less than amount, give them that.
		local cash = jcms.cash_Get(ply)
		if cash < amount then
			jcms.cash_Set(ply, amount)
			return true
		end
		return false
	end

	function jcms.cash_GiveForAmmo(ply, ammoType, ammoCount, costMultiplier)
		if tonumber(ammoType) then
			ammoType = game.GetAmmoName(tonumber(ammoType))
		end
		
		if type(ammoType) == "string" then
			local cost = jcms.weapon_ammoCosts[ string.lower(ammoType) ]
			cost = cost or jcms.weapon_ammoCosts._DEFAULT
			
			costMultiplier = tonumber(costMultiplier) or 0.25
			jcms.cash_Add(ply, math.floor(ammoCount * cost * costMultiplier))
			-- todo Play sound
		end
	end

end
-- // }}}