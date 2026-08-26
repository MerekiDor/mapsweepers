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

-- // Locals {{{

	local function count_remap(i,count, a,b)
		if count == 1 then
			return a
		else
			return math.Remap(i, 1, count, a, b)
		end
	end

-- // }}}

-- // Argument Parser {{{

	jcms.orders_argparser = {
		orbital_fixed = function(ply, args)
			local tr = ply:GetEyeTrace()
			return true, tr.HitPos
		end,

		orbital_fixed_outdoors = function(ply, args) --TODO: Allegedly not usable on skybox
			local tr = ply:GetEyeTrace()

			if tr.HitSky then return true, tr.HitPos - jcms.vectorUp end --Hitting the roof has somewhat wonky behaviour

			local skyPos, _ = jcms.util_GetSky(tr.HitPos)
			if skyPos then
				return true, skyPos - jcms.vectorUp
			else
				jcms.net_SendOrderMessage(ply, 5)
				return false
			end
		end,
		
		orbital_target = function(ply, args)
			local tr = ply:GetEyeTrace()

			if not tr.HitWorld and jcms.team_GoodTarget(tr.Entity) then
				return true, tr.Entity
			else
				jcms.net_SendOrderMessage(ply, 4)
				return false	
			end
		end,

		orbital = function(ply, args)
			local tr = ply:GetEyeTrace()

			if not tr.HitWorld and jcms.team_GoodTarget(tr.Entity) then
				return true, true, tr.Entity
			else
				return true, false, tr.HitPos
			end
		end,

		orbital_cone = function(ply, args)
			local start = ply:EyePos()
			local startAhead = start + ply:EyeAngles():Forward()*40000

			local best, bestHP, bestDist = nil, -1, math.huge
			for _, ent in ents.Iterator() do
				if jcms.team_GoodTarget(ent) and not(ent:IsPlayer() or jcms.team_SameTeam(ply, ent)) then --Still doesn't target vtols due to GoodTarget
					local hp = ent:Health()
					
					if hp > bestHP then
						local entpos = ent:WorldSpaceCenter()
						local threshold = entpos:Distance(start) * 0.25
						local dist, vOnLine = util.DistanceToLine(start, startAhead, entpos)
						if (dist < threshold) and (dist < bestDist) then
							bestHP = hp
							bestDist = dist
							best = ent
						end
					end
				end
			end

			if IsValid(best) then
				return true, best
			else
				jcms.net_SendOrderMessage(ply, 4)
				return false
			end

		end,

		orbital_sphere = function(ply, args)
			local tr = ply:GetEyeTrace()
			local targetPos = tr.HitPos

			local best, bestHP, bestDist = nil, -1, math.huge
			for i, ent in ipairs(ents.FindInSphere(targetPos, 350)) do
				local newHP = ent:Health()
				local newDistance = ent:GetPos():DistToSqr(targetPos)
				if ent:IsNPC() and (newHP > bestHP) or ( newHP == bestHP and newDistance < bestDist)  then
					bestHP = newHP
					bestDist = newDistance
					best = ent
				end
			end

			return true, IsValid(best), best or tr.HitPos
		end,
		
		turret = function(ply, args)
			local maxDist = 300
			local tr = ply:GetEyeTrace()
			
			if tr.StartPos:DistToSqr(tr.HitPos) > maxDist*maxDist then
				jcms.net_SendOrderMessage(ply, 2)
				return false
			end
			
			local flatNormal = Vector(tr.Normal)
			flatNormal.z = 0
			flatNormal:Normalize()
			local angle = flatNormal:Angle()
			
			return true, tr.HitPos, angle
		end,

		turret_static = function(ply, args)
			local maxDist = 300
			local tr = ply:GetEyeTrace()
			
			if not tr.HitWorld then
				jcms.net_SendOrderMessage(ply, 5)
				return false
			end

			if tr.StartPos:DistToSqr(tr.HitPos) > maxDist*maxDist then
				jcms.net_SendOrderMessage(ply, 2)
				return false
			end

			if tr.HitNormal:Dot( jcms.vectorUp ) < 0 then
				jcms.net_SendOrderMessage(ply, 5)
				return false
			end

			local flatNormal = Vector(tr.Normal)
			flatNormal.z = 0
			flatNormal:Normalize()
			local angle = flatNormal:Angle()
			
			return true, tr.HitPos, angle
		end,

		turret_static_attach = function(ply, args)
			local maxDist = 300
			local tr = ply:GetEyeTrace()
			
			if not tr.HitWorld then
				jcms.net_SendOrderMessage(ply, 5)
				return false
			end

			if tr.StartPos:DistToSqr(tr.HitPos) > maxDist*maxDist then
				jcms.net_SendOrderMessage(ply, 2)
				return false
			end

			local angle = tr.HitNormal:Angle()
			angle:RotateAroundAxis( angle:Right(), -90 )
			
			return true, tr.HitPos, angle
		end,

		respawn_beacon = function(ply, args)
			local maxDist = 300
			local tr = ply:GetEyeTrace()
			
			if not tr.HitWorld then 
				jcms.net_SendOrderMessage(ply, 5)
				return false
			end

			if tr.StartPos:DistToSqr(tr.HitPos) > maxDist*maxDist then
				jcms.net_SendOrderMessage(ply, 2)
				return false
			end

			if tr.HitNormal:Dot( jcms.vectorUp ) < 0.5 then
				jcms.net_SendOrderMessage(ply, 5)
				return false
			end

			local flatNormal = Vector(tr.Normal)
			flatNormal.z = 0
			flatNormal:Normalize()
			local angle = flatNormal:Angle()

			local tr2 = util.TraceHull {
				mins = Vector(-16, -16, 0), maxs = Vector(16, 16, 72),
				mask = MASK_PLAYERSOLID, start = tr.HitPos, endpos = tr.HitPos + Vector(0, 0, 8)
			}

			if tr2.Hit then
				jcms.net_SendOrderMessage(ply, 3)
				return false 
			end

			return true, tr.HitPos, angle
		end,

		vehicle = function(ply, args)
			local maxDist = 450
			local tr = ply:GetEyeTrace()
			
			if not tr.HitWorld then
				jcms.net_SendOrderMessage(ply, 5)
				return false
			end

			if tr.StartPos:DistToSqr(tr.HitPos) > maxDist*maxDist then
				jcms.net_SendOrderMessage(ply, 2)
				return false
			end

			if tr.HitNormal:Dot( jcms.vectorUp ) < 0.5 then
				jcms.net_SendOrderMessage(ply, 3)
				return false
			end

			local flatNormal = Vector(tr.Normal)
			flatNormal.z = 0
			flatNormal:Normalize()
			local angle = flatNormal:Angle()

			local tr2 = util.TraceHull {
				mins = Vector(-130, -130, 10), maxs = Vector(130, 130, 130),
				mask = MASK_PLAYERSOLID, start = tr.HitPos, endpos = tr.HitPos + Vector(0, 0, 8)
			}

			if tr2.Hit then
				jcms.net_SendOrderMessage(ply, 3)
				return false 
			end

			return true, tr.HitPos, angle
		end,
		
		mine = function(ply, args)
			local maxDist = 300
			local tr = ply:GetEyeTrace()
			
			if tr.StartPos:DistToSqr(tr.HitPos) > maxDist*maxDist then
				jcms.net_SendOrderMessage(ply, 2)
				return false
			end
			
			local ang = tr.HitNormal:Angle()
			ang:RotateAroundAxis(ang:Right(), -90)
			
			return true, tr.HitPos + tr.HitNormal, ang, tr.Entity, tr
		end
	}

-- // }}}

