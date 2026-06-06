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

-- // Combine-Specific-Functions {{{
	function jcms.npc_Gunship_Think_Rally(npc, bRad, bPrep, bLife, bDPS, bColour)
		if npc.jcms_npcState == jcms.NPC_STATE_GUNSHIPRALLY then
			--npc:SetSaveValue("m_flMaxSpeed", 700)
			npc:EmitSound("npc/combine_gunship/see_enemy.wav", 140, 80, 1, CHAN_AUTO, 0, 38) --Roar / Announce
			npc:EmitSound("npc/strider/striderx_pain8.wav", 140, 80, 1, CHAN_AUTO, 0, 38)
			timer.Simple(bPrep - 1.4, function()
				if not IsValid(npc) then return end
				npc:EmitSound("npc/strider/charging.wav", 140, 80, 0.75, CHAN_AUTO, 0, 0)
			end)

			--Start the beam
			npc.deathRay = ents.Create("jcms_deathray")
			npc.deathRay:SetPos(npc:GetPos() - Vector(0,0,25))
			npc.deathRay:SetParent(npc, 4)
			npc.deathRay.filter = npc --todo: We still seem to be killing ourselves sometimes somehow?
			npc.deathRay:Spawn()

			npc.deathRay:SetBeamColour(bColour or Vector(0, 1, 1))
			npc.deathRay:SetBeamRadius(bRad)
			npc.deathRay:SetBeamPrepTime(bPrep)
			npc.deathRay:SetBeamLifeTime(bLife)

			npc.deathRay.DPS = bDPS
			npc.deathRay.DPS_DIRECT = bDPS

			npc.jcms_gunshipMoveStart = CurTime()
			npc.jcms_npcState = jcms.NPC_STATE_GUNSHIPPRECHARGE
			return true 
		end

		if npc.jcms_npcState == jcms.NPC_STATE_GUNSHIPPRECHARGE then
			local toTarget = (npc.jcms_gunshipMoveTarget - npc:GetPos()):GetNormalized()
			npc:SetSaveValue("m_vecDesiredFaceDir", toTarget )
			--npc:SetAngles(toTarget:Angle())

			if CurTime() - npc.jcms_gunshipMoveStart > bPrep - 0.5 then
				npc.jcms_npcState = jcms.NPC_STATE_GUNSHIPCHARGE
			end
			return true
		end

		return false
	end

	function jcms.npc_Gunship_Setup(npc, strafeDelay)
		npc:Fire("DisableGroundAttack") --Disable the default belly cannon

		npc:SetMaxHealth(npc:GetMaxHealth()*50) --5k hp, makes cone targeting treat us with proper priority.
		npc:SetHealth(npc:GetMaxHealth())
		npc.jcms_gunship_hits = 0 --Set by NPC, here to avoid a lua error.
		npc.jcms_gunship_maxHits = 0 --ditto
		npc.jcms_gunship_hitAcc = 0 --Accumulator for FX

		npc.jcms_ignoreStraggling = true
		
		--Custom AI stuff
		jcms.npc_setupNPCAirNav(npc)

		npc.jcms_gunshipNextBlast = CurTime() + strafeDelay --Delay until they start causing problems.
		npc.jcms_gunshipMoveTarget = npc:GetPos()
		npc.jcms_gunshipDefaultSpeed = npc:GetInternalVariable("m_flMaxSpeed")

		jcms.npc_gunship_onFire = false --VFX / half health.

		npc:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS) --Don't collide with other air units.
	end

	function jcms.npc_Gunship_TakeDamage(npc, dmg)
		npc:SetHealth(npc:GetMaxHealth())
		local damage = dmg:GetDamage() 
		local hits = 1
		if damage < 50 then 
			hits = 0.015
		elseif damage < 125 then 
			hits = 0.5
		end
		
		if npc:GetNWInt("jcms_sweeperShield", -1) > 0 then 
			hits = 0
		end

		npc.jcms_gunship_hits = npc.jcms_gunship_hits - hits
		if npc.jcms_gunship_hits <= 0 and not npc.jcms_GunshipDead then 
			npc.jcms_GunshipDead = true
			npc:SetHealth(0)
			--hook.Call("OnNPCKilled", GAMEMODE, npc, dmg:GetAttacker(), dmg:GetInflictor())
		end

		if not jcms.npc_gunship_onFire and npc.jcms_gunship_hits <= npc.jcms_gunship_maxHits/2 then 			
			local ed = EffectData()
			ed:SetEntity(npc)
			ed:SetScale(0)
			ed:SetStart( Vector(-150,0,15) )
			util.Effect("jcms_burningcharacter", ed)

			jcms.npc_gunship_onFire = true
		end
		
		npc.jcms_gunship_hitAcc = npc.jcms_gunship_hitAcc + hits
		if npc.jcms_gunship_hitAcc > 1 then
			local ed = EffectData()
			ed:SetOrigin(dmg:GetDamagePosition() + VectorRand(-25, 25)) 
			util.Effect("Explosion", ed)

			npc:EmitSound("NPC_CombineGunship.Pain", 140)

			npc.jcms_gunship_hitAcc = 0
		end

		local ed = EffectData()
		ed:SetOrigin(dmg:GetDamagePosition()) 
		util.Effect("RPGShotDown", ed)

		
		npc:SetNWFloat("HealthFraction", npc.jcms_gunship_hits / npc.jcms_gunship_maxHits)
	end

