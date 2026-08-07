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
-- Hints are dispatched by the DIRECTOR. This file contains the data this system uses & helper functions.

if SERVER then 
	jcms.hintData = {}
	--Also exists on client, but is in cl_init.lua
	--Should maybe change that? Don't like having stuff spread out.

	--Maybe I should give the tables different names (e.g. sv should be plyHintData or something, since it's a differently structured table)

	--[[ NOTE
		I've realized I probably don't need to network this data in the first place.
		I can just ignore tips we've already heard clientside.
	--]]
end

jcms.HINT_SPAWNMENU		= 0 
jcms.HINT_FIRSTAID		= 1 
jcms.HINT_AMMO			= 2
jcms.HINT_TURRETREP		= 3
jcms.HINT_RESPAWN		= 4
jcms.HINT_ANTIAIR		= 5
jcms.HINT_BREACH		= 6
jcms.HINT_LEECHES		= 7
jcms.HINT_POLYP			= 8
jcms.HINT_UNIQUEORDERS	= 9
jcms.HINT_STUCK			= 10
jcms.HINT_FLIPOVER		= 11
jcms.HINT_CREEP			= 12

if CLIENT then 
	jcms.hints = {
		[jcms.HINT_SPAWNMENU] = "#jcms.hint_spawnmenu",
		[jcms.HINT_FIRSTAID] = "#jcms.hint_firstaid",
		[jcms.HINT_AMMO] = "#jcms.hint_ammo",
		[jcms.HINT_TURRETREP] = "#jcms.hint_turretrep",
		[jcms.HINT_RESPAWN] = game.SinglePlayer() and "#jcms.hint_respawn_solo" or "#jcms.hint_respawn",
		[jcms.HINT_ANTIAIR] = "#jcms.hint_antiair",
		[jcms.HINT_BREACH] = "#jcms.hint_breach",
		[jcms.HINT_LEECHES] = "#jcms.hint_leeches",
		[jcms.HINT_POLYP] = "#jcms.hint_polyp",
		[jcms.HINT_UNIQUEORDERS] = "#jcms.hint_uniqueorders",
		[jcms.HINT_STUCK] = "#jcms.hint_stuck",
		[jcms.HINT_FLIPOVER] = "#jcms.hint_flipover",

		[jcms.HINT_CREEP] = [=[Flesh Creep can be cleared using explosives]=]
	}
end

