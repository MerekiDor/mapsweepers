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

-- // Drawing {{{

	function jcms.hud_npc_DrawHealthbars(ply, colHealth, colArmor)
		local sw, sh = ScrW(), ScrH()
		local barw = sw/6
		local pad = 4

		local hasArmor = ply:GetMaxArmor() > 0
		local healthFrac = math.Clamp(ply:Health() / ply:GetMaxHealth(), 0, 1)
		local armorFrac = hasArmor and math.Clamp(ply:Armor() / ply:GetMaxArmor(), 0, 1) or 0

		surface.SetAlphaMultiplier(0.25)
		surface.SetDrawColor(colHealth)
		surface.DrawOutlinedRect(sw/3-barw/2, sh-128, barw, 18)

		if hasArmor then
			surface.SetDrawColor(colArmor)
			surface.DrawOutlinedRect(sw/3-barw/2+64, sh-128-18, barw, 12)
		end
		
		surface.SetAlphaMultiplier(1)
		surface.SetDrawColor(colHealth)
		surface.DrawRect(sw/3-barw/2+pad, sh-128+pad, (barw-pad*2)*healthFrac, 24)

		if hasArmor then
			surface.SetDrawColor(colArmor)
			surface.DrawRect(sw/3-barw/2+64+pad, sh-128-18-pad, (barw-pad*2)*armorFrac, 12)
		end
		
		draw.SimpleText("// ".. math.ceil( math.max(0,ply:Health()) ), "jcms_medium", sw/3-barw/2+8, sh-128-4, colHealth, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		
		if hasArmor then
			draw.SimpleText("/ ".. math.ceil( math.max(0,ply:Armor()) ), "jcms_medium", sw/3-barw/2+8+64, sh-128-4-24, colArmor, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		end
		surface.SetAlphaMultiplier(1)

		if jcms.util_IsPVP() then
			local bop = math.abs( math.sin(CurTime()*5) )*6
			draw.SimpleText("#jcms.pvp_npctip", jcms.util_IsLowRes() and "jcms_small_bolder" or "jcms_medium", sw/2, sh - 16 - bop, colArmor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end
	end

	function jcms.hud_npc_DrawTargetIDs(col, colAlt)
		local myPVPTeam = jcms.locPly:GetNWInt("jcms_pvpTeam", -1)

		local sw, sh = ScrW(), ScrH()
		local ep = EyePos()

		local minDist, minDistPly, minDistPlySV

		for i, ply in ipairs(player.GetAll()) do
			if ply:Team() == 1 and ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE and (myPVPTeam == -1 or ply:GetNWInt("jcms_pvpTeam", -1) ~= myPVPTeam) then
				local v = ply:WorldSpaceCenter()
				local sv = v:ToScreen()
				local dist = ep:Distance(v)
				local distToCh = math.Distance(sv.x, sv.y, sw/2, sh/2)
				
				if distToCh <= 48 then
					surface.SetDrawColor(col)
					jcms.draw_Circle(sv.x, sv.y, 24, 24, 1, 18)

					if not minDist or distToCh < minDist then
						minDistPly = ply
						minDist = distToCh
						minDistPlySV = sv
					end
				else
					local size = math.Clamp(5000 / dist, 8, 64)
					surface.SetDrawColor(col)
					surface.DrawOutlinedRect(sv.x-size/2, sv.y-size/2, size, size, 1)
				end
			end
		end

		local eyeEnt = jcms.locPly:GetEyeTrace().Entity
		if IsValid(eyeEnt) then
			minDistPly = eyeEnt
			minDistPlySV = jcms.locPly:GetEyeTrace().HitPos:ToScreen()
		end

		if minDistPly and minDistPly:Health() > 0 then
			surface.SetDrawColor(colAlt)
			jcms.draw_Circle(minDistPlySV.x, minDistPlySV.y, 18, 18, 2, 12)

			local name = minDistPly.Nick and minDistPly:Nick() or minDistPly.PrintName or minDistPly:GetClass()
			draw.SimpleText(name, "jcms_medium", sw/2, sh*0.3, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

			local hasArmor = minDistPly.Armor
			local healthFrac = math.Clamp(minDistPly:Health()/minDistPly:GetMaxHealth(), 0, 1)
			local armorFrac = hasArmor and math.Clamp(minDistPly:Armor()/minDistPly:GetMaxArmor(), 0, 1) or 0

			local healthWidth = math.min(sw/2, minDistPly:GetMaxHealth())
			surface.SetDrawColor(col)
			surface.DrawOutlinedRect(sw/2-healthWidth/2-2, sh*0.3+4, healthWidth, 8)
			surface.DrawRect(sw/2-healthWidth/2, sh*0.3+6, healthWidth*healthFrac, 8)
			draw.SimpleText(math.ceil(minDistPly:Health()), "jcms_small_bolder", sw/2-healthWidth/2-4, sh*0.3+10, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			if hasArmor then
				local armorWidth = math.min(sw/2, minDistPly:GetMaxArmor())
				surface.SetDrawColor(colAlt)
				surface.DrawOutlinedRect(sw/2-armorWidth/2+2, sh*0.3+16, armorWidth, 8)
				surface.DrawRect(sw/2-armorWidth/2+4, sh*0.3+18, armorWidth*armorFrac, 8)
				draw.SimpleText(math.ceil(minDistPly:Armor()), "jcms_small_bolder", sw/2-armorWidth/2, sh*0.3+24, colAlt, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		surface.SetAlphaMultiplier(1)
	end

	function jcms.hud_npc_DrawCrosshair(ply, weapon, col, colAlt, colSpecial)
		local sw, sh = ScrW(), ScrH()
		local chSize = 16
		local chThick = 2
		
		surface.SetAlphaMultiplier(0.15)
		surface.SetDrawColor(col)
		surface.DrawOutlinedRect(sw/2-chSize/2, sh/2-chSize/2, chSize, chSize)
		
		surface.SetAlphaMultiplier(1)
		surface.SetDrawColor(col)
		surface.DrawRect(sw/2-chSize/2-8+chThick, sh/2-chThick/2, 8, chThick)
		surface.DrawRect(sw/2+chSize/2-chThick, sh/2-chThick/2, 8, chThick)
		surface.DrawRect(sw/2-chThick/2, sh/2+chSize/2-chThick, chThick, 8)
		
		if IsValid(weapon) then
			local clip, clipmax = weapon:Clip1(), weapon:GetMaxClip1()
			if clipmax == - 1 then
				clip = ply:GetAmmoCount( weapon:GetPrimaryAmmoType())
				clipmax = clip
			end
			
			if clip > -1 and clipmax > 0 then
				surface.SetAlphaMultiplier(1-clip/clipmax)
				draw.SimpleText(clip, "jcms_medium", sw/2 - chSize - 8, sh/2, clip/clipmax<0.4 and colAlt or col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
			
			local clip2, clip2max = weapon:Clip2(), weapon:GetMaxClip2()
			if clip2max == - 1 then
				clip2 = ply:GetAmmoCount( weapon:GetSecondaryAmmoType())
				clip2max = clip2
			end
			
			if clip2 > -1 and clip2max > 0 then
				surface.SetAlphaMultiplier(1)
				draw.SimpleText(clip2, "jcms_medium", sw/2 + chSize + 8, sh/2, colAlt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			local specials = weapon:GetNWInt("jcms_npcspecial", 0)
			if specials > 0 then
				surface.SetAlphaMultiplier(1)
				local binding = tostring(input.LookupBinding("+menu") or "???"):upper()
				draw.SimpleText("["..binding.."] x" .. specials, "jcms_medium", sw/2, sh/2 + 24, colSpecial, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		surface.SetAlphaMultiplier(1)
	end

	function jcms.hud_npc_DrawCrosshairMelee(ply, weapon, col)
		local sw, sh = ScrW(), ScrH()
		local chSize = 48
		surface.SetAlphaMultiplier(0.15)
		surface.SetDrawColor(col)
		surface.DrawOutlinedRect(sw/2-chSize/2, sh/2-chSize/2, chSize, chSize)
		
		surface.SetAlphaMultiplier(1)
		surface.SetDrawColor(col)
		for i=1, 3 do
			surface.DrawRect(sw/2 - chSize/2 + chSize/4*i - 2, sh/2 - chSize/2 - 16 + 8*i, 4, chSize)
		end

		if IsValid(weapon) then
			local specials = weapon:GetNWInt("jcms_npcspecial", 0)
			if specials > 0 then
				surface.SetAlphaMultiplier(1)
				local binding = tostring(input.LookupBinding("+menu") or "???"):upper()
				draw.SimpleText("["..binding.."] x" .. specials, "jcms_medium", sw/2, sh/2 + 48, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		surface.SetAlphaMultiplier(1)
	end

	function jcms.hud_npc_DrawSweeperStatus(col, colAlt)
		local myPVPTeam = jcms.locPly:GetNWInt("jcms_pvpTeam", -1)
		local scoreboardAnim = 0

		local sw = ScrW()
		local sweepers = {}
		for i, ply in ipairs(player.GetAll()) do
			if ply:GetNWInt("jcms_desiredteam", 0) == 1 then
				table.insert(sweepers, ply)
			end
		end

		local count = #sweepers
		for i, sweeper in ipairs(sweepers) do
			if not (myPVPTeam == -1 or sweeper:GetNWInt("jcms_pvpTeam", -1) ~= myPVPTeam) then continue end
			local x = Lerp(scoreboardAnim, sw/2 - 20 * (count - 1) + (i-1) * 40, 300)
			local y = Lerp(scoreboardAnim, 16, 100 + i*64)
			if sweeper:Alive() and sweeper:GetObserverMode() == OBS_MODE_NONE then
				local class = sweeper:GetNWString("jcms_class", "infantry")
				
				local healthFrac = math.Clamp(sweeper:Health()/sweeper:GetMaxHealth(), 0, 1)
				local armorFrac = math.Clamp(sweeper:Armor()/sweeper:GetMaxArmor(), 0, 1)
				local healthWidth = Lerp(scoreboardAnim, 32, sweeper:GetMaxHealth())
				local armorWidth = Lerp(scoreboardAnim, 32, sweeper:GetMaxArmor())
				
				surface.SetAlphaMultiplier(healthFrac/2)
				surface.SetDrawColor(col)
				surface.DrawOutlinedRect(x - 16, y+38, healthWidth, 4, 1)
				surface.SetAlphaMultiplier(1)
				surface.SetDrawColor(col)
				surface.DrawRect(x - 16, y+38, healthWidth*healthFrac, 4, 1)
				
				surface.SetAlphaMultiplier(armorFrac/2)
				surface.SetDrawColor(colAlt)
				surface.DrawOutlinedRect(x - 16, y+46, armorWidth, 4, 1)
				surface.SetAlphaMultiplier(1)
				surface.SetDrawColor(colAlt)
				surface.DrawRect(x - 16, y+46, armorWidth*armorFrac, 4, 1)
				
				if sweeper:Team() == 2 then
					draw.SimpleText("NPC", "jcms_small_bolder", x, y + 16, colAlt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				else
					local classmat = jcms.mat_GetClassMat(class)
					if not classmat:IsError() then
						classmat = jcms.mat_GetClassMat("recon")
					end
					
					surface.SetMaterial(classmat)
					if armorFrac <= 0 then
						surface.SetDrawColor(col)
						surface.DrawTexturedRectRotated(x + math.random()*4 - 2, y + 16 + math.random()*4 - 2, 32, 32, math.random()*2-1)
					else
						surface.SetDrawColor(colAlt)
						surface.DrawTexturedRectRotated(x, y + 16, 32, 32, 0)
					end
				end
			else
				draw.SimpleText(sweeper:GetNWBool("jcms_evacuated") and "^" or "X", "jcms_medium", x, y + 16, colAlt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			if scoreboardAnim > 0.01 then
				local colAlpha = ColorAlpha(col, scoreboardAnim*500)
				draw.SimpleText(sweeper:Nick(), "jcms_medium", x + 32, y + 8, colAlpha)
			end
		end

		local respawns = jcms.util_GetRespawnCount()
		if respawns > 0 then
			draw.SimpleText(language.GetPhrase("jcms.sweeperrespawns"):format(respawns), "jcms_small_bolder", sw/2, Lerp(scoreboardAnim, 72, 16), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
		surface.SetAlphaMultiplier(1)
	end

	function jcms.hud_npc_DrawObjectives(col, colAlt)
		local objs = jcms.objectives
		if objs and #objs > 0 then
			local y = 24

			draw.SimpleText("#jcms.theirprogress", "jcms_medium", 32, y, col)
			y = y + 32

			for i, objective in ipairs(objs) do
				local str = jcms.objective_Localize(objective.type)
				local x, n = objective.progress, objective.n
				local completed = objective.completed

				draw.SimpleText(str, "jcms_small_bolder", 48, y, completed and colAlt or col)
				surface.SetDrawColor(completed and colAlt or col)
				surface.DrawOutlinedRect(24, y, 16, 16, 1)
				if completed then
					surface.DrawRect(24+2, y+2, 16-4, 16-4)
				end

				if x and n>0 then
					local progress = math.Clamp(x / n, 0, 1)
					local progressString
					if objective.percent then
						progressString = string.format("%d%%  ", progress*100)
					else
						progressString = string.format("%d/%d  ", x, n)
					end

					local tw = draw.SimpleText(progressString, "jcms_small", 48, y + 18, completed and colAlt or col)
					local barw = 150 - tw

					surface.DrawOutlinedRect(48 + tw, y + 22, barw, 6)
					surface.DrawRect(48 + tw + 2, y + 22 + 2, barw*progress, 6)

					y = y + 48
				else
					y = y + 24
				end
			end
		end
	end

	function jcms.hud_npc_DrawDamage(col, colAlt)
		local y = ScrH() / 2 + 32
		local ct = CurTime()

		for i, dmg in ipairs(jcms.hud_npc_damages) do
			local a = math.ease.InOutBack( math.Clamp( (dmg.time - ct + 2)*2, 0, 1) )
			surface.SetAlphaMultiplier(a)

			local name = dmg.entName or "???"
			local x = ScrW()/2 + 48*a
			local tw = draw.SimpleText(name, "jcms_small_bolder", x, y, col)

			local dmgCol = col
			if ct - dmg.time < 0.25 then
				dmgCol = colAlt
			end

			a = math.Clamp(a, 0, 1)

			if dmg.health > 0 then
				draw.SimpleText(language.GetPhrase("jcms.damagedealt"):format(dmg.health), "jcms_small", x + tw + 16, y, dmgCol)
				if dmg.shields > 0 then
					y = y + 12 * a
				end
			end

			if dmg.shields > 0 then
				draw.SimpleText(language.GetPhrase("jcms.damagedealt_shield"):format(dmg.shields), "jcms_small", x + tw + 16, y, dmgCol)
			end

			y = y + 24 * a
		end

		surface.SetAlphaMultiplier(1)
	end

-- // }}}

-- // Damage Report {{{

	jcms.hud_npc_damages = {}

	function jcms.hud_npc_AddDamage(ent, isShields, n)
		if not IsValid(ent) then
			return
		end

		local ct = CurTime()
		local newRequired = true
		for i, dmg in ipairs(jcms.hud_npc_damages) do
			if dmg.ent == ent and ct - dmg.time <= 1.5 then
				dmg.time = ct
				if isShields then
					dmg.shields = dmg.shields + n
				else
					dmg.health = dmg.health + n
				end
				newRequired = false
				break
			end
		end

		if newRequired then
			local entName = ent.PrintName or tostring(ent)
			if ent:IsPlayer() then
				entName = ent:Name()
			end

			table.insert(jcms.hud_npc_damages, {
				entName = entName,
				ent = ent,
				time = ct,
				health = isShields and 0 or n,
				shields = isShields and n or 0
			})
		end

		for i=#jcms.hud_npc_damages, 1, -1 do
			if (ct - jcms.hud_npc_damages[i].time) > 2 then
				table.remove(jcms.hud_npc_damages, i)
			end
		end
	end

-- // }}}

-- // Other {{{

	function jcms.hud_npc_SpectatorDraw(col, colAlt)
		local sw = ScrW()
		jcms.hud_npc_DrawObjectives(col, colAlt)
		jcms.hud_npc_DrawSweeperStatus(col, colAlt)

		local tg = jcms.locPly:GetObserverTarget()
		if IsValid(tg) and tg:IsPlayer() then
			local tgclass = tg:GetNWString("jcms_class", "infantry")

			surface.SetDrawColor(col)
			local tw = draw.SimpleText(language.GetPhrase("jcms.spectating") .. " " .. tg:Nick(), "jcms_big", ScrW()/2 + 16, ScrH() - 84, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			
			local classmat = jcms.mat_GetClassMat(tgclass)
			if not classmat:IsError() then
				surface.SetMaterial(classmat)
				surface.DrawTexturedRectRotated(ScrW()/2 - tw/2 - 16, ScrH() - 84 - 16, 32, 32, 0)
			end
		
			local healthFrac = math.Clamp(tg:Health() / tg:GetMaxHealth(), 0, 1)
			local armorFrac = math.Clamp(tg:Armor() / tg:GetMaxArmor(), 0, 1)
			
			local healthWidth = math.min(sw/2, tg:GetMaxHealth()*2)
			local armorWidth = math.min(sw/2, tg:GetMaxArmor()*2)

			surface.SetDrawColor(col)
			surface.DrawOutlinedRect(ScrW()/2 - healthWidth/2, ScrH() - 78, healthWidth, 12, 1)
			surface.DrawRect(ScrW()/2 - healthWidth/2 + 2, ScrH() - 78 + 2, (healthWidth-4)*healthFrac, 12, 1)

			surface.SetDrawColor(colAlt)
			surface.DrawOutlinedRect(ScrW()/2 - armorWidth/2, ScrH() - 78 + 16, armorWidth, 8, 1)
			surface.DrawRect(ScrW()/2 - armorWidth/2 + 2, ScrH() - 78 + 2 + 16, (armorWidth-4)*armorFrac, 8, 1)

			jcms.hud_SpectatorDraw_ChangeClass(col, colAlt) --TODO: Needs actual proper integration, doesn't render rn.
		end


		local f2 = math.ease.InOutCubic(jcms.hud_dead)
		cam.Start2D()
			surface.SetDrawColor(0, 0, 0, 255*f2)
			surface.DrawRect(-2,-2,ScrW()+4,ScrH()+4)
		cam.End2D()
		surface.SetAlphaMultiplier(1)
	end

	--[[
	hook.Add("PreDrawHalos", "jcms_sweeperHalos", function()
		local classData = jcms.class_GetLocPlyData()

		if classData and classData.faction then
			local sweepers = team.GetPlayers(1)
			local brokenSweepers = {}

			for i=#sweepers, 1, -1 do
				local sweeper = sweepers[i]
				if not (sweeper:Alive() and sweeper:GetObserverMode() == OBS_MODE_NONE) then
					table.remove(sweepers, i)
				else
					local haloEnt = sweeper
					
					if IsValid( sweeper:GetVehicle() ) then
						haloEnt = sweeper:GetVehicle()
					elseif IsValid( sweeper:GetNWEntity("jcms_vehicle") ) then
						local veh = sweeper:GetNWEntity("jcms_vehicle")
						haloEnt = veh
						
						if veh.GetTankOtherPart then
							table.insert(sweepers, i+1, veh:GetTankOtherPart())
						end
					end

					if sweeper:Armor() <= 0 then
						table.remove(sweepers, i)
						table.insert(brokenSweepers, haloEnt)
					else
						sweepers[i] = haloEnt
					end
				end
			end

			local add1 = (math.cos( CurTime() * 6 ) + 1) / 2 * 64
			halo.Add(sweepers, Color(255, add1, add1), 1, 1, 1, true, true)

			local add2 = (math.cos( CurTime() * 12 ) + 1) / 2 * 64
			halo.Add(brokenSweepers, Color(add2, 100 + add2*2, 200 + add2), 2, 2, 2, true, true)
		end
	end)
	--]]

-- // }}}