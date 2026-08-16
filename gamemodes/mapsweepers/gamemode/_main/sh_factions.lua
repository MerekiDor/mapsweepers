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

-- // List {{{

	jcms.factions = {
		antlion = {
			name = "antlion",
			color = Color(235, 237, 100)
		},

		combine = {
			name = "combine",
			color = Color(43, 179, 225)
		},

		rebel = {
			name = "rebel",
			color = Color(143, 67, 229)
		},

		zombie = {
			name = "zombie",
			color = Color(139, 17, 17)
		}
	}

	jcms.vanillaFactions = {}
	for k,v in pairs(jcms.factions) do
		jcms.vanillaFactions[k] = v
	end

-- // }}}

-- // Misc {{{

	jcms.factions_neutralColor = Color(230, 230, 230)
	jcms.factions_neutralColorInteger = jcms.util_ColorInteger(jcms.factions_neutralColor)

-- // }}}

-- // Functions {{{

	function jcms.factions_GetOrder()
		local keys = table.GetKeys(jcms.factions)
		table.sort(keys)
		return keys
	end

	function jcms.factions_GetColor(factionName)
		local fd = jcms.factions[ factionName ]
		return fd and fd.color or jcms.factions_neutralColor
	end

	function jcms.factions_GetColorInteger(factionName)
		local fd = jcms.factions[ factionName ]

		if fd and fd.color then
			if not fd.colorInteger then
				fd.colorInteger = jcms.util_ColorInteger(fd.color)
			end

			return fd.colorInteger
		else
			return jcms.factions_neutralColorInteger
		end
	end

-- // }}}