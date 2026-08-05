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

-- Used as reference.
-- // Unrestricted {{{
	jcms.MAPGEN_CONSTRUCT_AREA = 59402361
	jcms.MAPGEN_CONSTRUCT_DENSITY = 1.157295952082

	jcms.MAPGEN_CONSTRUCT_AREART = 322817.33914096
	jcms.MAPGEN_CONSTRUCT_DENSITYRT = 34.8672226934

	jcms.MAPGEN_CONSTRUCT_AREASPAN = 82411875
-- // }}}

-- // Restricted {{{
	jcms.MAPGEN_CONSTRUCT_AREA_RESTRICTED = 59294861
	jcms.MAPGEN_CONSTRUCT_DENSITY_RESTRICTED = 0.7195
	
	jcms.MAPGEN_CONSTRUCT_AREART_RESTRICTED = 106770
	jcms.MAPGEN_CONSTRUCT_DENSITYRT_RESTRICTED = 11.7614

	jcms.MAPGEN_CONSTRUCT_AREASPAN_UNRESTRICTED = 85719375
-- // }}}

jcms.MAPGEN_CONSTRUCT_AVGAREASIZE = 345.53675117538
jcms.MAPGEN_CONSTRUCT_VOLUME = 359613
jcms.MAPGEN_CONSTRUCT_DIAMETER = math.sqrt(82411875)

-- // A* {{{

	function jcms.mapgen_Navigate(fromArea, toArea, cond)
		-- Rewritten from https://wiki.facepunch.com/gmod/Simple_Pathfinding

		if not (IsValid(fromArea) and IsValid(toArea)) then return false end
		if fromArea == toArea then return true, { fromArea } end

		fromArea:ClearSearchLists()
		fromArea:AddToOpenList()
		fromArea:SetCostSoFar(0)

		local camefrom = {}
		
		local function unwind()
			local current = toArea
			local total_path = { current }

			current = current:GetID()
			while camefrom[current] do
				current = camefrom[current]
				table.insert(total_path, navmesh.GetNavAreaByID(current))
			end

			return total_path
		end

		local function estimate(a, b)
			return a:GetCenter():Distance(b:GetCenter())
		end

		while not fromArea:IsOpenListEmpty() do
			local last = fromArea:PopOpenList()

			if last == toArea then
				return true, unwind()
			else
				last:AddToClosedList()

				local adjAreas = last:GetAdjacentAreas()
				
				for i, adj in ipairs(adjAreas) do
					if adj:IsDamaging() or adj:IsUnderwater() then continue end
					
					local newcost = last:GetCostSoFar() + estimate(last, adj)
					
					if cond and not cond(last, adj, newcost) then
						continue
					end
					
					if ( adj:IsOpen() or adj:IsClosed() ) and ( adj:GetCostSoFar() <= newcost ) then
						continue
					else
						adj:SetCostSoFar(newcost)
						adj:SetTotalCost(newcost + estimate(adj, toArea))

						if adj:IsOpen() then
							adj:UpdateOnOpenList()
						else
							adj:AddToOpenList()
						end

						camefrom[ adj:GetID() ] = last:GetID()
					end
				end
			end
		end

		return false
	end

-- // }}}

