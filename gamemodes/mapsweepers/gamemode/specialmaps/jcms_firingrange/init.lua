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

function jcms.specialmap_CustomSpawnFunction(ply, transition)
    if not jcms.mapdata.analyzed then
        jcms.mapgen_AnalyzeMap(true)
    end

    local pos
    local ang
    if ply.jcms_inArena then
        if jcms.arena_data and ply.jcms_arenaSetToRespawn then
            pos, ang = jcms.specialmap_GetArenaRespawnPos(ply)
        else
            pos = Vector(512 + math.random(-1, 1)*32, 2508 + math.random(-1,1)*32, 64)
            ang = Angle(0, 90, 0)
            ply.jcms_inArena = nil
            ply:SetNWInt("jcms_cash", 0)
        end
    else
        pos = Vector(480 + math.random(-2, 2)*32, 1536 + math.random(-2, 2)*32, 0)
        ang = Angle(0, 0, 0)
    end

    ply.jcms_arenaSetToRespawn = nil

    if ply:GetNWString("jcms_class", "") == "" then
        -- spawning for the first time
        jcms.printf("Spawning %s for the first time", ply:Nick())
        ply:SetNWString("jcms_class", "infantry")
        ply:SetNWInt("jcms_cash", 0)
        pos = ply:GetPos()
        ang = ply:EyeAngles()
    else
        jcms.net_SendRespawnEffect(ply)
    end

    ply:SetNWString("jcms_desiredclass", ply:GetNWString("jcms_class", "infantry"))
    ply.jcms_justSpawned = true
        jcms.net_ShareMissionData({}, ply)
        jcms.playerspawn_Sweeper(ply, pos, true)
        jcms.specialmap_RestoreLoadout(ply, ply.jcms_lastLoadout)
        ply:SetEyeAngles( ang )
        ply:SetTeam(1)
	ply.jcms_justSpawned = false
end

function jcms.specialmap_RestoreLoadout(ply, loadout)
    if type(loadout) == "table" then
        for class in pairs(loadout) do
            ply:Give(class)
        end
    end
end

function jcms.specialmap_GrantFreeOrbitalBeam()
    if jcms.specialmap_freeOrbitalBeam then return end
    jcms.specialmap_freeOrbitalBeam = true

    jcms.specialmap_beamOriginalCost = jcms.orders.orbitalbeam.cost
    jcms.orders.orbitalbeam.cost = 1
    jcms.net_SendOrder("orbitalbeam", jcms.orders.orbitalbeam)
    for i, ply in ipairs( player.GetAll() ) do
        jcms.orders_ClearCooldown(ply, "orbitalbeam")
    end

    if jcms.arena_data and jcms.arena_data.players then
        jcms.net_SendTip(jcms.arena_data.players, true, "#jcms.arenasoftlock", 0)
    end
end

function jcms.specialmap_RestoreNormalOrbitalBeam()
    if not jcms.specialmap_freeOrbitalBeam then return end
    jcms.specialmap_freeOrbitalBeam = false

    jcms.orders.orbitalbeam.cost = jcms.specialmap_beamOriginalCost or 750
    jcms.net_SendOrder("orbitalbeam", jcms.orders.orbitalbeam)
end

function jcms.specialmap_CustomRespawnFunc(ply)
    ply:Spawn()
end

function jcms.specialmap_TrackNPC(npc)
    if jcms.arena_data then
        table.insert(jcms.arena_data.npcs, npc)

        if jcms.arena_settings and jcms.arena_settings.bountymul then
            npc.jcms_bounty = math.ceil( (npc.jcms_bounty or 0) * jcms.arena_settings.bountymul )
        end

        local enemyData = jcms.npc_types[ npc.jcms_enemyType ]
        if enemyData and enemyData.arenaModeSoftlocker then
            npc.jcms_arenaSoftlocker = true
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
                            local heavyThreshold = 5

                            if jcms.arena_settings then
                                heavyThreshold = math.min( heavyThreshold, math.ceil(jcms.arena_settings.waves / 2) )

                                if jcms.arena_settings.nextwave == "press" and #jcms.arena_data.npcs <= 0 then
                                    heavyThreshold = math.huge
                                end
                            end

                            intensity = jcms.arena_data.wave >= heavyThreshold and INTENSITY_HEAVY or INTENSITY_LIGHT
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

