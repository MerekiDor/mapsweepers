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

-- // Helper function {{{

	jcms.deprecated_warnedList = {}
	function jcms.deprecated_Define(oldFuncName, newFuncName)
		if oldFuncName:sub(1, 5) == "jcms." then oldFuncName = oldFuncName:sub(6, -1) end
		if newFuncName:sub(1, 5) == "jcms." then newFuncName = newFuncName:sub(6, -1) end
		
		local col1 = Color(255, 0, 0)
		local col2 = Color(106, 73, 255)
		local col3 = Color(87, 243, 87)

		local msgct = {
			col1, "[!!! MAP SWEEPERS DEPRECATED CODE !!!] \"", 
			col2, "jcms." .. oldFuncName, 
			col1, "\" is DEPRECATED - use \"", 
			col3, "jcms." .. newFuncName,
			col1, "\" instead!"
		}

		jcms[ oldFuncName ] = function(...)
			if not jcms.deprecated_warnedList[ oldFuncName ] then
				jcms.deprecated_warnedList[ oldFuncName ] = true
				ErrorNoHalt("")
			end

			MsgC( unpack(msgct) )

			return jcms[ newFuncName ]( ... )
		end
	end

-- // }}}

-- // Server {{{
if SERVER then
	jcms.deprecated_Define("jcms.giveCash", "jcms.cash_Add")
	jcms.deprecated_Define("jcms.giveCashForUselessAmmo", "jcms.cash_GiveForAmmo")

	jcms.deprecated_Define("jcms.npc_AddBulletShield", "jcms.AddBubbleMantle")
end
-- // }}}

-- // CLIENT {{{
if CLIENT then
end
-- // }}}