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

-- This code is 100%, pure and refined ass.
-- it only ever loads on jcms_tutorial, though.

hook.Add("InitPostEntity", "jcms_TutorialBuild", function()
	jcms.tutorialPhase = 0
	jcms.tutorialEnts = {}
	
	for i, ent in pairs(ents.GetAll()) do
		local name = ent:GetName()
		if #name > 0 then
			jcms.tutorialEnts[name] = ent
		end
	end

	local terminal = ents.Create("jcms_terminal")
	terminal:Spawn()
	terminal:SetPos(Vector("2304.127686 -1312.477295 -382.837189"))
	terminal:SetAngles(Angle(0, 270, 0))
	terminal:InitAsTerminal("models/props_combine/breenconsole.mdl", "pin")
	terminal.jcms_hackType = "circuit"
	jcms.tutorialEnts._terminal1 = terminal
end)

hook.Add("jcms_PlayerNetReady", "jcms_tutorialOnActivate", function(data)
	local objectives = {
		{ type = "tutorialphase0", progress = 0, total = 0 }
	}
	jcms.net_ShareMissionData(objectives)
end)

hook.Add("Think", "jcms_TutorialThink", function()
	local ply = Entity(1)
	
	if jcms.tutorialPhase <= 1 then
		table.Empty(jcms.weapon_prices)
	end
	
	if not ( IsValid(jcms.tutorialEnts._terminal1) and jcms.tutorialEnts._terminal1:GetNWBool("jcms_terminal_locked") ) then
		if IsValid(jcms.tutorialEnts.door1) and (not jcms.tutorialEnts.door1.done) and jcms.tutorialPhase == 0 then
			jcms.tutorialEnts.door1:Fire("Open")
			jcms.tutorialEnts.door1.done = true
			jcms.tutorialPos = Vector("2509.516357 -1418.914062 -319.917389")
		end
	end
	
	if jcms.tutorialPhase == 1 then
		local cash = ply:GetNWInt("jcms_cash")
		
		if cash >= 100 or jcms.tutorialHadEnoughCash then
			ply:SetNWInt("jcms_cash", math.max(100, cash))
			jcms.tutorialHadEnoughCash = true
			jcms.tutorialPos = Vector("3073.396729 -1118.742798 -320.100616")
		end
	end
	
	if (jcms.tutorialPhase==1 or jcms.tutorialPhase==2) and ply:GetPos():WithinAABox(Vector("3279.147461 -696.502747 -387.080994"), Vector("3478.897705 -936.565002 -279.127930")) then
		if jcms.tutorialPhase==1 then
			jcms.tutorialPhase = 2
			table.Empty(jcms.orders)
			jcms.net_RemoveOrder("mine_breach")
			jcms.orders.jumppad = jcms.orders_tutorialInactive.jumppad
			jcms.net_SendOrder("jumppad", jcms.orders_tutorialInactive.jumppad)
			jcms.tutorialPos = Vector("3380.335449 -823.307312 -320.280365")

			local objectives = {
				{ type = "tutorialphase2", progress = 0, total = 0 }
			}
			jcms.net_ShareMissionData(objectives)
		end
		
		ply:SetNWInt("jcms_cash", math.max(150, ply:GetNWInt("jcms_cash")))
	end
	
	if jcms.tutorialPhase == 2 and ply:GetPos():WithinAABox(Vector("2973.141113 -946.744263 6.538483"), Vector("3272.571289 -696.505676 -267.185547")) then
		jcms.tutorialPhase = 3
		table.Empty(jcms.orders)
		jcms.net_RemoveOrder("jumppad")

		jcms.orders.turret_smg = jcms.orders_tutorialInactive.turret_smg
		jcms.orders.turret_shotgun = jcms.orders_tutorialInactive.turret_shotgun
		jcms.orders.turret_bolter = jcms.orders_tutorialInactive.turret_bolter
		jcms.orders.turret_gatling = jcms.orders_tutorialInactive.turret_gatling
		jcms.orders.tesla = jcms.orders_tutorialInactive.tesla

		jcms.net_SendOrder("turret_smg", jcms.orders_tutorialInactive.turret_smg)
		jcms.net_SendOrder("turret_shotgun", jcms.orders_tutorialInactive.turret_shotgun)
		jcms.net_SendOrder("turret_bolter", jcms.orders_tutorialInactive.turret_bolter)
		jcms.net_SendOrder("turret_gatling", jcms.orders_tutorialInactive.turret_gatling)
		jcms.net_SendOrder("tesla", jcms.orders_tutorialInactive.tesla)

		jcms.tutorialPos = Vector("3227.235840 -762.787659 -191.658691")

		local objectives = {
			{ type = "tutorialphase3", progress = 0, total = 0 }
		}
		jcms.net_ShareMissionData(objectives)
	end
	
	if jcms.tutorialPhase == 3 then
		jcms.tutorialEnts.door3:Fire("Open")
		
		if not jcms.tutorialCellNPCs then 
			jcms.tutorialCellNPCs = {}
		else
			for i=#jcms.tutorialCellNPCs, 1, -1 do
				local npc = jcms.tutorialCellNPCs[i]
				if not IsValid(npc) or npc:Health() <= 0 then
					table.remove(jcms.tutorialCellNPCs, i)
				end
			end
		end
		
		if #jcms.tutorialCellNPCs < 5 then
			local pos = Vector(math.random(2529, 2810), math.random(-583, -232), -256)
			local npc = jcms.npc_Spawn("zombie_husk", pos)
			npc.jcms_bounty = 35
			
			local ed2 = EffectData()
			ed2:SetColor(jcms.factions_GetColorInteger("zombie"))
			ed2:SetFlags(0)
			ed2:SetEntity(npc)
			util.Effect("jcms_spawneffect", ed2)
			table.insert(jcms.tutorialCellNPCs, npc)
		end
		
		for i, ent in ipairs(ents.FindByClass "jcms_turret") do
			if ent:GetTurretKind() == "gatling" then
				jcms.tutorialPhase = 4
				table.Empty(jcms.orders)
				jcms.net_RemoveOrder("turret_smg")
				jcms.net_RemoveOrder("turret_shotgun")
				jcms.net_RemoveOrder("turret_bolter")
				jcms.net_RemoveOrder("turret_gatling")
				jcms.net_RemoveOrder("tesla")

				local objectives = {
					{ type = "tutorialphase4", progress = 0, total = 0 }
				}
				jcms.net_ShareMissionData(objectives)
			end
		end
		
		ply:SetNWInt("jcms_cash", math.max(350, ply:GetNWInt("jcms_cash")))
	end
	
	if jcms.tutorialPhase == 4 then
		jcms.tutorialEnts.door4:Fire("Open")
		if not IsValid(jcms.tutorialEnts.shop) then
			local shop = ents.Create("jcms_shop")
			shop:Spawn()
			shop:SetPos(Vector(1985, -128, -256))
			shop:SetAngles(Angle(0, -90, 0))
			jcms.tutorialEnts.shop = shop
			
			jcms.weapon_prices = {
				weapon_pistol = 159,
				weapon_smg1 = 219,
				weapon_357 = 359,
				weapon_ar2 = 429,
				weapon_shotgun = 399,
				weapon_crossbow = 699
			}
			
			jcms.net_SendWeaponPrices(jcms.weapon_prices, ply)
		end
		
		if #ply:GetWeapons() > 1 then
			jcms.tutorialEnts.gate_prearena:Fire("Open")
			jcms.tutorialPhase = 5

			local objectives = {
				{ type = "tutorialphase5", progress = 0, total = 0 }
			}
			jcms.net_ShareMissionData(objectives)
		else
			ply:SetNWInt("jcms_cash", math.max(500, ply:GetNWInt("jcms_cash")))
		end
	end
	
	if jcms.tutorialPhase == 5 then
		jcms.tutorialEnts.door5:Fire("Open")
		
		if ply:GetPos():WithinAABox(Vector("386.476715 -101.987541 177.482651"), Vector("-198.440903 -453.348785 -1.969206")) then
			jcms.tutorialPos = Vector("1985.008301 -262.267548 -191.978653")
			
			if not jcms.tutorialRangeNPCs then 
				jcms.tutorialRangeNPCs = {}
				jcms.tutorialRangeSpawning = true
				jcms.tutorialRangeNextSpawn = CurTime() + 3
				
				table.Empty(jcms.orders)
				jcms.orders.carpetbombing = jcms.orders_tutorialInactive.carpetbombing
				jcms.orders.shelling = jcms.orders_tutorialInactive.shelling
				jcms.orders.shieldcharger = jcms.orders_tutorialInactive.shieldcharger
				jcms.net_SendOrder("carpetbombing", jcms.orders_tutorialInactive.carpetbombing)
				jcms.net_SendOrder("shelling", jcms.orders_tutorialInactive.shelling)
				jcms.net_SendOrder("shieldcharger", jcms.orders_tutorialInactive.shieldcharger)
			else
				for i=#jcms.tutorialRangeNPCs, 1, -1 do
					if jcms.tutorialRangeNPCs[i]:Health() <= 0 then
						table.remove(jcms.tutorialRangeNPCs, i)
					end
				end
			end
			
			if #jcms.tutorialRangeNPCs < 5 and jcms.tutorialRangeSpawning and (CurTime() - jcms.tutorialRangeNextSpawn)>0 then
				local pos = Vector(math.random(-90, 205), math.random(15, 479), 0)
				local npc = jcms.npc_Spawn("combine_soldier", pos)
				
				local ed2 = EffectData()
				ed2:SetColor(jcms.factions_GetColorInteger("combine"))
				ed2:SetFlags(0)
				ed2:SetEntity(npc)
				util.Effect("jcms_spawneffect", ed2)
				table.insert(jcms.tutorialRangeNPCs, npc)
				
				jcms.tutorialRangeNextSpawn = CurTime() + 0.5
				if #jcms.tutorialRangeNPCs >= 5 then
					jcms.tutorialRangeSpawning = false
				end
			elseif #jcms.tutorialRangeNPCs == 0 then
				jcms.tutorialRangeSpawning = true
			end
		end
	end
	
	if jcms.tutorialPhase == 6 then
		ply:SetNWInt("jcms_cash", math.max(1000, ply:GetNWInt("jcms_cash")))
		local v = Vector("58.321732 287.461945 204.396271")

		if not IsValid(jcms.tutorialRangeGunship) then
			if jcms.tutorialRangeGunshipDying then
				jcms.tutorialPhase = 7
				
				table.Empty(jcms.orders)
				jcms.net_RemoveOrder("orbitalbeam")
				jcms.net_RemoveOrder("carpetbombing")
				jcms.net_RemoveOrder("shelling")
				jcms.net_RemoveOrder("shieldcharger")
				jcms.orders.restock = jcms.orders_tutorialInactive.restock
				jcms.orders.firstaid = jcms.orders_tutorialInactive.firstaid
				
				jcms.orders.restock.cooldown = 10
				jcms.orders.firstaid.cooldown = 15
				jcms.net_SendOrder("restock", jcms.orders_tutorialInactive.restock)
				jcms.net_SendOrder("firstaid", jcms.orders_tutorialInactive.firstaid)

				local objectives = {
					{ type = "tutorialphase7", progress = 0, total = 0 }
				}
				jcms.net_ShareMissionData(objectives)
			else
				jcms.tutorialRangeGunship = jcms.npc_Spawn("combine_gunship", v)
				jcms.tutorialRangeGunship:SetPos(v)
				
				local ed2 = EffectData()
				ed2:SetColor(jcms.factions_GetColorInteger("combine"))
				ed2:SetFlags(0)
				ed2:SetEntity(jcms.tutorialRangeGunship)
				util.Effect("jcms_spawneffect", ed2)
			end
		else
			jcms.tutorialRangeGunship.jcms_gunshipMoveTarget = v
			jcms.tutorialRangeGunship:SetSaveValue("m_vecDesiredPosition", v)

			for i, ent in ipairs( ents.FindByClass("jcms_deathray") ) do
				ent:SetBeamLifeTime(6)
				ent:SetBeamPrepTime(3)
			end
		end
	end
	
	if jcms.tutorialPhase == 7 then
		jcms.tutorialEnts.door6:Fire("Open")
		ply:SetNWInt("jcms_cash", math.max(500, ply:GetNWInt("jcms_cash")))
	end
	
	if jcms.tutorialPhase == 8 then
		if ply:GetPos():WithinAABox(Vector("413.180328 -1117.818970 127.761681"), Vector("935.266113 -1411.558838 -1.790360")) then
			jcms.tutorialEnts.door7:Fire("Close")
			jcms.tutorialEnts.door8:Fire("Open")
			jcms.tutorialPos = Vector("563.179016 -1093.080322 0.031250")
			
			if jcms.orders.restock then
				table.Empty(jcms.orders)
				jcms.net_RemoveOrder("restock")
				jcms.net_RemoveOrder("firstaid")
				jcms.orders.respawnbeacon = jcms.orders_tutorialInactive.respawnbeacon
				
				jcms.orders.respawnbeacon.cooldown = 30
				jcms.net_SendOrder("respawnbeacon", jcms.orders_tutorialInactive.respawnbeacon)
			end
		end
		
		ply:SetNWInt("jcms_cash", math.max(2000, ply:GetNWInt("jcms_cash")))
		
		if ply:GetPos():WithinAABox(Vector("1343.458374 -1728.119751 0.365191"), Vector("1598.161743 -1417.928101 205.418396")) then
			jcms.tutorialPhase = 9
			
			local v1 = Vector("1540.895508 -2394.598633 87.637070")
			local v2 = Vector("1516.377319 -2533.124023 212.545593")
			local v3 = Vector("1373.599365 -2531.058838 212.545593")
			
			jcms.tutorialFinalZombies = {}
			table.insert(jcms.tutorialFinalZombies, jcms.npc_Spawn("zombie_husk", v1))
			table.insert(jcms.tutorialFinalZombies, jcms.npc_Spawn("zombie_husk", v2))
			table.insert(jcms.tutorialFinalZombies, jcms.npc_Spawn("zombie_husk", v3))
			
			local evacSafeOverride = function(ent)
				for i, z in ipairs(jcms.tutorialFinalZombies) do
					if IsValid(z) and z:Health() > 0 then
						return false
					end
				end
				
				return true
			end
			
			for i, ent in ipairs(ents.FindByClass "jcms_evac") do
				ent.IsSafe = evacSafeOverride
				ent:SetMaxCharge(10)
				ent:SetCharge(0)
				ent.forceCharging = true
			end

			local objectives = {
				{ type = "tutorialphase9", progress = 0, total = 0 }
			}
			jcms.net_ShareMissionData(objectives)
		end
	end
	
	if jcms.tutorialPhase == 9 then
		jcms.tutorialEnts.door9:Fire("Open")
	end
end)

