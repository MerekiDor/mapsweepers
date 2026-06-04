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
ENT.PrintName = "Shop"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/props_wasteland/kitchen_fridge001a.mdl")
		self:SetColor(Color(255, 64, 64))
		self:PhysicsInitStatic(SOLID_VPHYSICS)
		jcms.terminal_Setup(self, "shop", "jcorp")
		self.jcms_hackType = nil
	end
end

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "GunPriceMul")
    self:NetworkVar("Float", 0, "AmmoPriceMul")

    if SERVER then
        self:SetGunPriceMul(1)
        self:SetAmmoPriceMul(0.5)
    end
end

if SERVER then
	sound.Add( {
		name = "jcms_shop_idle",
		channel = CHAN_STATIC,
		volume = 1.0,
		level = 90,
		pitch = 110,
		sound = {
			"ambient/machines/combine_terminal_idle2.wav",
			"ambient/machines/combine_terminal_idle1.wav"
		}
	} )
	
	function ENT:Think()
		if not self.nextIdleSound or CurTime() > self.nextIdleSound then
			self.nextIdleSound = CurTime() + 6
			self:EmitSound("jcms_shop_idle")
		end
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end
	
	function ENT:DrawTranslucent(flags)
		if bit.band(flags, STUDIO_RENDER) then
			local pos, ang = self:GetPos(), self:GetAngles()
			local angUp = ang:Up()

			pos:Add(angUp*80)
			pos:Add(ang:Forward()*25.2)
			pos:Add(ang:Right()*27)
			ang:RotateAroundAxis(angUp, 90)
			ang:RotateAroundAxis(ang:Forward(), 90)

			local w, h = 1730, 1200
			local rendered = jcms.terminal_Render(self, pos, ang, w, h)

			if rendered == false then
				cam.Start3D2D(pos, ang, 1/32)
				local color_bg, color_fg, color_accent = jcms.terminal_GetColors(self)
					surface.SetDrawColor(color_bg)
					surface.SetDrawColor(color_bg.r/3, color_bg.g/3, color_bg.b/3)
					surface.DrawRect(0, 0, w, h)
					
					surface.SetDrawColor(color_fg)
					surface.DrawOutlinedRect(0, 0, w, h, 12)
				cam.End3D2D()
			end
		end
	end
end