-- // Util {{{
	local JCMS_MASK_SOLIDNOCLIPS = bit.bor(CONTENTS_SOLID, CONTENTS_WINDOW, CONTENTS_GRATE, CONTENTS_OPAQUE, CONTENTS_MOVEABLE)
	--Note: CONTENTS_DETAIL includes playerclips. Perhaps detail includes anything that doesn't split visleaves?
	function jcms.mapgen_ValidArea(area)
		--Are we a trigger_hurt or underwater
		if jcms.mapdata and not(jcms.mapdata.validAreaDict[area] == nil) then return jcms.mapdata.validAreaDict[area] end --Optimisation, going to be using this func outside mapgen in future.
		if area:IsDamaging() or area:IsUnderwater() then return false end

		--Are we somehow inside a solid fucking block (conflux has this issue)
		local areaContents = util.PointContents( area:GetCenter() )
		local areaContentsAll = areaContents
		for i=1, 4, 1 do 
			local contents = util.PointContents( area:GetCorner(i-1) )
			areaContents = bit.band( contents, areaContents )
			areaContentsAll = bit.bor(contents, areaContentsAll)
		end

		--if ALL corners, and our centre are solid. Normal sane maps like construct have slanted navareas on small ledges, so we have to deal with that.
		if bit.band(areaContents, CONTENTS_SOLID) ~= 0 then 
			return false 
		end
		--If any of our points are touching a playerclip don't use it. Not reliable at all, but hopefully I'll fix that in the future.
		if bit.band(areaContentsAll, CONTENTS_PLAYERCLIP) ~= 0 then 
			return false
		end

		--Make sure we aren't on nodraw, because we can't reliably check if we're under a displacement due to static props.
		--Will also filter areas of the map that we're not meant to reach I suppose.
		local centre = area:GetCenter() + Vector(0,0,5)
		local floorCheck = util.TraceLine({
			start = centre,
			endpos = centre - Vector(0,0,10),
			mask = JCMS_MASK_SOLIDNOCLIPS
		})

		if floorCheck.HitNoDraw then
			return false
		end

		--Are we under a displacement? Traces pass through the back-side but not the top.
		local tr = util.TraceLine({
			start = centre,
			endpos = centre + Vector(0,0,32000), 
			mask = JCMS_MASK_SOLIDNOCLIPS
		})

		if tr.HitNoDraw then --We've hit the bottom of a nodraw brush, and are probably under a road (or some other brush poking through a displacement)
			return false
		end
		
		local backTrace = util.TraceLine({
			start = tr.HitPos,
			endpos = centre,
			mask = JCMS_MASK_SOLIDNOCLIPS
		})
		
		if centre:DistToSqr(backTrace.HitPos) > 5^2 then
			--todo: This stil fails for some valid navAreas. 
			--I am not sure whether this is floating point inaccuracy, or the raised centre genuinely still being underneath.
			return false 
		end

		if jcms.isAreaInClip(area) then --Potentially one of the most expensive checks, so we do this last.
			return false
		end

		return true 
	end

	function jcms.mapgen_CentreWeights( areasToCheck )
		local midAreaWeights = {}
		--local avgDepth = jcms.mapdata.areaDepthAvg
		for i, area in ipairs(areasToCheck or navmesh.GetAllNavAreas()) do
			--local depth = jcms.mapdata.areaDepths[area]
			--if depth and depth > avgDepth then
				local score = 1 / math.max(1, jcms.mapgen_GetDistanceFromCenterRelative( area:GetCenter() ))
				midAreaWeights[ area ] = score
			--end
		end
		return midAreaWeights
	end

	function jcms.mapgen_BorderWeights( areasToCheck )
		local borderAreaWeights = {}
		--local avgDepth = jcms.mapdata.areaDepthAvg
		for i, area in ipairs(areasToCheck or navmesh.GetAllNavAreas()) do 
			--local depth = jcms.mapdata.areaDepths[area]
			--if depth and depth > avgDepth then
				local score = jcms.mapgen_GetDistanceFromCenterRelative( area:GetCenter() )
				borderAreaWeights[ area ] = score
			--end
		end
		return borderAreaWeights
	end

	function jcms.mapgen_TryReadNodeData()
		ainReader.readNodeData()

		if not ainReader.nodePositions then return end 
		
		local md = jcms.mapdata
		md.nodeAreas = {}
		for i, nodePos in ipairs(ainReader.nodePositions) do 
			md.nodeAreas[nodePos] = jcms.mapgen_NearestArea(nodePos)
		end
	end

	function jcms.mapgen_Wait( progress )
		if game.SinglePlayer() then return end
		game.GetWorld():SetNWFloat( "jcms_mapgen_progress", progress )
		if coroutine.running() then coroutine.yield() end
	end

	function jcms.isAreaInClip(area)
		local areaPoints = {}
		for i=1, 4, 1 do
			table.insert(areaPoints, area:GetCorner(i-1))
		end

		for i, brush in pairs(bspReader.brushes) do
			--Only care about playerclips
			if not bit.band(bspReader.brushContents[i], CONTENTS_PLAYERCLIP) then continue end

			--Copy of our area table, we're going to modify it.
			local areaCopy = {}
			for i, v in ipairs(areaPoints) do 
				areaCopy[i] = Vector(v)
			end

			--Are our points inside the planes?
			local rejected = false
			for i, brushside in ipairs(brush) do
				local planeNormal = bspReader.planeNormals[brushside.planeNum+1]
				local planeDistance = bspReader.planeDistances[brushside.planeNum+1]
				local planePoint = planeNormal * planeDistance --Used for plane-intersection

				local inside = {}
				local insideCount = 0
				for i, vec in ipairs(areaCopy) do
					if vec:Dot(planeNormal) - planeDistance < 0 then 
						inside[vec] = true
						insideCount = insideCount + 1
					else
						inside[vec] = false
					end
				end

				if insideCount == 0 then --We're entirely outside of this plane, so we're outside the brush.
					rejected = true
					break
				end

				--[[
					TODO: It may be possible to compress the following loops into a single one (which would be more performant).
					I've done it in a way that's easier to think about / test for the moment, though.
				--]]
				for i=#areaCopy, 1, -1 do --Cull nodes with only outside neighbours.
					local vec = areaCopy[i]
					if inside[vec] then continue end

					local neighbour1 = areaCopy[ (i-1)%#areaCopy ]
					local neighbour2 = areaCopy[ (i+1)%#areaCopy ]

					if not inside[neighbour1] and not inside[neighbour2] then
						table.remove(areaCopy, i)
					end
				end

				local newAreaCopy = {}
				for i, vec in ipairs(areaCopy) do
					if inside[vec] then
						table.insert(newAreaCopy, vec)
						continue
					end

					local neighbour1 = areaCopy[ (i-1)%#areaCopy ]
					local neighbour2 = areaCopy[ (i+1)%#areaCopy ]

					if inside[neighbour1] and inside[neighbour2] then --Both neighbours are inside, split us.
						local toNeighbour1 = neighbour1 - vec
						local toNeighbour2 = neighbour2 - vec

						local intersection1 = util.IntersectRayWithPlane(vec, toNeighbour1, planePoint, planeNormal) --yay! I get to be lazy. Thank you facepunch!
						local intersection2 = util.IntersectRayWithPlane(vec, toNeighbour2, planePoint, planeNormal)

						table.insert(newAreaCopy, intersection1)
						table.insert(newAreaCopy, intersection2)
					elseif inside[neighbour1] or inside[neighbour2] then --One is inside, this condition is technically redundant as we already know this, but this is more readable.
						local inNeighbour = inside[neighbour1] and neighbour1 or neighbour2

						local toInNeighbour = inNeighbour - vec
						local intersection = util.IntersectRayWithPlane(vec, toInNeighbour, planePoint, planeNormal)
						table.insert(newAreaCopy, intersection)
					end
				end
				areaCopy = newAreaCopy
			end

			if not rejected then --If we're still inside the brush at the end, this area intersects a playerclip (return). Otherwise keep going.
				return true
			end
		end
		return false
	end

-- // }}

-- // Permanent data {{{

	jcms.mapdata = jcms.mapdata or { analyzed = false, vaild = false }

	local upVec = Vector(0,0,32768)
	function jcms.mapgen_AnalyzeMap(dontAddToValidList)
		local analyseStart = SysTime()

		local md = jcms.mapdata
		local nav = navmesh.GetAllNavAreas()
		table.Shuffle(nav)
		
		md.areaCountUnrestricted = #nav
		md.areaCount = 0
		md.analyzed = true
		
		md.areaTotal = 0 -- Total area of all valid areas.
		md.areaTotalRT = 0 --Ditto, but the sum of roots of areas
		md.areaSpan = 0 -- Area (width*height) from top-left-most to bottom-right-most corner of valid portion of the map
		md.density = 0 -- Total/span.
		
		md.areaTotalUnrestricted = 0 -- Total area of ALL areas. Even invalid ones.
		md.areaTotalUnrestrictedRT = 0 --Ditto, but sum of roots of areas
		md.areaSpanUnrestricted = 0 -- Total navmesh span including invalid areas.
		md.densityUnrestricted = 0 -- Unr.total / unr.span

		md.avgAreaSizeRT = 0 --The average area of a navmesh area. 
		md.avgAreaSizeUnrestrictedRT = 0 --Ditto, but even invalid areas.
		
		md.vis = { avgAccumulator = 0 }
		md.visUnrestricted = { avgAccumulator = 0 }

		md.areaAreas = {}
		md.areaAreasUnrestricted = {}

		md.validAreas = {} --Table of all valid areas
		md.validAreaDict = {} --Dict for valid areas
		
		md.usefulness = 0 -- Tells us how much of the navmesh is actually valid. 0 = none, 1 = all of it.

		md.areaSkyVis = {}
		
		md.valid = md.areaCountUnrestricted > 1
		if md.valid then
			local depthAreaCounter = 0
			md.areaDepths = {}
			md.areaDepthAvg = 0
			md.areaDepthMax = 0
			
			md.sizedAreas = {
				huge = {},
				big = {},
				medium = {},
				small = {},
				tiny = {}
			}
			
			local minAreas = { tiny = 100^2, small = 250^2, medium = 450^2, big = 800^2, huge = 1250^2 }
			local allowedRatios = { tiny = 1.25, small = 1.5, medium = 1.8, big = 2.5, huge = 5 }
			local checkOrder = { "huge", "big", "medium", "small", "tiny" }
			local minDim = 50
			
			local xMin, yMin, xMax, yMax
			local xMinU, yMinU, xMaxU, yMaxU
			
			local areaZones = {}
		
			local function replacezones(from, to)
				for area, zone in pairs(areaZones) do
					if zone == from then
						areaZones[ area ] = to
					end
				end
			end
			
			for i, area in ipairs(nav) do
				local width, height = area:GetSizeX(), area:GetSizeY()
				md.areaAreasUnrestricted[area] = width*height
				md.areaTotalUnrestricted = md.areaTotalUnrestricted + md.areaAreasUnrestricted[area]
				md.areaTotalUnrestrictedRT = md.areaTotalUnrestrictedRT + math.sqrt(md.areaAreasUnrestricted[area])
				md.avgAreaSizeUnrestrictedRT = md.avgAreaSizeUnrestrictedRT + math.sqrt(md.areaAreasUnrestricted[area])
				
				local onborder = false
				for i=0, 3 do
					if area:GetAdjacentCountAtSide(i) <= 0 then
						onborder = true
						break
					end
				end
				
				if onborder then
					md.areaDepths[ area ] = 0
					depthAreaCounter = depthAreaCounter + 1
				end
				
				
				local centre = area:GetCenter() 
				local skyTrace = util.TraceLine({
					start = centre,
					endpos = centre + upVec,
					mask = MASK_SOLID_BRUSHONLY
				})
				md.areaSkyVis[area] = skyTrace.hitSky

				local v1, v2 = area:GetCorner(0), area:GetCorner(2)
				xMinU = math.min(xMinU or v1.x, v1.x, v2.x)
				xMaxU = math.max(xMaxU or v1.x, v1.x, v2.x)
				yMinU = math.min(yMinU or v1.y, v1.y, v2.y)
				yMaxU = math.max(yMaxU or v1.y, v1.y, v2.y)
				
				local areaVis = #area:GetVisibleAreas()
				md.visUnrestricted.min = math.min(md.visUnrestricted.min or areaVis, areaVis)
				md.visUnrestricted.max = math.max(md.visUnrestricted.max or areaVis, areaVis)
				md.visUnrestricted.avgAccumulator = md.visUnrestricted.avgAccumulator + areaVis
				
				md.validAreaDict[area] = jcms.mapgen_ValidArea(area)
				if not md.validAreaDict[area] then continue end
				table.insert(md.validAreas, area)
				
				local adj = area:GetAdjacentAreas()
				for j=#adj, 1, -1 do
					if not adj[j]:IsConnected(area) then
						table.remove(adj, j)
					end
				end
				
				local zoneAround = nil
				for j, oarea in ipairs(adj) do
					if not jcms.mapgen_ValidArea(oarea) then continue end
					
					if areaZones[oarea] then
						zoneAround = areaZones[oarea]
						break
					end
				end
				
				if zoneAround then
					areaZones[area] = zoneAround
					for j, oarea in ipairs(adj) do
						if not jcms.mapgen_ValidArea(oarea) then continue end
						if areaZones[oarea] and areaZones[oarea] ~= zoneAround then
							replacezones(areaZones[oarea], zoneAround)
						else
							areaZones[oarea] = zoneAround
						end
					end
				else
					local inZone = areaZones[area] or i
					
					for j, oarea in ipairs(adj) do
						if not jcms.mapgen_ValidArea(oarea) then continue end
						areaZones[oarea] = inZone
					end
				end
				
				if width < minDim or height < minDim then continue end
				
				local ratio = math.max(width, height) / math.min(width, height)
				for j, mag in ipairs(checkOrder) do
					if ( ratio < allowedRatios[mag] ) and (width*height >= minAreas[mag]) then
						md.areaAreas[area] = md.areaAreasUnrestricted[area]
						md.areaTotal = md.areaTotal + md.areaAreas[area]
						md.areaTotalRT = md.areaTotalRT + math.sqrt(md.areaAreas[area])
						md.avgAreaSizeRT = md.avgAreaSizeRT + math.sqrt(md.areaAreasUnrestricted[area])
						
						xMin = math.min(xMin or v1.x, v1.x, v2.x)
						xMax = math.max(xMax or v1.x, v1.x, v2.x)
						yMin = math.min(yMin or v1.y, v1.y, v2.y)
						yMax = math.max(yMax or v1.y, v1.y, v2.y)
						
						md.areaCount = md.areaCount + 1
						md.vis.min = math.min(md.vis.min or areaVis, areaVis)
						md.vis.max = math.max(md.vis.max or areaVis, areaVis)
						md.vis.avgAccumulator = md.vis.avgAccumulator + areaVis

						table.insert(md.sizedAreas[mag], area)
						break
					end
				end
			end
			
			local lastDepthWorkedWith = 0
			local depthAccumulator = 0
			repeat
				local foundOne = false
				
				for area, depth in pairs(md.areaDepths) do
					if depth == lastDepthWorkedWith then
						foundOne = true
						for i, oarea in ipairs( area:GetAdjacentAreas() ) do
							if not md.areaDepths[ oarea ] then
								depthAreaCounter = depthAreaCounter + 1
								depthAccumulator = depthAccumulator + (depth + 1)
								md.areaDepths[ oarea ] = depth + 1
							end
						end
					end
				end
				
				md.areaDepthMax = lastDepthWorkedWith
				if foundOne then
					lastDepthWorkedWith = lastDepthWorkedWith + 1
				else
					break
				end
			until (depthAreaCounter >= md.areaCountUnrestricted or lastDepthWorkedWith > 9999)
			
			if lastDepthWorkedWith > 9999 then
				print("area depth overflow... somehow? dev stats: ", depthAreaCounter, md.areaCountUnrestricted)
			end
			
			md.areaDepthAvg = depthAccumulator / depthAreaCounter
			
			md.vis.avg = md.vis.avgAccumulator / md.areaCount
			md.vis.avgAccumulator = nil
			
			md.visUnrestricted.avg = md.visUnrestricted.avgAccumulator / md.areaCount
			md.visUnrestricted.avgAccumulator = nil
			
			md.areaSpan = (xMax - xMin)*(yMax - yMin)
			md.areaSpanUnrestricted = (xMaxU - xMinU)*(yMaxU - yMinU)

			md.areaSpanRT = math.sqrt(md.areaSpan)
			md.areaSpanUnrestrictedRT = math.sqrt(md.areaSpanUnrestricted)
			
			md.density = md.areaTotal / md.areaSpan
			md.densityUnrestricted = md.areaTotalUnrestricted / md.areaSpanUnrestricted
			md.usefulness = md.areaTotal / md.areaTotalUnrestricted

			md.densityRT = md.areaTotalRT / md.areaSpanRT
			md.densityUnrestrictedRT = md.areaTotalUnrestrictedRT / md.areaSpanUnrestrictedRT

			md.avgAreaSizeRT = md.avgAreaSizeRT / md.areaCount
			md.avgAreaSizeUnrestrictedRT = md.avgAreaSizeUnrestrictedRT / #nav
			
			md.navmeshSpan = { xMin, yMin, xMax, yMax }
			md.navmeshSpanUnrestricted = { xMinU, yMinU, xMaxU, yMaxU }
			
			local zoneList = {}
			local translation = {}
			local zindex = 0
			
			for area, zone in pairs(areaZones) do
				if not jcms.mapgen_ValidArea(area) then continue end

				if not translation[zone] then
					zindex = zindex + 1
					translation[zone] = zindex
				end
				
				local trzone = translation[zone]
				if not zoneList[trzone] then
					zoneList[trzone] = { area }
				else
					table.insert(zoneList[trzone], area)
				end
			end
			
			table.sort(zoneList, function(first, last)
				return #first > #last
			end)
			
			local zoneDict = {}
			local zoneAreaSizes = {}
			local largestId = -1
			local largestSize = 0 
		
			for zoneId, areas in ipairs(zoneList) do
				local totalArea = 0
				for j, area in ipairs(areas) do
					zoneDict[area] = zoneId
					totalArea = totalArea + area:GetSizeX() * area:GetSizeY()
				end
				zoneAreaSizes[zoneId] = totalArea
				if largestSize < totalArea then 
					largestId = zoneId
					largestSize = totalArea
				end
			end
			
			jcms.mapdata.zoneList = zoneList
			jcms.mapdata.zoneDict = zoneDict
			jcms.mapdata.zoneSizes = zoneAreaSizes
			jcms.mapdata.largestZone = largestId
		end

		md.volumeTotal = 0 --Total volume of all visleaves
		for i=1, #bspReader.leafMins, 1 do 
			if bspReader.leafClusterConnections[i-1] and not(bspReader.getVisLeafArea( i-1 ) == jcms.pathfinder.skyArea) then --Hacky check for if we're in the map.
				local mins, maxs = bspReader.getVisLeafBounds( i-1 )
				local minX, minY, minZ = mins:Unpack()
				local maxX, maxY, maxZ = maxs:Unpack()

				local vol = ( (maxX - minX) * (maxY - minY) * (maxZ - minZ) ) ^ (1/3)
				md.volumeTotal = md.volumeTotal + vol
			end
		end

		if not ainReader.nodePositions then 
			ainReader.readNodeData()
		end

		jcms.mapgen_TryReadNodeData()

		if md.areaCount <= 1 then
			md.valid = false
		end

		if (not dontAddToValidList) and (md.valid) and (not ai.GetNodeCount or ai.GetNodeCount() > 0) then --checks if the function exists bc I don't wanna boot up 32bit just to check if it's only on dev rn
			jcms.addValidMap(game.GetMap()) --might be more accurate to call this setValidMap?
		end

		print("[MapSweepers] Map analysed in: " .. tostring( math.Round(SysTime() - analyseStart, 3) ) .. " seconds")

		hook.Run("MapSweepers_MapAnalysisDone")

		collectgarbage("collect")
	end

	function jcms.mapgen_ExpandedAreaList(areas)
		local handledAreas = {}
		local expandedAreas = {}

		for i, area in ipairs(areas) do
			if not handledAreas[area] then
				handledAreas[area] = true
				table.insert(expandedAreas, area)

				local adjAreas = navmesh.Find(area:GetCenter(), (area:GetSizeX() + area:GetSizeY())/2 + 400, 300, 300)
				for j, adjArea in ipairs(adjAreas) do
					if not handledAreas[adjArea] then
						handledAreas[adjArea] = true
						table.insert(expandedAreas, adjArea)
					end
				end
			end
		end

		return expandedAreas
	end

	function jcms.mapgen_SubdivideAreasIntoVectors(areas, subdiv)
		local vectors = {}

		subdiv = math.max(tonumber(subdiv) or 2, 2)
		for i, area in ipairs(areas) do
			local xSubdivCount = math.ceil(area:GetSizeX() / subdiv)
			local ySubdivCount = math.ceil(area:GetSizeY() / subdiv)

			for x=1, xSubdivCount do
				for y=1, ySubdivCount do
					local v = area:GetCorner(0)
					v.x = xSubdivCount==1 and (v.x + area:GetSizeX()/2) or (v.x + subdiv * (x-1))
					v.y = ySubdivCount==1 and (v.y + area:GetSizeY()/2) or (v.y + subdiv * (y-1))
					v.z = area:GetZ(v)
					
					if bit.band(util.PointContents(v), CONTENTS_SOLID) == 0 then
						table.insert(vectors, v)
					end
				end
			end
		end

		return vectors
	end

	function jcms.mapgen_VectorGrid(areas, subdivisionSize, connectionDist)	
		local chunks, chunksize, getChunkId, getChunkTable, getAllNearbyNodes = jcms.util_ChunkFunctions(512)
		
		subdivisionSize = math.max( 1, tonumber(subdivisionSize) or 128 )
		connectionDist = math.max(1, tonumber(connectionDist) or subdivisionSize * 1.9)
		assert( connectionDist < subdivisionSize * 4, "[jcms.mapgen_VectorGrid] Connection distance is too high, your PC wouldn't like it." )

		local extremePoints = {}
		local subdiv = subdivisionSize
		local connectionDist2 = connectionDist * connectionDist
		for i, area in ipairs(areas) do
			local areaSizeX = area:GetSizeX()
			local areaSizeY = area:GetSizeY()

			local xSubdivCount = math.ceil(areaSizeX / subdiv)
			local ySubdivCount = math.ceil(areaSizeY / subdiv)

			for x=1, xSubdivCount do
				for y=1, ySubdivCount do
					local v = area:GetCorner(0)
					local vx, vy, vz = v:Unpack() --Messy optimisation here, we still use v.z because we need the new vec pos for it to be accurate.
					vx = xSubdivCount==1 and (vx + areaSizeX/2) or (vx + subdiv * (x-1))
					vy = ySubdivCount==1 and (vy + areaSizeY/2) or (vy + subdiv * (y-1))
					v:SetUnpacked(vx, vy, vz)
					v.z = area:GetZ(v)
					if bit.band(util.PointContents(v), CONTENTS_SOLID) == 0 then
						table.insert(getChunkTable(vx, vy, v.z), v)

						if (x==1 or x==xSubdivCount) and (y==1 or y==ySubdivCount) then
							extremePoints[v] = area
						end
					end
				end
			end
		end

		local tr_res = {}
		local tr_data = { 
			mask = MASK_PLAYERSOLID_BRUSHONLY, 
			output = tr_res
		}
		local vStart = Vector(0,0,0)
		local vEnd = Vector(0,0,0)

		local connections = {}
		for chunkId, chunk in pairs(chunks) do
			local n = chunk[1]
			if n then
				local nodes = getAllNearbyNodes(n.x, n.y, n.z)
				for i, pt in ipairs( nodes ) do
					for oi=1, i-1 do
						local opt = nodes[oi]
						local dist2 = opt:DistToSqr(pt)

						if dist2 >= (subdiv*subdiv - 16) then
							local ptx, pty, ptz = pt:Unpack()
							local optx, opty, optz = opt:Unpack()

							local zDiminishDist2 = (ptx - optx)^2 + (pty - opty)^2 + ((ptz - optz)*0.25)^2
							
							if zDiminishDist2 <= connectionDist2 then
								local shouldConnect = false
								if extremePoints[pt] and extremePoints[opt] and extremePoints[pt] ~= extremePoints[opt] and extremePoints[pt]:IsConnected(extremePoints[opt]) then
									shouldConnect = true
								else
									vStart:SetUnpacked( ptx, pty, ptz + subdiv/2 )
									vEnd:SetUnpacked( optx, opty, optz + subdiv )
									tr_data.start = vStart
									tr_data.endpos = vEnd
									util.TraceLine(tr_data)

									if not tr_res.Hit then
										shouldConnect = true
									end
								end

								if shouldConnect then
									if not connections[pt] then
										connections[pt] = { opt }
									else
										table.insert(connections[pt], opt)
									end

									if not connections[opt] then
										connections[opt] = { pt }
									else
										table.insert(connections[opt], pt)
									end
								end
							end
						end
					end
				end
			end
		end

		for chunkId, chunk in pairs(chunks) do
			if #chunk == 0 then
				chunks[chunkId] = nil
			end
		end

		--[[timer.Simple(1, function()
			for pt1,cs in pairs(connections) do
				for i, pt2 in ipairs(cs) do
					debugoverlay.Line(pt1, pt2, 1, ColorRand(), true)
				end
			end
		end)]]

		return connections, chunks
	end

	function jcms.mapgen_WallTraces(tr_count, tr_dist, tr_data)
		local outputTraces = {}

		for j = 1, tr_count do
			local ang = math.pi * 2 / tr_count * j
			local cos, sin = math.cos(ang), math.sin(ang)
			tr_data.endpos = Vector(tr_data.start.x + cos * tr_dist, tr_data.start.y + sin * tr_dist, tr_data.start.z)
			local tr = util.TraceHull(tr_data)
			table.insert(outputTraces, tr)
		end

		return outputTraces
	end

	function jcms.mapgen_VectorGridCosts_WallProximity(connections, chunks, traceDist, wallCostMultiplier, inverseCost)
		wallCostMultiplier = tonumber(wallCostMultiplier) or 1

		local costs = {}

		local tr_dist = tonumber(traceDist) or 100
		local tr_count = 8
		local tr_data = { 
			mins = Vector(-24, -24, -8), 
			maxs = Vector(24, 24, 8), 
			mask = MASK_PLAYERSOLID_BRUSHONLY
		}

		for chunkId, chunk in pairs(chunks) do
			for i, pt in ipairs(chunk) do
				local weight = 1
				local px, py, pz = pt:Unpack()
				tr_data.start = Vector( px, py, pz + 64 )

				for i, tr in ipairs(jcms.mapgen_WallTraces(tr_count, tr_dist, tr_data)) do 
					weight = math.min(weight, tr.Fraction)
				end

				costs[pt] = (inverseCost and (1 - weight) or weight) * wallCostMultiplier
			end
		end

		return costs
	end

	function jcms.mapgen_OptimiseVectorPath( vectorPath )
		if not(#vectorPath > 1) then return end

		local lineStart = #vectorPath
		local lineEnd = #vectorPath
		local currentDir = (vectorPath[#vectorPath] - vectorPath[#vectorPath-1]):GetNormalized()

		for i=#vectorPath, 1, -1 do 
			local vec1 = vectorPath[i]
			local vec2 = vectorPath[i-1]
			if not vec2 then continue end 

			local dirVec = vec1 - vec2
			dirVec:Normalize()

			if dirVec:IsEqualTol(currentDir, 0.025) then --approximately equal.
				lineEnd = i
			else
				for i=lineStart - 1, lineEnd, -1 do 
					table.remove(vectorPath, i)
				end

				currentDir = dirVec
				lineStart = i
			end
		end

	end

	function jcms.mapgen_GenPathAround(areas, traceDist, wallCostMultiplier)
		local connections, chunks = jcms.mapgen_VectorGrid(areas, math.Rand(0.0220, 0.0280) * 6000)
		local costs = jcms.mapgen_VectorGridCosts_WallProximity(connections, chunks, traceDist or 256, tonumber(wallCostMultiplier) or 15000, true)

		local bestPath = nil
		local bestPathLength = 0
		
		local minCost = math.huge
		local sumCost = 0
		local pointsCount = 0
		for pt in pairs(connections) do
			minCost = math.min( minCost, costs[pt] )
			sumCost = sumCost + costs[pt]
			pointsCount = pointsCount + 1
		end
		local avgCost = sumCost / pointsCount 

		local allPoints = {}
		for pt in pairs(connections) do
			if costs[ pt ] <= (minCost*5 + avgCost)/6 then
				table.insert(allPoints, pt)
			end 
		end

		local pathsTried = 0
		if #allPoints > 1 then

			for i, pt in ipairs(allPoints) do
				local oi
				repeat
					oi = math.random(1, #allPoints)
				until ( oi ~= i )
				local opt = allPoints[oi]

				local path = jcms.pathfinder.navigateVectorGrid(connections, costs, pt, opt)
				local pathLength = 0

				if path then
					for j=1, #path-1 do
						local v1, v2 = path[j], path[j+1]
						pathLength = pathLength + v1:Distance(v2)
					end
				end

				pathsTried = pathsTried + 1
				if pathLength > bestPathLength then
					bestPath = path
					bestPathLength = pathLength
				end

				local chance = 1-(2/(pathsTried+1))
				local rng = math.random()
				if bestPath and pathsTried >= math.min(#allPoints, 2) and rng<chance then
					break
				end
			end

			--[[timer.Simple(0.5, function()
				if bestPath then
					for j=1, #bestPath-1 do
						local v1, v2 = bestPath[j], bestPath[j+1]
						debugoverlay.Line(v1, v2, 5, HSVToColor(j/#bestPath*360, 0.8, 1), true)
					end
				end
			end)]]

			return bestPath, bestPathLength
		end
	end

	function jcms.mapgen_GenLongPath(areas, traceDist, wallCostMultiplier, fromVector)
		local connections, chunks = jcms.mapgen_VectorGrid(areas, math.Rand(0.0220, 0.0280) * 6000)
		local costs = jcms.mapgen_VectorGridCosts_WallProximity(connections, chunks, traceDist or 256, tonumber(wallCostMultiplier) or 15000, true)

		local bestPath = nil
		local bestPathLength = 0
		
		local minCost = math.huge
		local sumCost = 0
		local pointsCount = 0
		for pt in pairs(connections) do
			minCost = math.min( minCost, costs[pt] )
			sumCost = sumCost + costs[pt]
			pointsCount = pointsCount + 1
		end
		local avgCost = sumCost / pointsCount 

		local allPoints = {}
		for pt in pairs(connections) do
			if costs[ pt ] <= (minCost*5 + avgCost)/6 then
				table.insert(allPoints, pt)
			end 
		end

		if #allPoints > 1 then
			local closestPtDist2, closestPt = math.huge
			for i, pt in ipairs(allPoints) do
				local dist2 = pt:DistToSqr(fromVector)
				if dist2 < closestPtDist2 then
					closestPtDist2 = dist2
					closestPt = pt
				end
			end

			if closestPt then
				local farawayPoints = {}
				local maxDist2 = 0
				for i, pt in ipairs(allPoints) do
					local dist2 = closestPt:DistToSqr(pt)
					if dist2 > maxDist2 then
						maxDist2 = dist2
					end
				end

				local halfwayDist2 = (math.sqrt(maxDist2)*0.67)^2
				for i, pt in ipairs(allPoints) do
					if closestPt:DistToSqr(pt) >= halfwayDist2 then
						table.insert(farawayPoints, pt)
					end
				end

				table.Shuffle(farawayPoints)
				for i, pt in ipairs(farawayPoints) do
					local path = jcms.pathfinder.navigateVectorGrid(connections, costs, closestPt, pt)
					local pathLength = 0

					if path then
						for j=1, #path-1 do
							local v1, v2 = path[j], path[j+1]
							pathLength = pathLength + v1:Distance(v2)
						end

						timer.Simple(0.5, function()
							if path then
								for j=1, #path-1 do
									local v1, v2 = path[j], path[j+1]
									debugoverlay.Line(v1, v2, 5, HSVToColor(j/#path*360, 0.8, 1), true)
								end
							end
						end)

						return path, pathLength
					end
				end
			end
		end
	end

	function jcms.mapgen_PickBestFacingDirection(fromVector, trace_distance, trace_filter, trace_mask)
		local n = 24
		local fx, fy, fz = fromVector:Unpack()

		local traceResult = {}
		local traceData = {
			mask = trace_mask,
			filter = trace_filter,
			start = fromVector,
			endpos = Vector(0, 0, 0),
			output = traceResult
		}

		trace_distance = math.max(tonumber(trace_distance) or 256, 0)
		local results = {}
		local max = 0
		for i=1, n do
			local a = math.pi*2/n*i
			local cos, sin = math.cos(a), math.sin(a)
			traceData.endpos:SetUnpacked(fx + cos*trace_distance, fy + sin*trace_distance, fz)
			util.TraceLine(traceData)
			results[i] = traceResult.StartSolid and 0 or traceResult.Fraction
			max = math.max(results[i], max)
		end
		
		if max > 0 then
			local bests = {}
			for i=1, n do
				if results[i] >= max then
					table.insert(bests, i)
				end
			end

			local besti = bests[math.random(1, #bests)] or 0
			return true, Angle(0, 360/n*besti, 0)
		else
			return false, Angle(0, math.random()*360, 0)
		end
	end
	
	function jcms.mapgen_DemonstrateList(list)
		if type(list) == "table" then
			timer.Simple(0.5, function()
				local u = Vector(0, 0, 4)
				local n = #list
				for i, area in ipairs(list) do
					local col = HSVToColor(i/n*360, 0.75, 0.9)
					debugoverlay.Triangle(area:GetCorner(2)+u, area:GetCorner(1)+u, area:GetCorner(0)+u, 3, col)
					debugoverlay.Triangle(area:GetCorner(2)+u, area:GetCorner(0)+u, area:GetCorner(3)+u, 3, col)
				end
			end)
		end
	end

	function jcms.mapgen_DemonstrateWeighedList(list)
		if type(list) == "table" then
			timer.Simple(0.5, function()
				local u = Vector(0, 0, 4)
				local maxWeight = 0
				for area, weight in pairs(list) do
					maxWeight = math.max(maxWeight, weight)
				end

				for area, weight in pairs(list) do
					local col = HSVToColor(weight/maxWeight*360, 1, weight>maxWeight/2 and 1 or 0.5)
					debugoverlay.Triangle(area:GetCorner(2)+u, area:GetCorner(1)+u, area:GetCorner(0)+u, 3, col)
					debugoverlay.Triangle(area:GetCorner(2)+u, area:GetCorner(0)+u, area:GetCorner(3)+u, 3, col)
				end
			end)
		end
	end

	function jcms.mapgen_DemonstrateNavmeshDepths()
		timer.Simple(0.5, function()
			local u = Vector(0, 0, 4)
			local maxDepth = jcms.mapdata.areaDepthMax
			local avgDepth = jcms.mapdata.areaDepthAvg
			for area, depth in pairs(jcms.mapdata.areaDepths) do
				local col = HSVToColor(depth/maxDepth*240, 0.75, depth > avgDepth and 1 or 0.5)
				debugoverlay.Triangle(area:GetCorner(2)+u, area:GetCorner(1)+u, area:GetCorner(0)+u, 3, col)
				debugoverlay.Triangle(area:GetCorner(2)+u, area:GetCorner(0)+u, area:GetCorner(3)+u, 3, col)
			end
		end)
	end
	
	function jcms.mapgen_DemonstrateNavmeshVis()
		timer.Simple(0.5, function()
			local u = Vector(0, 0, 4)
			local minVis, maxVis = jcms.mapdata.visUnrestricted.min, jcms.mapdata.visUnrestricted.max
			
			for i, area in ipairs(navmesh.GetAllNavAreas()) do
				local col = HSVToColor(math.Remap(#area:GetVisibleAreas(), minVis, maxVis, 0, 240), 0.7, 1)
				debugoverlay.Triangle(area:GetCorner(2)+u, area:GetCorner(1)+u, area:GetCorner(0)+u, 3, col)
				debugoverlay.Triangle(area:GetCorner(2)+u, area:GetCorner(0)+u, area:GetCorner(3)+u, 3, col)
			end
		end)
	end
	
	function jcms.mapgen_DemonstrateNavmeshDistFromCenter()
		timer.Simple(0.5, function()
			local u = Vector(0, 0, 4)
			local minX, minY, maxX, maxY = jcms.mapgen_GetNavmeshSpan()
			local cx, cy = (minX+maxX)/2, (minY+maxY)/2
			local maxDist = 0
			
			for i, area in ipairs(navmesh.GetAllNavAreas()) do
				local c = area:GetCenter()
				maxDist = math.max( maxDist, math.Distance(c.x, c.y, cx, cy) )
			end
			
			for i, area in ipairs(navmesh.GetAllNavAreas()) do
				local c = area:GetCenter()
				local col = HSVToColor(math.Distance(c.x, c.y, cx, cy)/maxDist*360, 0.7, 1)
				debugoverlay.Triangle(area:GetCorner(2)+u, area:GetCorner(1)+u, area:GetCorner(0)+u, 3, col)
				debugoverlay.Triangle(area:GetCorner(2)+u, area:GetCorner(0)+u, area:GetCorner(3)+u, 3, col)
			end
		end)
	end
	
	function jcms.mapgen_GetNavmeshSpan(unrestricted) -- Mins/maxs of the navmesh.
		if unrestricted then
			if not jcms.mapdata.navmeshSpanUnrestricted then
				jcms.mapgen_AnalyzeMap()
			end

			return unpack(jcms.mapdata.navmeshSpanUnrestricted)
		else
			if not jcms.mapdata.navmeshSpan then
				jcms.mapgen_AnalyzeMap()
			end
			
			return unpack(jcms.mapdata.navmeshSpan)
		end
	end

	function jcms.mapgen_GetAreaSpan(unrestricted) -- The "area" of the navmesh span.
		if unrestricted then
			if not jcms.mapdata.areaSpanUnrestricted then
				jcms.mapgen_AnalyzeMap()
			end

			return jcms.mapdata.areaSpanUnrestricted
		else
			if not jcms.mapdata.areaSpan then
				jcms.mapgen_AnalyzeMap()
			end

			return jcms.mapdata.areaSpan
		end
	end
	
	function jcms.mapgen_GetDistanceFromCenter(pos, squared, unrestricted)
		local xMin, yMin, xMax, yMax = jcms.mapgen_GetNavmeshSpan(unrestricted)
		
		if squared then
			return math.DistanceSqr( pos.x, pos.y, (xMin+xMax)/2, (yMin+yMax)/2 )
		else
			return math.Distance( pos.x, pos.y, (xMin+xMax)/2, (yMin+yMax)/2 )
		end
	end
	
	function jcms.mapgen_GetDistanceFromCenterRelative(pos, unrestricted)
		local xMin, yMin, xMax, yMax = jcms.mapgen_GetNavmeshSpan(unrestricted)
		local maxDist = math.Distance( (xMin+xMax)/2, (yMin+yMax)/2, xMin, yMin )
		return math.Distance( pos.x, pos.y, (xMin+xMax)/2, (yMin+yMax)/2 ) / maxDist
	end

	function jcms.mapgen_GetSizedAreas()
		if not jcms.mapdata.sizedAreas then
			jcms.mapgen_AnalyzeMap()
		end
		
		return jcms.mapdata.sizedAreas
	end
	
	function jcms.mapgen_GetVisData(unrestricted)
		if unrestricted then
			if not jcms.mapdata.visUnrestricted then
				jcms.mapgen_AnalyzeMap()
			end
			
			return jcms.mapdata.visUnrestricted
		else
			if not jcms.mapdata.vis then
				jcms.mapgen_AnalyzeMap()
			end
			
			return jcms.mapdata.vis
		end
	end

	function jcms.mapgen_GetAreaAreas(unrestricted)
		if unrestricted then
			if not jcms.mapdata.areaAreasUnrestricted then
				jcms.mapgen_AnalyzeMap()
			end

			return jcms.mapdata.areaAreasUnrestricted
		else
			if not jcms.mapdata.areaAreas then
				jcms.mapgen_AnalyzeMap()
			end

			return jcms.mapdata.areaAreas
		end
	end

	function jcms.mapgen_GetMapSizeMultiplier()
		local md = jcms.mapdata

		if not md.areaTotalUnrestricted then
			jcms.mapgen_AnalyzeMap()
		end

		if not md.valid then
			return 1, 1, 1, 1, 1
		end

		--Area mult, volume mult
		local areaMult = md.areaTotalUnrestrictedRT / jcms.MAPGEN_CONSTRUCT_AREART
		local volumeMult = md.volumeTotal/ jcms.MAPGEN_CONSTRUCT_VOLUME
		local densityMult = md.densityUnrestrictedRT / jcms.MAPGEN_CONSTRUCT_DENSITYRT
		local avgAreaMult = md.avgAreaSizeRT / jcms.MAPGEN_CONSTRUCT_AVGAREASIZE
		local spanMult = md.areaSpan / jcms.MAPGEN_CONSTRUCT_AREASPAN

		return areaMult, volumeMult, densityMult, avgAreaMult, spanMult
	end
	
	function jcms.mapgen_GetMapSizeMultiplier_Restricted() --Restricted versions
		local md = jcms.mapdata
		if not md.areaTotal then
			jcms.mapgen_AnalyzeMap()
		end

		local areaMult = md.areaTotalRT / jcms.MAPGEN_CONSTRUCT_AREART_RESTRICTED
		local volumeMult = md.volumeTotal/ jcms.MAPGEN_CONSTRUCT_VOLUME
		local densityMult = md.densityRT / jcms.MAPGEN_CONSTRUCT_DENSITYRT_RESTRICTED
		local avgAreaMult = md.avgAreaSizeRT / jcms.MAPGEN_CONSTRUCT_AVGAREASIZE
		local spanMult = md.areaSpanUnrestricted / jcms.MAPGEN_CONSTRUCT_AREASPAN_UNRESTRICTED

		return areaMult, volumeMult, densityMult, avgAreaMult, spanMult
	end

	function jcms.mapgen_AdjustCountForMapSize(count)
		local sizeMul = jcms.mapgen_GetMapSizeMultiplier()
		return math.floor( count * math.max(1, sizeMul^0.8) )
	end
	
-- // }}}

-- // Area Functions {{{

	function jcms.mapgen_UseRandomArea(priorityOrder)
		local sizedAreas = jcms.mapgen_GetSizedAreas()
		
		if priorityOrder then
			for i, size in ipairs(priorityOrder) do
				local v, k = table.Random(sizedAreas[ size ])
				if v and k then
					return v, k, size
				end
			end
		else
			local sizeWeights = {}

			for size, subtable in pairs(sizedAreas) do
				sizeWeights[ size ] = #subtable
			end

			local size = jcms.util_ChooseByWeight(sizeWeights)
			local v, k = table.Random(sizedAreas[ size ])
			if v and k then
				return v, k, size
			end
		end
	end

	function jcms.mapgen_AreaPointAwayFromEdges(a, distance)
		local sx, sy = a:GetSizeX(), a:GetSizeY()
		distance = math.Clamp( tonumber(distance) or 64, 0, math.max(sx, sy) )

		local center = a:GetCenter()
		center.x = center.x + math.max(0, sx-distance) * (math.random() - 0.5)
		center.y = center.y + math.max(0, sy-distance) * (math.random() - 0.5)
		return a:GetClosestPointOnArea(center)
	end

	function jcms.mapgen_NearestArea(pos) --Similar to GetNearestNavArea but only using valid ones.
		local closest = nil
		local closestDist = math.huge
		for i, area in ipairs(jcms.mapdata.validAreas) do 
			local dist = pos:DistToSqr(area:GetCenter())
			if dist < closestDist then 
				closest = area
				closestDist = dist
			end
		end
		return closest, closestDist
	end

	function jcms.mapgen_GetAreaEdgePos(navArea, edge)
		local c1 = navArea:GetCorner( edge ) 
		local c2 = navArea:GetCorner( (edge + 1)%4 )
		return (c1 + c2)/2 
	end

	function jcms.mapgen_DropEntToNav(ent, pos, range) --More reliable :DropToFloor. Don't use on npcs/non-statics as they could fall through a displacement.
		pos = pos or ent:GetPos()
		local nearestArea = navmesh.GetNearestNavArea(pos, false, range or 250, true, true)
		if not IsValid(nearestArea) then return end
		ent:SetPos( nearestArea:GetClosestPointOnArea(pos) )
	end
	
	function jcms.mapgen_AreaFlat(area)
		local c1, c2, c3, c4 = area:GetCorner(1), area:GetCorner(2), area:GetCorner(3), area:GetCorner(0)
		if math.max(c1.z, c2.z, c3.z, c4.z) - math.min(c1.z, c2.z, c3.z, c4.z) > 34 then --TODO: Not hardcoded >34
			return false
		end
		return true
	end


-- // }}}

-- // Distribution {{{

	function jcms.mapgen_DistributePOIs(n, rad, weighedAreas)
		weighedAreas = weighedAreas or jcms.mapgen_GetAreaAreas()
		local shuffled = jcms.util_GetShuffledByWeight(weighedAreas)

		rad = tonumber(rad) or math.sqrt(jcms.mapgen_GetAreaSpan()*0.3)/math.sqrt(n)
		local rad2 = rad*rad
		local bestSolution = {}

		local startTime = SysTime()
		for iteration, startingArea in ipairs(shuffled) do
			local solution = { jcms.mapgen_AreaPointAwayFromEdges(startingArea, 64) }

			for i=1, math.ceil(#shuffled/2) + 1 do
				local area = jcms.util_ChooseByWeight(weighedAreas)
				local areaArea = area:GetSizeX() * area:GetSizeY()
				local attempts = math.Clamp(math.ceil( math.sqrt(areaArea) / 150 ), 1, 16)

				for j=1, attempts do
					local v = jcms.mapgen_AreaPointAwayFromEdges(area, 64)
					local good = true
					for k, ov in ipairs(solution) do
						if v:DistToSqr(ov) < rad2 then
							good = false
							break
						end
					end

					if good then
						table.insert(solution, v)

						if #solution >= n then
							break
						end
					end
				end

				if #solution >= n then
					break
				end
			end

			if (#solution == n) or (SysTime() - startTime) > 1 then
				bestSolution = solution
				break
			elseif #solution > #bestSolution then
				table.Empty(bestSolution)
				table.Add(bestSolution, solution)
			end
		end

		timer.Simple(0.5, function()
			for i,v in ipairs(bestSolution) do
				debugoverlay.Cross(v, 64, 1, Color(255,0,0), true)
				debugoverlay.Cross(v, 128, 1, Color(0,255,0), true)
			end
		end)

		return bestSolution
	end

-- // }}}

-- // Map Gen {{{

	function jcms.mapgen_PlacePrefabs(maxcount, weightedTypes, areasToUse) --TODO: terrible name, because we have spreadprefabs
		areasToUse = areasToUse or jcms.mapdata.validAreas

		local prefabCounts = {}
		local allAreas = {}
		for i, area in ipairs( areasToUse ) do
			if not ( area:GetSizeX() < 48 or area:GetSizeY() < 48 or bit.band( area:GetAttributes(), bit.bor(NAV_MESH_AVOID, NAV_MESH_OBSTACLE_TOP) ) > 0 ) then
				table.insert( allAreas, area )
			end
		end
		
		local canHouse = {}
		
		local zoneDict = jcms.mapgen_ZoneDict()
		for i, area in ipairs(allAreas) do
			canHouse[area] = {}

			for naturaltype in pairs(weightedTypes) do
				local prefabData = jcms.prefabs[naturaltype]
				if not(prefabData.onlyMainZone and not(zoneDict[area] == jcms.mapdata.largestZone)) then 
					local can, bonusData = jcms.prefab_Check(naturaltype, area)
					if can then
						table.insert( canHouse[area], { naturaltype, bonusData } )
					end
				end
			end
		end
		
		local stamped = 0
		local mapSizeMul = jcms.mapgen_GetMapSizeMultiplier_Restricted()

		local cachedWeights = {} --Prevent repeat work
		local function calcw(area, prefabType)
			for i, tuple in ipairs(canHouse[area]) do
				if tuple[1] == prefabType then
					local prefabData = jcms.prefabs[prefabType]
					local weight = (1 / #canHouse[area])
					if prefabData.areaWeight then 
						cachedWeights[prefabType] = cachedWeights[prefabType] or {}
						cachedWeights[area] = cachedWeights[area] or prefabData.areaWeight(area)
						weight = weight * cachedWeights[area]
					end
					return weight 
				end
			end
			return 0
		end

		for i=1, maxcount do
			local prefabType
			while true do
				prefabType = jcms.util_ChooseByWeight(weightedTypes)

				local prefabData = jcms.prefabs[prefabType]
				if prefabData.limit and (prefabCounts[prefabType] or 0) >= (isfunction(prefabData.limit) and prefabData.limit() or prefabData.limit) * math.Round(prefabData.limitMulBySize and mapSizeMul or 1) then
					weightedTypes[prefabType] = nil
				else
					break
				end
			end

			if not prefabType then
				break
			end

			local weighedAreas = {}
			for j, area in ipairs(allAreas) do
				local w = calcw(area, prefabType)
				if w > 0 then
					weighedAreas[area] = w
				end
			end

			local chosenArea = jcms.util_ChooseByWeight(weighedAreas)
			if chosenArea then
				for j, tuple in ipairs(canHouse[chosenArea]) do
					if tuple[1] == prefabType then
						jcms.prefab_ForceStamp(prefabType, chosenArea, tuple[2])
						stamped = stamped + 1
						
						prefabCounts[prefabType] = (prefabCounts[prefabType] or 0) + 1
						canHouse[chosenArea] = {}
 						break
					end
				end
			else
				break
			end
		end

		jcms.printf("Stamped prefabs: %d", stamped)
	end

	function jcms.mapgen_PlaceNaturals(maxcount, weightOverride)
		--2x shops if difficulty is <=0.9 , minimum of 1 shop.
		local shopCount = math.max(jcms.mapgen_AdjustCountForMapSize((jcms.runprogress_GetDifficulty() <= 0.9 and 2 or 1)), 1)
		local mainZoneShopCount = math.min(shopCount, math.floor(shopCount/4 + 2))

		if mainZoneShopCount == shopCount then
			jcms.mapgen_SpreadPrefabs("shop", mainZoneShopCount, 0, true)
			jcms.printf("Shop count: %d (all in the main zone)", mainZoneShopCount)
		else
			jcms.mapgen_SpreadPrefabs("shop", mainZoneShopCount, 0, true)
			jcms.mapgen_SpreadPrefabs("shop", shopCount - mainZoneShopCount, 0, false)
			jcms.printf("Shop count: %d (%d/%d in the main portion of the map)", shopCount, mainZoneShopCount, shopCount)
		end

		local naturalWeights = jcms.prefab_GetNaturalTypesWithWeights()

		if isfunction(weightOverride) then
			for name, weight in pairs(naturalWeights) do 
				naturalWeights[name] = weightOverride(name, weight)
			end
		end

		jcms.mapgen_PlacePrefabs(maxcount, naturalWeights, jcms.mapdata.validAreas)
		pcall( jcms.mapgen_PlaceDataLogs ) -- Don't want to fail map gen because of an error here
	end

	function jcms.mapgen_PlaceFactionPrefabs(maxcount, faction )
		local facWeights = jcms.prefab_GetFactionTypesWithWeights(faction)
		
		jcms.mapgen_PlacePrefabs(maxcount, facWeights, jcms.mapdata.validAreas)
	end
	
	function jcms.mapgen_PlaceEncounters()
		local d = assert(jcms.director, "director is not running, can't place encounters")
		d.encounters = d.encounters or {}
		
		local sizedAreas = jcms.mapgen_GetSizedAreas()
		local zoneDict = jcms.mapgen_ZoneDict()
		local visData = jcms.mapgen_GetVisData()
		
		local chances = {
			huge = 0.95,
			big = 0.74,
			medium = 0.38,
			small = 0.12,
			tiny = 0.02
		}
		
		local delays = {
			huge = 3.5,
			big = 3,
			medium = 3,
			small = 2,
			tiny = 1.3
		}
		
		if visData and (visData.max <= 4 or visData.avg <= 2) then -- This is a pretty shitty situation to be in.
			visData = nil
		end
		
		local stamped = 0
		local difficultyChanceMul = (jcms.runprogress_GetDifficulty() + 1.8) / 3
		for size, areas in pairs(sizedAreas) do
			for i, area in ipairs(areas) do
				local chance = chances[size]

				if zoneDict[ area ] ~= 1 then
					local newChance = chance + 0.27
					chance = newChance
				end
				
				if visData then
					local vis = #area:GetVisibleAreas()
					local aavg = (visData.avg + visData.min)/2
					if vis < aavg then
						-- Places where we *do* want encounters.
						chance = math.Remap(vis, visData.min, aavg, math.max(chance*1.5, 0.45), math.max(chance*1.25, 0.3))
					elseif vis < visData.avg then
						-- Various corners of the map. Having an encounter here is a little underwhelming but possible.
						chance = math.Remap(vis, aavg, visData.avg, chance*0.5, chance*0.2)
					else
						-- Main part of the map.
						chance = math.Remap(vis, visData.avg, visData.max, chance*0.4, chance*0.2)
					end
				end
				
				if math.random() < (chance * difficultyChanceMul) then
					local sx, sy = area:GetSizeX(), area:GetSizeY()
					
					local v = area:GetCenter()
					v.z = v.z + 32
					
					table.insert(d.encounters, {
						pos = v,
						rad = math.max(math.sqrt(sx*sx + sy*sy) + 60, 350)*1.5,
						npcCount = math.ceil( math.ceil((sx + sy)/(512))^1.28 ) + 1,
						delay = delays[size] + math.random(),
						danger = (math.random() < (chance * difficultyChanceMul)) and jcms.NPC_DANGER_STRONG or jcms.NPC_DANGER_FODDER
					})
					
					stamped = stamped + 1
				end
			end
		end
		
		jcms.printf("Encounters placed: %d", stamped)
	end

	jcms.mapgen_goodDataLogProps = {
		["models/props_wasteland/controlroom_desk001a.mdl"] = true,
		["models/props_wasteland/controlroom_desk001b.mdl"] = true,
		["models/props_interiors/furniture_desk01a.mdl"] = true,
		["models/props_combine/breendesk.mdl"] = true,
		["models/props_forest/table_shed.mdl"] = true,
		["models/props_c17/furnituretable002a.mdl"] = true,
		["models/props_c17/furnituretable001a.mdl"] = true,
		["models/props_wasteland/cafeteria_table001a.mdl"] = true,
		["models/props/cs_italy/it_mkt_table2.mdl"] = true,
		["models/props/cs_italy/it_mkt_table1.mdl"] = true,
		["models/props/cs_office/table_coffee.mdl"] = true,
		["models/props/cs_militia/table_kitchen.mdl"] = true,
		["models/props/de_inferno/tablecoffee.mdl"] = true,
		["models/props/de_tides/restaurant_table.mdl"] = true,
		["models/props/de_inferno/tableantique.mdl"] = true,
		["models/props/cs_militia/wood_table.mdl"] = true,
		["models/props/cs_office/table_meeting.mdl"] = true,
		["models/props_c17/hospital_surgerytable01.mdl"] = true,
		["models/props/cs_militia/table_shed.mdl"] = true,
		["models/props_c17/furnituretable003a.mdl"] = true,
		["models/props_junk/cardboard_box001a.mdl"] = true,
		["models/props_junk/cardboard_box002a.mdl"] = true,
		["models/props/de_nuke/crate_extrasmall.mdl"] = true,
		["models/props_junk/wood_crate002a.mdl"] = true,
		["models/props_junk/wood_crate001a.mdl"] = true,
		["models/props_junk/wood_crate001a_damaged.mdl"] = true,
		["models/props/de_prodigy/prodcratesb.mdl"] = true,
		["models/props/de_inferno/crate_fruit_break.mdl"] = true,
		["models/props_wasteland/prison_shelf002a.mdl"] = true,
		["models/props_wasteland/prison_shelf001a.mdl"] = true,
		["models/props_wasteland/kitchen_shelf002a.mdl"] = true,
		["models/props_wasteland/kitchen_shelf001a.mdl"] = true,
		["models/props_interiors/furniture_shelf01a.mdl"] = true,
		["models/props_c17/shelfunit01a.mdl"] = true,
		["models/props/cs_militia/furniture_shelf01a.mdl"] = true,
		["models/props_c17/hospital_shelf01.mdl"] = true,
		["models/props_c17/furnitureshelf002a.mdl"] = true,
		["models/props_c17/furnituredrawer001a.mdl"] = true,
		["models/props/de_inferno/furnituredrawer001a.mdl"] = true,
		["models/props_c17/furnituredrawer003a.mdl"] = true,
		["models/props_interiors/furniture_cabinetdrawer01a.mdl"] = true,
		["models/props_borealis/bluebarrel002.mdl"] = true,
		["models/props/de_train/barrel.mdl"] = true,
		["models/props_c17/oildrum001.mdl"] = true,
		["models/props_c17/oildrum001_explosive.mdl"] = true,
		["models/props_wasteland/laundry_cart002.mdl"] = true,
		["models/props_wasteland/laundry_cart001.mdl"] = true,
		["models/props_junk/metalbucket02a.mdl"] = true,
		["models/props_junk/trashdumpster01a.mdl"] = true,
		["models/props_c17/bench01a.mdl"] = true
	}

	function jcms.mapgen_PlaceDataLogs(count)
		local spawnCount = tonumber(count) or 0
		if not count then
			if math.random() < 0.36 then
				if math.random() < 0.1 then
					spawnCount = math.random(2, 3)
				else
					spawnCount = 1
				end
			else
				spawnCount = 0
			end
		end
		
		if spawnCount <= 0 then return end

		local props = ents.FindByClass("prop_physics")
		local validProps = {}
		for i, prop in ipairs(props) do
			if prop:Health() > 0 and jcms.mapgen_goodDataLogProps[ prop:GetModel() ] then
				table.insert(validProps, prop)
			end
		end
		table.Shuffle(validProps)

		local validAreas = {}
		local minVis, avgVis = jcms.mapdata.visUnrestricted.min, jcms.mapdata.visUnrestricted.avg
		for i, area in ipairs( navmesh.GetAllNavAreas() ) do
			if IsValid(area) and not (area:IsUnderwater() or area:IsDamaging()) then
				if (#area:GetVisibleAreas() <= math.ceil( (minVis + avgVis)/2 )-100) or (jcms.mapdata.areaDepths[ area ] and jcms.mapdata.areaDepths[ area ] == 0) then
					table.insert(validAreas, area)
				end
			end
		end
		table.Shuffle(validAreas)

		for i=1, spawnCount do
			local usePropMethod = #validProps > 0 and math.random() < 0.8
			local propMethodWorked = false

			if usePropMethod then
				for i, prop in ipairs(validProps) do
					local mins, maxs = prop:GetModelRenderBounds()
					local pos = prop:GetPos()
					pos.z = pos.z + maxs.z + math.Rand(8, 16)
					pos.x = pos.x + math.Rand(mins.x, maxs.x) * math.random()
					pos.y = pos.y + math.Rand(mins.y, maxs.y) * math.random()

					if util.IsInWorld(pos) then
						local pad = ents.Create("jcms_datapad")
						pad:SetAngles( AngleRand() )
						pad:SetPos( pos )
						pad:Spawn()

						local phys = pad:GetPhysicsObject()
						if IsValid(phys) then
							phys:Wake()
							table.remove(validProps, i)
							propMethodWorked = true
							break
						else
							pad:Remove()
						end
					end
				end
			end

			if not propMethodWorked then
				local area = validAreas[1]
				if area then
					local randomSpot = jcms.mapgen_AreaPointAwayFromEdges(area, 24)
					local pad = ents.Create("jcms_datapad")
					pad:SetAngles( AngleRand() )
					pad:SetPos( randomSpot )
					pad:Spawn()

					local phys = pad:GetPhysicsObject()
					if IsValid(phys) then
						phys:Wake()
						table.remove(validAreas, 1)
					else
						pad:Remove()
					end
				else
					break
				end
			end
		end
	end
	
	function jcms.mapgen_FromMission(mission)
		assert(type(mission) == "table" and mission.faction and mission.generate, "invalid mission data, must be a table")
		local missionData = {} -- Put various entities and persistent mission data in here.
		mission:generate(missionData)
		jcms.director.missionData = missionData
	end

-- // }}}

-- // Zones {{{

	function jcms.mapgen_ZoneList()
		if not jcms.mapdata.zoneList then
			jcms.mapgen_AnalyzeMap()
		end
		
		return jcms.mapdata.zoneList
	end
	
	function jcms.mapgen_ZoneDict()
		if not jcms.mapdata.zoneDict then
			jcms.mapgen_AnalyzeMap()
		end
		
		return jcms.mapdata.zoneDict
	end

	function jcms.mapgen_MainZone()
		return jcms.mapgen_ZoneList()[jcms.mapdata.largestZone]
	end

-- // }}}

-- // Shared Generation Behaviours. {{{

	function jcms.mapgen_SpreadPrefabs(prefabtype, count, sizeXY, onlyMainZone, avoidAreas)
		if type(count) ~= "number" or (count <= 0) then return end
		local pref = jcms.prefabs[prefabtype]

		local zoneDict = jcms.mapgen_ZoneDict()

		-- // Initial weights {{{
			local defaultWeightedAreas = {}
			for i, area in ipairs(jcms.mapdata.validAreas) do 
				if not(onlyMainZone and not(zoneDict[area] == jcms.mapdata.largestZone)) and area:GetSizeX() > sizeXY and area:GetSizeY() > sizeXY and pref.check(area) then 
					defaultWeightedAreas[area] = math.sqrt(area:GetSizeX() * area:GetSizeY())
				end
			end
		-- // }}}

		local prefabAreas = avoidAreas or {}
		local prefabs = {}

		--Optimisation
		local upVec = Vector(0, 0, 190)
		local area_vectors = {}
		local area_raisedVectors = {}
		for area, weight in pairs(defaultWeightedAreas) do 
			area_vectors[area] = area:GetCenter()
			area_raisedVectors[area] = area:GetCenter() + upVec
		end

		if avoidAreas then
			for i, area in ipairs(avoidAreas) do
				area_vectors[area] = area:GetCenter()
				area_raisedVectors[area] = area:GetCenter() + upVec
			end
		end

		jcms.mapgen_Wait( 0.05 )

		for i=1, count, 1 do
			local weightedAreas = {}
			for area, weight in pairs(defaultWeightedAreas) do 
				local closestDist = math.huge
				local canSeeOther = false

				for i, otherArea in ipairs(prefabAreas) do --Don't spawn too close to others.
					local dist = area_vectors[area]:Distance( area_vectors[otherArea] )
					closestDist = (closestDist < dist and closestDist) or dist
					canSeeOther = canSeeOther or otherArea:IsPartiallyVisible( area_raisedVectors[area] )
				end
				
				if not(closestDist == math.huge) then  
					weight = weight * math.sqrt(closestDist)
				end
				if canSeeOther then 
					weight = weight * 0.00001
				end
				weightedAreas[area] = weight
			end

			local chosenArea = jcms.util_ChooseByWeight(weightedAreas)

			if not chosenArea then return prefabs end --Fail safe (map has no or not enough valid areas)

			local worked, pref = jcms.prefab_TryStamp(prefabtype, chosenArea) --We've already checked if our target area is valid, no need to check again
			table.insert(prefabAreas, chosenArea) 
			table.insert(prefabs, pref)

			jcms.mapgen_Wait( 0.05 + (i/count)*0.95 )
		end

		return prefabs, prefabAreas
	end
-- // }}}