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
ENT.PrintName = "Infinite Ammo Crate"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.ShareRadius = 1256

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/items/ammocrate_smg1.mdl")
		self:PhysicsInitStatic(SOLID_VPHYSICS)
		self:AddEFlags(EFL_DONTBLOCKLOS)
		self:SetUseType(SIMPLE_USE)
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Cooldown")
	self:NetworkVar("Float", 1, "LastUsedAt")
	self:NetworkVar("Bool", 0, "Locked")

	if SERVER then
		self:SetCooldown(5)
	end
end

if SERVER then
	function ENT:TryGiveAmmo(ply, cashOverride)
		local cash = cashOverride
		local worked = jcms.util_TryGiveAmmo(ply, cash)
		return worked
	end

	function ENT:Use(activator)
		if not ( IsValid(activator) and activator:IsPlayer() and jcms.team_JCorp_player(activator) and activator:Alive() and activator:GetObserverMode() == OBS_MODE_NONE ) then
			return
		end
		if self:GetLocked() then 
			self:EmitSound("player/suit_denydevice.wav")
			return 
		end

		
		local ct, cooldown, lastTime = CurTime(), self:GetCooldown(), self:GetLastUsedAt()
		local worked = false
		if (ct > cooldown + lastTime) then
			local pos = self:WorldSpaceCenter()

			worked = jcms.util_TryGiveAmmo(activator, 100)
			if worked then

				local shareRadius2 = self.ShareRadius^2
				for i, sweeper in ipairs(jcms.GetAliveSweepers()) do
					if (sweeper ~= activator) and (sweeper:WorldSpaceCenter():DistToSqr(pos) <= shareRadius2) and (sweeper:Visible(self)) then
						if self:TryGiveAmmo(sweeper, 75) then
							timer.Simple(0.02, function()
								if IsValid(sweeper) then
									local ed = EffectData()
									ed:SetEntity(sweeper)
									ed:SetOrigin(pos)
									ed:SetMagnitude(0.6)
									ed:SetScale(3)
									ed:SetFlags(4)
									util.Effect("jcms_chargebeam", ed)
								end
							end)
						end
					end
				end

				self:SetSequence("Open")
				self:SetCycle(0)
				self:EmitSound("buttons/lever2.wav")

				timer.Simple(0.02, function()
					if IsValid(activator) then
						local ed = EffectData()
						ed:SetEntity(activator)
						ed:SetOrigin(pos)
						ed:SetMagnitude(1)
						ed:SetScale(5)
						ed:SetFlags(4)
						util.Effect("jcms_chargebeam", ed)
					end
				end)

				timer.Simple(1.25, function()
					if IsValid(self) then
						self:SetSequence("Close")
						self:SetCycle(0)
						self:EmitSound("AmmoCrate.Close")
					end
				end)

				self:SetLastUsedAt(ct)
				self:SetCooldown(cooldown + 5)
			end
		end

		if not worked then
			self:EmitSound("common/wpn_denyselect.wav")
		end
	end
end

if CLIENT then
	ENT.mat_ammo = Material("jcms/beam_ammo.png")

	function ENT:Think()
		self:SetCycle( math.min(1, self:GetCycle() + FrameTime()/1.5) )
	end

	function ENT:DrawTranslucent()
		local v = self:WorldSpaceCenter()
		local a = self:GetAngles()
		
		v:Add(a:Up()*20)
		v:Add(a:Forward()*14)
		a:RotateAroundAxis(a:Right(), -30)
		a:RotateAroundAxis(a:Up(), 90)
		local eyeDist = jcms.EyePos_lowAccuracy:DistToSqr(v)

		local frac = math.Clamp( ( CurTime() - self:GetLastUsedAt() ) / self:GetCooldown(), 0, 1 )

		local r,g,b = 255, 32, 37
		if frac >= 1 and not self:GetLocked() then
			r,g,b = 132, 230, 255
		end
		cam.Start3D2D(v, a, 1/16)
			surface.SetDrawColor(r, g, b, 255*frac)
			if eyeDist <= 500^2 then
				surface.DrawOutlinedRect(-128, 96, 256, 54, 4)
			end
			surface.SetMaterial(self.mat_ammo)
			surface.DrawTexturedRectRotated(0, 0, 128, 128, 0)
			surface.SetDrawColor(r, g, b, 255*(0.5+(frac^2)/2))
			if not self:GetLocked() then
				surface.DrawRect(-128+8, 96+8, (256-16)*frac, 54-16)
			end

			if eyeDist <= 128^2 then
				if self:GetLocked() then 
					draw.SimpleText( [=[LOCKED]=], "jcms_medium", 0, 96 + 54/2, surface.GetDrawColor(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
				else
					draw.SimpleText( language.GetPhrase("jcms.cooldown_crate"):format(self:GetCooldown()), "jcms_medium", 0, 96+54+8, surface.GetDrawColor(), TEXT_ALIGN_CENTER )
				end
			end
		cam.End3D2D()
	end
end
