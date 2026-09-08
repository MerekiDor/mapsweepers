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
local class = {}
class.orderIndex = 4
jcms.class_Add("engineer", class, true)

-- Pathfinder Armor
class.mdl = "models/player/jcms/jcorp_engineer.mdl"
class.mdls_pvp = {
	[1] = "models/player/jcms/jcorp_engineer.mdl",
	[2] = "models/player/jcms/mafia_engineer.mdl"
}

class.footstepSfx = "NPC_MetroPolice.RunFootstep"

class.health = 75
class.shield = 50
class.shieldRegen = 5
class.shieldDelay = 7

class.damage = 1
class.hurtMul = 1
class.hurtReduce = 1
class.speedMul = 1

function class.OnSpawn(ply)
	ply:Give( "weapon_physcannon", false )
end

--Engineer's cost offset behaviours.
class.engineer_discounts = {
	[jcms.SPAWNCAT_ORBITALS] = 0.5,
	[jcms.SPAWNCAT_MINES] = 0.5
}

class.engineer_cooldowns = {
	[jcms.SPAWNCAT_TURRETS] = 0.5,
	[jcms.SPAWNCAT_ORBITALS] = 0.5,
	[jcms.SPAWNCAT_MOBILITY] = 1,
	[jcms.SPAWNCAT_SUPPLIES] = 1,
	[jcms.SPAWNCAT_MINES] = 0.5,
	[jcms.SPAWNCAT_DEFENSIVE] = 0.5,
	[jcms.SPAWNCAT_UTILITY] = 0.5
}

function class.getCostMult(orderData)
	return class.engineer_discounts[orderData.category] or 1
end

function class.getCoolDownMult(orderData)
	return class.engineer_cooldowns[orderData.category] or 1
end

if CLIENT then
	class.stats = {
		offensive = "1",
		resistance = "-1",
		mobility = "0"
	}
end

