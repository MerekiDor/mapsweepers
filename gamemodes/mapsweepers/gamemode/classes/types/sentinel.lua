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
local class = {}
class.orderIndex = 3
jcms.class_Add("sentinel", class, true)

-- Sentinel Armor
class.mdl = "models/player/jcms/jcorp_sentinel.mdl"
class.mdls_pvp = {
	[1] = "models/player/jcms/jcorp_sentinel.mdl",
	[2] = "models/player/jcms/mafia_sentinel.mdl"
}

class.footstepSfx = "NPC_CombineS.RunFootstep"

class.health = 100
class.shield = 150
class.shieldRegen = 25
class.shieldDelay = 15

class.damage = 1
class.hurtMul = 1
class.hurtReduce = 1
class.speedMul = 0.75
class.walkSpeed = 160
class.runSpeed = 160
class.boostedRunSpeed = 250
class.disallowSprintAttacking = true

class.barrierLength = 12
class.barrierCooldown = 3

jcms.class_useNewSentinel = false

function class.PerformBarrierLogic(ply, active)
	local ct = CurTime()
	local length = class.barrierLength
	local cooldown = class.barrierCooldown

	if ply.jcms_sentinelBarrierCooldown and ply.jcms_sentinelBarrierCooldown > ct then
		ply.jcms_sentinelBarrierExpiresAt = nil
		active = false
	elseif ply.jcms_sentinelBarrierExpiresAt and ct >= ply.jcms_sentinelBarrierExpiresAt then
		ply.jcms_sentinelBarrierCooldown = ct + cooldown
		active = false
	elseif active then
		if not ply.jcms_sentinelBarrierExpiresAt then
			ply.jcms_sentinelBarrierExpiresAt = ct + length
		end
		ply.jcms_sentinelBarrierCooldown = nil
	else
		ply.jcms_sentinelBarrierExpiresAt = nil
		if not ply.jcms_sentinelBarrierCooldown then
			ply.jcms_sentinelBarrierCooldown = ct + cooldown
		end
	end

	return active
end

