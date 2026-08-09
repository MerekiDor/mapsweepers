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
AddCSLuaFile()

ENT.Type = "ai"
ENT.Base = "base_anim"
ENT.PrintName = "Flesh Creep"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OTHER

-- // Cell stuff {{{
	jcms.zombieCreepCells = jcms.zombieCreepCells or {} --**IMPORTANT NOTE**: This is an ent on server and a bool on client.

	-- // Cell Grid Definitions
		local cellOffset = 128-17 --Mitigation for the extra size cells get making empty areas appear fleshed. Most hammer geometry is on power of 2 coords so this just offsets it a little.
		local cellWidth = 512 - 128
		local cellHeight = 256

		local rowLength = math.ceil(32768 / cellWidth) --How many indices are there for each complete line of x/y values? 
		local layerLength = rowLength^2 --How many for a single z layer?
		local totalLength = layerLength * math.ceil(32768 / cellHeight) --Max index of the table
		jcms.zombieCreep_BitCount = math.ceil(math.log(totalLength, 2))
	-- // }}}
	local vecCellSize = Vector(cellWidth, cellWidth, cellHeight)
	jcms.zombieCreep_cellSize = vecCellSize
	
	--Optimisation - tracking the start/end so we don't have to check a ton of empty spots each rebuild.
	jcms.zombieCreepMinCell = jcms.zombieCreepMinCell or totalLength
	jcms.zombieCreepMaxCell = jcms.zombieCreepMaxCell or 1

	-- // Getters {{{
		function jcms.zombieCreep_GetCellIndices(pos)
			--Convert world space xyz to array space xyz
			return math.floor((pos.x + 16384 + cellOffset) / cellWidth, 0), math.floor((pos.y + 16384 + cellOffset) / cellWidth, 0), math.floor((pos.z + 16384 + cellOffset) / cellHeight, 0)
		end

		function jcms.zombieCreep_GetCellByIndices(x, y, z)
			--Convert 3D xyz to 1D array index
			return x + (rowLength * y) + (layerLength * z)
		end

		function jcms.zombieCreep_GetCell( pos )
			--The contents of these two functions used to be in this one, I guess this is just shorthand for them now.
			local xIndex, yIndex, zIndex = jcms.zombieCreep_GetCellIndices(pos)
			return jcms.zombieCreep_GetCellByIndices(xIndex, yIndex, zIndex)  --xIndex + (rowLength * yIndex) + (layerLength * zIndex)
		end

		function jcms.zombieCreep_GetCellPos( cell )
			local zRemainder = cell % layerLength
			local yRemainder = zRemainder % rowLength

			local xIndex = yRemainder
			local yIndex = (zRemainder - yRemainder) / rowLength
			local zIndex = (cell - zRemainder) / layerLength

			return Vector((xIndex * cellWidth) - 16384 - cellOffset, (yIndex * cellWidth)  - 16384 - cellOffset, (zIndex * cellHeight) - 16384 - cellOffset)
		end
	-- // }}}

	-- // Setters {{{
		function jcms.zombieCreep_OccupyCell( cell, occupier )
			--Update min/max cells
			if cell > jcms.zombieCreepMaxCell then
				jcms.zombieCreepMaxCell = cell
			end
			if cell < jcms.zombieCreepMinCell then 
				jcms.zombieCreepMinCell = cell
			end

			--Mark us
			if SERVER then
				jcms.zombieCreepCells[cell] = occupier
			else
				jcms.zombieCreepCells[cell] = true
			end
		end

		function jcms.zombieCrep_ClearCell( cell )
			--I was going to recalc max/min here, but that's probably not necessary. If it *is* it should probably be done in the rebuild anyway since it'll be expensive.
			jcms.zombieCreepCells[cell] = nil
		end
	-- // }}}

	hook.Add("SetupMove", "jcms_ZombieCreep_Snare", function(ply, mv, cmd)
		local cell = jcms.zombieCreep_GetCell( ply:GetPos() )

		local cellVal = jcms.zombieCreepCells[cell] --Different on client/server ):
		if not(SERVER and IsValid(cellVal) or CLIENT and cellVal) then return end
		if not ply:IsOnGround() then return end
		if not jcms.team_JCorp_player_valid(ply) then return end

		if SERVER then
			jcms.director_TryShowTip(ply, jcms.HINT_CREEP)
		end

		mv:SetMaxClientSpeed(100)
	end)
-- // }}}

