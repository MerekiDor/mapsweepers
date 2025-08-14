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
local class = {}
class.orderIndex = 3
jcms.class_Add("sentinel", class, true)

-- Sentinel Armor
class.mdl = "models/player/gasmask.mdl"
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

class.matOverrides = { 
	["models/cstrike/ct_sas"] = "models/jcms/player/sentinel",
	["models/cstrike/ct_sas_glass"] = "jcms/jglow"
}

jcms.class_useNewSentinel = false

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

			if armour > 0 and ply.sentinel_canTeleport and not ply.sentinel_isTeleporting then
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

						--TODO: ABSOLUTELY NEEDS TO BE INDICATED. Should be some large-text saying "ANCHORED" + some smaller text elaborating a bit
						--(Telling people they won't teleport / that it's buildings causing this)
						--This should ideally display whenever they're close to a building.
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
							local weightedZones = {}
							for zone, area in ipairs(jcms.mapdata.zoneSizes) do
								if area >= 5000 then 
									weightedZones[zone] = math.sqrt(area)
								end
							end
							
							plyZoneId = jcms.util_ChooseByWeight(weightedZones)
							plyZone = zoneList[plyZoneId]
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
			local charge = math.ceil((npc.jcms_bounty or 1) / 30) --We receive some shield even if our target has no bounty.
		
			if charge > 0 then
				local oldArmor = ply:Armor()
				local newArmor = math.min( oldArmor + charge, 250 ) --Can charge past max armour. --TODO: Visuals (Preferably make the "overcharged" part of the armour bar lighter)
				--TODO: Would be nice if we could also overcharge with batteries/chargers, although that probably isn't possible.

				if newArmor ~= oldArmor then
					ply:SetArmor( newArmor )
					ply:EmitSound("items/battery_pickup.wav", 50, 110 + charge * 5 + math.random()*5, 0.75)
				end
			end
		end
	end

	function class.Think(ply)
		if CLIENT then return end

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
end

if CLIENT then
	class.stats = {
		offensive = "0",
		resistance = "2",
		mobility = "-2"
	}

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
	
	function class.TranslateActivity(ply, act)
		if (act == ACT_MP_RUN) and (ply.sentinel_isSprinting) then
            return ACT_HL2MP_RUN_CHARGING
        end
	end
end
