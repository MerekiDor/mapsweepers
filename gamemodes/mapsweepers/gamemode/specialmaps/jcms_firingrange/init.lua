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

jcms.specialmap_missionType = "arenamode"

jcms.specialmap_arenaPos = Vector(-160, 3632, -256)
jcms.specialmap_arenaRadius = 256

function jcms.specialmap_GetDifficulty()
    if jcms.arena_settings then
        return tonumber(jcms.arena_settings.difficulty) or 1
    else
        return 1
    end
end

function jcms.specialmap_GetAndIncrementSquadIndex()
    local d = jcms.arena_data
    if d then
        d.squadIndex_npcCount = ( (d.squadIndex_npcCount or 0) + 1) % jcms.npcSquadSize
        d.squadIndex = (d.squadIndex or 0) + (d.squadIndex_npcCount == 0 and 1 or 0)
        return d.squadIndex
    else
        return 0
    end
end

function jcms.specialmap_IsWithinArena(pos)
    local pad = 4
    local mins_arena = Vector( -2528-pad, 2608-pad, -383-pad )
    local maxs_arena = Vector( 2208+pad, 4656+pad, 230+pad )

    local mins_observation = Vector(-336-pad, 2608-pad, -22-pad)
    local maxs_observation = Vector(16+pad, 4656+pad, 191+pad)

    return pos:WithinAABox(mins_arena, maxs_arena) and not pos:WithinAABox(mins_observation, maxs_observation)
end

function jcms.specialmap_AirgraphLeafCond(mins, maxs, leaf)
    local aux = maxs + mins
    aux:Mul(0.5)

    if jcms.specialmap_IsWithinArena(aux) then
        aux:Mul(2)
        aux:Sub(mins)
        aux:Sub(mins)
        return aux.x > 200 and aux.y > 200 and aux.z > 128, 0.1
    else
        return false, 0.1
    end
end

function jcms.specialmap_CleanupArena()
    local excluded_classes = {
        ["ai_hint"] = true,
        ["spotlight_end"] = true,
        ["beam"] = true
    }

    for i, ent in ents.Iterator() do
        if not ent:CreatedByMap() and jcms.specialmap_IsWithinArena(ent:WorldSpaceCenter()) then
            local classname = ent:GetClass()
            if not excluded_classes[ ent ] then
                ent:Dissolve()
            end
        end
    end
end

function jcms.specialmap_CustomSpawnFunction(ply, transition)
	ply.jcms_justSpawned = true
	ply:SetNWString("class", "infantry")
	jcms.playerspawn_Sweeper(ply, ply:GetPos(), true)
	ply:SetNWInt("jcms_cash", 0)
	ply:SetTeam(1)
	ply.jcms_justSpawned = false
	jcms.net_SendRespawnEffect(ply)
end

function jcms.specialmap_CustomRespawnFunc(ply)
	ply.jcms_justSpawned = true
	ply:SetNWString("class", "infantry")
    
    local pos
    local ang
    if ply.jcms_inArena then
        -- TODO account for RBs
        pos = Vector(512 + math.random(-1, 1)*32, 2508 + math.random(-1,1)*32, 64)
        ang = Angle(0, 90, 0)
    else
        pos = Vector(480 + math.random(-2, 2)*32, 1536 + math.random(-2, 2)*32, 0)
        ang = Angle(0, 0, 0)
    end

    jcms.playerspawn_Sweeper(ply, pos, true)
	ply:SetTeam(1)
	ply.jcms_justSpawned = false
    ply.jcms_inArena = false
    ply:SetEyeAngles( ang )
end

function jcms.specialmap_TrackNPC(npc)
    if jcms.arena_data then
        table.insert(jcms.arena_data.npcs, npc)

        if jcms.arena_settings and jcms.arena_settings.bountymul then
            npc.jcms_bounty = math.ceil( (npc.jcms_bounty or 0) * jcms.arena_settings.bountymul )
        end
    end
end

function jcms.specialmap_AllowWeaponManipulate(ply, weaponClass, isRemoving)
    return (not isRemoving) or (weaponClass ~= "weapon_stunstick")
end

