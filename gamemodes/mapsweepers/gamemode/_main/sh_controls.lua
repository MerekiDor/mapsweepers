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

-- // SprintHack {{{
do
	if not jcms.sprintHackSetup then 
		local plyMeta = FindMetaTable("Player")

		--Disable lua detection of IN_SPEED if player class has sprinthack
		local ogKeyDown = plyMeta.KeyDown
		function plyMeta.KeyDown(ply, key)
			local kd = ogKeyDown(ply, key)
			if kd and bit.band(key, IN_SPEED) == IN_SPEED and not(ply:InVehicle()) and IsValid(ply:GetActiveWeapon()) and not IsValid(ply:GetNWEntity("jcms_vehicle")) then
				local data =  jcms.class_GetData(ply)
				return not(data and data.sprintHack)
			end
			return kd
		end

		local ogKeyPressed = plyMeta.KeyPressed
		function plyMeta.KeyPressed(ply, key)
			local kp = ogKeyPressed(ply, key)
			if kp and bit.band(key, IN_SPEED) == IN_SPEED and not(ply:InVehicle()) and IsValid(ply:GetActiveWeapon()) and not IsValid(ply:GetNWEntity("jcms_vehicle")) then 
				local data =  jcms.class_GetData(ply)
				return not(data and data.sprintHack)
			end
			return kp
		end
	end

	hook.Add( "SetupMove", "jcms_VehicleNoMove", function(ply, mv, cmd)
		if ply:GetMoveType() == MOVETYPE_NOCLIP and IsValid( ply:GetNWEntity("jcms_vehicle") ) then
			mv:SetForwardSpeed(0)
			mv:SetSideSpeed(0)
			mv:SetUpSpeed(0)
			mv:SetFinalStepHeight(0)
			mv:SetButtons( bit.band( mv:GetButtons(), bit.bnot(IN_JUMP) ) )
		end
	end )

	--Stops this from getting applied repeatedly when reloading code. This was fucking up my profiling - j
	jcms.sprintHackSetup = true

	hook.Add("SetupMove", "jcms_SetupMove", function(ply, mv, cmd)
		local data = jcms.class_GetData(ply)
	
		if data then
			if data.sprintHack then --Run without running. For recon and sentinel.
				if mv:KeyDown(IN_SPEED) then 
					ply:SetWalkSpeed(data.runSpeed)
				else
					ply:SetWalkSpeed(data.walkSpeed)
				end
				local nSpd = bit.bnot(IN_SPEED)
				local bttns = mv:GetButtons()
				mv:SetButtons(bit.band(nSpd, bttns))
			end
	
			if data.SetupMove then
				data.SetupMove(ply, mv, cmd, data)
			end
		end
	end)
end
-- // }}}

-- // Disallow attacking in vehicles + for certain classes {{{
do
	hook.Add("StartCommand", "jcms_NoVehicleShooting", function(ply, cmd)
		if SERVER then
			local jVehicle = ply:GetNWEntity("jcms_vehicle")
			if IsValid(jVehicle) then
				if jVehicle:GetDriver() == ply then
					jVehicle.attacking1 = bit.band( cmd:GetButtons(), IN_ATTACK) > 0
					jVehicle.attacking2 = bit.band( cmd:GetButtons(), IN_ATTACK2) > 0
				end
				
				cmd:RemoveKey(IN_ATTACK)
				cmd:RemoveKey(IN_ATTACK2)
			end
		end

		local classData = jcms.class_GetData(ply)
		if classData and classData.disallowSprintAttacking and ply:IsSprinting() then
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_ATTACK2)
		end
	end)
end
-- // }}}

