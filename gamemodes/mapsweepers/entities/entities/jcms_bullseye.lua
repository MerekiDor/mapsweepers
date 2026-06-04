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
ENT.PrintName = "Bullseye"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

jcms.team_jCorpClasses["jcms_bullseye"] = true

if SERVER then 
	--ENT.DamageTarget = NULL

	function ENT:Initialize()
		self:SetModel("models/hunter/blocks/cube025x025x025.mdl") --maybe even models/hunter/plates/plate.mdl
		self:PhysicsInitSphere(1)
		self:SetMoveType(MOVETYPE_NONE)

		--So that we actually get targeted.
		self:SetMaxHealth(1)
		self:SetHealth(1)

		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	end

	function ENT:OnTakeDamage(dmgInfo)
		if not IsValid(self.DamageTarget) then 
			self:Remove()
			return
		end

		self.DamageTarget:TakeDamageInfo(dmgInfo)
	end
end

if CLIENT then
	function ENT:Think()
		self:DestroyShadow()
	end

	function ENT:Draw()
		
	end
end

