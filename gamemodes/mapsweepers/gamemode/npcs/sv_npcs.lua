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

jcms.npc_types = jcms.npc_types or {}
jcms.npc_commanders = {}

jcms.NPC_DANGER_FODDER = 1
jcms.NPC_DANGER_STRONG = 2
jcms.NPC_DANGER_BOSS = 3
jcms.NPC_DANGER_RAREBOSS = 4

jcms.npc_idleSchedules = {
	[SCHED_IDLE_STAND] = true,
	[SCHED_ALERT_STAND] = true
}

jcms.npcSquadSize = 4 -- Let's see if smaller squads fix their strange behavior. Used to be 16.

-- // Misc {{{

	function jcms.npc_GetScaledCost(data) --Spam more fodder enemies when there are more players.
		local cost = data.cost or 1
		if data.danger == jcms.NPC_DANGER_FODDER or data.danger == jcms.NPC_DANGER_STRONG then
			local plyCount = (jcms.director and jcms.director.livingPlayers) or #team.GetPlayers(1)

			cost = cost / math.sqrt(plyCount)
			cost = cost / jcms.runprogress_GetDifficulty()
			--For reference: 2pl is roughly 1.58x fodder count, 4pl is 2.52x, 8pl is roughly 4x.
		end
		return cost
	end

	function jcms.npc_GetScaledDamage(override)
		local plyCount = override or #team.GetPlayers(1)
		return (1 + math.max((plyCount-1) * 0.125, 0)) * jcms.runprogress_GetDifficulty()
	end

	function jcms.npc_GetScaledSwarmWeight(data) 
		--Absolute difficulty value affects strong-ratio. 
		--If this is too noticeable make it math.sqrt(difficulty)
		local missionTimeMult = 1
		if jcms.director then 
			--2x every 1 hour
			missionTimeMult = 1 + (jcms.director_GetMissionTime() / (60*60))
		end

		return (data.danger == jcms.NPC_DANGER_STRONG and data.swarmWeight * jcms.runprogress_GetDifficulty() * missionTimeMult) or data.swarmWeight or 1
	end

-- // }}