--Calculate Cell expansion
--jcms.zombieCreep_cellAreas = jcms.zombieCreep_cellAreas or {}
jcms.zombieCreep_cellGroundPoints = jcms.zombieCreep_cellGroundPoints or {}
jcms.zombieCreep_cellDepths = jcms.zombieCreep_cellDepths or {}
hook.Add("MapSweepers_MapAnalysisDone", "jcms_ZombieCreep_CalcCellData", function()
	local areaDepths = {}
	local areaDepthCounts = {}

	for i, area in ipairs(jcms.mapdata.validAreas) do 
		-- // Get area AABB {{{
			local minx, miny, minz = math.huge, math.huge, math.huge
			local maxx, maxy, maxz = -math.huge, -math.huge, -math.huge
			for i=1, 4, 1 do 
				local corner = area:GetCorner(i-1) 

				--mins
				minx = math.min(minx, corner.x)
				miny = math.min(miny, corner.y)
				minz = math.min(minz, corner.z)

				--maxs
				maxx = math.max(maxx, corner.x)
				maxy = math.max(maxy, corner.y)
				maxz = math.max(maxz, corner.z)
			end
		-- // }}}

		local cellMinX, cellMinY, cellMinZ = jcms.zombieCreep_GetCellIndices(Vector(minx, miny, minz)) --TODO: Optimise
		local cellMaxX, cellMaxY, cellMaxZ = jcms.zombieCreep_GetCellIndices(Vector(maxx, maxy, maxz))

		--Iterate every cell within our bounds and add ground-points at the centre of each overlap.
		for x=cellMinX, cellMaxX do
			for y=cellMinY, cellMaxY do
				for z=cellMinZ, cellMaxZ do 
					local cell = jcms.zombieCreep_GetCellByIndices(x,y,z)
					local cellStart = jcms.zombieCreep_GetCellPos(cell)
					local cellEnd = cellStart + vecCellSize

					--Overlap Mins/Maxs
					local olMinx, olMiny, olMinz = math.max(minx, cellStart.x), math.max(miny, cellStart.y), math.max(minz, cellStart.z)
					local olMaxx, olMaxy, olMaxz = math.min(maxx, cellEnd.x), math.min(maxy, cellEnd.y), math.min(maxz, cellEnd.z)

					--Middle of our overlap & snap to ground
					local olCentre = Vector((olMinx+olMaxx)/2, (olMiny+olMaxy)/2, (olMinz+olMaxz)/2)
					olCentre.z = area:GetZ(olCentre)

					--TODO: This shouldn't happen.
					if not( jcms.zombieCreep_GetCell(olCentre) == cell ) then continue end

					jcms.zombieCreep_cellGroundPoints[cell] = jcms.zombieCreep_cellGroundPoints[cell] or {}
					table.insert(jcms.zombieCreep_cellGroundPoints[cell], olCentre)

					areaDepths[cell] = areaDepths[cell] or 0
					areaDepthCounts[cell] = areaDepthCounts[cell] or 0

					areaDepths[cell] = areaDepths[cell] + (jcms.mapdata.areaDepths[area] or 0)
					areaDepthCounts[cell] = areaDepthCounts[cell] + 1
				end
			end
		end

		for cell, total in pairs(areaDepths) do 
			jcms.zombieCreep_cellDepths[cell] = total / areaDepthCounts[cell]
		end
	end
end)

--Footsteps
hook.Add( "jcms_PlayerFootsteps", "0jcms_ZombieCreep_Footstep", function( ply, pos, foot, sound, volume, rf )
	local cell = jcms.zombieCreep_GetCell( pos )
	local cellVal = jcms.zombieCreepCells[cell] --Different on client/server ):
	if not(SERVER and IsValid(cellVal) or CLIENT and cellVal) then return end

	if SERVER then
		jcms.director_TryShowTip(ply, jcms.HINT_CREEP)
	end

	if foot == 0 then 	--Left
		ply:EmitSound("Mud.StepLeft")
	else				--Right
		ply:EmitSound("Mud.StepRight")
	end
end )

ENT.BodyTarget = nil
function ENT:jcms_BodyTarget(origin, noisy)
	return self:WorldSpaceCenter()
end

