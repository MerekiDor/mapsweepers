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
ENT.PrintName = "Turret"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.SentinelAnchor = true
ENT.JCMS_Stunnable = true

if SERVER then
	function jcms.turret_GetTargetPos(self, target, origin)
		local boneId = target:LookupBone("ValveBiped.Bip01_Head1") or target:LookupBone("ValveBiped.Bip01_Spine4")
		if boneId then
			local matrix = target:GetBoneMatrix(boneId)
			if matrix and matrix:GetTranslation() ~= target:GetPos() then
				return matrix:GetTranslation()
			end
		end

		if target.jcms_BodyTarget then
			return target:jcms_BodyTarget(origin)
		else
			return target:BodyTarget(origin)
		end
	end
	
	function jcms.turret_IsDifferentTeam(self, ent)
		return not jcms.team_SameTeam(self, ent)
	end

	function jcms.turret_IsDifferentTeam_Optimised(isHacked, ent, pvpTeam)
		if isHacked then 
			local entTbl = ent:GetTable()

			return jcms.team_JCorp(ent) and not(entTbl.GetHackedByRebels and entTbl:GetHackedByRebels())
		else
			local entPvpTeam = ent:GetNWInt("jcms_pvpTeam", -1)
			return (jcms.team_NPC_optimised(ent) and not jcms.team_pvpSameTeam_Strict_optimised(pvpTeam, entPvpTeam)) or not jcms.team_pvpSameTeam_optimised(pvpTeam, entPvpTeam)
		end
	end
	
	function jcms.turret_IsTraceGoingThroughSmoke(tr)
		local t = CurTime()

		for i=#jcms.smokeScreens, 1, -1 do
			local smokeScreen = jcms.smokeScreens[i]
			if t > smokeScreen.expires then
				table.remove(jcms.smokeScreens, i)
			else
				local a, b = util.IntersectRayWithSphere(tr.StartPos, tr.HitPos - tr.StartPos, smokeScreen.pos, smokeScreen.rad)
				
				if a then
					--The intersect function returns two fractions representing where along the ray the intersection took place (Start and end)
					--These can be <0 (Meaning the sphere was BEHIND the ray / not in the way) or >1 (Meaning the sphere was AHEAD of the ray)
					--In either case this means it isn't actually blocking our view of our target.
					return a > 0 and a < 1
				end
			end
		end
		
		return false
	end
end

