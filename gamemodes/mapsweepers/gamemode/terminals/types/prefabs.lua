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

local terms = jcms.terminal_modeTypes

if SERVER then
	terms.pin = {
		command = function(ent, cmd, data, ply)
			if cmd == 0 then
				jcms.terminal_ToPurpose(ent)
				return true
			elseif cmd >= 1 and cmd <= 9 or cmd == 11 then
				if #data < 4 then
					local entering = cmd==11 and "0" or tostring(cmd)
					local newdata =  data .. entering
					return true, newdata
				end
			elseif cmd == 10 then
				if data == ent.jcms_pin then
					jcms.terminal_Unlock(ent, ply, false)
					return true, ""
				else
					jcms.terminal_Punish(ent, ply)
					ent:EmitSound("buttons/button8.wav", 75, 110, 1.0)
					return true, ""
				end
			elseif cmd == 12 then
				return true, ""
			end
		end
	}

	-- Normal terminals
	terms.cash_cache = {
		command = function(ent, cmd, data, ply)
			if ent:GetNWBool("jcms_terminal_locked") then
				if cmd == 0 then
					jcms.terminal_ToUnlock(ent)
					return true
				end
			else
				local counts = { 10, 100, 1000, math.huge }
				local count = counts[ (cmd-1)%4 + 1 ]
				local depositing = cmd > 4

				if depositing then
					local plyCash = ply:GetNWInt("jcms_cash")
					count = math.min(count, plyCash)
					ply:SetNWInt("jcms_cash", plyCash - count)
					return count > 0, (tonumber(data) or 0) + count
				else
					local terminalCash = tonumber(data) or 0
					count = math.min(count, terminalCash)
					ply:SetNWInt("jcms_cash", ply:GetNWInt("jcms_cash") + count)
					ent:SetNWInt("cash", terminalCash - count)
					return count > 0, terminalCash - count
				end
			end
		end,
		
		generate = function(ent)
			local rn = ent:EntIndex()%6
			return (4+rn) * 500
		end
	}

	terms.gambling = {
		command = function(ent, cmd, data, ply)
			local cash = ply:GetNWInt("jcms_cash", 0)

			if cash > 0 then
				local won = math.random() < 0.5
				ply:SetNWInt("jcms_cash", won and cash*2 or 0)

				ent:EmitSound(won and "garrysmod/content_downloaded.wav" or "buttons/button8.wav")

				if cash >= 10000 and not won then
					timer.Simple(0.8, function()
						if IsValid(ent) then
							
							util.BlastDamage(ent, ent, ent:WorldSpaceCenter(), 200, cash / 1000)
							local ed = EffectData()
							ed:SetMagnitude(1)
							ed:SetOrigin(ent:WorldSpaceCenter())
							ed:SetRadius(450)
							ed:SetNormal(jcms.vectorUp)
							ed:SetFlags(1)
							util.Effect("Explosion", ed)

							ply:ViewPunch( AngleRand(-30, 30) )

						end
					end)
				end

				if cash >= 150 and not won then
					jcms.announcer_SpeakChance(0.6, jcms.ANNOUNCER_HA)
					jcms.net_NotifyGeneric(ply, jcms.NOTIFY_LOST, jcms.util_CashFormat(cash) .. " J")
				end

				return true, won and 1 or 2
			else
				return false, 0
			end
		end,
		
		generate = function(ent)
			-- Announcer JonahSoldier warns us not to touch the gambling machine
			local timerId = "jcms_dontTouchGambling" .. ent:EntIndex()
			timer.Create(timerId, 0.5, 0, function()
				if not IsValid(ent) then
					timer.Remove(timerId)
				else
					ent.jcms_warnedAboutGambling = ent.jcms_warnedAboutGambling or {}
					for i, sweeper in ipairs(jcms.GetAliveSweepers()) do
						if not ent.jcms_warnedAboutGambling[sweeper] then
							local tr = sweeper:GetEyeTrace()
							if (tr.Entity == ent) and (tr.StartPos:DistToSqr(tr.HitPos) <= 230*230) then
								ent.jcms_warnedAboutGambling[sweeper] = true
								jcms.announcer_Speak(jcms.ANNOUNCER_DONTTOUCH, sweeper)
							end
						end
					end
				end
			end)
		end
	}

	terms.upgrade_station = {
		command = function(ent, cmd, data, ply)
			local upgradeValues = string.Split(data, " ")

			local cost = 1000
			for i, value in ipairs(upgradeValues) do
				if value == "x" then
					cost = cost + 500
				end
			end

			if ply:GetNWInt("jcms_cash") < cost then
				return false
			end

			if tonumber(upgradeValues[ cmd ]) then
				local value = tonumber(upgradeValues[ cmd ])
				if cmd == 1 then
					ply.jcms_incendiaryUpgrade = (ply.jcms_incendiaryUpgrade and ply.jcms_incendiaryUpgrade + 1) or 1
					-- Incendiary Ammo upgrade
					ply.jcms_damageEffect = function(ply, target, dmgInfo)
						if not jcms.team_JCorp(target) and not(target:GetClass() == "jcms_fire" or target:GetClass() == "gmod_hands" or target:GetClass() == "predicted_viewmodel") and not target:IsWeapon() then 
							target:Ignite(ply.jcms_incendiaryUpgrade * 2)
						end
					end
				elseif cmd == 2 then
					-- Shield upgrade
					ply:SetMaxArmor( math.floor(ply:GetMaxArmor() * 1.5) )
				elseif cmd == 3 then
					-- Explosive Ammo upgrade
					ply.jcms_explosiveUpgrade = (ply.jcms_explosiveUpgrade and ply.jcms_explosiveUpgrade + 1) or 1
					local expl = ply.jcms_explosiveUpgrade --readability

					ply.jcms_EntityFireBullets = function(ent, bulletData)
						bulletData.TracerName = nil
						bulletData.Tracer = math.huge
				
						local ogCallback = bulletData.Callback
						bulletData.Callback = function(attacker, tr, dmgInfo)
							if type(ogCallback) == "function" then
								ogCallback(attacker, tr, dmgInfo)
							end

							local dmg = dmgInfo:GetDamage()
							local blastRadius, blastDmg = math.max(dmg^(2/3) * 5 * expl, 66), math.max(expl * dmg/4, 2)
							
							if SERVER then
								local effectdata = EffectData()
								local angles = attacker:EyeAngles()
								local origin = attacker:EyePos() + angles:Right() * 1 + angles:Up() * -2 + angles:Forward() * 16
								effectdata:SetStart(origin)
								effectdata:SetScale(math.random(6500, 9000))
								effectdata:SetMagnitude(blastRadius)
								effectdata:SetAngles(tr.Normal:Angle())
								effectdata:SetOrigin(tr.HitPos)
								effectdata:SetFlags(5)
								util.Effect("jcms_bolt", effectdata, true, true)
							end
				
							util.BlastDamage(ent, ent, tr.HitPos, blastRadius, blastDmg) --Roughly 50 rad, 5dmg for an smg | 100rad, 20dmg for a sniper
						end
					end
				end

				upgradeValues[cmd] = "x"
				ent:EmitSound("items/medshot4.wav", 100, 80, 1)
				ply:SetNWInt("jcms_cash", ply:GetNWInt("jcms_cash") - cost)
				return true, table.concat(upgradeValues, " ")
			else
				return false
			end
		end,

		generate = function(ent)
			local upgradeList = {
				health = { 5, 10, 15 },
				shield = { 25, 25, 25 },
				damage = { 0.05, 0.1, 0.2 }
			}

			local order = table.GetKeys(upgradeList)
			table.Shuffle(order)

			for i, category in ipairs(order) do
				local upgradeTiers = upgradeList[ category ]
				upgradeList[category] = upgradeTiers[i]
			end

			return string.format("%d %d %.2f", upgradeList.health, upgradeList.shield, upgradeList.damage)
		end
	}

	terms.respawn_chamber = {
		command = function(ent, cmd, data, ply)
			if cmd == 0 and ent:GetNWBool("jcms_terminal_locked") then
				jcms.terminal_ToUnlock(ent)
				return true
			end
			return false
		end,

		generate = function(ent)
			local locked = ent:GetNWBool("jcms_terminal_locked") and not ent.respawnBeaconUsedUp

			if not locked then
				if IsValid(ent.jcms_hackedBy) then
					ent:SetNWInt("jcms_pvpTeam", ent.jcms_hackedBy:GetNWInt("jcms_pvpTeam", -1) )
				end

				ent:SetColor( jcms.util_IsPVP() and Color(143, 143, 143) or Color(255, 143, 143) ) --Neutral col in pvp. Not team-dependent because that'd benefit camping more.

				if not ent.initializedAsRespawnBeacon and jcms.director then
					table.insert(jcms.director.respawnBeacons, ent)
					ent.initializedAsRespawnBeacon = true
				end
			end

			return locked and "0" or "1"
		end
	}

	terms.gunlocker = {
		command = function(ent, cmd, data, ply)
			local locked = ent:GetNWBool("jcms_terminal_locked")

			if cmd == 1 and not locked and data ~= "" then
				local oldValue = ply.jcms_canGetWeapons
				ply.jcms_canGetWeapons = true
				ply:Give(ent.jcms_weaponclass)
				ply.jcms_canGetWeapons = oldValue

				ent:ResetSequence("idle_open")
				ent:SetCycle(0)
				ent:EmitSound("doors/door_latch1.wav", 75, 137, 1)

				local gunstats = jcms.gunstats_Get(ent.jcms_weaponclass)
				if gunstats then
					jcms.net_NotifyGeneric(ply, jcms.NOTIFY_OBTAINED, gunstats.name or "#"..ent.jcms_weaponclass)
				end
				return true, ""
			elseif cmd == 2 and locked then
				jcms.terminal_ToUnlock(ent)
				return true
			end
		end,
		
		generate = function(ent)
			if not ent.jcms_weaponclass then
				local starterCash = jcms.util_IsPVP() and jcms.cvar_cash_start_pvp:GetInt() or jcms.cvar_cash_start:GetInt()
				local evacCash = jcms.cvar_cash_evac:GetInt()
				local winCash = jcms.cvar_cash_victory:GetInt()

				--not accounting for clerks because I couldn't be bothered.
				local totalCash = starterCash + (evacCash + winCash) * jcms.runprogress.winstreak

				local weights = {}
				for k,v in pairs(jcms.weapon_prices) do
					if v <= 0 then continue end
					if not jcms.gunstats_Get(k) then continue end
					--weights[k] = (v <= 3200 and (v/5) or (math.min(20000, v)^1.12 + 6000)) / 100
					local cost = v * jcms.util_GetLobbyWeaponCostMultiplier()

					if cost < totalCash * 0.5 then							--Not possible
						weights[k] = nil
					elseif cost < totalCash then							--Rapid fall off
						weights[k] = ((cost*2 / totalCash) - 1)^3 
					elseif cost >= totalCash and cost <= totalCash * 2 then	--Equally likely
						weights[k] = 1 
					else												--Fall-off but never reach 0
						weights[k] = 1 / (cost / totalCash - 1)
					end
				end

				local chosen = jcms.util_ChooseByWeight(weights)
				
				if not chosen then
					chosen = "weapon_crowbar"
				end

				ent.jcms_weaponclass = chosen
			end

			return ent.jcms_weaponclass
		end
	}
	
	terms.shop = {
		command = function(ent, cmd, data, ply)
			local weapon = ply:GetActiveWeapon()
			local balance = ply:GetNWInt("jcms_cash")
			
			if IsValid(weapon) then
				local dist2 = ply:EyePos():DistToSqr(ent:WorldSpaceCenter())

				if dist2 > 256*256 then
					return false
				end

				if cmd == 1 then
					-- Selling current weapon
					local gunPriceMul = ent:GetGunPriceMul()
					local weaponPrice = jcms.weapon_prices[ weapon:GetClass() ]
					
					if not weaponPrice then
						return false
					else
						jcms.giveCash(ply, math.max(1, math.floor(weaponPrice*gunPriceMul*0.25)))
						ply:StripWeapon(weapon:GetClass())

						-- If the ammo type of the weapon is useless, we sell it.
						for i=1, 2 do
							local ammoType = i==1 and weapon:GetPrimaryAmmoType() or weapon:GetSecondaryAmmoType()

							if ammoType >= 0 then
								local useless = jcms.isAmmoTypeUseless(ply, ammoType)
								if useless then
									local count = ply:GetAmmoCount(ammoType)
									ply:SetAmmo(0, ammoType)
									jcms.giveCashForUselessAmmo(ply, ammoType, count)
								end
							end
						end

						return true
					end
					
				elseif cmd == 2 or cmd == 4 then
					-- Buying primary (cmd=2) or secondary (cmd=4) ammo
					local primary = cmd==2
					local ammoType = primary and weapon:GetPrimaryAmmoType() or weapon:GetSecondaryAmmoType()
					
					if ammoType and ammoType > 0 then
						local ammoTypeName = game.GetAmmoName(ammoType)
						local ammoPrice = jcms.weapon_ammoCosts[ ammoTypeName:lower() ] or jcms.weapon_ammoCosts._DEFAULT
						local ammoPriceMul = ent:GetAmmoPriceMul()
						
						local clipSize = primary and weapon:GetMaxClip1() or weapon:GetMaxClip2()
						local weaponModeTable = (primary and weapon.Primary) or (not primary and weapon.Secondary)

						if clipSize < 0 then
							clipSize = weaponModeTable and tonumber(weaponModeTable.DefaultClip) or 1
						end

						clipSize = math.max(clipSize, 1)
						
						local totalPrice = math.ceil(math.ceil(ammoPrice * clipSize)*ammoPriceMul)
						if balance >= totalPrice then
							ply:GiveAmmo(clipSize, ammoType)
							ply:SetNWInt("jcms_cash", balance - totalPrice)
							return true
						else
							return false
						end
					end
				elseif cmd == 3 or cmd == 5 then
					-- Selling primary (cmd=3) or secondary (cmd=5) ammo
					local primary = cmd==3
					local ammoType = primary and weapon:GetPrimaryAmmoType() or weapon:GetSecondaryAmmoType()
					
					if ammoType and ammoType > 0 then
						local ammoTypeName = game.GetAmmoName(ammoType)
						local ammoPrice = jcms.weapon_ammoCosts[ ammoTypeName:lower() ] or jcms.weapon_ammoCosts._DEFAULT
						local ammoPriceMul = ent:GetAmmoPriceMul()
						local plyAmmo = ply:GetAmmoCount(ammoType)
						
						local clipSize = primary and weapon:GetMaxClip1() or weapon:GetMaxClip2()
						local weaponModeTable = (primary and weapon.Primary) or (not primary and weapon.Secondary)

						if clipSize < 0 then
							clipSize = weaponModeTable and tonumber(weaponModeTable.DefaultClip) or 1
						end

						clipSize = math.max(clipSize, 1)
						
						local totalPrice = math.floor( math.max(1, ammoPrice*clipSize*0.5*ammoPriceMul) )
						if plyAmmo >= clipSize then
							ply:SetAmmo(plyAmmo-clipSize, ammoType)
							jcms.giveCash(ply, totalPrice)
							return true
						else
							return false
						end
					end
				end
			end
		end
	}
