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
ENT.PrintName = "Tesla Coil"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Damage = 6
ENT.Radius = 400
ENT.ChainRadius = 500
ENT.ChainSteps = 14
ENT.FireRate = 0.4

ENT.SentinelAnchor = true

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/props_c17/utilityconnecter006c.mdl")
		self:SetMaterial("models/props_combine/metal_combinebridge001")
		self:SetColor(Color(255, 32, 32))
		self:PhysicsInitStatic(SOLID_VPHYSICS)
		
		self:SetMaxHealth(35)
		self:SetHealth(35)

		self.nextAttack = CurTime()
	end

	self.hackStunEnd = CurTime()
end

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "HealthFraction")
	self:NetworkVar("Bool", 0, "HackedByRebels")
	self:SetHealthFraction(1)
	self:NetworkVarNotify("HackedByRebels", function(ent, name, old, new )
		if new then 
			self:SetColor(Color(162, 81, 255))
			self.hackStunEnd = CurTime() + 2.5
		else
			self:SetColor(Color(255, 32, 32))
		end
	end)
end

if SERVER then
	function ENT:TeslaEffect(target)
		target = target or self

		local tPos = target:WorldSpaceCenter()
		local effectdata = EffectData()
		effectdata:SetStart(tPos)
		effectdata:SetOrigin(tPos)
		effectdata:SetMagnitude(2)
		effectdata:SetNormal(vector_up)
		effectdata:SetScale(5)
		effectdata:SetEntity(target)
		util.Effect("TeslaHitboxes", effectdata)
	end

	function ENT:Think()
		if self:Health() > 0 then
			local cTime = CurTime()
			if self.nextAttack <= cTime and (self.hackStunEnd < CurTime() or not self:GetHackedByRebels()) then
				local selfPos = self:GetPos()

				local targets = ents.FindInSphere(selfPos, self.Radius)
				local finalTargets = {}
				for i, ent in ipairs(targets) do 
					if jcms.team_GoodTarget(ent) and jcms.turret_IsDifferentTeam(self, ent) and self:TurretVisible(ent) then
						table.insert(finalTargets, ent)
					end
				end

				local best = jcms.turret_targetingModes.strongest(self, finalTargets, selfPos)

				if IsValid(best) then
					local hp = self:Health()
					self:SetHealth(hp - 1)
					self:SetHealthFraction(hp / self:GetMaxHealth())
					self:Zap(best)
				end

				self.nextAttack = cTime + self.FireRate
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

		local hfrac = self:Health() / self:GetMaxHealth()
		if (math.random() < (1 - hfrac) - 0.5) and hfrac < 0.5 then
			
			self:TeslaEffect()
			timer.Simple(0.1, function() 
				if IsValid(self) then 
					self:TeslaEffect() 
				end
			end)
			local ed = EffectData()
			ed:SetOrigin(self:WorldSpaceCenter() + VectorRand(-16, 16))
			ed:SetMagnitude(1-hfrac)
			ed:SetScale(1-hfrac)
			ed:SetRadius(4-hfrac)
			ed:SetNormal(VectorRand())
			util.Effect("Sparks", ed)
		end
	end

	function ENT:Zap(target)
		local selfPos = self:GetPos()
		local targetPos = target:GetPos()

		local damageinfo = DamageInfo()
		damageinfo:SetAttacker(IsValid(self.jcms_owner) and self.jcms_owner or self)
		damageinfo:SetInflictor(self)
		damageinfo:SetDamage((self:GetHackedByRebels() and 0.15 or 1) * self.Damage)
		damageinfo:SetDamageType( bit.bor(DMG_SHOCK, DMG_DISSOLVE) )
		damageinfo:SetReportedPosition(selfPos)
		damageinfo:SetDamagePosition(targetPos)
		target:TakeDamageInfo(damageinfo)
		
		self:TeslaEffect()
		timer.Simple(0.1, function() 
			if IsValid(self) then 
				self:TeslaEffect() 
			end
		end)
		self:TeslaEffect(target)

		self:EmitSound("Weapon_StunStick.Melee_HitWorld")

		local ed = EffectData()
		ed:SetStart(self:WorldSpaceCenter())
		ed:SetOrigin(target:WorldSpaceCenter())
		util.Effect("jcms_tesla", ed)

		local hitBefore = { self = true, ent = true }
		for i=1, self.ChainSteps do
			local bestDist2, bestTarget = self.ChainRadius*self.ChainRadius+1
			local targetPos = target:WorldSpaceCenter()
			
			for j, near in ipairs(ents.FindInSphere(targetPos, self.ChainRadius)) do
				if (not hitBefore[near]) and (near:Health() > 0 and near:Health() <= target:Health() + self.Damage + 30) and jcms.team_GoodTarget(near) and jcms.turret_IsDifferentTeam(self, near) then
					local dist2 = targetPos:DistToSqr(near:WorldSpaceCenter())
					if (not bestTarget) or (dist2 < bestDist2) then
						bestTarget = near
						bestDist2 = dist2
					end
				end
			end
			
			local previous = target
			target = bestTarget
			
			if IsValid(target) then
				hitBefore[target] = true
				
				damageinfo:ScaleDamage(1 - 0.5/self.ChainSteps)
				target:TakeDamageInfo(damageinfo)
				
				self:TeslaEffect(target)
				
				local ed = EffectData()
				ed:SetStart(previous:WorldSpaceCenter())
				ed:SetOrigin(target:WorldSpaceCenter())
				util.Effect("jcms_tesla", ed)
			else
				break
			end
		end
	end

	function ENT:TurretVisible(target)
		local origin = self:GetPos()
		
		local tr = util.TraceLine {
			start = origin,
			endpos = target:WorldSpaceCenter(),
			mask = MASK_OPAQUE_AND_NPCS,
			filter = self
		}
		
		if jcms.turret_IsTraceGoingThroughSmoke(tr) then
			return false
		end
		
		return tr.Entity == target or not tr.Hit
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
	function ENT:DrawTranslucent()
		if self:GetHackedByRebels() then
			jcms.render_HackedByRebels(self)
		end
	end
end
