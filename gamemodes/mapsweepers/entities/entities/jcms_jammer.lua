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
ENT.PrintName = "RGG Jammer"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.JammingRadius = 750
ENT.JammingTime = 2

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/jcms/rgg_dish.mdl")
		self:PhysicsInitStatic(SOLID_VPHYSICS)

		self:SetMaxHealth(350)
		self:SetHealth(350)

		local filter = RecipientFilter()
		filter:AddAllPlayers()
		self:EmitSound( "ambient/levels/citadel/datatransmission04_loop.wav", 75, 100, 0.75, CHAN_AUTO, 0, 0, filter )
		self:EmitSound( "ambient/machines/power_transformer_loop_2.wav", 75, 100, 1, CHAN_AUTO, 0, 0, filter )
	end

	function ENT:OnRemove()
		self:StopSound( "ambient/levels/citadel/datatransmission04_loop.wav" )
		self:StopSound( "ambient/machines/power_transformer_loop_2.wav" )
	end
	
	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:Think()
		if self:Health() <= 0 then return end
		local selfPos = self:WorldSpaceCenter()

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

		self:NextThink(CurTime() + 1)
		return true
	end

	function ENT:OnTakeDamage(dmg)
		self:SetHealth(self:Health() - dmg:GetDamage())
		
		local ed = EffectData()
		ed:SetOrigin(dmg:GetDamagePosition())
		ed:SetNormal( (dmg:GetDamagePosition() - self:WorldSpaceCenter()):GetNormalized() )
		util.Effect("MetalSpark", ed)

		self:EmitSound("Computer.BulletImpact")
		
		if self:Health() <= 0 then
			local pos = self:WorldSpaceCenter()
			local ed = EffectData()
			ed:SetMagnitude(1)
			ed:SetOrigin(pos)
			ed:SetRadius(140)
			ed:SetNormal(self:GetAngles():Up())
			ed:SetFlags(5)
			ed:SetColor( jcms.util_ColorIntegerFast(185, 220, 255) )
			util.Effect("jcms_blast", ed)
			util.Effect("Explosion", ed)
			self:Remove()
		end
	end
end

if CLIENT then
	function ENT:Initialize()
		self:SetRenderBounds(jcms.vectorOrigin, jcms.vectorOrigin, Vector(self.JammingRadius, self.JammingRadius, self.JammingRadius) )
	end

	function ENT:DrawTranslucent()
		if math.random() > math.sqrt(self:Health() / self:GetMaxHealth()) then
			jcms.render_HackedByRebels(self)
		end

		self:DrawStaticOverlay()
	end

	
	function ENT:DrawStaticOverlay()
		jcms.render_JammerSphere( self:GetPos(), self.JammingRadius )
	end
end