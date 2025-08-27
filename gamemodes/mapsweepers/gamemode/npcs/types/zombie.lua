--[[
	Map Sweepers - Co-op NPC Shooter Gamemode for Garry's Mod by "Octantis Addons" (consisting of MerekiDor & JonahSoldier)
    Copyright (C) 2025  MerekiDor

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

-- // Zombie-Specific Functions {{{
	function jcms.npc_SlowZombieThink(npc) --Slow zombies get "sped up" when ridiculously far and out of sight.
		--Game was never really designed for this many players, zombie missions in particular end up feeling very empty with 16 people. This should help.
		local swpCountReduce = math.max(#team.GetPlayers(1) - 8, 0) * 150

		if npc:GetPathDistanceToGoal() > math.max(2250 - swpCountReduce, 250) then
			local npcPos = npc:WorldSpaceCenter()
			local npcNextPos = npc:GetCurWaypointPos()

			if #jcms.GetSweepersInRange(npcNextPos, 750) > 0 then return end

			local tr = util.TraceEntityHull({
				start = npcNextPos,
				endpos = npcNextPos
			}, npc)
			if tr.Hit then return end --Don't teleport us into the goddamn wall.

			local isVisible = false
			local shouldTP = true
			local isFar = true
			for i, ply in ipairs(jcms.GetAliveSweepers()) do
				local startVisible = ply:VisibleVec( npcPos )
				local endVisible = ply:VisibleVec( npcNextPos )

				local swpEyePos = ply:EyePos()
				local maxDist = (4000 - swpCountReduce)^2
				local far = npcNextPos:DistToSqr(swpEyePos) > maxDist and npcPos:DistToSqr(swpEyePos) > maxDist --are we and our dest super far

				local visibleForThisSwp = startVisible or endVisible --are we or our destination visible

				isFar = isFar and ( not visibleForThisSwp or far ) --set far to false if we're close and can be seen
				shouldTP = shouldTP and (not visibleForThisSwp or far) --only block us if we're close and can be seen
				isVisible = isVisible or visibleForThisSwp
			end

			if shouldTP then
				if isFar and isVisible then --Visual justification for far-away teleports.
					local ed = EffectData()
					ed:SetFlags(1)
					ed:SetEntity(npc)
					ed:SetOrigin(npcNextPos)
					util.Effect("jcms_chargebeam", ed)
				end
				npc:SetPos(npcNextPos + Vector(0,0,15))
				npc:AdvancePath()
			end
		end
	end

	function jcms.npc_MiniTank_Launch(npc, target)
		if not IsValid(npc) then return end
		if not IsValid(target) then return end

		local npcPos = npc:WorldSpaceCenter()
		local targPos = target:WorldSpaceCenter()

		local dir = npcPos - targPos
		dir:Normalize()
		dir:Add(Vector(0,0,1.5))
		dir:Mul(100)

		local moveType = target:GetMoveType()
		if moveType == MOVETYPE_VPHYSICS then
			target:GetPhysicsObject():ApplyForceCenter(Vector(0,0,100000))
			dir:Mul(target:GetPhysicsObject():GetMass())
			dir:Mul(15)
			target:GetPhysicsObject():ApplyForceCenter(-dir)
		elseif moveType == MOVETYPE_WALK or moveType == MOVETYPE_STEP then
			if target:OnGround() then
				target:SetVelocity(Vector(0,0,300))
			end

			if moveType == MOVETYPE_WALK then 
				dir:Mul(0.035)
			else --We love the source engine because it always makes sense.
				dir:Mul(-2.5)
				dir.z = -dir.z * 0.75
			end
			timer.Simple(0.1, function()
				if IsValid(target) then
					target:SetVelocity(dir)
				end
			end)
		end
	end
-- // }}}

jcms.npc_commanders["zombie"] = {
	start = function(c)
		c.nextRowdy = CurTime() + 10
	end,

	think = function(c)
		local mTime = jcms.director_GetMissionTime()
		if mTime < 7.5 then return end

		local d = jcms.director
		if d and #d.npcs < 40 then
			d.swarmNext = (d.swarmNext or mTime) - 1 -- Speeding up hordes
		end

		local cTime = CurTime()
		if c.nextRowdy < cTime then --Zombies (almost) always know where you are.
			for i, npc in ipairs(d.npcs) do 
				if npc.jcms_faction == "zombie" and npc.GetEnemy and not IsValid(npc:GetEnemy()) then
					jcms.npc_GetRowdy(npc)
				end
			end
			c.nextRowdy = cTime + 10
		end
	end,

	flashpointSummon = function(c, flashPoint, boss)
		util.ScreenShake( flashPoint:WorldSpaceCenter(), 25, 20, 6, 25000, true)

		local filter = RecipientFilter()
		filter:AddAllPlayers()
		flashPoint:EmitSound("ambient/creatures/town_zombie_call1.wav", 140, 100, 1, CHAN_STATIC, 0, 0, filter)

		local d = jcms.director
		d.swarmNext = 0

		local upgrades = {
			["npc_zombie"] = {
				["zombie_boomer"] = 0.5,
				["zombie_poison"] = 0.4,
				["zombie_minitank"] = 0.05,
				["buff"] = 0.5
			},
			["npc_fastzombie"] = {
				["zombie_charple"] = 0.25,
				["buff"] = 1
			},
			["npc_zombine"] = {
				["buff"] = 1
			},
			["npc_poisonzombie"] = {
				["zombie_minitank"] = 1,
				["buff"] = 0.25
			}
		}

		if jcms.HasEpisodes() then
			upgrades.npc_zombie["zombie_combine"] = 1
			upgrades.npc_fastzombie["zombie_combine"] = 0.5
		end

		timer.Simple(2, function()
			local npcs = ents.FindByClass("npc_*")
			local sweepers = jcms.GetAliveSweepers()
			for i, npc in ipairs(npcs) do
				local npcClass = npc:GetClass()
				if not upgrades[npcClass] then continue end

				local upgrade = jcms.util_ChooseByWeight(upgrades[npcClass])
				if upgrade == "buff" then --Make us faster and give us a shield
					if npc:GetNWInt("jcms_sweeperShield_max", -1) == -1 then
						jcms.npc_SetupSweeperShields(npc, 25, 7, 3, Color(255,255,255))
					end

					local ed = EffectData()
					ed:SetEntity(npc)
					ed:SetMagnitude(0.1 * 512) --Interval / 512
					ed:SetScale(0) --duration
					util.Effect("jcms_teslahitboxes_dur", ed)

					local timerName = "jcms_zombie_fastThink_" .. tostring(npc:EntIndex())
					if not timer.Exists( timerName ) then 
						timer.Create(timerName, 0.05, 0, function()
							if not IsValid(npc) then
								timer.Remove(timerName)
								return
							end

							npc:SetPlaybackRate(1.5)
						end)
					end
				else --replace with better vers
					npc:Remove()
					--We replace the old npc ref with the new one for the effect.
					npc = jcms.npc_Spawn(upgrade, npc:GetPos())
				end

				local ed = EffectData()
				ed:SetFlags(1)
				ed:SetEntity(npc)
				ed:SetOrigin(npc:GetPos())
				util.Effect("jcms_chargebeam", ed)
			end
		end)

		timer.Simple(2.1, function()
			npcs = ents.FindByClass("npc_*")
			for i, npc in ipairs(npcs) do
				if npc.GetEnemy then
					local enemy = npc:GetEnemy()
					if not IsValid(enemy) then
						jcms.npc_GetRowdy(npc)
					end

					enemy = npc:GetEnemy()
					if IsValid(enemy) then
						npc:NavSetGoalPos(enemy:GetPos())
					end
				end

				timer.Simple(math.Rand(0, 0.25), function()
					if not IsValid(npc) then return end

					for i=1, 3, 1 do --Advance 3 times
						if (npc.IsCurWaypointGoal and not npc:IsCurWaypointGoal()) and npc:GetPathDistanceToGoal() > 1000 then
							local npcPos = npc:WorldSpaceCenter()
							local npcNextPos = npc:GetCurWaypointPos()

							--Collision detection to stop us from teleporting into other zombies.
							local tr = util.TraceEntityHull({
								start = npcNextPos,
								endpos = npcNextPos,
								mask = MASK_NPCSOLID
							}, npc)
							if not IsValid(tr.Entity) then
								local ed = EffectData()
								ed:SetFlags(2)
								ed:SetEntity(npc)
								ed:SetOrigin(npcNextPos)
								util.Effect("jcms_chargebeam", ed)

								npc:SetPos(npcNextPos + Vector(0,0,15))
								npc:AdvancePath()
							end
						end
					end
				end)
			end

			d.swarmNext = 0
		end)
	end, 

	placePrefabs = function(c, data)
		--Place extra respawn chambers		
		local function weightOverride(name, ogWeight)
			return ((name == "respawn_chamber") and 1) or 0
		end

		jcms.mapgen_PlaceNaturals(jcms.mapgen_AdjustCountForMapSize( 2 + math.ceil(1.5 * #jcms.GetLobbySweepers())), weightOverride)
	end
}

jcms.npc_types.zombie_explodingcrab = {
	faction = "zombie",

	danger = jcms.NPC_DANGER_FODDER,
    cost = 0.025,
    swarmWeight = 0.0000001,

	class = "npc_headcrab_fast",
	bounty = 2,
	
	anonymous = true,

	portalScale = 0.5,
	postSpawn = function(npc)
		npc.jcms_dmgMult = 15
		npc.jcms_maxScaledDmg = 65
		npc:SetMaterial("models/jcms/explosiveheadcrab/body")

		local scale = Vector(1.5,1.5,1.5)
		for i=1, npc:GetBoneCount(), 1 do
			npc:ManipulateBoneScale( i-1, scale)
		end

		npc:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS)

		npc.jcms_explodingCrab_despawnTimer = 0

		local timerName = "jcms_" .. tostring(npc) .. "_think" --Anonymous npcs don't get their think called by director, this is a workaround
		timer.Create(timerName, 2.5, 0, function()
			if not IsValid(npc) then 
				timer.Remove(timerName)
				return
			end

			local npcPos = npc:GetPos()
			local nearest = jcms.GetNearestSweeper(npcPos)
			if not IsValid(nearest) then return end
	
			if nearest:GetPos():DistToSqr(npcPos) > 2500^2 then
				npc.jcms_explodingCrab_despawnTimer = npc.jcms_explodingCrab_despawnTimer + 1
			end
	
			if npc.jcms_explodingCrab_despawnTimer > 25 then --If we've been >2500 units from a player for more than 25s, explode
				npc:EmitSound("NPC_Vortigaunt.Shoot")
				util.ParticleTracerEx("vortigaunt_beam", npc:WorldSpaceCenter(), npc:WorldSpaceCenter(), false, -1, -1)
				npc:Remove()
			end
		end)
	end,

	damageEffect = function(npc, target, dmgInfo)
		local ed = EffectData()
		ed:SetMagnitude(1.8)
		ed:SetOrigin(npc:GetPos())
		ed:SetRadius(64)
		ed:SetFlags(5)
		ed:SetColor( jcms.util_ColorIntegerFast(128, 255, 64) )
		util.Effect("jcms_blast", ed)
		npc:Remove()
	end,

	takeDamage = function(npc, dmg)
		local attacker = dmg:GetAttacker()
		local inflictor = dmg:GetInflictor()
		if not npc:IsOnGround() and jcms.team_JCorp(attacker) and jcms.util_IsStunstick(inflictor) then
			dmg:ScaleDamage(10)
			local fromPos = npc:WorldSpaceCenter()

			local newDmg = DamageInfo()
			newDmg:SetDamage(22)
			newDmg:SetDamageType( bit.bor(DMG_CRUSH, DMG_DISSOLVE) )
			newDmg:SetReportedPosition(fromPos)
			newDmg:SetAttacker(attacker)
			newDmg:SetInflictor(npc)
			newDmg:SetDamageForce( Vector(0, 0, 128) )

			local ed = EffectData()
			ed:SetMagnitude(0.9)
			ed:SetOrigin(fromPos)
			ed:SetRadius(84)
			ed:SetFlags(5)
			ed:SetColor( jcms.util_ColorIntegerFast(128, 200, 64) )
			util.Effect("jcms_blast", ed)

			npc:EmitSound("NPC_Vortigaunt.Shoot")
			for i, tg in ipairs( ents.FindInCone(fromPos, attacker:EyeAngles():Forward(), 512, 0.1 ) ) do
				if jcms.team_GoodTarget(tg) and jcms.team_NPC(tg) then
					local pos = tg:WorldSpaceCenter()
					newDmg:SetDamagePosition(pos)
					tg:TakeDamageInfo(newDmg)

					util.ParticleTracerEx("vortigaunt_beam", fromPos, pos, false, -1, -1)
				end
			end
		end
	end
}

jcms.npc_types.zombie_polyp = {
	faction = "zombie",

	danger = jcms.NPC_DANGER_STRONG,
    cost = 0.45,
    swarmWeight = 0.3,
	swarmLimit = 1,

	class = "npc_jcms_zombiepolyp",
	bounty = 50,

	portalScale = 0.5,

	anonymous = true, --Don't contribute to the softcap / director.
	isStatic = true, 

	postSpawn = function(npc)
		npc.jcms_ignoreStraggling = true

		if not jcms.director then return end

		local npcPos = npc:GetPos()
		local ply, closestDist = jcms.GetNearestSweeper(npcPos)

		if closestDist < npc:GetCloudRange() then
			local plyArea = jcms.director.playerAreas[ply]
			local zone
			if plyArea then
				local zID = jcms.mapgen_ZoneDict()[plyArea]
				zone = jcms.mapgen_ZoneList()[zID]
			end
			if not zone then
				local zList = jcms.mapgen_ZoneList()
				zone = zList[math.random(#zList)]
			end

			local positions = {}
			for i, v in ipairs(jcms.GetAliveSweepers()) do
				table.insert(positions, v:GetPos())
			end

			local validZones = jcms.director_GetAreasAwayFrom(zone, positions, npc:GetCloudRange(), math.huge)
			table.Shuffle(validZones)

			if #validZones == 0 then
				return
			end

			for i, area in ipairs(validZones) do
				local centre = area:GetCenter()
					
				--Ensure we aren't teleporting into another npc.
				local upV = Vector(0,0,15)
				local tr = util.TraceEntityHull({
					start = centre + upV,
					endpos = centre + upV
				}, npc)

				if not tr.Hit then --Free-space found
					npc:SetPos(centre)
					break
				end
			end
		end

		local centre = npc:WorldSpaceCenter()
		local upTr = util.TraceLine({
			start = centre,
			endpos = centre + Vector(0,0,32768),
			mask = MASK_NPCSOLID_BRUSHONLY
		})

		if not upTr.HitSky then 
			npc:SetCloudRange(npc:GetCloudRange() * 0.60)
		end
	end,

	check = function(director)
		--These can technically spawn infinitely, and have a performance impact, so we need to cap them.
		return jcms.npc_capCheck("npc_jcms_zombiepolyp", 12)
	end
}

jcms.npc_types.zombie_husk = {
	portalSpawnWeight = 2,
	faction = "zombie",

	danger = jcms.NPC_DANGER_FODDER,
    cost = 0.15,
    swarmWeight = 1,

	class = "npc_zombie",
	bounty = 13,

	postSpawn = function(npc)
		local hp = math.ceil(npc:GetMaxHealth()*1.5)
		npc:SetMaxHealth(hp)
		npc:SetHealth(hp)

		npc.jcms_dmgMult = 4

		-- 9-12 torso
		--45 - 47 head/crab(?)

		local totalRand = 45
		for i=9, 12 do
			local rand = math.Rand(0, totalRand)
			totalRand = math.max(totalRand - rand, 0)
			npc:ManipulateBoneAngles(i, AngleRand(-rand, rand), true)
		end
	end,

	think = jcms.npc_SlowZombieThink
}

jcms.npc_types.zombie_fast = {
	portalSpawnWeight = 1,
	faction = "zombie",

	danger = jcms.NPC_DANGER_FODDER,
    cost = 0.35,
    swarmWeight = 0.6,

	class = "npc_fastzombie",
	bounty = 28,

	postSpawn = function(npc)
		local hp = math.ceil(npc:GetMaxHealth()*1.25)
		npc:SetMaxHealth(hp)
		npc:SetHealth(hp)

		npc.jcms_dmgMult = 4
	end
}

jcms.npc_types.zombie_poison = {
	portalSpawnWeight = 0.8,
	portalScale = 1.1,
	faction = "zombie",

	danger = jcms.NPC_DANGER_STRONG,
    cost = 0.45,
    swarmWeight = 0.45,

	class = "npc_poisonzombie",
	bounty = 35,

	postSpawn = function(npc)
		local hp = math.ceil(npc:GetMaxHealth()*1.5)
		npc:SetMaxHealth(hp)
		npc:SetHealth(hp)

		npc.jcms_dmgMult = 5
	end,

	think = jcms.npc_SlowZombieThink
}

jcms.npc_types.zombie_minitank = {
	--This enemy kinda sucks. They are like *vaguely* interesting enough to be used as a niche thing, though.
	--They are used as extra enemies to improve flashpoint-swarms, and as a fall-back """Boss""" for when there are too many spawners.
	portalScale = 1.1,
	faction = "zombie",

	danger = jcms.NPC_DANGER_BOSS, --Originally STRONG, but I'm using this as a fallback for if there's too many spawners now.
    cost = 0.35,
    swarmWeight = 0.0000000001, --0.3,

	class = "npc_poisonzombie",
	bounty = 45,

	preSpawn = function(npc)
		npc:SetSaveValue("m_nCrabCount", 0)
	end,

	postSpawn = function(npc)
		npc.jcms_ignoreStraggling = true

		local hp = math.ceil(npc:GetMaxHealth()*2.75)
		npc:SetMaxHealth(hp)
		npc:SetHealth(hp)

		npc.jcms_dmgMult = 10
		npc.jcms_maxScaledDmg = 90

		npc:SetSaveValue("m_nCrabCount", 0)
		npc:SetBloodColor(DONT_BLEED)
		npc:CapabilitiesAdd(CAP_SKIP_NAV_GROUND_CHECK) --NOTE: Unsure if this does what I think it does. I was looking for something
		--that'd stop them from trying to navigate around friendlies and just navigate *through* them instead. This *seems* to do that.

		local chestScale = Vector(1.25, 1.25, 1.25)
		for i=1, 5, 1 do
			npc:ManipulateBoneScale( i-1, chestScale)
		end

		local scale = Vector(1.75,1.75,1.75)
		for i=5, 32, 1 do
			npc:ManipulateBoneScale( i-1, scale)
		end

		npc:ManipulateBoneScale(4, jcms.vectorOne / 1.25)

		for i=2, 6, 1 do
			npc:SetBodygroup( i, 0 )
		end

		npc:SetModelScale(1.25, 0)

		local timerName = "jcms_zombie_fastThink_" .. tostring(npc:EntIndex())
		timer.Create(timerName, 0.05, 0, function()
			if not IsValid(npc) then
				timer.Remove(timerName)
				return
			end

			if npc:GetCurrentSchedule() == 103 then
				npc:SetPlaybackRate(1.25)
			else
				npc:SetPlaybackRate(0.9)
			end
		end)
		
		npc.lastPhraseTime = CurTime()
		
		npc:SetNWString("jcms_boss", "zombie_minitank")
	end,

	scaleDamage = function(npc, hitGroup, dmgInfo)
		local inflictor = dmgInfo:GetInflictor()
		if not IsValid(inflictor) then return end

		local attkVec = npc:GetPos() - inflictor:GetPos()
		attkVec.z = 0
		local attkNorm = attkVec:GetNormalized()
		local npcAng = npc:GetAngles():Forward()

		if hitGroup == 1 then  --Ignore headshots
			local effectdata = EffectData()
			effectdata:SetEntity(npc)
			effectdata:SetOrigin(dmgInfo:GetDamagePosition() - attkNorm)
			effectdata:SetStart(dmgInfo:GetDamagePosition() + attkNorm )

			effectdata:SetFlags(3)
			effectdata:SetColor(0)
			effectdata:SetScale(6)

			util.Effect("bloodspray", effectdata)
			if npc.lastPhraseTime + 0.5 < CurTime() then
				npc:EmitSound("NPC_PoisonZombie.Pain") --todo: use the original sounds instead so we can pitch shift.
				npc.lastPhraseTime = CurTime()
			end
			return
		end

		local dot = attkNorm:Dot(-npcAng)
		local angDiff = math.acos(dot)

		if angDiff < math.pi/2 then --Heavy damage resist from the front, weak from behind.
			npc:EmitSound("Dirt.BulletImpact")

			local effectdata = EffectData()
			effectdata:SetEntity(npc)
			effectdata:SetOrigin(dmgInfo:GetDamagePosition() - attkNorm)
			effectdata:SetStart(dmgInfo:GetDamagePosition() + attkNorm )
			effectdata:SetSurfaceProp(12)
			effectdata:SetDamageType(dmgInfo:GetDamageType())
			util.Effect("Impact", effectdata)

			dmgInfo:ScaleDamage(0.25) --Heavy resistance.
		end

		timer.Simple(0, function()
			if IsValid(npc) then
				npc:SetNWFloat("HealthFraction", npc:Health() / npc:GetMaxHealth())
			end
		end)
	end,

	damageEffect = function(npc, target, dmgInfo)
		jcms.npc_MiniTank_Launch(npc, target)
	end,

	takeDamage = function(npc, dmg)
		npc:SetNWFloat("HealthFraction", npc:Health() / npc:GetMaxHealth())
	end,

	--throw anim, releascrab, run, and firewalk sequences could be interesting

	think = function(npc)
		local npcPos = npc:WorldSpaceCenter()
		local fwd = npc:GetAngles():Forward()

		local tr = util.TraceHull({
			start = npcPos,
			endpos = npcPos + fwd*100,
			mins = -Vector(10,10,10),
			maxs = Vector(10,10,10),
			filter = npc --don't hit ourselves.
		})

		if IsValid(tr.Entity) and tr.Entity:IsNPC() then 
			npc:SetSchedule(SCHED_MELEE_ATTACK1)
			
			--todo: we could get npcs stuck doing this, so we probably either want rebel-jumppad style logic, or to attach a timer to them.
			timer.Simple(0.5, function()
				if not IsValid(tr.Entity) then return end
				tr.Entity:EmitSound("NPC_BaseZombie.PoundDoor")
				jcms.npc_MiniTank_Launch(npc, tr.Entity)
			end)
		end

		jcms.npc_SlowZombieThink(npc)
	end 
}

jcms.npc_types.zombie_boomer = {
	portalSpawnWeight = 0,
	faction = "zombie",

	danger = jcms.NPC_DANGER_STRONG,
    cost = 0.65,
    swarmWeight = 0.5,

	class = "npc_jcms_boomer",
	bounty = 25,

	portalScale = 1.1,

	think = jcms.npc_SlowZombieThink
}

jcms.npc_types.zombie_combine = {
	portalSpawnWeight = 0.6,
	faction = "zombie",
	episodes = true,

	danger = jcms.NPC_DANGER_STRONG,
    cost = 0.6,
    swarmWeight = 0.5,

	class = "npc_zombine",
	bounty = 40,

	postSpawn = function(npc)
		local hp = math.ceil(npc:GetMaxHealth()*1.75)
		npc:SetMaxHealth(hp)
		npc:SetHealth(hp)
	end,

	think = function(npc)
		jcms.npc_SlowZombieThink(npc)

		if #jcms.GetSweepersInRange(npc:GetPos(), 600) > 0 then return end
		npc:Fire("StartSprint") --Force us to run until we're closer.
	end,
	
	damageEffect = function(npc, target, dmgInfo)
		if dmgInfo:IsDamageType( DMG_BLAST, DMG_BLAST_SURFACE ) then 
			return --Don't buff grenade damage
		end

		dmgInfo:ScaleDamage(5)
	end,

	scaleDamage = function(npc, hitGroup, dmgInfo)
		if hitGroup == 1 or hitGroup == 0 then return end --Ignore headshots
		local inflictor = dmgInfo:GetInflictor() 
		if not IsValid(inflictor) then return end 

		local attkVec = npc:GetPos() - inflictor:GetPos()
		attkVec.z = 0
		local attkNorm = attkVec:GetNormalized()
		local npcAng = npc:GetAngles():Forward()

		local dot = attkNorm:Dot(-npcAng)
		local angDiff = math.acos(dot)

		if angDiff < math.pi/2 then --Heavy damage resist from the front, weak from behind.
			npc:EmitSound("SolidMetal.BulletImpact", 100, 100, 1)

			local effectdata = EffectData()
			effectdata:SetEntity(npc)
			effectdata:SetOrigin(dmgInfo:GetDamagePosition() - attkNorm)
			effectdata:SetStart(dmgInfo:GetDamagePosition() + attkNorm )
			effectdata:SetSurfaceProp(2)
			effectdata:SetDamageType(dmgInfo:GetDamageType())

			util.Effect("impact", effectdata)

			dmgInfo:ScaleDamage(0.075) --Slightly more forgiving than 0 damage.
		end
	end
}

jcms.npc_types.zombie_spirit = {
	portalSpawnWeight = 0,
	faction = "zombie",

	danger = jcms.NPC_DANGER_STRONG,
	cost = 1,
	swarmWeight = 0.35,

	class = "npc_jcms_spirit",
	bounty = 60,

	check = function(director)
		--Reliant on other npcs to be useful, and can end up stalling them more than helping them if too many are present.
		return jcms.npc_capCheck("npc_jcms_spirit", 4)
	end
}

jcms.npc_types.zombie_spawner = {
	faction = "zombie",

	danger = jcms.NPC_DANGER_BOSS,
	cost = 1.25,
	swarmWeight = 1,

	class = "npc_jcms_zombiespawner",
	bounty = 250,

	postSpawn = function(npc)
		-- // If our space is clear return early {{{
			local npcPos = npc:GetPos()
			--local upV1 = Vector(0,0,120)
			local upV2 = Vector(0,0,25)
			local tr = util.TraceEntityHull({
				start = npcPos + upV2,
				endpos = npcPos + upV2
			}, npc)

			if not tr.Hit then return end
		-- // }}}

		-- Teleport to somewhere away from sweepers.
		local positions = {}
		for i, v in ipairs(jcms.GetAliveSweepers()) do
			table.insert(positions, v:GetPos())
		end

		local validZones = jcms.director_GetAreasAwayFrom(jcms.mapgen_ZoneList()[jcms.mapdata.largestZone], positions, 1000, math.huge)
		if #validZones == 0 then return end
		table.Shuffle(validZones)

		for i, area in ipairs(validZones) do
			if area:GetSizeX() > 128 and area:GetSizeY() > 128 then
				npc:SetPos(area:GetCenter())
				break
			end
		end
	end,

	check = function(director)
		--At a certain point these reduce difficulty by muscling-out every other enemy type. We have minitanks as a fallback.
		return jcms.npc_capCheck("npc_jcms_zombiespawner", 4)
	end
}

jcms.npc_types.zombie_charple = {
	faction = "zombie",

	danger = jcms.NPC_DANGER_FODDER,
    cost = 0.2,
    swarmWeight = 0.0000001,

	class = "npc_fastzombie",
	bounty = 20,

	postSpawn = function(npc)
		npc:SetBodygroup( 1, 0 ) --Remove our headcrab
		npc:SetMaterial("models/charple/charple3_sheet")

		local hp = math.ceil(npc:GetMaxHealth()*0.5)
		npc:SetMaxHealth(hp)
		npc:SetHealth(hp)

		npc.jcms_dmgMult = 15

		npc:Fire("GagEnable")
		npc.jcms_charpleGurgle = CreateSound(npc, "npc/zombie_poison/pz_breathe_loop2.wav")
		npc.jcms_charpleGurgle:PlayEx(0.5, 150)
		npc.jcms_charpleGurgle:SetSoundLevel( 90 )

		npc.lastPhraseTime = CurTime()

		npc:CallOnRemove( "jcms_charple_stopsound", function()
			npc.jcms_charpleGurgle:Stop()
		end)

		npc.jcms_maxScaledDmg = 65

		npc.jcms_charpleDeathTime = CurTime() + 50
	end,

	think = function(npc)
		if npc:Health() <= 0 then return end

		-- // Accelerate our breathing the closer we are to a player. {{{ 
			local npcPos = npc:GetPos()
			local dist = math.huge
			for i, ply in ipairs(jcms.GetAliveSweepers()) do
				local newDist = ply:GetPos():Distance(npcPos)
				dist = ((newDist < dist) and newDist) or dist
			end

			local soundPlaying = npc.jcms_charpleGurgle:IsPlaying()
			if dist > 3000 and soundPlaying then
				npc.jcms_charpleGurgle:Stop()
			elseif not soundPlaying then
				npc.jcms_charpleGurgle:Play()
			end

			local soundPitch = Lerp((dist -50)/600, 200, 140)
			npc.jcms_charpleGurgle:ChangePitch(soundPitch, 0.1)
		-- // }}}

		-- // Bandaid for charples frequently getting stuck {{{
			--If a charple's alive for >50s, and isn't visible, we kill it.
			--This should most-often mean they're stuck in a corner somewhere. It'll get a couple normal ones, but that's a worthwhile sacrifice.

			if npc.jcms_charpleDeathTime < CurTime() then 
				local isVisible = false
				for i, ply in ipairs(jcms.GetAliveSweepers()) do 
					isVisible = isVisible or ply:Visible(npc)
				end

				if isVisible then
					npc.jcms_charpleDeathTime = CurTime() + 20 
				else
					npc:TakeDamage(npc:GetMaxHealth())
				end
			end
		-- // }}}
	end,

	takeDamage = function(npc, dmg)
		local elapsed = CurTime() - npc.lastPhraseTime

		if elapsed > 0.5 then
			local dmgSound = "npc/headcrab_poison/ph_wallpain" .. tostring(math.random(1,3)) .. ".wav"
			npc:EmitSound(dmgSound, 75, 80)
			npc.lastPhraseTime = CurTime()
		end

		--Remove our headcrab after we die. (also stops our gurgle)
		local ent = npc
		timer.Simple(0, function()
			if IsValid(ent) and ent:Health() <= 0 then
				npc.jcms_charpleGurgle:Stop()

				for i, v in ipairs(ents.FindInSphere(ent:GetBonePosition(40), 0.01)) do
					if v:GetClass() == "npc_headcrab_fast" then
						v:Remove()
					end
				end
			end
		end)
	end
}
