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


prefabs.combine_floorturrets = {
	faction = "combine",
	weight = 1,
	onlyMainZone = true,

	check = function(area)
		if not jcms.mapgen_ValidArea(area) then return false end
		if area:GetSizeX() < 30 or area:GetSizeY() < 30 then return false end

		if not jcms.mapgen_AreaFlat(area) then 
			return false 
		end

		return true
	end,

	areaWeight = function(area)
		local centre = area:GetCenter() 
		local indoorTrace = util.TraceLine({
			start = centre,
			endpos = centre + Vector(0,0,32768),
			mask = MASK_SOLID_BRUSHONLY
		})

		local weight = indoorTrace.HitSky and 0.01 or 1 --Prefer indoors / hidden
		weight = weight * (#area:GetAdjacentAreas() <= 2 and 1 or 0.25)
		return weight  --* math.max(#area:GetVisibleAreas(), 1) / #area:GetAdjacentAreas() --Prefer Corners with high visible area-count.
	end,

	stamp = function(area, data)
		local ang, pos = jcms.prefab_CalcOverlooking(area, true)

		local ent = ents.Create("npc_turret_floor")
		if not IsValid(ent) then return end

		ent:SetAngles(ang)
		ent:SetPos(pos + Vector(0,0,5) + ang:Forward() * 30)
		
		ent:Spawn()
		ent:Fire("Disable")

		ent:Fire( "AddOutput", "OnTipped !self:SelfDestruct:0:1" )

		local timerName = "jcms_"..tostring(ent).."beep"
		local function ping()
			if not IsValid(ent) then
				timer.Remove(timerName)
				return
			end
	
			ent:EmitSound("NPC_FloorTurret.Ping")
		end

		timer.Create(timerName, 2, 10, ping) --20s

		timer.Simple(20, function()
			timer.Create(timerName, 1, 4, ping) --24s
		end)

		timer.Simple(24, function()
			timer.Create(timerName, 0.25, 8, ping) --26s
		end)

		timer.Simple(26, function()
			if not IsValid(ent) then return end
			ent:EmitSound("NPC_FloorTurret.Deploy")
			ent:Fire("Enable")
		end)

		return ent
	end
}

--[[
prefabs.combine_shieldwall = {
	
	natural = true, --TODO: Remove
	weight = 0.12,

	check = function(area)
		
	end,

	stamp = function(area, data)
		--models/props_combine/combine_fence01a.mdl --left
		--models/props_combine/combine_fence01b.mdl --right

		--models/props_combine/combine_interface001a.mdl --Terminal
		--use skin 2

		--outland_10.shieldwall_on
		--outland_10.shieldwall_off

		--combine.sheild_loop
		--combine.sheild_touch
	end	
}
--]]