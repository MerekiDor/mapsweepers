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

jcms.turrets = {
	smg = {
		damage = 5,
		firerate = 0.083,
		damagetype = DMG_BULLET,
		attackPattern = { 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 0 },
		muzzleflashScale = 1.85,
		muzzleflashFlag = 3,
		clip = 750,
		
		radius = 1600,
		tracer = "StriderTracer",
		hiteffect = "AR2Impact",
		
		timeAlert = 0.5,
		timeLoseAlert = 2,

		updateRate = 4, --How often do we try to acquire targets (optimisation)
		
		turnSpeedYaw = 180,
		turnSpeedPitch = 45,
		pitchLockMin = -66,
		pitchLockMax = 66,
		
		spreadX = 2.05,
		spreadY = 1.41,
		targetingMode = "weakest",
		
		sound = "Weapon_AR2.NPC_Single",
		soundEmpty = "Weapon_AR2.Empty",
		
		boosted = { --engineer.
			attackPattern = { 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0 },
			firerate = 0.068
			--I can't think of anything other than generic stat boosts, since it's just a generalist.
			--I picked changes that were the most visually obvious.
			--If you can think of anything better it'd be appreciated, this is a bit underwhelming. Not the end of the world though.
		}
	},
	
	bolter = {
		damage = 60,
		firerate = 1.1,
		damagetype = DMG_BULLET + DMG_ALWAYSGIB,
		muzzleflashScale = 2,
		pvpMuzzleflashFlags = { [2] = 2 },
		muzzleflashFlag = 4,
		clip = 100,
		
		radius = 2600,
		tracer = "jcms_bolt",
		tracerFlag = 0,
		tracerUsesPVPTeam = true,
		hiteffect = "AR2Impact",
		
		timeAlert = 1,
		timeLoseAlert = 2,

		updateRate = 3, --How often do we try to acquire targets (optimisation)
		
		turnSpeedYaw = 80,
		turnSpeedPitch = 40,
		pitchLockMin = -66,
		pitchLockMax = 66,
		
		spreadX = 0.4,
		spreadY = 0.3,
		targetingMode = "closestangle",
		
		sound = "Airboat.FireGunHeavy",
		soundEmpty = "Weapon_AR2.Empty",
		
		postSpawn = function(turret)
			if jcms.util_IsPVP() then
				turret:SetSniperGlare(true)
			end
		end,

		boosted = { --engineer.
			postSpawn = function(turret)
				jcms.npc_SetupSweeperShields(turret, 35, 10, 5, Color(255, 0, 0))
				if jcms.util_IsPVP() then
					turret:SetSniperGlare(true)
				end
			end
		}
	},
	
	shotgun = {
		damage = 9,
		firerate = 0.8,
		damagetype = DMG_BUCKSHOT,
		attackPattern = { 19, 18, 16, 17 },
		muzzleflashScale = 1.4,
		muzzleflashFlag = 2,
		clip = 100,
		
		radius = 750,
		tracer = "jcms_laser",

		updateRate = 5, --How often do we try to acquire targets (optimisation)
		
		timeAlert = 0.5,
		timeLoseAlert = 2,
		
		turnSpeedYaw = 190,
		turnSpeedPitch = 66,
		pitchLockMin = -66,
		pitchLockMax = 66,
		
		spreadX = 10.5,
		spreadY = 5,
		targetingMode = "closest",
		
		sound = "Weapon_Shotgun.NPC_Single",
		soundEmpty = "Weapon_AR2.Empty",
		
		boosted = { --engineer.
			tracerFlag = 1,
			spreadX = 9,

			OnHit = function(turret, target, dmgInfo, tr)
				if not jcms.team_JCorp(target) then 
					target:Ignite(2.5)
				end
			end
		}
	},
	
	gatling = {
		damage = 8,
		firerate = function(self) 
			return Lerp(self:GetTurretSpinup(), 0.5, 0.04)
		end,
		spinupTime = 3.5,
		damagetype = DMG_BULLET,
		muzzleflashScale = 1.25,
		muzzleflashFlag = 1,
		clip = 1250,
		
		radius = 1400,
		tracer = "jcms_bolt",
		tracerFlag = 1,
		
		timeAlert = 0.5,
		timeLoseAlert = 2,

		updateRate = 3, --How often do we try to acquire targets (optimisation)
		
		turnSpeedYaw = 48,
		turnSpeedPitch = 16,
		pitchLockMin = -66,
		pitchLockMax = 66,
		
		spreadX = 2.4,
		spreadY = 2.0,
		targetingMode = "closestangle",
		
		sound = "Weapon_SMG1.NPC_Single",
		soundEmpty = "Weapon_SMG1.Empty",
		
		boosted = { --engineer
			damage = 5, --Offset the massive increase in damage from the blast a little.
			tracerFlag = 2,
			bulletEffect = function(turret, tr)
				util.BlastDamage(turret, (IsValid(turret.jcms_owner) and turret.jcms_owner) or turret, tr.HitPos, 75, 8)
			end
		}
	},

	smrls = {
		damage = 100,
		blastRadius = 250,
		firerate = 3,
		damagetype = DMG_BLAST,
		clip = 32,
		
		radius = 5400,
		radiusMin = 600,
		
		timeAlert = 1,
		timeLoseAlert = 5,

		updateRate = 4,
		
		turnSpeedYaw = 80,
		turnSpeedPitch = 80,
		pitchLockMin = -24,
		pitchLockMax = 40,
		
		spreadX = 0.2,
		spreadY = 0.2,
		targetingMode = "smrls",
		
		sound = "PropAPC.FireRocket",
		soundEmpty = "Weapon_AR2.Empty",
		
		boosted = {}
	}
}

