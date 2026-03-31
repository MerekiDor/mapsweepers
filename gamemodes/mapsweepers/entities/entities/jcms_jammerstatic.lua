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
ENT.PrintName = "RGG Jammer Pillar"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.JammingRadius = 750
ENT.JammingTime = 2

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsActive")

	self:NetworkVarNotify("IsActive", function(ent, name, old, new )
		if old == new then return end

		if new then
			ent:EmitSound("outland_10.shieldwall_on")
		else
			ent:EmitSound("outland_10.shieldwall_off")
		end
	end)
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/jcms/jcorp_downloadpillar.mdl")
		self:PhysicsInitStatic(SOLID_VPHYSICS)
	end
	
	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:Think()
		local selfPos = self:WorldSpaceCenter()

		if self:GetIsActive() then
			for i, target in ipairs(ents.FindInSphere( selfPos, self.JammingRadius )) do
				if IsValid(target) and target.JCMS_Stunnable and jcms.team_JCorp_ent(target) then
					if not target.jcms_stunEnd or target.jcms_stunEnd < CurTime() then
						local ed = EffectData()
						ed:SetMagnitude(1.5)
						ed:SetOrigin(target:WorldSpaceCenter())
						ed:SetRadius(50)
						ed:SetNormal(jcms.vectorUp)
						ed:SetFlags(5)
						ed:SetColor( jcms.util_ColorIntegerFast(230, 185, 255) )
						util.Effect("jcms_blast", ed)

						local ed = EffectData()
						ed:SetFlags(3)
						ed:SetEntity(target)
						ed:SetOrigin(selfPos)
						util.Effect("jcms_chargebeam", ed)

						target:EmitSound("NPC_Turret.Die")
					end

					local ed = EffectData()
					ed:SetScale(self.JammingTime + 0.5)
					ed:SetMagnitude( 0.2 * 512)
					ed:SetEntity(target)
					util.Effect("jcms_teslahitboxes_dur", ed)

					target.jcms_stunEnd = CurTime() + self.JammingTime
				end
			end
		end

		self:NextThink(CurTime() + 1)
		return true
	end
end

if CLIENT then
	ENT.mat_noise = Material "jcms/noise.png"

	function ENT:Initialize()
		self:SetRenderBounds(jcms.vectorOrigin, jcms.vectorOrigin, Vector(self.JammingRadius, self.JammingRadius, self.JammingRadius) )
	end

	function ENT:DrawTranslucent()
		if self:GetIsActive() then
			self:DrawStaticOverlay()
		end
	end

	--TODO: Would be nice if progress until we activate/deactivate was displayed in the same manner as datadownload HP
	function ENT:DrawStaticOverlay()
		render.SetStencilEnable(true)
		render.ClearStencil()
		render.SetStencilTestMask(255)
		render.SetStencilWriteMask(255)

		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		render.SetStencilPassOperation(STENCIL_REPLACE)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)
		render.SetStencilReferenceValue(1)
		
		render.OverrideBlend(true, BLEND_ZERO, BLEND_ONE, BLENDFUNC_ADD)

		local selfPos = self:GetPos()
		local range = self.JammingRadius
		if EyePos():DistToSqr(selfPos) > range^2 then 
			render.SetColorMaterial()
			render.DrawSphere(selfPos, range, 22, 22, color_white)
			
			render.SetStencilReferenceValue(0)
			render.SetStencilPassOperation(STENCIL_REPLACE)
			render.DrawSphere(selfPos, -range, 22, 22, color_white)
		else
			render.ClearStencilBufferRectangle( 0,0, ScrW(), ScrH(), 1 )

			render.SetStencilReferenceValue(0)
			render.SetStencilPassOperation(STENCIL_REPLACE)

			render.SetColorMaterial()
			render.DrawSphere(selfPos, -range, 22, 22, color_white)
		end
		
		render.OverrideBlend(false)
		
		render.SetStencilCompareFunction(STENCIL_EQUAL)
		render.SetStencilReferenceValue(1)

		render.OverrideBlend(true, BLEND_ONE, BLEND_ONE, BLENDFUNC_ADD)
			cam.Start2D()
				surface.SetMaterial(self.mat_noise)
				surface.SetDrawColor(220/2, 180/2, 250/2)
				jcms.hud_DrawNoiseRect(0, 0, ScrW(), ScrH())
			cam.End2D()
		render.OverrideBlend(false)
		
		render.SetStencilEnable( false )
		render.ClearStencil()
	end
end