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
ENT.PrintName = "Datapad"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "PickedOnce")
end

function ENT:Initialize()
	self:SetModel("models/jcms/jcorp_datapad.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)

	if SERVER then
		self:AddEFlags(EFL_DONTBLOCKLOS)
		self:SetUseType(SIMPLE_USE)

		self.lightglow = ents.Create("env_lightglow")
		self.lightglow:SetPos(self:WorldSpaceCenter())
		self.lightglow:SetParent(self)
		self.lightglow:SetKeyValue("rendercolor", "255 32 32")
		self.lightglow:SetKeyValue("VerticalGlowSize", 10)
		self.lightglow:SetKeyValue("HorizontalGlowSize", 24)
		self.lightglow:SetKeyValue("MinDist", 50)
		self.lightglow:SetKeyValue("MaxDist", 300)
		self.lightglow:SetKeyValue("OuterMaxDist", 1000)
		self.lightglow:Spawn()

		self.receivedSteamID64s = {}
	end
end

if SERVER then
	ENT.CarryAngles = Angle(180, 90, -110)

	function ENT:Use(activator)
		if IsValid(activator) and activator:IsPlayer() and jcms.team_JCorp_player(activator) then
			activator:PickupObject(self)

			if IsValid(self.lightglow) then
				self.lightglow:Remove()
			end

			if not self:GetPickedOnce() then
				self:EmitSound("npc/dog/dogphrase16.wav", 100, 133, 1)
				self:SetPickedOnce(true)

				timer.Simple(0.75, function()
					if IsValid(self) then
						self:EmitSound("buttons/blip2.wav", 100, 167)
					end
				end)

				jcms.giveCash(activator, 50)
			end

			local sid64 = activator:SteamID64()
			if not self.receivedSteamID64s[ sid64 ] then
				self.receivedSteamID64s[ sid64 ] = true
				activator:SendLua("jcms.codex_UnlockRandomLog()")
			end
		end
	end

	function ENT:GetPreferredCarryAngles(ply)
		return self.CarryAngles
	end

	function ENT:OnTakeDamage(dmg)
		self:TakePhysicsDamage(dmg)
	end

	function ENT:PhysicsCollide(colData, collider)
		if colData.Speed > 100 then
			self:EmitSound("weapon.ImpactSoft")
		end
	end
end

if CLIENT then
	ENT.jcms_infoStrictAngles = true
end