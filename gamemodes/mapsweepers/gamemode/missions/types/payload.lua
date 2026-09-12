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

function jcms.mapgen_PayloadGenPath()
	local accepted = false
	local nodeVectors = {}

	local payloadHullMins = Vector(-42, -42, 24)
	local payloadHullMaxs = Vector(42, 42, 48)
	
	local zoneDict = jcms.mapgen_ZoneDict()
	
	local midAreaWeights = {}
	local avgDepth = jcms.mapdata.areaDepthAvg
	for area, depth in pairs(jcms.mapdata.areaDepths) do
		if zoneDict[area] == jcms.mapdata.largestZone and depth > avgDepth then
			local score = depth^2 - jcms.mapgen_GetDistanceFromCenterRelative( area:GetCenter() ) * avgDepth
			midAreaWeights[ area ] = score
		end
	end

	jcms.mapgen_Wait( 0.1 )

	for attempt = 1, 20 do
		local area = jcms.util_ChooseByWeight(midAreaWeights)
		if not area then break end
		
		local rad = 6000 - attempt * 100
		local areas = jcms.director_GetAreasAwayFrom(jcms.mapdata.zoneList[jcms.mapdata.largestZone], {area:GetCenter()}, 0, rad)
		local path, pathLength = jcms.mapgen_GenPathAround(areas, 256, 15000)

		if path then
			nodeVectors = path
			accepted = true

			if pathLength > rad * (1 - attempt * 0.05) then
				break
			end
		end

		jcms.mapgen_Wait( 0.1 + (attempt/20) * 0.8 )
	end
	
	if not accepted then
		error("Can't generate a good-enough payload track. This map sucks, find a better one.")
	else
		local nodes = {}
		local lastNodeEnt = NULL

		-- Removing dips
		local dipi = 1
		local tr_res = {}
		local tr_data = { output = tr_res, mask = MASK_PLAYERSOLID_BRUSHONLY, mins = Vector(-32, -32, 16), maxs = Vector(32, 32, 64) }
		while #nodeVectors >= 3 do
			local v1, v2, v3 = nodeVectors[dipi], nodeVectors[dipi+1], nodeVectors[dipi+2]
			if not (v1 and v2 and v3) then
				break
			end

			local shouldRemoveV2 = false
			if math.abs(v1.z - v2.z) <= 250 and (v2.z < v1.z-48) and (v2.z < v3.z-48) then
				tr_data.start = v1
				tr_data.endpos = v3
				util.TraceHull(tr_data)

				if not tr_res.HitWorld and not tr_res.StartSolid then
					shouldRemoveV2 = true
				end
			end

			if shouldRemoveV2 then
				print("Optimized payload path (removed a V-shaped dip) at Vector(" .. tostring(v2) ..")")
				table.remove(nodeVectors, dipi+1)
				if dipi > 1 then
					dipi = dipi - 1
				end
			else
				dipi = dipi + 1
			end
		end
		
		for i, v in ipairs(nodeVectors) do
			local nodeEnt = ents.Create("jcms_node")
			
			nodeEnt:SetPos(v)
			nodeEnt:Spawn()

			if IsValid(lastNodeEnt) then
				lastNodeEnt:ConnectNode(nodeEnt)
			end

			lastNodeEnt = nodeEnt
			table.insert(nodes, nodeEnt)
		end

		return nodes
	end
end