if SERVER then
	function class.OnSpawn(ply, data)
		local filt = RecipientFilter()
		filt:AddPlayer(ply)
		ply.sentinel_breathSound = CreateSound(ply, "player/breathe1.wav", filt)
		
		ply.sentinel_lastDmgBlocked = 0
	end

	function class.TakeDamage(ply, dmg)
		if not(ply:GetObserverMode() == OBS_MODE_NONE and ply:Alive()) then return end

		if dmg:IsDamageType(DMG_NERVEGAS) then
			ply.sentinel_lastDmgBlocked = CurTime()
			dmg:SetDamage(0)
			return
		end

		-- // Thorns {{{
			local attacker = dmg:GetAttacker()
			if IsValid(attacker) then 
				local selfPos = ply:WorldSpaceCenter()
				local attkPos = attacker:WorldSpaceCenter()
				
				if dmg:IsDamageType( DMG_CRUSH + DMG_CLUB + DMG_SLASH  ) and not jcms.team_JCorp(attacker) and attkPos:DistToSqr(selfPos) < 100^2 then 
					local rtnDmg = math.max(dmg:GetDamage(), 25)

					local rtnDmgInfo = DamageInfo()	
					rtnDmgInfo:SetAttacker(ply)
					rtnDmgInfo:SetInflictor(ply)
					rtnDmgInfo:SetReportedPosition(selfPos)
					rtnDmgInfo:SetDamageType(DMG_SHOCK)
					rtnDmgInfo:SetDamage(rtnDmg)
					rtnDmgInfo:SetDamagePosition(attkPos)

					ply.jcms_sentinelReturningDamage = true
					attacker:TakeDamageInfo(rtnDmgInfo)
					ply.jcms_sentinelReturningDamage = nil

					local effectdata = EffectData()
					effectdata:SetStart(attkPos)
					effectdata:SetOrigin(attkPos)
					effectdata:SetMagnitude(2)
					effectdata:SetNormal(vector_up)
					effectdata:SetScale(5)
					effectdata:SetEntity(attacker)
					util.Effect("TeslaHitboxes", effectdata)

					local ed = EffectData()
					ed:SetStart(selfPos)
					ed:SetOrigin(attkPos)
					util.Effect("jcms_tesla", ed)
					
					ply:EmitSound("weapons/stunstick/alyx_stunner" .. math.random(1,2) .. ".wav", 75, 175 + math.Rand(-10, 10), 0.6)
				end
			end
		-- // }}}

		-- // Panic teleport {{{
			ply.sentinel_invulnTime = ply.sentinel_invulnTime or 0

			if CurTime() < ply.sentinel_invulnTime then 
				dmg:SetDamage(0)
				return
			end

			local armour = ply:Armor()
			ply.sentinel_canTeleport = ply.sentinel_canTeleport or armour > 20 --Are we allowed to panic?

			if armour < 15 and ply.sentinel_canTeleport and not ply.sentinel_isTeleporting then 
				ply:EmitSound("buttons/blip2.wav", 65, 150)
			end

			if armour > 0 and ply.sentinel_canTeleport and not ply.sentinel_isTeleporting and jcms.director then
				timer.Simple(0, function() --Just checking if dmg > armour doesn't account for all of the modifiers we apply, so this guarantees accurate behaviour.
					if not IsValid(ply) or ply:Armor() > 0 then return end 

					ply.sentinel_isTeleporting = true

					ply.sentinel_teleportSound = CreateSound(ply, "ambient/levels/labs/teleport_alarm_loop1.wav")
					ply.sentinel_teleportSound:Play()

					--TODO: We probably want an actual on-screen count-down (including miliseconds) for this now that it's more important. 
					timer.Simple(1.5, function() --Delay/warning before teleporting.
						if not IsValid(ply) then return end
						ply.sentinel_teleportSound:Stop()
						ply.sentinel_isTeleporting = false

						for i, ent in ipairs(ents.FindInSphere(ply:WorldSpaceCenter(), 200)) do
							if ent.SentinelAnchor and (not ent.GetHackedByRebels or not ent:GetHackedByRebels()) then 
								return --Don't teleport us if we're near a friendly building.
							end
						end

						if IsValid(ply:GetNWEntity("jcms_vehicle", NULL)) then return end -- Don't teleport us out of vehicles

						local zoneList = jcms.mapgen_ZoneList()
						local zoneDict = jcms.mapgen_ZoneDict()
						
						-- todo: Re-use the teleport-in effect
						local d = jcms.director
						local plyArea = d.playerAreas[ply]
						local plyZoneId = zoneDict[plyArea]
						local plyZone = zoneList[plyZoneId]
						
						if not plyZone or jcms.mapdata.zoneSizes[plyZoneId] < 5000^2 then
							plyZone = zoneList[jcms.mapdata.largestZone]
						end

						if not plyZone then return end --This is stupid but I guess people are willing to play on maps made of tiny rooms.


						local plyMins, plyMaxs = ply:GetHull()
						--local zOff = Vector(0,0, plyMaxs.z + 5)
						local zOff2 = Vector(0,0,5)

						local awayAreas = jcms.director_GetAreasAwayFrom(plyZone, {ply:GetPos()}, 1500, math.huge)

						local weightedAreas = {}
						for i, area in ipairs(awayAreas) do
							local centre = area:GetCenter()
							local tr = util.TraceEntityHull({
								start = centre + zOff2,
								endpos = centre + zOff2
							}, ply)

							if not tr.Hit then --Make sure we won't get stuck at target dest
								--Equal chance to go to any point in zone, regadless of nav density.
								weightedAreas[area] = math.sqrt(area:GetSizeX() * area:GetSizeY())
							end
						end
							
						--TODO: fall-back for if we have no valid areas in zone?
						local chosenArea = jcms.util_ChooseByWeight(weightedAreas)

						local pos = IsValid(chosenArea) and chosenArea:GetCenter() or ply:GetPos()

						-- // Blast / Telefrag {{{
							local dmg = DamageInfo()
							dmg:SetDamagePosition(pos)
							dmg:SetReportedPosition(pos)
							dmg:SetDamageType( DMG_BLAST )
							dmg:SetInflictor(ply)
							dmg:SetAttacker(ply)

							for i, target in ipairs( ents.FindInSphere(pos, 250) ) do
								if not jcms.team_SameTeam(ply, target) and target.TakeDamageInfo then
									dmg:SetDamage( 150 )
									target:TakeDamageInfo(dmg)
								end
							end

							local ed = EffectData()
							ed:SetOrigin( pos )
							ed:SetRadius( 250 )
							ed:SetNormal( vector_up )
							ed:SetMagnitude( 2.5 )
							ed:SetFlags( 1 )
							util.Effect("jcms_blast", ed)
						-- // }}}

						-- // Teleport effect {{{
							--This is for where they come from, not where they're going to.
							--Makes it clearer what happened to other nearby players.	

							local ed = EffectData() --Same as dog death
							ed:SetMagnitude(1.5)
							ed:SetOrigin(ply:WorldSpaceCenter())
							ed:SetRadius(150)
							ed:SetNormal(ply:GetAngles():Up())
							ed:SetFlags(5)
							ed:SetColor( jcms.util_ColorIntegerFast(230, 185, 255) )
							util.Effect("jcms_blast", ed)
						-- // }}}

						ply:SetPos( pos )

						ply:EmitSound("ambient/machines/teleport4.wav")
						ply.sentinel_invulnTime = CurTime() + 1.5 --1.5s of invincibility after teleporting
						ply.sentinel_canTeleport = false
					end)
				end)
			end
		-- // }}}
	end

	function class.SetupMove(ply, mv, cmd) --Long-Distance-Running
		local sprintDelay = 1 --Delay to start speeding up

		if ply:IsSprinting() and not ply.sentinel_isSprinting then
			ply.sentinel_sprintStart = CurTime()
		end
		ply.sentinel_isSprinting = ply:IsSprinting()

		if ply.sentinel_isSprinting then
			local sprintFrac = (CurTime() - ply.sentinel_sprintStart - sprintDelay)/5 --Progress to max
			ply:SetRunSpeed(Lerp( sprintFrac, class.runSpeed, class.boostedRunSpeed))
		else
			ply:SetRunSpeed(class.runSpeed)
		end
	end

	function class.OnKill(ply, npc, inflictor)
		if jcms.class_useNewSentinel then
			-- Experimental sentinel
			if ply.jcms_sentinelReturningDamage then
				return -- Don't get a shield from thorn kills
			end

			if jcms.util_IsStunstick(inflictor) or (not npc.jcms_bounty or npc.jcms_bounty < 20) then
				return -- Dont give shields for kills that are too cheap. Unless we're using stunstick.
			end

			local shieldCount = ply:GetNWInt("jcms_shield", 0)
			local shieldCountCap = 3
			local final = shieldCount == shieldCountCap - 1
			ply:SetNWInt("jcms_shield", math.min(shieldCount + 1, shieldCountCap))

			if shieldCount < shieldCountCap then
				local sfx = final and ("ambient/energy/newspark0"..math.random(10, 11)..".wav") or ("ambient/energy/newspark0"..math.random(8, 9)..".wav")
				ply:EmitSound("ambient/energy/newspark09.wav", 75, math.Remap(shieldCount, 0, shieldCountCap-1, 104, 119), 1)
			end
		else
			--Shield charge on kill.
			local charge = math.ceil(jcms.runprogress_GetDifficulty() * (npc.jcms_bounty or 1) / 30) --We receive some shield even if our target has no bounty.
		
			if charge > 0 then
				local oldArmor = ply:Armor()
				local newArmor = math.min( oldArmor + charge, ply:GetMaxArmor() * 2 ) -- Can charge past max armour.

				if newArmor > oldArmor then
					ply:SetArmor( newArmor )
					ply:EmitSound("items/battery_pickup.wav", 50, 110 + charge * 5 + math.random()*5, 0.75)
				end
			end
		end
	end

	function class.Think(ply)
		class.ThinkBarrier(ply)
		class.ThinkGasMask(ply)
	end

	function class.ThinkBarrier(ply)
		local active = ply:IsWalking() and ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE and not IsValid(ply:GetVehicle()) and not IsValid(ply:GetNWEntity("jcms_vehicle"))
		active = class.PerformBarrierLogic(ply, active)
		
		local barrier = ply.jcms_sentinelBarrier
		if active then
			if not IsValid(barrier) then
				barrier = ents.Create("jcms_sentinelbarrier")
				barrier:SetModel("models/jcms/jcorp_sentinelbarrier.mdl")
				barrier:SetMaterial("models/props_combine/portalball001_sheet")
				barrier:SetColor(Color(0, 161, 255))
				barrier:AddEFlags(EFL_DONTBLOCKLOS)
				barrier:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
				barrier:SetSentinel(ply)
				barrier:Spawn()
				ply.jcms_sentinelBarrier = barrier
			end
		elseif IsValid(barrier) then
			barrier:Remove()
			ply.jcms_sentinelBarrier = nil
		end
	end

	function class.ThinkGasMask(ply)
		if CurTime() - ply.sentinel_lastDmgBlocked < 2 then
			if not(ply.sentinel_breathSound:IsPlaying()) then 
				ply.sentinel_breathSound:PlayEx(1, 80)
			end
		else
			if ply.sentinel_breathSound:IsPlaying() then 
				ply.sentinel_breathSound:Stop()
			end
		end
	end

	hook.Add("MapSweepersClassApplied", "jcms_RemoveSentinelBarrier", function(ply, class, data)
		if class ~= "sentinel" then
			if ply.sentinel_breathSound then
				ply.sentinel_breathSound:Stop()
				ply.sentinel_breathSound = nil
			end

			if IsValid(ply.jcms_sentinelBarrier) then
				ply.jcms_sentinelBarrier:Remove()
				ply.jcms_sentinelBarrier = nil
			end
		end
	end)