-- // }}}

-- // {{{ Enums for custom behaviours
	jcms.NPC_STATE_GUNSHIPRALLY = 3
	jcms.NPC_STATE_GUNSHIPPRECHARGE = 4
	jcms.NPC_STATE_GUNSHIPCHARGE = 5
-- // }}}

jcms.npc_commanders["combine"] = {
	placePrefabs = function(c, data)
		--Faction prefabs
		local count = math.ceil(jcms.mapgen_AdjustCountForMapSize( 2 ) * jcms.runprogress_GetDifficulty())
		jcms.mapgen_PlaceFactionPrefabs(count, "combine")
	end
}

jcms.npc_types.combine_scanner = {
	faction = "combine",
	noArenaMode = true,
	
	danger = jcms.NPC_DANGER_FODDER,
	cost = 0.1,
	swarmWeight = 0.35,
	swarmLimit = 1,

	portalScale = 0.5,

	class = "npc_cscanner",
	bounty = 20,

	airUnit = true, --Stop us from receiving the in-air bonus

	proficiency = WEAPON_PROFICIENCY_GOOD
}

jcms.npc_types.combine_metrocop = {
	portalSpawnWeight = 0.8,
	faction = "combine",
	
	danger = jcms.NPC_DANGER_FODDER,
	cost = 0.85,
	swarmWeight = 0.75,

	class = "npc_metropolice",
	bounty = 40,

	weapons = {
		weapon_pistol = 3,
		weapon_smg1 = 2
	},

	postSpawn = function(npc)
		npc:SetKeyValue("manhacks", math.random() < 0.6 and "1" or "0")
	end,

	proficiency = WEAPON_PROFICIENCY_GOOD
}

jcms.npc_types.combine_soldier = {
	portalSpawnWeight = 1.0,
	faction = "combine",
	
	danger = jcms.NPC_DANGER_FODDER,
	cost = 1.1,
	swarmWeight = 1,

	class = "npc_combine_s",
	bounty = 70,

	weapons = {
		weapon_shotgun = 1,
		weapon_ar2 = 2,
		weapon_smg1 = 4
	},

	postSpawn = function(npc)
		npc:SetKeyValue("NumGrenades", "1")

		local wep = npc:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "weapon_smg1" then 
			wep:SetSaveValue("m_fMaxRange1", 1000)
		end
	end,

	proficiency = WEAPON_PROFICIENCY_VERY_GOOD
}

jcms.npc_types.combine_suppressor = {
	portalSpawnWeight = 0.04,
	faction = "combine",
	
	danger = jcms.NPC_DANGER_STRONG,
	cost = 1.75,
	swarmWeight = 0.5,

	class = "npc_combine_s",
	bounty = 130,

	model = "models/combine_soldier_prisonguard.mdl",
	skin = 2,

	weapons = {
		weapon_jcms_mg = 1,
	},

	postSpawn = function(npc)
		npc:SetKeyValue("NumGrenades", "3")
		jcms.npc_SetupSweeperShields(npc, 40, 8, 4.5, Color(22, 65, 207))
		npc:SetHealth( npc:GetMaxHealth() )
	end,

	proficiency = WEAPON_PROFICIENCY_VERY_GOOD
}

