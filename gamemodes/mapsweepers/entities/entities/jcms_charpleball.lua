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
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/props_phx/cannonball_solid.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:AddEFlags(EFL_DONTBLOCKLOS)
		self:SetMaterial("models/charple/charple3_sheet")

		self:SetMaxHealth(150)
		self:SetHealth(150)
		self:SetBloodColor(BLOOD_COLOR_ANTLION_WORKER)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMaterial("flesh")
			phys:SetAngleVelocity( VectorRand(-720, 720) )

			phys:SetDragCoefficient(0)
			phys:SetDamping(0, 0)
		end

		if (self.jcms_upgradeLevel or 0) >= 1 then
			self:SetModelScale(1.5)
		end
	end

	if CLIENT then
		local ed = EffectData()
		ed:SetEntity(self)
		ed:SetScale(0)
		util.Effect("jcms_burningcharacter", ed)
	end
end

if SERVER then
	ENT.Spawner = NULL
	ENT.CharpleCount = 3
	ENT.LostOne = false

	function ENT:SplitIntoCharples()
		self:EmitSound("NPC_Antlion.RunOverByVehicle")

		local charples = {}
		local spawner = self.Spawner

		for i=1, self.CharpleCount do
			local charple = jcms.npc_Spawn("zombie_charple", self:WorldSpaceCenter() + VectorRand(-8, 8))
			charple.jcms_upgradeLevel = self.jcms_upgradeLevel

			local ang = math.random() * math.pi * 2
			local cos, sin = math.cos(ang), math.sin(ang)
			local mag = math.random() * 320

			local vel = Vector(cos * mag, sin * mag, math.Rand(150, 450))
			charple:SetVelocity(vel)
			charple:SetAngles(Angle(0, ang / math.pi * 180, 0))

			local ed = EffectData()
			ed:SetEntity(charple)
			--TODO: Fire's used to distinguish upgraded ones rn but it'd be better if it was just black smoke eminating from them.
			ed:SetScale( (charple.jcms_upgradeLevel >=2 and 0) or math.random() * 0.5 + 0.5 )
			ed:SetStart( jcms.vectorOrigin )
			util.Effect("jcms_burningcharacter", ed)

			table.insert(charples, charple)

			if IsValid(self.Spawner) then
				table.insert(self.Spawner.spawnedNPCs, charple)
			end
		end

		for i, charple in ipairs(charples) do
			for j=1, i-1 do
				constraint.NoCollide(charple, charples[j], 0, 0)
			end

			--[[
			if IsValid(spawner) then 
				constraint.NoCollide(charple, spawner, 0, 0)
			end--]]
			charple:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS)
		end

		timer.Simple(0.1, function()
			for i, charple in ipairs(charples) do
				if IsValid(charple) then
					charple:SetActivity(2099)
				end
			end
		end)

		if self.jcms_upgradeLevel > 0 then 
			--TODO: Black smoke, not grey
			--TODO: SFX
			--self:EmitSound("weapons/flaregun/fire.wav", 90, 60)

			local nearest, dist = jcms.GetNearestSweeper(self:GetPos())
			local dur = dist < 150 and 7.5 or 12 

			local ed = EffectData()
			ed:SetMagnitude(dur)
			ed:SetOrigin(self:WorldSpaceCenter())
			ed:SetNormal(self:GetAngles():Up())
			ed:SetRadius(150*self.jcms_upgradeLevel)
			ed:SetFlags(3)
			util.Effect("jcms_blast", ed)

			if jcms.smokeScreens then
				table.insert(jcms.smokeScreens, { pos = self:WorldSpaceCenter(), rad = 125*self.jcms_upgradeLevel, expires = CurTime() + (dur-1) }) 
			end
		end

		self:Remove()
	end

	function ENT:OnTakeDamage(dmg)
		self:TakePhysicsDamage(dmg)

		self:SetHealth( math.max(0, self:Health() - dmg:GetDamage()) )

		if not self.LostOne and self:Health() <= self:GetMaxHealth() * 0.5 then
			self.CharpleCount = self.CharpleCount - 1
			self.LostOne = true
		end

		if self:Health() == 0 then
			local ed = EffectData()
			ed:SetMagnitude(0.8)
			ed:SetOrigin(self:WorldSpaceCenter())
			ed:SetRadius(128)
			ed:SetNormal(jcms.vectorUp)
			ed:SetFlags(1)
			util.Effect("jcms_blast", ed)
			util.Effect("Explosion", ed)
			self:Remove()
		end
	end

	function ENT:PhysicsCollide(colData, physObj)
		if colData.HitNormal:Dot(jcms.vectorUp) < -0.3 then
			local hitEntity = colData.HitEntity

			if hitEntity ~= game.GetWorld() and IsValid(hitEntity) and hitEntity:IsNPC() then
				return
			end

			timer.Simple(0, function() --Stop complaining
				self:SplitIntoCharples()
			end)
		end
	end
end

if CLIENT then
	ENT.mat_fire1 = Material "effects/fire_cloud1.vtf"
	ENT.mat_fire2 = Material "effects/fire_cloud2.vtf"

	function ENT:DrawTranslucent()
		render.SetMaterial( CurTime()%0.1<0.05 and self.mat_fire1 or self.mat_fire2 )
		render.DrawSprite(self:WorldSpaceCenter(), math.random(70, 80), math.random(70, 80), color_white)
	end

	function ENT:OnRemove()
		local ed = EffectData()
		ed:SetMagnitude(0.7)
		ed:SetOrigin(self:WorldSpaceCenter())
		ed:SetRadius(128)
		ed:SetNormal(jcms.vectorUp)
		ed:SetFlags(1)
		util.Effect("jcms_blast", ed)
	end

	function ENT:Think()
		if not self.didIncomingSound then
			local distToObserver = jcms.EyePos_lowAccuracy:Distance( self:WorldSpaceCenter() )
			self.maxDistToObserver = self.maxDistToObserver and math.max(self.maxDistToObserver, distToObserver) or distToObserver

			if self.maxDistToObserver >= 1000 and distToObserver <= 400 then
				self.didIncomingSound = true
				self:EmitSound("npc/env_headcrabcanister/incoming.wav", 140, 110)
			end
		end
	end
end