if SERVER then
	jcms.zombieCreepCell_LastDestroyed = jcms.zombieCreepCell_LastDestroyed or {} --Tracking last removal, used to stop instant refilling.

	function ENT:Initialize()
		self:SetPos(self:GetPos() + Vector(0,0,1)) --Explosives don't work right without this

		self:SetMaxHealth(150)
		self:SetHealth(150)

		self.jcms_ignoreStraggling = true
		self.jcms_turretImmune = true

		self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)

		local ed = EffectData()
			ed:SetStart(self:GetPos())
			ed:SetOrigin(self:GetPos())
			ed:SetMagnitude(2)
		util.Effect("jcms_creepexpand", ed)
	
		-- // Cell & Expansion
			local cell = jcms.zombieCreep_GetCell( self:GetPos() )
			if IsValid(jcms.zombieCreepCells[cell]) then							--We're in an occupied cell, don't want to double up, get rid of us.
				self:Remove()
				return
			end

			if not jcms.zombieCreep_cellGroundPoints[cell] then
				self:Remove()
				return
			end
			
			--Set our cell and occupy it.
			self.jcms_zombieCreep_cell = cell
			jcms.zombieCreep_OccupyCell(self.jcms_zombieCreep_cell, self)

			-- // Expansion Cells {{{
				self.adjacentCells = {}
				local x,y,z = jcms.zombieCreep_GetCellIndices( self:GetPos() )
				
				--x
				table.insert(self.adjacentCells, jcms.zombieCreep_GetCellByIndices(x-1,y,z))
				table.insert(self.adjacentCells, jcms.zombieCreep_GetCellByIndices(x+1,y,z))
				
				--y
				table.insert(self.adjacentCells, jcms.zombieCreep_GetCellByIndices(x,y-1,z))
				table.insert(self.adjacentCells, jcms.zombieCreep_GetCellByIndices(x,y+1,z))
				
				--z
				table.insert(self.adjacentCells, jcms.zombieCreep_GetCellByIndices(x,y,z-1))
				table.insert(self.adjacentCells, jcms.zombieCreep_GetCellByIndices(x,y,z+1))
			-- // }}}

			jcms.net_SendCreep(cell, true)

			local nearest, dist = jcms.GetNearestSweeper(self:GetPos())

			self.nextExpansion = CurTime() + math.Rand(0, 2)
		-- // }}}

		self.lastNearPlayer = CurTime()
		self.decayTime = 45 / math.sqrt(#team.GetPlayers(1)) + math.Rand(0,30)
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_NEVER
	end

	--Expansion pulse
	local pulseDuration = 26
	local pulseDelay = 130
	jcms.zombieCreep_isPulsing = false
	timer.Create("jcms_zombieCreep_pulse", pulseDelay, 0, function()
		if jcms.zombieCreep_isPulsing then 
			timer.Adjust("jcms_zombieCreep_pulse", pulseDelay)
			jcms.zombieCreep_isPulsing = false
		else
			timer.Adjust("jcms_zombieCreep_pulse", pulseDuration)
			jcms.zombieCreep_isPulsing = true
		end
	end)

	local npcMins, npcMaxs = Vector(-52,-52,0),Vector(52,52,52)
	function ENT:Think()
		local selfTbl = self:GetTable()
		local cTime = CurTime()

		--Rapid expansion during pulses
		if jcms.zombieCreep_isPulsing and selfTbl.nextExpansion < cTime then --TODO: This gets *crazy* expensive now
			selfTbl.nextExpansion = cTime + 1

			table.Shuffle(self.adjacentCells)
			for i, cell in ipairs(self.adjacentCells) do 
				local cellPoints = jcms.zombieCreep_cellGroundPoints[cell]
				if not cellPoints or #cellPoints == 0 then continue end --Nowhere to put us

				--Not occupied, >30s since it was last cleared.
				if not IsValid(jcms.zombieCreepCells[cell]) and (jcms.zombieCreepCell_LastDestroyed[cell] or 0) + 30 < cTime then 

					--Stop expanding if we're too close to the player. Having creep intrude *into* your nest is annoying, and serves no gameplay purpose.
					local cellPos = jcms.zombieCreep_GetCellPos( cell )
					local nearest, dist = jcms.GetNearestSweeper(cellPos)
					if dist > 850 and dist < 2000 then
						--[[local tr = util.TraceHull({
							mins = npcMins,
							maxs = npcMaxs,
							mask = MASK_NPCSOLID,
							start = cellPos,
							endpos = cellPos
						})

						if not IsValid(tr.Entity) then--]]
							jcms.npc_Spawn("zombie_creep", cellPoints[math.random(#cellPoints)])
							break
						--end
					end
				end
			end

		else
			local nearest, dist = jcms.GetNearestSweeper(self:GetPos())

			if dist < 2500 then
				self.lastNearPlayer = CurTime()
			elseif CurTime() - self.lastNearPlayer > self.decayTime then
				self:Remove()
			end
		end

		self:NextThink(cTime + 2 + math.Rand(0,1)) --Slower update rate, default of 10 times per second is extreme for what we're doing.
	end

	function ENT:OnRemove()
		if self.jcms_zombieCreep_cell then 
			jcms.zombieCreepCell_LastDestroyed[self.jcms_zombieCreep_cell] = CurTime()
			jcms.zombieCrep_ClearCell(self.jcms_zombieCreep_cell)
			
			jcms.net_SendCreep(self.jcms_zombieCreep_cell, false)
			
			local ed = EffectData()
			ed:SetStart(self:GetPos())
			ed:SetOrigin(self:GetPos())
			ed:SetMagnitude(2)
			util.Effect("jcms_creepexpand", ed)
		end
	end
	
	function ENT:OnTakeDamage(dmgInfo)

		--Health deduction & Animation
		local dmg = dmgInfo:GetDamage()
		self:SetHealth(self:Health() - dmg)

		if self:Health() <= 0 then 
			self:Remove()
			hook.Call("OnNPCKilled", GAMEMODE, self, dmgInfo:GetAttacker(), dmgInfo:GetInflictor())
		end
	end

	--Damage Transfer (Explosion)
	hook.Add("jcms_LuaBlastDamage", "jcms_CreepDamage", function(inflictor, attacker, damageOrigin, damageRadius, damage)
		local cell = jcms.zombieCreep_GetCell( damageOrigin )
		local cellOccupier = jcms.zombieCreepCells[cell]
	
		if IsValid(cellOccupier) then 
			local ed = EffectData()
			ed:SetRadius(damageRadius / 2)
			ed:SetOrigin(damageOrigin)
			ed:SetMagnitude(0.3)
			ed:SetFlags(0)
			util.Effect("jcms_bigblast", ed)

			local dmgInfo = DamageInfo()
			dmgInfo:SetDamage(damage)
			dmgInfo:SetDamageType(DMG_BLAST)
			dmgInfo:SetAttacker(attacker)
			dmgInfo:SetInflictor(inflictor)
			cellOccupier:TakeDamageInfo(dmgInfo)
		end
	end)
	hook.Add("jcms_LuaBlastDamageInfo", "jcms_CreepDamage", function(dmgInfo, damageOrigin, damageRadius)
		local cell = jcms.zombieCreep_GetCell( damageOrigin )
		local cellOccupier = jcms.zombieCreepCells[cell]
	
		if IsValid(cellOccupier) then 
			cellOccupier:TakeDamageInfo(dmgInfo)
			
			local ed = EffectData()
			ed:SetRadius(damageRadius / 2 )
			ed:SetOrigin(damageOrigin)
			ed:SetMagnitude(0.3)
			ed:SetFlags(0)
			util.Effect("jcms_bigblast", ed)
		end
	end)
end


if CLIENT then 
	jcms.zombieCreepBoxes = jcms.zombieCreepBoxes or {}
	jcms.zombieCreep_Material = CreateMaterial("jcms_zombieCreep_flesh", "LightmappedGeneric", {
		["$basetexture"] = "models/flesh",
		--["$vertexcolor"] = "1",
		--["$noclamp"] = "1"
		--["$vertexalpha"] = "1",
	})

	local rt = GetRenderTarget("jcms_ZombieCreep_WorldRT", ScrW(), ScrH())
	local drawing = false

	-- // Box Rendering {{{
		--Calculate a list of boxes for zombiecreep using greedy meshing
		hook.Add("jcms_ZombieCreep_RebuildMesh", "jcms_ZombieCreep_RebuildMesh", function()
			jcms.zombieCreepBoxes = {} --Clear, we're about to rebuild.

			local i = jcms.zombieCreepMinCell
			local meshedCells = {}

			local debugSafety = 999999

			while i <= jcms.zombieCreepMaxCell and debugSafety > 0 do
				debugSafety = debugSafety - 1

				if jcms.zombieCreepCells[i] and not meshedCells[i] then --Hit something
					local chunkStart = i --Cell our box starts at
					local chunkEnd

					-- X Expansion {{{
						--Get the end of the current row
						local curRowEnd = (chunkStart - (chunkStart % rowLength)) + rowLength --Floor to start of current row, then add row length. Flooring done wackily because Glua removes //

						--NOTE: "x" and "y" are still just indices, not coordinates. I'm using them to indicate direction of travel.
						local xEnd = chunkStart
						for x=i+1, curRowEnd do --Expand until hitting empty, end of row, or another mesh.
							if not jcms.zombieCreepCells[x] or meshedCells[x] then
								break
							end

							meshedCells[x] = true
							xEnd = x
						end

						local xSpan = xEnd - chunkStart
					-- // }}}

					-- Y Expansion {{{
						local curLayerEnd = (chunkStart - (chunkStart % layerLength)) + layerLength

						--NOTE: "x" and "y" are still just indices, not coordinates. I'm using them to indicate direction of travel.
						local yEnd = xEnd
						for y=i+rowLength, curLayerEnd, rowLength do --Iterate by y, starting on the next row.
							local hit = false
							for x=y, y+xSpan do --Iterate to the edge of the x selection
								if not jcms.zombieCreepCells[x] or meshedCells[x] then
									hit = true
									break
								end
							end
							
							if hit then break end

							for x=y, y+xSpan do --Go back through and mark all of them as meshed
								meshedCells[x] = true
							end
							yEnd = y+xSpan --This row's clear
						end
					
						chunkEnd = yEnd
					-- // }}}

					--We're not going to bother with z, as creep mostly expands horizontally, and vertical meshes will in 99% of cases be small, so expanding up might even make us less efficient.

					local offs = Vector(15, 15, 15) --Z fighting prevention
					local offs2 = Vector(5,5,5) --NearZ clip issue prevention
					--Calculate our mins / maxes for the box
					local mins, maxs = jcms.zombieCreep_GetCellPos(chunkStart) - offs, jcms.zombieCreep_GetCellPos(chunkEnd) + vecCellSize + offs

					--normal mins/maxes, inner mins/maxes, outermins/maxes
					table.insert(jcms.zombieCreepBoxes, {mins, maxs, mins - offs2, maxs + offs2, mins + offs2, maxs - offs2})

					--We still have to check after our mesh's last x, but we can skip a few cells we've already looked at.
					i = xEnd + 1
				else
					i = i + 1
				end
			end
		end)

		local zCreepBoxCol = Color(255, 0, 0, 0)
		function jcms.ZombieCreep_Render(bDrawingDepth, bDrawingSkybox, isDraw3DSkybox)
			if bDrawingDepth or bDrawingSkybox or isDraw3DSkyBox or render.GetRenderTarget() or drawing then return end

			render.SetStencilEnable(true)
			render.ClearStencil()
			render.SetStencilTestMask(255)
			render.SetStencilWriteMask(255)

			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilPassOperation(STENCIL_INCRSAT)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)
			render.SetStencilReferenceValue(1)

			local eyePos = EyePos()

			render.SetColorMaterial()
			for i, box in ipairs(jcms.zombieCreepBoxes) do 
				local mins = box[1]
				local maxs = box[2]
				if  eyePos:WithinAABox( mins, maxs ) then 
					local iMins, iMaxs = box[3], box[4]
					render.SetStencilPassOperation(STENCIL_INCRSAT)
					render.PerformFullScreenStencilOperation()

					render.SetStencilPassOperation(STENCIL_DECRSAT)
					render.DrawBox(jcms.vectorOrigin, angle_zero, iMaxs, iMins, zCreepBoxCol)
				else
					local oMins, oMaxs = box[5], box[6]
					render.SetStencilPassOperation(STENCIL_INCRSAT)
					render.DrawBox(jcms.vectorOrigin, angle_zero, oMins, oMaxs, zCreepBoxCol)
					
					render.SetStencilPassOperation(STENCIL_DECRSAT)
					render.DrawBox(jcms.vectorOrigin, angle_zero, oMaxs, oMins, zCreepBoxCol)
				end
			end

			
			render.SetStencilReferenceValue(1)
			render.SetStencilCompareFunction(STENCIL_LESSEQUAL)
			render.DrawTextureToScreen( rt )

			render.SetStencilEnable( false )
			render.ClearStencil()
		end
	-- // }}}

	-- // World Render {{{
		function jcms.zombieCreep_DrawWorld()
			if drawing then return end

			render.PushRenderTarget(rt)
			render.WorldMaterialOverride(jcms.zombieCreep_Material)
			render.BrushMaterialOverride(jcms.zombieCreep_Material)
				drawing = true

				render.SuppressEngineLighting( true )
				render.Clear( 0,0,0,0, false, false)

				render.RenderView({
					drawviewmodel = false,
					drawhud = false, 
					drawmonitors =  false,
					drawviewer = false,	
				})

				drawing = false
				render.SuppressEngineLighting( false )

			render.BrushMaterialOverride()
			render.WorldMaterialOverride()
			render.PopRenderTarget()
		end

		hook.Add("PreDrawTranslucentRenderables", "0jcms_worldRender_Suppress", function()
			if drawing then return true end
		end)

		hook.Add("PreDrawOpaqueRenderables", "0jcms_worldRender_Suppress", function()
			if drawing then return true end
		end)

		hook.Add("PreDrawSkyBox", "0jcms_worldRender_Suppress", function()
			if drawing then return true end
		end)
	-- // }}}
end