jcms.npc_types.combine_sniper = {
	portalSpawnWeight = 0.05,
	faction = "combine",

	danger = jcms.NPC_DANGER_STRONG,
	cost = 1.75,
	swarmWeight = 0.5,
	
	class = "npc_combine_s",
	bounty = 75,

	model = "models/combine_soldier_prisonguard.mdl",
	skin = 1,

	weapons = {
		weapon_jcms_sniper = 1,
	},

	postSpawn = function(npc)
		npc:SetMaxLookDistance(6000)
		npc:SetArrivalDistance(5000)
		npc:SetKeyValue("ignoreunseenenemies", "1")

		npc:SetMaxHealth(math.ceil(npc:GetMaxHealth() * 0.75))
		npc:SetHealth(npc:GetMaxHealth())
		
		npc:GetActiveWeapon():SetSaveValue("m_fMinRange1", 256)
		npc:GetActiveWeapon():SetSaveValue("m_fMaxRange1", 5000)
		npc:SetSaveValue("m_flDistTooFar", 5000)
		
		npc.jcms_maxScaledDmg = 65
	end,

	proficiency = WEAPON_PROFICIENCY_VERY_GOOD
}

jcms.npc_types.combine_elite = {
	portalSpawnWeight = 0.1,
	faction = "combine",
	
	danger = jcms.NPC_DANGER_FODDER,
	cost = 1.4,
	swarmWeight = 0.6,

	class = "npc_combine_s",
	model = "models/combine_super_soldier.mdl",
	bounty = 95,

	weapons = {
		weapon_ar2 = 1,
		weapon_smg1 = 0.001
	},

	postSpawn = function(npc)
		npc:SetKeyValue("NumGrenades", "2")
		jcms.npc_SetupSweeperShields(npc, 30, 5, 1.5, jcms.factions_GetColorInteger("combine"))

		npc:SetSaveValue("m_fIsElite", true)
	end,

	proficiency = WEAPON_PROFICIENCY_PERFECT
}

jcms.npc_types.combine_hunter = {
	portalSpawnWeight = 0.01,
	faction = "combine",
	episodes = true,

	danger = jcms.NPC_DANGER_STRONG,
	cost = 1.8,
	swarmWeight = 0.12,
	swarmLimit = 2,
	
	class = "npc_hunter",
	bounty = 125,

	proficiency = WEAPON_PROFICIENCY_VERY_GOOD,

	hullSize = HULL_MEDIUM_TALL
}

jcms.npc_types.combine_gunship = {
	faction = "combine",
	arenaModeSoftlocker = true,
	
	danger = jcms.NPC_DANGER_BOSS,
	cost = 5.5,
	swarmWeight = 1,
	swarmLimit = 1,
	aerial = true,

	class = "npc_combinegunship",
	bounty = 450,
	portalScale = 5,

	postSpawn = function(npc)
		jcms.npc_Gunship_Setup(npc, 50)
		npc:SetNWString("jcms_boss", "combine_gunship")

		local healthMult = npc:GetMaxHealth() / (100 * 50) --Keep us scaling with default boss HP Scaling
		npc.jcms_gunship_maxHits = math.floor(math.max(2 * healthMult, 2)) --2 Hits
		npc.jcms_gunship_hits = npc.jcms_gunship_maxHits

		if math.random() < 0.001 then --Tiny chance to spawn already dead
			local prop = ents.Create("prop_ragdoll")
			prop:SetModel("models/crashedgunship.mdl")
			prop:SetPos(npc:GetPos())
			prop:Spawn()
			
			npc:Remove()
		end
	end,

	think = function(npc, state) --Strafe w/ deathray occasionally
		npc:SetSaveValue("m_vecDesiredPosition", npc:GetPos())

		if jcms.npc_Gunship_Think_Rally(npc, 96, 1.5, 12, 120, Vector(0.1, 0.5, 1)) then 
			npc:SetSaveValue("m_flMaxSpeed", 700)
		elseif npc.jcms_npcState == jcms.NPC_STATE_GUNSHIPCHARGE then
			npc:SetSaveValue("m_vecDesiredPosition", npc.jcms_gunshipMoveTarget)

			local npcPos = npc:GetPos()
			local distToTarget = npc.jcms_gunshipMoveTarget:DistToSqr(npcPos)
			local strafeTime = CurTime() - npc.jcms_gunshipMoveStart
			if distToTarget > 600^2 and strafeTime < 12.5 then --if we're firing this when we stop, it causes issues.
				npc:Fire("MoveTopSpeed")
			elseif distToTarget < 250^2 or strafeTime > 13.5 then -- if we've reached our objective, return to idle.
				npc:SetSaveValue("m_flMaxSpeed", npc.jcms_gunshipDefaultSpeed )
				npc.jcms_gunshipNextBlast = CurTime() + 35
				npc.jcms_npcState = jcms.NPC_STATE_AIRIDLE
			end
		elseif npc.jcms_npcState == jcms.NPC_STATE_AIRNAVIGATE then
			jcms.npc_airNavigateThink(npc, 200)
		elseif npc.jcms_gunshipNextBlast < CurTime() and IsValid(npc:GetEnemy()) then --Initiate strafe
			local enemy = npc:GetEnemy()

			local npcPos = npc:GetPos()
			local targetPos = enemy:GetPos()

			-- todo: Run a trace and limit our strafe based on that so we don't slam ourselves into walls.

			-- todo: This is probably messy/unrefined. I haven't bothered thinking about how to improve this calculation yet.
			targetPos.z = math.max(npcPos.z, targetPos.z + 800)
			local toTarget = (targetPos - npcPos)
			local dist = toTarget:Length()
			dist = math.Clamp(dist*1.5, 1000, 4000)

			targetPos = npcPos + toTarget:GetNormalized() * dist
			npc.jcms_gunshipMoveTarget = targetPos

			npc:IgnoreEnemyUntil( enemy, CurTime() + 15 )
			npc.jcms_npcState = jcms.NPC_STATE_GUNSHIPRALLY
		else
			jcms.npc_airThink(npc)
		end
	end,

	damageEffect = function(npc, target, dmgInfo)
		if not target:IsPlayer() and not(bit.band(dmgInfo:GetDamageType(), DMG_BULLET) == 0) then --Gunships' bullets seem to have a hardcoded 10x damage buff against anything that isn't a player. 
			dmgInfo:ScaleDamage(0.25)
		end
	end,
	
	takeDamage = function(npc, dmg)
		jcms.npc_Gunship_TakeDamage(npc, dmg)
	end,

	check = function(director)
		return jcms.npc_capCheck("npc_combinegunship", 12) and jcms.npc_airCheck()
	end
}

