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

jcms.pathfinder = jcms.pathfinder or {}

-- // Generating Our Air Nodes {{{
	hook.Add("InitPostEntity", "jcms_pathfinder_initialize", function()
		local pathfinderStart = SysTime()

		jcms.pathfinder.airNodes = {} --air nodes
		jcms.pathfinder.leafAirNodes = {} --Nodes for each leaf

		--If something broke while reading don't generate any nodes, as that'll cause more issues down the line.
		if not bspReader.pvsDataRead or not bspReader.leafDataRead or not bspReader.nodeDataRead or not bspReader.planeDataRead then return end

		do --Detect skybox
			local skyCam = ents.FindByClass("sky_camera")[1] --Should only be one of these.
			
			if IsValid(skyCam) then 
				local leaf = bspReader.getVisLeaf( skyCam:GetPos() )
				jcms.pathfinder.skyArea = bspReader.getVisLeafArea( leaf )
			end
		end

		--idk how much of a performance gain not re-creating these tables each time is going to be, but it's easy so might-as-well.
		local trHullRes = {}
		local hullTrData = {
			start = vector_origin, --set in loop
			endpos = vector_origin,
			mins = Vector(-40,-40,-40), --Helis are -38 to 38; not sure about gunships as they don't return anything.
			maxs = Vector(40,40,40),
			mask = MASK_NPCWORLDSTATIC,
			output = trHullRes
		}
		
		--Generate nodes
		for leaf=1, #bspReader.leafMins, 1 do
			if bspReader.leafClusterConnections[leaf-1] and not(bspReader.getVisLeafArea( leaf-1 ) == jcms.pathfinder.skyArea) then --Hacky way of checking we're not in the world, because I don't store that data.
				local mins = bspReader.leafMins[leaf]
				local maxs = bspReader.leafMaxs[leaf]

				local bounds = maxs - mins
				if bounds.x > 400 and bounds.y > 400 and bounds.z > 1500 then 
					local centre = (mins + maxs)/2
					jcms.pathfinder.leafAirNodes[leaf-1] = {}

					local divLen = math.max((bounds.z - 1500)/2, 1000) --1000 or enough to split into 2 nodes
					local divCount = 1 + math.floor((bounds.z - 1500) / divLen) 
					for j=1, divCount, 1 do 
						local position = Vector(centre.x, centre.y, mins.z + 1000 + (divLen * (j-1)))
						if bit.band(util.PointContents( position ), CONTENTS_SOLID) == 0 then
							hullTrData.start = position
							hullTrData.endpos = position
							util.TraceHull(hullTrData)

							if not trHullRes.Hit then --Stop us generating too close to anything
								local node = {
									pos = position,
									connections = {}, --connections to other nodes.
									connectionCosts = {} --Distances
								}
								table.insert(jcms.pathfinder.airNodes, node)
								table.insert(jcms.pathfinder.leafAirNodes[leaf-1], node) --So we can be easily accessed later.
							end
						end
					end
				end
				--1 node per 1000u
			end
		end

		--Generate connections between nodes
		local maxRange = 15000^2 --Capped at 15000 dist for performance.
		for i=1, #jcms.pathfinder.airNodes, 1 do
			local startNode = jcms.pathfinder.airNodes[i]
			--[[todo:
				Only test our PVS?
			--]]
			for j=i, #jcms.pathfinder.airNodes, 1 do 
				local endNode = jcms.pathfinder.airNodes[j]
				if not(startNode == endNode) and startNode.pos:DistToSqr(endNode.pos) < maxRange then
					local tr = util.TraceLine({
						start = startNode.pos,
						endpos = endNode.pos,
						mask = MASK_NPCWORLDSTATIC
					})
					if not tr.Hit then 
						local dist = startNode.pos:Distance(endNode.pos)
						table.insert(startNode.connections, endNode)
						table.insert(endNode.connections, startNode)

						table.insert(startNode.connectionCosts, dist)
						table.insert(endNode.connectionCosts, dist)
					end
				end
			end
			--debugoverlay.Cross(startNode.pos, 30, 15, Color( 0, 0, 0 ), true)
		end


		-- // Calculate zones (same as in map-gen, used to prevent us having to fully explore the graph for inaccessible areas) {{{
			local nodeZones = {}
			jcms.pathfinder.nodeZones = nodeZones

			local zoneIter = 0
			local unZonedNodes = {}
			--table.Add(unZonedNodes, jcms.pathfinder.airNodes)
			for i=1, #jcms.pathfinder.airNodes, 1 do
				local node = jcms.pathfinder.airNodes[i]
				unZonedNodes[node] = true
			end

			while table.Count(unZonedNodes) > 0 do
				zoneIter = zoneIter + 1

				local closedNodes = {} --dict of checked/closed nodes
				local _, node = table.Random( unZonedNodes ) --Little uncomfortable about using table.random here, but it was the most straightforwards way to do this.
				local openNodes = {node} --stack of un-checked nodes. 

				while #openNodes > 0 do
					local startNode = table.remove(openNodes, 1)
					nodeZones[startNode] = zoneIter --Our zone

					--closing the node
					closedNodes[startNode] = true
					unZonedNodes[startNode] = nil

					for i, otherNode in ipairs(startNode.connections) do 
						if not closedNodes[otherNode] then 
							table.insert(openNodes, otherNode)
							closedNodes[otherNode] = true
						end
					end
				end
			end
		-- // }}}

		
		print("[MapSweepers] Airgraph nodes generated in: " .. tostring( math.Round(SysTime() - pathfinderStart, 3) ) .. " seconds")
	end)
-- // }}}