-- // Orders {{{

	jcms.orders = {
		-- Turrets
		turret_smg = {
			category = jcms.SPAWNCAT_TURRETS,
			cost = 350,
			cooldown = 10,
			argparser = "turret",
			slotPos = 1,
			func = function(ply, pos, angle) jcms.spawnmenu_Turret("smg", ply, pos, angle) end
		},
		
		turret_bolter = {
			category = jcms.SPAWNCAT_TURRETS,
			cost = 600,
			cooldown = 20,
			argparser = "turret",
			slotPos = 2,
			func = function(ply, pos, angle) jcms.spawnmenu_Turret("bolter", ply, pos, angle) end
		},
		
		turret_shotgun = {
			category = jcms.SPAWNCAT_TURRETS,
			cost = 550,
			cooldown = 15,
			argparser = "turret",
			slotPos = 3,
			func = function(ply, pos, angle) jcms.spawnmenu_Turret("shotgun", ply, pos, angle) end
		},
		
		turret_gatling = {
			category = jcms.SPAWNCAT_TURRETS,
			cost = 950,
			cooldown = 30,
			argparser = "turret",
			slotPos = 4,
			func = function(ply, pos, angle) jcms.spawnmenu_Turret("gatling", ply, pos, angle) end
		},
		
		turret_smrls = {
			category = jcms.SPAWNCAT_TURRETS,
			cost = 1100,
			cooldown = 45,
			argparser = "turret_static_attach",
			slotPos = 5,
			func = function(ply, pos, angle) 
				local turret = ents.Create("jcms_turret_smrls")
				turret:SetPos(pos)
				turret:SetAngles(angle)
				turret:Spawn()

				if IsValid(ply) and jcms.isPlayerEngineer(ply) then
					turret:SetupBoosted()
				end

				if IsValid(ply) then
					turret:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(turret)

				local ed = EffectData()
				ed:SetColor(jcms.util_GetColorIntegerPvP(ply))
				ed:SetFlags(0)
				ed:SetEntity(turret)
				util.Effect("jcms_spawneffect", ed)
				turret.jcms_owner = ply

				jcms.npc_UpdateRelations(turret)
				turret:EmitSound("npc/roller/blade_cut.wav", 75, 90)

				if CPPI then
					turret:CPPISetOwner( game.GetWorld() )
				end
			end
		},
		
		-- Orbitals
		carpetbombing = {
			category = jcms.SPAWNCAT_ORBITALS,
			cost = 300,
			cooldown = 60,
			slotPos = 1,
			argparser = "orbital_fixed",
			func = function(ply, pos)
				local dif = pos - ply:GetPos()
				dif:Normalize()
				dif.z = 0
				dif:Mul(1000)
				
				jcms.net_SendLocator("all", nil, "#jcms.carpetbombing", pos, jcms.LOCATOR_TIMED, 2.5)

				jcms.spawnmenu_Airstrike {
					pos = pos - dif,
					pos2 = pos + dif,
					
					delay = { 0.05, 0.09 },
					arrival = 2.5,
					count = 20,
					
					radius = 500,
					radius2 = 600,
					
					blast_radius = 400,
					blast_damage = 100,
					callback = function(bomb)
						bomb.jcms_owner = ply
					end
				}
				
				jcms.util_JetSound(pos)
				jcms.net_NotifyGeneric(ply, jcms.NOTIFY_ORDERED, "#jcms.carpetbombing")
			end
		},
		
		shelling = {
			category = jcms.SPAWNCAT_ORBITALS,
			cost = 450,
			cooldown = 90,
			slotPos = 2,
			argparser = "orbital_fixed",
			func = function(ply, pos)
				local deviate = VectorRand(-200, 200)
				deviate.z = 0
				
				local arrival = math.Rand(2, 5)
				local count = jcms.isPlayerEngineer(ply) and 50 or 60

				jcms.net_SendLocator("all", nil, "#jcms.shelling", pos, jcms.LOCATOR_WARNING, 5)

				local blast_radius = 400
				local blast_damage = 150
				local pvpTeam = ply:GetNWInt("jcms_pvpTeam", -1)
				if pvpTeam == -1 then pvpTeam = 1 end --Default 1 to work with normal mode.

				local function shootFunc(bomb_pos, norm, length, i, count, timeToDrop)
					local tr = util.TraceLine {
						start = bomb_pos, endpos = bomb_pos + norm * (length + 1024),
						mask = MASK_PLAYERSOLID_BRUSHONLY
					}

					local ed = EffectData()
					ed:SetStart(tr.StartPos)
					ed:SetOrigin(tr.HitPos)
					ed:SetFlags(3)
					ed:SetMagnitude(1.5)
					ed:SetMaterialIndex(pvpTeam)
					util.Effect("jcms_bolt", ed)

					timer.Simple(1.5, function()
						local dmg = DamageInfo()
						if IsValid(ply) then
							dmg:SetInflictor(ply)
							dmg:SetAttacker(ply)
						else
							dmg:SetInflictor(game.GetWorld())
							dmg:SetAttacker(game.GetWorld())
						end
						dmg:SetDamage(blast_damage)
						dmg:SetDamageType(DMG_BLAST)
						dmg:SetReportedPosition(tr.StartPos)
						dmg:SetDamagePosition(tr.HitPos)
						util.BlastDamageInfo(dmg, tr.HitPos, blast_radius)
						util.ScreenShake(tr.HitPos, 10, 30, math.Rand(0.4, 0.7), blast_radius*2, false)
					end)

					sound.EmitHint(SOUND_DANGER, tr.HitPos, blast_radius*2, 1.5)
				end

				jcms.spawnmenu_Airstrike {
					pos = pos,
					pos2 = pos + deviate,
					
					delay = {0.65, 1.61},
					arrival = arrival,
					count = count,
					
					radius = 700,
					radius2 = 2200,

					shootFunc = shootFunc
				}

				jcms.announcer_SpeakChance(0.2, jcms.ANNOUNCER_SHELLING)
				jcms.net_NotifyGeneric(ply, jcms.NOTIFY_ORDERED, "#jcms.shelling")
			end
		},

		antiairmissile = {
			category = jcms.SPAWNCAT_ORBITALS,
			cost = 250,
			cooldown = 15,
			slotPos = 6,
			argparser = "orbital_cone",
			func = function(ply, target)
				local skyPos = jcms.util_GetSky(target:GetPos())
				
				if skyPos then
					skyPos.z = skyPos.z - 128
					jcms.net_SendLocator("all", nil, "#jcms.antiairmissile", target, jcms.LOCATOR_WARNING, 5)

					local missile = ents.Create("jcms_micromissile")
					missile:SetPos(skyPos)
					missile.Damage = 1250
					missile.Radius = 100
					missile.Proximity = 45
					missile.Target = target
					missile.jcms_owner = ply
					missile.AntiAir = true
					missile:SetBlinkColor(Vector(1, 0, 0))
					missile:Spawn()
					
					jcms.util_JetSound(target:GetPos())
					jcms.net_NotifyGeneric(ply, jcms.NOTIFY_ORDERED, "#jcms.antiairmissile")
				end
			end
		},
		
		orbitalbeam = {
			category = jcms.SPAWNCAT_ORBITALS,
			cost = 750,
			cooldown = 120,
			slotPos = 3,
			argparser = "orbital_fixed_outdoors",
			func = function(ply, pos)
				local beam = ents.Create("jcms_deathraycontroller")

				local rad = 32

				beam.Speed = 350
				beam.beamRadius = rad
				beam:SetPos(pos)
				beam:Spawn()
				beam.jcms_owner = ply
				
				beam.deathRay.DPS = 90
				beam.deathRay.DPS_DIRECT = 160
				beam.deathRay:SetBeamRadius(rad)
				beam.deathRay:SetBeamColour( jcms.util_GetPVPVectorColor(ply) )
				beam.deathRay.jcms_owner = ply

				beam.IsIdleUntilActive = jcms.util_IsPVP()

				jcms.announcer_SpeakChance(0.2, jcms.ANNOUNCER_ORBITALBEAM)
				jcms.net_NotifyGeneric(ply, jcms.NOTIFY_ORDERED, "#jcms.orbitalbeam")
			end
		},

		smoke = {
			category = jcms.SPAWNCAT_ORBITALS,
			cost = 150,
			cooldown = 30,
			slotPos = 5,
			argparser = "orbital_fixed",
			pvpExclusive = true,

			func = function(ply, pos)
				local dif = pos - ply:GetPos()
				dif:Normalize()
				dif.z = 0
				local right = dif:Angle():Right()
				right:Mul(300)
				
				jcms.net_SendLocator("all", nil, "#jcms.smoke", pos, jcms.LOCATOR_TIMED, 2.5)

				jcms.spawnmenu_Airstrike {
					model = "models/props_junk/propane_tank001a.mdl",
					pos = pos - right,
					pos2 = pos + right,
					
					delay = { 0.1, 0.25 },
					arrival = 2,
					count = 5,
					
					radius = 300,
					radius2 = 350,
					
					callback = function(bomb)
						bomb.jcms_owner = ply
						bomb:GetPhysicsObject():EnableDrag(false)

						bomb:CallOnRemove( "jcms_smokeburst", function()
							bomb:EmitSound("weapons/flaregun/fire.wav", 120, 80)
							local ed = EffectData()
							ed:SetMagnitude(20)
							ed:SetOrigin(bomb:WorldSpaceCenter())
							ed:SetNormal(bomb:GetAngles():Up())
							ed:SetRadius(350)
							ed:SetFlags(3)
							util.Effect("jcms_blast", ed)
							ed:SetColor(jcms.util_ColorInteger(Color(200, 200, 200, 255)))
							
							if jcms.smokeScreens then
								table.insert(jcms.smokeScreens, { pos = bomb:WorldSpaceCenter(), rad = 340, expires = CurTime() + 19 }) 
							end
						end)
					end
				}
				
				jcms.util_JetSound(pos)
				jcms.net_NotifyGeneric(ply, jcms.NOTIFY_ORDERED, "#jcms.smoke")
			end
		},
		
		-- Mobility
		jumppad = {
			category = jcms.SPAWNCAT_MOBILITY,
			cost = 150,
			cooldown = 10,
			slotPos = 1,
			argparser = "turret_static",
			func = function(ply, pos, angle)
				local pad = ents.Create("jcms_jumppad")
				pad:SetPos(pos)
				pad:Spawn()
				
				pad:SetAngles(angle)
				local mins = pad:OBBMins()
				mins.x = 0
				mins.y = 0
				mins.z = -mins.z
				pad:SetPos(pos + mins)
				pad.jcms_owner = ply

				if IsValid(ply) then
					pad:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(pad)

				local ed = EffectData()
				ed:SetColor(jcms.util_GetColorIntegerPvP(ply))
				ed:SetFlags(0)
				ed:SetEntity(pad)
				util.Effect("jcms_spawneffect", ed)

				if CPPI then
					pad:CPPISetOwner( game.GetWorld() )
				end

				return pad
			end
		},
		
		vtol = {
			category = jcms.SPAWNCAT_MOBILITY,
			cost = 1200,
			cooldown = 300,
			slotPos = 2,
			argparser = "vehicle",
			
			func = function(ply, pos, angle)
				local vtol = ents.Create("jcms_vtol")
				vtol:SetPos(pos)
				vtol:Spawn()
				
				vtol:SetAngles(angle)
				local mins = vtol:OBBMins()
				mins.x = 0
				mins.y = 0
				mins.z = -mins.z
				vtol:SetPos(pos + mins)
				vtol.jcms_owner = ply

				if IsValid(ply) then
					vtol:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(vtol)

				local ed = EffectData()
				ed:SetColor(jcms.util_GetColorIntegerPvP(ply))
				ed:SetFlags(0)
				ed:SetEntity(vtol)
				util.Effect("jcms_spawneffect", ed)

				if CPPI then
					vtol:CPPISetOwner( game.GetWorld() )
				end
			end
		},

		apc = {
			category = jcms.SPAWNCAT_MOBILITY,
			cost = 600,
			cooldown = 600,
			slotPos = 3,
			argparser = "vehicle",
			
			func = function(ply, pos, angle)
				local apc = ents.Create("jcms_apc")
				apc:SetPos(pos)
				apc:Spawn()
				
				apc:SetAngles(angle)
				local mins = apc:OBBMins()
				mins.x = 0
				mins.y = 0
				mins.z = -mins.z
				apc:SetPos(pos + mins)
				apc.jcms_owner = ply

				if IsValid(ply) then
					apc:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(apc)

				local ed = EffectData()
				ed:SetColor(jcms.util_GetColorIntegerPvP(ply))
				ed:SetFlags(0)
				ed:SetEntity(apc)
				util.Effect("jcms_spawneffect", ed)

				if CPPI then
					apc:CPPISetOwner( game.GetWorld() )
				end
			end
		},

		hovertank = {
			category = jcms.SPAWNCAT_MOBILITY,
			cost = 4000,
			cooldown = 600,
			slotPos = 4,
			argparser = "vehicle",
			
			func = function(ply, pos, angle)
				local tank = ents.Create("jcms_tank")
				tank:SetPos(pos)
				if IsValid(ply) then
					tank:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				tank:Spawn()
				jcms.util_TryUpdateForPVP(tank)
				
				tank:SetAngles(angle)
				local mins = tank:OBBMins()
				mins.x = 0
				mins.y = 0
				mins.z = -mins.z
				tank:SetPos(pos + mins)
				tank.jcms_owner = ply

				local ed = EffectData()
				ed:SetColor(jcms.util_GetColorIntegerPvP(ply))
				ed:SetFlags(0)
				ed:SetEntity(tank)
				util.Effect("jcms_spawneffect", ed)

				if CPPI then
					tank:CPPISetOwner( game.GetWorld() )
				end
			end
		},

		-- Supplies
		firstaid = {
			category = jcms.SPAWNCAT_SUPPLIES,
			cost = 500,
			cooldown = 300,
			slotPos = 2,
			argparser = "orbital_fixed",
			
			func = function(ply, pos)
				local teamInt = -1
				local faction = "jcorp"
				if IsValid(ply) then
					teamInt = ply:GetNWInt("jcms_pvpTeam", -1)
					faction = jcms.util_GetFactionNamePVP(ply)
				end

				local col
				if faction == "mafia" then
					col = Color(193, 255, 79)
				else
					col = Color(96, 255, 124)
				end

				local crate, flare = jcms.spawnmenu_Airdrop(pos, "jcms_restock", 10, "#jcms.firstaid", col, ply)
				crate:SetAmmoCashInside( 0 )
				crate:SetHealthInside( 100 )
				crate:SetOwnerNickname( ply:Nick() )
				crate:SetLocalAngularVelocity( AngleRand(48, 128) )
				crate:SetMaterial("models/jcms/"..faction.."_crate_heal")
				crate:SetColor(col)
				crate:SetNWInt("jcms_pvpTeam", teamInt)

				jcms.announcer_SpeakChance(0.4, jcms.ANNOUNCER_SUPPLIES)
				jcms.net_NotifyGeneric(ply, jcms.NOTIFY_ORDERED, "#jcms.firstaid")
				if CPPI then
					crate:CPPISetOwner( game.GetWorld() )
				end
			end
		},
		
		restock = {
			category = jcms.SPAWNCAT_SUPPLIES,
			cost = 300,
			cooldown = 90,
			slotPos = 1,
			argparser = "orbital_fixed",
			
			func = function(ply, pos, angle)
				local teamInt = -1
				local faction = "jcorp"
				if IsValid(ply) then
					teamInt = ply:GetNWInt("jcms_pvpTeam", -1)
					faction = jcms.util_GetFactionNamePVP(ply)
				end

				local col
				if faction == "mafia" then
					col = Color(238, 255, 0)
				else
					col = Color(255, 0, 0)
				end

				local crate, flare = jcms.spawnmenu_Airdrop(pos, "jcms_restock", 10, "#jcms.restock", col, ply)
				crate:SetAmmoCashInside( 400 )
				crate:SetHealthInside( 0 )
				crate:SetOwnerNickname( ply:Nick() )
				crate:SetLocalAngularVelocity( AngleRand(48, 128) )
				crate:SetMaterial("models/jcms/"..faction.."_crate_ammo")
				crate:SetColor(col)
				crate:SetNWInt("jcms_pvpTeam", teamInt)

				jcms.announcer_SpeakChance(0.4, jcms.ANNOUNCER_SUPPLIES_AMMO)
				jcms.net_NotifyGeneric(ply, jcms.NOTIFY_ORDERED, "#jcms.restock")
				if CPPI then
					crate:CPPISetOwner( game.GetWorld() )
				end
			end
		},

		antirad = {
			category = jcms.SPAWNCAT_SUPPLIES,
			cost = 300,
			cooldown = 5 * 60,
			slotPos = 3,
			pvpExclusive = true,
			argparser = "orbital_fixed",
			
			func = function(ply, pos)
				local teamInt = -1
				local faction = "jcorp"
				if IsValid(ply) then
					teamInt = ply:GetNWInt("jcms_pvpTeam", -1)
					faction = jcms.util_GetFactionNamePVP(ply)
				end

				local col
				if faction == "mafia" then
					col = Color(193, 255, 79)
				else
					col = Color(96, 255, 124)
				end

				local crate, flare = jcms.spawnmenu_Airdrop(pos, "jcms_restock", 2, "#jcms.antirad", col, ply)
				crate:SetAmmoCashInside( 0 )
				crate:SetHealthInside( 0 )
				crate:SetAntiradInside( 90 )
				crate:SetOwnerNickname( ply:Nick() )
				crate:SetLocalAngularVelocity( AngleRand(48, 128) )
				crate:SetMaterial("models/jcms/"..faction.."_crate_heal")
				crate:SetColor(col)
				crate:SetNWInt("jcms_pvpTeam", teamInt)

				jcms.announcer_SpeakChance(0.4, jcms.ANNOUNCER_SUPPLIES)
				jcms.net_NotifyGeneric(ply, jcms.NOTIFY_ORDERED, "#jcms.antirad")
				if CPPI then
					crate:CPPISetOwner( game.GetWorld() )
				end
			end
		},
		
		-- Mines
		mine_multiblast = {
			category = jcms.SPAWNCAT_MINES,
			cost = 100,
			cooldown = 10,
			slotPos = 1,
			argparser = "mine",
			
			func = function(ply, pos, angle, attachEnt, traceResult)
				local mine = ents.Create("jcms_landmine")
				mine:SetPos(pos)
				mine:SetAngles(angle)
				mine:SetBlinkScale(1.5)
				mine:SetBlinkPeriod(0.72)
				
				mine.Radius = 170
				mine.Damage = 100
				mine.BlastCount = jcms.isPlayerEngineer(ply) and 4 or 5
				mine.BlastCooldown = 1.5
				mine.RequiredTargets = 1
				mine.Proximity = 120
				mine.jcms_owner = ply
				if IsValid(ply) then
					mine:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(mine)

				mine:Spawn()
				
				constraint.Weld(mine, attachEnt, 0, 0)
				if (attachEnt:IsNPC() or attachEnt:IsNextBot()) then
					mine:Detach()
				end

				if CPPI then
					mine:CPPISetOwner( game.GetWorld() )
				end
			end
		},
		
		mine_c4 = {
			category = jcms.SPAWNCAT_MINES,
			cost = 200,
			cooldown = 40,
			slotPos = 4,
			argparser = "mine",
			
			func = function(ply, pos, angle, attachEnt, traceResult)
				local mine = ents.Create("jcms_landmine")
				mine:SetPos(pos)
				angle:RotateAroundAxis(angle:Up(),180 + math.Rand(-0.5, 0.5)*20)
				mine:SetAngles(angle)
				
				mine.Radius = 523
				mine.Damage = 750
				mine.BlastCount = 1
				mine.BlastCooldown = 1
				mine.RequiredTargets = 9999
				mine.DestroysBuildings = true
				mine.Proximity = 0
				mine.Expires = 10
				mine.jcms_owner = ply
				mine:Spawn()
				mine:SetModel("models/weapons/w_c4_planted.mdl")
				mine:PhysicsInit(SOLID_VPHYSICS)
				mine:SetColor(Color(255, 255, 255))
				constraint.Weld(mine, attachEnt, 0, 0)

				if IsValid(ply) then
					mine:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(mine)

				mine:SetAngles(angle)
				mine:SetBlinkScale(1.5)
				mine:SetBlinkPeriod(1)

				timer.Simple(mine.Expires/2, function() -- Flash faster
					if IsValid(mine) then 
						mine:SetBlinkPeriod(0.5)
						mine:SetBlinkScale(2)
					end
				end)

				timer.Simple(mine.Expires - 1, function()
					if IsValid(mine) then 
						mine:SetBlinkPeriod(0.25)
						mine:SetBlinkScale(3)
					end
				end)
				
				jcms.net_SendLocator("all", nil, "#jcms.mine_c4", mine, jcms.LOCATOR_TIMED, 10, nil, ply)

				if CPPI then
					mine:CPPISetOwner( game.GetWorld() )
				end
			end
		},
		
		mine_breach = {
			category = jcms.SPAWNCAT_MINES,
			cost = 100,
			cooldown = 10,
			slotPos = 3,
			argparser = "mine",
			
			func = function(ply, pos, angle, attachEnt, traceResult)
				local mine = ents.Create("jcms_landmine")
				mine:SetPos(pos)
				mine:SetAngles(angle)
				
				mine.Radius = 10
				mine.Damage = 75
				mine.BlastCount = 1
				mine.BlastCooldown = 1
				mine.RequiredTargets = 9999
				mine.Proximity = 0
				mine.Expires = 1
				mine.PushOwnerForce = 350000
				mine.BreachDoors = true
				mine.jcms_owner = ply
				mine:Spawn()
				mine:SetModel("models/props_combine/combine_mine01.mdl")
				mine:SetModelScale(0.25)
				mine:PhysicsInit(SOLID_VPHYSICS)
				mine:SetColor( ((IsValid(ply) and ply:GetNWInt("jcms_pvpTeam", -1) == 2) and Color(241, 212, 14)) or Color(255, 32, 32) )

				if IsValid(ply) then
					mine:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(mine)

				mine:SetBlinkScale(0.25)
				mine:SetBlinkPeriod(0.25)

				mine.jcms_weldedTo = attachEnt
				constraint.Weld(mine, attachEnt, 0, 0, 0, true)

				if CPPI then
					mine:CPPISetOwner( game.GetWorld() )
				end

				return mine --todo: For all orders. Also make the way I'm doing this a bit less Jank.
			end
		},
		
		-- Defensives
		shieldcharger = {
			category = jcms.SPAWNCAT_DEFENSIVE,
			cost = 650,
			cooldown = 90,
			slotPos = 2,
			argparser = "turret_static",
			
			func = function(ply, pos, angle)
				local boosted = jcms.isPlayerEngineer(ply)
				local shieldcharger = ents.Create("jcms_shieldcharger")
				shieldcharger:SetPos(pos)
				shieldcharger:SetAngles(angle)
				if IsValid(ply) then
					shieldcharger:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(shieldcharger)
				shieldcharger:Spawn()
				
				if boosted then
					shieldcharger:SetChargeRadius(750)
					shieldcharger:SetMaxHealth( shieldcharger:Health() * 1.5 )
					shieldcharger:SetHealth( shieldcharger:GetMaxHealth() )
				end
				
				local ed = EffectData()
				ed:SetColor(jcms.util_GetColorIntegerPvP(ply))
				ed:SetFlags(0)
				ed:SetEntity(shieldcharger)
				util.Effect("jcms_spawneffect", ed)

				if CPPI then
					shieldcharger:CPPISetOwner( game.GetWorld() )
				end
			end
		},

		tesla = {
			category = jcms.SPAWNCAT_DEFENSIVE,
			cost = 300,
			cooldown = 45,
			slotPos = 1,
			argparser = "turret_static",
			
			func = function(ply, pos, angle)
				local boosted = jcms.isPlayerEngineer(ply)
				local tesla = ents.Create("jcms_tesla")
				tesla:SetPos(pos + Vector(0,0,20))
				tesla:SetAngles(angle)
				tesla.jcms_owner = ply
				if IsValid(ply) then
					tesla:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(tesla)

				if boosted then
					tesla.Radius = 550
					tesla.FireRate = 0.2
					tesla:SetMaxHealth( tesla:Health() * 1.5 )
					tesla:SetHealth( tesla:GetMaxHealth() )
				end
				
				tesla:Spawn()
				
				local ed = EffectData()
				ed:SetColor(jcms.util_GetColorIntegerPvP(ply))
				ed:SetFlags(0)
				ed:SetEntity(tesla)
				util.Effect("jcms_spawneffect", ed)

				if CPPI then
					tesla:CPPISetOwner( game.GetWorld() )
				end
			end
		},

		-- Utility
		respawnbeacon = {
			category = jcms.SPAWNCAT_UTILITY,
			cost = 1000,
			cooldown = 240,
			slotPos = 1,
			argparser = "respawn_beacon",
			pvpBlacklisted = true,
			
			func = function(ply, pos, angle)
				local beacon = ents.Create("jcms_respawnbeacon")
				beacon:SetPos(pos)
				beacon:SetAngles(angle)
				beacon:Spawn()
				
				local ed = EffectData()
				ed:SetColor(jcms.util_GetColorIntegerPvP(ply))
				ed:SetFlags(0)
				ed:SetEntity(beacon)
				util.Effect("jcms_spawneffect", ed)
				
				beacon:EmitSound("npc/roller/blade_cut.wav", 75, 100)

				if CPPI then
					beacon:CPPISetOwner( game.GetWorld() )
				end
				
				if IsValid(ply) then
					beacon:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(beacon)
			end
		},
		
		autohacker = {
			category = jcms.SPAWNCAT_UTILITY,
			cost = 500,
			cooldown = 160,
			slotPos = 2,
			argparser = "mine",
			
			func = function(ply, pos, angle, attachEnt, traceResult)
				local boosted = jcms.isPlayerEngineer(ply)
				local device = ents.Create("jcms_sapper")
				angle:RotateAroundAxis(angle:Right(), 90 + math.Rand(-0.5, 0.5)*20)
				device:SetPos(pos)
				device:SetAngles(angle)
				device.jcms_owner = ply
				device:Spawn()
				device:SetupDevice("autohacker", attachEnt, boosted)
				constraint.Weld(device, attachEnt, 0, 0)

				if IsValid(ply) then
					device:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(device)
				
				if CPPI then
					device:CPPISetOwner( game.GetWorld() )
				end
			end
		},
		
		locator = {
			category = jcms.SPAWNCAT_UTILITY,
			cost = 100,
			cooldown = 20,
			slotPos = 3,
			argparser = "mine",
			
			func = function(ply, pos, angle, attachEnt, traceResult)
				local boosted = jcms.isPlayerEngineer(ply)

				local device = ents.Create("jcms_sapper")
				angle:RotateAroundAxis(angle:Right(), 90 + math.Rand(-0.5, 0.5)*20)
				device:SetPos(pos)
				device:SetAngles(angle)
				device.jcms_owner = ply
				device:Spawn()
				device:SetupDevice("locator", attachEnt, boosted)
				constraint.Weld(device, attachEnt, 0, 0)

				if IsValid(ply) then
					device:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
				end
				jcms.util_TryUpdateForPVP(device)

				if CPPI then
					device:CPPISetOwner( game.GetWorld() )
				end
			end
		},
	}
	
	jcms.orders_lastused = {}
	
	function jcms.orders_Hash()
		return jcms.util_Hash(jcms.orders)
	end
	
	function jcms.orders_CanUse(ply, orderId)
		local orderData = jcms.orders[ orderId ]
		if orderData then
			local costMult, coolDownMult = jcms.class_GetCostMultipliers(jcms.class_GetData(ply), orderData)
			local cost = orderData.cost_override or orderData.cost
			local isPvp = jcms.util_IsPVP()
			if cost <= 0 or (isPvp and orderData.pvpBlacklisted) or (not isPvp and orderData.pvpExclusive)  then
				return false, 0
			end

			local cooldown = orderData.cooldown_override or orderData.cooldown

			if ply:GetNWInt("jcms_cash") < math.ceil(cost*costMult) then 
				return false, 1, ("%d / %d"):format(ply:GetNWInt("jcms_cash", 0), math.ceil(cost*costMult))
			end
			
			if not jcms.orders_lastused[orderId] then return true end
			local id = ply:SteamID64()
			local lastUse = jcms.orders_lastused[orderId][id]
			if not lastUse then return true end

			local timeSinceUse = CurTime() - lastUse
			local cooldown = math.ceil(cooldown*coolDownMult)
			return timeSinceUse >= cooldown, 6, math.floor(cooldown - timeSinceUse)
		end
	end
	
	function jcms.orders_ForceUse(ply, orderId, ...)
		local orderData = assert(jcms.orders[ orderId ], "unknown order '"..tostring(orderId).."'")
		
		local costMult, coolDownMult = jcms.class_GetCostMultipliers(jcms.class_GetData(ply), orderData)
		local cost = orderData.cost_override or orderData.cost
		local cooldown = orderData.cooldown_override or orderData.cooldown

		ply:SetNWInt("jcms_cash", ply:GetNWInt("jcms_cash") - math.ceil(cost*costMult))
		jcms.orders_SetCooldown(ply, orderId, math.ceil(cooldown*coolDownMult))
		orderData.func(ply, ...)

		jcms.statistics_AddOther(ply, "orders", 1)
	end
	
	function jcms.orders_SetCooldown(ply, orderId, cooldown)
		if jcms.orders[ orderId ] then
			if not jcms.orders_lastused[ orderId ] then
				jcms.orders_lastused[ orderId ] = {}
			end
			
			local id = ply:SteamID64()
			
			jcms.orders_lastused[ orderId ][ id ] = CurTime()
			jcms.net_SendOrderCooldown(ply, orderId, tonumber(cooldown) or 0)
		end
	end

	function jcms.orders_ClearCooldown(ply, orderId)
		if jcms.orders[ orderId ] then
			if not jcms.orders_lastused[ orderId ] then
				jcms.orders_lastused[ orderId ] = {}
			end

			local id = ply:SteamID64()
			jcms.orders_lastused[ orderId ][ id ] = nil
			jcms.net_SendOrderCooldown(ply, orderId, 0)
		end
	end
	
	function jcms.orders_ClearAllCooldowns()
		table.Empty(jcms.orders_lastused)
		
		for i, ply in ipairs( player.GetHumans() ) do
			jcms.net_SendOrderClearCooldowns(ply)
		end
	end

	if not jcms.specialmap_dontUseOrderOverrides then
		local orderOverridesFile = "mapsweepers/server/order_overrides.json"
		hook.Add("InitPostEntity", "jcms_OrderOverrides", function(ply)
			if file.Exists(orderOverridesFile, "DATA") then
				local json = file.Read(orderOverridesFile, "DATA")

				if json then
					local success, rtn = pcall(util.JSONToTable, json)
					if success and type(rtn) == "table" then
						for orderId, override in pairs(rtn) do
							local orderData = jcms.orders[orderId]
							if orderData then
								if type(override.cost) == "number" and override.cost ~= orderData.cost then
									jcms.orders[orderId].cost_override = math.Clamp(override.cost, 0, 16777215)
								end

								if type(override.cooldown) == "number" and override.cooldown ~= orderData.cooldown then
									jcms.orders[orderId].cooldown_override = math.Clamp(override.cooldown, 0, 4095)
								end

								if override.cost == 0 then
									jcms.net_RemoveOrder(orderId)
								else
									jcms.net_SendOrder(orderId, orderData)
								end
							end
						end
					end
				end
			end
		end)

		hook.Add("ShutDown", "jcms_SaveOrderOverrides", function()
			local overrides = {}

			for orderId, orderData in pairs(jcms.orders) do
				if orderData.cost_override or orderData.cooldown_override then
					overrides[ orderId ] = {
						cost = tonumber(orderData.cost_override),
						cooldown = tonumber(orderData.cooldown_override)
					}
				end
			end

			if next(overrides) then
				local success, rtn = pcall(util.TableToJSON, overrides, true)
				if success and rtn then
					success = file.Write(orderOverridesFile, rtn)

					if success then
						jcms.printf("Saving order overrides to '%s'.", orderOverridesFile)
					else
						jcms.printf("Failed to save order overrides. Error: %s", tostring(rtn))
					end
				else
					jcms.printf("Failed to save order overrides, bad data!")
				end
			else
				file.Delete(orderOverridesFile, "DATA")
			end
		end)
	end

