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

-- // Antlion-Specific Functions {{{
	function jcms.npc_NearThumper(target) --This should be somewhat more performant than FindInSphere in this context - J
		local thumpers = ents.FindByClass("prop_thumper")
		local nPos = target:GetPos()
		for i, v in ipairs(thumpers) do
			if v:GetInternalVariable("m_bEnabled") and v:GetPos():DistToSqr(nPos) < 750^2 then --Radius is actually 1k but they can attack things at the edges.
				return v --Useful for CyberGuards to know which one I guess
			end
		end
		return false
	end

	function jcms.npc_NearAntRepellant(target)
		local repellants = ents.FindByClass("point_antlion_repellant")
		local nPos = target:GetPos()
		for i, v in ipairs(repellants) do
			if v:GetInternalVariable("m_bEnabled") and v:GetPos():DistToSqr(nPos) < 750^2 then --Radius is actually 1k but they can attack things at the edges.
				return true
			end
		end
		return false
	end

	function jcms.DischargeEffect(pos, duration, radius, intervalMin, intervalMax, beamCountMin, beamCountMax, thickMin, thickMax, lifeMin, lifeMax)
		-- // Defaults {{{
			--Pos is required, everything else is optional
			--Duration as nil or negative means it lasts forever.
			radius = radius or 250
			intervalMin = intervalMin or 0.5
			intervalMax = intervalMax or 2.1
			beamCountMin = beamCountMin or 3
			beamCountMax = beamCountMax or 10
			thickMin = thickMin or 3
			thickMax = thickMax or 5
			lifeMin = lifeMin or 0.1
			lifeMax = lifeMax or 0.15
		-- // }}}
		
		local discharge = ents.Create("point_tesla")

		discharge:SetPos(pos)
		discharge:SetKeyValue("texture", "trails/laser.vmt")
		discharge:SetKeyValue("m_Color", "255 255 255")
		discharge:SetKeyValue("m_flRadius", tostring(radius))
		discharge:SetKeyValue("interval_min", tostring(intervalMin))
		discharge:SetKeyValue("interval_max", tostring(intervalMax))
		discharge:SetKeyValue("beamcount_min", tostring(beamCountMin))
		discharge:SetKeyValue("beamcount_max", tostring(beamCountMax))
		discharge:SetKeyValue("thick_min", tostring(thickMin))
		discharge:SetKeyValue("thick_max", tostring(thickMax))
		discharge:SetKeyValue("lifetime_min", tostring(lifeMin))
		discharge:SetKeyValue("lifetime_max", tostring(lifeMax))

		discharge:Spawn()
		discharge:Activate()

		discharge:Fire("DoSpark", "", 0)
		discharge:Fire("TurnOn", "", 0)

		if duration and not(duration < 0) then 
			timer.Simple(duration, function()
				if IsValid(discharge) then
					discharge:Remove()
				end
			end)
		end

		return discharge --So we can still mess with the discharge entity directly if we really need to.
	end

	function jcms.npc_CyberGuard_Think(npc)
		-- // Buffing allies {{{
			local sched = npc:GetCurrentSchedule()
			if (sched==252 or sched==104 or sched==324 or sched==81) and (npc.jcms_cyberguardLastAtk==nil or (CurTime()-npc.jcms_cyberguardLastAtk)>=15) then
				npc:SetSchedule(SCHED_RANGE_ATTACK1)
				
				timer.Simple(1.0, function()
					if IsValid(npc) and npc:GetSequenceName(npc:GetSequence()) == "fireattack" then
						npc.jcms_cyberguardLastAtk = CurTime()
						
						for i, ent in ipairs(ents.FindInSphere(npc:WorldSpaceCenter(), 800)) do
							if jcms.team_GoodTarget(ent) and jcms.team_SameTeam(ent, npc) and npc ~= ent then
								jcms.npc_AddBulletShield(ent, 4)
							end
						end
					end
				end)
			end
		-- // }}}

		-- // Disabling thumpers {{{
			local nearThumper = jcms.npc_NearThumper(npc)
			if nearThumper then
				nearThumper:SetSaveValue("m_bEnabled", false)

				nearThumper:EmitSound("coast.thumper_shutdown")
				npc:EmitSound("d3_citadel.weapon_zapper_charge_node")
				local soundPatch = CreateSound(nearThumper ,"NPC_AttackHelicopter.CrashingAlarm1")
				soundPatch:PlayEx(0.75, 90)

				local ed = EffectData()
				ed:SetStart(npc:WorldSpaceCenter())
				ed:SetOrigin(nearThumper:WorldSpaceCenter())
				util.Effect("jcms_tesla", ed)

				for i=1, 5, 1 do
					jcms.DischargeEffect(nearThumper:GetPos() + Vector(0, 0, 100) + VectorRand(-1, 1):GetNormalized() * 65, 30)
				end

				timer.Simple(30, function()
					if IsValid(soundPatch) then
						soundPatch:Stop()
					end
					
					if IsValid(nearThumper) then
						nearThumper:SetSaveValue("m_bEnabled", true)
					end
				end)
			end
		-- // }}}
	end

	function jcms.npc_SetupAntlionBurrowCheck(npc)
		local npcTbl = npc:GetTable()
		
		npcTbl.jcms_lastBurrowCheck = CurTime()
		local timerName = "jcms_antlion_unburrowThink_" .. tostring(npc:EntIndex())

		local function npc_Antlion_BurrowCheck()			
			if not IsValid(npc) then
				timer.Remove(timerName)
				return
			end

			local cTime = CurTime()
			if npcTbl.jcms_shouldUnburrow and cTime - npcTbl.jcms_lastBurrowCheck > 10 and npc:GetInternalVariable("startburrowed") then 
				npc:Fire("Unburrow")
				npcTbl.jcms_lastBurrowCheck = cTime
			end
		end

		timer.Create(timerName, 10, 6, npc_Antlion_BurrowCheck)
	end

	function jcms.npc_AntlionFodder_Think(npc)
		local enemy = npc:GetEnemy()
		if not IsValid(enemy) or not jcms.npc_NearAntRepellant(enemy) then return end

		npc:SetSaveValue("vLastKnownLocation", enemy:GetPos())
		npc:IgnoreEnemyUntil(enemy, CurTime() + 10)
		npc:SetSchedule(SCHED_TAKE_COVER_FROM_ORIGIN)
	end

	function jcms.npc_AntlionBeamAttack(npc, targetPos, range, fromAngle, toAngle, duration)
		local beam = ents.Create("jcms_beam")
		beam:SetPos(npc:WorldSpaceCenter())
		beam:SetBeamAttacker(npc)
		beam:Spawn()
		beam.Damage = 20
		beam.friendlyFireCutoff = 100 --Don't hurt guards/other high-HP targets. Fodder's fine though.
		beam:SetBeamLength(range)

		npc:EmitSound("ambient/energy/weld"..math.random(1,2)..".wav", 140, 105, 1)

		beam:FireBeamSweep(targetPos, fromAngle, toAngle, duration)
		
		return beam
	end

	--todo: Maybe playbackrate scaling could be used to scale up the threat of fodder lategame?
