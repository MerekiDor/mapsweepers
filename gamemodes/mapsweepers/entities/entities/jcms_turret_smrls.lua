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
ENT.Base = "jcms_turret"
ENT.PrintName = "Missile Platform"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
	if SERVER then
		local health = 300
		self:SetHealth(health)
		self:SetMaxHealth(health)
		self:SetModel("models/jcms/jcorp_smrls.mdl")
		self:PhysicsInitStatic(SOLID_VPHYSICS)
		self.nextAttack = 0

		self.kamikazeTime = math.huge

		if jcms.npc_airCheck() then
			local shootPos = self:GetTurretShootPos()
			
			-- Scanning nearby area {{{
				local startingPositions = { shootPos }
				local pitchMin, pitchMax = math.min(-90, jcms.turrets.smrls.pitchLockMin - 10), math.max(90, jcms.turrets.smrls.pitchLockMax + 20)
				local baseAngle = self:GetAngles()
				local up, right = baseAngle:Up(), baseAngle:Right()

				local traceRes = {}
				local traceInfo = {
					mins = Vector(-12, -12, -12),
					maxs = Vector(12, 12, 12),
					mask = MASK_NPCSOLID_BRUSHONLY,
					filter = self,
					output = traceRes,
					start = shootPos
				}

				for lat=1,12 do -- yaw
					local lat_a = math.Remap(lat, 0, 12, 0, 360)
					for long=1,6 do -- pitch
						local long_a = math.Remap(long, 1, 6, pitchMin, pitchMax)

						local ang = Angle(baseAngle)
						ang:RotateAroundAxis(right, long_a)
						ang:RotateAroundAxis(up, lat_a)

						local vec = ang:Forward()
						vec:Mul(1024)
						vec:Add(shootPos)

						traceInfo.endpos = vec
						util.TraceHull(traceInfo)

						if not traceRes.Hit then
							table.insert(startingPositions, traceRes.HitPos)
						else
							for i=1, 4 do
								vec:Sub(shootPos)
								vec:Mul(0.666)
								vec:Add(shootPos)

								util.TraceHull(traceInfo)
								if not traceRes.Hit then
									table.insert(startingPositions, traceRes.HitPos)
									break
								end
							end
						end
					end
				end
			-- }}}

			-- Trying to reach nodes {{{
				for i, sp in ipairs(startingPositions) do
					local nodesToCheck = jcms.pathfinder.getNodesInPVS(sp)
					local nodesDists2 = {}
					for i, node in ipairs(nodesToCheck) do
						nodesDists2[node] = node.pos:DistToSqr(shootPos)
					end

					table.sort(nodesToCheck, function(first, last)
						return nodesDists2[first] < nodesDists2[last]
					end)

					traceInfo.start = sp
					for i, node in ipairs(nodesToCheck) do
						traceInfo.endpos = node.pos
						util.TraceHull(traceInfo)

						if not traceRes.Hit then
							self.startNode = node
							
							if sp:DistToSqr(shootPos) > 9 then
								self.extraStartPos = sp
							end

							debugoverlay.Line(sp, node.pos, 3, Color(255, 255, 0))
							debugoverlay.Line(shootPos, sp, 3, Color(255, 128, 0))
							break
						end
					end

					if self.startNode then
						break
					end
				end
			-- }}}
		end

		self.jcms_stunEnd = CurTime()
		self:UpdateTurretKind("smrls")
	end

	self.turretAngle = Angle(0, 0, 0)
end

function ENT:TurretAngleIsSafe()
	local target = self:GetTurretDesiredAngle()
	local angle = self.turretAngle
	return math.abs(math.AngleDifference(angle.y, target.y)) <= 12
end

function ENT:SetupBoosted() -- For engineer
	self:SetMaxHealth(450)
	self:SetHealth(450)
	self:SetTurretBoosted(true)
end