-- // Stuck Detector {{{
if SERVER then
	jcms.stuckKeyDict = {
		["Fwd"] = IN_FORWARD,
		["Back"] = IN_BACK,
		["Left"] = IN_MOVELEFT,
		["Right"] = IN_MOVERIGHT,
		["Jump"] = IN_JUMP,
		["Crouch"] = IN_DUCK
	}

	function jcms.PlayerStuckCheck(ply)
		if ply:Team() ~= 1 or IsValid( ply:GetNWEntity("jcms_vehicle") ) then
			return false
		end

		if not ply:IsInWorld() then
			return true
		end
		
		local idlingFor = CurTime() - (ply.jcms_idleSince or CurTime())

		if not ply:IsOnGround() and idlingFor > 0.7 then
			return true
		end

		local count = 0

		local plyTbl = ply:GetTable()
		
		if idlingFor > 1 then
			if plyTbl.jcms_stuck_triedFwd then
				count = count + math.min(plyTbl.jcms_stuck_triedFwd, 1)
			end

			if plyTbl.jcms_stuck_triedBack then
				count = count + math.min(plyTbl.jcms_stuck_triedBack, 1)
			end

			if plyTbl.jcms_stuck_triedLeft then
				count = count + math.min(plyTbl.jcms_stuck_triedLeft, 1)
			end

			if plyTbl.jcms_stuck_triedRight then
				count = count + math.min(plyTbl.jcms_stuck_triedRight, 1)
			end

			count = math.min(count, 2)

			if plyTbl.jcms_stuck_triedJump then
				count = count + math.min(plyTbl.jcms_stuck_triedJump, 4)
			end

			if plyTbl.jcms_stuck_triedCrouch then
				count = count + math.min(plyTbl.jcms_stuck_triedCrouch, 2)
			end
		end

		return count >= 5
	end

	function jcms.PlayerStuckClear(ply)
		local plyTbl = ply:GetTable()
		plyTbl.jcms_stuck_triedFwd = nil
		plyTbl.jcms_stuck_triedBack = nil
		plyTbl.jcms_stuck_triedLeft = nil
		plyTbl.jcms_stuck_triedRight = nil
		plyTbl.jcms_stuck_triedJump = nil
		plyTbl.jcms_stuck_triedCrouch = nil
		plyTbl.jcms_stuck_last = CurTime()
	end

	function jcms.PlayerStuckLogicForPlayer(ply, ct)
		ct = ct or CurTime()
		local plyTbl = ply:GetTable()

		if (not plyTbl.jcms_stuck_last or ct - plyTbl.jcms_stuck_last >= 3.5) and ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
			local idlingFor = ct - (plyTbl.jcms_idleSince or CurTime())

			if idlingFor > 1 then
				if jcms.PlayerStuckCheck(ply) then
					jcms.PlayerStuckHandle(ply)
				end
			else
				jcms.PlayerStuckClear(ply)
			end
		end
	end

	function jcms.PlayerStuckLogic(specificPly)
		if specificPly and IsValid(specificPly) then
			jcms.PlayerStuckLogicForPlayer(specificPly)
		else
			if not jcms.director or jcms.director.debug then
				return
			end

			local ct = CurTime()
			for i, ply in ipairs( player.GetAll() ) do
				jcms.PlayerStuckLogicForPlayer(ply, ct)
			end
		end
	end

	function jcms.PlayerStuckHandle(ply)
		local oldIdleTime = ply.jcms_idleSince or CurTime()
		local oldPos = ply:GetPos()

		jcms.PlayerStuckClear(ply)

		timer.Simple(0.5, function()
			if IsValid(ply) and ((ply.jcms_idleSince or CurTime()) <= oldIdleTime) then
				jcms.net_SendTip(ply, false, jcms.HINT_STUCK)
				jcms.DischargeEffect(ply:WorldSpaceCenter(), 1)
			end
		end)

		timer.Simple(2.8, function()
			if IsValid(ply) and ply:GetPos():DistToSqr(oldPos) < 32 and ((ply.jcms_idleSince or CurTime()) <= oldIdleTime) then
				local ed = EffectData()
				ed:SetMagnitude(2)
				ed:SetOrigin(ply:WorldSpaceCenter())
				ed:SetRadius(150)
				ed:SetNormal(ply:GetAngles():Up())
				ed:SetFlags(5)
				ed:SetColor( jcms.util_ColorIntegerFast(255, 128, 128) )
				util.Effect("jcms_blast", ed)

				ply:EmitSound("ambient/machines/teleport4.wav", 100, 150, 1)
				
				local teleportToAreas = {}
				do -- Calculating which points we can take the player to
					local nearestNavArea = navmesh.GetNearestNavArea(oldPos, true, 16000, false, false)
					if nearestNavArea then
						table.insert(teleportToAreas, nearestNavArea)
					end

					local adjacent = navmesh.Find(ply:GetPos(), 2000, 2000, 2000)
					if nearestNavArea then
						table.RemoveByValue(adjacent, nearestNavArea)
					end

					if #adjacent > 0 then
						table.Add(teleportToAreas, adjacent)
					else
						local zoneList = jcms.mapgen_ZoneList()
						local mainZone = zoneList[1]
						if mainZone and #mainZone > 0 then
							table.Add(teleportToAreas, mainZone)
						end
					end
				end

				local bestVector = vec
				for i, area in ipairs(teleportToAreas) do -- Picking an area to take the player to
					local vec = area:GetCenter()

					if vec:DistToSqr(oldPos) <= 32 then
						continue
					end
					
					local vec2 = Vector(vec.x, vec.y, vec.z + 8)

					local tr = util.TraceHull {
						mins = Vector(-16, -16, 0), maxs = Vector(16, 16, 72),
						mask = MASK_PLAYERSOLID, start = vec, endpos = vec2
					}
		
					if tr.Hit then
						continue 
					end

					bestVector = vec
					break
				end

				if bestVector then
					ply:SetPos(bestVector)

					local ed = EffectData()
					ed:SetMagnitude(2)
					ed:SetOrigin(ply:WorldSpaceCenter())
					ed:SetRadius(250)
					ed:SetNormal(ply:GetAngles():Up())
					ed:SetFlags(5)
					ed:SetColor( jcms.util_ColorIntegerFast(255, 128, 128) )
					util.Effect("jcms_blast", ed)
				end
			end
		end)
	end

	hook.Add("SetupMove", "jcms_StuckTracker", function(ply, mv, cmd)
		local plyTbl = ply:GetTable()
		for name, key in pairs(jcms.stuckKeyDict) do
			if mv:KeyPressed(key) then
				local tk = "jcms_stuck_tried" .. name
				plyTbl[tk] = (plyTbl[tk] or 0) + 1
				jcms.PlayerStuckLogic(ply)
			end
		end
	end)

	timer.Create("jcms_StuckChecker", 1.5, 0, function()
		jcms.PlayerStuckLogic()
	end)
end
-- // }}}

-- // Snares {{{
	--Slightly different logic between client and server because I'm not gonna network the entire snares table.
	
	if SERVER then
		hook.Add("SetupMove", "jcms_Snare", function(ply, mv, cmd)
			if not ply.jcms_snares then return end

			local speedCap = mv:GetMaxClientSpeed()
			for snarer, minSpeed in pairs(ply.jcms_snares) do 
				if IsValid(snarer) then
					speedCap = math.min(speedCap, minSpeed)
				end
			end

			--TODO: Do something about recon's jump

			speedCap = mv:SetMaxClientSpeed(speedCap)
		end)
	elseif CLIENT then
		hook.Add("SetupMove", "jcms_Snare", function(ply, mv, cmd)
			--TODO: Network the maximum speed on server, read that here.
		end)
	end
-- // }}}