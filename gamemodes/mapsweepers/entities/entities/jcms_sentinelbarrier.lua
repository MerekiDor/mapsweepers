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
ENT.PrintName = "Sentinel Barrier"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

ENT.Absorption = 0.2
ENT.MeleeAbsorption = 0.75

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "DamageTaken")
	self:NetworkVar("Float", 1, "MinDamageTaken")
	self:NetworkVar("Float", 2, "MaxDamageTaken")
	self:NetworkVar("Entity", 0, "Sentinel")
	self:NetworkVar("Bool", 0, "IsAntlionShield")
end

function ENT:Initialize()
	self:SetModel("models/jcms/jcorp_sentinelbarrier.mdl")
	--self:SetMaterial("models/props_combine/portalball001_sheet")
	--self:SetColor(Color(0, 161, 255))
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetHealth(1)
	
	self:SetMinDamageTaken(10)
	self:SetMaxDamageTaken(250)

	if SERVER then
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		self:AddEFlags(EFL_DONTBLOCKLOS)
		self:EmitSound("weapons/physcannon/energy_sing_flyby2.wav", 100, 97, 1)
	end

	if CLIENT then
		self.distortMatrix = Matrix()
		self.distortMatrix:Zero()
		self.popupTime = 0
		self.damageAccumulator = 0 -- animates from 0 to current DamageTaken smoothly

		self:EnableMatrix("RenderMultiply", self.distortMatrix)
	end
end

function ENT:SetPosToSentinel()
	local owner = self:GetSentinel()
	if not IsValid(owner) then return end

	local pos, ang = owner:WorldSpaceCenter(), owner:EyeAngles()
	local fwd = ang:Forward()
	local up = ang:Up()
	ang:RotateAroundAxis(up, 180)
	
	fwd:Mul(48 + math.abs(ang.p)/180*24)
	pos:Add(fwd)

	up:Mul(4)
	pos:Add(up)

	ang.p = ang.p * 0.75
	self:SetPos(pos)
	self:SetAngles(ang)
end

function ENT:GetDamageTakenFactor()
	return math.Clamp( math.TimeFraction(self:GetMinDamageTaken(), self:GetMaxDamageTaken(), self:GetDamageTaken()), 0, 1 )^2
end

function ENT:GetShieldRestorationFactor(power)
	power = power or self:GetDamageTakenFactor()
	
	if power > 0 then
		return Lerp(power, 0.01, 0.25) -- Restores 1% to 25% of shield for yourself and allies
	else
		return 0
	end
end

if SERVER then
	function ENT:Think()
		if not self:GetIsAntlionShield() then
			local dt = 0.1
			self:NextThink( CurTime() + dt ) --this is kinda redundant, 0.1s is the default - j
			self:SetPosToSentinel()
			return true
		end
	end

	function ENT:OnTakeDamage(dmg)
		local sentinel = self:GetSentinel()
		if not IsValid(sentinel) then return end
		local attacker = dmg:GetAttacker()
		if not IsValid(attacker) then return end

		if not jcms.team_SameTeam(sentinel, attacker) then
			self:SetDamageTaken( self:GetDamageTaken() + dmg:GetDamage() )

			local ed = EffectData()
			ed:SetFlags(0)
			ed:SetColor(jcms.util_colorIntegerSweeperShield)
			ed:SetOrigin(dmg:GetDamagePosition())
			ed:SetNormal(self:GetAngles():Forward())
			ed:SetScale(2)
			util.Effect("jcms_shieldeffect", ed)
		end
	end

	function ENT:OnRemove()
		self:Detonate()
	end

	function ENT:Detonate()
		if self:GetIsAntlionShield() then 
			local ed = EffectData()
			ed:SetMagnitude(1)
			ed:SetOrigin(self:WorldSpaceCenter())
			ed:SetRadius(15)
			ed:SetNormal(self:GetAngles():Forward())
			ed:SetFlags(5)
			ed:SetColor( jcms.util_ColorInteger(Color(255, 128, 0)) )
			util.Effect("jcms_blast", ed)
		else
			local shieldRestorationFactor = self:GetShieldRestorationFactor()
			if shieldRestorationFactor <= 0 then return end

			local pos = self:WorldSpaceCenter()
			local powerFactor = self:GetDamageTakenFactor()
			
			local ed = EffectData()
			ed:SetMagnitude(0.84 + powerFactor * 0.33)
			ed:SetOrigin(pos)
			ed:SetRadius(5 + powerFactor*3)
			ed:SetNormal(self:GetAngles():Forward())
			ed:SetFlags(5)
			ed:SetColor( jcms.util_ColorIntegerFast(23 + powerFactor*200, 185 - powerFactor*120, 255 - powerFactor*100) )
			util.Effect("jcms_blast", ed)

			local sentinel = self:GetSentinel()
			if not IsValid(sentinel) then return end

			for i, swp in ipairs( jcms.GetSweepersInRange(pos, 1200 + 300*powerFactor) ) do
				if jcms.team_SameTeam(sentinel, swp) then
					local armor = swp:Armor()
					local armorMax = swp:GetMaxArmor()
					local newValue = math.min( armorMax * 1.25, armor + math.ceil(armorMax * shieldRestorationFactor) ) -- Allow up to 25% overcharge

					if newValue > armor then
						swp:SetArmor(newValue)
						local ed2 = EffectData()
						ed2:SetEntity(swp)
						ed2:SetOrigin(pos)
						ed2:SetMagnitude(1)
						ed2:SetScale(1)
						ed2:SetFlags(0)
						util.Effect("jcms_chargebeam", ed)
					end
				end
			end
		end
	end