-- Arena Functions {{{

    function jcms.specialmap_BuildArenaSpawnpoints(spawnpoints)
        if not ainReader.nodePositions or not jcms.mapdata.nodeAreas then
            jcms.printf("Re-reading arena nodegraph (first time map launch?)")
            jcms.mapgen_TryReadNodeData()
            if not ainReader.nodePositions or not jcms.mapdata.nodeAreas then
                error("Failed to read the NodeGraph for arena. Try restarting the map.")
                return
            end
        end

        for i, v in ipairs(ainReader.nodePositions) do
            if ainReader.nodeTypes[i] == 2 then
                table.insert(spawnpoints, v)
            end
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

    function jcms.specialmap_GetArenaRespawnPos(ply)
        local arena_settings = assert(jcms.arena_settings, "not in arena")
        local arena_data = assert(jcms.arena_data, "not in arena")

        local rbs = ents.FindByClass("jcms_respawnbeacon")
        if #rbs > 0 then
            local rb = rbs[ math.random(1, #rbs) ]
            if IsValid(rb) then
                rb:DoPostRespawnEffect(ply)
                local pos = rb:GetPos()
                pos.z = pos.z + 6
                return pos, rb:GetAngles()
            end
        end
        
        local arena_x, arena_y, arena_z = arena_settings.pos:Unpack()
        return Vector( arena_x + math.random(-3, 3)*32, arena_y + math.random(-3, 3)*32, arena_z ), Angle(0, math.random(1, 4)*90, 0)
    end

    function jcms.specialmap_StartArena(arena_settings)
        jcms.arena_settings = arena_settings
        jcms.arena_data = { 
            wave = 0, 
            cost = 12 + arena_settings.difficulty * 3,
            costIncreases = 0,
            costIncreaseCountdown = 1,
            respawns = arena_settings.respawns,
            players = table.Copy( arena_settings.players ),
            spawnpoints = table.Copy( arena_settings.spawnpoints ),
            npcs = {},
            npcsToKill = 0,
            killsTotal = 0,
            deathsTotal = 0,
            canProgress = false,
            startedAt = CurTime(),
            lastWaveAt = 0,
            dontThinkUntil = 0,
            lastKillAt = 0
        }

        if arena_settings.nextwave == "press" then
            jcms.specialmap_ArenaSpawnNextButtons()
        end

        game.GetWorld():SetNWString("jcms_missiontype", "arenamode")
        game.GetWorld():SetNWString("jcms_missionfaction", arena_settings.faction)
        game.GetWorld():SetNWInt("jcms_difficulty", jcms.runprogress_GetDifficulty())
        jcms.net_ShareMissionData({}, arena_settings.players)
        jcms.orders_ClearAllCooldowns()

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

    function jcms.specialmap_ArenaSpawnNextButtons()
        local arena_settings = jcms.arena_settings
        local arena_data = jcms.arena_data
        if not (arena_settings and arena_data) then return end
        
        if IsValid(arena_data.nextButton1) then
            arena_data.nextButton1:Remove()
        end

        if IsValid(arena_data.nextButton2) then
            arena_data.nextButton2:Remove()
        end

        local pos1 = Vector(96 + 4, 3632, -383 + 48)
        local pos2 = Vector(-416 - 4, 3632, -383 + 48)

        arena_data.nextButton1 = ents.Create("jcms_terminal")
        arena_data.nextButton1:SetPos( pos1 )
        arena_data.nextButton1:SetAngles( Angle(-8, 0, 0) )
        arena_data.nextButton1:Spawn()
        arena_data.nextButton1:InitAsTerminal("models/props_combine/combinebutton.mdl", "arena_nextwave")
        arena_data.nextButton1.jcms_hackType = nil

        arena_data.nextButton2 = ents.Create("jcms_terminal")
        arena_data.nextButton2:SetPos( pos2 )
        arena_data.nextButton2:SetAngles( Angle(-8, 180, 0) )
        arena_data.nextButton2:Spawn()
        arena_data.nextButton2:InitAsTerminal("models/props_combine/combinebutton.mdl", "arena_nextwave")
        arena_data.nextButton2.jcms_hackType = nil
    end

    function jcms.specialmap_ArenaThinkObjectives()
        local arena_settings = jcms.arena_settings
        local arena_data = jcms.arena_data
        if not (arena_settings and arena_data) then return end

        local objectives = {}

        local difficultyName = "#jcms.arenadifficulty_" .. (arena_settings.difficultyName or "normal")
        if arena_settings.waves >= math.huge then
            table.insert(objectives, { type = "arenawave", format = { arena_data.wave, difficultyName }, progress = 0, total = 0 })
        else
            table.insert(objectives, { type = "arenawave", format = { arena_data.wave, difficultyName }, progress = arena_data.wave, total = arena_settings.waves })
        end
        
        if arena_data.npcsToKill > 0 then
            table.insert(objectives, { type = "j", progress = math.max(0, arena_data.npcsToKill - #arena_data.npcs), total = arena_data.npcsToKill })
        end
        
        local nextwave = arena_settings.nextwave
        if arena_data.wave < arena_settings.waves then
            if nextwave == "15s" or nextwave == "30s" or nextwave == "60s" then
                local time = tonumber( nextwave:sub(1, 2) ) or 15
                local remains = math.ceil( math.max(0, arena_data.lastWaveAt + time - CurTime()) )
                table.insert(objectives, { type = "arenanextwave", progress = remains, style = 1 })
            elseif nextwave == "press" and #arena_data.npcs == 0 then
                table.insert(objectives, { type = "arenapressbutton", progress = 0, total = 0 })

                if not ( IsValid(arena_data.nextButton1) and IsValid(arena_data.nextButton2) ) then
                    jcms.specialmap_ArenaSpawnNextButtons()
                end

                if (arena_data.lastWaveAt > 0) and (CurTime() - arena_data.lastWaveAt >= 5) then
                    local btn = CurTime() % 5 <= 2.5 and arena_data.nextButton1 or arena_data.nextButton2
                    local pos = btn:GetPos()
                    pos.z = pos.z - 16
                    jcms.net_SendLocator(arena_data.players, "arenabtn", "#jcms.obj_arenapressbutton", pos, jcms.LOCATOR_WARNING, 1.5)
                end
            end
        end

        local newHash = util.SHA256( objectives and util.TableToJSON(objectives) or "" )
        if newHash ~= arena_data.objectivesHash then
            arena_data.objectivesHash = newHash
            
            if objectives then
                jcms.net_ShareMissionData(objectives, arena_settings.players)
            end
        end
    end

    function jcms.specialmap_ArenaThinkSoftlock()
        local arena_settings = jcms.arena_settings
        local arena_data = jcms.arena_data
        if not (arena_settings and arena_data) then return end
        if #arena_data.npcs <= 0 then return end

        local allNPCsSoftlock = true
        for i, npc in ipairs(arena_data.npcs) do
            if not npc.jcms_arenaSoftlocker or npc:Health() <= 0 then
                allNPCsSoftlock = false
                break
            end
        end

        local idling = (arena_data.lastKillAt > 0) and (CurTime() - arena_data.lastKillAt > 12)

        local noWayOut = true
        for i, ply in ipairs(arena_data.players) do
            if jcms.orders_CanUse(ply, "orbitalbeam") or jcms.orders_CanUse(ply, "antiairmissile") then
                noWayOut = false
                break
            end
        end

        if allNPCsSoftlock and idling and noWayOut then
            if not jcms.specialmap_freeOrbitalBeam then
                jcms.specialmap_GrantFreeOrbitalBeam()
            end

            for i, ply in ipairs(arena_data.players) do
                if ply:GetNWInt("jcms_cash", 0) < 5 then
                    ply:SetNWInt("jcms_cash", 5)
                end
            end
        end
    end

    function jcms.specialmap_ArenaThink()
        local arena_settings = jcms.arena_settings
        local arena_data = jcms.arena_data
        if not (arena_settings and arena_data) then return end

        for i=#arena_data.players, 1, -1 do
            local ply = arena_data.players[i]

            if ply.jcms_arenaSetToRespawn then
                continue
            end

            if not ( IsValid(ply) and ply:Alive() ) then
                if arena_data.respawns > 0 then
                    ply.jcms_arenaSetToRespawn = true
                    arena_data.respawns = math.max(0, arena_data.respawns - 1)
                else
                    table.remove(arena_data.players, i)
                end
                arena_data.deathsTotal = arena_data.deathsTotal + 1
            end
        end

        local mayThink = not (arena_data.dontThinkUntil and CurTime() < arena_data.dontThinkUntil)

        if mayThink then
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
        end

        if #arena_data.npcs <= 4 and (arena_data.lastKillAt > 0) and (CurTime() - arena_data.lastKillAt > 12) then
            for i, npc in ipairs(arena_data.npcs) do
                jcms.net_SendLocator(arena_data.players, "as"..npc:EntIndex(), "#jcms.arenastraggler", npc, jcms.LOCATOR_GENERIC, 2)
            end
        end

        local performObjectiveThink = false
        if mayThink then
            if #arena_data.players > 0 then
                if (arena_data.wave >= arena_settings.waves) and (arena_settings.waves ~= math.huge) then
                    -- All waves done. We're now just waiting for all NPCs to die
                    if #arena_data.npcs <= 0 then
                        jcms.specialmap_EndArena(true)
                    else
                        performObjectiveThink = true
                    end
                else
                    -- Waves not done but there may be extra conditions depending on the mode we've chosen
                    if jcms.specialmap_ArenaCanProgress(arena_settings, arena_data) then
                        jcms.specialmap_NextWave()
                    end

                    performObjectiveThink = true
                end
            else
                jcms.specialmap_EndArena(false)
            end
        else
            performObjectiveThink = true
        end

        if performObjectiveThink then
            jcms.specialmap_ArenaThinkObjectives()
            jcms.specialmap_ArenaThinkSoftlock()
            game.GetWorld():SetNWInt("jcms_respawncount_1", arena_data.respawns or 0)
        end
    end

    function jcms.specialmap_EndArena(victory)
        local arena_settings = jcms.arena_settings
        local arena_data = jcms.arena_data
        if not (arena_settings and arena_data) then return end
        jcms.specialmap_RestoreNormalOrbitalBeam()

        local arenaString = jcms.specialmap_GetArenaString()
        local arenaProgress = jcms.specialmap_GetArenaProgress()
        local killsString = jcms.util_CashFormat(arena_data.killsTotal)
        game.GetWorld():SetNWInt("jcms_respawncount_1", 0)

        if victory then
            jcms.net_SendTip(arena_data.players, true, "#jcms.arenavictory", arenaProgress, { arenaString, killsString })
        else
            jcms.net_SendTip("all", true, "#jcms.arenafail", arenaProgress, { arenaString, killsString })
            jcms.net_ShareMissionData({}, arena_data.players)
        end

        timer.Simple(3.5, function()
            for i, ply in ipairs(arena_data.players) do
                if IsValid(ply) and ply:Alive() and ply.jcms_inArena then
                    ply:ScreenFade(SCREENFADE.OUT, color_white, 1, 0.5)
                    jcms.net_ShareMissionData({}, ply)
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

                    ply:SetNWInt("jcms_cash", 0)
                    ply:SetHealth( ply:GetMaxHealth() )
                    ply:SetArmor( ply:GetMaxArmor() )
                    ply:RemoveAllAmmo()
                    jcms.util_TryGiveAmmo(ply, 100)
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

        jcms.specialmap_RestoreNormalOrbitalBeam()
        arena_data.lastWaveAt = CurTime()
        arena_data.dontThinkUntil = CurTime() + 5
        arena_data.nextWaveTriggered = nil
        arena_data.wave = arena_data.wave + 1
        arena_data.costIncreaseCountdown = arena_data.costIncreaseCountdown - 1
        if arena_data.costIncreaseCountdown <= 0 then
            arena_data.costIncreases = arena_data.costIncreases + 1
            arena_data.costIncreaseCountdown = 1 + arena_data.costIncreases
            arena_data.cost = math.min(arena_data.cost + 2.5, 100)
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

            if (data.faction == arena_settings.faction or data.faction == "any") and (not data.noArenaMode) and (not data.secretNPC) and (not data.missionSpecific) and (data.danger <= dangerCap) then
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

        local spawnpoints = arena_data.spawnpoints
        table.Shuffle(spawnpoints)

        if #spawnpoints <= 0 then
            table.insert(spawnpoints, arena_settings.pos)
        end

        local navAreas = navmesh.GetAllNavAreas()
        local function spawnAt(npcType, pos)
            local randomPly = arena_data.players[ math.random(1, #arena_data.players) ]
            local randomArea = navAreas[ math.random(1, #navAreas) ]
            local npcData = jcms.npc_types[ npcType ]
            if not npcData then return end
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

        if (#queue <= #spawnpoints) and (arena_data.wave%4 ~= 1) then
            for i, npcType in ipairs(queue) do
                spawnAt(npcType, spawnpoints[i])
            end
        elseif #queue > 0 then
            local npcsSpawned = 0
            local squadCount = math.min(#spawnpoints, math.ceil(#queue / 3) + 1)
            local npcsPerSquad = math.ceil(#queue / squadCount) * 2
            local navAreas = navmesh.GetAllNavAreas()

            for i=1, squadCount do
                local vectors, allFit = jcms.director_PackSquadVectors(spawnpoints[i], npcsPerSquad, math.Rand(90, 105) )

                for j=1, #vectors do
                    local queueIndex = npcsSpawned + j
                    local npcType = queue[ queueIndex ]
                    if npcType then
                        spawnAt(npcType, vectors[j])
                        npcsSpawned = npcsSpawned + 1
                    else
                        break
                    end
                end

                if #vectors <= 0 then
                    spawnAt(npcType, spawnpoints[i])
                    npcsSpawned = npcsSpawned + 1
                end

                if npcsSpawned >= #queue then
                    break
                end
            end
        end

        if dangerCap >= jcms.NPC_DANGER_BOSS then
            jcms.announcer_SpeakChance(0.75, jcms.ANNOUNCER_SWARM_BIG)
        else
            jcms.announcer_SpeakChance(0.45, jcms.ANNOUNCER_SWARM)
        end

        arena_data.npcsToKill = #arena_data.npcs + #queue

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
            prop:SetKeyValue("ItemCount", dangerCap >= jcms.NPC_DANGER_BOSS and 4 or 2)
            prop:Spawn()

            jcms.net_SendLocator(arena_data.players, nil, "#jcms.arenasupplies", prop, jcms.LOCATOR_GENERIC, 10)
        end
    end

-- }}}

-- Building the map {{{
    
    hook.Add("InitPostEntity", "jcms_FiringRangeBuild", function()
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
    end)

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

        if orderId == "respawnbeacon" then
            if jcms.arena_settings and jcms.arena_settings.disablerb then
                jcms.net_SendOrderMessage(ply, 7, "")
                return true
            elseif jcms.arena_data then
                jcms.arena_data.respawns = jcms.arena_data.respawns + 1
            end 
        end
    end)

    hook.Add("OnEntityCreated", "jcms_ArenaNerfs", function(ent)
        if not IsValid(ent) then return end
        local class = ent:GetClass()

        if class == "jcms_turret" then
            timer.Simple(0, function()
                if not IsValid(ent) then return end
                local maxclip = ent:GetTurretMaxClip()
                local clip = ent:GetTurretClip()
                local nerfFactor = 0.1

                maxclip = math.ceil(maxclip * nerfFactor)
                clip = math.min(maxclip, math.ceil(clip * nerfFactor))
                
                ent:SetTurretMaxClip( maxclip )
                ent:SetTurretClip( clip )
            end)
        elseif class == "jcms_tesla" or class == "jcms_shieldcharger" then
            timer.Simple(0, function()
                local maxhp = ent:GetMaxHealth()
                local hp = ent:Health()
                local nerfFactor = 0.4

                maxhp = math.ceil(maxhp * nerfFactor)
                hp = math.min(maxhp, math.ceil(hp * nerfFactor))

                ent:SetMaxHealth(maxhp)
                ent:SetHealth(hp)
            end)
        end
    end)

-- }}}