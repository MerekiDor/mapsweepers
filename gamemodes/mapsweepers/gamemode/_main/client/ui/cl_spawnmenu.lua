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

local offMatrix = Matrix()
local offVector = Vector(0, 0, 0)

if IsValid(jcms.spawnmenu_mouseCapturePanel) then
	jcms.spawnmenu_mouseCapturePanel:Remove()
end

-- // Orders {{{

	jcms.orders = jcms.orders or {}
	jcms.spawnmenu_scrolled = false
	
	function jcms.orders_Hash()
		return jcms.util_Hash(jcms.orders)
	end
	
	jcms.orders_lists = {}

	
	function jcms.orders_CanUse(orderId)
		local orderData = jcms.orders[ orderId ]
		if not orderData then return false end 

		local costMult, coolDownMult = jcms.class_GetCostMultipliers(jcms.class_GetLocPlyData(), orderData)
		local timeUntilUse = (orderData.nextUse or 0) - CurTime()
		local affordable = math.ceil(orderData.cost*costMult) <= jcms.locPly:GetNWInt("jcms_cash", 0)

		return (affordable and timeUntilUse <= 0)
	end
	
	function jcms.orders_RebuildLists()
		for i = 1, 8 do
			if not jcms.orders_lists[i] then
				jcms.orders_lists[i] = {}
			else
				table.Empty(jcms.orders_lists[i])
			end
		end
		
		for orderid, data in pairs(jcms.orders) do
			table.insert(jcms.orders_lists[(data.category or jcms.SPAWNCAT_UTILITY) + 1], orderid)
		end
		for _, catTbl in pairs(jcms.orders_lists) do --Consistent sorting/order.
			table.sort(catTbl, function(A, B) 
				return jcms.orders[A].slotPos < jcms.orders[B].slotPos
			end)
		end
	end
	
	jcms.orders_RebuildLists()

	

-- // }}}

-- // Order category materials {{{

	jcms.orders_categoryMats = {
		Material "jcms/orderwheel/turrets.png",
		Material "jcms/orderwheel/utility.png",
		Material "jcms/orderwheel/mines.png",
		Material "jcms/orderwheel/mobility.png",
		Material "jcms/orderwheel/orbitals.png",
		Material "jcms/orderwheel/supplies.png",
		Material "jcms/orderwheel/mission.png",
		Material "jcms/orderwheel/defensive.png"
	}

-- // }}}

-- // Aux {{{

	local function drawSegment(x, y, ang1, ang2, r1, r2, inset)
		ang1, ang2 = math.min(ang1, ang2), math.max(ang1, ang2)
		r1, r2 = math.min(r1, r2), math.max(r1, r2)
		inset = inset or 0

		local vtx = {
			{ x = x + math.cos(ang2)*r2, y = y + math.sin(ang2)*r2 },
			{ x = x + math.cos(ang2)*r1, y = y + math.sin(ang2)*r1 },
			{ x = x + math.cos(ang1)*r1, y = y + math.sin(ang1)*r1 },
			{ x = x + math.cos(ang1)*r2, y = y + math.sin(ang1)*r2 },
		}

		local cx, cy = x, y
		if inset > 0 then
			local n = #vtx
			cx, cy = 0, 0
			for i, v in ipairs(vtx) do
				cx = cx + v.x
				cy = cy + v.y
			end
			cx, cy = cx/n, cy/n

			for i, v in ipairs(vtx) do
				local dist = math.Distance(v.x, v.y, cx, cy)
				local ndist = math.max(dist - inset, 0)
				v.x = Lerp(ndist/dist, cx, v.x)
				v.y = Lerp(ndist/dist, cy, v.y)
			end
		end

		draw.NoTexture()
		surface.DrawPoly(vtx)
		return cx, cy
	end
	
	jcms.mousewheel = 0
	jcms.mousewheelOccupied = false 
	
	function jcms.mousewheel_Occupy()
		jcms.mousewheelOccupied = true
	end

-- // }}}

