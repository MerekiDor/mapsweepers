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

local prefabs = jcms.prefabs


prefabs.zombie_barnacles = {
	faction = "zombie",
	weight = 1,
	onlyMainZone = true,

	check = function(area)
		local centre = area:GetCenter()

		local tr = util.TraceLine({
			start = centre,
			endpos = centre + Vector(0,0,1000)
		})

		return tr.Hit and tr.HitWorld and not tr.HitSky and math.acos(tr.HitNormal:Dot(-jcms.vectorUp)) < math.pi/4
	end,

	areaWeight = function(area) 
		return 1 / #area:GetAdjacentAreas() --Prefer Chokepoints
	end,

	stamp = function(area, data)
		local mainBarnacle = jcms.npc_Spawn("zombie_barnacle", area:GetCenter())

		--Spawn up to 2 additional barnacles for a total of 3
		local upV = Vector(0,0,1000)
		for i=1, 2 do 
			local pos = area:GetRandomPoint()

			local tr = util.TraceLine({
				start = pos,
				endpos = pos + upV
			})

			--Extra hitworld check so that we don't spawn on other barnacles.
			if tr.Hit and  tr.HitWorld and not tr.HitSky and math.acos(tr.HitNormal:Dot(-jcms.vectorUp)) < math.pi/4 then 
				jcms.npc_Spawn("zombie_barnacle", pos)
			end
		end


		return mainBarnacle
	end
}