end

if CLIENT then
	ENT.mat_antShield = CreateMaterial("jcms_antlionSentinelShield", "UnlitGeneric", {
		["$basetexture"] = "models/debug/debugwhite",
		["$detail"] = "models/props_combine/portalball001_sheet",
		["$detailscale"] = 1
	})

	function ENT:Think()
		local dt = FrameTime()
		self.popupTime = self.popupTime + dt

		local dmgTaken = self:GetDamageTaken()
		local fieldPitch = Lerp(self:GetDamageTakenFactor(), 100, 163)
		if not self.sfxField then
			self.sfxField = CreateSound(self, "weapons/physcannon/energy_sing_loop4.wav")
			self.sfxField:PlayEx(1, fieldPitch)
		else
			self.sfxField:ChangePitch(fieldPitch)
		end

		self.damageAccumulator = (self.damageAccumulator*4 + dmgTaken)/5
		self.damageDelta = dmgTaken - self.damageAccumulator

		local sentinel = self:GetSentinel()
		if IsValid(sentinel) then
			sentinel.jcms_sentinelBarrier = self
		end
	end

	function ENT:OnRemove()
		if self.sfxField then
			self:EmitSound("ambient/energy/newspark05.wav")
			self.sfxField:Stop()
			self.sfxField = nil
		end
	end

	function ENT:DrawTranslucent()
		self:RemoveAllDecals()
		
		if not self:GetIsAntlionShield() then
			self:SetPosToSentinel()
			self:SetupBones()

			local damageDelta = 1 - 100 / (100 + self.damageDelta)
			local shieldPowerExp = (1 - self.popupTime/3) / (self.popupTime*24 + 1) + 0.13 + damageDelta
			local damagePower = 50 * self:GetDamageTakenFactor()

			local scaleVector = VectorRand(0.99, 1.01 + damagePower/1000)
			local shieldScale = math.ease.OutBack( math.min(self.popupTime*4, 1) )*0.3 + 0.7 + damageDelta*0.75
			scaleVector:Mul(shieldScale)

			local mtx = self.distortMatrix
			mtx:Identity()
			mtx:Scale( scaleVector )
			
			self:EnableMatrix("RenderMultiply", mtx)

			render.SetColorModulation(damagePower, Lerp(shieldPowerExp, 0, 10), Lerp(shieldPowerExp, 0, 20))
				self:DrawModel()
			render.SetColorModulation(1, 1, 1)
		else
			local mtx = self.distortMatrix
			mtx:Identity()
			mtx:Scale( VectorRand(1, 1.1) )
			
			self:EnableMatrix("RenderMultiply", mtx)

			render.MaterialOverride(self.mat_antShield)
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					render.SetColorModulation(1, 0.50, 0)
						self:DrawModel()
					render.SetColorModulation(1, 1, 1)
				render.OverrideBlend( false )
			render.MaterialOverride()
		end
	end
end