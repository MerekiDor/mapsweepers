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
ENT.PrintName = "Vanguard Backpack"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/props_combine/combine_light002a.mdl")
		self:SetColor(Color(255, 200, 81))
		self:PhysicsInitStatic(SOLID_VPHYSICS)
		
		self:SetMaxHealth(75)
		self:SetHealth(75)

		self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER )
		self:SetModelScale(0.75)
	end
end

if SERVER then
	function ENT:Use(activator, caller, useType, value)
		local parent = self:GetParent()
		if not IsValid(parent) and IsValid(activator) and activator:IsPlayer() and jcms.team_JCorp_player(activator) then
			activator:PickupObject(self)
		end
	end

	function ENT:FallOff()
		self:SetParent()
		self:SetOwner()
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetHealth(math.min(self:Health(), 5))
	end
	
	function ENT:Explode(attacker)
		if self.jcms_exploded then return end
		self.jcms_exploded = true

		local pos = self:WorldSpaceCenter()
		util.BlastDamage(self, attacker or self, pos, 255, 50)

		if IsValid(self.jcms_owner) then
			self.jcms_owner:TakeDamage(50, attacker or self, self)
		end

		local ed = EffectData()
		ed:SetOrigin(self:GetPos())
		ed:SetNormal(vector_up)
		util.Effect("Explosion", ed)

		self:Remove()

		for i, ent in ipairs( ents.FindInSphere(pos, 512) ) do
			if jcms.team_NPC(ent) and ent:Health() > 0 then
				ent:Ignite(5, 0)
			end
		end
	end

	function ENT:OnTakeDamage(dmg)
		if self.jcms_exploded then return end
		self:SetHealth(self:Health() - dmg:GetDamage())

		if self:Health() <= 0 then
			self:Explode(dmg:GetAttacker())
		else
			if self:Health() < self:GetMaxHealth()*0.42 then
				self:Ignite(5)
			end

			local ed = EffectData()
			ed:SetEntity(self)
			ed:SetScale(50)
			ed:SetColor(6)
			ed:SetOrigin(dmg:GetDamagePosition())
			util.Effect("BloodImpact", ed)
		end

		return 0
	end
end