end

if CLIENT then
	class.stats = {
		offensive = "0",
		resistance = "2",
		mobility = "-2"
	}

	function jcms.draw_SentinelAnchor()
		if jcms.hud_myclass == "sentinel" then
			local anchoredBy
			for i, ent in ipairs(ents.FindInSphere(jcms.locPly:WorldSpaceCenter(), 200)) do
				if ent.SentinelAnchor and (not ent.GetHackedByRebels or not ent:GetHackedByRebels()) then 
					anchoredBy = ent
					break
				end
			end

			local W = 5
			jcms.hud_sentinelAnchorAnim = ((jcms.hud_sentinelAnchorAnim or 0)*W + (anchoredBy and 1 or 0))/(W+1)
			local anim = jcms.hud_sentinelAnchorAnim

			if anim > 0.001 then
				local off = 6
				local str1 = language.GetPhrase("jcms.sentinelanchored_title")
				local str2 = language.GetPhrase("jcms.sentinelanchored_desc1")
				local str3 = anchoredBy and language.GetPhrase("jcms.sentinelanchored_desc2"):format(anchoredBy.PrintName or anchoredBy:GetClass()) or jcms.hud_sentinelAnchorLastString or ""
				jcms.hud_sentinelAnchorLastString = str3
				
				surface.SetAlphaMultiplier(anim)
				draw.SimpleText(str1, "jcms_hud_big", 0, -24, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(str2, "jcms_hud_medium", 0, -24, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				draw.SimpleText(str3, "jcms_hud_medium", 0, 36, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				
				render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					draw.SimpleText(str1, "jcms_hud_big", 0, -24-off, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
					draw.SimpleText(str2, "jcms_hud_medium", 0, -24-off, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
					draw.SimpleText(str3, "jcms_hud_medium", 0, 36-off, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				render.OverrideBlend(false)
				surface.SetAlphaMultiplier(1)
			end
		else
			jcms.hud_sentinelAnchorAnim = 0
			jcms.hud_sentinelAnchorLastString = nil
		end
	end

	function jcms.draw_SentinelBarrier()
		local w, h = 500, 24
		local x, y = -w/2, -200-h
		local off = 6

		local barrierEnt = jcms.locPly.jcms_sentinelBarrier
		local active = IsValid(barrierEnt)
		active = class.PerformBarrierLogic(jcms.locPly, active)
		
		local health = 0
		local ct = CurTime()
		if active then
			health = math.Clamp( (jcms.locPly.jcms_sentinelBarrierExpiresAt - ct) / class.barrierLength, 0, 1)
		else
			health = 1 - math.Clamp( (jcms.locPly.jcms_sentinelBarrierCooldown - ct) / class.barrierCooldown, 0, 1)
		end

		local accumulatedFactor = active and barrierEnt:GetShieldRestorationFactor() or 0
		local accumulated = math.ceil( accumulatedFactor * jcms.locPly:GetMaxArmor() )
		local isAtMaxDamage = active and (barrierEnt:GetDamageTaken() >= barrierEnt:GetMaxDamageTaken())

		local str1 = ("[%s]"):format( (input.LookupBinding("+walk") or "N/A"):upper() )
		local str2 = [=[Bullet Barrier]=]
		local str3 = ([=[Accumulated shields: %d]=]):format(accumulated)

		local colorDark = active and jcms.color_dark or jcms.color_dark_alt
		local colorBright = active and (isAtMaxDamage and jcms.color_alert or jcms.color_bright) or jcms.color_bright_alt
		local unavailable = (not active and health < 1)

		if unavailable then
			surface.SetAlphaMultiplier(0.3)
		end

		surface.SetDrawColor(colorDark)
		if active then
			draw.SimpleText(str3, "jcms_hud_medium", x + w/2, y - 18, colorDark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		else
			if not unavailable then
				draw.SimpleText(str1, "jcms_hud_medium", x + w/2, y + h + 12, colorDark, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end

			draw.SimpleText(str2, "jcms_hud_medium", x + w/2, y - 12, colorDark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end
		surface.DrawRect(x, y, w, h)
		
		render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			surface.SetDrawColor(colorBright)
			surface.DrawRect(x, y-off, w*health, h)
			if active then
				draw.SimpleText(str3, "jcms_hud_medium", x + w/2, y - 18 - off, colorBright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			elseif health > 0 then
				if not unavailable then
					draw.SimpleText(str1, "jcms_hud_medium", x + w/2, y + h + 12 - off, colorBright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				end

				draw.SimpleText(str2, "jcms_hud_medium", x + w/2, y - 12 - off, colorBright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			end
		render.OverrideBlend(false)

		if unavailable then
			surface.SetAlphaMultiplier(1)
		end
	end

	function class.CalcViewModelView( wep, viewModel, oldPos, oldAng, cPos, cAng, ply )
		if jcms.cvar_motionsickness:GetBool() then return end
		local plyTable = ply:GetTable()

		local vel = ply:GetVelocity()
		local speed = vel:Length()
		local mspeed = 200
		
		local right, up, fwd = cAng:Right(), cAng:Up(), cAng:Forward()
		local dotRight = vel:Dot(right)
		local bob = plyTable.jcms_viewBobProgress or 0
		local sway1, sway2 = math.sin(bob), math.sin(bob*2)*0.2
		
		plyTable.jcms_viewBobSprint = ( (plyTable.jcms_viewBobSprint or 0)*12 + (ply:IsSprinting() and 1 or 0) ) / 13
		local sprintHolster = plyTable.jcms_viewBobSprint
		
		local magn = Lerp(1 - mspeed/(speed+mspeed), 0, 2)
		cAng:RotateAroundAxis(up, (-sway1-dotRight*0.02)*magn)
		cAng:RotateAroundAxis(right, (-sway2 - sprintHolster*13)*magn)
		cAng:RotateAroundAxis(fwd, dotRight*0.03*magn)
		
		if plyTable.jcms_viewBobDiffVector then
			local oldx, oldy, oldz = cPos:Unpack()
			local diff = plyTable.jcms_viewBobDiffVector
			cPos:Add(diff)
			diff:Div(10)
			local dip = plyTable.jcms_viewBobDip or 0
			diff:Add(up * dip * -0.23)
			cPos:Add(diff)
			cPos:Add(math.cos(bob)*right*0.3)

			local pushBackMagn = math.Clamp(magn, 0, 1)
			local newx, newy, newz = cPos:Unpack()
			cPos:SetUnpacked( Lerp(pushBackMagn, oldx, newx), Lerp(pushBackMagn, oldy, newy), Lerp(pushBackMagn, oldz, newz) )
		end
	end

	function class.CalcView(ply, origin, angles, fov)
		if jcms.cvar_motionsickness:GetBool() then return end
		local plyTable = ply:GetTable()

		-- // ViewBob {{{
			local speed = ply:GetVelocity():Length()
			local mspeed = 200
			local magn = Lerp(1 - mspeed/(speed+mspeed), 0, -0.13)
			local dipMagn = math.Clamp((1 - mspeed/(speed+mspeed))*4, 0, 1)

			local bob = plyTable.jcms_viewBobProgress or 0
			bob = bob + speed * FrameTime() * 70 / (ply:IsOnGround() and 1200 or 8700)
			
			local right, up = angles:Right(), angles:Up()
			local sway1, sway2, sway3 = math.sin(bob), math.sin(bob*2)*0.8
			local dip = math.Clamp(math.TimeFraction(0.32, 0.9, math.cos(bob*2+0.3)), 0, 1)*dipMagn
			
			local diff = plyTable.jcms_viewBobDiffVector or Vector(0, 0, 0)
			diff:SetUnpacked(0, 0, 0)
			diff:Add(right * sway1 * magn)
			diff:Add(up * (sway2 * magn + dip*0.1))
			
			diff:Mul(10)
			origin:Add(diff)
		-- // }}

		plyTable.jcms_viewBobDip = dip
		plyTable.jcms_viewBobProgress = bob
		plyTable.jcms_viewBobDiffVector = diff
		plyTable.jcms_viewBobFov = fov
	end

	function class.DrawHUD(ply)
		jcms.setup3d2dCentral("bottom")
			jcms.draw_SentinelAnchor()
			jcms.draw_SentinelBarrier()
		cam.End3D2D()
	end
	
	function class.TranslateActivity(ply, act)
		if (act == ACT_MP_RUN) and (ply.sentinel_isSprinting) then
            return ACT_HL2MP_RUN_CHARGING
        end
	end
end