end

if CLIENT then
	terms.pin = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		
		local btnId
		if not ent:GetNWBool("jcms_terminal_locked") then
			local vw, vh = w*0.8, 64
			local vx, vy = (w-vw)/2, (h-vh)/2

			surface.SetDrawColor(color_bg)
			surface.DrawRect(vx, vy, vw, vh)
			render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)

			local matrix = jcms.terminal_getGlitchMatrix(8)
			cam.PushModelMatrix(matrix, true)
				surface.SetDrawColor(color_fg)
				surface.DrawRect(vx, vy + vh, vw, 4)
				draw.SimpleText("#jcms.terminal_unlocked", "jcms_hud_medium", vx + vw/2, vy + vh/2 - 4, CurTime() % 0.25 < 0.125 and color_accent or color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.PopModelMatrix()
		else
			local vh = math.min(w, h) * 0.75
			local vw = vh * 0.66
			local vx, vy = (w-vw)/2, (h-vh)/4*3

			surface.SetDrawColor(color_bg)
			surface.DrawRect(vx, vy, vw, vh)
			render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			
			local currentPin = modedata or "" 
			currentPin = currentPin .. string.rep("_", 4-#currentPin)

			local entryHeight = 64
			surface.DrawRect(vx + 16, vy + 16, vw - 32, entryHeight)
			draw.SimpleText(currentPin, "jcms_hud_medium", vx + vw/2, vy + 16 + entryHeight/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local buttonWidth, buttonHeight = (vw-32)/3, (vh - entryHeight - vy + 16) / 4
			local pad = 4
			local i = 0

			local strings = { 1, 2, 3, 4, 5, 6, 7, 8, 9, "OK", 0, "CLR" }
			local notbefore = true

			for y=1,4 do
				for x=1,3 do
					i = i + 1
					local bx = vx + (vw-buttonWidth*3)/2 + buttonWidth*(x-1) + pad
					local by = vy + 32 + entryHeight + buttonHeight*(y-1) + pad
					local this = notbefore and (mx>=bx and my>=by and mx<=bx+buttonWidth and my<=by+buttonHeight)
					if this then
						local matrix = jcms.terminal_getGlitchMatrix(8)
						cam.PushModelMatrix(matrix, true)
						surface.SetDrawColor(color_fg)
						notbefore = false
						btnId = i
					end
					surface.DrawRect(bx, by, buttonWidth-pad*2, buttonHeight-pad*2)
					draw.SimpleText(strings[i], "jcms_hud_small", bx + buttonWidth/2, by + buttonHeight/2, this and color_accent or color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					if this then
						surface.SetDrawColor(color_bg)
						cam.PopModelMatrix()
					end
				end
			end
		end
		render.OverrideBlend( false )
		return btnId
	end


	terms.cash_cache = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		surface.SetDrawColor(color_bg)
		surface.DrawRect(0,0,w,96)

		local hoveredBtn
		local mDeposit, mi = mx>w/2 and true or false, math.floor( (my - 164 + 54)/54 )
		if ent:GetNWBool("jcms_terminal_locked") then
			surface.DrawRect(w/4,104,w/2,64)

			if mx >= w/4 and mx <= w/2*3 and my >= 104 and my <= 104+64 then
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				surface.SetDrawColor(color_fg)
				surface.DrawOutlinedRect(w/4,104,w/2,64,3)
				hoveredBtn = 0
			end
		else
			for i=1, 4 do
				surface.DrawRect(1,164 + 54*(i-1),w/2-3,48)
				surface.DrawRect(w/2+3,164 + 54*(i-1),w/2-4,48)
			end

			if mi >= 1 and mi <= 4 and mx >= 0 and mx <= w then
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				surface.SetDrawColor(color_fg)
				surface.DrawOutlinedRect(mDeposit and w/2+3 or 1,164 + 54*(mi-1),w/2-4,48,3)
				hoveredBtn = mi + (mDeposit and 4 or 0)
			end
		end

		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
		draw.SimpleText("#jcms.terminal_cashcache", "jcms_hud_small", w/2, -8, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		local matrix = jcms.terminal_getGlitchMatrix(8)
		local cash = tonumber(modedata) or 0
		cam.PushModelMatrix(matrix, true)
			local tw = draw.SimpleText("#jcms.terminal_cashcache", "jcms_hud_small", w/2, -8, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			local tw = draw.SimpleText(jcms.util_CashFormat(cash) .. " ", "jcms_hud_big", w/2 - 16, 48, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			surface.SetDrawColor(color_fg)
			jcms.draw_IconCash("jcms_hud_medium", w/2 + tw/2 + 16, 48, 6)

			if ent:GetNWBool("jcms_terminal_locked") then
				draw.SimpleText("#jcms.terminal_unlock", "jcms_hud_small", w/2, 104+32, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			else
				draw.SimpleText("#jcms.terminal_withdraw", "jcms_hud_small", w/4, 144, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("#jcms.terminal_deposit", "jcms_hud_small", w/4*3, 144, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				local strings = { "10", "100", "1000", language.GetPhrase("jcms.terminal_all") }
				for i=1, 4 do
					draw.SimpleText("-" .. strings[i], "jcms_hud_small", w/4, 164 + 54*(i-1)+24, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					draw.SimpleText("+" .. strings[i], "jcms_hud_small", w/4*3, 164 + 54*(i-1)+24, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end
		cam.PopModelMatrix()
		render.OverrideBlend(false)
		return hoveredBtn
	end

	terms.gambling = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		local color_dark = Color(60, 22, 109)
		
		local swayAngle = CurTime() % 1 * math.pi * 2
		local swayX, swayY = math.cos(swayAngle)*8, math.sin(swayAngle)*8

		local str1 = "#jcms.terminal_gambling1"
		local str2 = "#jcms.terminal_gambling2"
		local str3 = "#jcms.terminal_gambling3"
		draw.SimpleText("$", "jcms_hud_superhuge", w/4+swayX, 48+swayY, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("$", "jcms_hud_huge", w*3/4+swayX, 96+swayY, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(str1, "jcms_hud_big", w/2+swayX, swayY, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(str2, "jcms_hud_medium", w/2+swayX, 96+swayY, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		local mycash = jcms.util_CashFormat( jcms.locPly:GetNWInt("jcms_cash", 0) ) .. " J"
		local cashFont = "jcms_hud_medium"
		if #mycash <= 3 then
			cashFont = "jcms_hud_superhuge"
		elseif #mycash <= 7 then
			cashFont = "jcms_hud_huge"
		elseif #mycash <= 9 then
			cashFont = "jcms_hud_big"
		elseif #mycash <= 12 then
			cashFont = "jcms_hud_score"
		end

		draw.SimpleText(mycash, cashFont, w+swayX, 220+swayY, color_bg, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

		local bsize = 150
		surface.SetDrawColor(color_bg)
		jcms.draw_Circle(bsize+swayX, h-bsize-32+swayY, bsize, bsize, 24, 24)

		local matrix = jcms.terminal_getGlitchMatrix(8)
		local hovered = math.DistanceSqr(mx, my, bsize, h-bsize-32) <= (bsize - 8)^2 and EyePos():DistToSqr( ent:WorldSpaceCenter() ) <= 100^2
		cam.PushModelMatrix(matrix, true)
			render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				draw.SimpleText(str1, "jcms_hud_big", w/2, 0, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				draw.SimpleText(str2, "jcms_hud_medium", w/2, 96, color_accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				draw.SimpleText(mycash, cashFont, w, 220, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

				local pad = 8
				surface.SetDrawColor(hovered and color_accent or color_fg)
				jcms.draw_Circle(bsize, h-bsize-32, bsize-pad, bsize-pad, bsize-pad, 24)
			render.OverrideBlend(false)

			draw.SimpleText(str3, "jcms_hud_big", bsize, h-bsize-32, hovered and color_white or color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.PopModelMatrix()

		if hovered then
			return 1
		end
	end

	terms.upgrade_station = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)

		surface.SetDrawColor(color_fg)
		local hoveredBtn = -1
		local values = string.Split(modedata, " ")
		local cost = 1000

		for i=1,3 do
			if hoveredBtn == -1 and values[i]~="x" and mx > 16 and mx < w-32 and my > 72*i and my < 72*i+64 then
				hoveredBtn = i
			end

			if values[i] == "x" then
				cost = cost + 500
			end

			surface.SetDrawColor(color_bg)
			jcms.hud_DrawNoiseRect(16, 72*i, w-32, 64, 128)
		end

		draw.SimpleText("#jcms.terminal_augmentstation", "jcms_hud_medium", w/2, 0, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(language.GetPhrase("jcms.terminal_cost"):format(cost), "jcms_hud_big", w/2, 72*4, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			draw.SimpleText("#jcms.terminal_augmentstation", "jcms_hud_medium", w/2, 0, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			local strings = {
				values[1]~="x" and string.format(language.GetPhrase("jcms.terminal_augment_incendiary"), values[1]),
				values[2]~="x" and string.format(language.GetPhrase("jcms.terminal_augment_shield"), values[2]),
				values[3]~="x" and string.format(language.GetPhrase("jcms.terminal_augment_explosive"), tonumber(values[3])*100)
			}

			for i=1,3 do
				if values[i] == "x" then
					draw.SimpleText("#jcms.terminal_soldout", "jcms_hud_small", w/2, 72*i+32, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				else
					local col = hoveredBtn == i and color_accent or color_fg
					surface.SetDrawColor(col)
					surface.DrawOutlinedRect(16, 72*i, w-32, 64, 4)
					draw.SimpleText(strings[i], "jcms_hud_small", w/2, 72*i+32, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end

			draw.SimpleText(language.GetPhrase("jcms.terminal_cost"):format(cost), "jcms_hud_big", w/2, 72*4, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			render.OverrideBlend( false )
		cam.PopModelMatrix()

		return hoveredBtn
	end

	terms.respawn_chamber = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		local cycle = (CurTime()%1)*32

		surface.SetDrawColor(color_bg)
		surface.DrawRect(0, 0, 8, h)
		surface.DrawRect(w-8, 0, 8, h)
		jcms.hud_DrawStripedRect(16, 64, w-32, h-64-16, 128, cycle)
		draw.SimpleText("#jcms.terminal_respawnchamber", "jcms_hud_medium", w/2, 0, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		local buttonId
		local active = (tonumber(modedata) or 0) > 0

		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
			surface.SetDrawColor(color_fg)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			surface.DrawRect(0, 0, 8, h)
			surface.DrawRect(w-8, 0, 8, h)
			draw.SimpleText("#jcms.terminal_respawnchamber", "jcms_hud_medium", w/2, 0, active and color_accent or color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			render.OverrideBlend( false )

			if ent:GetNWBool("jcms_terminal_locked", false) then 
				local bx,by,bw,bh = w/2 - 150/2, h*0.65 - 48/2, 150, 48
				bx,by,bw,bh = bx, by + bh + 8, 150, bh
				if mx>=bx and my>=by and mx<=bx+bw and my<=by+bh then
					surface.SetDrawColor(color_fg)
					buttonId = 0
				else 
					surface.SetDrawColor(color_bg)
				end
				surface.DrawRect(bx,by,bw,bh)
				cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					draw.SimpleText("#jcms.terminal_unlock", "jcms_hud_small", bx + bw/2, by + bh/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					render.OverrideBlend( false )
				cam.PopModelMatrix()
			end

			draw.SimpleText(active and "#jcms.terminal_active" or "#jcms.terminal_inactive", "jcms_hud_big", w/2, (h - 16)/2 + 32, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.PopModelMatrix()

		return buttonId
	end

	terms.gunlocker = function(ent, mx, my, w, h, modedata)
		local locked = ent:GetNWInt("jcms_terminal_locked")
		local class = modedata
		local empty = class == ""
		
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)

		if ent.jcms_cachedGunClass ~= class then
			ent.jcms_cachedGunClass = class
			ent.jcms_cachedGunData = jcms.gunstats_Get(class)
		end

		local gundata = ent.jcms_cachedGunData
		local gunmat = jcms.gunstats_GetMat(class)

		local wx, wy, ws = 0, 128, h/2.5
		surface.SetDrawColor(color_bg)
		jcms.hud_DrawStripedRect(wx, wy, ws, ws, 64, -CurTime()*24)

		local str1 = "#jcms.terminal_gunlocker"
		local str2 = "TM Mafia Security - R.W.S.S. Model B"
		local str3 = empty and "X" or (gundata and gundata.name or "#jcms.unknownbase0")
		draw.SimpleText(str1, "jcms_hud_medium", w/2, 0, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(str2, "jcms_hud_small", 24, 54, color_bg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		
		local font = "jcms_hud_medium"
		surface.SetFont(font)
		local tw, th = surface.GetTextSize(str3)
		if tw > w - ws - 32 then
			font = "jcms_hud_small"
		end

		local str4 = empty and "X" or (gundata and gundata.base or "???")
		surface.SetDrawColor(color_bg)
		surface.DrawRect(wx + ws + 16, 128 + 24, w - ws - wx - 16, 64)

		local str5 = "#jcms.terminal_gunlocker_take"
		local str6 = "#jcms.terminal_unlock"

		if locked then
			surface.SetMaterial(jcms.mat_lock)
			surface.SetDrawColor(color_bg)
			surface.DrawTexturedRect(wx+ws+16, wy+ws-ws/2, ws/2, ws/2)
		end

		local bx, by, bw, bh = w/2 + 64, 240, w/2 - 64, 48
		local by2 = by + bh + 12
		if locked then
			surface.DrawRect(bx, by2, bw, bh)
		else
			bx = wx + ws + 16
			bw = w - bx
		end

		if not empty then
			surface.DrawRect(bx, by, bw, bh)
		end
		
		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			draw.SimpleText(str1, "jcms_hud_medium", w/2, 0, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText(str2, "jcms_hud_small", 24, 54, color_accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			tw, th = draw.SimpleText(str3, font, wx + ws + 24, 128, color_fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(str4, "jcms_hud_small", wx + ws + 24 + 16, 128 + th*0.84, color_accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			render.OverrideBlend( false )
			
			if gunmat and not gunmat:IsError() then
				surface.SetMaterial(gunmat)
				surface.SetDrawColor(color_white)
				surface.DrawTexturedRect(wx, wy, ws, ws)
			else
				draw.SimpleText("?", "jcms_hud_huge", wx + ws/2, wy + ws/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			if locked then
				surface.SetMaterial(jcms.mat_lock)
				surface.SetDrawColor(color_fg)
				surface.DrawTexturedRect(wx+16, wy+ws-16-ws/4, ws/4, ws/4)
			end

			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			surface.SetDrawColor(color_fg)
			surface.DrawOutlinedRect(wx, wy, ws, ws, 4)

			if not empty then
				draw.SimpleText(str5, "jcms_hud_small", bx+bw/2, by+bh/2, locked and color_bg or color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			if locked then
				draw.SimpleText(str6, "jcms_hud_small", bx+bw/2, by2+bh/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			local btnId
			if (not empty and not locked) and mx >= bx and my >= by and mx <= bx + bw and my <= by + bh then
				surface.SetDrawColor(color_fg)
				surface.DrawOutlinedRect(bx, by, bw, bh, 4)
				btnId = 1
			elseif locked and mx >= bx and my >= by2 and mx <= bx + bw and my <= by2 + bh then
				surface.SetDrawColor(color_fg)
				surface.DrawOutlinedRect(bx, by2, bw, bh, 4)
				btnId = 2
			end
			render.OverrideBlend( false )
		cam.PopModelMatrix()

		return btnId
	end
	
	terms.shop = function(ent, mx, my, w, h, modedata)
		-- This right here is some of the ugliest motherfucking code ever
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		local me = LocalPlayer()

		if not ent.gunStatsCache then
			ent.gunStatsCache = {}
		end
		
		local gunPriceMul = ent:GetGunPriceMul()
		local ammoPriceMul = ent:GetAmmoPriceMul()
		
		local buttonId = -1
		local hoveredWeaponClass
		local hoveredWeaponStats
		
		local color_dark = Color(color_bg.r/3, color_bg.g/3, color_bg.b/3)
		local color_accent_dark = Color(color_accent.r/3, color_accent.g/3, color_accent.b/3)
		surface.SetDrawColor(color_dark)
		surface.DrawRect(0, 0, w, h)
		
		surface.SetDrawColor(color_fg)
		surface.DrawOutlinedRect(0, 0, w, h, 4)
	
		local sepX = w * 0.696
		jcms.hud_DrawStripedRect(sepX - 4, 4, 8, h - 8, 64, (CurTime() % 1) * 32)

		-- Weapons {{{
			draw.SimpleText("#jcms.terminal_weapons", "jcms_hud_medium", sepX/2, 24, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			if not ent.weaponHoverAnims then
				ent.weaponHoverAnims = {}
			end
			
			local baseWeaponX = 100
			local baseWeaponY = 104 - 24

			ent.scrollYMax = math.max(0, ent.scrollYMax or 0)
			if mx >= baseWeaponX and mx <= sepX and my >= baseWeaponY and my <= h - 32 then
				jcms.mousewheel_Occupy()
				ent.scrollY = math.Clamp( (ent.scrollY or 0) - jcms.mousewheel * 100, 0, ent.scrollYMax)
			else
				ent.scrollY = math.Clamp( (ent.scrollY or 0), 0, ent.scrollYMax)
			end

			if ent.scrollYMax > h - baseWeaponY then -- Scrollbar
				local hoveredElementId = -1

				surface.SetDrawColor(color_fg)
				local bx, by, bw, bh = 24, baseWeaponY, 48, 64
				hoveredElementId = hoveredElementId==-1 and (mx>=bx and my>=by and mx<=bx+bw and my<=by+bh and 1) or hoveredElementId
				surface.SetDrawColor(hoveredElementId==1 and color_accent or color_fg)
				surface.DrawRect(bx, by, bw, bh)
				draw.SimpleText("^", "jcms_hud_medium", bx + bw/2, by + bh/2, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				bx, by, bw, bh = 24, h - 64 - 32, 48, 64
				hoveredElementId = hoveredElementId==-1 and (mx>=bx and my>=by and mx<=bx+bw and my<=by+bh and 2) or hoveredElementId
				surface.SetDrawColor(hoveredElementId==2 and color_accent or color_fg)
				surface.DrawRect(bx, by, bw, bh)
				draw.SimpleText("v", "jcms_hud_medium", bx + bw/2, by + bh/2, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				
				bx, by, bw, bh = 32, baseWeaponY + 64 + 8, 32, h - baseWeaponY - (64 + 24)*2
				hoveredElementId = hoveredElementId==-1 and (mx>=bx-24 and my>=by and mx<=bx+bw+24 and my<=by+bh and 3) or hoveredElementId
				surface.SetDrawColor(hoveredElementId==3 and color_accent or color_fg)
				surface.DrawOutlinedRect(bx, by, bw, bh, 4)

				local gripHeight = h^2 / (ent.scrollYMax + h)
				surface.DrawRect(bx, Lerp(ent.scrollY/ent.scrollYMax, by, by + bh - gripHeight), bw, gripHeight)

				if me:KeyDown(IN_USE) and hoveredElementId > 0 then
					if hoveredElementId == 3 then
						ent.scrollY = math.Clamp(math.Remap(my, by + gripHeight/2, by + bh - gripHeight/2, 0, ent.scrollYMax or 0), 0, ent.scrollYMax or 0)
					else
						ent.scrollY = math.Clamp( (ent.scrollY or 0) + (hoveredElementId==1 and -1 or 1) * h * FrameTime(), 0, ent.scrollYMax or 0)
					end
				end
			end

			local wx, wy = baseWeaponX, baseWeaponY + 24 - ent.scrollY
			local wsize = 100
			local animWeight = 1.5

			local newGunHash = jcms.util_Hash( jcms.weapon_prices )
			if ent.previousGunHash ~= newGunHash then
				-- Lots of copypasted code unfortunately.
				if not ent.categorizedGuns then
					ent.categorizedGuns = {}
				else
					table.Empty(ent.categorizedGuns)
				end

				for weapon, cost in pairs(jcms.weapon_prices) do
					if cost <= 0 then continue end
					if not jcms.gunstats_Get(weapon) then continue end
					if not ent.gunStatsCache[ weapon ] then
						ent.gunStatsCache[ weapon ] = jcms.gunstats_Get(weapon)
					end
					local stats = ent.gunStatsCache[ weapon ]
					local category = stats and stats.category or "_"

					if not ent.categorizedGuns[ category ] then
						ent.categorizedGuns[ category ] = { weapon }
					else
						table.insert(ent.categorizedGuns[ category ], weapon)
					end
				end
				
				for category, list in pairs(ent.categorizedGuns) do
					table.sort(list)
				end

				local topmostCategory = ent.categorizedGuns["_"]
				ent.categorizedGuns["_"] = nil

				ent.categoriesSorted = table.GetKeys(ent.categorizedGuns)
				table.sort(ent.categoriesSorted, function(first, last)
					return #ent.categorizedGuns[ first ] > #ent.categorizedGuns[ last ]
				end)

				if topmostCategory and #topmostCategory > 0 then
					table.insert(ent.categoriesSorted, 1, "_")
					ent.categorizedGuns["_"] = topmostCategory
				end
				
				ent.previousGunHash = newGunHash
			end

			local categorizedGuns = ent.categorizedGuns
			local categoriesSorted = ent.categoriesSorted

			for i, category in ipairs(categoriesSorted) do
				local inBounds = (wy >= baseWeaponY and wy <= h - wsize - baseWeaponY)

				if inBounds then
					surface.SetDrawColor(color_fg)
					surface.DrawRect(baseWeaponX, wy, sepX - 64 - baseWeaponX, 32)
					jcms.hud_DrawStripedRect(baseWeaponX, wy + 32 + 8, sepX - 64 - baseWeaponX, 8, 64)
					draw.SimpleText(category, "jcms_hud_small", baseWeaponX + 32, wy + 16, color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
				wx = baseWeaponX
				wy = wy + 72

				for j, wepclass in ipairs(categorizedGuns[category]) do
					local hovered = inBounds and mx >= wx and my >= wy and mx <= wx + wsize and my <= wy + wsize
					
					if inBounds then
						local price = jcms.weapon_prices[wepclass]
						if not price or price <= 0 then
							continue
						end

						local canAfford = me:GetNWInt("jcms_cash", 0) >= price

						if not ent.gunStatsCache[ wepclass ] then
							ent.gunStatsCache[ wepclass ] = jcms.gunstats_Get(wepclass)
						end
						local wepstats = ent.gunStatsCache[ wepclass ]
						local owned = me:HasWeapon(wepclass)

						if hovered then
							buttonId = 0
							hoveredWeaponClass = wepclass
							hoveredWeaponStats = wepstats
						end
						
						ent.weaponHoverAnims[wepclass] = ((ent.weaponHoverAnims[wepclass] or 0)*animWeight + (hovered and 1 or 0)) / (animWeight+1)
					
						local hov = ent.weaponHoverAnims[wepclass]
						local mat = jcms.gunstats_GetMat(wepclass)

						local col = owned and color_accent or (canAfford and color_fg or color_bg)

						if hovered and not owned then
							surface.SetAlphaMultiplier(hov/3)
							surface.SetDrawColor(col)
							jcms.hud_DrawStripedRect(wx + 8, wy + 8, wsize - 16, wsize - 16, 64, (CurTime()%1)*16 )
							surface.SetAlphaMultiplier(1)
						end

						if hov > 0.005 then
							cam.PushModelMatrix( jcms.terminal_getGlitchMatrix(4, hov), true )
						end

						if mat and not mat:IsError() then
							surface.SetMaterial(mat)

							local fcol = canAfford and (1 + hov)/2 or 0.2 + hov*0.8
							surface.SetDrawColor(Lerp(fcol, col.r, 255), Lerp(fcol, col.g, 255), Lerp(fcol, col.b, 255))
							surface.DrawTexturedRect(wx, wy, wsize, wsize)
						else
							local col = canAfford and color_fg or color_bg
							surface.SetDrawColor(col)
							surface.DrawOutlinedRect(wx, wy, wsize, wsize, 4)
							
							local wepname = wepstats and wepstats.name or wepclass
							local len = #wepname
							draw.SimpleText(wepname, len>10 and "jcms_small" or "jcms_medium", wx+wsize/2, wy+wsize/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						end

						if owned then
							surface.SetAlphaMultiplier(0.8 + hov/3)
							surface.SetDrawColor(col)
							surface.DrawOutlinedRect(wx, wy, wsize, wsize, 4)
							surface.SetAlphaMultiplier(1)
						end

						if hov > 0.005 then
							cam.PopModelMatrix()
						end
					end

					wx = wx + wsize + 8
					if wx >= sepX - baseWeaponX - 64 then
						wx = baseWeaponX
						wy = wy + wsize + 8
						inBounds = (wy >= baseWeaponY and wy <= h - wsize - baseWeaponY)
					end
				end

				if wx > wsize then
					wy = wy + wsize
				end
				wy = wy + 32
				inBounds = (wy >= baseWeaponY and wy <= h - wsize - baseWeaponY)
				
				ent.scrollYMax = wy + ent.scrollY - h + 256
			end
		-- }}}

		-- Ammo {{{
			draw.SimpleText("#jcms.terminal_selweapon", "jcms_hud_small", (sepX+w)/2, 24, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			local selectedWeapon = me:GetActiveWeapon()
			if IsValid(selectedWeapon) then
				local wepclass = selectedWeapon:GetClass()
				local mat = jcms.gunstats_GetMat(wepclass)
				
				if not ent.gunStatsCache[ wepclass ] then
					ent.gunStatsCache[ wepclass ] = jcms.gunstats_Get(wepclass)
				end
				local stats = ent.gunStatsCache[ wepclass ]
				local owned = me:HasWeapon(wepclass)
				local imgSize = 256

				if mat and not mat:IsError() then
					surface.SetMaterial(mat)
					
					cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(4), true)
						surface.SetDrawColor(255, 255, 255)
						surface.DrawTexturedRectRotated( (sepX + w)/2, 80 + imgSize/2, imgSize, imgSize, 0)
					cam.PopModelMatrix()
				else
					imgSize = 0
				end

				local ammoY = imgSize + 128

				if stats then
					local wepprice = jcms.weapon_prices[ wepclass ]

					surface.SetFont("jcms_hud_medium")
					local name = stats.name
					local fits = surface.GetTextSize(name) < (w - sepX)*0.95
					draw.SimpleText(name, fits and "jcms_hud_medium" or "jcms_hud_small", (sepX+w)/2, 80 + imgSize + 8, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

					if not mat then
						ammoY = ammoY + 72
					end
					local ammoType1 = IsValid(selectedWeapon) and selectedWeapon:GetPrimaryAmmoType() or -1
					local ammoType2 = IsValid(selectedWeapon) and selectedWeapon:GetSecondaryAmmoType() or -1

					if wepprice and wepprice > 0 then
						wepprice = math.max(1, math.floor(wepprice*gunPriceMul*0.25))

						local bx, by, bw, bh = sepX + 48, ammoY + 48, w - sepX - 48*2, 55
						buttonId = buttonId == -1 and (mx>=bx and my>=by and mx<=bx+bw and my<=by+bh and 1) or buttonId

						surface.SetDrawColor(color_fg)
						surface.DrawOutlinedRect(bx, by, bw, bh, 2)
						surface.DrawRect(bx + bw - 100, by, 100, bh)
						draw.SimpleText("#jcms.selltheweapon", "jcms_hud_small", bx + 32, by + bh/2, color_fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						draw.SimpleText(wepprice .. " J", "jcms_hud_small", bx + bw - 50, by + bh/2, color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

						if buttonId == 1 then
							surface.SetAlphaMultiplier(0.2)
							surface.SetDrawColor(color_fg)
							render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
							cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(8), true)
								surface.DrawRect(bx, by, bw, bh)
							cam.PopModelMatrix()
							render.OverrideBlend( false )
							surface.SetAlphaMultiplier(1)
						end

						ammoY = ammoY + 128 + 32
					end

					local ammoHeight = 200

					for ammoTypeIndex = 1, 2 do
						local ammoType = ammoTypeIndex == 1 and ammoType1 or ammoType2
						if ammoType < 0 then continue end

						local ammoTypeName = game.GetAmmoName(ammoType)
						draw.SimpleText(language.GetPhrase(ammoTypeName .. "_ammo"), "jcms_hud_small", (sepX+w)/2, ammoY, color_accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
						
						local ammoPrice = jcms.weapon_ammoCosts[ ammoTypeName:lower() ] or jcms.weapon_ammoCosts._DEFAULT
						local ammoPriceMul = ent:GetAmmoPriceMul()
						local clipSize = ammoTypeIndex==1 and selectedWeapon:GetMaxClip1() or selectedWeapon:GetMaxClip2()
						local weaponModeTable = (ammoTypeIndex==1 and selectedWeapon.Primary) or (ammoTypeIndex==2 and selectedWeapon.Secondary)
						if clipSize < 0 then
							clipSize = weaponModeTable and tonumber(weaponModeTable.DefaultClip) or 1
						end
						clipSize = math.max(clipSize, 1)

						local totalPriceBuy = math.ceil(math.ceil(ammoPrice * clipSize)*ammoPriceMul)
						local totalPriceSell = math.floor( math.max(1, ammoPrice*clipSize*0.5*ammoPriceMul) )

						render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
							surface.SetDrawColor(color_accent)
							jcms.hud_DrawNoiseRect(sepX + 32, ammoY - 16, w - sepX - 64, ammoHeight, 1024)
							surface.DrawRect(sepX + 32, ammoY - 16 - 8, w - sepX - 64, 2)
						render.OverrideBlend( false )

						local buttonIndex = 2 + (ammoTypeIndex - 1)*2
						local bx, by, bw, bh = sepX + 48, ammoY + 48, w - sepX - 48*2, 55
						buttonId = buttonId == -1 and (mx>=bx and my>=by and mx<=bx+bw and my<=by+bh and buttonIndex) or buttonId
						surface.DrawOutlinedRect(bx, by, bw, bh, 2)
						surface.DrawRect(bx + bw - 100, by, 100, bh)
						draw.SimpleText(language.GetPhrase("jcms.buyxcount"):format(clipSize), "jcms_hud_small", bx + 32, by + bh/2, color_accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						draw.SimpleText(totalPriceBuy .. " J", "jcms_hud_small", bx + bw - 50, by + bh/2, color_accent_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

						if buttonId == buttonIndex then
							render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
							cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(8), true)
								surface.DrawOutlinedRect(bx, by, bw, bh, 4)
							cam.PopModelMatrix()
							render.OverrideBlend( false )
						end

						buttonIndex = 3 + (ammoTypeIndex - 1)*2
						by = by + bh + 8
						buttonId = buttonId == -1 and (mx>=bx and my>=by and mx<=bx+bw and my<=by+bh and buttonIndex) or buttonId
						surface.DrawOutlinedRect(bx, by, bw, bh, 2)
						surface.DrawRect(bx + bw - 100, by, 100, bh)
						draw.SimpleText(language.GetPhrase("jcms.sellxcount"):format(clipSize), "jcms_hud_small", bx + 32, by + bh/2, color_accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						draw.SimpleText(totalPriceSell .. " J", "jcms_hud_small", bx + bw - 50, by + bh/2, color_accent_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

						if buttonId == buttonIndex then
							render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
							cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(8), true)
								surface.DrawOutlinedRect(bx, by, bw, bh, 4)
							cam.PopModelMatrix()
							render.OverrideBlend( false )
						end

						ammoY = ammoY + ammoHeight + 32
					end
				end
			else
				surface.SetDrawColor(color_fg)
				jcms.hud_DrawNoiseRect(sepX + 32, 72, w - sepX - 64, h - 72 - 32, 1024)
				draw.SimpleText("?", "jcms_hud_huge", (sepX + w)/2, h / 2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		-- }}}

		if buttonId == 0 and hoveredWeaponClass then
			cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
				local price = jcms.weapon_prices[hoveredWeaponClass]
				local canAfford = me:GetNWInt("jcms_cash", 0) >= price
				
				local col = canAfford and color_accent or color_bg
				local col_dark = canAfford and color_accent_dark or color_dark
				surface.SetDrawColor(col)
				
				local wepname = hoveredWeaponStats and hoveredWeaponStats.name or hoveredWeaponClass
				local font = "jcms_hud_small"
				surface.SetFont(font)
				local tw = surface.GetTextSize(wepname) + 32
				jcms.hud_DrawStripedRect(mx - tw/2 - 8, my + 32 - 8, tw + 16, 38 + 16, 64)
				surface.SetDrawColor(col_dark)
				surface.DrawRect(mx - tw/2, my + 32, tw, 38)
				draw.SimpleText(wepname, "jcms_hud_small", mx, my + 48, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				draw.SimpleTextOutlined(jcms.util_CashFormat(price) .. " J", "jcms_hud_medium", mx, my + 108, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, col_dark)
			cam.PopModelMatrix()

			if me:KeyPressed(IN_USE) then
				RunConsoleCommand("jcms_buyweapon", hoveredWeaponClass)
			end
		elseif buttonId > 0 then
			return buttonId
		end
	end
end