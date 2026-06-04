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
ENT.PrintName = "Explosives"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Radius = 150
ENT.Damage = 100
ENT.BlastCount = 1
ENT.BlastCooldown = 1
ENT.RequiredTargets = 1
ENT.Proximity = 80
ENT.Expires = 10*60 -- lasts 10 minutes
ENT.PushOwnerForce = 5
ENT.BreachDoors = false
ENT.DestroysBuildings = false -- If true, destroys static defenses in PVP

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/weapons/w_slam.mdl")
		self:SetColor((self:GetNWInt("jcms_pvpTeam", -1) == 2 and Color(241, 212, 14)) or Color(255, 32, 32))

		self:PhysicsInit(SOLID_VPHYSICS)
		self.blastTime = CurTime()
		self.expiration = CurTime() + self.Expires
		self.blasts = 0
		self:SetUseType(SIMPLE_USE)
	end

	if CLIENT then
		self:EmitSound("npc/roller/blade_cut.wav", 75, 120)
	end

	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
end

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "BlinkPeriod")
	self:NetworkVar("Float", 1, "BlinkScale")
	self:NetworkVar("Vector", 0, "BlinkColor")
	self:NetworkVar("Angle", 0, "BlinkDirection")
	--self:SetBlinkColor( Vector(1, 0, 0) )
end

function ENT:UpdateForFaction(faction)
	local col = Vector(1, 0, 0)
	if faction == "mafia" then
		col:SetUnpacked(241/255, 212/255, 14/255)
	end
	self:SetBlinkColor(col)
end