-- // }}}

-- // Sounds {{{
	sound.Add( { --Literally just SolidMetal.BulletImpact with a higher soundLevel
		name = "jcms_MetalImpact_Loud",
		channel = CHAN_VOICE,
		volume = 1.0,
		level = 90,
		pitch = 100,
		sound = {
			"physics/metal/metal_solid_impact_bullet1.wav",
			"physics/metal/metal_solid_impact_bullet2.wav",
			"physics/metal/metal_solid_impact_bullet3.wav",
			"physics/metal/metal_solid_impact_bullet4.wav",
		}
	} )
-- // }}}

jcms.npc_commanders["antlion"] = {
	placePrefabs = function(c, data)
		--Faction prefabs
		local count = math.ceil(jcms.mapgen_AdjustCountForMapSize( 4 ) * jcms.runprogress_GetDifficulty())
		jcms.mapgen_PlaceFactionPrefabs(count, "antlion")
	end
}

jcms.npc_types.antlion_worker = {
	portalSpawnWeight = 0.25,
	faction = "antlion",
	
	danger = jcms.NPC_DANGER_FODDER,
	suppressSwarmPortalEffect = true,
	cost = 1,
	swarmWeight = 0.3,

	class = "npc_antlion",
	bounty = 50,
	
	episodes = true,

	preSpawn = function(npc)
		if not npc.jcms_fromPortal then
			npc:SetKeyValue("startburrowed", "1")
		end

		if jcms.HasEpisodes() then
			npc:SetKeyValue("spawnflags", bit.bor(npc:GetKeyValues().spawnflags, 262144))
		end
	end,

	postSpawn = function(npc)
		npc:SetSkin( math.random(0, npc:SkinCount() ))

		if not jcms.HasEpisodes() then
			npc:SetMaxHealth(45)
			npc:SetHealth(45)
		end

		jcms.npc_SetupAntlionBurrowCheck(npc)
		npc.jcms_dmgMult = 0.73
	end,

	timerMin = 0.2,
	timerMax = 5.6,
	timedEvent = function(npc)
		if not npc.jcms_fromPortal then
			npc:Fire "Unburrow"
			npc.jcms_shouldUnburrow = true

			timer.Simple(60, function() --fall-back
				if IsValid(npc) and npc:GetInternalVariable("startburrowed") then 
					npc:Remove()
				end
			end)
		end
	end,
	
	think = function(npc, state)
		if npc:GetCurrentSchedule() == SCHED_COMBAT_FACE then
			npc:SetSchedule(SCHED_CHASE_ENEMY)
		end
	end
}

