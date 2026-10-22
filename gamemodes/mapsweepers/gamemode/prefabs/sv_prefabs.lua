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

-- // Prefabs {{{
	jcms.prefabs = {} --Filled by types files

	function jcms.prefab_Check(type, area)
		return jcms.prefabs[ type ].check(area)
	end

	function jcms.prefab_ForceStamp(type, area, bonusData)
		return jcms.prefabs[ type ].stamp(area, bonusData)
	end

	function jcms.prefab_TryStamp(type, area)
		local can, bonusData = jcms.prefab_Check(type, area)

		if can then
			local ent = jcms.prefab_ForceStamp(type, area, bonusData)
			return true, ent
		else
			return false
		end
	end

	function jcms.prefab_GetNaturalTypes()
		local t = {}

		for name, data in pairs(jcms.prefabs) do
			if data.natural then
				table.insert(t, name)
			end
		end

		return t
	end

	function jcms.prefab_GetNaturalTypesWithWeights()
		local t = {}

		for name, data in pairs(jcms.prefabs) do
			if data.natural then
				t[name] = data.weight or 1.0
			end
		end

		return t
	end
	
	function jcms.prefab_GetFactionTypesWithWeights(faction)
		local t = {}

		for name, data in pairs(jcms.prefabs) do
			if data.faction == faction then
				t[name] = data.weight or 1.0
			end
		end

		return t
	end

	function jcms.prefab_GetWallSpotsFromArea(area, elevation, injectionDistance, subdivisionByUnits, conicDivergence, conicSubdivision)
		local wallspots = {}
		local normals = {}

		local center = area:GetCenter()
		center.z = center.z + elevation

		injectionDistance = injectionDistance or 16
		subdivisionByUnits = subdivisionByUnits or 128
		conicDivergence, conicSubdivision = conicDivergence, conicSubdivision or 2

		local xSpan, ySpan = area:GetSizeX(), area:GetSizeY()
		local xSteps, ySteps = math.max(1, math.floor(xSpan / subdivisionByUnits)), math.max(1, math.floor(ySpan / subdivisionByUnits))

		for x = 1, xSteps do
			for sign = -1, 1, 2 do
				local fromPos = center + Vector(math.Remap(x, 0, xSteps + 1, -xSpan/2, xSpan/2), 0, 0)
				local targetPos = fromPos + Vector(0, sign*(ySpan/2 + injectionDistance), 0)

				local s, pos, normal = jcms.prefab_CheckConicWallSpot(fromPos, targetPos, conicDivergence, conicSubdivision)

				if s then
					table.insert(wallspots, pos)
					table.insert(normals, normal)
				end
			end
		end

		for y = 1, ySteps do
			for sign = -1, 1, 2 do
				local fromPos = center + Vector(0, math.Remap(y, 0, ySteps + 1, -ySpan/2, ySpan/2), 0)
				local targetPos = fromPos + Vector(sign*(xSpan/2 + injectionDistance), 0, 0)

				local s, pos, normal = jcms.prefab_CheckConicWallSpot(fromPos, targetPos, conicDivergence, conicSubdivision)

				if s then
					table.insert(wallspots, pos)
					table.insert(normals, normal)
				end
			end
		end
		
		return wallspots, normals
	end

	function jcms.prefab_CheckConicWallSpot(fromPos, targetPos, divergence, subdivision)
		local tr_Main = util.TraceLine {
			start = fromPos,
			endpos = targetPos
		}

		if not tr_Main.HitWorld then return false end
		if bit.band( tr_Main.SurfaceFlags, SURF_TRANS ) > 0 then return false end
		local normal = tr_Main.HitNormal
		
		local zThreshold = 0.2 -- walls cant be this tilted
		if normal.z > zThreshold or normal.z < -zThreshold then return false end
		
		local normalAngle = normal:Angle()
		local right, up = normalAngle:Right(), normalAngle:Up()

		local angleThreshold = 1.25
		divergence = divergence or 48
		subdivision = subdivision or 3

		for i = 1, subdivision do
			local dist = divergence / subdivision * i

			for j = 1, 2 do
				local tr_Adj = util.TraceLine {
					start = fromPos,
					endpos = targetPos + (j == 1 and right or up)*dist
				}
				
				if not tr_Adj.HitWorld then return false end
				if bit.band( tr_Adj.SurfaceFlags, SURF_TRANS ) > 0 then return false end
				if not normalAngle:IsEqualTol( tr_Adj.HitNormal:Angle(), angleThreshold ) then return false end
			end
		end

		return true, tr_Main.HitPos, tr_Main.HitNormal
	end

	function jcms.prefab_CalcSideVisibilities(area)
		local centre = area:GetCenter()

		local sideVisCounts = {0,0,0,0}
		local areas = area:GetVisibleAreas()
		for i, otherArea in ipairs(areas) do 
			if otherArea == area then continue end
			if not jcms.mapgen_ValidArea(otherArea) then continue end

			--Get the side the area's on, using closest instead of centre because large areas might have heavily offset centres
			local toTarget = area:ComputeDirection(otherArea:GetClosestPointOnArea(centre))

			sideVisCounts[toTarget+1] = sideVisCounts[toTarget+1] + 1
		end

		return sideVisCounts
	end

	function jcms.prefab_CalcOverlooking(area, rearEdge)
		--Get the side with the most visible areas, and give us an angle / pos facing that way
		--rearEdge = get the back (wall) instead of the front (edge). used for floor-turrets (default behv is used for emplacement prefab)
		local sideVisCounts = jcms.prefab_CalcSideVisibilities(area)

		local highestSide
		local highestCount = -1
		for side, count in ipairs(sideVisCounts) do 
			if count > highestCount then
				highestSide = side 
				highestCount = count
			end
		end
		
		local edgePos = jcms.mapgen_GetAreaEdgePos(area, highestSide -1)
		local angle = (edgePos - area:GetCenter()):Angle()

		if rearEdge then
			local edge = (highestSide + 1)%4 --+2 but we're excluding the -1
			edgePos = jcms.mapgen_GetAreaEdgePos(area, edge)
		end

		return angle, edgePos 
	end
-- // }}}