hook.Add("MapSweepersPlayerSignal", "jcms_TutorialRoom2", function(ply, signalId, at)
	if not IsValid(jcms.tutorialEnts.tobemarked) or at == jcms.tutorialEnts.tobemarked then
		jcms.tutorialEnts.door2:Fire("Open")
		
		if jcms.tutorialPhase == 0 then
			table.Empty(jcms.orders)
			jcms.orders.mine_breach = jcms.orders_tutorialInactive.mine_breach
			jcms.net_SendOrder("mine_breach", jcms.orders_tutorialInactive.mine_breach)
			jcms.tutorialPhase = 1

			local objectives = {
				{ type = "tutorialphase1", progress = 0, total = 0 }
			}
			jcms.net_ShareMissionData(objectives)
		end
	end
end)

hook.Add("MapSweepersPlayerOrder", "jcms_TutorialShootingRange", function(ply, orderId, a1, a2, a3, a4)
	if orderId == "carpetbombing" and jcms.tutorialPhase == 5  then
		timer.Simple(5, function()
			if jcms.tutorialPhase == 5 then
				jcms.tutorialPhase = 6
				jcms.orders.orbitalbeam = jcms.orders_tutorialInactive.orbitalbeam
				jcms.orders.orbitalbeam.cooldown = 5
				jcms.net_SendOrder("orbitalbeam", jcms.orders_tutorialInactive.orbitalbeam)

				local objectives = {
					{ type = "tutorialphase6", progress = 0, total = 0 }
				}
				jcms.net_ShareMissionData(objectives)
			end
		end)
	end
	
	if orderId == "orbitalbeam" and IsValid(jcms.tutorialRangeGunship) then
		jcms.tutorialRangeGunshipDying = true
	end
	
	if jcms.tutorialPhase == 7 then
		if orderId == "restock" then
			jcms.tutorialUsedRestock = true
		elseif orderId == "firstaid" then
			jcms.tutorialUsedFirstAid = true
		end
		
		if jcms.tutorialUsedRestock and jcms.tutorialUsedFirstAid then
			jcms.tutorialPhase = 8
			jcms.tutorialEnts.door7:Fire("Open")

			local objectives = {
				{ type = "tutorialphase8", progress = 0, total = 0 }
			}
			jcms.net_ShareMissionData(objectives)
		end
	end
	
	if jcms.tutorialPhase == 8 and orderId == "respawnbeacon" then
		if a1:DistToSqr( Vector("1472.481567 -1490.755127 0.031250") ) > 50^2 then
			return true
		else
			jcms.tutorialEnts.suicidehatch:Fire("Open")
			jcms.tutorialPos = a1 + Vector(0, 0, 24)
		end
	end
end)