-- // }}}

-- // Basics {{{

	function jcms.spawnmenu_GetValidatedLoadout(ply, loadout, gunPriceMul, ammoPriceMul)
		gunPriceMul = gunPriceMul or 1
		ammoPriceMul = ammoPriceMul or 1
		local vq = {}
		
		local counts = {}
		local classes = {}
		local gunstats = {}
		for class, count in pairs(loadout) do
			if not jcms.weapon_prices[class] or jcms.weapon_blacklist[class] then
				continue 
			end
			
			counts[class] = count
			gunstats[class] = jcms.gunstats_Get(class)
			table.insert(classes, class)
		end
		
		local plyCash = ply:GetNWInt("jcms_cash", 0)
		while true do
			table.Shuffle(classes)
			local boughtOne = false
			for i, class in ipairs(classes) do
				local count = counts[class]
				if count == 0 then continue end
				
				if vq[class] then
					-- Get extra ammo
					local price = math.ceil(jcms.gunstats_ExtraAmmoCostData(gunstats[class], 1)*ammoPriceMul)
					if plyCash >= price then
						vq[class] = vq[class] + 1
						counts[class] = counts[class] - 1
						plyCash = plyCash -  price
						boughtOne = true
					end
				else
					-- Buy gun
					local price = math.ceil(jcms.weapon_prices[class]*gunPriceMul)
					if plyCash >= price then
						vq[class] = 1
						counts[class] = counts[class] - 1
						plyCash = plyCash -  price
						boughtOne = true
					end
				end
			end
			
			if not boughtOne then
				break
			end
		end
		
		return vq
	end
	
	function jcms.spawnmenu_PurchaseLoadout(ply, loadout, gunPriceMul, ammoPriceMul)
		gunPriceMul = gunPriceMul or 1
		ammoPriceMul = ammoPriceMul or 1
		local consumedCash = 0
		
		ply.jcms_canGetWeapons = true
		for class, count in pairs(loadout) do
			local weapon = ply:Give(class, true)
			
			if not IsValid(weapon) then
				weapon = ents.Create(class)
				weapon:SetPos(ply:WorldSpaceCenter())
				weapon:SetAngles(AngleRand(-360, 360))
			end
			
			consumedCash = consumedCash + math.ceil((jcms.weapon_prices[class] or 0)*gunPriceMul)
			
			local stats = jcms.gunstats_Get(class)
			
			if stats then
				local ammotype = stats.ammotype
				if ammotype then
					local ammoGiven = jcms.gunstats_CountGivenAmmoFromLoadoutCount(stats, count)
					if (ammoGiven > stats.clipsize) and (stats.clipsize > 0) then
						ply:GiveAmmo(ammoGiven - stats.clipsize, ammotype)
						
						if IsValid(weapon) then
							weapon:SetClip1(stats.clipsize)
						end
					else
						--ply:GiveAmmo(ammoGiven - stats.clipsize, ammotype) -- Not sure what the fuck was I thinking and why it was here all along,
						ply:GiveAmmo(ammoGiven, ammotype)
					end
					consumedCash = consumedCash + math.ceil(jcms.gunstats_ExtraAmmoCostData(stats, count-1)*ammoPriceMul)
				end
			end
		end
		ply.jcms_canGetWeapons = false

		ply:SetNWInt("jcms_cash", ply:GetNWInt("jcms_cash") - consumedCash)
	end

	function jcms.spawnmenu_PurchaseAndGiveGun(ply, class, count, clipCostMul)
		local cost = jcms.weapon_prices[ class ]
		clipCostMul = tonumber(clipCostMul) or 1
		local count = math.max( math.floor(count or 1), 1 )
		local plyCash = ply:GetNWInt("jcms_cash", 0)
		
		if type(cost) == "number" and cost > 0 then
			local stats = jcms.gunstats_Get(class)

			if ply:HasWeapon(class) then

				-- Buying extra ammo only.
				if stats and stats.ammotype ~= "none" then
					local extraClipCount = math.min(jcms.gunstats_CountMaximumAffordableCount(stats, plyCash), count)
					local extraClipCost = math.ceil( jcms.gunstats_ExtraAmmoCostData(stats, extraClipCount) * clipCostMul )
					
					if ply:GetObserverMode() == OBS_MODE_NONE then
						ply:GiveAmmo(extraClipCount * stats.clipsize, stats.ammotype)
					else
						local oldAmmoCount = ply:GetAmmoCount(stats.ammotype)
						ply:SetAmmo(oldAmmoCount + extraClipCount * stats.clipsize, stats.ammotype)
					end
					ply:SetNWInt("jcms_cash", plyCash - extraClipCost)
					return extraClipCount > 0
				end

			else
			
				if plyCash >= cost then
					-- Buying a weapon with or without extra ammo for the first time.
					ply.jcms_canGetWeapons = true
					if stats and stats.ammotype ~= "none" then
						local extraClipCount = math.min(jcms.gunstats_CountMaximumAffordableCount(stats, plyCash - cost), count - 1)
						local extraClipCost = jcms.gunstats_ExtraAmmoCostData(stats, extraClipCount) * clipCostMul
						
						local givenAmmoCount = jcms.gunstats_CountGivenAmmoFromLoadoutCount(stats, extraClipCount)
						local oldAmmoCount = ply:GetAmmoCount(stats.ammotype)

						ply:Give(class, false)
						ply:SetAmmo(oldAmmoCount + givenAmmoCount, stats.ammotype)
						ply:SetNWInt("jcms_cash", plyCash - cost - extraClipCost)
					else
						ply:Give(class, true)
						ply:SetNWInt("jcms_cash", plyCash - cost)
					end
					ply.jcms_canGetWeapons = false

					return true
				end

			end
		end

		return false
	end

	function jcms.spawnmenu_PurchaseLoadoutGun(ply, class, count)
		if not ply.jcms_pendingLoadout then
			ply.jcms_pendingLoadout = {}
			ply:SetNWInt("jcms_pendingLoadoutCost", 0)
		end

		local cost = jcms.weapon_prices[ class ]
		local count = math.max( math.floor(count or 1), 1 )
		local plyCash = ply:GetNWInt("jcms_cash", 0) - ply:GetNWInt("jcms_pendingLoadoutCost", 0)

		if cost and cost > 0 then
			cost = math.ceil(cost * jcms.util_GetLobbyWeaponCostMultiplier())
			local stats = jcms.gunstats_Get(class)

			if ply.jcms_pendingLoadout[ class ] and ply.jcms_pendingLoadout[ class ] >= 1 then
				
				-- Buying extra ammo only.
				if stats and stats.ammotype ~= "none" then
					local extraClipCount = math.min(jcms.gunstats_CountMaximumAffordableCount(stats, plyCash), count)
					local extraClipCost = jcms.gunstats_ExtraAmmoCostData(stats, extraClipCount)
					ply.jcms_pendingLoadout[ class ] = ply.jcms_pendingLoadout[ class ] + extraClipCount
					ply:SetNWInt("jcms_pendingLoadoutCost", ply:GetNWInt("jcms_pendingLoadoutCost", 0) + extraClipCost)
					return extraClipCount > 0
				end

			else

				if plyCash >= cost then
					-- Buying a weapon with or without extra ammo for the first time.
					if stats and stats.ammotype ~= "none" then
						local extraClipCount = math.min(jcms.gunstats_CountMaximumAffordableCount(stats, plyCash - cost), count - 1)
						local extraClipCost = jcms.gunstats_ExtraAmmoCostData(stats, extraClipCount)
						ply.jcms_pendingLoadout[ class ] = 1 + extraClipCount
						ply:SetNWInt("jcms_pendingLoadoutCost", ply:GetNWInt("jcms_pendingLoadoutCost", 0) + cost + extraClipCost)

					else
						ply.jcms_pendingLoadout[ class ] = 1
						ply:SetNWInt("jcms_pendingLoadoutCost", ply:GetNWInt("jcms_pendingLoadoutCost", 0) + cost)
					end

					return true
				end

			end
		end

		return false
	end

	function jcms.spawnmenu_SellLoadoutGun(ply, class, count)
		if ply.jcms_pendingLoadout and ply:GetNWInt("jcms_pendingLoadoutCost", 0) > 0 and ply.jcms_pendingLoadout[ class ] then
			local cost = jcms.weapon_prices[ class ]
			
			if ply.jcms_pendingLoadout[ class ] > 0 and cost and cost > 0 then
				cost = math.ceil(cost * jcms.util_GetLobbyWeaponCostMultiplier())
				local count = math.min( ply.jcms_pendingLoadout[ class ], math.max( math.floor(count or 1), 1 ) )
				
				local earnedBack = 0
				if count == ply.jcms_pendingLoadout[ class ] then
					earnedBack = earnedBack + cost
				end

				local stats = jcms.gunstats_Get(class)
				if stats and stats.ammotype ~= "none" and (ply.jcms_pendingLoadout[ class ] > 1) then
					earnedBack = earnedBack + jcms.gunstats_ExtraAmmoCostData(stats, count - (count == ply.jcms_pendingLoadout[ class ] and 1 or 0))
				end

				ply:SetNWInt("jcms_pendingLoadoutCost", ply:GetNWInt("jcms_pendingLoadoutCost", 0) - earnedBack)
				ply.jcms_pendingLoadout[ class ] = ply.jcms_pendingLoadout[ class ] - count
				if ply.jcms_pendingLoadout[ class ] == 0 then
					ply.jcms_pendingLoadout[ class ] = nil
					return true, true -- Did it work? Did we fully exhaust the weapon?
				else
					return true, false
				end
			end
			return false, false
		end
	end

	function jcms.spawnmenu_Turret(kind, ply, pos, angle)
		local turret = ents.Create("jcms_turret")
		turret:SetPos(pos)
		turret:Spawn()
		
		turret:UpdateTurretKind(kind)
		turret:SetAngles(angle)

		if IsValid(ply) and jcms.isPlayerEngineer(ply) then
			turret:SetupBoosted()
		end

		if IsValid(ply) then
			turret:SetNWInt("jcms_pvpTeam", ply:GetNWInt("jcms_pvpTeam", -1))
		end
		jcms.util_TryUpdateForPVP(turret)

		local ed = EffectData()
		ed:SetColor(jcms.util_GetColorIntegerPvP(ply))
		ed:SetFlags(0)
		ed:SetEntity(turret)
		util.Effect("jcms_spawneffect", ed)

		local mins = turret:OBBMins()
		mins.x = 0
		mins.y = 0
		mins.z = -mins.z + 2
		turret:SetPos(pos + mins)
		turret.jcms_owner = ply

		jcms.npc_UpdateRelations(turret)
		turret:EmitSound("weapons/shotgun/shotgun_cock.wav")

		local tData = turret:GetTurretData()
		if tData.postSpawn then 
			tData.postSpawn(turret)
		end

		if CPPI then
			turret:CPPISetOwner( game.GetWorld() )
		end
	end
	
	function jcms.spawnmenu_Airdrop(pos, class, delay, locatorName, col, ply)
		local flare = ents.Create("jcms_dropflare")
		flare:SetPos(pos)
		flare:Spawn()

		flare.jcms_owner = ply

		if col then
			flare:SetBeamColour(Vector(col.r/255, col.g/255, col.b/255))
		end

		return flare:DropThing(class, delay, locatorName, col), flare
	end
	
	function jcms.spawnmenu_Airstrike(info)
		--[[ Airstrike info table structure:
			pos (Vector) - Where the bombs will drop
			pos2 (Vector?) - If specified, bombs will gradually move from pos to pos2 (like carpet bombing)
			count (int?) - This many bombs will drop. 1 by default.
			model (string?) - Path to bomb model. Should be explosive. "models/props_phx/ww2bomb.mdl" by default.
			entityclass (string?) - Overrides entity type, in case you got custom bombs. prop_physics by default.
			arrival (number?) - How much time should pass until the bomb hits. 3 by default.
			delay (number?) - If there's more than 1 bomb, this will be the delay between each consequent one. 0.25 by default. Can be a table with 2 numbers, in that case it will be random.
			radius (number?) - Inaccuracy radius for each bomb. 128 by default.
			radius2 (number?) - If specified, radius will slowly change from radius to radius2 as bombs drop.
			blast_radius (number?) - Overrides model's blast radius. If nil, won't override.
			blast_damage (number?) - Overrides model's blast damage. If nil, won't override.
			lead (Entity?) - The entity whom we're trying to follow. Pretty janky, I've never used it myself.
			shootFunc (function(bomb_pos, norm, length, i, count, timeToDrop)?) - Overrides what happens instead of spawning the bomb entity 
		--]]

		assert(isvector(info.pos), "specify airstrike's position")
		local pos1 = info.pos
		local pos2 = info.pos2 or pos1
		local count = info.count or 1
		local model = info.model or "models/props_phx/ww2bomb.mdl"
		local entityclass = info.entityclass or "prop_physics"
		local arrival = info.arrival or 3
		local delay = info.delay or 0.25
		local radius1 = info.radius or 128
		local radius2 = info.radius2 or radius1 
		local blast_radius = info.blast_radius
		local blast_damage = info.blast_damage
		local callback = info.callback
		local leadEntity = IsValid(info.lead) and info.lead or nil

		local max_speed = math.min(physenv.GetPerformanceSettings().MaxVelocity, 2500)
		local slightlyDown = Vector(0, 0, -4)
		local bombInjection = Vector(0, 0, -512)

		local cumulativeDelay = 0
		local currentDirector = jcms.director
		
		for i=1, count do
			local pos = count == 1 and pos1 or LerpVector(count_remap(i, count, 0, 1), pos1, pos2)

			local skyPos = jcms.util_GetSky(pos)

			if skyPos then
				local bomb_pos = skyPos + slightlyDown
				
				local randomRadius = math.random() * count_remap(i, count, radius1, radius2)
				local randomAngle = math.random() * math.pi * 2

				pos = pos + Vector(math.cos(randomAngle) * randomRadius, math.sin(randomAngle) * randomRadius, 0)
				local downtrace = util.TraceLine {
					start = bomb_pos, 
					endpos = pos + bombInjection,
					mask = bit.bor(CONTENTS_MONSTER, MASK_SOLID_BRUSHONLY)
				}

				if (downtrace.HitWorld or IsValid(downtrace.Entity)) and not downtrace.HitSky then
					local impact_pos = downtrace.HitPos
					local dif = impact_pos - bomb_pos
					local length = dif:Length()
					local norm = dif / length
					local launchDelay = 0

					local timeToDrop = length / max_speed
					if timeToDrop < arrival then
						launchDelay = arrival - timeToDrop
					else
						local frac = arrival / timeToDrop
						bomb_pos = LerpVector(frac, impact_pos, bomb_pos)
						dif = impact_pos - bomb_pos
						length = length * frac
						timeToDrop = timeToDrop * frac
					end
					
					if info.shootFunc then
						timer.Simple(cumulativeDelay + launchDelay, function()
							if jcms.director == currentDirector then							
								if IsValid(leadEntity) then
									local lead_pos = leadEntity:WorldSpaceCenter() + leadEntity:GetGroundSpeedVelocity()*timeToDrop
									norm = lead_pos - bomb_pos
									norm:Normalize()
								end
								
								info.shootFunc(bomb_pos, norm, length, i, count, timeToDrop)
							end
						end )
					else
						timer.Simple(cumulativeDelay + launchDelay, function()
							if jcms.director == currentDirector then
								local ent = ents.Create(entityclass)
								ent:SetModel(model)
								
								if IsValid(leadEntity) then
									local lead_pos = leadEntity:WorldSpaceCenter() + leadEntity:GetGroundSpeedVelocity()*timeToDrop
									norm = lead_pos - bomb_pos
									norm:Normalize()
								end

								local bs = ent:BoundingRadius()*2.1
								bomb_pos = bomb_pos + norm*bs
								ent:SetPos(bomb_pos)
								ent:SetAngles( norm:Angle() )
								ent:Spawn()
								
								if callback then
									callback(ent, i, count)
								end

								if blast_damage then
									ent:SetKeyValue("ExplodeDamage", blast_damage)
								end

								if blast_radius then
									ent:SetKeyValue("ExplodeRadius", blast_radius)
								end
								
								norm:Mul(max_speed)
								local phys = ent:GetPhysicsObject()
								phys:Wake()
								phys:SetVelocityInstantaneous(norm)
								phys:SetDamping(0, 0)

								--util.SpriteTrail(ent, 0, color_white, true, 2, 0, 3, 0.5, "trails/smoke")
							end
						end )
					end
					
					if istable(delay) then
						cumulativeDelay = cumulativeDelay + math.Rand(delay[1], delay[2])
					else
						cumulativeDelay = cumulativeDelay + delay
					end
				end
			end
		end
	end