jcms.npc_types.antlion_drone = {
	portalSpawnWeight = 1.0,
	faction = "antlion",
	
	danger = jcms.NPC_DANGER_FODDER,
	cost = 0.4,
	swarmWeight = 1,

	class = "npc_antlion",
	suppressSwarmPortalEffect = true,
	bounty = 18,

	preSpawn = function(npc)
		if not npc.jcms_fromPortal then
			npc:SetKeyValue("startburrowed", "1")
		end
	end,

	think = function(npc)
		jcms.npc_AntlionFodder_Think(npc)
	end,

	postSpawn = function(npc)
		npc:SetSkin( math.random(0, npc:SkinCount() ))
		npc.jcms_dmgMult = 3
		jcms.npc_SetupAntlionBurrowCheck(npc)
	end,

	timerMin = 0.1,
	timerMax = 3.2,
	timedEvent = function(npc)
		if not npc.jcms_fromPortal then
			npc:Fire "Unburrow"
			npc.jcms_shouldUnburrow = true

			timer.Simple(60, function() --fall-back
				if IsValid(npc) and npc:GetInternalVariable("startburrowed") then 
					npc:Remove()
				end
			end)
		end
	end
}

jcms.npc_types.antlion_waster = {
	portalSpawnWeight = 1.33,
	faction = "antlion",

	danger = jcms.NPC_DANGER_FODDER,
	suppressSwarmPortalEffect = true,
	cost = 0.2,
	swarmWeight = 1.2,
	
	class = "npc_antlion",
	bounty = 7,

	preSpawn = function(npc)
		if not npc.jcms_fromPortal then
			npc:SetKeyValue("startburrowed", "1")
		end
	end,

	think = function(npc)
		jcms.npc_AntlionFodder_Think(npc)
	end,

	postSpawn = function(npc)
		npc:SetSkin( math.random(0, npc:SkinCount() ))
		npc:SetModelScale(0.63)
		npc:SetColor( Color(168, 125, 59) )
		npc:SetMaxHealth( npc:Health() / 2 )
		npc:SetHealth( npc:GetMaxHealth() )

		local timerName = "jcms_antlion_fastThink_" .. tostring(npc:EntIndex())
		timer.Create(timerName, 0.05, 0, function() 
			if not IsValid(npc) then 
				timer.Remove(timerName)
				return 
			end

			local sched = npc:GetCurrentSchedule()

			if sched == 126 or sched == 125 or sched == 41 then
				npc:SetPlaybackRate(1.5)
			end
		end)

		npc.jcms_dmgMult = 2
		jcms.npc_SetupAntlionBurrowCheck(npc)
	end,
	
	takeDamage = function(npc, dmg)
		dmg:SetDamageType(DMG_ALWAYSGIB)
	end,

	timerMin = 0.1,
	timerMax = 1.2,
	timedEvent = function(npc)
		if not npc.jcms_fromPortal then
			npc:Fire "Unburrow"
			npc.jcms_shouldUnburrow = true
			
			timer.Simple(60, function() --fall-back
				if IsValid(npc) and npc:GetInternalVariable("startburrowed") then 
					npc:Remove()
				end
			end)
		end
	end,
}

jcms.npc_types.antlion_guard = {
	faction = "antlion",
	
	class = "npc_antlionguard",
	suppressSwarmPortalEffect = true,
	bounty = 350,
	
	danger = jcms.NPC_DANGER_BOSS,
	cost = 6,
	swarmWeight = 1,
	swarmLimit = 3,
	portalScale = 4,

	hullSize = HULL_LARGE,
	
	preSpawn = function(npc)
		if not npc.jcms_fromPortal then
			npc:SetKeyValue("startburrowed", "1")
		end
	end,

	postSpawn = function(npc)
		--todo: Guards seem to like getting stuck in doorways/trying to nav to people they can't reach.
		--It would be better if we detected that and made them hide or patrol instead.
		--Will need to apply to all guards (default, cyber, ultracyber)
		jcms.npc_GetRowdy(npc)
		
		local hp = math.ceil(npc:GetMaxHealth()*0.85)
		npc:SetMaxHealth(hp)
		npc:SetHealth(hp)
		
		npc:SetNWString("jcms_boss", "antlion_guard")
		jcms.npc_SetupAntlionBurrowCheck(npc)

		npc:SetBloodColor(DONT_BLEED)
	end,

	takeDamage = function(npc, dmg)
		timer.Simple(0, function()
			if IsValid(npc) then
				npc:SetNWFloat("HealthFraction", npc:Health() / npc:GetMaxHealth())
			end
		end)
	end,
	
	scaleDamage = function(npc, hitGroup, dmgInfo)
		if bit.band(dmgInfo:GetDamageType(), bit.bor(DMG_BLAST,DMG_BLAST_SURFACE)) ~= 0 then 
			dmgInfo:ScaleDamage(0.75)
			return 
		end

		local inflictor = dmgInfo:GetInflictor() 
		if not IsValid(inflictor) then return end 

		local attkVec = npc:GetPos() - inflictor:GetPos()
		local attkNorm = attkVec:GetNormalized()
		local npcAng = npc:GetAngles():Forward()

		local dot = attkNorm:Dot(-npcAng)
		local angDiff = math.acos(dot)

		local effectdata = EffectData()
		effectdata:SetEntity(npc)
		effectdata:SetOrigin(dmgInfo:GetDamagePosition() - attkNorm)
		effectdata:SetStart(dmgInfo:GetDamagePosition() + attkNorm )
		effectdata:SetSurfaceProp(2)
		effectdata:SetDamageType(dmgInfo:GetDamageType())

		if angDiff < math.pi/4 then --Heavy damage resist from the front, weak from behind.
			npc:EmitSound("jcms_MetalImpact_Loud")

			util.Effect("impact", effectdata)
			effectdata:SetNormal(attkNorm)
			util.Effect("MetalSpark", effectdata)

			dmgInfo:ScaleDamage(0.25) --Slightly more forgiving than 0 damage.
		else
			effectdata:SetColor(1)
			effectdata:SetScale(0.5)
			util.Effect("BloodImpact", effectdata)
		end
	end,

	timerMin = 0.1,
	timerMax = 1.2,
	timedEvent = function(npc) --Not replicated for cyberguards because they're teleported in by mafia.
		if not npc.jcms_fromPortal then
			npc:Fire "Unburrow"
			npc.jcms_shouldUnburrow = true

			timer.Simple(60, function() --fall-back
				if IsValid(npc) and npc:GetInternalVariable("startburrowed") then 
					npc:Remove()
				end
			end)
		end
	end,
	
	check = function(director)
		return jcms.npc_capCheck("npc_antlionguard", 12)
	end
}

