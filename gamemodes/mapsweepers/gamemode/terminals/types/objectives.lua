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
	terms.thumper_controls = {
		command = function(ent, cmd, data, ply)
			if cmd == 0 then
				jcms.terminal_ToUnlock(ent)
				return true
			elseif cmd == 1 and not ent:GetNWBool("jcms_terminal_locked") then
				local worked, newdata = ent.jcms_terminal_Callback(ent, cmd, data, ply)
				return worked, newdata
			end
		end
	}
	
	terms.jcorpnuke = {
		command = function(ent, cmd, data, ply)
			if cmd == 1 then
				local worked, newdata = ent.jcms_terminal_Callback(ent, cmd, data, ply)
				return worked, newdata
			end
		end
	}

	terms.mainframe_terminal = {
		generate = function(ent)
			local isUnlocked = true
			for i, terminal in ipairs(ent.dependents) do 
				isUnlocked = isUnlocked and terminal.isComplete
			end

			if not isUnlocked then
				ent.jcms_hackTypeStored = ent.jcms_hackType
				ent.jcms_hackType = nil
			elseif ent.jcms_hackTypeStored then
				ent.jcms_hackType = ent.jcms_hackTypeStored
			end

			if not ent:GetNWBool("jcms_terminal_locked") then 
				local newColorVector = Vector(1, 0.25, 0.25)

				if IsValid(ent.jcms_hackedBy) then
					jcms.director_PvpObjectiveCompleted(ent.jcms_hackedBy, ent:GetPos())

					local pvpTeam = ent.jcms_hackedBy:GetNWInt("jcms_pvpTeam", -1)
					if pvpTeam ~= -1 then
						local pvpTeamColor = jcms.util_GetPVPColor(ent.jcms_hackedBy)
						newColorVector:SetUnpacked(
							(200 + pvpTeamColor.r)/2/255,
							(200 + pvpTeamColor.g)/2/255,
							(200 + pvpTeamColor.b)/2/255
						)
					end
				end

				for i, nodeEnt in ipairs(ent.track) do 
					nodeEnt:SetEnergyColour(newColorVector)
				end
				ent.isComplete = true
				
					
				if IsValid(ent.prevTerminal) then --Re-generate our predecessor, so it updates/unlocks.
					jcms.terminal_ToPurpose(ent.prevTerminal)
				end
			end

			ent.isUnlocked = isUnlocked --So we can use this easily for object tagging in the mission file.
			isUnlocked = isUnlocked and "1" or "0"
			local trackId = tostring(ent.trackId)
			return trackId .. "_" .. isUnlocked
		end,

		command = function(ent, cmd, data, ply)
			local dataTbl = string.Explode( "_", data )
			local trackID = dataTbl[1]
			local unlocked = dataTbl[2]

			if cmd == 0 and unlocked and ent:GetNWBool("jcms_terminal_locked") then 
				jcms.terminal_ToUnlock(ent)
				return true
			end
		end
	}

	terms.payload_controls = {
		command = function(ent, cmd, data, ply)
			if cmd == 0 then
				jcms.terminal_ToUnlock(ent)
				return true
			elseif cmd == 1 then

				if ent:GetNWBool("jcms_terminal_locked") then
					if data == "u" then
						jcms.terminal_ToUnlock(ent)
						return true
					else
						return true, "u"
					end
				else
					local worked, newdata = ent.jcms_terminal_Callback(ent, cmd, data, ply)
					return worked, newdata
				end
			end
		end,

		generate = function(ent)
			if ent.jcms_manuallyHacked == false then --Autohacks allow payload to move. THE COMPARISON IS NEEDED HERE. We want to ignore nil
				local worked, newdata = ent.jcms_terminal_Callback(ent, cmd, data, ply)
				return worked, newdata
			end

			if ent.nodeWasCrossed then
				return "p"
			else
				return ""
			end
		end
	}

	terms.datadownloadcomputer = {
		command = function(ent, cmd, data, ply)
			if cmd == 0 then
				local cash = ply:GetNWInt("jcms_cash")
				if cash >= ent.jcms_datadownload_cost then
					ply:SetNWInt("jcms_cash", cash - ent.jcms_datadownload_cost)
					local worked, newdata = ent.jcms_terminal_Callback(ent, cmd, data, ply)
					return worked, newdata
				end
				return false
			end
		end,

		generate = function(ent)
			return tostring(ent.jcms_datadownload_cost)
		end
	}
