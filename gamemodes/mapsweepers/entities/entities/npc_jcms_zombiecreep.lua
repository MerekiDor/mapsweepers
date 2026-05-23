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
ENT.PrintName = "Zombie Creep"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH


-- // Cell stuff {{{
	jcms.zombieCreepCells = jcms.zombieCreepCells or {}

	-- // Cell Grid Definitions
		local cellWidth = 512
		local cellHeight = 256

		local rowLength = math.ceil(32768 / cellWidth) --How many indices are there for each complete line of x/y values? 
		local layerLength = rowLength^2 --How many for a single z layer?
		local totalLength = layerLength * math.ceil(32768 / cellHeight) --Max index of the table
	-- // }}}
	
	--Optimisation - tracking the start/end so we don't have to check a ton of empty spots each rebuild.
	jcms.zombieCreepMinCell = jcms.zombieCreepMinCell or totalLength
	jcms.zombieCreepMaxCell = jcms.zombieCreepMaxCell or 1

	-- // Getters {{{
		function jcms.zombieCreep_GetCell( pos )
			local xIndex = math.floor((pos.x + 16384) / cellWidth, 0)
			local yIndex = math.floor((pos.y + 16384) / cellWidth, 0)
			local zIndex = math.floor((pos.z + 16384) / cellHeight, 0)

			return xIndex + (rowLength * yIndex) + (layerLength * zIndex)
		end

		function jcms.zombieCreep_GetCellPos( cell )
			local zRemainder = cell % layerLength
			local yRemainder = zRemainder % rowLength

			local xIndex = yRemainder
			local yIndex = (zRemainder - yRemainder) / rowLength
			local zIndex = (cell - zRemainder) / layerLength

			return Vector((xIndex * cellWidth) - 16384, (yIndex * cellWidth)  - 16384, (zIndex * cellHeight) - 16384)
		end
	-- // }}}

	-- // Setters {{{
		function jcms.zombieCreep_OccupyCell( cell )
			--Update min/max cells
			if cell > jcms.zombieCreepMaxCell then
				jcms.zombieCreepMaxCell = cell
			end
			if cell < jcms.zombieCreepMinCell then 
				jcms.zombieCreepMinCell = cell
			end

			--Mark us
			jcms.zombieCreepCells[cell] = true
		end

		function jcms.zombieCrep_ClearCell( cell )
			--I was going to recalc max/min here, but that's probably not necessary. If it *is* it should probably be done in the rebuild anyway since it'll be expensive.
			jcms.zombieCreepCells[cell] = nil
		end
	-- // }}}

	if SERVER then --TODO: Shared for prediction
		hook.Add("SetupMove", "jcms_ZombieCreep_Snare", function(ply, mv, cmd)
			local cell = jcms.zombieCreep_GetCell( ply:GetPos() )
			if not jcms.zombieCreepCells[cell] then return end
			if not ply:IsOnGround() then return end

			mv:SetMaxClientSpeed(150)
		end)
	end