jcms.npc_types.antlion_burrowerguard = {
	faction = "antlion",
	
	class = "npc_antlionguard",
	suppressSwarmPortalEffect = true,
	bounty = 275,
	
	danger = jcms.NPC_DANGER_BOSS,
	cost = 5,
	swarmWeight = 1,
	swarmLimit = 3,
	portalScale = 4,

	hullSize = HULL_MEDIUM_TALL,
	
	preSpawn = function(npc)
		if not npc.jcms_fromPortal then
			npc:SetKeyValue("startburrowed", "1")
			npc:SetKeyValue("incavern", "1")
			npc:SetKeyValue("cavernbreed", "1")
		end
	end,

	postSpawn = function(npc)
		--todo: Guards seem to like getting stuck in doorways/trying to nav to people they can't reach.
		--It would be better if we detected that and made them hide or patrol instead.
		--Will need to apply to all guards (default, cyber, ultracyber)
		jcms.npc_GetRowdy(npc)
		
		local hp = math.ceil(npc:GetMaxHealth()*0.8)
		npc:SetMaxHealth(hp)
		npc:SetHealth(hp)
		
		npc:SetNWString("jcms_boss", "antlion_burrowerguard")
		jcms.npc_SetupAntlionBurrowCheck(npc)

		npc:SetModelScale(0.75, 0)
		npc:SetHullType(HULL_MEDIUM_TALL)
	end,

	think = function(npc)
		--If we can't reach an enemy, search for nodes near them that we can fit in and teleport/burrow there.

		local enemy = npc:GetEnemy()
		if IsValid(enemy) and npc:IsUnreachable(enemy) and not npc.jcms_burrowerGuard_isburrowing then
			local nodes = jcms.pathfinder.ain_nodeSplat(enemy:WorldSpaceCenter(), 500, npc:GetHullType(), CAP_MOVE_GROUND)
			table.Shuffle(nodes) 

			for i, node in ipairs(nodes) do
				local nodePos = ainReader.nodePositions[node] + jcms.vectorUp

				local tr = util.TraceEntityHull({
					start = nodePos,
					endpos = nodePos,
					mask = MASK_NPCSOLID
				}, npc)

				if not tr.Hit then --Put us in a free spot
					npc.jcms_burrowerGuard_isburrowing = true

					-- // Burrow Anim {{{
						npc:SetSchedule(SCHED_RANGE_ATTACK1) --Would be better if we had no SFX from this

						timer.Simple(0.4, function()
							if not IsValid(npc) then return end

							npc:EmitSound("npc/antlion/digdown1.wav", 90, 90 + math.Rand(-5, 5))
							
							local ed = EffectData()
							ed:SetOrigin(npc:WorldSpaceCenter())
							ed:SetScale(2.7 - 0.4) --Duration
							ed:SetMagnitude(250) --Depth
							ed:SetEntity(npc)
							util.Effect("jcms_burrow", ed)
						end)
					-- // }}}
					
					-- // Unburrow
						timer.Simple(2.7, function()
							if not IsValid(npc) then return end

							npc:SetPos(nodePos)
							
							npc:SetSaveValue("m_bIsBurrowed", true)
							npc:Fire "Unburrow"

							timer.Simple(3.5, function() 
								npc.jcms_burrowerGuard_isburrowing = false
							end)
						end)
					-- // }}}

					break
				end
			end
		end
	end,

	takeDamage = function(npc, dmg)
		dmg:SetDamageType(bit.bor(dmg:GetDamageType(), DMG_ALWAYSGIB))
		timer.Simple(0, function()
			if IsValid(npc) then
				npc:SetNWFloat("HealthFraction", npc:Health() / npc:GetMaxHealth())

				if npc:Health() <= 0 then --Burst on death (Ragdolling doesn't work right due to our smaller size)
					npc.jcms_burrowerguard_dead = true
					timer.Simple(1.45, function() 	
						if IsValid(npc) then	
							EmitSound( "NPC_Antlion.PoisonBurstExplode", npc:WorldSpaceCenter() )
						end
					end)

					timer.Simple(1.65, function()
						if IsValid(npc) then
							local pos = npc:WorldSpaceCenter()
							
							local ed = EffectData()
							ed:SetOrigin(pos)
							ed:SetRadius(50)
							ed:SetNormal(vector_up)
							ed:SetMagnitude(0.6)
							ed:SetFlags(4)
							util.Effect("jcms_blast", ed)

							npc:Fire("Break")
							ParticleEffect( "antlion_gib_02", pos, angle_zero )

							npc:EmitSound("npc/antlion_grub/squashed.wav", 75, 80)
						end
					end)
				end
			end
		end)
	end,

	--TODO: This needs to be removed and replaced with a custom system for dealing with poison.
	damageEffect = function(npc, target, dmgInfo)
		if npc.jcms_burrowerGuard_suppressDamageEffect then return end

		if not(bit.band(dmgInfo:GetDamageType(), DMG_CLUB) > 0) then
			dmgInfo:ScaleDamage(0)
		else
			dmgInfo:SetDamageType(bit.bor(DMG_CLUB, DMG_POISON))
			dmgInfo:ScaleDamage(3)

			if target:IsPlayer() and target:Armor() == 0 then
				local newDmgInfo = DamageInfo()

				newDmgInfo:SetDamage(10)
				newDmgInfo:SetAttacker(npc)
				newDmgInfo:SetInflictor(npc)
				newDmgInfo:SetDamageType(DMG_CLUB)
				newDmgInfo:SetReportedPosition(dmgInfo:GetReportedPosition())
				newDmgInfo:SetDamagePosition(dmgInfo:GetDamagePosition())
				
				npc.jcms_burrowerGuard_suppressDamageEffect = true
				target:TakeDamageInfo(newDmgInfo)
				npc.jcms_burrowerGuard_suppressDamageEffect = false
			end
		end
	end,

	timerMin = 0.1,
	timerMax = 1.2,
	timedEvent = function(npc) --Not replicated for cyberguards because they're teleported in by mafia.
		if not npc.jcms_fromPortal then
			npc:Fire "Unburrow"
			npc.jcms_shouldUnburrow = true
		end
	end,
	
	check = function(director)
		return jcms.npc_capCheck("npc_antlionguard", 12)
	end
}

jcms.npc_types.antlion_mineralguard = {
	faction = "antlion",
	missionSpecific = "miningoperations",
	noArenaMode = true,
	
	class = "npc_antlionguard",
	suppressSwarmPortalEffect = true,
	bounty = 150,
	
	danger = jcms.NPC_DANGER_BOSS,
	cost = 5,
	swarmWeight = 0.0000000001,
	swarmLimit = 3,
	portalScale = 3.8,

	hullSize = HULL_LARGE,
	
	preSpawn = function(npc)
		if not npc.jcms_fromPortal then
			npc:SetKeyValue("startburrowed", "1")
		end
	end,

	postSpawn = function(npc)
		local hp = math.ceil(npc:GetMaxHealth()*1.25)
		npc:SetMaxHealth(hp)
		npc:SetHealth(hp)

		jcms.npc_GetRowdy(npc)

		if not npc.jcms_oreType then
			local weights = {}
			for name, oreData in pairs(jcms.oreTypes) do
				weights[name] = oreData.weight or 1
			end
			
			npc.jcms_oreType = jcms.util_ChooseByWeight(weights)
		end

		npc:SetMaterial(jcms.oreTypes[npc.jcms_oreType].material)
		npc:SetNWString("jcms_boss", "antlion_guard")
		jcms.npc_SetupAntlionBurrowCheck(npc)
	end,

	takeDamage = function(npc, dmg)
		timer.Simple(0, function()
			if IsValid(npc) then
				npc:SetNWFloat("HealthFraction", npc:Health() / npc:GetMaxHealth())
			end
		end)

		local pos = dmg:GetDamagePosition()
		local attacker = dmg:GetAttacker()
		local damage = dmg:GetDamage()

		local function spawnOre(isStunstick)
			local chunk = ents.Create("jcms_orechunk")
			chunk.jcms_miner = attacker
			chunk:SetPos(pos)
			chunk:SetAngles(AngleRand())
			chunk:SetOreType(npc.jcms_oreType)
			chunk:Spawn()

			local phys = chunk:GetPhysicsObject()
			phys:Wake()
			phys:AddVelocity(VectorRand(-32, 32))
			
			if isStunstick then
				npc:EmitSound("weapons/crowbar/crowbar_impact1.wav", 100, math.Rand(120, 125))
			end

			npc:EmitSound("Breakable.Concrete")

			local ed = EffectData()
			ed:SetOrigin(pos)
			ed:SetColor(npc.jcms_oreColourInt or 0)
			ed:SetRadius( math.Clamp(damage + 5, 10, 120) )

			util.Effect("jcms_oremine", ed)
		end


		local inflictor = dmg:GetInflictor()
		if (not npc.jcms_nextMine or CurTime() >= npc.jcms_nextMine) and IsValid(inflictor) and jcms.util_IsStunstick(inflictor) then
			npc.jcms_nextMine = CurTime() + 0.32

			spawnOre(true)
		end

		timer.Simple(0, function() 
			if not(IsValid(npc) and npc:Health() <= 0) then return end 
			if npc.jcms_mined then return end
			npc.jcms_mined = true

			for i=0, 9 do 
				timer.Simple( i/20 + math.Rand(0, 0.1), function() 
					spawnOre(false)
				end)
			end
		end)
	end,

	timerMin = 0.1,
	timerMax = 1.2,
	timedEvent = function(npc)
		if not npc.jcms_fromPortal then
			npc:Fire "Unburrow"
			npc.jcms_shouldUnburrow = true

			timer.Simple(60, function() --fall-back
				if IsValid(npc) and npc:GetInternalVariable("startburrowed") then 
					npc:Remove()
				end
			end)
		end
	end,
	
	check = function(director)
		return jcms.npc_capCheck("npc_antlionguard", 12)
	end
}

jcms.npc_types.antlion_cyberguard = {
	faction = "antlion",
	
	class = "npc_antlionguard",
	bounty = 300,
	
	danger = jcms.NPC_DANGER_BOSS,
	cost = 5,
	swarmWeight = 0.8,
	swarmLimit = 2,
	portalScale = 3,

	hullSize = HULL_LARGE,

	preSpawn = function(npc)
		npc:SetMaterial("models/jcms/cyberguard")
	end,

	postSpawn = function(npc)
		jcms.npc_GetRowdy(npc)
		
		local hp = math.ceil( npc:GetMaxHealth())
		npc:SetMaxHealth(hp)
		npc:SetHealth(hp)
		
		npc:SetNWString("jcms_boss", "antlion_cyberguard")
	end,

	think = function(npc, state)
		jcms.npc_CyberGuard_Think(npc)
	end,
	
	scaleDamage = function(npc, hitGroup, dmgInfo)
		local inflictor = dmgInfo:GetInflictor()
		if not IsValid(inflictor) then return end 

		local attkVec = npc:GetPos() - inflictor:GetPos()
		attkVec.z = 0
		
		local attkNorm = attkVec:GetNormalized()
		local npcAng = npc:GetAngles():Forward()

		npc:EmitSound("Computer.BulletImpact")

		local effectdata = EffectData()
		effectdata:SetEntity(npc)
		effectdata:SetOrigin(dmgInfo:GetDamagePosition() - attkNorm)
		effectdata:SetStart(dmgInfo:GetDamagePosition() + attkNorm )
		effectdata:SetSurfaceProp(29)
		effectdata:SetDamageType(dmgInfo:GetDamageType())
		
		util.Effect("impact", effectdata)
		
		local dmg = dmgInfo:GetDamage()
		if dmg > 0.3 then
			dmgInfo:SetDamage( math.max(dmg - 4, 0.3) )
		end
		
		timer.Simple(0, function()
			if IsValid(npc) then
				npc:SetNWFloat("HealthFraction", npc:Health() / npc:GetMaxHealth())
			end
		end)
	end,
	
	check = function(director)
		return jcms.npc_capCheck("npc_antlionguard", 12)
	end
}

jcms.npc_types.antlion_ultracyberguard = {
	faction = "antlion",
	
	class = "npc_antlionguard",
	bounty = 600,
	
	danger = jcms.NPC_DANGER_RAREBOSS,
	cost = 10,
	swarmWeight = 1,
	swarmLimit = 1,
	portalScale = 5,

	hullSize = HULL_LARGE,

	postSpawn = function(npc)
		jcms.npc_GetRowdy(npc)
		
		local hp = math.ceil( npc:GetMaxHealth() * 1.5 )
		npc:SetMaxHealth(hp)
		npc:SetHealth(hp)
		npc:SetModel("models/jcms/ultracyberguard.mdl")

		npc.jcms_dmgMult = 0.75
		npc.jcms_uCyberguard_nextBeam = CurTime() + 10
		npc.jcms_uCyberguard_stage2 = false

		npc:SetNWString("jcms_boss", "antlion_ultracyberguard")
	end,

	think = function(npc, state)
		jcms.npc_CyberGuard_Think(npc) --Base think for cyberguard behaviours

		-- // Buffing bosses {{{
			for i, ent in ipairs(ents.FindInSphere(npc:WorldSpaceCenter(), 800)) do
				if not(ent == npc) and ent:GetMaxHealth() > 250 and ent:GetNWInt("jcms_sweeperShield_max", -1) == -1 and jcms.team_GoodTarget(ent) and jcms.team_SameTeam(ent, npc) then
					local ed = EffectData()
					ed:SetStart(npc:WorldSpaceCenter())
					ed:SetOrigin(ent:WorldSpaceCenter())
					util.Effect("jcms_tesla", ed)

					-- todo: Better sound effects
					ent:EmitSound("d3_citadel.weapon_zapper_charge_node")
					
					jcms.npc_SetupSweeperShields(ent, 100, 10, 10, jcms.factions_GetColorInteger("antlion"))
				end
			end
		-- // }}}

		-- // Laser Beams {{{
			local enemy = npc:GetEnemy()
			if IsValid(enemy) and npc.jcms_uCyberguard_nextBeam < CurTime() and enemy:WorldSpaceCenter():DistToSqr(npc:GetPos()) > 150 then 
				local ePos = npc:Visible(enemy) and enemy:EyePos() or npc:GetEnemyLastSeenPos(enemy)

				npc:SetSchedule(SCHED_RANGE_ATTACK2)
				local gestureLayer = npc:AddGesture(ACT_RANGE_ATTACK1)
				npc:SetLayerPlaybackRate(gestureLayer, 0.85)

				local attackType = (math.random() < (enemy:GetVelocity():Length() / 400)) and 1 or 2 --1 = Sweep, 2 = direct
				--Sweeps are more likely if you're moving, direct attacks more likely for stationary/slow
				
				local beamPrep = 0.45
				local beamLife = 3
				local sweepVertically = math.Rand(0, 0.15)
				local sweepDistance = (math.random()<0.5 and 1 or -1)*60 
				local beamDPS = 40
				local beamRadius = 5

				if attackType == 2 then 
					beamPrep = 0.9
					beamLife = 4

					beamDPS = 80
					beamRadius = 20

					sweepVertically = 0 
					sweepDistance = 0
				end
				local beamTotal = beamPrep + beamLife
				
				--npc:SetPlaybackRate(0.85)

				npc.jcms_uCyberguard_nextBeam = CurTime() + 2 --Stop us from re-running logic whil we're mid-prep
				--npc.jcms_cyberguardLastAtk = CurTime() --Stop the shieldbubble logic from interrupting us
				timer.Simple(0.9, function()
					if not IsValid(npc) or not IsValid(enemy) or not(npc:GetCurrentSchedule() == SCHED_RANGE_ATTACK2) then
						npc:RemoveLayer( gestureLayer )
						return 
					end 
					--npc:SetPlaybackRate(0.15)
					npc:SetLayerPlaybackRate(gestureLayer, 0.15)

					local boneId = 4 --Head
					local matrix = npc:GetBoneMatrix(boneId)
					local pos = matrix:GetTranslation()

					local beam = ents.Create("jcms_deathray")
					beam:SetPos(pos)
					beam:SetAngles(npc:GetAngles())
					beam.filter = npc
					beam:Spawn()

					beam:SetBeamColour(Vector(1, 0.6, 0.1))
					beam:SetBeamRadius(beamRadius)
					beam:SetBeamPrepTime(beamPrep)
					beam:SetBeamLifeTime(beamLife)
					beam:SetUseAngles(true)

					beam.DPS = beamDPS
					beam.DPS_DIRECT = beamDPS
					beam.IgniteOnHit = false
					beam.instantDamageImpulse = true

					npc:SetMoveYawLocked( true )

					local startAng, finishAng = jcms.beam_GetBeamAngles(pos, ePos + (enemy:GetVelocity() * (beamPrep + beamLife/3)), sweepVertically, sweepDistance)
					local endTime = CurTime() + beamTotal
					npc:IgnoreEnemyUntil( enemy, endTime )

					--TODO: Recalculate finishAng when the beam actually starts

					local timerName = "jcms_ultracyberguard_beamAim" .. tostring(npc:EntIndex())
					timer.Create(timerName, 0.0, 0, function()
						if not IsValid(npc) or not IsValid(beam) or not(npc:GetCurrentSchedule() == SCHED_RANGE_ATTACK2) then
							timer.Remove(timerName)
							if IsValid(npc) then
								--npc:SetPlaybackRate(1) 
								npc:SetLayerPlaybackRate(gestureLayer, 1)
								npc:SetMoveYawLocked( false )
							end 
							if IsValid(beam) then beam:Remove() end
							return
						end

						local frac = (endTime - CurTime())/beamTotal
						
						local mat = npc:GetBoneMatrix(boneId)
						local pos = mat:GetTranslation()

						beam:SetPos(pos)
						beam:SetAngles(LerpAngle(frac, startAng, finishAng))
					end)
			
					npc.jcms_uCyberguard_nextBeam = CurTime() + (npc.jcms_uCyberguard_stage2 and 8 or 15)
				end)
			end
		-- // }}}
	end,

	takeDamage = function(npc, dmgInfo) 
		if not npc.jcms_uCyberguard_stage2 and npc:Health() - dmgInfo:GetDamage() < npc:GetMaxHealth()/2 then 
			--PLACEHOLDER
			local ed = EffectData()
			ed:SetEntity(npc)
			ed:SetFlags(1)
			ed:SetColor(jcms.factions_GetColorInteger("antlion"))
			util.Effect("jcms_shieldeffect", ed)

			npc:EmitSound("npc/antlion_guard/antlion_guard_shellcrack" .. tostring(math.random(1,2)) .. ".wav")
			npc.jcms_uCyberguard_stage2 = true 
		end
	end,

	scaleDamage = function(npc, hitGroup, dmgInfo)
		local inflictor = dmgInfo:GetInflictor()
		local attkVec = IsValid(inflictor) and (npc:GetPos() - inflictor:GetPos()) or Vector(0, 0, 1)
		attkVec.z = 0
		
		local attkNorm = attkVec:GetNormalized()
		local npcAng = npc:GetAngles():Forward()

		npc:EmitSound("Computer.BulletImpact")

		local effectdata = EffectData()
		effectdata:SetEntity(npc)
		effectdata:SetOrigin(dmgInfo:GetDamagePosition() - attkNorm)
		effectdata:SetStart(dmgInfo:GetDamagePosition() + attkNorm )
		effectdata:SetSurfaceProp(29)
		effectdata:SetDamageType(dmgInfo:GetDamageType())
		
		util.Effect("impact", effectdata)
		
		local dmg = dmgInfo:GetDamage()
		if dmg > 0.3 then
			dmgInfo:SetDamage( math.max(dmg - 4, 0.3) )
		end
		
		timer.Simple(0, function()
			if IsValid(npc) then
				npc:SetNWFloat("HealthFraction", npc:Health() / npc:GetMaxHealth())
			end
		end)
	end
}

jcms.npc_types.antlion_reaper = {
	portalSpawnWeight = 0.1,
	faction = "antlion",
	
	danger = jcms.NPC_DANGER_STRONG,
	cost = 1.75,
	swarmWeight = 0.3,
	portalScale = 1.5,

	class = "npc_jcms_reaper",
	bounty = 75,

	postSpawn = function(npc)
		npc:SetMaxLookDistance(3000)
		
		npc.jcms_maxScaledDmg = 65
	end,

	damageEffect = function(npc, target, dmgInfo)
		--0.75x damage to non-players (mainly turrets), because they can't dodge
		if not target:IsPlayer() then 
			dmgInfo:ScaleDamage(0.75)
		end
	end
}

jcms.npc_types.antlion_grubbomb = {
	faction = "antlion",
	noArenaMode = true,

	danger = jcms.NPC_DANGER_FODDER,
	cost = 0.2,
	swarmWeight = 0.0000001,

	class = "npc_antlion_grub",
	bounty = 15,

	anonymous = true,
	isStatic = true,
	airUnit = true, --Stop us from receiving the in-air bonus

	preSpawn  = function(npc)
		jcms.mapgen_DropEntToNav(npc, npc:GetPos(), 800) --TODO: Maybe comment this out, I think this is only needed for debugspawn
	end,
	
	postSpawn = function(npc)
		--Technically unnecessary because anonymous already means we don't have director logic applied to us.
		npc.jcms_ignoreStraggling = true
	end,
	
	takeDamage = function(npc, dmg)
		timer.Simple(0, function()
			if IsValid(npc) and npc:Health() <= 0 then
				local pos = npc:WorldSpaceCenter()

				ParticleEffect( "antlion_gib_02", pos, angle_zero )
				
				EmitSound( "NPC_Antlion.PoisonBurstExplode", pos );
				
				local blstDmg = DamageInfo()

				blstDmg:SetAttacker(npc)
				blstDmg:SetInflictor(npc)
				
				blstDmg:SetDamage(50)
				blstDmg:SetReportedPosition(pos)
				blstDmg:SetDamageForce(jcms.vectorOrigin)
				blstDmg:SetDamageType( bit.bor(DMG_POISON, DMG_BLAST_SURFACE, DMG_ACID) )

				util.BlastDamageInfo(blstDmg, pos, 100)
			end
		end)
	end,

	check = function() return false end --Stop us from spawning naturally
}