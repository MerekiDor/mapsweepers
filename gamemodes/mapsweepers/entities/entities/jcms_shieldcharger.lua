--[[
	Map Sweepers - Co-op NPC Shooter Gamemode for Garry's Mod by "Octantis Addons" (consisting of MerekiDor & JonahSoldier)
    Copyright (C) 2025  MerekiDor

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
ENT.PrintName = "Shield Charger"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.ChargePerSecond = 5
ENT.ChargeInterval = 0.5

ENT.SentinelAnchor = true

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/props_combine/combine_light001a.mdl")
		self:SetColor(Color(32, 230, 255))
		self:PhysicsInitStatic(SOLID_VPHYSICS)
		
		self:SetMaxHealth(500)
		self:SetHealth(500)
	end

	if CLIENT then
		self.chargeEffectX = 0
	end

	self.hackStunEnd = CurTime()
end

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "HealthFraction")
	self:NetworkVar("Int", 0, "ChargeRadius")
	self:NetworkVar("Bool", 0, "HackedByRebels")
	self:SetHealthFraction(1)
	self:SetChargeRadius(600)

	self:NetworkVarNotify("HackedByRebels", function(ent, name, old, new )
		if new then 
			self:SetColor(Color(162, 81, 255))
			self.hackStunEnd = CurTime() + 2.5
		else
			self:SetColor(Color(32, 230, 255))
		end
	end)
end

if SERVER then
	function ENT:Think()
		local charging = false
		if self:Health() > 0 then
			if self.hackStunEnd < CurTime() or not self:GetHackedByRebels() then 
				local radius = self:GetChargeRadius()
				for i, ply in ipairs(jcms.GetAliveSweepers()) do
					if (ply:Armor() < ply:GetMaxArmor()) and (ply:WorldSpaceCenter():DistToSqr(self:WorldSpaceCenter()) <= radius*radius) then
						self:ChargeShield(ply)
						charging = true
					end
				end
			end
		else
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

		self:NextThink(CurTime() + self.ChargeInterval)
		return true
	end

	function ENT:ChargeShield(ply)
		local plyArmour = ply:Armor()
		local chargeAmount = math.Clamp(ply:GetMaxArmor() - plyArmour, 0, self.ChargePerSecond*self.ChargeInterval)

		self:SetHealth(self:Health() - chargeAmount)
		self:SetHealthFraction(math.Clamp(self:Health() / self:GetMaxHealth(), 0, 1))

		if self:GetHackedByRebels() then
			chargeAmount = -chargeAmount
		end
		
		ply:SetArmor(plyArmour + chargeAmount)
	end
	
	function ENT:OnTakeDamage(dmg)
		if self:GetHackedByRebels() then
			local inflictor, attacker = dmg:GetInflictor(), dmg:GetAttacker()
			if IsValid(inflictor) and jcms.util_IsStunstick(inflictor) and jcms.team_JCorp(attacker) then --UnHack
				jcms.util_UnHack(self)
				return 0
			end
			self:SetHealth(self:Health() - dmg:GetDamage())
			self:SetHealthFraction(math.Clamp(self:Health() / self:GetMaxHealth(), 0, 1))
			return 0
		end
	end
end

if CLIENT then

	function ENT:OnRemove()
		if self.soundCharge then
			self.soundCharge:Stop()
		end
	end
	
	function ENT:Think()
		if self:GetHackedByRebels() and self.hackStunEnd > CurTime() then return end

		if FrameTime() > 0 then
			self.chargeEffectX = (self.chargeEffectX + 1) % 3

			if self.chargeEffectX == 0 then
				self.isCharging = false

				local radius = self:GetChargeRadius()
				for i, ply in ipairs(jcms.GetAliveSweepers()) do
					if ply:Health() > 0 and (ply:Armor() < ply:GetMaxArmor()) and (ply:WorldSpaceCenter():DistToSqr(self:WorldSpaceCenter()) <= radius*radius) then
						local ed = EffectData()
						ed:SetFlags(0)
						ed:SetOrigin(self:WorldSpaceCenter())
						ed:SetEntity(ply)
						util.Effect("jcms_chargebeam", ed)
						self.isCharging = true
					end
				end
			end
		end
		
		if self.soundCharge and not self.soundCharge:IsPlaying() then
			self.soundCharge:Stop()
			self.soundCharge = nil
		end

		if not self.soundCharge and self.isCharging then
			self.soundCharge = CreateSound(self, "ambient/machines/combine_shield_touch_loop1.wav")
		end

		if self.soundCharge then
			if self.isCharging then
				local chargePitch = self:GetHackedByRebels() and 130 or 84
				
				if not self.soundCharge:IsPlaying() then
					self.soundCharge:PlayEx(1, chargePitch)
				else
					self.soundCharge:ChangePitch(chargePitch)
				end
			else
				if self.soundCharge:IsPlaying() and self.soundCharge:GetVolume() <= 0 then
					self.soundCharge:Stop()
				else
					self.soundCharge:ChangeVolume(0, 0.25)
					self.soundCharge:ChangePitch(1, 0.25)
				end
			end
		end
	end

	function ENT:DrawTranslucent()
		if self:GetHackedByRebels() then
			jcms.render_HackedByRebels(self)
		end
	end
end