-- DOOM Music (addon compatibility) {{{
    timer.Simple(2, function()
        if jcms.doomdms_musicIntensityLogic then
            function jcms.doomdms_musicIntensityLogic()
                for ply, intensity in pairs( jcms.doomdms_lastValues ) do
                    if not IsValid(ply) then
                        jcms.doomdms_lastValues[ ply ] = nil
                    end
                end

                local INTENSITY_NONE = 0
                local INTENSITY_LIGHT = 1
                local INTENSITY_HEAVY = 2

                local intensity_tallies = {
                    [INTENSITY_NONE] = 0,
                    [INTENSITY_LIGHT] = 4,
                    [INTENSITY_HEAVY] = 16
                }

                if jcms.arena_data then
                    for i, ply in ipairs( player.GetHumans() ) do
                        local intensity = INTENSITY_NONE
                        if ply.jcms_inArena then
                            intensity = jcms.arena_data.wave >= 5 and INTENSITY_HEAVY or INTENSITY_LIGHT
                        end

                        if jcms.doomdms_lastValues[ ply ] ~= intensity then
                            jcms.doomdms_lastValues[ ply ] = intensity
                            
                            net.Start("DOOM_CalculateHostiles")
                                net.WriteInt(intensity_tallies[intensity] or 0, 32)
                                net.WriteInt(1, 32)
                            net.Send(ply)
                        end
                    end
                else
                    for ply, intensity in pairs( jcms.doomdms_lastValues ) do
                        jcms.doomdms_lastValues[ ply ] = nil
                        net.Start("DOOM_CalculateHostiles")
                            net.WriteInt(0, 32)
                            net.WriteInt(1, 32)
                        net.Send(ply)
                    end
                end
            end

            hook.Add("Think", "DOOM_CalculateHostiles", jcms.doomdms_musicIntensityLogic)
        end
    end)
-- }}}