jcms.missions.payload = {
	faction = "any",
	pvpAllowed = false,

	generate = function(data, missionData)
		local track = jcms.mapgen_PayloadGenPath()
		missionData.track = track
		missionData.trackLength = 0

		jcms.mapgen_Wait( 0.95 )
		
		for i,n in ipairs(track) do
			missionData.trackLength = missionData.trackLength + n.distance
		end

		local hackNodes = {}
		if #track > 7 then
			local hackNodesCount = math.random(2, 3)
			local everySteps = math.Round( #track / (hackNodesCount + 1) )
			local baseStep = math.random(1, math.ceil(everySteps/2))
			
			for i = 1, hackNodesCount do
				hackNodes[ baseStep + everySteps * i ] = true
			end
		elseif #track >= 5 then
			local presets = {
				[5] = { 3 },
				[6] = { math.random(3, 4) },
				[7] = math.random() < 0.5 and { 4 } or { 3, 5 }
			}

			for i, index in ipairs(presets[ #track ]) do
				hackNodes[index] = true
			end
		end

		for nodeIndex in pairs(hackNodes) do
			local ent = track[ nodeIndex ]
			local area = navmesh.GetNearestNavArea(ent:GetPos(), false, 1000, true, true)
			if area then
				ent:SetModel("models/props_combine/combine_mine01.mdl")
				local term = ents.Create("jcms_terminal")
				local wallspots, normals = jcms.prefab_GetWallSpotsFromArea(area, 32, 300)

				if #wallspots > 0 then
					local ri = math.random(1, #wallspots)

					term:SetPos(wallspots[ri] + normals[ri] * 25)
					term:SetAngles(normals[ri]:Angle())
				else
					--Prevents us from using the navArea we're in if it's too small. Don't want the terminal immediately under the payload.
					local ang1 = ent:GetAngles()
					ang1:RotateAroundAxis( ang1:Up(), math.random() < 0.5 and -90 or 90 )
					
					local navPos = ent:GetPos()
					navPos:Add( ang1:Forward() * math.random(120, 200) )

					local newArea = navmesh.GetNearestNavArea(navPos, false, 250, true, true) or area

					--Puts us at the edge of whichever area we're at
					local dir = math.random(0, 3)
					term:SetPos(jcms.mapgen_GetAreaEdgePos(newArea, dir))
					local ang2 = Angle(0,90,0)
					ang2:RotateAroundAxis( ang2:Up(), dir * 90 )
					term:SetAngles(ang2)

				end

				jcms.mapgen_DropEntToNav(term)

				term:Spawn()
				term:InitAsTerminal("models/props_combine/combine_interface002.mdl", "payload_controls")
				term.jcms_hackTypeStored = term.jcms_hackType --workaround to make us unhackable with stunstick
				term.jcms_hackType = nil
				ent.terminal = term

				function term:jcms_terminal_Callback(cmd, data, ply)
					if not ent:GetIsEnabled() then
						
						jcms.director_PvpObjectiveCompleted(ply, term:GetPos(), true)
						ent:SetIsEnabled(true)
						term:EmitSound("buttons/button17.wav")
						return true, "c"
					end
				end

				local wld = game.GetWorld()
				local v1, v2 = term:WorldSpaceCenter(), ent:GetPos()
				constraint.Rope(wld, wld, 0, 0, v1, v2, v1:Distance(v2), 150, 0, 3)

				ent:SetEnergyColour( Vector(0, 1, 1) )
				ent:SetIsEnabled(false)
			end
		end
		
		track[1]:SetModel("models/props_combine/combine_mine01.mdl")
		track[#track]:SetModel("models/props_combine/combine_mine01.mdl")
		track[#track]:SetIsPowerful(true)

		local payload = ents.Create("jcms_payload")
		payload:SetPos(track[1]:GetTrackPosition())
		payload.targetNode = track[2]
		payload.oldNode = track[1]
		payload:Spawn()
		payload.MaxSpeed = missionData.trackLength / ((60 * 3.5) * jcms.runprogress_GetDifficulty()) -- 3.5 minutes to reach the end (difficulty scaled)
		missionData.payload = payload

		jcms.mapgen_Wait( 1 )

		jcms.mapgen_PlaceNaturals( jcms.mapgen_AdjustCountForMapSize(11) )
		jcms.mapgen_PlaceEncounters()
	end,

	think = function(director)
		local payload = director.missionData.payload
		if math.random() < 0.5 and IsValid(payload) then
			local ply = director.strongestPlayer
			if IsValid(ply) then
				for i, npc in ipairs(jcms.director.npcs) do
					if math.random() < 0.5 and not npc:Visible(ply) then
						npc:UpdateEnemyMemory(ply, payload:WorldSpaceCenter())
					end
				end
			end
		end
	end,

	tagEntities = function(director, missionData, tags)
		local pl = missionData.payload

		if IsValid(pl) then
			tags[pl] = { name = "#jcms.payload_entity", moving = true, active = true, landmarkIcon = "payload" }
		elseif tags[pl] then
			tags[pl] = nil
		end
	end,
	
	getObjectives = function(missionData)
		if missionData.completed then
			missionData.evacuating = true
		
			if not IsValid(missionData.evacEnt) then
				missionData.evacEnt = jcms.mission_DropEvac(jcms.mission_PickEvacLocation())
			end

			return jcms.mission_GenerateEvacObjective()
		else
			local track = missionData.track
			local payload = missionData.payload

			local ruined = not IsValid(payload)
			if not ruined then
				for i, node in ipairs(track) do
					if not IsValid(node) then
						ruined = true 
						break
					end
				end
			end

			if ruined then
				if (not jcms.director.gameover) then
					jcms.director.gameover = true
					jcms.mission_End(false)
				end

				return { { type = "die", progress = 0, total = 0 } }
			else
				local payloadProgress = 0
				
				local lastPassedNode = 1
				local isHindered = false
				for i, node in ipairs(track) do
					if IsValid(payload.oldNode) and (node == payload.oldNode) then
						lastPassedNode = i

						if node.terminal and node.terminal.jcms_hackTypeStored then
							node.terminal.jcms_hackType = node.terminal.jcms_hackTypeStored
							node.terminal.jcms_hackTypeStored = nil
							node.terminal:EmitSound("npc/roller/remote_yes.wav", 100, 100)
							node.terminal:SetNWString("jcms_terminal_modedata", "p")
							node.terminal.nodeWasCrossed = true
							jcms.net_SendTip("all", true, "#jcms.payload_stopped", 0)
						end

						if not node:GetIsEnabled() then
							isHindered = true
						end
						
						break
					end
				end

				local nextNode = lastPassedNode + 1
				if nextNode <= #track then
					local distSoFar = 0
					for i=1, lastPassedNode-1 do
						distSoFar = distSoFar + track[i].distance
					end

					local vOld, vNew = track[lastPassedNode]:GetTrackPosition(), track[nextNode]:GetTrackPosition()
					local dist, vOnLine, distAlong = util.DistanceToLine(vOld, vNew, payload:WorldSpaceCenter())
					payloadProgress = (distSoFar + distAlong) / missionData.trackLength
				else
					payloadProgress = 1
				end

				local payloadProgressMilestone = math.ceil(payloadProgress/0.25)
				if (not missionData.lastMilestone or missionData.lastMilestone < payloadProgressMilestone) then
					jcms.net_SendTip("all", true, "#jcms.payload_completion", payloadProgress)
					missionData.lastMilestone = payloadProgressMilestone
				end

				if payloadProgress >= 1 then
					missionData.completed = true
					
					for i, n in ipairs(missionData.track) do
						local upwards = Vector(0, 0, 1)
						timer.Simple(0.3 + i*0.06 + math.random()*0.4, function()
							if IsValid(n) then
								local ed = EffectData()
								ed:SetOrigin(n:GetPos())
								ed:SetMagnitude(2)
								ed:SetScale(2)
								ed:SetRadius(3)
								ed:SetNormal(upwards)
								util.Effect("Sparks", ed)
								n:Remove()
							end
						end)
					end
					
					timer.Simple(0.3 + #missionData.track*0.06 + 1, function()
						if IsValid(payload) then
							payload:EmitSound("ambient/machines/teleport3.wav")
							payload:Remove()
							
							local ed = EffectData()
							ed:SetOrigin(payload:GetPos())
							ed:SetFlags(1)
							util.Effect("jcms_evacbeam", ed)
						end
					end)
				end

				local pushing = payload:GetPushingPlayerCount() or 0
				local living = math.max(1, jcms.director.livingPlayers)

				if isHindered then
					return {
						{ type = "bringpayload", completed = missionData.completed, percent = true, progress = math.floor(payloadProgress*100), total = 100 },
						{ type = "hackcontrolpoint", progress = 0, total = 0 },
						{ type = "j", progress = 0, total = 0 }
					}
				else
					return {
						{ type = "pushpayload", completed = pushing > 0, progress = pushing, total = living },
						{ type = "bringpayload", completed = missionData.completed, percent = true, progress = math.floor(payloadProgress*100), total = 100 },
						{ type = "j", progress = 0, total = 0 }
					}
				end
			end
		end
	end
}