function jcms.pathfinder.getNearestNode( point )
	if not jcms.pathfinder.airNodes then return end

	local closestDist = math.huge
	local closestNode

	for i, node in ipairs(jcms.pathfinder.airNodes) do
		local dist = node.pos:DistToSqr(point)
		if dist < closestDist then 
			closestNode = node
			closestDist = dist
		end
	end

	return closestNode
end

function jcms.pathfinder.getNearestNodePVS( point )
	if not jcms.pathfinder.airNodes then return end
	
	local closestDist = math.huge
	local closestNode

	for i, node in ipairs(jcms.pathfinder.getNodesInPVS( point )) do
		local dist = node.pos:DistToSqr(point)
		if dist < closestDist then 
			closestNode = node
			closestDist = dist
		end
	end

	return closestNode
end

function jcms.pathfinder.getNodesInPVS( point )
	local pvs = bspReader.getPVSAtPoint(point)
	local nodes = {}

	if not jcms.pathfinder.leafAirNodes then
		return nodes
	end

	for _, cluster in ipairs(pvs) do 
		local leaves = bspReader.getClusterVisleaves(cluster) 
		for i, leaf in ipairs(leaves) do
			local leafNodes = jcms.pathfinder.leafAirNodes[leaf]
			
			if leafNodes then 
				for _, node in ipairs(leafNodes) do 
					table.insert(nodes, node)
				end
			end
		end
	end

	return nodes
end

function jcms.pathfinder.AStar( startNode, endNode, totalCost, exploreConnected ) --Generalised A* algorithm since we use this for (Currently) 3 different graph types
	local openNodes = {startNode}
	local openDict = {[startNode] = true}
	local nodePathCosts = {[startNode] = totalCost}
	local nodePredecessors = {}
	local closedDict = {}

	local success = false
	while #openNodes > 0 do
		-- // Select lowest-cost from open as currentNode {{{
			local currentNode
			local lowestCost = math.huge
			for i, node in ipairs(openNodes) do --Select node with lowest cost
				if (nodePathCosts[node] or math.huge) < lowestCost then
					lowestCost = nodePathCosts[node]
					currentNode = node
				end
			end
			table.RemoveByValue(openNodes, currentNode)
			openDict[currentNode] = nil
			closedDict[currentNode] = true
		-- // }}}

		if currentNode == endNode then -- Found our target, break
			success = true 
			break
		end

		--This part is still kinda messy, if I need to work with this system more in-future I might try to further cut down repeat code. 
		exploreConnected(currentNode, closedDict, nodePathCosts, nodePredecessors, openDict, openNodes)
	end

	if not success then return end
	
	--Backtrack to make a path
	local path = {endNode}
	while true do --if we were successful we're guaranteed to have a path.
		local node = nodePredecessors[path[#path]]

		table.insert(path, node)
		if node == startNode then break end
	end

	return path --Chain of nodes representing our path.
end

function jcms.pathfinder.navigate( startPoint, endPoint ) --A*
	--We can accept either a vector position or the node itself. Latter is used for optimisation of missile turrets.
	local startNode = (isvector(startPoint) and jcms.pathfinder.getNearestNodePVS( startPoint )) or startPoint
	local endNode = (isvector(endPoint) and jcms.pathfinder.getNearestNodePVS( endPoint )) or endPoint

	if not startNode or isvector(startNode) then --fallback
		startNode = jcms.pathfinder.getNearestNode( startPoint )
	end
	if not endNode or isvector(endNode) then --fallback
		endNode = jcms.pathfinder.getNearestNode( endPoint )
	end

	if startNode == endNode or not startNode or not endNode then return end --Don't need to navigate if we're just going to where we already are.
	if not(jcms.pathfinder.nodeZones[startNode] == jcms.pathfinder.nodeZones[endNode]) then return end --We can't reach our target, don't waste time trying.

	-- Uses airgraph node data, avoids occupied nodes. 
	local function exploreConnected(currentNode, closedDict, nodePathCosts, nodePredecessors, openDict, openNodes)
		for i, node in ipairs(currentNode.connections) do
			if not closedDict[node] and not node.occupied then
				local heuristic = node.pos:Distance(endNode.pos)
				local cost = nodePathCosts[currentNode] + currentNode.connectionCosts[i]
				--Add us to openNodes if we aren't in it
				if (nodePathCosts[node] or math.huge) > heuristic + cost then
					nodePredecessors[node] = currentNode
					nodePathCosts[node] = heuristic + cost
				end
				if not openDict[node] then 
					openDict[node] = true
					table.insert(openNodes, node)
				end
			end
		end
	end

	--Everything else is generic.
	return jcms.pathfinder.AStar( startNode, endNode, startNode.pos:Distance(endNode.pos), exploreConnected )
end

function jcms.pathfinder.navigateVectorGrid( connections, costs, startPoint, endPoint )
	-- Based entirely on the code above.
	if startPoint == endPoint or not startPoint or not endPoint or not (connections[startPoint]) or not (connections[endPoint]) then return end

	--Uses vector connection data instead of airgraph nodes
	local function exploreConnected(currentNode, closedDict, nodePathCosts, nodePredecessors, openDict, openNodes)
		for i, node in ipairs( connections[currentNode] ) do
			if not closedDict[node] then
				local heuristic = node:Distance(endPoint)
				local cost = nodePathCosts[currentNode] + (costs[node] or 0) + node:Distance(currentNode)

				if (nodePathCosts[node] or math.huge) > heuristic + cost then
					nodePredecessors[node] = currentNode
					nodePathCosts[node] = heuristic + cost
				end
				if not openDict[node] then 
					openDict[node] = true
					table.insert(openNodes, node)
				end
			end
		end
	end

	--Everything else is generic.
	return jcms.pathfinder.AStar( startPoint, endPoint, startPoint:Distance(endPoint), exploreConnected )
end