if SERVER then
	hook.Add("InitPostEntity", "jcms_LinkPortalsToDoors", function()
		local namedDoors = {}
		for i, door in ipairs(ents.FindByClass("prop_door_rotating")) do 
			if IsValid(door) then
				local name = door:GetName()
				if not(name == "") then
					namedDoors[name] = door
				end
			end
		end
		for i, door in ipairs(ents.FindByClass("func_door")) do 
			local name = door:GetName()
			if not(name == "") then
				namedDoors[name] = door
			end
		end

		for i, portal in ipairs(ents.FindByClass("func_areaportal")) do 
			local doorNameTarg = portal:GetInternalVariable("target")
			if doorNameTarg ~= "" then 
				local doorTarg = namedDoors[doorNameTarg]
				if doorTarg and IsValid(doorTarg) then
					doorTarg.jcms_portalLink = portal
				end
			end
		end
	end)

	function jcms.DestroyBuildingsHookFunction(ent, dmginfo)
		local attacker = dmginfo:GetAttacker()
		if not (IsValid(attacker) and IsValid(ent)) then return end

		if (dmginfo:GetDamage() >= 44) and isfunction(ent.BreakByBreach) and (not jcms.team_pvpSameTeam(attacker, ent)) then
			ent:BreakByBreach(dmginfo:GetDamageForce())
		end
	end

	function ENT:Detach()
		local removed = constraint.RemoveAll(self)
		if removed then
			self:EmitSound("physics/metal/metal_computer_impact_bullet3.wav", 75, 110)

			local col = Color(255, 64, 64)
			if self:GetNWInt("jcms_pvpTeam", -1) == 2 then
				col:SetUnpacked(255, 255, 0)
			end
			util.SpriteTrail(self, 0, col, true, 10, 0, 0.5, 0.1, "trails/laser")
		end
	end

	function ENT:PhysicsCollide(colData, collider)
		if colData.Speed > 100 then
			self:EmitSound("Grenade.ImpactHard")
		end
	end

	function ENT:Use(user)
		if not self.BreachDoors and user:GetObserverMode() == OBS_MODE_NONE and user:Team() == 1 then
			self:Detach()
			user:PickupObject(self)
		end
	end

	function ENT:GravGunOnPickedUp(user)
		if not self.BreachDoors and user:GetObserverMode() == OBS_MODE_NONE and user:Team() == 1 then
			self:Detach()
		end
	end

	function ENT:OnTakeDamage(dmg)
		self:TakePhysicsDamage(dmg)
	end
	
	function ENT:Think()
		local selfTbl = self:GetTable()
		if selfTbl.expiration and (CurTime() > selfTbl.expiration) then
			if selfTbl.BlastCount > 1 then
				self:Remove()
			else
				self:Detonate()
			end
		else
			local goodTargets = 0
			local mypos = self:GetPos()
			for i, target in ipairs(ents.FindInSphere(mypos, selfTbl.Proximity)) do
				if jcms.team_GoodTarget(target) and not jcms.team_SameTeam(self, target) then
					local tr = util.TraceLine { start = mypos, endpos = target:EyePos(), mask = MASK_SHOT, filter = self }
					if not tr.Hit or tr.Entity == target then
						goodTargets = goodTargets + 1
					end
				end
			end
			
			if (goodTargets >= selfTbl.RequiredTargets) and (selfTbl.blasts < selfTbl.BlastCount) and (CurTime() >= selfTbl.blastTime+selfTbl.BlastCooldown) then
				self:Detonate()
			end
		end
	end

	function ENT:DamageUnder(ignoreEntity)
		if not (self.Damage and self.Damage > 0) then 
			return
		end
		
		local underVector = self:GetAngles():Up()
		underVector:Mul(-1)
		
		local mypos = self:GetPos()
		local dmg = DamageInfo()
		dmg:SetAttacker(IsValid(self.jcms_owner) and self.jcms_owner or self)
		dmg:SetDamage(self.Damage)
		dmg:SetInflictor(self)
		dmg:SetDamageType(DMG_BLAST)
		dmg:SetReportedPosition(mypos)
		dmg:SetDamageForce(underVector * 700)

		local filter = { self, ignoreEntity }
		for i, ent in ipairs(ents.FindInSphere(mypos, 800)) do
			local entpos = ent:WorldSpaceCenter()

			if (entpos - mypos):Dot(underVector) > 0 then

				debugoverlay.Line(mypos, entpos, 5, Color(0, 255, 150), true)

				local tr = util.TraceLine {
					start = mypos, endpos = entpos,
					filter = filter, mask = MASK_SHOT
				}

				if IsValid(tr.Entity) and tr.Entity:Health() > 0 and (not jcms.team_JCorp(tr.Entity)) then
					dmg:SetDamagePosition(entpos)
					tr.Entity:TakeDamageInfo(dmg)
				end

			end
		end
	end
	
	function ENT:Detonate()
		local pos = self:GetPos()

		if self.Damage >= 400 then
			local ed = EffectData()
			ed:SetMagnitude(1)
			ed:SetOrigin(pos)
			ed:SetRadius(self.Radius)
			ed:SetNormal(self:GetAngles():Up())
			ed:SetFlags(1)
			util.Effect("jcms_bigblast", ed)
			util.Effect("Explosion", ed)
			self:EmitSound("Explo.ww2bomb")
			util.ScreenShake(pos, self.Damage / 100 + 2, 30, 2, self.Radius*3)
		else
			local ed = EffectData()
			ed:SetMagnitude(1)
			ed:SetOrigin(pos)
			ed:SetRadius(self.Radius)
			ed:SetNormal(self:GetAngles():Up())
			ed:SetFlags(1)
			util.Effect("jcms_blast", ed)
			util.Effect("Explosion", ed)
			self:EmitSound("explode_"..math.random(3,4))
		end
		
		if self.DestroysBuildings then
			hook.Add("PostEntityTakeDamage", "jcms_destroyBuildings", jcms.DestroyBuildingsHookFunction)
		end

		do
			-- pcall so that we don't accidentally throw an error and keep the hook forever
			local s, rtn = pcall(util.BlastDamage, self, IsValid(self.jcms_owner) and self.jcms_owner or self, pos, self.Radius, self.Damage)
			
			if not s then 
				ErrorNoHaltWithStack(rtn)
			end
		end

		if self.DestroysBuildings then
			hook.Remove("PostEntityTakeDamage", "jcms_destroyBuildings")
		end
		
		self.blasts = self.blasts + 1
		self.blastTime = CurTime()
		
		local weldedTo = self.jcms_weldedTo
		if IsValid(weldedTo) and IsValid( weldedTo:GetPhysicsObject() ) then
			local colorInt = jcms.util_GetColorIntegerPvP(self)
			if self.BreachDoors then
				if weldedTo:GetClass() == "prop_door_rotating" then
					weldedTo:PhysicsInit(SOLID_VPHYSICS)
					weldedTo:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
					weldedTo.jcms_breached = true

					if weldedTo.jcms_portalLink then --Open our area portal
						weldedTo.jcms_portalLink:Fire("Open")
					end

					local despawnAfter = 1.5
					timer.Simple(despawnAfter, function()
						if IsValid(weldedTo) then
							local ed = EffectData()
							ed:SetColor(colorInt)
							ed:SetFlags(2)
							ed:SetEntity(weldedTo)
							util.Effect("jcms_spawneffect", ed)
						end
					end)

					timer.Simple(despawnAfter + 1.5, function() 
						if IsValid(weldedTo) then 
							weldedTo:Remove()
						end
					end)

					self:DamageUnder(weldedTo)
				elseif weldedTo:GetClass() == "func_door" then
					weldedTo:Fire("Unlock")
					weldedTo:Fire("Open")
					weldedTo.jcms_breached = true

					self:DamageUnder(weldedTo)
				elseif weldedTo.BreakByBreach then
					weldedTo:BreakByBreach( self:GetAngles():Up() )
				end
			end
			
			local forceVector = self:GetAngles():Up()
			forceVector:Mul(-1)
			forceVector:Mul(self.PushOwnerForce)
			
			local mt = weldedTo:GetMoveType()
			if mt == MOVETYPE_VPHYSICS then
				local phys = weldedTo:GetPhysicsObject()
				if IsValid(phys) then
					phys:ApplyForceOffset(forceVector, self:GetPos())
				end
			elseif mt == MOVETYPE_WALK then
				-- Player
				weldedTo:SetVelocity(forceVector)
			elseif mt ~= MOVETYPE_PUSH then
				-- NPCs presumably
				forceVector:Mul(0.01)
				weldedTo:SetVelocity(forceVector)
			end
		end
		
		if self.blasts >= self.BlastCount then
			self:Remove()
		end
	end