jcms.turrets_boosted = {}
--Create tables for the boosted variants.
for k, v in pairs(jcms.turrets) do 
	local boostedTbl = table.Copy(v)
	if v.boosted then --Override our values with the boosted versions
		table.Merge(boostedTbl, v.boosted)
		v.boosted = nil 
		boostedTbl.boosted = nil
	end

	jcms.turrets_boosted[k] = boostedTbl
end

jcms.turret_targetingModes = {
	closest = function(self, targets, origin, radius)
		local best, npcPos
		local mindist2

		for i, target in ipairs(targets) do
			if not IsValid(target) then continue end
			local targetPos = jcms.turret_GetTargetPos(self, target, origin)
			local dist2 = origin:DistToSqr(targetPos)
			if not mindist2 or dist2 < mindist2 then
				mindist2, best, npcPos = dist2, target, targetPos
			end
		end
		
		return best, npcPos
	end,

	closestangle = function(self, targets, origin, radius)
		local best, npcPos
		local leastDelta

		local curAngle = self:GetAngles() + self:TurretAngle()
		curAngle:Normalize()

		for i, target in ipairs(targets) do
			if not IsValid(target) then continue end
			local targetPos = jcms.turret_GetTargetPos(self, target, origin)

			local targetAngle = (targetPos - origin):Angle()
			local delta = math.AngleDifference(targetAngle.p, curAngle.p)^2 + math.AngleDifference(targetAngle.y, curAngle.y)^2

			if not leastDelta or delta < leastDelta then
				leastDelta, best, npcPos = delta, target, targetPos
			end
		end

		return best, npcPos
	end,

	weakest = function(self, targets, origin, radius)
		local best, npcPos
		local minhealth

		for i, target in ipairs(targets) do
			if not IsValid(target) then continue end				local health = target:Health()
			if not minhealth or health < minhealth then
				local targetPos = jcms.turret_GetTargetPos(self, target, origin)
				minhealth, best, npcPos = health, target, targetPos
			end
		end

		return best, npcPos
	end,

	strongest = function(self, targets, origin, radius)
		local best, npcPos
		local maxhealth

		for i, target in ipairs(targets) do
			if not IsValid(target) then continue end
			local health = target:Health()
			if not maxhealth or health > maxhealth then
				local targetPos = jcms.turret_GetTargetPos(self, target, origin)
				maxhealth, best, npcPos = health, target, targetPos
			end
		end

		return best, npcPos
	end
}

jcms.turret_bodygroups = {
	smg = 1, 
	bolter = 2,
	gatling = 3,
	shotgun = 4
}