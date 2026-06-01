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
ENT.PrintName = "Terminal"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

jcms.terminal_modelInfos = {
	["models/props_combine/breenconsole.mdl"] = {
		theme = "combine",
		width = 500,
		height = 500,
		up = 44,
		right = 2,
		fwd = -9,
		rotateFwd = 40
	},

	["models/props_combine/combine_interface001.mdl"] = {
		theme = "combine",
		width = 600,
		height = 500,
		up = 51,
		right = 11,
		fwd = -1,
		rotateRight = -45,
		rotateUp = 90,
	},
	
	["models/props_combine/masterinterface.mdl"] = {
		theme = "combine",
		width = 1300,
		height = 600,
		up = 48,
		right = 21,
		fwd = -10,
		rotateRight = -45,
		rotateUp = 90,
	},
	
	["models/props_combine/combine_emitter01.mdl"] = {
		theme = "jcorp",
		width = 500,
		height = 500,
		up = 16,
		right = -8,
		fwd = 8,
		rotateRight = -40,
		rotateUp = -90
	},
	
	["models/props_wasteland/laundry_washer003.mdl"] = {
		theme = "rebel",
		width = 800,
		height = 500,
		up = 24,
		right = -4,
		fwd = -4,
		rotateFwd = -40,
		rotateUp = 180
	},

	["models/props_combine/combine_intwallunit.mdl"] = {
		theme = "combine",
		width = 500,
		height = 660,
		up = 14,
		right = 2,
		fwd = 4.5,
		rotateRight = -90,
		rotateUp = 90
	},

	["models/props_lab/hev_case.mdl"] = {
		theme = "rebel",
		width = 800,
		height = 512,
		up = 55,
		right = 16,
		fwd = 18,
		rotateRight = -50,
		rotateUp = 90
	},

	["models/props_combine/combine_interface002.mdl"] = {
		theme = "combine",
		width = 500,
		height = 500,
		up = 44,
		right = 9,
		fwd = 6,
		rotateUp = 90,
		rotateRight = -40
	},

	["models/jcms/rgg_node.mdl"] = {
		theme = "rebel",
		width = 500,
		height = 500,
		up = 42,
		right = 8,
		fwd = 15,
		rotateUp = 90,
		rotateRight = -40
	},

	["models/props_c17/cashregister01a.mdl"] = {
		theme = "rebel",
		width = 720,
		height = 600,
		up = 13,
		right = 0,
		fwd = 14,
		rotateUp = 180,
		rotateFwd = -60
	},

	["models/jcms/mafia_locker.mdl"] = {
		theme = "antlion",
		width = 1000,
		height = 700,
		up = 12,
		right = 15,
		fwd = 13,
		rotateUp = 90,
		rotateRight = -90
	},

	["models/props_combine/combinebutton.mdl"] = {
		theme = "jcorp",
		width = 720,
		height = 480,
		up = 8,
		right = 10,
		fwd = 5,
		rotateUp = 90,
		rotateRight = -48
	}
}

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/props_combine/breenconsole.mdl")
		self:PhysicsInitStatic(SOLID_VPHYSICS)
	end
end

if SERVER then
	function ENT:InitAsTerminal(mdl, purpose, linkCallback)
		self.jcms_validTerminal = true
		self:SetModel(mdl)
		self:PhysicsInitStatic(SOLID_VPHYSICS)

		local info = jcms.terminal_modelInfos[ mdl ]
		jcms.terminal_Setup(self, purpose, info and info.theme)
		self.jcms_terminal_Callback = linkCallback or function() return "" end
	end

	function ENT:Think()
		if not self.jcms_validTerminal then
			self:Remove()
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

			local info = jcms.terminal_modelInfos[ self:GetModel() ]
			
			local width, height = 512, 512
			if info then
				width, height = info.width, info.height
				local fwd, right, up = ang:Forward(), ang:Right(), ang:Up()
				ang:RotateAroundAxis(up, info.rotateUp or 0)
				ang:RotateAroundAxis(right, info.rotateRight or 0)
				ang:RotateAroundAxis(fwd, info.rotateFwd or 0)

				fwd:Mul(info.fwd or 0)
				right:Mul(info.right or 0)
				up:Mul(info.up or 0)

				pos:Add(fwd)
				pos:Add(right)
				pos:Add(up)

				jcms.terminal_Render(self, pos, ang, width, height)
			end
		end
	end
end
