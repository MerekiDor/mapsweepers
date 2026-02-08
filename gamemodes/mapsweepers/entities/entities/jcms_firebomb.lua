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
ENT.PrintName = "Flame Grenade"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "ExpiresAt")

	if SERVER then
		self:SetExpiresAt( CurTime() + 5 )
	end
end

function ENT:Initialize()
	self:SetModel("models/weapons/w_eq_fraggrenade_thrown.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)

	if SERVER then
		util.SpriteTrail(self, 0, Color(255, 180, 20), true, 4, 0, 2, 1, "trails/laser")
		self:SetUseType(SIMPLE_USE)
	end

	if CLIENT then
		self.color = Color(0, 0, 0)
	end

	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
end

if SERVER then
	function ENT:OnTakeDamage(dmg)
		self:TakePhysicsDamage(dmg)
	end

	function ENT:Use(activator)
		if IsValid(activator) and activator:IsPlayer() and jcms.team_JCorp_player(activator) then
			activator:PickupObject(self)

			self:SetExpiresAt( math.max( self:GetExpiresAt(), CurTime() + 1.5 ) )
		end
	end

	function ENT:Think()
		if not self.jcms_exploded and CurTime() > self:GetExpiresAt() then
			self:Detonate()
		end
	end

	function ENT:Detonate()
		self.jcms_exploded = true
		local pos = self:WorldSpaceCenter()

		local ed = EffectData()
		ed:SetOrigin(pos)
		ed:SetNormal(vector_up)
		util.Effect("HelicopterMegaBomb", ed)
		
		self:Remove()

		pos.z = pos.z + 72
		local traceRes = {}
		local traceInfo = {
			mask = MASK_NPCSOLID_BRUSHONLY,
			filter = self,
			output = traceRes,
			start = pos
		}

		for i=1, 5 do
			traceInfo.endpos = Angle(math.random()*75 + 15, math.random()*360, 0):Forward()
			traceInfo.endpos:Mul(256)
			traceInfo.endpos:Add(pos)
			util.TraceLine(traceInfo)

			if traceRes.Hit and traceRes.HitNormal:Dot(vector_up) > 0.75 then
				local fire = ents.Create("jcms_fire")
				fire:SetPos(traceRes.HitPos)
				fire:Spawn()
				fire:DropToFloor()
		
				fire:SetRadius(45)
				fire:SetActivationTime(CurTime() + 1)
				fire.dieTime = CurTime() + 14
				fire.jcms_owner = self.Attacker
			end
		end

		local dmg = DamageInfo()
		dmg:SetDamagePosition(pos)
		dmg:SetReportedPosition(pos)
		dmg:SetDamageForce(jcms.vectorUp)
		dmg:SetDamage(15)
		dmg:SetDamageType(bit.bor(DMG_BLAST, DMG_BURN))
		dmg:SetInflictor(self)
		dmg:SetAttacker(IsValid(self.Attacker) and self.Attacker or self)
		util.BlastDamageInfo(dmg, pos, 100)

		self:EmitSound("ambient/fire/ignite.wav", 100, 103, 1)

	end
end

if CLIENT then
	ENT.mat_ring = Material "effects/select_ring"
	ENT.mat_light = Material "sprites/light_glow02_add"

	function ENT:Think()
		local timeRemains = math.max(0, self:GetExpiresAt() - CurTime())
		local divfactor = timeRemains <= 3 and (timeRemains <= 1 and 0.1 or 0.5) or 1
		local beepIndex = math.floor(timeRemains/divfactor)*divfactor
		if self.lastBeepIndex ~= beepIndex then
			self.lastBeepIndex = beepIndex
			self:EmitSound("hl1/fvox/beep.wav", 60, Lerp(math.Clamp(math.TimeFraction(3, 0, timeRemains), 0, 1), 137, 154), 1)
		end
	end

	function ENT:DrawTranslucent()
		local timeRemains = math.max(0, self:GetExpiresAt() - CurTime())
		local f = math.abs( math.sin(5 * math.pi * (timeRemains^0.68)) )

		local col = self.color
		if timeRemains <= 0 then
			col:SetUnpacked(255, 255, 32)
		else
			col:SetUnpacked(Lerp(f, 180, 255), Lerp(f, 8, 255), Lerp(f, 0, 32))
		end

		local pos = self:WorldSpaceCenter()
		
		render.SetMaterial(self.mat_ring)
		render.DrawSprite(pos, 12*f, 12*f, col)

		if timeRemains < 1.5 then
			render.SetMaterial(self.mat_light)

			local f2 = math.ease.InCirc(1 - timeRemains/1.5)
			col.a = f2*255

			render.DrawSprite(pos, Lerp(f2, 0, 128), Lerp(f2, 0, 48), col)
		end
	end
end