-- // }}}

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/barnacle.mdl")
		self:SetSubMaterial(0, "models/jcms/zombiepolyp/polyp_base")
		self:SetAngles( Angle(0, 0, 180) )

		self:PhysicsInitBox( Vector(-52,-52,0),Vector(52,52,52) )
		self:SetMoveType(MOVETYPE_NONE)
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

		local selfCentre = self:WorldSpaceCenter()
		for i=13, 20, 1 do 
			self:ManipulateBoneScale( i, vector_origin )
			self:ManipulateBonePosition( i, selfCentre )
		end
		self:SetBloodColor(BLOOD_COLOR_ANTLION)
		
		self:SetMaxHealth(75)
		self:SetHealth(75)

		self.jcms_ignoreStraggling = true
	
		self.jcms_zombieCreep_cell = jcms.zombieCreep_GetCell( self:GetPos() )
		jcms.zombieCreep_OccupyCell(self.jcms_zombieCreep_cell)

		-- // Expansion Cell detection {{{
			local ourArea = navmesh.GetNearestNavArea(self:GetPos())
			local selfZone = jcms.mapgen_ZoneDict()[ourArea]

			local nearbyAreas = jcms.director_GetAreasAwayFrom(jcms.mapgen_ZoneList()[selfZone], {self:GetPos()}, 0, cellWidth * 1.5)
			local adjacentCellDict = {}

			table.Shuffle(nearbyAreas)
			for i, area in ipairs(nearbyAreas) do
				if area:IsPotentiallyVisible( ourArea ) then --Stops us going through walls/rooves
					local areaCentre = area:GetCenter()
					local cell = jcms.zombieCreep_GetCell(areaCentre)
					adjacentCellDict[cell] = areaCentre
				end
			end

			--TODO: More than one point per navarea (big ones cause problems)
			self.expansionPoints = adjacentCellDict
			self.expansionPoints[self.jcms_zombieCreep_cell] = nil --Ignore our own cell (optimisation)
		-- // }}}

		self.nextExpansion = CurTime() + 10 + #ents.FindByClass("npc_jcms_zombiecreep") + math.Rand(0, 10) --30
		self:SetPos(self:GetPos() + Vector(0,0,1)) --Explosives don't work right without this

		--TODO: Give us some bullseyes so that explosives clear us easier
	end

	function ENT:Think()
		local selfTbl = self:GetTable()
		local cTime = CurTime()

		if selfTbl.nextExpansion < cTime and table.Count(selfTbl.expansionPoints) > 0 then
			--Spawn another creeper at the first available cell.
			for cell, pos in pairs(selfTbl.expansionPoints) do 
				if not jcms.zombieCreepCells[cell] then
					jcms.npc_Spawn("zombie_creep", pos)
					break
				end
			end
			selfTbl.nextExpansion = cTime + 15 * math.sqrt(#ents.FindByClass("npc_jcms_zombiecreep"))
		end

		self:NextThink(cTime + 1) --Slower update rate, default of 10 times per second is extreme for what we're doing.
	end

	function ENT:OnRemove()
		jcms.zombieCrep_ClearCell(self.jcms_zombieCreep_cell)
	end
	
	function ENT:OnTakeDamage(dmgInfo)
		-- // Scaling {{{
			local inflictor = dmgInfo:GetInflictor()
			if IsValid(inflictor) and jcms.util_IsStunstick(inflictor) then 
				dmgInfo:ScaleDamage(4)
			end
		-- // }}}

		--Health deduction & Animation
		local dmg = dmgInfo:GetDamage()
		self:SetHealth(self:Health() - dmg)

		if self:Health() <= 0 then 
			self:Remove()
		end
	end
end


if CLIENT then 
	jcms.zombieCreepBoxes = jcms.zombieCreepBoxes or {}
	local vecCellSize = Vector(cellWidth, cellWidth, cellHeight)

	function ENT:Initialize()
		self.jcms_zombieCreep_cell = jcms.zombieCreep_GetCell( self:GetPos() )
		jcms.zombieCreep_OccupyCell(self.jcms_zombieCreep_cell)

		hook.Call("jcms_ZombieCreep_RebuildMesh")
	end

	function ENT:OnRemove()
		jcms.zombieCrep_ClearCell(self.jcms_zombieCreep_cell)
		hook.Call("jcms_ZombieCreep_RebuildMesh")
	end

	function ENT:Draw()
		local dist = jcms.EyePos_lowAccuracy:DistToSqr(self:WorldSpaceCenter())
		if dist < 2000^2 then 
			self:DrawModel()
		end
	end

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
								
				--table.insert(jcms.zombieCreepBoxes, {chunkStart, chunkEnd})

				--Calculate our mins / maxes for the box
				table.insert(jcms.zombieCreepBoxes, {jcms.zombieCreep_GetCellPos(chunkStart), jcms.zombieCreep_GetCellPos(chunkEnd) + vecCellSize})
				--We still have to check after our mesh's last x, but we can skip a few cells we've already looked at.
				i = xEnd + 1
			else
				i = i + 1
			end
		end
	end)


	local zCreepBoxCol = Color(255, 0, 0, 25)
	hook.Add("PostDrawTranslucentRenderables", "jcms_ZombieCreep_Render", function(bDrawingDepth, bDrawingSkybox, isDraw3DSkybox)
		if bDrawingDepth or bDrawingSkybox or isDraw3DSkyBox then return end

		render.SetColorMaterial()
		for i, box in ipairs(jcms.zombieCreepBoxes) do 
			local mins = box[1]
			local maxs = box[2]

			render.DrawBox(jcms.vectorOrigin, angle_zero, mins, maxs, zCreepBoxCol)
			render.DrawBox(jcms.vectorOrigin, angle_zero, maxs, mins, zCreepBoxCol)
		end
	end)
end
