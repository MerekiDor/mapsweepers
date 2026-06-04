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
ENT.PrintName = "Breakable Object"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false

function ENT:Initialize()
	if SERVER then
		self:PhysicsInitStatic(SOLID_VPHYSICS)
		self:AddEFlags(EFL_DONTBLOCKLOS)
		self.breakStages = self.breakStages or {}
	end
end

if SERVER then
	ENT.DmgMul = 1
	ENT.DmgReduction = 0

	function ENT:OnTakeDamage(dmg)
		dmg:SetDamage( math.max(dmg:GetDamage() * self.DmgMul - self.DmgReduction, 0) )
		self:TakePhysicsDamage(dmg)
		
		self:SetHealth( self:Health() - dmg:GetDamage() )
		local newHealth = self:Health()

		if newHealth <= 0 then
			self:Remove()
		else
			for i, stage in ipairs(self.breakStages) do
				if newHealth <= stage.health then
					self:SetModel(stage.mdl)
					break
				end
			end
		end
	end
end

if CLIENT then
	function ENT:Draw(flags)
		self:DrawModel()
	end
end