jcms.npc_types.combine_cybergunship = {
	faction = "combine",
	arenaModeSoftlocker = true,
	
	danger = jcms.NPC_DANGER_RAREBOSS,
	cost = 8,
	swarmWeight = 1,
	swarmLimit = 1,
	aerial = true,

	class = "npc_combinegunship",
	bounty = 700,
	portalScale = 5,

	postSpawn = function(npc)
		jcms.npc_Gunship_Setup(npc, 20)
		npc:SetNWString("jcms_boss", "combine_cybergunship")
		
		local healthMult = npc:GetMaxHealth() / (100 * 50) --Keep us scaling with default boss HP Scaling
		npc.jcms_gunship_maxHits = math.floor(3 * healthMult) -- 3 Hits
		npc.jcms_gunship_hits = npc.jcms_gunship_maxHits

		local scale = Vector(1.25,1.25,1.25)
		for i=1, npc:GetBoneCount(), 1 do  
			npc:ManipulateBoneScale( i-1, scale)
		end

		--Cybergunship AI
		npc.jcms_gunshipLastMoveTarget = npc:GetPos()

		npc.jcms_cybergunship_siren = CreateSound(npc, "ambient/alarms/apc_alarm_loop1.wav")
		npc.jcms_cybergunship_siren:SetSoundLevel(120)
		npc.jcms_cybergunship_siren:SetDSP(38)
		
		npc:CallOnRemove("jcms_cybergunship_remove", function()
			npc.jcms_cybergunship_siren:Stop()
			hook.Call("OnNPCKilled", GAMEMODE, npc, NULL, NULL)
		end)

		npc:SetSubMaterial(1, "models/jcms/cybergunship/body")
	end,

	think = function(npc, state) --Strafe w/ deathray occasionally
		npc:SetSaveValue("m_vecDesiredPosition", npc:GetPos())

		if jcms.npc_Gunship_Think_Rally(npc, 64, 1.5, 16, 120, Vector(0.8, 0.5, 1)) then
			if not npc.jcms_cybergunship_siren:IsPlaying() then 
				npc.jcms_cybergunship_siren:PlayEx(0.75, 145)
			end
		elseif npc.jcms_npcState == jcms.NPC_STATE_GUNSHIPCHARGE then
			local npcPos = npc:GetPos()

			local enemy = npc:GetEnemy()
			if IsValid(enemy) then 
				local targetPos = enemy:GetPos()

				targetPos.z = math.max(npcPos.z, targetPos.z + 800)
				local toTarget = (targetPos - npcPos)
				local dist = math.max(toTarget:Length()*2, 5000)

				targetPos = targetPos + (toTarget:GetNormalized() * dist)

				local fac = 0.15 --Controls how quickly we adjust course
				npc.jcms_gunshipMoveTarget = (targetPos * fac) + (npc.jcms_gunshipLastMoveTarget * (1 - fac))
			end
			npc.jcms_gunshipLastMoveTarget = npc.jcms_gunshipMoveTarget

			npc:SetSaveValue("m_vecDesiredPosition", npc.jcms_gunshipMoveTarget)
			local distToTarget = npcPos:Distance(npc.jcms_gunshipMoveTarget)
			npc:SetSaveValue("m_flMaxSpeed", math.max(400, distToTarget/4 ))

			local strafeTime = CurTime() - npc.jcms_gunshipMoveStart
			if strafeTime < 15 then --if we're firing this when we stop, it causes issues.
				npc:Fire("MoveTopSpeed")
			elseif strafeTime > 16 then -- if we've reached our objective, return to idle.
				npc:SetSaveValue("m_flMaxSpeed", npc.jcms_gunshipDefaultSpeed )
				npc.jcms_gunshipNextBlast = CurTime() + 20
				npc.jcms_npcState = jcms.NPC_STATE_AIRIDLE
				npc.jcms_cybergunship_siren:Stop()
			end
		elseif npc.jcms_npcState == jcms.NPC_STATE_AIRNAVIGATE then
			jcms.npc_airNavigateThink(npc, 200)
		elseif npc.jcms_gunshipNextBlast < CurTime() and IsValid(npc:GetEnemy()) then --Initiate strafe
			npc.jcms_npcState = jcms.NPC_STATE_GUNSHIPRALLY
		else
			jcms.npc_airThink(npc)
		end
	end,

	entityFireBullets = function(npc, bulletData)
		bulletData.TracerName = nil
		bulletData.Tracer = math.huge

		bulletData.Spread = Vector(0.005, 0.005, 0)

		bulletData.Callback = function(attacker, tr, dmgInfo)
			local effectdata = EffectData()
			effectdata:SetStart(LerpVector(7/tr.StartPos:Distance(tr.HitPos), tr.StartPos, tr.HitPos))
			effectdata:SetScale(math.random(6500, 9000))
			effectdata:SetAngles(tr.Normal:Angle())
			effectdata:SetOrigin(tr.HitPos)
			effectdata:SetFlags(4)
			util.Effect("jcms_bolt", effectdata)

			util.BlastDamage(npc, npc, tr.HitPos, 50, 4) --50 rad, 4dmg
		end
	end,

	damageEffect = function(npc, target, dmgInfo)
		if not target:IsPlayer() and not(bit.band(dmgInfo:GetDamageType(), DMG_BULLET) == 0) then --Gunships' bullets seem to have a hardcoded 10x damage buff against anything that isn't a player. 
			dmgInfo:ScaleDamage(0.25)
		end
	end,

	takeDamage = function(npc, dmg)
		jcms.npc_Gunship_TakeDamage(npc, dmg)
	end,

	check = jcms.npc_airCheck
}

