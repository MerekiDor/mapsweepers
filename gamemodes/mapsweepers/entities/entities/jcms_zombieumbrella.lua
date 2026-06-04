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
ENT.PrintName = "Umbrella"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

jcms.team_jCorpClasses["jcms_zombieumbrella"] = true

function ENT:SetupDataTables()
	self:NetworkVar("Float", 1, "HealthFraction")
	self:NetworkVar("Entity", 1, "BlockerEnt")
	if SERVER then 
		self:SetHealthFraction(1)
	end
end


if SERVER then
	function ENT:Initialize()
		self:SetModel("models/jcms/jcorp_umbrella.mdl")
		self:PhysicsInitStatic(SOLID_VPHYSICS)

		self:SetMaxHealth(500)
		self:SetHealth(self:GetMaxHealth())
		
		-- // Blocker {{{

			local blocker = ents.Create("prop_physics")
			blocker:SetPos( self:GetPos() )
			blocker:SetModel("models/jcms/jcorp_umbrellashield.mdl")
			blocker:SetMaterial("models/props_combine/portalball001_sheet")
			blocker:SetColor(Color(0, 161, 255))
			blocker:Spawn()

			self:SetBlockerEnt(blocker)

			--blocker:DrawShadow(false)
			--todo: Shadow doesn't look good, but is needed for visual communication
			--post release we might want to re-visit this and give the ground an energy outline or something.

			blocker:SetParent(self) 
			blocker:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)

		-- // }}}
	end

	function ENT:OnTakeDamage(dmg) --Slightly modified version of turret takeDamage
		self:TakePhysicsDamage(dmg)
		
		timer.Simple(0, function()
			if not IsValid(self) then return end
			self:SetHealthFraction(self:Health() / self:GetMaxHealth())

			local blocker = self:GetBlockerEnt()
			if IsValid(blocker) then
				blocker:Extinguish()
			end
		end)

		if self:Health() > 0 then
			local inflictor, attacker = dmg:GetInflictor(), dmg:GetAttacker()

			if IsValid(inflictor) and jcms.util_IsStunstick(inflictor) and jcms.team_JCorp(attacker) then --Repairs
				jcms.util_PerformRepairs(self, attacker)
				return 0
			elseif dmg:GetDamage() > 0 then
				local dmgtype = dmg:GetDamageType()
				
				if bit.band(dmgtype, bit.bor(DMG_BULLET, DMG_BUCKSHOT, DMG_SLASH, DMG_CLUB)) > 0 then
					self:EmitSound("physics/metal/metal_sheet_impact_bullet"..math.random(1,2)..".wav")
					local ed = EffectData()
					ed:SetOrigin(dmg:GetDamagePosition())
					local force = dmg:GetDamageForce()
					force:Normalize()
					force:Mul(-1)
					
					ed:SetScale(math.Clamp(math.sqrt(dmg:GetDamage()/25), 0.01, 1))
					ed:SetMagnitude(math.Clamp(math.sqrt(dmg:GetDamage()/10), 0.1, 10))
					ed:SetRadius(16)
					
					ed:SetNormal(force)
					util.Effect("Sparks", ed)
				end
				
				if math.random() < 0.25 then
					self:EmitSound("npc/scanner/scanner_pain"..math.random(1,2)..".wav")
				end
				
				if bit.band(dmgtype, bit.bor(DMG_ACID, DMG_SHOCK)) > 0 then
					dmg:ScaleDamage(1.5)
				elseif bit.band(dmgtype, bit.bor(DMG_NERVEGAS, DMG_SLOWBURN, DMG_DROWN)) > 0 then
					dmg:ScaleDamage(0)
				else
					dmg:ScaleDamage(0.75)
				end
				
				local final = dmg:GetDamage()
				self:SetHealth(self:Health() - final)
				
				if self:Health() <= 0 then
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
				
				return final
			end
		else
			return 0
		end
	end
end

if CLIENT then 
	function ENT:Think()
		if FrameTime() == 0 then return end 

		local shield = self:GetBlockerEnt()
		if not IsValid(shield) then return end

		local ed = EffectData()
		ed:SetFlags(0)
		ed:SetOrigin(shield:GetPos() + Vector(math.Rand(-115, 115), math.Rand(-115, 115),190))--Vector(math.Rand(-115, 115), math.Rand(-115, 115), 90))
		ed:SetEntity(self)
		util.Effect("jcms_chargebeam", ed)
	end
end
