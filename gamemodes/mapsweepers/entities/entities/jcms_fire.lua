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
ENT.PrintName = "Fire Zone"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

PrecacheParticleSystem("embers_medium_01")
PrecacheParticleSystem("fire_medium_base")
PrecacheParticleSystem("fire_medium_burst")

--Large
PrecacheParticleSystem("fire_medium_02_nosmoke")

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "ActivationTime") --fadeIn
	self:NetworkVar("Float", 2, "Radius")
end

if SERVER then 
	function ENT:Initialize() 
		self.damage = 3
		self.dieTime = CurTime() + 30

		--Eat any fires that we overlap with
		local ourDieTime = self.dieTime
		local ourRadius = self:GetRadius()
		local ourDamage = self.damage

		for i, ent in ipairs(ents.FindInSphere(self:GetPos(), self:GetRadius())) do
			if ent:GetClass() == "jcms_fire" then 
				ourDieTime = math.max(ourDieTime, ent.dieTime)
				ourRadius = math.max(ourRadius, ent:GetRadius()) + 5
				ourDamage = ourDamage + ent.damage
			end
		end

		self.damage = ourDamage
		self:SetRadius(ourRadius)
		self.dieTime = ourDieTime
	end

	function ENT:Think()
		self:Extinguish()
		local selfTbl = self:GetTable()

		if selfTbl:GetActivationTime() > CurTime() then return end

		local selfPos = self:GetPos() 

		local dmg = DamageInfo()
		if IsValid(selfTbl.jcms_owner) then
			dmg:SetAttacker(selfTbl.jcms_owner)
		else
			dmg:SetAttacker(self)
		end
		dmg:SetInflictor(self)
		dmg:SetReportedPosition(selfPos)
		dmg:SetDamageType( bit.bor(DMG_BURN, DMG_DIRECT) )

		local damage = selfTbl.damage

		for i, ent in ipairs(ents.FindInSphere( selfPos, selfTbl:GetRadius() )) do 
			if ent.jcms_fireproof then
				continue
			end
			
			local entTakeDamageInfo = ent.TakeDamageInfo
			if entTakeDamageInfo then 
				dmg:SetDamage(damage)
				dmg:SetDamagePosition(ent:GetPos())
				entTakeDamageInfo(ent, dmg)
			end

			local entClass = ent:GetClass()
			if entClass == "prop_physics" or string.StartsWith(entClass, "npc_") then
				if not (IsValid(selfTbl.jcms_owner) and jcms.team_SameTeam(ent, selfTbl.jcms_owner)) then
					ent:Ignite(3)
				end
			end
		end

		if selfTbl.dieTime < CurTime() then
			self:Remove()
		end

		self:NextThink(CurTime() + 1)
		return true
	end
end

if CLIENT then 
	ENT.mat_glow = Material "sprites/light_glow02_add"

	function ENT:Initialize()
		self.firePart1 = CreateParticleSystem( self, "embers_medium_01", PATTACH_ABSORIGIN_FOLLOW)
		self.firePart2 = CreateParticleSystem( self, "fire_medium_base", PATTACH_ABSORIGIN_FOLLOW)
		self.firePart3 = CreateParticleSystem( self, "fire_medium_burst", PATTACH_ABSORIGIN_FOLLOW)

		self.firePart1:SetShouldDraw( false )
		self.firePart2:SetShouldDraw( false )
		self.firePart3:SetShouldDraw( false )

		self.firePart1:StartEmission() --embers are always on

		local selfPos = self:GetPos()
		local tr = util.TraceLine({
			start = selfPos,
			endpos = selfPos - jcms.vectorUp
		})
		self.normal = tr.HitNormal

		self:DrawShadow( false ) --Doesn't seem to work?

		local activationDelay = self:GetActivationTime() - CurTime()
		self.activationDur = activationDelay

		timer.Simple( activationDelay / 2 - math.Rand(0,0.1), function() --start some small flames/burning when we're halfway activated
			if not IsValid(self) or not IsValid(self.firePart2) then return end

			self.firePart2:Restart()
			--self.firePart2:SetShouldDraw( true )
		end)

		timer.Simple( activationDelay - math.Rand(0,0.1), function() --start the fire proper
			if not IsValid(self) or not IsValid(self.firePart3) then return end

			self.firePart3:Restart()
			--self.firePart3:SetShouldDraw( true )
		end)
		--end)

		self.fire_col_obj = Color(0,0,0) --Set in DrawTranslucent, created here for optimisation.
	end

	function ENT:DrawTranslucent() --TODO: Significant lua lag in this function, probably want to optimise more
		self:DestroyShadow()

		local selfTbl = self:GetTable()

		local mypos = self:GetPos()
		local rad = selfTbl.GetRadius(self)
		local dist = jcms.EyePos_lowAccuracy:DistToSqr(mypos)

		local timeToActivation = (selfTbl.GetActivationTime(self) - CurTime())
		local activationMult = Lerp( timeToActivation / selfTbl.activationDur, 1.2, 0.25)

		if IsValid(selfTbl.firePart1) and IsValid(selfTbl.firePart2) and IsValid(selfTbl.firePart3) and dist < 3500^2 then 
			if dist < 1500^2 and jcms.performanceEstimate > 25 then 
				selfTbl.firePart1:Render()
				if dist < 750^2 and jcms.performanceEstimate > 40 and timeToActivation - selfTbl.activationDur/2 < 0 then --are we half-way activated
					selfTbl.firePart2:Render()
				end
			end
			
			if timeToActivation - selfTbl.activationDur < 0 then 
				selfTbl.firePart3:Render()
			end
		end

		local from, to = 1250^2, 300^2 --Has a little bit of cost albeit not much
		local mult = math.Clamp(math.Remap(dist, from, to, 1, 0), 0.75, 1.25)	--Scale
		local mult2 = math.Clamp(math.Remap(dist, from, to, 1, 0), 0.35, 0.5)	--Alpha/Brightness

		mult = mult * activationMult
		--mult2 = mult2 * activationMult

		local cr, cb, cg = math.random(250, 255) * mult2, math.random(100, 150) * mult2, 32 * mult2
		selfTbl.fire_col_obj:SetUnpacked(cr, cb, cg)
		render.SetMaterial(selfTbl.mat_glow)

		local offsPos = mypos
		offsPos:Add(selfTbl.normal) 
		local scale1 = 6 * rad * mult 
		render.DrawQuadEasy(offsPos, selfTbl.normal, scale1, scale1, selfTbl.fire_col_obj, 0)

		if dist > 200^2 then 
			selfTbl.fire_col_obj:SetUnpacked(cr * mult2, cg * mult2, cb * mult2)

			local scale2 = mult*14*rad
			offsPos:Mul(10)
			render.DrawSprite(offsPos, scale2, scale2, selfTbl.fire_col_obj)
		end
	end
end