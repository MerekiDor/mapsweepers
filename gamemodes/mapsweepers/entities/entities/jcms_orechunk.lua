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
ENT.PrintName = "Ore Chunk"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Worth")
	self:NetworkVar("Int", 1, "OreColourInt")
	self:NetworkVar("String", 0, "OreName")
end

if SERVER then
	ENT.ModelsWithMasses = {
		["models/props_foliage/rock_forest02.mdl"] = 60,
		["models/props_foliage/rock_forest01a.mdl"] = 35,
		["models/props_mining/rock_caves01a.mdl"] = 25,
		["models/props_debris/concrete_spawnchunk001b.mdl"] = 20,
		["models/props_mining/rock_caves01b.mdl"] = 15,
	}

	function ENT:SetOreType(oretype)
		local data = assert(jcms.oreTypes[oretype], "unknown ore type '"..tostring(oretype).."'")
		
		self.jcms_oreValue = data.value
		self:SetOreName(oretype)
		self:SetOreColourInt(jcms.util_ColorInteger(data.color) or 0)

		self:SetMaterial(data.material)

		if data.chunkSetup then 
			data.chunkSetup(self)
		end

		self.ChunkTakeDamage = data.chunkTakeDamage
		self.ChunkPhysCollide = data.chunkPhysCollide
		self.ChunkDestroyed = data.chunkDestroyed
		self.Think = data.chunkThink --More optimised than having all of them check if they have it every second, change if Think is needed for anything else.
	end

	function ENT:Initialize()
		local weights = {}
		for mdl, mass in pairs(self.ModelsWithMasses) do
			weights[mdl] = 100 - mass
		end

		local mdl = self:GetModel()
		if mdl == "models/error.mdl" then
			mdl = jcms.util_ChooseByWeight(weights)
		end

		local mass = self.ModelsWithMasses[mdl]

		self:SetModel(mdl)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		self:SetMaxHealth((mass*1.25) + 15)
		self:SetHealth(self:GetMaxHealth())

		self.jcms_oreMass = mass

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass( mass )
		end

		self:SetWorth( jcms.ore_GetValue(self:GetOreName(), mass) )
		self.jcms_reconBlastImmune = true
	end

	function ENT:OnRemove()
		local ed = EffectData()
		ed:SetOrigin(self:WorldSpaceCenter())
		ed:SetColor(self:GetOreColourInt() or 0)
		ed:SetRadius(math.Rand(2, 5))
		util.Effect("jcms_oremine", ed)
	end

	function ENT:Use(activator)
		if IsValid(activator) and activator:IsPlayer() and jcms.team_JCorp_player(activator) then
			activator:PickupObject(self)
			self.jcms_lastPickedUp = activator
			self.jcms_lastPickedUpTime = CurTime()
		end
	end

	function ENT:OnTakeDamage(dmg)
		if self.jcms_died then return end
		
		if self.ChunkTakeDamage then
			self:ChunkTakeDamage(dmg)
		end

		self:TakePhysicsDamage(dmg)

		local mul = 1
		local dmgType = dmg:GetDamageType()

		local resists = bit.bor(DMG_SHOCK, DMG_BURN, DMG_DROWN, DMG_NERVEGAS, DMG_POISON)
		if bit.band( dmgType, resists ) > 0 then
			mul = 0
		end

		self:SetHealth( math.Clamp(self:Health() - dmg:GetDamage()*mul, 0, self:GetMaxHealth()) )
		if self:Health() <= 0 then
			self:EmitSound("Breakable.Concrete")
			self:Remove()

			local ed = EffectData()
			ed:SetOrigin(self:WorldSpaceCenter())
			ed:SetColor(self:GetOreColourInt())
			ed:SetRadius(self:GetMaxHealth() + 5)
			util.Effect("jcms_oremine", ed)
		elseif dmg:GetDamage() >= 4 then
			local ed = EffectData()
			ed:SetOrigin(self:WorldSpaceCenter())
			ed:SetColor(self:GetOreColourInt())
			ed:SetRadius(dmg:GetDamage())
			util.Effect("jcms_oremine", ed)
		end

		if (self:Health() <= 0 and self.ChunkDestroyed) and not self.jcms_died then
			self.jcms_died = true
			self:ChunkDestroyed()
		end
	end

	function ENT:PhysicsCollide(colData, collider)
		if self.ChunkPhysCollide then
			self:ChunkPhysCollide(colData, collider)
		end

		if colData.Speed > 250 then
			self:EmitSound("Rock.ImpactHard")
		elseif colData.Speed > 100 then
			self:EmitSound("Concrete.ImpactSoft")
		end
	end
end

if CLIENT then
	ENT.jcms_infoStrictAngles = true
end