jcms.npc_types.combine_breen = {
	faction = "combine",
	noArenaMode = true,
	secretNPC = true,
	
	danger = jcms.NPC_DANGER_FODDER,
	cost = 1, 
	swarmWeight = 0.01,
	swarmLimit = 1,

	class = "npc_breen",
	bounty = 5,
	portalScale = 1,

	postSpawn = function(npc)
		npc:SetMaxHealth(70)
		npc:SetHealth( npc:GetMaxHealth() )
	end,
	
	think = function(npc)
		if IsValid(npc:GetEnemy()) then
			npc:SetSchedule(SCHED_CHASE_ENEMY)
		end
		
		if not npc.lastBreenPhrase or (CurTime() - npc.lastBreenPhrase) > 10 then
			local lines = {
				{ "breencast.br_collaboration%s", 11 },
				{ "breencast.br_overwatch%s", 9, },
				{ "breencast.br_tofreeman%s", 12 },
				{ "breencast.br_welcome%s", 7 },
				{ "breencast.br_disruptor%s", 8 },
				{ "breencast.br_instinct%s", 25 }
			}
			
			local lineData = lines[ math.random(1, #lines) ]
			local txt = lineData[1]
			local num = math.random( lineData[2] )
			if num <= 9 then
				num = "0"..num
			end
			
			npc:EmitSound(string.format(txt, num), 100, 100, 1, CHAN_VOICE)
			npc.lastBreenPhrase = CurTime()
		end
	end
}

jcms.npc_types.gman = {
	faction = "any",
	noArenaMode = true,
	secretNPC = true,
	
	danger = jcms.NPC_DANGER_FODDER,
	cost = 1, 
	swarmWeight = 0.0002,
	swarmLimit = 1,

	class = "npc_gman",
	bounty = 10,
	portalScale = 1,

	check = function(director)
		return (not director.gmanSpawned) 
		and (director.livingPlayers == 1) 
		and (not director.missionData.evacuating) 
		and (jcms.director_GetMissionTime() > 600)
		and math.random() < 0.1
	end,

	postSpawn = function(npc)
		npc:SetMaxHealth(50)
		npc:SetHealth(50)

		npc.phrase_i = 1
		npc.phrases = {
			"vo/citadel/gman_exit01.wav",
			"vo/citadel/gman_exit02.wav",
			"vo/citadel/gman_exit03.wav",
			"vo/citadel/gman_exit04.wav",
			"vo/citadel/gman_exit05.wav",
			"vo/citadel/gman_exit06.wav",
			"vo/citadel/gman_exit07.wav",
			"vo/citadel/gman_exit08.wav",
			"vo/citadel/gman_exit09.wav",
			"vo/citadel/gman_exit10.wav"
		}

		if jcms.director then
			jcms.director.gmanSpawned = true
		end
	end,

	takeDamage = function(npc, dmg)
		if npc.phrase_i > #npc.phrases or (IsValid(dmg:GetAttacker()) and dmg:GetAttacker():IsPlayer() and jcms.team_JCorp_player( dmg:GetAttacker() )) then
			npc:SetHealth(-1)

			local oldPhrase = npc.phrases[npc.phrase_i-1]
			if oldPhrase then
				npc:StopSound(oldPhrase)
				npc:StopSound("music/hl2_intro.mp3")
				game.SetTimeScale(1)
			end
		else
			dmg:ScaleDamage(0)
			npc:SetHealth(50)
		end
	end,
	
	think = function(npc)
		local sweeper = jcms.GetNearestSweeper( npc:GetPos() )
		if sweeper then
			local phrase = npc.phrases[npc.phrase_i]
			local oldPhrase = npc.phrases[npc.phrase_i-1]

			if not npc.playedMusic then
				npc.playedMusic = true
				npc:EmitSound("music/hl2_intro.mp3")
			end

			if not phrase then
				npc:SetHealth(-1)

				local dmg = DamageInfo()
				dmg:SetDamage(5000)
				dmg:SetDamageForce(Vector(0,0,1))
				dmg:SetDamageType(DMG_DIRECT)
				npc:TakeDamageInfo(dmg)

				npc:StopSound("music/hl2_intro.mp3")
				game.SetTimeScale(1)
			else
				if npc.phrase_i == 1 then
					game.SetTimeScale(0.3)
					sweeper:EmitSound(phrase)
					sweeper:ScreenFade(SCREENFADE.OUT, Color(0, 0, 0), 1, 0.5)
				end

				if npc.phrase_i == 5 then
					npc:EmitSound("ambient/explosions/explode_9.wav", 75, 50, 0.7)
				end
				
				if npc.phrase_i >= 2 then
					npc:SetSchedule(SCHED_WAIT_FOR_SCRIPT)
					local fwd = sweeper:EyeAngles():Forward()
					fwd.z = 0
					fwd:Mul(48)
					npc:SetPos( sweeper:GetPos() + fwd )
					npc:DropToFloor()
					npc:SetAngles( (sweeper:GetPos() - npc:GetPos()):Angle() )
					npc:EmitSound(phrase)
				end

				if npc.phrase_i == 2 then
					npc:EmitSound("ambient/energy/whiteflash.wav")
					jcms.DischargeEffect(npc:WorldSpaceCenter() - npc:GetAngles():Forward()*-24, 1, 512, 0.1, 0.2, 5, 8, 3, 4, 0.05, 0.15)
					sweeper:ScreenFade(SCREENFADE.IN, Color(255, 255, 255), 0.5, 0.1)
				end

				npc:SetSequence( math.random(0, npc:GetSequenceCount()-1) )
				npc.phrase_i = npc.phrase_i + 1
			end

			if oldPhrase then
				npc:StopSound(oldPhrase)
			end
		end
	end
}