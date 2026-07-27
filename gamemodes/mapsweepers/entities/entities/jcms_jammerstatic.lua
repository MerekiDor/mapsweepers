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
	self:NetworkVar("Float", 0, "NextStateSwitch")

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
	ENT.SwitchInterval = 120 --scripted_ents.GetMember("jcms_mainframe", "JammerSwitchInterval") --This causes load-order issues, hardcoded for now.
	
	ENT.chargebarRT = GetRenderTarget("jcms_jammerpillarchargebar_rt", 8, 200)
	ENT.chargebarRTMat = CreateMaterial("jcms_jammerpillarchargebar", "VertexLitGeneric", {
		["$basetexture"] = ENT.chargebarRT:GetName(),
		["$pointsamplemagfilter"] = 1,
		["$selfillum"] = 1
	})

	function ENT:Initialize()
		self:SetRenderBounds(jcms.vectorOrigin, jcms.vectorOrigin, Vector(self.JammingRadius, self.JammingRadius, self.JammingRadius) )
	end

	function ENT:RenderScreen()
		local timeFrac = (self:GetNextStateSwitch() - CurTime()) / self.SwitchInterval
		local barHeight = math.Round(timeFrac*200)

		render.PushRenderTarget(self.chargebarRT)
		cam.Start2D()
		
			if timeFrac < 0 and (CurTime()+0.03)%0.5<0.25 then 
				surface.SetDrawColor(99, 53, 0)
				surface.DrawRect(0, 0, 8, 200, 1)

				surface.SetDrawColor(252, 255, 82)
				surface.DrawRect(0, 0, 8, 200, 1)

				surface.SetDrawColor(255, 211, 13)
				surface.DrawOutlinedRect(0, 0, 8, 200, 1)	
			else
				if self:GetIsActive() then
					surface.SetDrawColor(81, 0, 99)
				else
					surface.SetDrawColor(15, 0, 99)
				end
				surface.DrawRect(0, 0, 8, 200 - barHeight, 1)
	
				if self:GetIsActive() then
					surface.SetDrawColor(185, 99, 255)
				else
					surface.SetDrawColor(99, 255, 247)
				end
				
				surface.DrawRect(0, 200 - barHeight, 8, barHeight, 1)
				if self:GetIsActive() then
					surface.SetDrawColor(238, 108, 255)
				else
					surface.SetDrawColor(108, 135, 255)
				end
				surface.DrawOutlinedRect(0, 200 - barHeight, 8, barHeight, 1)	
			end
		cam.End2D()
		render.PopRenderTarget()
	end

	function ENT:Draw()
		self:RenderScreen()
		render.MaterialOverrideByIndex(1, self.chargebarRTMat)
		self:DrawModel()
		render.MaterialOverrideByIndex()
	end

	function ENT:DrawTranslucent()
		if self:GetIsActive() then
			self:DrawStaticOverlay()
		end
	end

	function ENT:DrawStaticOverlay()
		jcms.render_JammerSphere( self:GetPos(), self.JammingRadius )
	end
end