end

if CLIENT then
	terms.thumper_controls = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		draw.SimpleText("#jcms.terminal_thumpercontrols", "jcms_hud_medium", w/2, h/2, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			draw.SimpleText("#jcms.terminal_thumpercontrols", "jcms_hud_medium", w/2, h/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			render.OverrideBlend( false )
		cam.PopModelMatrix()

		local thumper = ent:GetNWEntity("jcms_link")
		local time = IsValid(thumper) and thumper:GetCycle() or 0
		surface.SetDrawColor(color_bg)
		for i=0, 2 do
			surface.DrawRect(24*i, h/2 + 24 + math.ease.InCirc((math.cos(time*2*math.pi+i/4)+1)/2)*64, 18, 64)
		end

		surface.SetDrawColor(color_fg)
		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
		for i=0, 2 do
			surface.DrawRect(24*i, h/2 + 24 + math.ease.InCirc((math.cos(time*2*math.pi+i/4)+1)/2)*64, 18, 64)
		end
		render.OverrideBlend( false )
		cam.PopModelMatrix()

		local btnId
		
		local bx,by,bw,bh = 112, h/2 + 24, 150, 48
		if mx>=bx and my>=by and mx<=bx+bw and my<=by+bh then
			surface.SetDrawColor(color_fg)
			btnId = 1
		else
			surface.SetDrawColor(color_bg)
		end
		surface.DrawRect(bx,by,bw,bh)

		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			draw.SimpleText(modedata == "1" and "#jcms.terminal_disable" or "#jcms.terminal_enable", "jcms_hud_small", bx + bw/2, by + bh/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			render.OverrideBlend( false )
		cam.PopModelMatrix()

		local c = modedata == "1" and Color(0,255,0) or Color(255,0,0)
		draw.RoundedBox(16, bx + bw + 32, h/2 + 32, 32, 32, color_bg)
		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
		draw.SimpleText(modedata == "1" and "#jcms.terminal_active" or "#jcms.terminal_inactive", "jcms_hud_small", bx + bw + 32 + 48, h/2 + 32 + 12, color_bg, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			draw.RoundedBox(12, bx + bw + 32 + 4, h/2 + 32 + 4, 24, 24, c)
			draw.SimpleText(modedata == "1" and "#jcms.terminal_active" or "#jcms.terminal_inactive", "jcms_hud_small", bx + bw + 32 + 48, h/2 + 32 + 12, c, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			render.OverrideBlend( false )
		cam.PopModelMatrix()
		
		if ent:GetNWBool("jcms_terminal_locked") then
			bx,by,bw,bh = bx, by + bh + 8, 150, bh
			if mx>=bx and my>=by and mx<=bx+bw and my<=by+bh then
				surface.SetDrawColor(color_fg)
				btnId = 0
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

		render.OverrideBlend( false )
		return btnId
	end

	terms.jcorpnuke = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)

		surface.SetDrawColor(color_fg)
		jcms.hud_DrawNoiseRect(0, 0, w, h, 512)

		local buttonId = 0
		local off = 4
		
		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			surface.SetDrawColor(color_fg)
			draw.SimpleText("#jcms.terminal_nukecontrols", "jcms_hud_medium", w/2, 16, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			surface.DrawOutlinedRect(0, 0, w, h, 4)

			local spin = 0
			if modedata == "1" then
				if ent:GetSwpNear() then
					draw.SimpleText("#jcms.terminal_inactive", "jcms_hud_big", w-48, h/2, color_accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
					draw.SimpleText("#jcms.terminal_nukehelp", "jcms_hud_small", w-64, h/2 + 72, color_accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				else					
					local str1 = "#jcms.error"
					draw.SimpleText(str1, "jcms_hud_big", w/2, h/2, jcms.color_alert, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					draw.SimpleText(str1, "jcms_hud_big", w/2-4, h/2+4, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

					local str2 = string.format(language.GetPhrase("jcms.terminal_nukesweeperspresent"), ent:GetRequiredSwps())
					draw.SimpleText(str2, "jcms_hud_small", w/2-4, h/2 + 72+4, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					draw.SimpleText(str2, "jcms_hud_small", w/2, h/2 + 72, jcms.color_alert, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				end
				surface.SetDrawColor(color_bg)

				local bx, by, bw, bh = 46, 464, 400, 320
				if mx >= bx and my >= by and mx <= bx+bw and my<=by+bh then
					buttonId = 1
				end

				local matrix = Matrix()
				matrix:Translate( Vector(0, 0, 2) )

				cam.PushModelMatrix(matrix, true)
					surface.SetDrawColor(buttonId==1 and color_accent or CurTime()%0.5<0.25 and color_fg or color_bg)
					jcms.hud_DrawStripedRect(bx, by, bw, bh)
				cam.PopModelMatrix()

				surface.SetDrawColor(color_bg)
			elseif modedata == "2" then
				draw.SimpleText("#jcms.terminal_active", "jcms_hud_big", w-48, h/2, color_fg, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

				for i=1, 4 do
					local randomstrings = {
						"jcms.vo_iwillcomedownthereifyoudontstartmoving",
						"jcms.vo_taking1dollraforstandingthere",
						"jcms.vo_youareawasteofmoney",
						"jcms.vo_microchipkillsifyoustandstill",
						"jcms.vo_startmoving_killswitch"
					}

					local id = math.floor( (CurTime()*3 + i) % (#randomstrings) ) + 1
					draw.SimpleText(language.GetPhrase(randomstrings[id]), "jcms_small", w-64-i*4, h/2 + 64 + 16*i, color_fg, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				end

				surface.SetDrawColor(color_fg)
				spin = CurTime() % (math.pi * 2)
			else
				surface.SetDrawColor(color_accent)
				spin = CurTime() % (math.pi * 2)
				
				local frac = math.Clamp( 1-(modedata - CurTime())/60, 0, 1 )
				local bx, by, bw, bh = w - 620 - 64, h - 220, 620, 48
				surface.DrawOutlinedRect(bx, by, bw, bh, 4)
				jcms.hud_DrawStripedRect(bx + 8, by + 8, bw - 16, bh - 16, 64)
				surface.DrawRect(bx, by, bw*frac, bh)

				local time = CurTime()
				local str = language.GetPhrase("jcms.terminal_nukearming") .. string.rep(".", math.floor(time*5%4))
				draw.SimpleText(str, "jcms_hud_medium", bx, by - 8, color_accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				if time % 0.25 < 0.15 then
					draw.SimpleText("#jcms.terminal_nukearmingtip", "jcms_big", bx + bw/2, by + bh + 16, color_accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				end
			end

			local nukex, nukey = 128 + 64, h/2 + 32
			jcms.draw_Circle(nukex, nukey, 128, 128, 16, 18)
			jcms.draw_Circle(nukex, nukey, 16, 16, 16, 8)
			for i=1, 3 do
				local ang = math.pi/3*i*2 + spin
				jcms.draw_Circle(nukex, nukey, 128-16-8, 128-16-8, 128 - 32 - 16, 4, ang, ang + math.pi/3)
			end

			render.OverrideBlend(false)
		
		return buttonId
	end
	
	terms.mainframe_terminal = function(ent, mx, my, w, h, modedata)
		local dataTbl = string.Explode( "_", modedata )
		local trackID = dataTbl[1]
		local unlocked = tobool(dataTbl[2])

		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		draw.SimpleText("#jcms.terminal_mainframe", "jcms_hud_small", 0, 0, color_bg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("#jcms.terminal_mainframe_controlpanel", "jcms_hud_small", 0, 30, color_bg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		surface.SetDrawColor(color_bg)
		surface.DrawRect(0, 0, w, h*0.85)

		--Title-bar stuff
		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)

			draw.SimpleText("#jcms.terminal_mainframe", "jcms_hud_small", 0, 0, color_fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText("#jcms.terminal_mainframe_controlpanel", "jcms_hud_small", 0, 30, color_fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			render.OverrideBlend( false )
		cam.PopModelMatrix()

		--Track information
		draw.SimpleText(language.GetPhrase("jcms.terminal_mainframe_trackno"):format(trackID), "jcms_hud_big", w/2, h*0.4, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		draw.SimpleText("#jcms.terminal_mainframe_trackeffect"..trackID, "jcms_hud_small", w/2, h*0.4, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		
		local btnId
		if ent:GetNWBool("jcms_terminal_locked") then
			-- // <LOCKED> and Hack me! text {{{
				local c = unlocked and Color(0,255,0) or Color(255,0,0)
				local lockedTxt = unlocked and "#jcms.terminal_mainframe_unlocked" or "#jcms.terminal_mainframe_locked"
				local lockedFont = unlocked and "jcms_hud_small" or "jcms_hud_medium"

				local subtitleTxt = unlocked and "↓" or "#jcms.terminal_mainframe_lockedsubtitle"
				local subtitleFont = unlocked and "jcms_hud_small" or "jcms_hud_small"
				local tx, ty = w/2, unlocked and h*0.65 or h*0.7

				cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
					draw.SimpleText(lockedTxt, lockedFont, tx, ty, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
					draw.SimpleText(subtitleTxt, subtitleFont, tx, ty, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
						draw.SimpleText(lockedTxt, lockedFont, tx, ty, c, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
						draw.SimpleText(subtitleTxt, subtitleFont, tx, ty, c, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
					render.OverrideBlend( false )
				cam.PopModelMatrix()
			-- // }}}
			
			if unlocked then --The unlock button
				local bx,by,bw,bh = w/2 - 150/2, h*0.65 - 48/2, 150, 48
				bx,by,bw,bh = bx, by + bh + 8, 150, bh
				if mx>=bx and my>=by and mx<=bx+bw and my<=by+bh then
					surface.SetDrawColor(color_fg)
					btnId = 0
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
		else
			--We're hacked, put something else under the track details.
			cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
				draw.SimpleText("#jcms.terminal_mainframe_hacked", "jcms_hud_small", w/2, h*0.65, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					draw.SimpleText("#jcms.terminal_mainframe_hacked", "jcms_hud_small", w/2, h*0.65, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				render.OverrideBlend( false )
			cam.PopModelMatrix()
		end

		render.OverrideBlend( false )
		return btnId
	end

	terms.payload_controls = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)

		local str1 = "#jcms.terminal_rcp"
		draw.SimpleText(str1, "jcms_hud_medium", w/2, 0, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		
		local flash = CurTime() % 0.5 < 0.25
		local payloadDetected = modedata == "p" or modedata == "u"
		local unauth = modedata == "u"
		local disconnected = modedata ~= "c"

		local str2 = "#jcms.terminal_rail"
		local str3 = language.GetPhrase("jcms.terminal_rail_" .. (disconnected and "blocked" or "connected"))
		local str4 = unauth and "#jcms.terminal_gainaccess" or "#jcms.terminal_allowpassage"
		local str5 = payloadDetected and (unauth and "#jcms.terminal_accessdenied" or "#jcms.terminal_payload_detected") or "#jcms.terminal_payload_nf"

		local lw = math.floor(w/3)
		local lh = 48
		surface.SetDrawColor(color_bg)
		surface.DrawRect(0, 96 + lh/2, lw, 4)
		surface.DrawRect(lw*2, 96 + lh/2, lw, 4)
		surface.DrawRect(lw, 96, 4, lh)
		surface.DrawRect(lw*2-4, 96, 4, lh)
		if disconnected then
			draw.SimpleText("X", "jcms_hud_medium", w/2, 96 + lh/2, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			surface.DrawRect(lw, 96 + lh/2 - 8, lw, 4)
			surface.DrawRect(lw, 96 + lh/2 + 4, lw, 4)
		end
		local tw1 = draw.SimpleText(str2, "jcms_hud_small", 0, 200, color_bg)
		draw.SimpleText(str3, "jcms_hud_small", tw1 + 32, 200, color_bg)

		local bx, by, bw, bh = w/2-200, h-160, 400, 48
		local hovered = disconnected and payloadDetected and mx >= bx and my >= by and mx <= bx+bw and my <= by+bh
		if not payloadDetected then
			surface.DrawRect(bx, by, bw, bh)
			draw.SimpleText(str5, "jcms_hud_small", bx+bw/2, by+bh+4, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		else
			draw.SimpleText(str5, "jcms_hud_medium", bx+bw/2, by-6, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end

		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
		render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			draw.SimpleText(str1, "jcms_hud_medium", w/2, 0, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			surface.SetDrawColor(color_fg)
			surface.DrawRect(0, 96 + lh/2, lw, 4)
			surface.DrawRect(lw*2, 96 + lh/2, lw, 4)
			surface.DrawRect(lw, 96, 4, lh)
			surface.DrawRect(lw*2-4, 96, 4, lh)
			if disconnected then
				if flash then
					draw.SimpleText("X", "jcms_hud_medium", w/2, 96 + lh/2, color_accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			else
				surface.DrawRect(lw, 96 + lh/2 - 8, lw, 4)
				surface.DrawRect(lw, 96 + lh/2 + 4, lw, 4)
			end
			draw.SimpleText(str2, "jcms_hud_small", 0, 200, color_fg)
			draw.SimpleText(str3, "jcms_hud_small", tw1 + 32, 200, (disconnected and flash) and color_accent or color_fg)

			surface.SetDrawColor(hovered and color_accent or color_fg)
			surface.DrawOutlinedRect(bx, by, bw, bh, 4)
			draw.SimpleText(str4, "jcms_hud_small", bx+bw/2, by+bh/2, hovered and color_accent or color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if payloadDetected then
				draw.SimpleText(str5, "jcms_hud_medium", bx+bw/2, by-6, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				jcms.hud_DrawStripedRect(bx, by + bh + 4, bw, 8, 96, CurTime()%1*96)
			else
				jcms.hud_DrawStripedRect(bx, by, bw, bh, 96)
				draw.SimpleText(str5, "jcms_hud_small", bx+bw/2, by+bh+4, color_accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end
		render.OverrideBlend(false)
		cam.PopModelMatrix()

		if hovered then
			return 1
		end
	end

	terms.datadownloadcomputer = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		local green = Color(48, 255, 64)
		
		if tonumber(modedata) then
			local initCost = math.ceil(tonumber(modedata))
			local canAfford = jcms.locPly:GetNWInt("jcms_cash", 0) >= initCost

			local bId

			local str1 = "#jcms.datadownloadcomputer_quote"
			local str2 = "#jcms.datadownloadcomputer_title"
			local str3a = "#jcms.datadownloadcomputer_flavour1a"
			local str3b = "#jcms.datadownloadcomputer_flavour1b"
			local str4a = "#jcms.datadownloadcomputer_flavour2a"
			local str5 = "#jcms.datadownloadcomputer_flavour2b"
			--local str6 = language.GetPhrase("jcms.datadownloadcomputer_fee"):format( jcms.util_CashFormat(initCost) )

			surface.SetDrawColor(color_bg)
			surface.DrawRect(w/2, h/2, w/2, 4)
			draw.SimpleText(str1, "jcms_hud_small", w/2, h/2, color_bg, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

			draw.SimpleText(str2, "jcms_hud_big", w/2, 0, color_bg, TEXT_ALIGN_CENTER)
			
			local tw, _ = draw.SimpleText(str3a, "jcms_hud_medium", 0, 96, color_bg)
			draw.SimpleText(str3b, "jcms_hud_medium", tw + 16, 96, color_bg)

			local tw, _ = draw.SimpleText(str4a, "jcms_hud_medium", 0, 164, color_bg)
			draw.SimpleText(str5, "jcms_hud_medium", tw + 16, 164, color_bg)

			local t = CurTime()*7
			local symbolId = math.floor( t % #jcms.terminal_random_data ) + 1

			local bx, by, bw, bh = 0, h/2+32, w/2 - 64, h/3
			if mx >= bx and my >= by and mx <= bx+bw and my <= by+bh then
				bId = 0
			end

			surface.SetAlphaMultiplier(bId==0 and 0.8 or 0.3)
			surface.SetDrawColor(color_bg)
			surface.DrawRect(bx, by, bw, bh, 4)
			surface.SetAlphaMultiplier(1)
			
			for row = 1, 3 do
				for column = 1, 5 do
					draw.SimpleText(jcms.terminal_random_data[symbolId] or "?", "jcms_hud_big", w/2 + column*108, h/2 + row*84, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

					symbolId = symbolId + 1
					if symbolId > #jcms.terminal_random_data then
						symbolId = 1
					end
				end
			end

			cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
				render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					draw.SimpleText(str1, "jcms_hud_small", w/2, h/2, color_fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
					draw.SimpleText(str2, "jcms_hud_big", w/2, 0, color_fg, TEXT_ALIGN_CENTER)

					local tw, _ = draw.SimpleText(str3a, "jcms_hud_medium", 0, 96, color_fg)
					draw.SimpleText(str3b, "jcms_hud_medium", tw + 16, 96, color_bg)

					local tw, _ = draw.SimpleText(str4a, "jcms_hud_medium", 0, 164, color_fg)
					draw.SimpleText(str5, "jcms_hud_medium", tw + 16, 164, t%3<1.5 and color_bg or green)

					if not canAfford then
						surface.SetDrawColor(color_bg)
						jcms.hud_DrawStripedRect(bx, by, bw, bh, 64)
					end

					draw.SimpleText("#jcms.confirm", "jcms_hud_big", bx + bw/2, by + bh/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					--draw.SimpleText(str6, "jcms_hud_small", bx + bw/2, by + bh/2 + 16, canAfford and green or color_accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				render.OverrideBlend(false)
			cam.PopModelMatrix()

			return bId
		elseif modedata == "upload" then
			local str1 = "#jcms.datadownloadcomputer_uploading"
			draw.SimpleText(str1, "jcms_hud_superhuge", w/2, h/4, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			surface.SetDrawColor(color_bg)
			surface.DrawRect(32, h/2, w-64, 4)
			surface.DrawRect(32, h/2 + 4, 6, 64)
			surface.DrawRect(w-32-6, h/2 + 4, 6, 64)

			render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			surface.SetAlphaMultiplier(0.7)
			
			local progress = 0
			local obj = jcms.objectives[1]
			if obj.n == 100 then
				progress = obj.progress/obj.n or 0.75
			end

			for i=1, 4 do
				cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(i+2, math.random()), true)
					draw.SimpleText(str1, "jcms_hud_superhuge", w/2 + math.Rand(-16, 16), h/4 + math.Rand(-16, 16), color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				
					surface.SetDrawColor(color_fg)
					surface.DrawRect(32, h/2, w-64, 4)
					surface.DrawRect(32, h/2 + 4, 6, 64)
					surface.DrawRect(w-32-6, h/2 + 4, 6, 64)

					surface.SetDrawColor(color_accent)
					surface.DrawRect(42, h/2+16, (w-84)*progress, 48 - i*8)
				cam.PopModelMatrix()
			end
			surface.SetAlphaMultiplier(1)
			render.OverrideBlend(false)
		elseif modedata == "done" then
			local str1 = "#jcms.datadownloadcomputer_done"
			draw.SimpleText(str1, "jcms_hud_superhuge", w/2, h/4, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
					surface.SetAlphaMultiplier( (math.sin(CurTime()*3) + 1)/2 )
					draw.SimpleText(str1, "jcms_hud_superhuge", w/2, h/4, green, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					surface.SetAlphaMultiplier(1)
				cam.PopModelMatrix()
			render.OverrideBlend(false)
		end
	end
end