-- // Main {{{

	jcms.spawnmenu_isOpen = false
	jcms.spawnmenu_isContext = false
	jcms.spawnmenu_mouseCapturePanel = NULL
	jcms.spawnmenu_selectedOption = nil
	jcms.spawnmenu_selectedOrders = { 1, 1, 1, 1, 1, 1, 1, 1 }
	jcms.spawnmenu_lastUseTime = 0
	jcms.spawnmenu_tagKeyTranslation = { 7, 1, 3, 5, 8, 2, 4, 6 }
	jcms.spawnmenu_tagKeyTranslationAlt = { 2, 6, 3, 7, 4, 8, 1, 5 }

	function jcms.spawnmenu_Update()
		if (not jcms.spawnmenu_isOpen) then 
			return 
		end

		local selectedOption
		local fromKeyboard = false
		
		if jcms.spawnmenu_isContext then
			jcms.mousewheel_Occupy()
			for i=2, 9 do
				if input.IsKeyDown(i) then
					selectedOption = jcms.spawnmenu_tagKeyTranslation[i-1]
					fromKeyboard = true
					break
				end
			end
		end

		local mx, my = ScrW()/2, ScrH()/2
		if IsValid(jcms.spawnmenu_mouseCapturePanel) then
			mx, my = jcms.spawnmenu_mouseCapturePanel:LocalCursorPos()
		end
		
		if not selectedOption and math.DistanceSqr(mx, my, ScrW()/2, ScrH()/2) > (jcms.spawnmenu_isContext and 8*8 or 64*64) then
			local a = math.atan2(my-ScrH()/2, mx-ScrW()/2)
			if jcms.spawnmenu_isContext then
				local sector = math.floor( (a+math.pi/8)/(math.pi/4) )%8 + 1
				selectedOption = sector
			else
				local sector = math.floor( (a+math.pi/8)/(math.pi/4) )%8 + 1
				selectedOption = sector
				
				if jcms.spawnmenu_selectedOrders[sector] then
					local scrolled = false

					if jcms.mousewheel > 0 then
						jcms.spawnmenu_selectedOrders[sector] = math.min(jcms.spawnmenu_selectedOrders[sector] + 1, #jcms.orders_lists[sector])
						scrolled = true
					elseif jcms.mousewheel < 0 then
						jcms.spawnmenu_selectedOrders[sector] = math.max(jcms.spawnmenu_selectedOrders[sector] - 1, 1)
						scrolled = true
					elseif jcms.locPly:KeyPressed(IN_RELOAD) then
						jcms.spawnmenu_selectedOrders[sector] = (jcms.spawnmenu_selectedOrders[sector] % (#jcms.orders_lists[sector]) ) + 1
						scrolled = true
					end

					if scrolled then
						surface.PlaySound("weapons/zoom.wav")
						jcms.spawnmenu_scrolled = true
					end
				end
			end
		end

		jcms.spawnmenu_selectedOption = selectedOption
		if selectedOption and (fromKeyboard or input.IsMouseDown(MOUSE_LEFT)) then
			if jcms.spawnmenu_isContext then
				GAMEMODE:OnContextMenuClose()
			else
				if CurTime() - jcms.spawnmenu_lastUseTime > 0.25 then
					local selectionId = jcms.spawnmenu_selectedOrders[selectedOption]
					local ordersList = jcms.orders_lists[selectedOption]
					local selectedOrder = ordersList and jcms.orders_lists[selectedOption][ selectionId ]
					
					if selectedOrder then
						RunConsoleCommand("jcms_order", selectedOrder)
						GAMEMODE:OnSpawnMenuOpen()
					end
				end
			end
		end

	end

	local lasertracer = Material "effects/laser_tracer.vmt"
	function jcms.spawnmenu_PaintMouseCapture(p, w, h)
		local cx, cy = p:LocalCursorPos()
		local fx, fy = w/2, h/2
		local dist = math.Distance(cx, cy, fx, fy)
		
		local dir = math.atan2(cy-fy, cx-fx)
		local cos, sin = math.cos(dir), math.sin(dir)
		
		surface.SetMaterial(lasertracer)
		surface.SetDrawColor(jcms.color_bright)
		surface.DrawTexturedRectRotated(fx + cos*dist/2, fy + sin*dist/2, 16, dist, math.deg(-dir)+90)
		local size = Lerp(1-1/(dist/128+1), 8, 24)

		surface.SetDrawColor(jcms.color_bright)
		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
		jcms.draw_Circle(cx, cy, size, size, 2, 5)
		render.OverrideBlend( false )
		size = size - 4

		surface.SetDrawColor(jcms.color_alert)
		jcms.draw_Circle(cx, cy, size, size, 2, 5)
	end

	function jcms.spawnmenu_Draw()
		local blend = jcms.hud_spawnmenuAnim or 0
		if blend <= 0.03 then return end

		surface.SetAlphaMultiplier(blend^2)

		local sw, sh = ScrW()/2, ScrH()/2
		cam.Start2D()

		if jcms.spawnmenu_isContext then
			render.SetColorMaterial()
			draw.NoTexture()

			local span = math.pi*2/8
			local ca = -span/2 - span/2*(1-blend)

			local commands = { "attack", "airstrike", "look", "take", "defend", "help", "go", "meet" }
			
			for i=1, #commands do
				local clr = jcms.color_bright
				local clr_dark = jcms.color_dark
				if i == jcms.spawnmenu_selectedOption then
					clr = jcms.color_bright_alt
					clr_dark = jcms.color_dark_alt
				end
				
				local cos, sin = math.cos(ca+span/2), math.sin(ca+span/2)
				surface.SetDrawColor(clr.r, clr.g, clr.b, 72)
				drawSegment(sw, sh, ca, ca+span, 256 + (i%2==0 and 0 or 16), 128 + (i%2==0 and 32 or 0), 4)

				local dist = i%2==0 and 160 or 135
				local dist2 = i%2==0 and 72 or 64
				local alignX = cos > 0.2 and TEXT_ALIGN_LEFT or cos < -0.2 and TEXT_ALIGN_RIGHT or TEXT_ALIGN_CENTER
				local alignY = sin > 0.2 and TEXT_ALIGN_TOP or sin < -0.2 and TEXT_ALIGN_BOTTOM or TEXT_ALIGN_CENTER

				local text = language.GetPhrase("jcms." .. commands[i] .. "_cmd")
				draw.SimpleTextOutlined(text, "jcms_medium", sw+cos*dist, sh+sin*dist, clr, alignX, alignY, 1, clr_dark)
				draw.SimpleTextOutlined(jcms.spawnmenu_tagKeyTranslationAlt[i], i%2==0 and "jcms_small" or "jcms_big", sw+cos*dist2, sh+sin*dist2, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, clr_dark)

				ca = ca + span
			end
		else
			local span = math.pi*2/8
			local ca = -span/2*blend
			local dist = 150
			
			local myCash = LocalPlayer():GetNWInt("jcms_cash", 0)
			
			local classData = jcms.class_GetLocPlyData()
			
			for i=1, 8 do
				local clr = jcms.color_bright
				local clr_dark = jcms.color_dark
				local off, inset = 2, 4
				local alphamul = 1
				local cos, sin = math.cos(ca + span/2), math.sin(ca + span/2)
				
				local selectionId = jcms.spawnmenu_selectedOrders[i]
				local selectedOrder = jcms.orders_lists[i][ selectionId ]
				if not selectedOrder then
					alphamul = 0.25
				end
				
				if selectedOrder then
					local alignX = cos > 0.2 and TEXT_ALIGN_LEFT or cos < -0.2 and TEXT_ALIGN_RIGHT or TEXT_ALIGN_CENTER

					local orderData = jcms.orders[ selectedOrder ]
					local orderName = language.GetPhrase("jcms." .. selectedOrder)

					local costMult, coolDownMult = jcms.class_GetCostMultipliers(classData, orderData)
					local timeUntilUse = (orderData.nextUse or 0) - CurTime()
					local affordable = math.ceil(orderData.cost*costMult) <= myCash

					if (timeUntilUse > 0) or (not affordable) then
						alphamul = 0.25
					end

					if affordable and timeUntilUse <= 0 and i == jcms.spawnmenu_selectedOption then
						clr = jcms.color_bright_alt
						clr_dark = jcms.color_dark_alt
						off = 0
						inset = 2
					end

					surface.SetDrawColor(clr.r, clr.g, clr.b, 60*alphamul)
					drawSegment(sw, sh, ca, ca+span, 128, 128 + 64, 4)
					surface.SetDrawColor(clr, clr, clr, 255*alphamul)
					drawSegment(sw, sh, ca, ca+span, 128 - 4 - off, 128 - off, inset)

					if (i == jcms.spawnmenu_selectedOption or timeUntilUse >= 0 or i-1 == jcms.SPAWNCAT_MISSION) then
						local tx, ty = sw + cos*dist, sh + sin*dist - 2 - 16
						-- Detailed view

						if not affordable then
							surface.SetAlphaMultiplier(0.5 * blend^2)
						end

						local tw, th = draw.SimpleTextOutlined(orderName, "jcms_medium", tx, ty, clr, alignX, TEXT_ALIGN_BOTTOM, 1, clr_dark)
						if timeUntilUse <= 0 then
							ty = ty + th - 8
							tw, th = draw.SimpleTextOutlined(jcms.util_CashFormat(math.ceil(orderData.cost*costMult)) .. " (J)", "jcms_missiondesc", tx, ty-4, clr, alignX, TEXT_ALIGN_CENTER, 1, clr_dark)

							ty = ty + th + 4
							draw.SimpleTextOutlined(language.GetPhrase("jcms.cooldown"):format(string.FormattedTime(math.ceil(orderData.cooldown*coolDownMult), "%02i:%02i")), "jcms_small", tx, ty, clr, alignX, TEXT_ALIGN_BOTTOM, 1, clr_dark)
						else
							ty = ty + th - 4
							draw.SimpleTextOutlined(language.GetPhrase("jcms.cooldown"):format(string.FormattedTime(timeUntilUse, "%02i:%02i")), "jcms_missiondesc", tx, ty, jcms.color_alert, alignX, TEXT_ALIGN_BOTTOM, 1, clr_dark)
						end

						if not affordable then
							surface.SetAlphaMultiplier(blend^2)
						end
					else
						local tx, ty = sw + cos*(dist + 16), sh + sin*(dist + 16) - 2

						surface.SetMaterial(jcms.orders_categoryMats[i])
						surface.SetDrawColor(clr)
						surface.DrawTexturedRectRotated(tx, ty, 64, 64, 0)
					end
				else
					surface.SetDrawColor(clr.r, clr.g, clr.b, 60*alphamul)
					drawSegment(sw, sh, ca, ca+span, 128, 128 + 64, 4)
				end
				
				ca = ca + span
			end
			
			if jcms.spawnmenu_selectedOption then
				local selectedOption = jcms.spawnmenu_selectedOption
				local selectionId = jcms.spawnmenu_selectedOrders[selectedOption]
				local orderList = jcms.orders_lists[selectedOption]
				
				local selectedOrder = orderList[selectionId]
				local orderData = jcms.orders[ orderList[selectionId] ]
				if orderData then
					local orderDesc = language.GetPhrase("jcms." .. selectedOrder .. "_desc")
					draw.SimpleTextOutlined(orderDesc, "jcms_small", ScrW()/2, ScrH()/2 - 228, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, jcms.color_dark)
				end
				
				local maxDisplayed = 11
				local th = 20

				local oldAlphaMul = surface.GetAlphaMultiplier()
				for i, order in ipairs(orderList) do
					local iOff = i - selectionId + 1
					if iOff < -maxDisplayed/2+1 or iOff > maxDisplayed/2+1 then
						continue
					end
					
					local orderData = jcms.orders[ order ]
					local orderName = language.GetPhrase("jcms." .. order)
					
					local costMult, coolDownMult = jcms.class_GetCostMultipliers(classData, orderData)
					local timeUntilUse = (orderData.nextUse or 0) - CurTime()
					local affordable = math.ceil(orderData.cost*costMult) <= myCash
					
					if ((timeUntilUse > 0) or (not affordable)) and (i == selectionId) then
						surface.SetAlphaMultiplier(oldAlphaMul*0.25)
					end
				
					local clr = jcms.color_bright
					local clr_dark = jcms.color_dark
					
					if i == selectionId then
						clr = jcms.color_bright_alt
						clr_dark = jcms.color_dark_alt
					end
				
					if (affordable and timeUntilUse <= 0) or (i == selectionId) then
						local tw, th = draw.SimpleTextOutlined(orderName, "jcms_small", ScrW()/2, ScrH()/2 - (iOff-1)*th, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, clr_dark)
						
						if i == selectionId then
							local pulse = Lerp(math.abs(math.cos(CurTime()*4)), 6, 12) + tw/2
							draw.SimpleTextOutlined("[", "jcms_small", ScrW()/2 - pulse, ScrH()/2 - (iOff-1)*th, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, clr_dark)
							draw.SimpleTextOutlined("]", "jcms_small", ScrW()/2 + pulse, ScrH()/2 - (iOff-1)*th, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, clr_dark)
						end
					else
						draw.SimpleText(orderName, "jcms_small", ScrW()/2, ScrH()/2 - (iOff-1)*th, clr_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end

					surface.SetAlphaMultiplier(oldAlphaMul)
				end
			end

			if jcms.hud_spawnmenuAnimScrollTip > 0.03 then
				local blend2 = math.ease.InOutCirc(jcms.hud_spawnmenuAnimScrollTip)
				surface.SetAlphaMultiplier(blend2)

				local tipx, tipy = ScrW()/2, ScrH() * 0.75
				surface.SetFont("jcms_medium")
				local tw, th = surface.GetTextSize("#jcms.orderscrolltip")

				surface.SetDrawColor(jcms.color_dark_alt)
				surface.DrawRect(tipx - tw/2 - 16, tipy - th/2 - 12, tw + 32, th + 24)

				surface.SetDrawColor(jcms.color_bright_alt)
				surface.DrawRect(tipx - tw/2, tipy - th/2 - 12, tw, 1)
				surface.DrawRect(tipx - tw/2, tipy + th/2 + 11, tw, 1)
				jcms.hud_DrawStripedRect(tipx-tw/2-16, tipy - th/2 - 12, 4, th + 24, 32, CurTime()%1 * 24)
				jcms.hud_DrawStripedRect(tipx+tw/2+16-4, tipy - th/2 - 12, 4, th + 24, 32, CurTime()%1 * 24)
				local _, th2 = draw.SimpleText("#jcms.orderscrolltip", "jcms_medium", tipx, tipy - 4, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				
				surface.SetAlphaMultiplier(0.5*blend2)
				local binding = input.LookupBinding("+reload") or "???"
				local str = language.GetPhrase("jcms.orderscrolltip_alt"):format( binding:upper() )
				draw.SimpleText(str, "jcms_small_bolder", tipx, tipy + th2/2 + 2, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				surface.SetAlphaMultiplier(1)
			end
		end

		surface.SetAlphaMultiplier(1)
		cam.End2D()
	end

-- // }}}

-- // Overrides {{{

	function jcms.spawnmenu_MakeMouseCapturePanel()
		if IsValid(jcms.spawnmenu_mouseCapturePanel) then
			jcms.spawnmenu_mouseCapturePanel:Remove()
		end

		local p = GetHUDPanel():Add("DPanel")
		function p:OnMouseWheeled(d)
			jcms.mousewheel = d
		end
		jcms.spawnmenu_mouseCapturePanel = p
		p:SetSize(ScrW(), ScrH())
		p:Center()
		p:SetPaintBackground(false)
		p:MakePopup()
		p:SetKeyboardInputEnabled(false)
		p:SetCursor("crosshair")
		p.Paint = jcms.spawnmenu_PaintMouseCapture

		return jcms.spawnmenu_mouseCapturePanel
	end

	function GM:OnSpawnMenuOpen()
		if jcms.spawnmenu_isOpen then
			jcms.spawnmenu_isOpen = false
			jcms.spawnmenu_selectedOption = nil

			if IsValid(jcms.spawnmenu_mouseCapturePanel) then
				jcms.spawnmenu_mouseCapturePanel:Remove()
			end
		else
			local ply = LocalPlayer()
			
			if (ply:GetObserverMode() ~= OBS_MODE_NONE) then
				return
			else
			
				if jcms.team_JCorp_player(ply) then
					jcms.spawnmenu_isOpen = true
					jcms.spawnmenu_isContext = false
					jcms.spawnmenu_MakeMouseCapturePanel()
					surface.PlaySound("ambient/levels/citadel/pod_open1.wav")
				elseif jcms.team_NPC(ply) then
					RunConsoleCommand("jcms_order")
				end

			end
		end
	end

	function GM:OnSpawnMenuClose()
		--[[if not jcms.spawnmenu_isContext then
			jcms.spawnmenu_isOpen = false
			jcms.spawnmenu_selectedOption = nil
		end

		if IsValid(jcms.spawnmenu_mouseCapturePanel) then
			jcms.spawnmenu_mouseCapturePanel:Remove()
		end]]
	end

	function GM:OnContextMenuOpen()
		local ply = LocalPlayer()
		
		if (ply:GetObserverMode() ~= OBS_MODE_NONE) then
			return
		end
			
		if jcms.team_JCorp_player(ply) then
			jcms.spawnmenu_isOpen = true
			jcms.spawnmenu_isContext = true
			jcms.spawnmenu_MakeMouseCapturePanel()
		end
	end

	function GM:OnContextMenuClose()
		if jcms.spawnmenu_isContext then
			jcms.spawnmenu_isOpen = false

			if jcms.spawnmenu_selectedOption then
				surface.PlaySound("buttons/lightswitch2.wav")
				RunConsoleCommand("jcms_signal", tostring(jcms.spawnmenu_selectedOption))
				jcms.spawnmenu_selectedOption = nil
			end
		end

		if IsValid(jcms.spawnmenu_mouseCapturePanel) then
			jcms.spawnmenu_mouseCapturePanel:Remove()
		end
	end

-- // }}}

-- // Scoreboard {{{

	function jcms.paint_scoreboard_PanelPlayers(p, w, h)
		surface.SetDrawColor(jcms.color_dark.r, jcms.color_dark.g, jcms.color_dark.b, 230)
		jcms.hud_DrawFilledPolyButton(0, 0, w, h)
		
		surface.SetDrawColor(jcms.color_bright)
		jcms.hud_DrawHollowPolyButton(0, 0, w, h)

		local str = language.GetPhrase("jcms.online"):format(player.GetCount(), game.MaxPlayers())
		draw.SimpleText(str, "jcms_small_bolder", 8, 12, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	function jcms.paint_scoreboard_PanelServerInfo(p, w, h)
		surface.SetDrawColor(jcms.color_dark.r, jcms.color_dark.g, jcms.color_dark.b, 230)
		jcms.hud_DrawFilledPolyButton(0, 0, w, h)
		
		surface.SetDrawColor(jcms.color_bright)
		jcms.hud_DrawHollowPolyButton(0, 0, w, h)

		local name = GetHostName()
		surface.SetFont("jcms_medium")
		local tw = surface.GetTextSize(name)
		draw.SimpleText(name, tw>=w*0.9 and "jcms_small_bolder" or "jcms_medium", w/2, 4, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(game.GetMap(), "jcms_small_bolder", w/2, 28, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		
		surface.SetDrawColor(jcms.color_pulsing)
		surface.DrawRect(16, 52, w-32, 1)
		surface.DrawRect(24, 74, w-48, 1)

		draw.SimpleText("#jcms."..jcms.util_GetMissionType(), "jcms_small_bolder", 20, (52+74)/2, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("#jcms."..jcms.util_GetMissionFaction(), "jcms_small_bolder", w-20, (52+74)/2, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		local time = string.FormattedTime( jcms.util_GetMissionTime() )
		local formatted = string.format("%02i:%02i:%02i", time.h, time.m, time.s)
		draw.SimpleText(formatted, "jcms_small_bolder", w/2, (52+74)/2, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	
		draw.SimpleText("#jcms.winstreak", "jcms_small_bolder", w/4, 100, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("x"..jcms.util_GetCurrentWinstreak(), "jcms_big", w/4, 112, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText("#jcms.difficulty", "jcms_small_bolder", w*3/4, 100, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(string.format("%d%%", jcms.util_GetCurrentDifficulty()*100), "jcms_big", w*3/4, 112, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	
		local level, exp = jcms.statistics_GetLevelAndEXP()
		local nextLevelExp = jcms.statistics_GetEXPForNextLevel(level + 1)

		surface.SetDrawColor(jcms.color_pulsing)
		surface.DrawOutlinedRect(18+48+8, 186, w-(18*2+48+8), 10)
		surface.SetDrawColor(jcms.color_bright)
		surface.DrawRect(18, 168, 48, 28)
		surface.DrawRect(18+48+8, 186, (w-(18*2+48+8))*math.Clamp(exp/nextLevelExp, 0, 1), 10)
		draw.SimpleText(("%s / %s EXP"):format(jcms.util_CashFormat(exp), jcms.util_CashFormat(nextLevelExp)), "jcms_small_bolder", 18+48+8, 184, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		draw.SimpleText(level, level>9999 and "jcms_small_bolder" or "jcms_medium", 18+48/2, 168+14, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	function jcms.paint_scoreboard_ScrollPanel(p, w, h)
		surface.SetDrawColor(jcms.color_pulsing)
		jcms.hud_DrawHollowPolyButton(0, 0, w, h)
	end

	function jcms.paint_scoreboard_Player(p, w, h)
		local i, ply = p.i, p.ply
		local myTeam = jcms.locPly:GetNWInt("jcms_pvpTeam", -1)
		local theirTeam = ply:GetNWInt("jcms_pvpTeam", -1)
		local canShowInfo = (theirTeam == -1) or (myTeam == theirTeam)

		surface.SetDrawColor(jcms.color_bright)
		surface.DrawRect(16, h-1, w-32, 1)

		local isSweeper = ply:Team() == 1
		local isNPC = ply:Team() == 2

		local evacuated = ply:GetNWBool("jcms_evacuated", false)
		local dead = (not evacuated) and (not ply:Alive() or ply:GetObserverMode() == OBS_MODE_CHASE)

		local ox, oy = dead and math.Rand(-1, 1) or 0, dead and math.Rand(-1, 1) or 0
		if dead or evacuated then
			surface.SetAlphaMultiplier(0.5)
		end

		if canShowInfo then
			local tgclass = ply:GetNWString("jcms_class")

			local classmat = evacuated and jcms.mat_evac or jcms.mat_GetClassMat(tgclass)
			if classmat and not classmat:IsError() then
				surface.SetMaterial(classmat)
				surface.SetDrawColor(jcms.color_bright)
				surface.DrawTexturedRect(5+ox, 2+oy, 16, 16)
			end
		end

		local nick = ply:Nick()
		surface.SetFont("jcms_small_bolder")
		local nw = surface.GetTextSize(nick)
		draw.SimpleText(nick, nw >= 100 and "DefaultVerySmall" or "jcms_small_bolder", 25+ox, h/2-1+oy, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local pingString = ply:IsBot() and "BOT" or ply:Ping().."ms"
		draw.SimpleText(pingString, "jcms_small", w - 4 + ox, h/2-1 + oy, jcms.color_pulsing, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		
		if isSweeper and canShowInfo then
			local cashString = jcms.util_CashFormat(ply:GetNWInt("jcms_cash", 0)) .. "J"
			draw.SimpleText(cashString, "jcms_small", w - 4 - 58 + ox, h/2-1 + oy, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		elseif isNPC then
			draw.SimpleText("NPC", "jcms_small", w - 4 - 58 + ox, h/2-1 + oy, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		local vol = ply:VoiceVolume()
		if vol > 0 and ply:IsSpeaking() then
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			jcms.hud_DrawNoiseRect(0, 0, vol*w, h)
			render.OverrideBlend( false )
		end
		
		if not (dead or evacuated) and isSweeper and canShowInfo then
			local healthWidth = ply:GetMaxHealth()/2
			local healthFrac = math.Clamp(ply:Health() / ply:GetMaxHealth(), 0, 1)
			local armorWidth = ply:GetMaxArmor()/2
			local armorFrac = math.Clamp(ply:Armor() / ply:GetMaxArmor(), 0, 1)

			surface.SetDrawColor(jcms.color_bright)
			surface.DrawRect(140, 5, healthWidth*healthFrac, 4)
			if healthFrac<1 then
				jcms.hud_DrawStripedRect(140+healthWidth*healthFrac, 5, healthWidth*(1-healthFrac), 4, 16)
			end

			surface.SetDrawColor(jcms.color_bright_alt)
			surface.DrawRect(140, 11, armorWidth*armorFrac, 4)
			if armorFrac<1 then
				jcms.hud_DrawStripedRect(140+armorWidth*armorFrac, 11, armorWidth*(1-armorFrac), 4, 16)
			end
		end

		surface.SetAlphaMultiplier(1)
		return true
	end

	function jcms.paint_scoreboard_Controls(p, w, h)
		surface.SetDrawColor(jcms.color_pulsing)
		jcms.hud_DrawHollowPolyButton(0, 0, w, h)
	end

	function jcms.paint_scoreboard_Header(p, w, h)
		surface.SetDrawColor(p:GetBackgroundColor())
		jcms.hud_DrawFilledPolyButton(0, 0, w, h)

		local name = language.GetPhrase("jcms.pvp_team" .. p.pvpTeam)
		draw.SimpleText(name, "jcms_medium", w/2, h/2, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local mat = jcms.hud_GetPVPTeamMat(p.pvpTeam)
		surface.SetDrawColor(0, 0, 0, 200)
		surface.SetMaterial(mat)
		surface.DrawTexturedRect(16, 2, h-4, h-4)
		surface.DrawTexturedRect(w-16-h+4, 2, h-4, h-4)
	end

	function jcms.scoreboard_SetupPlayerElement(elem)
		function elem:DoClick()
			local m = DermaMenu()
			m:AddOption("#jcms.scoreboard_profile", function()
				if IsValid(elem) and IsValid(elem.ply) then
					elem.ply:ShowProfile()
				end
			end)

			m:AddOption(elem.ply:IsMuted() and "#jcms.scoreboard_unmute" or "#jcms.scoreboard_mute", function()
				if IsValid(elem) and IsValid(elem.ply) then
					elem.ply:SetMuted(not elem.ply:IsMuted())
				end
			end):SetIcon(elem.ply:IsMuted() and "materials/icon16/sound.png" or "materials/icon16/sound_mute.png")

			if jcms.locPly:IsAdmin() then
				m:AddSpacer()
				m:AddOption("#jcms.scoreboard_respawn", function()
					if IsValid(elem) and IsValid(elem.ply) then
						RunConsoleCommand("jcms_forcerespawn", elem.ply:EntIndex())
					end
				end):SetIcon("icon16/shield.png")
				local sm, sm_parent = m:AddSubMenu("#jcms.scoreboard_givecash")
				sm_parent:SetIcon("icon16/shield.png")

				for i, count in ipairs { 100, 500, 1000, 5000, 10000 } do
					sm:AddOption("+"..count, function()
						if IsValid(elem) and IsValid(elem.ply) then
							RunConsoleCommand("jcms_givecash", count, elem.ply:EntIndex())
						end
					end)
				end
			end
			hook.Run("MapSweepersScoreboardPlayerMenu", m, elem, elem.ply, elem.i)
			m:Open()
		end
	end

	function GM:ScoreboardShow()
		local pnl = jcms.spawnmenu_MakeMouseCapturePanel()
		local cx, cy = ScrW()/2, ScrH()/2

		local p_left = pnl:Add("DPanel")
		p_left:SetSize(390, 470)
		p_left:SetPos(cx - p_left:GetWide() - 48, cy - p_left:GetTall()/2)
		p_left.Paint = jcms.paint_scoreboard_PanelPlayers
		p_left.plyDict = {}
		p_left:DockPadding(8, 24, 8, 8)

		if jcms.util_IsPVP() then
			local header_jcorp = p_left:Add("DPanel")
			header_jcorp:Dock(TOP)
			header_jcorp:DockMargin(0, 0, 0, 4)
			header_jcorp:SetBackgroundColor(Color(255, 32, 32))
			header_jcorp.Paint = jcms.paint_scoreboard_Header
			header_jcorp.pvpTeam = 1

			local team1 = p_left:Add("DScrollPanel")
			team1:Dock(TOP)
			team1:SetTall(188)
			team1:DockMargin(0, 0, 0, 4)
			team1.Paint = jcms.paint_scoreboard_ScrollPanel
			if IsValid(team1.VBar) then
				team1.VBar.Paint = BLANK_DRAW
				team1.VBar:SetHideButtons(true)
				team1.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
			end

			local header_mafia = p_left:Add("DPanel")
			header_mafia:Dock(TOP)
			header_mafia:DockMargin(0, 0, 0, 4)
			header_mafia:SetBackgroundColor(Color(255, 217, 32))
			header_mafia.Paint = jcms.paint_scoreboard_Header
			header_mafia.pvpTeam = 2

			local team2 = p_left:Add("DScrollPanel")
			team2:Dock(TOP)
			team2:SetTall(188)
			team2:DockMargin(0, 0, 0, 4)
			team2.Paint = jcms.paint_scoreboard_ScrollPanel
			if IsValid(team2.VBar) then
				team2.VBar.Paint = BLANK_DRAW
				team2.VBar:SetHideButtons(true)
				team2.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
			end

			function p_left.Think()
				for ply, elem in pairs(p_left.plyDict) do
					if not IsValid(ply) or not IsValid(elem) then
						elem:Remove()
						p_left.plyDict[ply] = nil
					end
				end

				for i, ply in ipairs(player.GetAll()) do
					local team = ply:GetNWInt("jcms_desiredteam", 0)
					if team ~= 1 then continue end

					local pvpTeam = ply:GetNWInt("jcms_pvpTeam", -1)
					local elem = p_left.plyDict[ ply ]
					local intendedParent

					if pvpTeam == 1 then
						intendedParent = team1
					elseif pvpTeam == 2 then
						intendedParent = team2
					end

					if not intendedParent then continue end

					if not elem or not IsValid(elem) then
						elem = intendedParent:Add("DButton")
						elem:Dock(TOP)
						elem:DockMargin(2, 2, 2, 0)
						elem.Paint = jcms.paint_scoreboard_Player
						jcms.scoreboard_SetupPlayerElement(elem)
						p_left.plyDict[ ply ] = elem
					else
						elem:SetParent(intendedParent)
						elem:Dock(TOP)
					end

					elem.ply = ply
					elem.i = i
				end
			end
		else
			local sweepers = p_left:Add("DScrollPanel")
			sweepers:Dock(TOP)
			sweepers:SetTall(250)
			sweepers:DockMargin(0, 0, 0, 4)
			sweepers.Paint = jcms.paint_scoreboard_ScrollPanel
			if IsValid(sweepers.VBar) then
				sweepers.VBar.Paint = BLANK_DRAW
				sweepers.VBar:SetHideButtons(true)
				sweepers.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
			end

			local npcs = p_left:Add("DScrollPanel")
			npcs:Dock(FILL)
			npcs.Paint = jcms.paint_scoreboard_ScrollPanel
			if IsValid(npcs.VBar) then
				npcs.VBar.Paint = BLANK_DRAW
				npcs.VBar:SetHideButtons(true)
				npcs.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
			end

			function p_left.Think()
				for ply, elem in pairs(p_left.plyDict) do
					if not IsValid(ply) or not IsValid(elem) then
						elem:Remove()
						p_left.plyDict[ply] = nil
					end
				end

				for i, ply in ipairs(player.GetAll()) do
					local team = ply:GetNWInt("jcms_desiredteam", 0)
					local elem = p_left.plyDict[ ply ]
					local intendedParent
					
					if team == 1 then
						intendedParent = sweepers
					else
						intendedParent = npcs
					end

					if not elem or not IsValid(elem) then
						elem = intendedParent:Add("DButton")
						elem:Dock(TOP)
						elem:DockMargin(2, 2, 2, 0)
						elem.Paint = jcms.paint_scoreboard_Player
						jcms.scoreboard_SetupPlayerElement(elem)
						p_left.plyDict[ ply ] = elem
					else
						elem:SetParent(intendedParent)
						elem:Dock(TOP)
					end

					elem.ply = ply
					elem.i = i
				end
			end
		end

		local p_right = pnl:Add("DPanel")
		p_right:SetSize(390, 420)
		p_right:SetPos(cx + 48, cy - p_right:GetTall()/2)
		p_right.Paint = jcms.paint_scoreboard_PanelServerInfo
		p_right:DockPadding(8, 24, 8, 8)

		local controls = p_right:Add("DScrollPanel")
		controls:Dock(BOTTOM)
		controls:DockMargin(4, 0, 4, 4)
		controls:SetTall(190)
		controls.Paint = jcms.paint_scoreboard_Controls
		controls:DockPadding(4, 4, 4, 4)
		if IsValid(controls.VBar) then
			controls.VBar.Paint = BLANK_DRAW
			controls.VBar:SetHideButtons(true)
			controls.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
		end

		hook.Run("MapSweepersScoreboardControls", controls) -- Use this to add your own buttons to the scoreboard.
	end

	function GM:ScoreboardHide()
		if IsValid(jcms.spawnmenu_mouseCapturePanel) then
			jcms.spawnmenu_mouseCapturePanel:Remove()
		end
	end

-- // }}}
