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

--[[ NOTE:
	THIS FILE IS LOADED AFTER sv_pathfinder.lua!
	That means the table there already exists, and you can access it.
-- ]]

jcms.pathfinder.ain_nodeUsers = jcms.pathfinder.ain_nodeUsers or {} --NPCs currently navigating through each node.

function jcms.pathfinder.ain_navigate(fromVec, toVec, hull, capabilities)
	ainReader.readNodeData()
	ainReader.readLinkData()

	local fromNode = jcms.pathfinder.ain_nearestNode(fromVec)
	local toNode = jcms.pathfinder.ain_nearestNode(toVec)

	if not( ainReader.nodeZones[fromNode] == ainReader.nodeZones[toNode]) then return end --Stop us exploring the whole graph
	--TODO: Not good enough. We need per-hull/capability data (i will likely only store this for walk / human)
	if fromNode == toNode then return end --Do not navigate 0-length paths.

	--readability
	local nodePositions = ainReader.nodePositions
	local nodeConnections = ainReader.nodeConnections
	local nodeConnectionMoves = ainReader.nodeConnectionMoves
	local nodeTypes = ainReader.nodeTypes
	local nodeUsers = jcms.pathfinder.ain_nodeUsers --NPCs navigating through this node
	
	
	--Uses ainreader nodedata, tries to spread navigation out.
	local function exploreConnected(currentNode, closedDict, nodePathCosts, nodePredecessors, openDict, openNodes)
		for i, node in ipairs(nodeConnections[currentNode]) do
			if not closedDict[node] and (nodeTypes[node] == 2) and not(bit.band(nodeConnectionMoves[currentNode][i][hull+1], capabilities) == 0) then
				local heuristic = nodePositions[node]:Distance(nodePositions[toNode]) + ((nodeUsers[node] or 0) * 50)
				local cost = nodePathCosts[currentNode] + nodePositions[currentNode]:Distance(nodePositions[node])

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

	--[[
	--debugging
	local path = jcms.pathfinder.AStar( fromNode, toNode, ainReader.nodePositions[fromNode]:Distance(ainReader.nodePositions[toNode]), exploreConnected )

	
	for i, node in ipairs(path) do
		--print(nodePositions[node])
		debugoverlay.Cross(nodePositions[node], 30, 8, Color( 0, 0, 255 ), true)
	end--]]

	--Everything else is generic.
	return jcms.pathfinder.AStar( fromNode, toNode, ainReader.nodePositions[fromNode]:Distance(ainReader.nodePositions[toNode]), exploreConnected )
end

--TODO: Can we check if each component is equal instead? (Actually would that even be more performant in this context?)
function jcms.pathfinder.ain_nearestNode(pos)
	ainReader.readNodeData()

	local closest = nil 
	local closestDist = math.huge

	for i, nPos in ipairs(ainReader.nodePositions) do
		local dist = nPos:DistToSqr(pos)
		if dist < closestDist then 
			closest = i
			closestDist = dist
		end
	end

	return closest
end