-- // }}}

-- // Console Commands {{{

	concommand.Add("jcms_order", function(ply, cmd, args)
		if ply:Alive() and ply:GetObserverMode() == 0 then
			if jcms.team_JCorp_player(ply) then
				local orderId = args[1]
				local orderData = jcms.orders[ orderId ]
				
				local filter = RecipientFilter()
				filter:AddPlayer(ply)
				
				local can, reason, format = jcms.orders_CanUse(ply, orderId)
				if orderData and can then
					local parserFunc = assert(jcms.orders_argparser[ orderData.argparser ], "map sweepers order '"..tostring(orderId).."' has no argparser. Dev oversight?")
					table.remove(args, 1)
					local success, a1,a2,a3,a4 = parserFunc(ply, args)
					if success then
						local p1, p2, p3, p4, p5, p6 = hook.Run("MapSweepersPlayerOrder", ply, orderId, a1, a2, a3, a4)
						-- Return true to block
						if (p1 or p2 or p3 or p4 or p5 or p6) then
							ply:EmitSound("items/medshotno1.wav", 75, 105, 1, CHAN_AUTO, 0, 0, filter)
						else
							jcms.orders_ForceUse(ply, orderId, a1, a2, a3, a4)
							jcms.printf("%s used '%s'!", ply:Nick(), orderId)
							ply:EmitSound("buttons/combine_button3.wav", 75, 125, 1, CHAN_AUTO, 0, 0, filter)

							if jcms.director then
								jcms.director_stats_AddOrdersUsed(ply)
							end
						end
					else
						jcms.printf("%s tried and failed to use '%s'!", ply:Nick(), orderId)
						ply:EmitSound("items/medshotno1.wav", 75, 105, 1, CHAN_AUTO, 0, 0, filter)
					end
				else
					ply:EmitSound("items/medshotno1.wav", 75, 105, 1, CHAN_AUTO, 0, 0, filter)
					jcms.net_SendOrderMessage(ply, reason or 0, format)
				end
			elseif jcms.team_NPC(ply) then
				local classData = jcms.class_GetData(ply)

				if classData and classData.Ability then
					local worked = classData.Ability(ply)

					if worked then
						ply:EmitSound("buttons/combine_button3.wav", 75, 125, 1, CHAN_AUTO, 0, 0, filter)
					else
						ply:EmitSound("items/medshotno1.wav", 75, 105, 1, CHAN_AUTO, 0, 0, filter)
					end
				end
			end
		end
	end)

	jcms.signals = {
		{ act = "group", text = "#jcms.attack", textEnt = "#jcms.attack_ent" },
		{ act = "forward", text = "#jcms.airstrike", textEnt = "#jcms.airstrike_ent" },
		
		{ act = "forward", text = "#jcms.look", textEnt = "#jcms.look_ent" },
		{ act = "forward", text = "#jcms.take", textEnt = "#jcms.take_ent" },
		
		{ act = "halt", text = "#jcms.defend", textEnt = "#jcms.defend_ent" },
		{ act = "wave", text = "#jcms.help", textEnt = "#jcms.help_ent" },

		{ act = "forward", text = "#jcms.go", textEnt = "#jcms.go_ent" },
		{ act = "forward", text = "#jcms.meet", textEnt = "#jcms.meet_ent" }
	}

	concommand.Add("jcms_signal", function(ply, cmd, args)
		if ply:Alive() and ply:GetObserverMode()==0 and jcms.team_JCorp_player(ply) then
			local signalId = args[1]
			local trace = ply:GetEyeTrace()
			local at

			if trace.Entity and not trace.HitWorld then
				at = trace.Entity
			else
				at = trace.HitPos
			end
			
			local signalData = jcms.signals[ tonumber(signalId) ]
			if signalData then
				local text = tostring(signalData.text or "")
				local arg = ply:Nick()

				if IsValid(at) then
					if signalData.textEnt then
						text = tostring(signalData.textEnt)
					end

					arg = tostring( at.jcms_localization or at:GetClass() )
				end

				jcms.net_SendLocator("all", "Signal"..ply:EntIndex(), { text, arg }, at, jcms.LOCATOR_SIGNAL, 10, nil, ply)

				if signalData.act then
					RunConsoleCommand("act", signalData.act)
				end
			end
			
			hook.Run("MapSweepersPlayerSignal", ply, signalId, at)
		end
	end)

-- // }}}