end

if CLIENT then
	ENT.mat_glow = Material "particle/Particle_Glow_04"

	function ENT:DrawTranslucent()
		local colVector = self:GetBlinkColor()

		local period = self:GetBlinkPeriod()
		local flashfraction = 0.6
		local timefrac = ( (CurTime() + self:EntIndex()) / (period*flashfraction) ) % (1/flashfraction)
		local f = timefrac < 1 and math.ease.InQuart(1-timefrac) or 0 

		local col = Color(255*colVector.x, 255*colVector.y, 255*colVector.z, 255 * f)
		local colBright = Color( Lerp(f, 255*colVector.x, 255), Lerp(f, 255*colVector.y, 255), Lerp(f, 255*colVector.z, 255), 255*f )

		local norm = self:GetAngles():Up()
		norm:Rotate( self:GetBlinkDirection() )
		local v1 = self:WorldSpaceCenter() + norm * self:BoundingRadius()/6
		local v2 = self:WorldSpaceCenter() + norm * self:BoundingRadius()*f

		local sizef = (f + 1)/2
		local scale = self:GetBlinkScale()
		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			render.SetMaterial(self.mat_glow)
			render.DrawSprite(v2, 96*scale*f, 32*scale*sizef, col)
			render.DrawQuadEasy(v1, norm, 32*scale*sizef, 24*scale*sizef, colBright, 0)
		render.OverrideBlend( false )
	end
end