function ENT:Initialize()
	if SERVER then
		local health = 125
		self:SetHealth(health)
		self:SetMaxHealth(health)
		self:SetModel("models/jcms/jcorp_turret.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		
		self.attackPatternIndex = 1
		self.nextAttack = 0

		self.kamikazeTime = math.huge
		
		self.keepupright = constraint.Keepupright(self, self:GetAngles(), 0, 32)
		
		self:AddCallback("PhysicsCollide", self.PhysicsCollide)
		self:GetPhysicsObject():Wake()
		self:SetUseType(SIMPLE_USE)

		self.jcms_stunEnd = CurTime()
	end
	
	self.turretAngle = Angle(0, 0, 0)
end

function ENT:SetupDataTables()
	self:NetworkVar("Angle", 0, "TurretDesiredAngle")
	self:NetworkVar("Int", 0, "TurretClip")
	self:NetworkVar("Int", 1, "TurretMaxClip")
	self:NetworkVar("Float", 0, "TurretAlert")
	self:NetworkVar("Float", 1, "TurretSpinup")
	self:NetworkVar("Float", 2, "TurretHealthFraction")
	self:NetworkVar("String", 0, "TurretKind")
	self:NetworkVar("Bool", 0, "TurretBoosted")
	self:NetworkVar("Bool", 1, "HackedByRebels")
	self:NetworkVar("Bool", 2, "SniperGlare")
	self:NetworkVar("Vector", 0, "TurretTurnSpeed")
	self:NetworkVar("Vector", 1, "TurretPitchLock")
	self:NetworkVar("Vector", 2, "GlareColour")
	
	if SERVER then
		self:SetTurretDesiredAngle( Angle(0, 0, 0) )
		self:SetTurretMaxClip(500)
		self:SetTurretClip(self:GetTurretMaxClip())
		self:SetTurretKind("smg")
		self:SetTurretHealthFraction(1)
		self:SetGlareColour(Vector(255, 60, 60))
	end

	self:NetworkVarNotify("HackedByRebels", function(ent, name, old, new )
		if new ~= old then 
			self:UpdateForFaction(new and "rgg" or jcms.util_GetFactionNamePVP(ent))
			if new then 
				self:SetSniperGlare(true)
			else
				if not jcms.util_IsPVP() then 
					self:SetSniperGlare(false)
				end
				ent:SetHealth(ent:GetMaxHealth()) --Repair to full HP if a sweeper hacked us
			end
		end
	end)
end

function ENT:UpdateForFaction(faction)
	for i, matname in ipairs(self:GetMaterials()) do
		self:SetSubMaterial(i-1, matname:gsub("jcorp_", tostring(faction) .. "_"))
	end

	if faction == "rgg" then 
		self:SetGlareColour(Vector(162, 81, 255))
	elseif faction == "mafia" then 
		self:SetGlareColour(Vector(241, 212, 14))
	else
		self:SetGlareColour(Vector(255, 60, 60))
	end
end

function ENT:SetupBoosted() --For engineer
	self:SetMaxHealth(215) --This feels a tad overkill. Ig I'll keep it since we're removing the cost reduction.
	self:SetHealth(215)
	self:SetTurretBoosted(true)
end

function ENT:GetTurretShootPos()
	local ang = self:GetAngles()
	return self:WorldSpaceCenter() + ang:Up()*22
end

function ENT:TurretAngleUpdate(dt)
	local selfTbl = self:GetTable()

	local target = selfTbl:GetTurretDesiredAngle()
	local angle = selfTbl.turretAngle or Angle(0,0,0)
	local speedPitch, speedYaw = selfTbl.TurretTurnSpeed(self)
	speedPitch = speedPitch or speedYaw
	
	local pitchMin, pitchMax = selfTbl.TurretPitchLock(self)
	angle.p = math.Clamp(math.ApproachAngle(angle.p, target.p, dt*speedPitch), -pitchMax, -pitchMin)
	angle.y = math.ApproachAngle(angle.y, target.y, dt*speedYaw)
	angle.r = target.r
end

function ENT:TurretAngleIsSafe()
	local target = self:GetTurretDesiredAngle()
	local angle = self.turretAngle
	local threshold = self:TurretFirerate() >= 0.6 and 1 or 6
	return math.abs(math.AngleDifference(angle.p, target.p)) <= threshold and math.abs(math.AngleDifference(angle.y, target.y)) <= threshold
end

function ENT:TurretAngle()
	return Angle(self.turretAngle)
end

function ENT:TurretTurnSpeed()
	local selfTbl = self:GetTable()
	local mul = (selfTbl:GetHackedByRebels() and 0.75) or 1 
	local v = selfTbl:GetTurretTurnSpeed()
	return v.x * mul, v.y * mul
end

function ENT:TurretPitchLock()
	local v = self:GetTurretPitchLock()
	return v.x, v.y
end

if SERVER then
	
	function ENT:UpdateTurretKind(kind)
		self:SetTurretKind(kind)
		self:SetBodygroup(1, jcms.turret_bodygroups[ kind ] or 1)
		local data = self:GetTurretData()
		self:SetTurretMaxClip(data.clip or 1)
		self:SetTurretClip(self:GetTurretMaxClip())
		self:SetTurretTurnSpeed(Vector(data.turnSpeedPitch, data.turnSpeedYaw, 0))
		self:SetTurretPitchLock(Vector(data.pitchLockMin, data.pitchLockMax, 0))
		self.targetingMode = data.targetingMode or "closest"
	end
	
	function ENT:TurretVisible(target)
		local origin = self:GetTurretShootPos()
		
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
	
	ENT.TurretVisibleTrace = ENT.TurretVisible

	function ENT:GetTurretData()
		local selfTbl = self:GetTable()
		local kind = selfTbl.GetTurretKind(self)
		return (selfTbl.GetTurretBoosted(self) and jcms.turrets_boosted[ kind ]) or  jcms.turrets[ kind ]
	end
	
	function ENT:GetTurretField(field)
		local selfTbl = self:GetTable()
		local f = selfTbl.GetTurretData(self)[ field ]
		if type(f) == "function" then
			return f(self)
		else
			return f
		end
	end

	function ENT:TurretDamage()
		return self:GetTurretField("damage")
	end
	
	function ENT:TurretFirerate()
		return self:GetTurretField("firerate")
	end

	function ENT:TurretRadius() --make rebel turrets in open areas less trivial to deal with/more engaging.
		 local selfTbl = self:GetTable() 
		local mul = (selfTbl.GetHackedByRebels(self) and 2) or 1
		return math.min(selfTbl.GetTurretField(self, "radius") * mul, jcms.rangeCap)
	end
	
	function ENT:TurretDamageType()
		return self:GetTurretField("damagetype")
	end
	
	function ENT:TurretGetAlertTime()
		return self:GetTurretField("timeAlert")
	end

	function ENT:TurretLoseAlertTime()
		return self:GetTurretField("timeLoseAlert")
	end
	
	function ENT:TurretSpread()
		return self:GetTurretField("spreadX"), self:GetTurretField("spreadY")
	end
	
	function ENT:GenTurretSpread()
		local x, y = self:TurretSpread()
		return ((math.random() + math.random()) - 1) * x, ((math.random() + math.random()) - 1) * y
	end
	
	function ENT:GetTargetsAround(origin, radius)
		local selfTbl = self:GetTable()
		if not selfTbl.targetsCache then
			selfTbl.targetsCache = {}
		else
			table.Empty(selfTbl.targetsCache)
		end
		
		--Below is at least 50% of the cost of turrets.

		local isHacked = selfTbl:GetHackedByRebels()
		local selfPvpTeam = self:GetNWInt("jcms_pvpTeam", -1)
		local entIndices = {}
		for _, ent in ipairs(ents.FindInSphere(origin, radius)) do 
			--if ent ~= self and ent:Health() > 0 then
			if jcms.team_GoodTarget(ent) and jcms.turret_IsDifferentTeam_Optimised(isHacked, ent, selfPvpTeam) and (self:TurretVisible(ent) or (IsValid(ent:GetNWEntity("jcms_vehicle", NULL)) and self:TurretVisible(ent:GetNWEntity("jcms_vehicle", NULL)))) then
				table.insert(selfTbl.targetsCache, ent)
				entIndices[ent] = ent:EntIndex()
			end
		end
		
		local function ent_index_sorter(first, last)
			return entIndices[first] < entIndices[last]
		end
		table.sort(selfTbl.targetsCache, ent_index_sorter)

		return selfTbl.targetsCache
	end

	ENT.NextTargetingThink = 0
	ENT.CurrentTarget = NULL

	function ENT:IsAboutToDie()
		return self:Health() <= 0 or self:GetTable().GetTurretClip(self) <= 0
	end

	function ENT:ThinkTurnAndShoot_AngleUpdate(dt)
		local selfTbl = self:GetTable()
		local target = selfTbl.CurrentTarget

		if IsValid(target) then
			local origin = selfTbl.GetTurretShootPos(self)
			local targetPos = jcms.turret_GetTargetPos(self, target, origin)
			local realAngle = self:GetAngles()
			local targetAngle = (targetPos - origin):Angle()
			targetAngle:Sub(realAngle)

			if not selfTbl:GetTurretDesiredAngle():IsEqualTol(targetAngle, selfTbl.TurretFirerate(self) >= 0.6 and 0.01 or 1) then
				selfTbl:SetTurretDesiredAngle(targetAngle)
			end
		end
		
		selfTbl.TurretAngleUpdate(self, dt)
	end

	function ENT:ThinkTurnAndShoot(dt) -- Self-explanatory
		local selfTbl = self:GetTable()
		local data = selfTbl.GetTurretData(self)
		local alert = selfTbl.GetTurretAlert(self)
		
		if selfTbl.GetHackedByRebels(self) and selfTbl.kamikazeJumped then
			return
		end

		if data.spinupTime then -- Spinning up or down
			if alert > 0 then
				selfTbl:SetTurretSpinup(math.min(selfTbl:GetTurretSpinup() + dt/data.spinupTime, 1) )
			else
				selfTbl:SetTurretSpinup(math.max(selfTbl:GetTurretSpinup() - dt/data.spinupTime, 0) )
			end
		end
		
		if alert >= 0.5 then -- Turning towards target
			selfTbl.ThinkTurnAndShoot_AngleUpdate(self, dt)
		end

		if (alert >= 1) then -- Shooting
			if (not selfTbl.nextAttack or selfTbl.nextAttack <= CurTime()) and selfTbl.TurretAngleIsSafe(self) then
				selfTbl.Shoot(self)
				selfTbl.nextAttack = CurTime() + selfTbl.TurretFirerate(self)
			end
		else
			selfTbl.attackPatternIndex = 1
		end
	end

	function ENT:ThinkAlert(dt) -- Updating Turret Alert (up or down)
		local selfTbl = self:GetTable()
		local alert = selfTbl.GetTurretAlert(self)

		--Slower reaction speed if we're hacked, or if the target is slow to pick up (alyx)
		local target = selfTbl.CurrentTarget
		if not IsValid(target) then target = nil end

		local alertMul = ((selfTbl.GetHackedByRebels(self) or (target and target.jcms_slowTurretReact)) and 3) or 1
		if target and alert < 1 then
			selfTbl:SetTurretAlert(math.min(alert + dt/(selfTbl.TurretGetAlertTime(self) * alertMul), 1) )
		elseif not target and alert > 0 then
			selfTbl:SetTurretAlert(math.max(alert - dt/(selfTbl.TurretLoseAlertTime(self) / alertMul), 0) )
		end
	end

	function ENT:ThinkTargeting() -- For updating self.CurrentTarget
		local selfTbl = self:GetTable()
		local cTime = CurTime()
		if cTime < (selfTbl.NextTargetingThink or 0) then return end
		
		local origin, radius = selfTbl.GetTurretShootPos(self), selfTbl.TurretRadius(self)

		if selfTbl.IsAboutToDie(self) then -- For picking nearby targets to kamikaze at
			radius = 500
		end

		local targets = selfTbl.GetTargetsAround(self, origin, radius)
		local targetingFunction = jcms.turret_targetingModes[ selfTbl.targetingMode ] or jcms.turret_targetingModes.closest
		local best = targetingFunction(self, targets, origin, radius)

		local alert = selfTbl.GetTurretAlert(self)
		if (alert > 0.5) and IsValid(best) and (selfTbl.lastSFXTarget ~= best) then -- Performing "target acquired" sound
			local hacked = selfTbl.GetHackedByRebels(self)
			local level = (hacked and 90) or 75
			local pitch = (hacked and 130) or 125 
			self:EmitSound("npc/scanner/scanner_siren1.wav", level, pitch)
			selfTbl.lastSFXTarget = best
		elseif (alert == 0) then
			selfTbl.lastSFXTarget = nil
		end
		
		selfTbl.CurrentTarget = best

		--Turrets determine their think-speed. Turrets that need faster/more reliable target acquisition think more (smgs, shotgun)
		--Turrets where that doesn't matter as much (e.g. due to slow turn speed) think less (bolter, gatling)
		local hackedReduce = self:GetHackedByRebels() and 2 or 1 -- Hacked turrets don't need to think as much
		selfTbl.NextTargetingThink = cTime + (1 / selfTbl.GetTurretField(self, "updateRate")) * hackedReduce
	end

	function ENT:ThinkKamikaze()
		local selfTbl = self:GetTable()
		if selfTbl.IsAboutToDie(self) then
			self:Ignite(5)

			if not selfTbl.kamikazeSound then
				self:EmitSound("npc/roller/mine/rmine_predetonate.wav")
				selfTbl.kamikazeSound = true
			end

			if IsValid(selfTbl.CurrentTarget) and not selfTbl.kamikazeJumped and selfTbl.kamikazeTime < CurTime() then
				selfTbl.Kamikaze(self, selfTbl.CurrentTarget)
			end
		end
	end

	function ENT:Think()
		local selfTbl = self:GetTable()
		local cTime = CurTime()
		local data = selfTbl.GetTurretData(self)
		
		local slowdown = selfTbl.GetTurretAlert() <= 0
		local dt = 0.05
		if slowdown then 
			selfTbl.NextTargetingThink = 0
		else
			local firerate = selfTbl.TurretFirerate(self)
			dt = math.min(dt, firerate)
		end

		selfTbl.ThinkTargeting(self) --Resets self.NextTargetingThink

		if slowdown then 
			dt = math.max(dt, selfTbl.NextTargetingThink - cTime)
		end

		selfTbl.ThinkKamikaze(self)
		selfTbl.ThinkAlert(self, dt)
		selfTbl.ThinkTurnAndShoot(self, dt)
		
		self:NextThink(cTime + dt)
		return true
	end

	function ENT:HandleAttackTrace(tr, mypos, data) --Used in shoot & for bolter's penetration
		local selfTbl = self:GetTable()

		data = data or selfTbl.GetTurretData(self) --These are only passed for optimization.
		mypos = mypos or selfTbl.GetTurretShootPos(self)

		tr.Angle = tr.Normal:Angle()

		local tracerEffect, hitEffect, tracerFlag = data.tracer, data.hiteffect, data.tracerFlag or 0
		local tracerUsesPVPTeam = data.tracerUsesPVPTeam

		local effectdata = EffectData()
		effectdata:SetStart(LerpVector(7/tr.StartPos:Distance(tr.HitPos), tr.StartPos, tr.HitPos))
		effectdata:SetScale(math.random(6500, 9000))
		effectdata:SetAngles(tr.Angle)
		effectdata:SetOrigin(tr.HitPos)
		effectdata:SetFlags(tracerFlag)
		if tracerUsesPVPTeam then
			effectdata:SetMaterialIndex(math.max(0, self:GetNWInt("jcms_pvpTeam", -1)))
		else
			effectdata:SetMaterialIndex(0)
		end
		util.Effect(tracerEffect, effectdata)
		
		if hitEffect then
			local effectdata2 = EffectData()
			effectdata2:SetStart(tr.HitPos)
			effectdata2:SetOrigin(tr.HitPos)
			effectdata2:SetScale(5)
			effectdata2:SetNormal(tr.HitNormal)
			effectdata2:SetEntity(tr.Entity)
			util.Effect(hitEffect, effectdata2)
		end

		if data.bulletEffect then 
			data.bulletEffect(self, tr)
		end
		
		if IsValid(tr.Entity) then
			local hackedByRebels = selfTbl:GetHackedByRebels()
			local mul = (hackedByRebels and (0.5 * jcms.npc_GetScaledDamage())) or 1
			local dmg = data.damage * mul
			if hackedByRebels then --bolters can get pretty extreme
				dmg = math.min(50, dmg)
			end

			local damageinfo = DamageInfo()
			damageinfo:SetAttacker((IsValid(selfTbl.jcms_owner) and not(selfTbl.jcms_owner == self)) and selfTbl.jcms_owner or game.GetWorld())
			--NOTE: Damage doesn't get applied when attacker is the turret ent. Unclear why. But we don't even get to our damage hooks.
			damageinfo:SetInflictor(self)
			damageinfo:SetDamage( dmg )
			damageinfo:SetDamageType( bit.bor(data.damagetype, DMG_AIRBOAT) )
			damageinfo:SetReportedPosition(mypos)
			damageinfo:SetDamagePosition(tr.HitPos)
			damageinfo:SetDamageForce( tr.Normal * mul )
			tr.Entity:DispatchTraceAttack(damageinfo, tr, tr.Normal)
			
			if data.OnHit then
				data.OnHit(self, tr.Entity, damageinfo, tr)
			end
		end
	end

	function ENT:Shoot()
		local selfTbl = self:GetTable()
		local data = selfTbl.GetTurretData(self)
		
		local pellets = 1
		
		if data.attackPattern then
			pellets = data.attackPattern[ selfTbl.attackPatternIndex ]
			selfTbl.attackPatternIndex = (selfTbl.attackPatternIndex % #data.attackPattern) + 1
			if pellets <= 0 then
				return
			end
		end
		
		if selfTbl.GetTurretClip(self) > 0 then
			local myangle = self:GetAngles()
			local up, right, fwd = myangle:Up(), myangle:Right(), myangle:Forward()
			local mypos = selfTbl.GetTurretShootPos(self) --glare
			
			for i=1, pellets do
				local dir = selfTbl.turretAngle + myangle
				local spreadX, spreadY = selfTbl.GenTurretSpread(self)
				dir:SetUnpacked(dir.p + spreadY, dir.y + spreadX, dir.r)
				dir = dir:Forward()
				
				local preventDefault = false
				if data.Shoot then
					preventDefault = data.Shoot(self, data, mypos, dir)
				end
				
				if not preventDefault then
					local tr = util.TraceLine {
						start = mypos,
						endpos = mypos + dir*0xFFFF,
						mask = MASK_SHOT,
						filter = self
					}
				
					selfTbl.HandleAttackTrace(self, tr, mypos, data)
				end
			end
			
			local effectdata3 = EffectData()
			effectdata3:SetEntity(self)
			effectdata3:SetScale(data.muzzleflashScale or 1)
			if data.pvpMuzzleflashFlags then
				effectdata3:SetFlags(data.pvpMuzzleflashFlags[self:GetNWInt("jcms_pvpTeam", -1)] or data.muzzleflashFlag or 1)
			else
				effectdata3:SetFlags(data.muzzleflashFlag or 1)
			end
			util.Effect("jcms_muzzleflash", effectdata3)
			
			self:SetTurretClip( self:GetTurretClip() - 1 )
			self:EmitSound(data.sound)
		else
			self:EmitSound(data.soundEmpty)
		end
	end
	
	function ENT:Kamikaze(target) -- Final contribution to J Corp
		local launchVector = (isvector(target) and target or target:WorldSpaceCenter()) - self:WorldSpaceCenter()
		launchVector.z = launchVector.z + math.random(200, 500)
		
		local phys = self:GetPhysicsObject()
		phys:AddVelocity(launchVector)
		phys:AddAngleVelocity(VectorRand(-200, 200))
		
		self.kamikazeJumped = true
		self:EmitSound("npc/roller/mine/rmine_blip3.wav")
		
		if IsValid(self.keepupright) then
			self.keepupright:Remove()
		end
	end

	function ENT:BlowUp(atPos)
		atPos = atPos or self:GetPos()

		util.BlastDamage(self, IsValid(self.jcms_owner) and self.jcms_owner or self, atPos, 200, self:GetHackedByRebels() and 20 or 66)
		local ed = EffectData()
		ed:SetOrigin(atPos)
		ed:SetNormal(vector_up)
		util.Effect("Explosion", ed)
		
		local ed = EffectData()
		ed:SetOrigin(self:WorldSpaceCenter())
		ed:SetRadius(200)
		ed:SetNormal(vector_up)
		ed:SetMagnitude(1.13)
		ed:SetFlags(1)
		util.Effect("jcms_blast", ed)
		
		self:Remove()
	end
	
	function ENT:PhysicsCollide(data, collider)
		if self.kamikazeJumped then
			if not self.kamikazeExploded then
				self:BlowUp(data.HitPos)
				self.kamikazeExploded = true
			end
		end
	end
	
	function ENT:UpdateTurretHealthFraction()
		self:SetTurretHealthFraction(math.Clamp(self:Health() / self:GetMaxHealth(), 0, 1))
	end

	function ENT:OnTakeDamage(dmg)
		self:TakePhysicsDamage(dmg)
		
		if self:Health() > 0 then
			local inflictor, attacker = dmg:GetInflictor(), dmg:GetAttacker()
			if IsValid(inflictor) and jcms.util_IsStunstick(inflictor) and jcms.team_JCorp(attacker) then --Repairs
				if self:GetHackedByRebels() then 
					jcms.util_UnHack(self, attacker)
					
					local maxShield = self:GetNWInt("jcms_sweeperShield_max", -1)
					if maxShield > 0 then
						local colInt = jcms.util_ColorInteger(Color(255, 0, 0))

						self:SetNWInt("jcms_sweeperShield_colour", colInt)
						jcms.net_SendSweeperShieldMark(self, maxShield, colInt) --Force an update clientside
					end
				end

				jcms.util_PerformRepairs(self, attacker)
				self:UpdateTurretHealthFraction()
				return 0
			elseif dmg:GetDamage() > 0 then
				local dmgtype = dmg:GetDamageType()
				
				if bit.band(dmgtype, DMG_CRUSH) > 0 then --Prevent us from being instakilled by physics objects.
					local dmgAmnt = dmg:GetDamage()
					dmgAmnt = math.min(dmgAmnt, 35)
					dmg:SetDamage(dmgAmnt)
				end
				
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
				
				if bit.band(dmgtype, DMG_ACID) > 0 then
					dmg:ScaleDamage(1.25)
				elseif bit.band(dmgtype, bit.bor(DMG_NERVEGAS, DMG_SLOWBURN, DMG_DROWN)) > 0 then
					dmg:ScaleDamage(0)
				else
					dmg:ScaleDamage(0.75)
				end

				if self:GetHackedByRebels() then
					dmg:ScaleDamage(5)
				end
				
				local final = dmg:GetDamage()
				self:SetHealth(self:Health() - final)
				
				if self:Health() <= 0 then
					if attacker:IsPlayer() and jcms.team_NPC(attacker) then
						jcms.director_stats_AddKillForNPC(attacker, 1)
					end

					local ed = EffectData()
					ed:SetOrigin(self:GetPos())
					ed:SetNormal(self:GetAngles():Up())
					ed:SetMagnitude(2)
					ed:SetScale(2)
					util.Effect("Sparks", ed)
					
					if self:GetHackedByRebels() then
						self:Kamikaze( self:GetPos() )
					else
						local selfPos = self:GetPos()
						local sweeperDelay = ((#jcms.GetSweepersInRange(selfPos, 250) > 0 and 2) or 0)--Give us more time if there's a player nearby.
						self.kamikazeTime = CurTime() + 0.5 + sweeperDelay

						timer.Simple(4 + sweeperDelay, function()
							if IsValid(self) and not self.kamikazeJumped then
								self:Kamikaze( self:GetPos() + VectorRand(-256, 256) )
							end
						end)
					end
				end
				
				self:UpdateTurretHealthFraction()
				return final
			end
		else
			return 0
		end
	end
	
	function ENT:Use(ply)
		if self:GetVelocity():LengthSqr() < 64*64 then
			local dif = self:WorldSpaceCenter() - ply:EyePos()
			local len = dif:Length()
			if len > 256 or len == 0 then return end

			dif:Div(len)
			dif:Mul(53)
			dif.z = 54

			self:GetPhysicsObject():AddVelocity(dif)
			self:EmitSound("physics/body/body_medium_impact_soft"..math.random(1,7)..".wav")
			ply:ViewPunch(Angle(math.Rand(-1, 0), math.Rand(-1, 1), 0))
		end
	end
end

if CLIENT then
	function ENT:Think()
		local selfTbl = self:GetTable()
		local frameTime = FrameTime()
		local ang = selfTbl.turretAngle or Angle(0,0,0) --self:TurretAngle()

		self:ManipulateBoneAngles(1, Angle(ang.y,0,0))
		self:ManipulateBoneAngles(2, Angle(0,0,ang.p))
		
		local spinning = selfTbl.GetTurretSpinup(self)
		selfTbl.animSpinup = ((selfTbl.animSpinup or 0) + spinning*frameTime*4)%1
		
		local spinBoneId = self:LookupBone("spinbone")
		if spinBoneId then
			self:ManipulateBoneAngles(spinBoneId, Angle(selfTbl.animSpinup*360,0,0))
		end
		
		if spinning > 0 then
			if not selfTbl.soundSpinup then
				selfTbl.soundSpinup = CreateSound(self, "npc/turret_wall/turret_loop1.wav")
				selfTbl.soundSpinup:ChangePitch(20, 0)
				selfTbl.soundSpinup:ChangeVolume(0, 0)
				selfTbl.soundSpinup:Play()
			end
			
			selfTbl.soundSpinup:ChangePitch(Lerp(math.sqrt(spinning), 20, 130), 0.2)
			selfTbl.soundSpinup:ChangeVolume(math.min(1, spinning*10), 0.1)
		elseif selfTbl.soundSpinup then
			selfTbl.soundSpinup:Stop()
			selfTbl.soundSpinup = nil
		end
		
		local hfrac = selfTbl.GetTurretHealthFraction(self)^5
		if frameTime > 0 and math.random() < (hfrac<=0 and 0.75 or (1 - hfrac)*0.25)*0.2 then
			local ed = EffectData()
			ed:SetOrigin(self:WorldSpaceCenter() + VectorRand(-16, 16))
			ed:SetMagnitude(1-hfrac)
			ed:SetScale(1-hfrac)
			ed:SetRadius(4-hfrac)
			ed:SetNormal(VectorRand())
			util.Effect("Sparks", ed)
		end
		
		selfTbl.TurretAngleUpdate(self, frameTime)
	end

	function ENT:Draw(flags)
		self:DrawModel()

		local dist = jcms.EyePos_lowAccuracy:DistToSqr(self:WorldSpaceCenter())
		if dist < 1000^2 then 
			self:DrawAmmoCounter(dist)
		end
	end
	
	local spriteMat = Material("particle/fire")
	local spriteMat2 = Material("particle/Particle_Glow_04")
	local beamCol = Color(120, 255, 255, 50)
	function ENT:DrawTranslucent()
		local selfTbl = self:GetTable()
		if selfTbl:GetHackedByRebels() then
			jcms.render_HackedByRebels(self)
		end

		if selfTbl:GetSniperGlare() then 
			local shootPos = selfTbl.GetTurretShootPos(self)
			
			local ang = self:GetAngles()
			ang:Add(selfTbl.turretAngle)
			local normal = ang:Forward()
			
			shootPos:Add(normal * 7.5)
			shootPos:Add(ang:Right() * -1)
			shootPos:Add(ang:Up() * 1.6)

			local glarePos =  shootPos + normal * 25

			local dif = EyePos()
			dif:Sub(shootPos)
			local dist = dif:Length()
			dif:Normalize()

			local dot = math.Clamp((dif:Dot(normal)-0.4)/0.6, 0, 1)^4 
			local scale = (dist - 350) / 1000
			local superDot = math.Remap(dot, 0.6, 1, 0, 1)
			if dot > 0.01 and scale > 0 then
				local r,g,b = self:GetGlareColour():Unpack()
				beamCol:SetUnpacked(r,g,b, 255)

				render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					render.SetMaterial(spriteMat)
					render.DrawSprite(glarePos, Lerp(dot, 0, 256)*scale, Lerp(dot^2, 0, 64)*scale, beamCol)
					
					render.SetMaterial(spriteMat2)
					if superDot > 0 then
						render.DrawQuadEasy(glarePos, normal, math.Rand(32, 48)*scale*superDot*superDot, math.Rand(2, 10)*scale*superDot, beamCol, math.cos(CurTime())*48)
						render.DrawQuadEasy(glarePos, normal, math.Rand(48, 64)*scale*superDot*superDot, math.Rand(3, 12)*scale*superDot, beamCol, math.sin(CurTime())*32)
					end
				render.OverrideBlend(false)
			end
		end
	end
	
	function ENT:OnRemove()
		if self.soundSpinup then
			self.soundSpinup:Stop()
		end
	end
	
	function ENT:DrawAmmoCounter( eyeDistSqr )
		local pos = self:GetPos()
		local ang = self:GetAngles()
		local selfTbl = self:GetTable()
		
		local up = ang:Up()
		local fw = ang:Forward()
		fw:Mul(-21)
		local right = ang:Right()
		right:Mul(0.4)
		pos:Add(fw)
		pos:Add(up*2)
		pos:Add(right)

		ang:RotateAroundAxis(up, -90)
		ang:RotateAroundAxis(ang:Forward(), 90)
		
		cam.Start3D2D(pos, ang, 1/32)
			local clip, maxClip = selfTbl:GetTurretClip(), selfTbl:GetTurretMaxClip()
			local f = 1 - clip / maxClip
			local x, y, w, h, p = -276, 0, 530, 170, 16
			

			local r, g, b = jcms.device_GetColor("bright1", self:GetNWInt("jcms_pvpTeam", -1)):Unpack()
			if selfTbl:GetHackedByRebels() then 
				r, g, b = 162, 81, 255
			end
			if f >= 0.5 then
				local blip = math.ease.InCirc( (math.sin(CurTime()*24) + 1)/2 )
				surface.SetDrawColor(Lerp(blip, r*0.12, r), Lerp(blip, g*0.12, g), Lerp(blip, b*0.12, b))
			else
				surface.SetDrawColor(r, g, b)
			end
			
			local ch = w - p*2
			surface.DrawRect(x+p,y+p,w-p*2-ch*f,h-p*2)
			if jcms.performanceEstimate > 40 or eyeDistSqr < 600^2 then --If lagging, LOD the text & outline more aggressively.
				surface.DrawOutlinedRect(x,y,w,h, p/3)
				draw.SimpleTextOutlined(("%d / %d"):format(clip, maxClip), "jcms_hud_big", x + w/2, y + h/2, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, surface.GetDrawColor())
			end
		cam.End3D2D()
	end
end
