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
ENT.PrintName = "Smoke Grenade"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/weapons/w_eq_smokegrenade.mdl")
		self:PhysicsInitSphere(2, "metal")
		self:GetPhysicsObject():Wake()
	end
	
	self:DrawShadow(false)
end

if SERVER then
	function ENT:PhysicsCollide(data, collider)
		self:ExplodeSmoke()
	end
	
	function ENT:ExplodeSmoke()
		self:EmitSound("weapons/flaregun/fire.wav", 120, 95)
		local ed = EffectData()
		ed:SetMagnitude(10)
		ed:SetOrigin(self:WorldSpaceCenter())
		ed:SetNormal(self:GetAngles():Up())
		ed:SetRadius(350)
		ed:SetFlags(3)
		ed:SetColor(jcms.util_ColorInteger(Color(200, 200, 200, 255)))
		util.Effect("jcms_blast", ed)
		self:Remove()
		
		if jcms.smokeScreens then
			table.insert(jcms.smokeScreens, { pos = self:WorldSpaceCenter(), rad = 340, expires = CurTime() + 9 }) 
		end
	end
end