-- // NPC Players {{{

	function jcms.npc_GetPlayersToRespawn()
		local t = {}
		local d = jcms.director
		
		for i, ply in ipairs( player.GetAll() ) do
			if ply.jcms_isNPC and (not ply:Alive() or ply:GetObserverMode() == OBS_MODE_CHASE) then
				if (not d) or (d.npcPlayerRespawnTimes and (d.npcPlayerRespawnTimes[ply] or 0) < CurTime()) then
					table.insert(t, ply)
				end
			end
		end
		
		return t
	end
	
	function jcms.npc_GeneratePlayerRespawnTable(ply)
		local d = jcms.director
		
		if d then
			local class = jcms.npc_PickPlayerNPCClass(d.faction)
			return { ply = ply, class = class, faction = d.faction }
		else
			return { ply = ply }
		end
	end
	
	function jcms.npc_PickPlayerNPCClass(faction)
		local options = {}
		
		for className, classData in pairs(jcms.classes) do
			if classData.faction == faction and not classData.jcorp then
				table.insert(options, className)
			end
		end
		
		return options[ math.random(1, #options) ]
	end

-- // }}}

-- // Spawning & Swarms {{{

	function jcms.npc_GetAndIncrementSquadIndex()
		local d = jcms.director
		
		if d then
			-- Every time this function is called it counts an NPC.
			-- If NPC count goes above [jcms.npcSquadSize], counter resets to 0
			-- and a new squad is created. Basically this makes sure that all NPCs spawn in squads of [jcms.npcSquadSize].
			d.squadIndex_npcCount = ( (d.squadIndex_npcCount or 0) + 1) % jcms.npcSquadSize
			d.squadIndex = (d.squadIndex or 0) + (d.squadIndex_npcCount == 0 and 1 or 0)
			return d.squadIndex
		else
			return 0
		end
	end

	function jcms.npc_Spawn(enemyType, pos, fromPortal)
		jcms.blockNPCTracker = true
		local enemyData = assert(jcms.npc_types[ enemyType ], "invalid enemy type '" .. tostring(enemyType) .. "'")
		
		assert( isvector(pos), "supply a vector please" )
		local npc = ents.Create(enemyData.class)
		if not IsValid(npc) then return NULL end
		local npcTbl = npc:GetTable()
		npcTbl.jcms_fromPortal = fromPortal
		
		npc:SetAngles( Angle(0, math.random() * 360, 0) )
		
		if enemyData.preSpawn then 
			enemyData.preSpawn(npc, pos, enemyData) 
		end
		
		if enemyData.think then
			npcTbl.jcms_Think = enemyData.think
		end

		if enemyData.scaleDamage then 
			npcTbl.jcms_ScaleDamage = enemyData.scaleDamage
		end
		npc:Spawn()
		if not game.SinglePlayer() then
			npc:SetLagCompensated( true )
		end

		if npc.SetMaxLookDistance then
			npc:SetMaxLookDistance( math.max(npc:GetMaxLookDistance(), 4096) )
		end
		npc:SetPos(pos + Vector(0,0,35))

		local hulltrace = util.TraceEntityHull({
			start = npc:EyePos(),
			endpos = pos,
			mask = MASK_NPCSOLID_BRUSHONLY
		}, npc)
		npc:SetPos(hulltrace.HitPos)
		
		--debugoverlay.Line(hulltrace.StartPos, hulltrace.HitPos, 1, Color(255, 0, 0), true)
		--debugoverlay.Box(hulltrace.HitPos, npc:OBBMins(), npc:OBBMaxs(), 1, Color(255, 0, 0), true)
		
		npcTbl.jcms_enemyType = enemyType
		npcTbl.jcms_danger = enemyData.danger or jcms.NPC_DANGER_FODDER
		npcTbl.jcms_TakeDamage = enemyData.takeDamage
		npcTbl.jcms_EntityFireBullets = enemyData.entityFireBullets
		npcTbl.jcms_damageEffect = enemyData.damageEffect
		npcTbl.jcms_faction = enemyData.faction

		npcTbl.jcms_bounty = enemyData.bounty or 100
		npcTbl.jcms_damageShare = {}

		if enemyData.danger == jcms.NPC_DANGER_BOSS or enemyData.danger == jcms.NPC_DANGER_RAREBOSS then --Make bosses stronger the more players there are
			local npcHP, npcMHP = npc:Health(), npc:GetMaxHealth()
			local plyCount = jcms.director and jcms.director.livingPlayers or 1

			--Add 50% of the boss's base HP to its pool for each player over 1.
			local mult = 0.5 * math.Max(plyCount-1, 0)
			npc:SetMaxHealth(npcMHP * (1 + mult) * jcms.runprogress_GetDifficulty())
			npc:SetHealth(npcHP * (1 + mult) * jcms.runprogress_GetDifficulty())

			npcTbl.jcms_bounty = npcTbl.jcms_bounty * (1 + mult/2) --25% increase in bounty per player to keep the economy vaguely similar.
		end

		if enemyData.weapon then
			npc:Give(enemyData.weapon)
		elseif enemyData.weapons then
			npc:Give(jcms.util_ChooseByWeight(enemyData.weapons))
		end

		if enemyData.proficiency then
			npc:SetCurrentWeaponProficiency(enemyData.proficiency)
		end

		if enemyData.postSpawn then 
			enemyData.postSpawn(npc, pos, enemyData) 
		end

		if enemyData.model then
			npc:SetModel(enemyData.model)
		end

		if enemyData.skin then
			npc:SetSkin(enemyData.skin)
		end

		if enemyData.timedEvent and enemyData.timerMin and enemyData.timerMax then
			timer.Simple( math.Rand(enemyData.timerMin, enemyData.timerMax), function()
				if IsValid(npc) then
					enemyData.timedEvent(npc, enemyData)
				end
			end )
		end

		local isNPC = npc:IsNPC()
		if isNPC then
			local squadName = string.format("%s%x", enemyData.faction, jcms.npc_GetAndIncrementSquadIndex())
			npc:SetSquad(squadName)
			npc:CapabilitiesAdd(bit.bor(CAP_MOVE_JUMP, CAP_USE, CAP_AUTO_DOORS, CAP_OPEN_DOORS))
		end
		
		jcms.npc_UpdateRelations(npc)

		if jcms.director and not enemyData.anonymous and isNPC then
			table.insert(jcms.director.npcs, npc)
		end

		hook.Run("MapSweepersNPCSpawned", npc, enemyType, enemyData, pos, fromPortal)
		
		jcms.blockNPCTracker = false
		return npc
	end

	function jcms.npc_SpawnFancy(enemyType, pos, delay, giveAwayPlayer, patrolArea)
		local enemyData = assert(jcms.npc_types[ enemyType ], "invalid enemy type '" .. tostring(enemyType) .. "'")
		assert( isvector(pos), "supply a vector please" )
		delay = math.max(0.1, tonumber(delay) or 1)
		
		local noeffect = enemyData.suppressSwarmPortalEffect
		local colorInteger = jcms.factions_GetColorInteger(enemyData.faction)

		if not noeffect then
			local ed = EffectData()
			ed:SetColor(colorInteger)
			ed:SetFlags(1)
			ed:SetOrigin(pos + Vector(0, 0, 256))
			ed:SetStart(pos + Vector(0, 0, 40))
			ed:SetMagnitude(delay)
			ed:SetScale(enemyData.portalScale or 1)
			util.Effect("jcms_spawneffect", ed)
		end
		
		local time = CurTime()
		timer.Simple(delay, function()
			local npc = jcms.npc_Spawn(enemyType, pos + Vector(0, 0, 8), false)
			if IsValid(npc) then
				if not noeffect then
					local ed2 = EffectData()
					ed2:SetColor(colorInteger)
					ed2:SetFlags(0)
					ed2:SetEntity(npc)
					util.Effect("jcms_spawneffect", ed2)
				end
				
				if IsValid(giveAwayPlayer) then
					npc:UpdateEnemyMemory(giveAwayPlayer, IsValid(patrolArea) and patrolArea:GetCenter() or giveAwayPlayer:GetPos())
					npc:SetSchedule(SCHED_CHASE_ENEMY)
				elseif IsValid(patrolArea) then
					timer.Simple(math.Rand(5, 7), function()
						if IsValid(npc) and npc:GetKnownEnemyCount() == 0 then
							npc:NavSetGoalPos(patrolArea:GetCenter())
							npc:StartEngineTask(48, 0)
						end
					end)
				end
			end
		end)
	end
	
	function jcms.npc_HandleStragglers(npcs)
		local d = jcms.director
		if d then
			local stragglerDelay = 1

			-- We only handle stragglers if there's at least a small squad of them.
			if #npcs >= 3 then
				local origins = {}
				local sweepers = jcms.GetAliveSweepers()

				for i, sweeper in ipairs(sweepers) do
					local v = sweeper:EyePos()
					table.insert(origins, v)
				end

				local areas = (d.zonePopulations[1] and d.zonePopulations[1]>0) and jcms.director_GetAreasAwayFrom(jcms.mapgen_ZoneList()[1], origins, 300, 2048) or {}
				for ply, area in pairs(d.playerAreas) do
					local zoneIndex = jcms.mapgen_ZoneDict()[ area ]
					if zoneIndex and zoneIndex > 1 then
						table.Add(areas, jcms.mapgen_ZoneList()[zoneIndex])
					else
						table.insert(areas, area)
					end
				end

				local vectors = jcms.mapgen_SubdivideAreasIntoVectors(areas, 512)
				table.Shuffle(vectors)

				local output = {}
				local trdata = { mask = MASK_VISIBLE, output = output }

				for i, v in ipairs(vectors) do
					v.z = v.z + 32
					local invisible = true
					trdata.endpos = v
					for j, origin in ipairs(origins) do
						trdata.start = origin
						util.TraceLine(trdata)

						if not output.Hit then
							invisible = false
							break
						end
					end

					if invisible then
						local sqvectors = jcms.director_PackSquadVectors(v, math.min(math.random(3, 7), #npcs), 70)
						for j, sqv in ipairs(sqvectors) do
							local npc = npcs[ #npcs ]
							
							local colorInt = jcms.factions_GetColorInteger(npc.jcms_faction)
							npc.jcms_npcStragglerTime = CurTime() + 1
							npc.jcms_npcIsStraggler = false
							npcs[ #npcs ] = nil

							local ed = EffectData()
							ed:SetColor(colorInt)
							ed:SetFlags(1)
							ed:SetOrigin(v)
							ed:SetStart(Vector(sqv.x, sqv.y, sqv.z + 32))
							ed:SetMagnitude(stragglerDelay)
							ed:SetScale(1)
							util.Effect("jcms_spawneffect", ed)

							timer.Simple(stragglerDelay, function()
								if IsValid(npc) then
									npc:SetPos(sqv)
									jcms.npc_GetRowdy(npc)

									local ed = EffectData()
									ed:SetColor(colorInt)
									ed:SetFlags(0)
									ed:SetEntity(npc)
									util.Effect("jcms_spawneffect", ed)
								end
							end)
						end
					end

					if #npcs <= 0 then
						break
					end
				end
			end
		else
			-- This case is actually impossible due to being called from director code, but whatever.
			for i, npc in ipairs(npcs) do
				npc:Remove()
			end
		end
	end

-- }}}

-- // NPC Utility/Helper functions {{{

	function jcms.npc_AddBulletShield(npc, count)
		npc:SetNWInt("jcms_shield", math.min(npc:GetNWInt("jcms_shield", 0) + (tonumber(count) or 1), 5) ) -- capped at 5 because this can get ridiculously high.
	end

	function jcms.npc_GetRowdy(npc, memoryPos)
		if not IsValid(npc) then return end 
		
		local ply = jcms.director_PickClosestPlayer( npc:GetPos() )
		if IsValid(ply) and npc.SetEnemy then --Gets called on things that don't have SetEnemy, somehow.
			npc:SetEnemy(ply)
			npc:UpdateEnemyMemory(ply, ply:GetPos())
		end
	end

	local nmt = FindMetaTable("NPC")
	function jcms.npc_UpdateRelations(ent)
		local buddies, baddies = {}, {}
		
		local function iterateEnts(entList) 
			for i, oent in ipairs(entList) do 
				local same = jcms.team_SameTeam(ent, oent)
				
				if getmetatable(oent) == nmt then
					if same then
						nmt.AddEntityRelationship(oent, ent, D_LI, 1)
					else
						nmt.AddEntityRelationship(oent, ent, D_HT, 0)
					end
				end
	
				table.insert(same and buddies or baddies, oent)
			end
		end

		--More optimised than ents.iterator, as we don't have to check huge amounts of point entities (like ai nodes)
		--NOTE: Assumes all npcs are have npc_ classnames. This is not an issue for default npcs, but could be a problem for other npc packs.
		iterateEnts(ents.FindByClass("jcms_*"))
		iterateEnts(ents.FindByClass("npc_*"))
		iterateEnts(player.GetAll())

		if getmetatable(ent) == nmt then
			for i, buddy in ipairs(buddies) do
				nmt.AddEntityRelationship(ent, buddy, D_LI, 1)
			end
	
			for i, baddy in ipairs(baddies) do
				nmt.AddEntityRelationship(ent, baddy, D_HT, 0)
			end
		end
	end

	function jcms.npc_SetupSweeperShields(npc, max, regen, regenDelay, col)
		local colInt = (type(col)=="number" and col) or (IsColor(col) and jcms.util_ColorInteger(col)) or 255

		npc:SetNWInt("jcms_sweeperShield", max)
		npc:SetNWInt("jcms_sweeperShield_max", max)
		npc:SetNWInt("jcms_sweeperShield_colour", colInt)

		local timerIdentifier = "jcms_ShieldRegen" .. npc:EntIndex()
		timer.Create(timerIdentifier, 1 / regen, 0, function()
			if IsValid(npc) then 
				local shield = npc:GetNWInt("jcms_sweeperShield", 0)
				local maxShield = npc:GetNWInt("jcms_sweeperShield_max", 0)

				if shield < maxShield and (not npc.jcms_lastDamaged or CurTime()-npc.jcms_lastDamaged > regenDelay) then
					local newShield = shield + 1 
					npc:SetNWInt("jcms_sweeperShield", newShield)
					
					if newShield == maxShield then
						local ed = EffectData()
						ed:SetEntity(npc)
						ed:SetFlags(2)
						ed:SetColor(colInt)
						util.Effect("jcms_shieldeffect", ed)
						npc:EmitSound("items/suitchargeok1.wav", 50, 120)
					end
				end
			else
				timer.Remove(timerIdentifier)
			end
		end)
	end

	function jcms.npc_PortalReleaseXNPCs(ent, x, origin, faction, npcType, callback)
		local navArea = navmesh.GetNearestNavArea(origin) --TODO: Replace with something that only uses validAreas.
		if not IsValid(navArea) or not jcms.mapgen_ValidArea(navArea) then 
			return
		end
		local vectors, fully = jcms.director_PackSquadVectors(navArea:GetRandomPoint(), x, math.random(72, 200), { filter = ent })
		local colorInteger = jcms.factions_GetColorInteger(faction)

		for i, v in ipairs(vectors) do
			local delay = math.Rand(0.6, 3.5)

			local npcKind
			if isfunction(npcType) then 
				npcKind = npcType()
			else
				npcKind = npcType
			end
			local npcData = jcms.npc_types[npcKind]

			if npcData.aerial then
				local nearestNode = jcms.pathfinder.getNearestNode(v)

				if nearestNode then 
					v = nearestNode.pos
				end
			end

			local ed = EffectData()
			ed:SetColor(colorInteger)
			ed:SetFlags(1)
			ed:SetOrigin(origin)
			ed:SetStart(v + Vector(0, 0, 48))
			ed:SetMagnitude(delay)
			ed:SetScale(npcData and npcData.portalScale or 1)
			util.Effect("jcms_spawneffect", ed)
			
			
			timer.Simple(delay, function()
				local npc = jcms.npc_Spawn(npcKind, v + Vector(0,0,10), true)

				if IsValid(npc) then
					local ed2 = EffectData()
					ed2:SetColor(colorInteger)
					ed2:SetFlags(0)
					ed2:SetEntity(npc)
					util.Effect("jcms_spawneffect", ed2)
				end
				if isfunction(callback) then 
					callback(ent, npc)
				end
			end)
		end
	end

	function jcms.npc_capCheck(class, maxCount)
		local d = jcms.director
		if not d then return true end

		local npcCount = 0
		for i, npc in ipairs(jcms.director.npcs) do
			npcCount = npcCount + ( ( npc:GetClass() == class and 1 ) or 0 )
		end

		return npcCount < maxCount
	end
	
-- // }}}

-- // Tracking misc NPCs {{{

	jcms.npc_entityAssignmentData = {
		["npc_manhack"] = { bounty = 2, faction = "combine" },
		["npc_headcrab"] = { bounty = 1, faction = "zombie" },
		["npc_headcrab_fast"] = { bounty = 1, faction = "zombie" },
		["npc_headcrab_poison"] = { bounty = 2, faction = "zombie" },
		["npc_headcrab_black"] = { bounty = 2, faction = "zombie" }
	}

	hook.Add("OnEntityCreated", "jcms_npcTracker", function(ent)
		if jcms.director and not jcms.blockNPCTracker and ent:IsNPC() then
			local class = ent:GetClass()
			local data = jcms.npc_entityAssignmentData[ class ]

			if data then
				if data.faction then
					ent.jcms_faction = data.faction
				end

				if data.bounty then
					ent.jcms_bounty = data.bounty
				end

				jcms.npc_UpdateRelations(ent)
			end
		end
	end)

-- // }}}

-- // Standardized NAV code {{{

	function jcms.npc_airCheck(director) -- Check func for all air units
		return #jcms.pathfinder.airNodes > 0
	end

	-- // {{{ Enums for custom behaviours
		jcms.NPC_STATE_AIRIDLE = 0
		jcms.NPC_STATE_AIRNAVIGATE = 1
	-- // }}}

	function jcms.npc_setupNPCAirNav(npc) --Set the values we use
		npc.jcms_npcState = jcms.NPC_STATE_AIRIDLE

		npc.jcms_nav_ignoreEnemies = false
		npc.jcms_moveQueue = {}
		npc.jcms_moveFails = 0
		npc.jcms_lastDist = math.huge

		npc:CallOnRemove("jcms_airgraph_clearOccupied", function(ent)
			local nextNode = npc.jcms_moveQueue[#npc.jcms_moveQueue]
			if nextNode then 
				nextNode.occupied = false 
				npc.jcms_moveQueue[1].occupied = false
			end
		end)
	end

	function jcms.npc_airNavigateThink(npc, distTolerance)
		if not npc.jcms_nav_ignoreEnemies and IsValid(npc:GetEnemy()) then --Break our navigation if we spot an enemy (patrol), or ignore (chase)
			npc.jcms_npcState = jcms.NPC_STATE_AIRIDLE
		end

		local targetNode = npc.jcms_moveQueue[#npc.jcms_moveQueue] 
		npc:SetSaveValue("m_vecDesiredPosition", targetNode.pos)

		targetNode.occupied = true
		npc.jcms_moveQueue[1].occupied = true

		local dist = npc:GetPos():Distance(targetNode.pos)
		if dist < distTolerance then --Remove from queue if we've reached it. 
			npc.jcms_moveQueue[#npc.jcms_moveQueue] = nil
			npc.jcms_moveFails = 0 --Reset

			if #npc.jcms_moveQueue > 0 then --Prev node no longer occupied.
				targetNode.occupied = false
			end
		end

		if math.abs(npc.jcms_lastDist - dist) < 50 then 
			npc.jcms_moveFails = npc.jcms_moveFails + 1
		end
		npc.jcms_lastDist = dist 

		if #npc.jcms_moveQueue == 0 or npc.jcms_moveFails > 5 then --Return to default behaviour after reaching target.
			npc.jcms_npcState = jcms.NPC_STATE_AIRIDLE
			npc.jcms_moveFails = 0

			local nextNode = npc.jcms_moveQueue[#npc.jcms_moveQueue]
			if nextNode then 
				nextNode.occupied = false 
				npc.jcms_moveQueue[1].occupied = false
			end
		end
	end

	function jcms.npc_airThink(npc) 
		local enemy = npc:GetEnemy()
		local shouldPatrol = true

		if IsValid(enemy) then -- Chase. If we can.
			local enemyPos = enemy:GetPos()
			local validNodes = jcms.pathfinder.getNodesInPVS( enemyPos )

			local closest
			local closestDist = math.huge
			for i, node in ipairs(validNodes) do 
				local dist = node.pos:DistToSqr(enemyPos)
				if dist < closestDist and not node.occupied and enemy:VisibleVec(node.pos) then 
					closest = node
					closestDist = dist 
				end
			end

			if closest then 
				local queue = jcms.pathfinder.navigate(npc:GetPos(), closest.pos)
				if queue then 
					shouldPatrol = false
					npc.jcms_moveQueue = queue 

					npc.jcms_nav_ignoreEnemies = true
					npc.jcms_npcState = jcms.NPC_STATE_AIRNAVIGATE
				end
			end
		end
		
		if shouldPatrol then -- Patrol
			-- We ignore nodes too far above sweepers, because that tends to send them ridiculously high (where they obviously won't find enemies).
			local sweepers = jcms.GetAliveSweepers()
			local highestZ = #sweepers <= 0 and math.huge or -math.huge -- If there are no sweepers for some reason, patrol anywhere.
			for i, ply in ipairs(sweepers) do 
				local newZ = ply:GetPos().z
				highestZ = ((newZ > highestZ) and newZ) or highestZ
			end

			local validNodes = {}
			for i, node in ipairs(jcms.pathfinder.airNodes) do 
				if node.pos.z < highestZ + 2500 and not node.occupied then --Don't go too high
					table.insert(validNodes, node) 
				end
			end
			local chosenNode = validNodes[math.random(#validNodes)]

			if chosenNode then
				local queue = jcms.pathfinder.navigate(npc:GetPos(), chosenNode.pos)
				if queue then
					npc.jcms_moveQueue = queue

					npc.jcms_nav_ignoreEnemies = false
					npc.jcms_npcState = jcms.NPC_STATE_AIRNAVIGATE
				end
			end
		end
	end

-- // }}
