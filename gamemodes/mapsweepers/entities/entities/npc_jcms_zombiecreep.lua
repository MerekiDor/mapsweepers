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

	local cellWidth = 512
	local cellHeight = 256

	local rowLength = math.ceil(32768 / cellWidth) --How many indices are there for each complete line of x/y values? 
	local layerLength = rowLength^2
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
		jcms.zombieCreepCells[self.jcms_zombieCreep_cell] = true

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
		if table.Count(self.expansionPoints) > 0 and self.nextExpansion < CurTime() then
			--Spawn another creeper at the first available cell.
			for cell, pos in pairs(self.expansionPoints) do 
				if not jcms.zombieCreepCells[cell] then
					jcms.npc_Spawn("zombie_creep", pos)
					break
				end
			end
			self.nextExpansion = CurTime() + 15 * math.sqrt(#ents.FindByClass("npc_jcms_zombiecreep"))
		end
	end

	function ENT:OnRemove()
		jcms.zombieCreepCells[self.jcms_zombieCreep_cell] = nil
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
	function ENT:Initialize()
		local cell = jcms.zombieCreep_GetCell( self:GetPos() )
		self.boxPos = jcms.zombieCreep_GetCellPos(cell)
		self.boxMins = Vector(0,0,0)
		self.boxMaxs = Vector(cellWidth, cellWidth, cellHeight)

		self:SetRenderBoundsWS(self.boxPos, self.boxPos + self.boxMaxs)
	end

	function ENT:DrawTranslucent()
		--TODO: PLACEHOLDER, HERE FOR PROTOTYPING

		render.SetColorMaterial()
		render.DrawBox(self.boxPos, angle_zero, self.boxMins, self.boxMaxs, Color(255, 0, 0, 25))
		render.DrawBox(self.boxPos, angle_zero, self.boxMaxs, self.boxMins, Color(255, 0, 0, 25))

		--jcms.render_JammerSphere( self:GetPos(), 750 )
		--render.DrawSphere( self:GetPos(), number radius, number longitudeSteps, number latitudeSteps, Color color = Color( 255, 255, 255 ) )
	end
end