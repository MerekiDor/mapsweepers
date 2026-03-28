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

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Decorator"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH


function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "RenderType")
end

if SERVER then
	function ENT:Initialize() 
		self:SetMoveType(MOVETYPE_NONE)
	end

	function ENT:SetupAsBoneFollower(target, bone, rotation)
		self:FollowBone(target, bone)

		local pos, ang = target:GetBonePosition( bone )

		local rotMat = Matrix() 
		rotMat:Rotate(ang)
		rotMat:Rotate(rotation or angle_zero)

		self:SetAngles(rotMat:GetAngles())
		self:SetPos(pos)
	end
end

if CLIENT then
	ENT.mat_glow = Material "sprites/light_glow02_add"
	ENT.mat_glow2 = Material "particle/Particle_Glow_04"

	local renderTypes = {
		[1] = function(self, flags)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				render.SetMaterial(self.mat_glow2)
				render.DrawSprite(self:GetPos(), 16, 16, Color(143, 67, 229))
			render.OverrideBlend( false )
		end,
	}

	function ENT:Initialize()
		self:SetPredictable(true)

		local renderType = self:GetRenderType()
		if renderType > 0 then
			self.DrawTranslucent = renderTypes[renderType]
		end
	end
end