if SERVER then
	-- Thinking {{{
	function jcms.turret_GlobalMissilePlatformSlowThink()
		local ct = CurTime()
		if ct - (jcms.missileplatform_lastSlowThink or 0) < 1 then return end
		jcms.missileplatform_lastSlowThink = ct

		local turrets = ents.FindByClass("jcms_turret_smrls")
		if #turrets <= 0 then return end
		for i, turret in ipairs(turrets) do
			turret.CurrentTarget = nil
		end

		local hasAir = jcms.npc_airCheck()

		local targetHealthBuffer = {} -- We don't want to fire so many missiles that it's an overkill. We track health of each target here.
		local pool = {}
		table.Add(pool, ents.FindByClass("jcms_*"))
		for i=#pool, 1, -1 do
			local ent = pool[i]
			local entTbl = ent:GetTable()
			local tg = entTbl.Target
			if IsValid(tg) and entTbl.Damage then
				if (targetHealthBuffer[tg] ~= true) then
					targetHealthBuffer[tg] = (targetHealthBuffer[tg] or 0) + entTbl.Damage * 1.5
					if targetHealthBuffer[tg] >= tg:Health() then
						targetHealthBuffer[tg] = true
					end
				end

				table.remove(pool, i)
			end
		end

		table.Add(pool, ents.FindByClass("npc_*"))
		table.Add(pool, player.GetAll())
		if #pool <= 0 then return end

		local traceRes = {}
		local traceData = {
			mins = Vector(-8, -8, -8),
			maxs = Vector(8, 8, 8),
			mask = MASK_NPCSOLID_BRUSHONLY,
			output = traceRes
		}

		local targetPriorities = {}
		local targetsSorted = {}
		local targetsVisibleByAirgraph = {}
		local bm = SysTime()
		for i, candidate in ipairs(pool) do
			if not (IsValid(candidate) and candidate:Health() > 0) then continue end
			if not jcms.team_GoodTarget(candidate) then continue end
			if targetHealthBuffer[ candidate ] == true then continue end
			targetPriorities[candidate] = (candidate.jcms_danger or 1)*2 + math.Clamp(candidate:Health() / candidate:GetMaxHealth(), 0, 1)

			local vis = false
			if hasAir then
				local pos = candidate:WorldSpaceCenter()
				local _, isUnderSky = jcms.util_GetSky(pos)
				if isUnderSky then
					targetsVisibleByAirgraph[candidate] = true -- bold assumption here, but is 3-4 times faster
					vis = true
				else
					local nearestNode = jcms.pathfinder.getNearestNodePVS(pos)
					if nearestNode then
						traceData.start = nearestNode.pos
						traceData.endpos = pos
						util.TraceHull(traceData)
						if not traceRes.Hit or traceRes.Entity == candidate then
							targetsVisibleByAirgraph[candidate] = true 
							vis = true
						end
					end
				end
			end

			if not vis then -- the hard way, we try to see if any of the missile platforms see it.
				for j, turret in ipairs(turrets) do
					if turret ~= candidate and turret:TurretVisibleTrace(candidate) then
						vis = true
						break
					end
				end
			end

			if vis then
				table.insert(targetsSorted, candidate)
			end
		end

		if #targetsSorted <= 0 then return end

		table.sort(targetsSorted, function(first, last)
			return targetPriorities[first] > targetPriorities[last]
		end)

		for i, turret in ipairs(turrets) do
			local isHacked = turret:GetHackedByRebels()
			local pvpTeam = turret:GetNWInt("jcms_pvpTeam", -1)
			local dmg = turret:TurretDamage() * 1.5

			for j, target in ipairs(targetsSorted) do
				if targetHealthBuffer[j] ~= true and jcms.turret_IsDifferentTeam_Optimised(isHacked, target, pvpTeam) then
					local directlyVisible = turret:TurretVisibleTrace(target)
					local canFire = (turret.startNode and targetsVisibleByAirgraph[target]) or directlyVisible

					if canFire then
						turret.CurrentTarget = target
						turret.CurrentTargetDirectlyVisible = directlyVisible

						targetHealthBuffer[j] = (targetHealthBuffer[j] or 0) + dmg
						if targetHealthBuffer[j] >= target:Health() then
							targetHealthBuffer[j] = true -- We've exhausted this target's health, therefore we can exclude it
						end

						break
					end
				end
			end
		end
	end

	function ENT:ThinkTurnAndShoot_AngleUpdate(dt)
		local selfTbl = self:GetTable()
		local target = selfTbl.CurrentTarget

		if IsValid(target) then
			local origin = selfTbl.GetTurretShootPos(self)
			local realAngle = self:GetAngles()

			local targetPos
			if selfTbl.CurrentTargetDirectlyVisible then
				targetPos = jcms.turret_GetTargetPos(self, target, origin)
			elseif self.extraStartPos then
				targetPos = self.extraStartPos
			elseif self.startNode then
				targetPos = self.startNode.pos
			end

			if targetPos then
				local targetAngle = (targetPos - origin):Angle()
				targetAngle:Sub(realAngle)

				if not selfTbl.GetTurretDesiredAngle(self):IsEqualTol(targetAngle, 1.5) then
					self:SetTurretDesiredAngle(targetAngle)
				end
			end
		end
		
		self:TurretAngleUpdate(dt)
	end

	function ENT:ThinkTargeting()
		local selfTbl = self:GetTable()
		jcms.turret_GlobalMissilePlatformSlowThink()

		local alert = selfTbl.GetTurretAlert(self)
		local target = self.CurrentTarget
		if IsValid(target) and (selfTbl.lastSFXTarget ~= target) then -- Performing "target acquired" sound
			local hacked = selfTbl.GetHackedByRebels(self)
			local level = (hacked and 90) or 75
			local pitch = (hacked and 105) or 100
			self:EmitSound("npc/scanner/scanner_siren1.wav", level, pitch)
			selfTbl.lastSFXTarget = target
		elseif alert <= 0 then
			selfTbl.lastSFXTarget = nil
		end
	end
	-- }}}
	
	function ENT:Shoot()
		if self:GetTurretClip() > 0 then
			local myangle = self:GetAngles()
			local up, right, fwd = myangle:Up(), myangle:Right(), myangle:Forward()
			local mypos = self:GetTurretShootPos()
			
			local dir = self:TurretAngle() + myangle
			local spreadX, spreadY = self:GenTurretSpread()
			dir:SetUnpacked(dir.p + spreadY, dir.y + spreadX, dir.r)
			dir = dir:Forward()
			
			local missile = ents.Create("jcms_micromissile")
			missile:SetPos(mypos)
			missile:SetAngles(myangle)
			missile:SetOwner(self)

			local dmg = self:TurretDamage()
			missile.Damage = dmg

			local rad = self:GetTurretField("blastRadius") or 100
			missile.Radius = rad
			missile.Proximity = rad/4

			missile.jcms_owner = self.jcms_owner
			missile.Target = self.CurrentTarget
			missile.Damping = 0.76
			missile.Speed = 1500
			missile.ActivationTime = CurTime() + 0.5

			local col = self:GetHackedByRebels() and jcms.factions_GetColor("rebel") or jcms.util_GetPVPColor(self.jcms_owner)
			missile:SetBlinkColor( Vector(col.r/255, col.g/255, col.b/255) )
			missile:Spawn()

			missile.jcms_isPlayerMissile = not self:GetHackedByRebels()

			if IsValid(self.CurrentTarget) then
				if not self:TurretVisibleTrace(self.CurrentTarget) then
					if self.startNode then --Lua error prevention. Some maps don't have an airgraph at all.
						missile.Path = jcms.pathfinder.navigate(self.startNode, self.CurrentTarget:WorldSpaceCenter())
					end
					if missile.Path and self.extraStartPos then
						table.insert(missile.Path, { pos = self.extraStartPos })
					end
					missile.Damping = 0.89
					missile.LoweredDampingPath = 2
					missile:GetPhysicsObject():SetVelocity(dir*64)
				else
					missile:GetPhysicsObject():SetVelocity(dir*300)
				end
			end

			missile:EmitSound("weapons/rpg/rocket1.wav", 90, 113)
			missile:CallOnRemove( "jcms_rpg_removeMissile", function()
				missile:StopSound("weapons/rpg/rocket1.wav")
			end)
			
			local effectdata = EffectData()
			effectdata:SetEntity(self)
			effectdata:SetScale(5)
			effectdata:SetFlags(1)
			util.Effect("jcms_muzzleflash", effectdata)
			
			self:SetTurretClip( self:GetTurretClip() - 1 )
			self:EmitSound(self:GetTurretData().sound)
		end
	end

	function ENT:Kamikaze(target)
		self.kamikazeJumped = true
		self:EmitSound("npc/roller/mine/rmine_blip3.wav")
		self:BlowUp()
	end

	function ENT:Use(ply)
		-- Can't nudge
	end
end

if CLIENT then
	function ENT:Think()
		local myang = self:GetAngles()
		local ang = self:TurretAngle()
		self:ManipulateBoneAngles(1, Angle(ang.y,0,0))
		self:ManipulateBoneAngles(2, Angle(0,0,-ang.p))
		
		local hfrac = self:GetTurretHealthFraction()^5
		if FrameTime() > 0 and math.random() < (hfrac<=0 and 0.75 or (1 - hfrac)*0.25)*0.2 then
			local ed = EffectData()
			ed:SetOrigin(self:WorldSpaceCenter() + VectorRand(-16, 16))
			ed:SetMagnitude(1-hfrac)
			ed:SetScale(1-hfrac)
			ed:SetRadius(4-hfrac)
			ed:SetNormal(VectorRand())
			util.Effect("Sparks", ed)
		end
		
		self:TurretAngleUpdate(FrameTime())
	end
	
	function ENT:Draw(flags)
		self:DrawModel()
	end
end
