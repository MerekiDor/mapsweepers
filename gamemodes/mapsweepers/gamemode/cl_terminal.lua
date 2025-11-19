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

local function getGlitchMatrix(div, baseAddition)
	baseAddition = baseAddition or 0
	local matrix = Matrix()
	matrix:Translate(Vector(0,0, baseAddition + (2 + (math.random() < 0.023 and math.random() or 0))/(div or 8)))
	return matrix
end

jcms.terminal_themes = {
	jcorp = { Color(64, 0, 0, 200), Color(230, 0, 0), Color(31, 114, 147) },
	combine = { Color(0, 242, 255, 55), Color(0, 168, 229, 210), Color(215, 38, 42) },
	rebel = { Color(32, 20, 255, 54), Color(143, 67, 229), Color(21, 224, 21) },
	antlion = { Color(200, 23, 17, 55), Color(255, 255, 0), Color(255, 124, 36) }
}

jcms.terminal_modeTypes = {
	pin = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		
		local btnId
		if not ent:GetNWBool("jcms_terminal_locked") then
			local vw, vh = w*0.8, 64
			local vx, vy = (w-vw)/2, (h-vh)/2

			surface.SetDrawColor(color_bg)
			surface.DrawRect(vx, vy, vw, vh)
			render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)

			local matrix = getGlitchMatrix(8)
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
						local matrix = getGlitchMatrix(8)
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
	end,

	cash_cache = function(ent, mx, my, w, h, modedata)
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
		local matrix = getGlitchMatrix(8)
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
	end,

	gambling = function(ent, mx, my, w, h, modedata)
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

		local matrix = getGlitchMatrix(8)
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
	end,

	upgrade_station = function(ent, mx, my, w, h, modedata)
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

		cam.PushModelMatrix(getGlitchMatrix(), true)
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
	end,

	respawn_chamber = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		local cycle = (CurTime()%1)*32

		surface.SetDrawColor(color_bg)
		surface.DrawRect(0, 0, 8, h)
		surface.DrawRect(w-8, 0, 8, h)
		jcms.hud_DrawStripedRect(16, 64, w-32, h-64-16, 128, cycle)
		draw.SimpleText("#jcms.terminal_respawnchamber", "jcms_hud_medium", w/2, 0, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		local buttonId
		local active = (tonumber(modedata) or 0) > 0

		cam.PushModelMatrix(getGlitchMatrix(), true)
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
				cam.PushModelMatrix(getGlitchMatrix(), true)
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					draw.SimpleText("#jcms.terminal_unlock", "jcms_hud_small", bx + bw/2, by + bh/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					render.OverrideBlend( false )
				cam.PopModelMatrix()
			end

			draw.SimpleText(active and "#jcms.terminal_active" or "#jcms.terminal_inactive", "jcms_hud_big", w/2, (h - 16)/2 + 32, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.PopModelMatrix()

		return buttonId
	end,

	gunlocker = function(ent, mx, my, w, h, modedata)
		local locked = ent:GetNWInt("jcms_terminal_locked")
		local class = modedata
		local empty = class == ""
		
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)

		if ent.jcms_cachedGunClass ~= class then
			ent.jcms_cachedGunClass = class
			ent.jcms_cachedGunData = jcms.gunstats_GetExpensive(class)
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
		
		cam.PushModelMatrix(getGlitchMatrix(), true)
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
	end,

	thumper_controls = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		draw.SimpleText("#jcms.terminal_thumpercontrols", "jcms_hud_medium", w/2, h/2, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		cam.PushModelMatrix(getGlitchMatrix(), true)
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
		cam.PushModelMatrix(getGlitchMatrix(), true)
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

		cam.PushModelMatrix(getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			draw.SimpleText(modedata == "1" and "#jcms.terminal_disable" or "#jcms.terminal_enable", "jcms_hud_small", bx + bw/2, by + bh/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			render.OverrideBlend( false )
		cam.PopModelMatrix()

		local c = modedata == "1" and Color(0,255,0) or Color(255,0,0)
		draw.RoundedBox(16, bx + bw + 32, h/2 + 32, 32, 32, color_bg)
		cam.PushModelMatrix(getGlitchMatrix(), true)
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
			cam.PushModelMatrix(getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				draw.SimpleText("#jcms.terminal_unlock", "jcms_hud_small", bx + bw/2, by + bh/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				render.OverrideBlend( false )
			cam.PopModelMatrix()
		end

		render.OverrideBlend( false )
		return btnId
	end,
	
	mainframe_terminal = function(ent, mx, my, w, h, modedata)
		local dataTbl = string.Explode( "_", modedata )
		local trackID = dataTbl[1]
		local unlocked = tobool(dataTbl[2])

		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		draw.SimpleText("#jcms.terminal_mainframe", "jcms_hud_small", 0, 0, color_bg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("#jcms.terminal_mainframe_controlpanel", "jcms_hud_small", 0, 30, color_bg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		surface.SetDrawColor(color_bg)
		surface.DrawRect(0, 0, w, h*0.85)

		--Title-bar stuff
		cam.PushModelMatrix(getGlitchMatrix(), true)
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

				cam.PushModelMatrix(getGlitchMatrix(), true)
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
				cam.PushModelMatrix(getGlitchMatrix(), true)
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					draw.SimpleText("#jcms.terminal_unlock", "jcms_hud_small", bx + bw/2, by + bh/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					render.OverrideBlend( false )
				cam.PopModelMatrix()
			end
		else
			--We're hacked, put something else under the track details.
			cam.PushModelMatrix(getGlitchMatrix(), true)
				draw.SimpleText("#jcms.terminal_mainframe_hacked", "jcms_hud_small", w/2, h*0.65, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					draw.SimpleText("#jcms.terminal_mainframe_hacked", "jcms_hud_small", w/2, h*0.65, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				render.OverrideBlend( false )
			cam.PopModelMatrix()
		end

		render.OverrideBlend( false )
		return btnId
	end,

	jcorpnuke = function(ent, mx, my, w, h, modedata)
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
	end,

	payload_controls = function(ent, mx, my, w, h, modedata)
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

		cam.PushModelMatrix(getGlitchMatrix(), true)
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
	end,
	
	shop = function(ent, mx, my, w, h, modedata)
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
			
			hook.Add("jcms_UpdatePrices", "jcms_UpdateShop", function()
				-- Lots of copypasted code unfortunately.
				if not ent.categorizedGuns then
					ent.categorizedGuns = {}
				else
					table.Empty(ent.categorizedGuns)
				end

				for weapon, cost in pairs(jcms.weapon_prices) do
					if cost <= 0 then continue end
					if not ent.gunStatsCache[ weapon ] then
						ent.gunStatsCache[ weapon ] = jcms.gunstats_GetExpensive(weapon)
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
			end)

			if not ent.categorizedGuns then hook.Call("jcms_UpdatePrices") end

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
							ent.gunStatsCache[ wepclass ] = jcms.gunstats_GetExpensive(wepclass)
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
							cam.PushModelMatrix( getGlitchMatrix(4, hov), true )
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
							local len = #wepstats.name
							draw.SimpleText(wepstats.name, len>10 and "jcms_small" or "jcms_medium", wx+wsize/2, wy+wsize/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
					ent.gunStatsCache[ wepclass ] = jcms.gunstats_GetExpensive(wepclass)
				end
				local stats = ent.gunStatsCache[ wepclass ]
				local owned = me:HasWeapon(wepclass)
				local imgSize = 256

				if mat and not mat:IsError() then
					surface.SetMaterial(mat)
					
					cam.PushModelMatrix(getGlitchMatrix(4), true)
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
							cam.PushModelMatrix(getGlitchMatrix(8), true)
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
							cam.PushModelMatrix(getGlitchMatrix(8), true)
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
							cam.PushModelMatrix(getGlitchMatrix(8), true)
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
			cam.PushModelMatrix(getGlitchMatrix(), true)
				local price = jcms.weapon_prices[hoveredWeaponClass]
				local canAfford = me:GetNWInt("jcms_cash", 0) >= price
				
				local col = canAfford and color_accent or color_bg
				local col_dark = canAfford and color_accent_dark or color_dark
				surface.SetDrawColor(col)
				
				local font = "jcms_hud_small"
				surface.SetFont(font)
				local tw = surface.GetTextSize(hoveredWeaponStats.name) + 32
				jcms.hud_DrawStripedRect(mx - tw/2 - 8, my + 32 - 8, tw + 16, 38 + 16, 64)
				surface.SetDrawColor(col_dark)
				surface.DrawRect(mx - tw/2, my + 32, tw, 38)
				draw.SimpleText(hoveredWeaponStats.name, "jcms_hud_small", mx, my + 48, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				draw.SimpleTextOutlined(jcms.util_CashFormat(price) .. " J", "jcms_hud_medium", mx, my + 108, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, col_dark)
			cam.PopModelMatrix()

			if me:KeyPressed(IN_USE) then
				RunConsoleCommand("jcms_buyweapon", hoveredWeaponClass)
			end
		elseif buttonId > 0 then
			return buttonId
		end
	end,

	spinners = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		
		local sSize, sStart, sGoal, map = (modedata or "2 0 0 0"):match("(%d+) (%d+) (%d+) (%w+)")
		local size = tonumber(sSize) or 8
		local startY = tonumber(sStart) or 1
		local goalY = tonumber(sGoal) or 1
		map = map or string.rep("0", size*size)
		
		local vh = math.min(w-32, h-32)
		local vw = vh
		local vx, vy = (w-vw)/2, (h-vh)/2
		local rw, rh = vw/size-4, vh/size-4

		local output
		local mtx, mty = math.floor((mx-vx) / (rw+4)) + 1, math.floor((my-vy) / (rh+4)) + 1
		local i = 0

		local syms = {
			["a"] = 1, ["b"] = 2, ["c"] = 3, ["d"] = 4, ["e"] = 5, ["f"] = 6,
			["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6
		}
		
		for y=1,size do
			for x=1,size do
				i = i + 1
				local rx, ry = vx + (rw+4)*(x-1), vy + (rh+4)*(y-1)
				local selected = x == mtx and y == mty
				if selected then output = i end
				local sym = map:sub(i,i)
				local completed = sym:match("%a") == sym

				render.OverrideBlend( false )
				surface.SetDrawColor(color_bg)
				surface.DrawRect(rx,ry,rw,rh)

				local u0 = (syms[sym]-1)/6
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				surface.SetMaterial(jcms.mat_maze)
				if completed or selected then
					surface.SetDrawColor(completed and color_accent or color_bg)
					surface.DrawTexturedRectUV(rx, ry, rw, rh, u0, 0.5, u0+1/6, 1)
				end

				cam.PushModelMatrix(getGlitchMatrix(5, -0.3), true)
					surface.SetDrawColor(selected and color_accent or color_fg)
					surface.DrawTexturedRectUV(rx, ry, rw, rh, u0, 0, u0+1/6, 0.5)

					if x == 1 and y == startY then
						render.OverrideBlend( false )
						draw.RoundedBoxEx(32, rx-32-4, ry+(rh-48)/2, 32, 48, color_bg, true, false, true, false)
						render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
						draw.SimpleText(">", "jcms_hud_small", rx-16, ry+rh/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					elseif x == size and y == goalY then
						render.OverrideBlend( false )
						draw.RoundedBoxEx(32, rx+rw+4, ry+(rh-48)/2, 32, 48, color_bg, false, true, false, true)
						render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
						draw.SimpleText(">", "jcms_hud_small", rx+rw+20, ry+rh/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end
				cam.PopModelMatrix()
				render.OverrideBlend( false )
			end
		end
		render.OverrideBlend(false)

		return output
	end,

	circuit = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		local split = string.Split(modedata, " ")
		if not(#split >= 3) then return end --Prevent errors if our modedata hasn't networked
		
		local selected = tonumber(split[4])
		local seed = ent:EntIndex() .. split[1]
		local count = #split[2]
		
		local properConnections = {}
		for i=1, count do
			local sym = string.sub(split[2], i, i)
			if not properConnections[sym] then
				properConnections[sym] = { i }
			else
				properConnections[sym][2] = i
			end
		end
		
		local locations = {}
		for i=1, count do
			local rn = util.SharedRandom("circuit"..seed, 150, 170, i)
			local a = math.pi*2/count*i
			local x, y = math.cos(a)*rn + w/2, math.sin(a)*rn + h/2
			locations[i] = { x, y, string.sub(split[2], i, i) }
		end
		
		local lastHover
		for i, loc in ipairs(locations) do
			local x, y, sym = unpack(loc)
			local hovered = math.Distance(mx, my, x, y) < 32
			local complete = split[3]:sub(tonumber(sym),tonumber(sym))=="1"

			if hovered and not complete then 
				lastHover = i 
				if selected then
					hovered = false
				end
			end
			
			if complete or selected == i then
				draw.NoTexture()
				local adif, len
				
				if selected == i then
					adif = math.atan2(y-my, x-mx)
					len = math.Distance(x, y, mx, my)
				end
				
				if complete then
					local info = properConnections[sym]
					if i == info[1] then
						local ox, oy = locations[info[2]][1], locations[info[2]][2]
						adif = math.atan2(y-oy, x-ox)
						len = math.Distance(x, y, ox, oy)
					end
				end
				
				if adif and len then
					local cos, sin = math.cos(adif)*len/2, math.sin(adif)*len/2
					surface.SetDrawColor(color_fg.r, color_fg.g, color_fg.b, 256/(len/200))
					surface.DrawTexturedRectRotated(x - cos, y - sin, len, 8, math.deg(-adif))
				end
			end
			
			draw.RoundedBox(32, x - 32, y - 32, 64, 64, (complete or selected==i) and color_fg or color_bg)
			
			if hovered or selected == i or complete then
				draw.SimpleText(sym, "jcms_hud_medium", x, y, (complete or selected==i) and color_bg or color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				
				if hovered then
					draw.SimpleText(sym, "jcms_hud_huge", w/2, h/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end
		end
		
		draw.SimpleText("#jcms.terminal_circuit_hint", "jcms_hud_small", w/2, 0, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText("#jcms.terminal_circuit_hint", "jcms_hud_small", w/2, -2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		
		if selected then
			return lastHover or 0
		else
			return lastHover
		end
	end,
	
	codematch = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		
		local split = string.Split(modedata, " ")
		if #split > 2 then
			local totalPieces = tonumber( split[1]:sub(1,1) ) or 0
			local wordSoFar = split[1]:sub(2, -1)
			local target = split[2]
			table.remove(split, 1)
			table.remove(split, 1)
			
			local off = 2
			local tw1 = draw.SimpleText("#jcms.terminal_find", "jcms_hud_small", 0, 24, color_bg) + 24
			local tw2, th2 = draw.SimpleText(target, "jcms_hud_big", tw1, -24, color_bg)
			
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText("#jcms.terminal_find", "jcms_hud_small", off, 24+off, color_fg)
				draw.SimpleText(target, "jcms_hud_big", tw1 + off, off-24, color_accent)
			render.OverrideBlend( false )
			
			
			surface.SetDrawColor(color_fg)
			surface.DrawRect(8, th2-24, w - 24, 4)
			surface.SetAlphaMultiplier(0.15)
			surface.SetDrawColor(color_bg)
			surface.DrawRect(8, th2-24+8, w/3, h-th2+24-8)
			
			local xcount, ycount = 4, 5
			local bw, bh = (w*2/3-8)/xcount - 5, (h-th2+24-8)/ycount
			
			local i = 0
			local hoverId
			for y=1, ycount do
				for x=1, xcount do
					i = i + 1
					local bx, by = w-bw*x, th2-24+8+bh*(y-1)
					if (hoverId==nil) and (mx > bx) and (my > by) and (mx <= bx + bw) and (my <= by + bh) then
						hoverId = i
					end
					
					local col = hoverId == i and color_accent or color_fg
					local off = 2
					
					local substr = split[i] or "??"
					local offset = hoverId==i and 0 or bh/8
					surface.SetAlphaMultiplier(1)
					surface.SetDrawColor(color_bg)
					surface.DrawRect(bx + off, by + off + offset, bw-4, bh-4 - offset*2)
					
					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					surface.SetAlphaMultiplier(hoverId == i and 1 or 0.2)
					surface.SetDrawColor(col)
					
					surface.SetAlphaMultiplier(1)
					surface.DrawOutlinedRect(bx + off, by + off + offset, bw-4, bh-4 - offset*2, 4)
					draw.SimpleText(substr, "jcms_hud_small", bx+bw/2-off, by+bh/2-off, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					render.OverrideBlend( false )
				end
			end
			
			local lx, ly = 32, th2 + 42
			for i=1, totalPieces do
				local subword = wordSoFar:sub((i-1)*2+1, i*2)
				
				if #subword > 0 then
					surface.SetDrawColor(color_accent)
					surface.DrawRect(lx, ly, 72, 4)
					draw.SimpleText(subword, "jcms_hud_small", lx + 8, ly - 4, color_accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				else
					surface.SetDrawColor(color_fg)
					surface.DrawRect(lx, ly, 32, 4)
				end
				
				ly = ly + 60
			end
			
			return hoverId
		end
	end,

	jeechblock = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)

		local target, written = unpack( modedata:Split(" ") )
		local str1 = "#jcms.terminal_writethisdown"
		local str2 = tostring(target or "")
		local str3 = tostring(written or "") .. (CurTime()%1<=0.5 and "_" or " ")

		draw.SimpleText(str1, "jcms_hud_small", w/2, 0, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(str2, "jcms_hud_medium", w/2, 32, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(str3, "jcms_hud_small", w/2, 114+24, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		
		local kb = { -- im so cool for writing this down myself
			{ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
			{ "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "<<<" },
			{ "A", "S", "D", "F", "G", "H", "J", "K", "L", "#jcms.confirm" },
			{ "Z", "X", "C", "V", "B", "N", "M", "#jcms.reset" }
		}

		for i, row in ipairs(kb) do
			local xbase = w/2-#row/2*48-12
			for j, sym in ipairs(row) do
				draw.SimpleText(sym, "jcms_hud_small", xbase+j*48 - (i==1 and 24 or 0), 168+i*42, color_bg, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end

		surface.SetDrawColor(jcms.color_dark)

		cam.PushModelMatrix(getGlitchMatrix(4, 0.05), true)
		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			draw.SimpleText(str1, "jcms_hud_small", w/2, 0, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText(str2, "jcms_hud_medium", w/2, 32, color_accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			surface.SetDrawColor(color_fg)
			surface.DrawOutlinedRect(16, 114, w-32, 48, 3)
			draw.SimpleText(str3, "jcms_hud_small", w/2, 114+24, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local hovBtnIndex = -1
			local btnIndex = 0
			for i, row in ipairs(kb) do
				local xbase = w/2-#row/2*48-12
				for j, sym in ipairs(row) do
					btnIndex = btnIndex + 1
					local bx, by = xbase+j*48 - (i==1 and 24 or 0), 168+i*42
					if hovBtnIndex == -1 then
						local hovered = false
						if #sym == 1 then
							hovered = math.DistanceSqr(bx, by, mx, my) <= 32*32
						else
							local dx, dy = mx - bx, my - by
							hovered = dx >= -8 and dx <= #sym*11 + 8 and dy >= -12 and dy <= 12
						end

						if hovered then
							hovBtnIndex = btnIndex
						end
					end
					draw.SimpleText(sym, "jcms_hud_small", bx, by, btnIndex == hovBtnIndex and color_accent or color_fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
			end
		render.OverrideBlend( false )
		cam.PopModelMatrix()

		return hovBtnIndex
	end
}

function jcms.terminal_GetCursor(pos, normal, fromPos, fromNormal)
	if not isvector(pos) or not isvector(normal) then return -math.huge, -math.huge end
	if not jcms.team_JCorp_player( jcms.locPly ) then return -math.huge, -math.huge end

	fromPos = fromPos or EyePos()
	fromNormal = fromNormal or EyeAngles():Forward()
	local v = util.IntersectRayWithPlane(fromPos, fromNormal, pos, normal)

	if v then
		local angle = normal:Angle()
		local difference = pos - v
		local x, y = difference:Dot( angle:Right() ), difference:Dot( angle:Up() )
		return x*32, y*32, v
	else
		return -math.huge, -math.huge
	end
end

function jcms.terminal_GetColors(ent)
	local theme = ent:GetNWString("jcms_terminal_theme", "jcorp")
	return unpack( jcms.terminal_themes[theme] or jcms.terminal_themes.jcorp )
end

function jcms.terminal_Render(ent, pos, angle, width, height)
	if render.GetRenderTarget() ~= nil then return end
	local modeType = ent:GetNWString("jcms_terminal_modeType")
	
	if (modeType ~= "") then
		local dist = EyePos():DistToSqr(pos)
		if dist > 500*500 then return false end
		local dot = (EyePos() - pos):Dot(angle:Up())
		if dot <= 0 then return end
		local modeDrawFunc = jcms.terminal_modeTypes[ modeType ]
		cam.Start3D2D(pos, angle, 1/32)
			local data = ent:GetNWString("jcms_terminal_modeData")
			local mx, my = jcms.terminal_GetCursor(pos, angle:Up())
			local output = modeDrawFunc(ent, mx, my, width, height, data)

			local locPly = LocalPlayer()
			local cd = CurTime() - (locPly.jcms_terminalCooldown or 0)

			local canUse = cd > 0.5
			if canUse and output and (output >= 0 and output <= 255) then
				if locPly:KeyDown(IN_USE) then
					jcms.net_SendTerminalInput(ent, output)
					locPly.jcms_terminalCooldown = CurTime()
				end
			end
		cam.End3D2D()
		return true
	end
end