-- Arena Function {{{

    function jcms.specialmap_StartArena(arena_settings)
        jcms.arena_settings = arena_settings
        jcms.arena_data = { 
            wave = 0, 
            cost = 10 + arena_settings.difficulty * 3,
            costIncreases = 0,
            costIncreaseCountdown = 1,
            respawns = arena_settings.respawns,
            players = table.Copy( jcms.arena_settings.players ),
            npcs = {},
            killsTotal = 0,
            deathsTotal = 0,
            canProgress = false,
            startedAt = CurTime(),
            lastWaveAt = 0,
            dontThinkUntil = 0,
            lastKillAt = 0
        }

        game.GetWorld():SetNWString("jcms_missiontype", "arenamode")
        game.GetWorld():SetNWString("jcms_missionfaction", arena_settings.faction)
        game.GetWorld():SetNWInt("jcms_difficulty", jcms.runprogress_GetDifficulty())
        jcms.net_ShareMissionData({}, arena_settings.players)

        for i, ply in ipairs(arena_settings.players) do
            ply:SetHealth( ply:GetMaxHealth() )
            ply:SetArmor( ply:GetMaxArmor() )
            ply:ScreenFade(SCREENFADE.OUT, color_black, 1, 1)
        end

        timer.Simple(1.5, function()
            local randomAngle = math.random() * math.pi * 2
            local arena_maxradius = arena_settings.radius or 250
            local count = #arena_settings.players
            
            local radius = 0
            if count > 1 then
                local factor = math.sqrt( math.TimeFraction(2, 16, count) )
                radius = Lerp(factor, 48, arena_maxradius)
            end

            local arena_x, arena_y, arena_z = arena_settings.pos:Unpack()
            for i, ply in ipairs(arena_settings.players) do
                if IsValid(ply) then
                    local ang = i / count * math.pi * 2 + randomAngle
                    local cos, sin = math.cos(ang)*radius, math.sin(ang)*radius
                    ply:SetPos( Vector( arena_x + cos, arena_y + sin, arena_z ) )
                    ply:SetEyeAngles( Angle( 0, math.deg(ang), 0 ) )
                    ply:ScreenFade(SCREENFADE.IN, color_black, 0.5, 0.5)
                    ply.jcms_inArena = true
                end
            end
        end)

        timer.Simple(5, function()
            timer.Create("jcms_ArenaThink", 0.5, 0, jcms.specialmap_ArenaThink)
        end)
    end

    function jcms.specialmap_ArenaCanProgress(arena_settings, arena_data)
        local nextwave = arena_settings.nextwave

        if nextwave == "clear" then
            return #arena_data.npcs <= 0
        elseif nextwave == "press" then
            return arena_data.lastWaveAt == 0 or arena_data.nextWaveTriggered
        elseif nextwave == "15s" or nextwave == "30s" or nextwave == "60s" then
            local time = tonumber( nextwave:sub(1, 2) ) or 15
            return (arena_data.lastWaveAt == 0) or (CurTime() - arena_data.lastWaveAt >= time)
        end
    end

    function jcms.specialmap_GetArenaString()
        local arena_settings = jcms.arena_settings
        local arena_data = jcms.arena_data
        if not (arena_settings and arena_data) then return "?" end
        return arena_settings.waves >= math.huge and tostring(arena_data.wave) or arena_data.wave .. "/" .. arena_settings.waves
    end

    function jcms.specialmap_GetArenaProgress()
        local arena_settings = jcms.arena_settings
        local arena_data = jcms.arena_data
        if not (arena_settings and arena_data) then return 0 end
        return arena_settings.waves >= math.huge and 0.999 or arena_data.wave / arena_settings.waves
    end

    function jcms.specialmap_ArenaThink()
        local arena_settings = jcms.arena_settings
        local arena_data = jcms.arena_data
        if not (arena_settings and arena_data) then return end

        for i=#arena_data.players, 1, -1 do
            local ply = arena_data.players[i]
            if not ( IsValid(ply) and ply:Alive() ) then
                table.remove(arena_data.players, i)
                arena_data.deathsTotal = arena_data.deathsTotal + 1
            end
        end

        if arena_data.dontThinkUntil and CurTime() < arena_data.dontThinkUntil then
            return
        end

        for i=#arena_data.npcs, 1, -1 do
            local npc = arena_data.npcs[i]
            local shouldRemove = false
            if IsValid(npc) then
                local state = npc:GetNPCState()
                if npc.jcms_Think then
                    npc:jcms_Think(state)
                end

                if state == NPC_STATE_DEAD then
                    shouldRemove = true
                end
            else
                shouldRemove = true
            end

            if shouldRemove then
                table.remove(arena_data.npcs, i)
                arena_data.killsTotal = arena_data.killsTotal + 1
                arena_data.lastKillAt = CurTime()
            end
        end

        if #arena_data.npcs <= 3 and (arena_data.lastKillAt > 0) and (CurTime() - arena_data.lastKillAt > 12) then
            for i, npc in ipairs(arena_data.npcs) do
                jcms.net_SendLocator(arena_data.players, "as"..npc:EntIndex(), "#jcms.arenastraggler", npc, jcms.LOCATOR_GENERIC, 2)
            end
        end

        if #arena_data.players > 0 then
            if (arena_data.wave >= arena_settings.waves) and (arena_settings.waves ~= math.huge) then
                -- All waves done. We're now just waiting for all NPCs to die
                if #arena_data.npcs <= 0 then
                    jcms.specialmap_EndArena(true)
                end
            elseif jcms.specialmap_ArenaCanProgress(arena_settings, arena_data) then
                -- Waves not done but there may be extra conditions depending on the mode we've chosen
                jcms.specialmap_NextWave()
            end
        else
            jcms.specialmap_EndArena(false)
        end
    end

    function jcms.specialmap_EndArena(victory)
        local arena_settings = jcms.arena_settings
        local arena_data = jcms.arena_data
        if not (arena_settings and arena_data) then return end

        local arenaString = jcms.specialmap_GetArenaString()
        local arenaProgress = jcms.specialmap_GetArenaProgress()
        local killsString = jcms.util_CashFormat(arena_data.killsTotal)

        if victory then
            jcms.net_SendTip(arena_data.players, true, "#jcms.arenavictory", arenaProgress, { arenaString, killsString })
        else
            jcms.net_SendTip("all", true, "#jcms.arenafail", arenaProgress, { arenaString, killsString })
        end

        timer.Simple(3.5, function()
            for i, ply in ipairs(arena_data.players) do
                if IsValid(ply) and ply:Alive() and ply.jcms_inArena then
                    ply:ScreenFade(SCREENFADE.OUT, color_white, 1, 0.5)
                end
            end
        end)

        timer.Simple(5, function()
            local pos = Vector(-480, 2336, 0)
            local ang = Angle(0, 180, 0)
            local offsets = { 0, -32, 32, -64, 64, -96, 96, -128, 128, -160, 160, -192, 192 }
            for i, ply in ipairs(arena_data.players) do
                if IsValid(ply) and ply:Alive() and ply.jcms_inArena then
                    ply.jcms_inArena = nil
                    ply:SetEyeAngles(ang)

                    local off_x = 32 * math.floor( (i-1) / (#offsets) )
                    local off_y = offsets[ ((i-1) % (#offsets)) + 1 ]
                    ply:SetPos(pos + Vector(off_x, off_y, 0))
                    ply:ScreenFade(SCREENFADE.IN, color_white, 0.75, 0.15)
                end
            end
            jcms.specialmap_CleanupArena()
        end)

        jcms.arena_settings = nil
        jcms.arena_data = nil

        timer.Remove("jcms_ArenaThink")
    end

    function jcms.specialmap_NextWave()
        local arena_settings = jcms.arena_settings
        local arena_data = jcms.arena_data
        if not (arena_settings and arena_data) then return end

        arena_data.lastWaveAt = CurTime()
        arena_data.dontThinkUntil = CurTime() + 5
        arena_data.nextWaveTriggered = nil
        arena_data.wave = arena_data.wave + 1
        arena_data.costIncreaseCountdown = arena_data.costIncreaseCountdown - 1
        if arena_data.costIncreaseCountdown <= 0 then
            arena_data.costIncreases = arena_data.costIncreases + 1
            arena_data.costIncreaseCountdown = 1 + arena_data.costIncreases
            arena_data.cost = math.min(arena_data.cost + 2, 100)
        end

        if arena_settings.wavebonus and arena_settings.wavebonus > 0 then
            for i, ply in ipairs(arena_data.players) do
                jcms.giveCash(ply, arena_settings.wavebonus)
            end
        end

        local hasSupplyDrop = false
        if arena_settings.supplydrops and arena_settings.supplydrops > 0 then
            hasSupplyDrop = arena_data.wave > 1 and (arena_data.wave % arena_settings.supplydrops == 0)
        end

        jcms.net_SendTip(arena_data.players, true, hasSupplyDrop and "#jcms.arenawavesupplies" or "#jcms.arenawave", jcms.specialmap_GetArenaProgress(), { jcms.specialmap_GetArenaString() })

        for i=0, 2 do
            timer.Simple(i, function()
                local filter = RecipientFilter()
                filter:AddPlayers(arena_settings.players)
                EmitSound("ambient/alarms/klaxon1.wav", arena_settings.pos, 0, CHAN_AUTO, 1, 150, 0, 97, 0, filter )
            end)
        end

        local dangerCap = arena_data.wave % 2 == 1 and jcms.NPC_DANGER_FODDER or jcms.NPC_DANGER_STRONG
        if arena_data.wave % 16 == 0 then
            dangerCap = jcms.NPC_DANGER_RAREBOSS
        elseif arena_data.wave % 5 == 0 then
            dangerCap = jcms.NPC_DANGER_BOSS
        end
        
        local hasEpisodes = jcms.HasEpisodes()
        local validTypes = {}
        for npcType, data in pairs(jcms.npc_types) do
            if (not hasEpisodes and data.episodes) then continue end

            if (data.faction == arena_settings.faction or data.faction == "any") and (not data.secretNPC) and (not data.missionSpecific) and (data.danger <= dangerCap) then
                validTypes[ npcType ] = data.swarmWeight or 1
            end
        end

        local totalCost = arena_data.cost
        local queue = {}
        local typeCounts = {}

        local function addToQueue(spawnType, data, cost)
            totalCost = totalCost - cost
            table.insert(queue, spawnType)
            typeCounts[spawnType] = (typeCounts[spawnType] or 0) + 1

            if data.swarmLimit and typeCounts[spawnType] >= data.swarmLimit then
                validTypes[spawnType] = nil
            end
        end

        for i=1, 75 do
            local shuffled = jcms.util_GetShuffledByWeight(validTypes)
            
            local spawned = false
            for j, spawnType in ipairs(shuffled) do
                local data = jcms.npc_types[ spawnType ]
                local cost = data.cost or 1

                if (#queue == 0) or (cost <= totalCost) then
                    addToQueue(spawnType, data, cost)
                    spawned = true
                    break
                end
            end
            
            if (totalCost <= 0) or (not spawned) then
                break
            end
        end

        local spawnpoints = table.Copy(ainReader.nodePositions)
        table.Shuffle(spawnpoints)

        if #queue <= #spawnpoints then
            local navAreas = navmesh.GetAllNavAreas()
            for i, npcType in ipairs(queue) do
                local randomPly = arena_data.players[ math.random(1, #arena_data.players) ]
                local randomArea = navAreas[ math.random(1, #navAreas) ]

                local pos = spawnpoints[i]
                local npcData = jcms.npc_types[ npcType ]
                if npcData.aerial then
                    local nearestNode = jcms.pathfinder.getNearestNode(pos)
                    if nearestNode then 
                        pos = nearestNode.pos or pos
                    end
                elseif npcData.hullSize then 
                    local nearestNode = jcms.pathfinder_ain_nearestHullNode(pos, npcData.hullSize)
                    if nearestNode then 
                        pos = ainReader.nodePositions[nearestNode] or pos
                    end
                end

                jcms.npc_SpawnFancy(npcType, pos, 3 + math.random(), randomPly, randomArea)
            end
        else
            print("TOO MANY", #queue, #spawnpoints)
        end

        if hasSupplyDrop and #spawnpoints > 0 then
            local randomSpot = spawnpoints[ math.random(1, #spawnpoints) ]
            
            local dropSpot = Vector(randomSpot)
            dropSpot.z = dropSpot.z + 16
            local dropSkyPos, isClear = jcms.util_GetSky(dropSpot)

            local prop = ents.Create("item_item_crate")

            if isClear then
                dropSkyPos.z = dropSkyPos.z - 16
                prop:SetPos(dropSkyPos)
            else
                prop:SetPos(dropSpot)
            end

            prop:SetAngles(AngleRand())
            prop:SetKeyValue("ItemClass", "jcms_dynamicsupply")
            prop:SetKeyValue("ItemCount", dangerCap >= jcms.NPC_DANGER_BOSS and 2 or 1)
            prop:Spawn()

            jcms.net_SendLocator(arena_data.players, nil, "#jcms.arenasupplies", prop, jcms.LOCATOR_GENERIC, 10)
        end
    end

-- }}}

-- Terminals {{{

    -- Firing Range {{{
        -- Class Changer
        if IsValid( jcms.specialmap_term1 ) then jcms.specialmap_term1:Remove() end
        jcms.specialmap_term1 = ents.Create("jcms_terminal")
        jcms.specialmap_term1:SetPos( Vector(478, 1866, 44) )
        jcms.specialmap_term1:SetAngles( Angle(-8, -90, 0) )
        jcms.specialmap_term1:Spawn()
        jcms.specialmap_term1:InitAsTerminal("models/props_combine/combinebutton.mdl", "cheat_changeclass")
        jcms.specialmap_term1.jcms_hackType = nil

        -- Weapon/Ammo Giver
        if IsValid( jcms.specialmap_term2 ) then jcms.specialmap_term2:Remove() end
        jcms.specialmap_term2 = ents.Create("jcms_terminal")
        jcms.specialmap_term2:SetPos( Vector(684, 1664, 27) )
        jcms.specialmap_term2:SetAngles( Angle(-8, 180, 0) )
        jcms.specialmap_term2:Spawn()
        jcms.specialmap_term2:InitAsTerminal("models/props_combine/combinebutton.mdl", "cheat_giveguns")
        jcms.specialmap_term2.jcms_hackType = nil

        -- Cash Giver
        if IsValid( jcms.specialmap_term3 ) then jcms.specialmap_term3:Remove() end
        jcms.specialmap_term3 = ents.Create("jcms_terminal")
        jcms.specialmap_term3:SetPos( Vector(684, 1664-256, 27) )
        jcms.specialmap_term3:SetAngles( Angle(-8, 180, 0) )
        jcms.specialmap_term3:Spawn()
        jcms.specialmap_term3:InitAsTerminal("models/props_combine/combinebutton.mdl", "cheat_givecash")
        jcms.specialmap_term3.jcms_hackType = nil
    -- }}}

    -- Arena {{{
        -- Settings - Left
        if IsValid( jcms.specialmap_term4 ) then jcms.specialmap_term4:Remove() end
        jcms.specialmap_term4 = ents.Create("jcms_terminal")
        jcms.specialmap_term4:SetPos( Vector(-847, 2273, 54) )
        jcms.specialmap_term4:SetAngles( Angle(-12, 45, 0) )
        jcms.specialmap_term4:Spawn()
        jcms.specialmap_term4:InitAsTerminal("models/props_combine/combinebutton.mdl", "arena_waves")
        jcms.specialmap_term4.jcms_hackType = nil

        -- Settings - Center
        if IsValid( jcms.specialmap_term5 ) then jcms.specialmap_term5:Remove() end
        jcms.specialmap_term5 = ents.Create("jcms_terminal")
        jcms.specialmap_term5:SetPos( Vector(-866, 2330, 54) )
        jcms.specialmap_term5:SetAngles( Angle(-12, 0, 0) )
        jcms.specialmap_term5:Spawn()
        jcms.specialmap_term5:InitAsTerminal("models/props_combine/combinebutton.mdl", "arena_basics")
        jcms.specialmap_term5.jcms_hackType = nil

        -- Settings - Right
        if IsValid( jcms.specialmap_term6 ) then jcms.specialmap_term6:Remove() end
        jcms.specialmap_term6 = ents.Create("jcms_terminal")
        jcms.specialmap_term6:SetPos( Vector(-836, 2379, 54) )
        jcms.specialmap_term6:SetAngles( Angle(-12, -45, 0) )
        jcms.specialmap_term6:Spawn()
        jcms.specialmap_term6:InitAsTerminal("models/props_combine/combinebutton.mdl", "arena_bonuses")
        jcms.specialmap_term6.jcms_hackType = nil

        jcms.specialmap_term5.term_waves = jcms.specialmap_term4
        jcms.specialmap_term5.term_bonuses = jcms.specialmap_term6

        -- Class Changer (locker room)
        if IsValid( jcms.specialmap_term7 ) then jcms.specialmap_term7:Remove() end
        jcms.specialmap_term7 = ents.Create("jcms_terminal")
        jcms.specialmap_term7:SetPos( Vector(573, 2572, 44) )
        jcms.specialmap_term7:SetAngles( Angle(-8, -90, 0) )
        jcms.specialmap_term7:Spawn()
        jcms.specialmap_term7:InitAsTerminal("models/props_combine/combinebutton.mdl", "cheat_changeclass")
        jcms.specialmap_term7.jcms_hackType = nil

        -- Weapon/Ammo Giver (locker room)
        if IsValid( jcms.specialmap_term8 ) then jcms.specialmap_term8:Remove() end
        jcms.specialmap_term8 = ents.Create("jcms_terminal")
        jcms.specialmap_term8:SetPos( Vector(573-128, 2572, 44) )
        jcms.specialmap_term8:SetAngles( Angle(-8, -90, 0) )
        jcms.specialmap_term8:Spawn()
        jcms.specialmap_term8:InitAsTerminal("models/props_combine/combinebutton.mdl", "cheat_giveguns")
        jcms.specialmap_term8.jcms_hackType = nil

        -- Cash Giver (locker room)
        if IsValid( jcms.specialmap_term9 ) then jcms.specialmap_term9:Remove() end
        jcms.specialmap_term9 = ents.Create("jcms_terminal")
        jcms.specialmap_term9:SetPos( Vector(573-128-64, 2572, 44) )
        jcms.specialmap_term9:SetAngles( Angle(-8, -90, 0) )
        jcms.specialmap_term9:Spawn()
        jcms.specialmap_term9:InitAsTerminal("models/props_combine/combinebutton.mdl", "cheat_givecash")
        jcms.specialmap_term9.jcms_hackType = nil
    -- }}}

-- }}}

-- Hooks {{{

    hook.Add("MapSweepersPlayerOrder", "jcms_RestrictOrdersToArena", function(ply, orderId, a1, a2, a3, a4)
        if not jcms.orders[orderId] then 
            return true
        end

        if not ply.jcms_inArena then
            jcms.net_SendOrderMessage(ply, 7, "")
            return true 
        end

        if type(a1) == "Vector" and not jcms.specialmap_IsWithinArena(a1) and (jcms.orders[orderId].argparser ~= "orbital_fixed_outdoors") then
            jcms.net_SendOrderMessage(ply, 7, "")
            return true
        end
    end)

-- }}}