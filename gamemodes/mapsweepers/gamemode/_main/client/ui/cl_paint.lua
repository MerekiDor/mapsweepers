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
	
	local level_ids = {
		["-2"] = 1,
		["-1"] = 2,
		["0"] = 3,
		["1"] = 4,
		["2"] = 5
	}
	
	local BLANK_DRAW = function() return true end

	local specialTexts = {
		["38f1f3e9410f60dd482026c2422322de5c548f49486641a6f0727732c92aae2a"] = "creator",
		["74ca5f72412bf8e2f408ea574bd9febdc1c0a88d94ba2f20ec9e6224f26179ca"] = "creator",

		["0e062e54c32c8eb7469aa84498fc60c2f2ad265961a499df4c45ac2f6610a016"] = "beta",
		["dc4617818bdcc3af96d716ec70b492638cdc075cf5ad7485452f0c798c9e5bcf"] = "beta",
		["4f92d868130e272c86a99ad26e3a4f0d920ad58d069aa59ee1b7d98568553a9f"] = "beta",
		["48f04893f12ffdd62342de3f63664b0c5ac941d0852c61f787c3e1ae3e2e1051"] = "beta",
		["5a42f186e685f1ac3087de065dd3b18a4798b884cdadba5df37c317af50497f3"] = "beta",
		["adbdc18a436c3d1a1f2544a98351eef55212800855a2d3e0795c2a7d116936c5"] = "beta",
		["9e05d7904911bb302535ed460d12b0a96a4ceabc303a36ef57372b848a85775c"] = "beta",
		["101449ca879207d041035e8a7c8d07db99dd16aa37626b1a66799084d6ea5594"] = "beta",
		["59ef25e24eb7b5eeabcc4ad1b85586314890fd5a1c71102db4ec82462aa14e64"] = "beta",
		["43085fee8c50e3159042bb86701f2985bc3f9c7d3219a359b7a965202e87c5f0"] = "beta",
		["05970fb36a49ce78bf4948e07f3ea4aeb68d34cb9983bed01ce2fc5b20767fcd"] = "beta",
		["f6d70cdd7d219f2e8530ad0c5c5e9944ed7af698ea2d9e0b9807ac8b2a79e9dc"] = "beta",
		["07a03556a1d529a6c704b5e59f87108eee88adae733aadd9613b26f90c60d947"] = "beta",
		["53244897389c48c988a59ea99bd1cf71bed7959c17be20e2bc35804b1b2b893e"] = "beta",

		["fef48441d1120d940ce10aa072c5afbcdd6a06fdfae839b879a82848b25a17ba"] = "supporter",
		["185f5d86bf27e1920a57b7664087c41f3862f01b215f39e099fb12a31ded0db2"] = "supporter",
		["6fd09cbbf6c5c986667a5145d430d7bc4c085a6b6c5b94397a3c1b5993612bda"] = "supporter",

		["71989b94d1ec6ce1e559b8ff2a0bfb7f766950aef7f4355a571100c5ba2261a0"] = "supporter", -- do
		["41d98165e676f01874738c2e88a98869007fb9216f0fb810b585d7d49877f39d"] = "supporter", -- ss
		["4b0bf4d9b4a8b6a5d2dd3cb1c0cdeb8479724e5de7cd8313a1a8c82541cdcf37"] = "supporter", -- na
		["02a7975c58da0334e0e5f8de91b0d9a2b8d29ef5d2352d2e821ed1219e445bb1"] = "supporter", -- de

		["0718768ecdf6b1aa28d7a41f6c0262e581fa533fd6c09128f86363d3147e3575"] = "supporter", --fl

		["310d9af23cf5c7a9f88db0c190da0232e0f9a07d62c2d21acc319e78aa46b9f2"] = "supporter", --pu
		["7b49561611f4c10cbcbe14e803533bc622629404d6a57dcedbbe97b00c71ed12"] = "supporter", --pe
		["50bc3e923a5641c5c528601f2a114c1a867428dc30d2cd049c907e9ba5e3ecfa"] = "supporter", --sc
	}

	function jcms.hud_GetSpecialText(ply)
		if not ply.__s64hash then
			ply.__s64hash = util.SHA256( ply:SteamID64() )
		end

		if specialTexts[ply.__s64hash] then
			return specialTexts[ply.__s64hash]
		elseif ply:IsSuperAdmin() then
			return "superadmin"
		elseif ply:IsAdmin() then
			return "admin"
		end
	end

-- // }}}

-- // Other Drawing {{{

	local function drawHollowPolyButton(x, y, w, h, pad)
		pad = math.min(w/2, pad or 8)
		
		draw.NoTexture()
		surface.DrawPoly {
			{ x = x, y = y+pad },
			{ x = x+pad, y = y },
			{ x = x+pad+1, y = y },
			{ x = x+1, y = y+pad }
		}
		
		surface.DrawPoly {
			{ x = x+w-1, y = y+h-pad },
			{ x = x+w, y = y+h-pad },
			{ x = x+w-pad, y = y+h },
			{ x = x+w-pad-1, y = y+h }
		}
		
		surface.DrawRect(x+pad, y, w-pad, 1)
		surface.DrawRect(x, y+h-1, w-pad, 1)
		surface.DrawRect(x, y+pad, 1, h-pad)
		surface.DrawRect(x+w-1, y, 1, h-pad)
	end
	
	local function drawFilledPolyButton(x, y, w, h, pad)
		pad = math.min(w/2, pad or 8)
		draw.NoTexture()
		surface.DrawPoly {
			{ x = x, y = y+pad },
			{ x = x+pad, y = y },
			{ x = x+w, y = y },
			{ x = x+w, y = y+h-pad },
			{ x = x+w-pad, y = y+h },
			{ x = x, y = y+h }
		}
	end
	
	local function drawStat(str, level, x1, x2, y, w, h)
		level = tostring(level)
		draw.SimpleText(str, "TargetID", x1, y+h/2, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		
		local clr = (level=="1" or level=="2") and jcms.color_bright_alt or jcms.color_bright
		surface.SetDrawColor(clr)
		
		local num = level_ids[ level ] or 3
		local piece_w = w/5 - 2
		for i=1, 5 do
			if i <= num then
				drawFilledPolyButton(x2 + (piece_w + 2)*(i-1), y, piece_w, h, 4)
			else
				drawHollowPolyButton(x2 + (piece_w + 2)*(i-1), y, piece_w, h, 4)
			end
		end
	end
	
	jcms.hud_DrawHollowPolyButton = drawHollowPolyButton
	jcms.hud_DrawFilledPolyButton = drawFilledPolyButton

-- // }}}

-- // Painting elements {{{

	function jcms.paint_Panel(p, w, h)
		surface.SetDrawColor(jcms.color_pulsing)
		drawHollowPolyButton(0, -1, w, h)
		
		if p.jText then
			local font = p.jFont or "jcms_medium"
			surface.SetFont(font)

			local tw, th = surface.GetTextSize(p.jText)
			jcms.hud_DrawNoiseRect(8, 0, w - 16, th + 2)
			draw.SimpleText(p.jText, font, w/2, 0, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	end

	function jcms.paintover_PanelClarify(p, w, h)
		surface.SetDrawColor(jcms.color_pulsing)
		DisableClipping(true)
		local tw, th = draw.SimpleText("?", "jcms_medium", -13, h/2, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		local height = th/2+2
		jcms.hud_DrawStripedRect(-14, 0, 2, h/2-height, 32, CurTime()*16)
		jcms.hud_DrawStripedRect(-14, h/2+height, 2, h/2-height, 32, CurTime()*16)
		DisableClipping(false)
	end

	function jcms.paint_Button(p, w, h)
		local pad = math.min(w/4, 8)
		local clr = (p:IsEnabled() and p:IsHovered()) and jcms.color_bright_alt or jcms.color_bright
		
		surface.SetDrawColor(clr)
		drawHollowPolyButton(0, 0, w, h, pad)
		
		draw.SimpleText(p:GetText(), p.jFont or "jcms_small", w/2 - 1, h/2 - 1, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		
		return true
	end
	
	function jcms.paint_ButtonFilled(p, w, h)
		local pad = math.min(w/4, 8)
		local cond = p:IsEnabled() and p:IsHovered()
		local clr = cond and jcms.color_bright_alt or jcms.color_bright
		local clr_dark = cond and jcms.color_dark_alt or jcms.color_dark
		local faded = not p:IsEnabled()

		if faded then surface.SetAlphaMultiplier(0.333) end
		surface.SetDrawColor(clr)
		drawFilledPolyButton(0, 0, w, h, pad)
		if faded then surface.SetAlphaMultiplier(1) end
		
		draw.SimpleText(p:GetText(), p.jFont or "jcms_small_bolder", w/2 - 1, h/2 - 1, clr_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		
		return true
	end

	function jcms.paint_ButtonSmall(p, w, h)
		local clr = p:IsHovered() and jcms.color_bright_alt or jcms.color_bright
		surface.SetDrawColor(clr.r, clr.g, clr.b, 72)
		jcms.hud_DrawNoiseRect(0, 0, w, h)
		draw.SimpleText(p:GetText(), p.jFont or "jcms_small_bolder", w/2 - 1, h/2 - 1, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return true
	end

	function jcms.paint_ImageButton(p, w, h)
		local clr = p:IsHovered() and jcms.color_bright_alt or jcms.color_bright
		local clr_dark = p:IsHovered() and jcms.color_dark_alt or jcms.color_dark

		surface.SetDrawColor(clr)
		if p.hollow then
			drawHollowPolyButton(0, 0, w, h, math.min(8, w/8, h/8))
			p:GetChild(0):SetImageColor(clr)
		else
			drawFilledPolyButton(0, 0, w, h, math.min(8, w/8, h/8))
			p:GetChild(0):SetImageColor(clr_dark)
		end
		return true
	end

	function jcms.paint_ClassButton(p, w, h)
		local clr = p:IsHovered() and jcms.color_bright_alt or jcms.color_bright
		local clr_dark = p:IsHovered() and jcms.color_dark_alt or jcms.color_dark

		if p.classname == LocalPlayer():GetNWString("jcms_desiredclass", "infantry") then
			surface.SetDrawColor(clr)
			drawFilledPolyButton(0, 0, w, h, 8)
			p:GetChild(0):SetImageColor(clr_dark)
		else
			p:GetChild(0):SetImageColor(clr)
		end

		return true
	end

	function jcms.paint_ButtonColor(p, w, h)
		local clr = jcms["color_" .. tostring(p.colorName)]
		local hov = p:IsHovered()

		if clr then
			local y = hov and 0 or 4
			local max = math.max(clr.r, clr.g, clr.b)
			surface.SetDrawColor(clr)
			drawFilledPolyButton(0, y, w, h - 4, 8)

			if max < 100 then
				surface.SetDrawColor(clr.r / max * 255, clr.g / max * 255, clr.b / max * 255)
				drawHollowPolyButton(0, y, w, h - 4, 8)
			end
			
			if IsValid( p:GetParent() ) and p:GetParent().selectedColor == p.colorName then
				draw.SimpleTextOutlined("#jcms.selected", "jcms_small", w/2, h/2 + y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
			end
		end

		return true
	end

	function jcms.paint_Slider(p, w, h)
		local notch = p:GetChild(0)
		local hov = p:IsHovered() or notch:IsHovered()
		local fr = p.fraction

		w = w - 4
		surface.SetDrawColor(hov and jcms.color_bright_alt or jcms.color_bright)
		drawHollowPolyButton(0, h/4, w, h/2)
		drawFilledPolyButton(2, h/4+2, (w-4)*fr, h/2-4, 6)

		if IsValid(notch) then
			notch.Paint = BLANK_DRAW
		end

		if hov then
			jcms.hud_DrawStripedRect(4, h/2-2, w-8, 4, 32, CurTime()%1*-16)
		end

		return true
	end

	function jcms.paint_NumSlider(p, w, h)
		if not p.childCache then
			p.childCache = {
				[0] = p:GetChild(0),
				[1] = p:GetChild(1),
				[2] = p:GetChild(2)
			}
		end

		p.childCache[0]:SetTextColor( jcms.color_bright )

		local ch = p.childCache[1]
		ch.fraction = math.TimeFraction(p:GetMin(), p:GetMax(), p:GetValue())
		ch.Paint = jcms.paint_Slider

		p.childCache[2]:SetTextColor( jcms.color_bright )
	end

	function jcms.paint_CheckBox(p, w, h)
		local state = p:GetChecked()
		local clr = p:IsHovered() and jcms.color_bright_alt or jcms.color_bright

		surface.SetDrawColor(clr)
		drawHollowPolyButton(0, 0, w, h, 4)
		if state then
			drawFilledPolyButton(2, 2, w-4, h-4, 3)
		end
	end

	function jcms.paint_CheckBoxLabel(p, w, h)
		local cb = p:GetChild(0)
		cb.Paint = jcms.paint_CheckBox
		local lb = p:GetChild(1)
		if not p.jText then
			p.jText = lb:GetText()
			lb:SetColor(Color(0,0,0,0))
		end
		surface.SetDrawColor(jcms.color_bright)
		draw.SimpleText(p.jText, "jcms_small_bolder", cb:GetWide() + 4, h/2, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		return true
	end
	
	local function jcms_Modal(p, w, h)
		local t = (CurTime()%1) * 16
		surface.SetDrawColor(jcms.color_dark)
		surface.DrawRect(0, 4, w, h-8)
		surface.SetDrawColor(jcms.color_bright)
		surface.DrawRect(0, 0, 1, h)
		surface.DrawRect(w-1, 0, 1, h)
		jcms.hud_DrawStripedRect(0, 0, w, 4, 32, t)
		jcms.hud_DrawStripedRect(0, h-6, w, 4, 32, t)
	end

	function jcms.paint_ModalJoinNPC(p, w, h)
		jcms_Modal(p, w, h)
		draw.SimpleText("#jcms.joinas_npc", "jcms_big", 16, 8, jcms.color_bright)
		draw.SimpleText("#jcms.modal_joinasnpc_description1", "jcms_medium", 24, 48, jcms.color_bright)
		draw.SimpleText("#jcms.modal_joinasnpc_description2", "jcms_medium", 24, 70, jcms.color_bright)
		
		local w, h = p:GetSize()
		draw.SimpleText("#jcms.modal_joinasnpc_warning", "jcms_small_bolder", w/2, 116, jcms.color_bright, TEXT_ALIGN_CENTER)

		return true
	end

	function jcms.paint_ModalReadyNoWeapons(p, w, h) -- modal that appears when you try to ready without any weapons
		jcms_Modal(p, w, h)
		draw.SimpleText([=[#jcms.modal_readynoweapons_title]=], "jcms_big", 16, 8, jcms.color_bright)
		draw.SimpleText([=[#jcms.modal_readynoweapons_description]=], "jcms_medium", 24, 48, jcms.color_bright)
		
		local w, h = p:GetSize()
		draw.SimpleText([=[#jcms.modal_readynoweapons_warning]=], "jcms_small_bolder", w/2, 116, jcms.color_bright, TEXT_ALIGN_CENTER)

		return true
	end

	function jcms.paint_ModalChangeMission(p, w, h)
		jcms_Modal(p, w, h)
		draw.SimpleText("#jcms.changemission_sp", "jcms_big", 16, 8, jcms.color_bright)

		return true
	end

	function jcms.paint_ModalChangeClass(p, w, h)
		jcms_Modal(p, w, h)
		draw.SimpleText("#jcms.changeclass", "jcms_big", 16, 8, jcms.color_bright)

		return true
	end

	function jcms.paint_ModalChangeLoadout(p, w, h)
		Derma_DrawBackgroundBlur(p, SysTime() - 1)
		jcms_Modal(p, w, h)
		draw.SimpleText("#jcms.editloadout", "jcms_big", w/2, 8, jcms.color_bright, TEXT_ALIGN_CENTER)

		return true
	end

	function jcms.paint_ModalGameBranch(p, w, h)
		local hasNMNavAddon = p.hasNMNavAddon
		Derma_DrawBackgroundBlur(p, 0)
		jcms_Modal(p, w, h)

		local str1 = "#jcms.antilag_title"
		local str2 = "#jcms.antilag_desc"
		local str3 = "#jcms.antilag_64bit"
		local str4 = "#jcms.antilag_mcore"
		local str5 = "#jcms.antilag_nmnav"
		draw.SimpleText(str1, "jcms_big", 16, 8, jcms.color_bright)
		draw.SimpleText(str2, "jcms_small_bolder", 16, 48, jcms.color_bright)

		if not p.mcorecvar then p.mcorecvar = GetConVar("gmod_mcore_test") end
		local cvar = p.mcorecvar

		if cvar:GetBool() then
			local col = jcms.color_pulsing
			surface.SetDrawColor(col)
			drawHollowPolyButton(24, 84-9, 18, 18, 4)
			drawFilledPolyButton(24+2, 84-9+2, 18-4, 18-4, 3)
			local tw = draw.SimpleText(str4, "jcms_small_bolder", 48, 84, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			surface.DrawRect(48-2, 84, tw+4, 1)
		else
			local col = CurTime()%1.5<0.5 and jcms.color_alert or jcms.color_bright
			surface.SetDrawColor(col)
			drawHollowPolyButton(24, 84-9, 18, 18, 4)
			draw.SimpleText(str4, "jcms_small_bolder", 48, 84, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		--if BRANCH == "x86-64" then
		if jit.arch == "x86" then
			local col = jcms.color_pulsing
			surface.SetDrawColor(col)
			drawHollowPolyButton(24, 84-9+28, 18, 18, 4)
			drawFilledPolyButton(24+2, 84-9+2+28, 18-4, 18-4, 3)
			local tw = draw.SimpleText(str3, "jcms_small_bolder", 48, 84+28, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			surface.DrawRect(48-2, 84+28, tw+4, 1)
		else
			local col = CurTime()%1.5<0.5 and jcms.color_alert or jcms.color_bright
			surface.SetDrawColor(col)
			drawHollowPolyButton(24, 84-9+28, 18, 18, 4)
			draw.SimpleText(str3, "jcms_small_bolder", 48, 84+28, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		
		if hasNMNavAddon then
			local col = CurTime()%1.5<0.5 and jcms.color_alert or jcms.color_bright
			surface.SetDrawColor(col)
			drawHollowPolyButton(24, 84-9+28*2, 18, 18, 4)
			draw.SimpleText(str5, "jcms_small_bolder", 48, 84+28*2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		return true
	end

	function jcms.paint_Modal64BitInstruction(p, w, h)
		local imgw, imgh = 1286, 318
		local scale = math.min(1, (w*0.8)/imgw, (h*0.9)/imgh)

		Derma_DrawBackgroundBlur(p, 0)
		if p.img then
			surface.SetMaterial(p.img)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRectRotated(w/2, h/2, 1286*scale, 318*scale, 0)
		end

		if IsValid(p.close) then
			p.close:SetPos(w/2-p.close:GetWide()/2, h/2+318*scale/2+64)
		end
	end

	function jcms.paint_Separator(p, w, h)
		local parent = p.parentPanel
		local clr = jcms.color_bright
		local clrFaded = ColorAlpha(clr, 50)
		
		local tw = draw.SimpleText(p.jText, "jcms_medium", w/2, h/2, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(clrFaded)
		jcms.hud_DrawStripedRect(0, 8, w/2 - tw - 4, h-16, 32)
		jcms.hud_DrawStripedRect(w/2 + tw + 8, 8, w/2 - tw - 4, h-16, 32)
	end

	function jcms.paint_PlayerLobby(p, w, h)
		local lowres = p.lowres
		local ply = p.player
		if IsValid(ply) then
			local ready = ply:GetNWBool("jcms_ready")
			p.readyAnim = math.Approach(p.readyAnim or 0, ready and 1 or 0, FrameTime()*4)
			if p.readyAnim > 0 then
				surface.SetAlphaMultiplier(0.5 * (math.ease.OutBack(p.readyAnim)^3))
				surface.SetDrawColor(jcms.color_bright)
				jcms.hud_DrawNoiseRect(0, 8, w, h-8, 32)
				surface.SetAlphaMultiplier(1)
				draw.SimpleText("#jcms.ready", "jcms_small_bolder", w - 16 + 100*math.ease.InQuart(1-p.readyAnim), h/2 + 2, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end

			if p.readyAnim > 0.12 then
				if not p.didSound then
					surface.PlaySound("npc/dog/dog_idle2.wav")
					p.didSound = true
				end
			else
				if p.didSound then
					surface.PlaySound("npc/dog/dog_idle4.wav")
					p.didSound = false
				end
			end

			surface.SetDrawColor(jcms.color_bright)
			drawHollowPolyButton(0, 8, w, h-8)

			local av = p:GetChild(0)
			jcms.hud_DrawStripedRect(av:GetX()-1, av:GetY()-1, av:GetWide()+2, av:GetTall()+2, av:GetTall(), (CurTime()%1)*16)
			surface.DrawRect(av:GetX(), av:GetY() + av:GetTall() + 2, av:GetWide(), 1)

			local baseX = av:GetX() + av:GetWide() + 4
			local baseY = 8

			if ply == LocalPlayer() then
				drawFilledPolyButton(0, 8, 8, h-8)
			end
			
			local pvpTeam = ply:GetNWInt("jcms_pvpTeam", -1)
			local sameTeamAsMe = pvpTeam == jcms.locPly:GetNWInt("jcms_pvpTeam", -1)
			local iconSize = lowres and 16 or 32
			local xOffset = pvpTeam > 0 and iconSize or 0

			local _, nameheight = draw.SimpleText(ply:Nick(), "jcms_small_bolder", baseX + iconSize + xOffset + 10, baseY + (lowres and 0 or 4), jcms.color_bright)
			local specialText = jcms.hud_GetSpecialText(ply)
			if specialText then
				local str = "#jcms.specialtext_" .. specialText

				local color = jcms.color_pulsing
				if specialText == "creator" then
					color = jcms.color_bright_alt
				elseif specialText == "supporter" then
					color = jcms.color_bright
				end

				draw.SimpleText(str, lowres and "DefaultVerySmall" or "DefaultSmall", baseX + xOffset + iconSize + 8, baseY + nameheight + (lowres and -4 or 2), color)
			end

			local desiredclass = ply:GetNWString("jcms_desiredclass", "")
			local genuinely = true

			if desiredclass == "" then
				desiredclass = "infantry"
				genuinely = false
			end

			DisableClipping( true )
			local icons = {}
			if jcms.leaderboard_data_pve and jcms.leaderboard_data_pve[1] and jcms.leaderboard_data_pve[1].sid64 == ply:SteamID64() then
				table.insert(icons, jcms.mat_leader_pve)
			end
			if jcms.leaderboard_data_pvp and jcms.leaderboard_data_pvp[1] and jcms.leaderboard_data_pvp[1].sid64 == ply:SteamID64() then
				table.insert(icons, jcms.mat_leader_pvp)
			end

			for i, mat in ipairs(icons) do
				surface.SetMaterial(mat)
				surface.DrawTexturedRect(baseX + iconSize - 84 - i*36, baseY + 4, iconSize, iconSize)
			end
			DisableClipping( false )
			
			surface.SetAlphaMultiplier(genuinely and 1 or 0.25)
			surface.SetDrawColor(jcms.color_bright)
			if pvpTeam > 0 then
				if sameTeamAsMe then
					surface.SetMaterial(jcms.mat_GetClassMat(desiredclass))
					surface.DrawTexturedRect(baseX + iconSize + 4, baseY + 4, iconSize, iconSize)
				else
					draw.SimpleText("?", "jcms_hud_small", baseX + iconSize*1.7, baseY + iconSize*0.6, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end

				surface.SetAlphaMultiplier(1)
				surface.SetDrawColor( jcms.hud_GetPVPTeamColor(pvpTeam) )
				surface.SetMaterial( jcms.hud_GetPVPTeamMat(pvpTeam) )
				surface.DrawTexturedRect(baseX + 4, baseY + 4, iconSize, iconSize)
			else
				surface.SetMaterial(jcms.mat_GetClassMat(desiredclass))
				surface.DrawTexturedRect(baseX + 4, baseY + 4, iconSize, iconSize)
				surface.SetAlphaMultiplier(1)
			end

			local col = Color( jcms.color_bright:Unpack() )
			col.r = (col.r + 255)/2
			col.g = (col.g + 255)/2
			col.b = (col.b + 255)/2

			if sameTeamAsMe then
				local index = 0
				local weaponListX = w*0.4

				local mx, my = p:LocalCursorPos()
				local selectionIndex = (my >= 0 and my <= h) and math.floor( (mx - baseX - weaponListX) / (iconSize+2) ) or -1
				local selectionWeapon = nil

				local weps = ply:GetWeapons()
				for _, weapon in ipairs(weps) do
					local class = weapon:GetClass()
					if class == "weapon_stunstick" then continue end

					local size = iconSize
					local sizePad = size + 2
					
					if selectionIndex ~= index then
						local gunmat = jcms.gunstats_GetMat(class)
						surface.SetDrawColor(jcms.color_pulsing)
						jcms.hud_DrawNoiseRect(baseX + weaponListX + index*sizePad, size - 22, size - 4, 24)

						surface.SetDrawColor(jcms.color_bright)
						surface.DrawRect(baseX + weaponListX + index*sizePad, size + 8, size - 4, 1)
						if not gunmat:IsError() then
							surface.SetMaterial(jcms.gunstats_GetMat(class))
							surface.DrawTexturedRectRotated(baseX + weaponListX + index*sizePad + 4 + size/2, size/2 + 4, size, size, 0)
							surface.SetDrawColor(col)
							surface.DrawTexturedRectRotated(baseX + weaponListX + index*sizePad + size/2, size/2, size, size, 0)
						else
							surface.SetDrawColor(jcms.color_bright)
							surface.DrawOutlinedRect(baseX + weaponListX + index*sizePad, 0, size, size)
						end
					else
						selectionWeapon = weapon
					end

					index = index + 1

					if (baseX + weaponListX + index*sizePad) > w-iconSize*2 and weps[_+1] then
						draw.SimpleTextOutlined("+", lowres and "jcms_medium" or "jcms_hud_small", w - iconSize - (lowres and 8 or 0), h/2, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, jcms.color_dark)
						break
					end
				end

				if IsValid(selectionWeapon) then
					local class = selectionWeapon:GetClass()
					local gunmat = jcms.gunstats_GetMat(class)

					local sizePad = iconSize + 2
					local size = iconSize*1.5
					if not gunmat:IsError() then
						surface.SetMaterial(gunmat)
						surface.SetDrawColor(jcms.color_bright)
						surface.DrawTexturedRectRotated(baseX + weaponListX + selectionIndex*sizePad + 4 + sizePad/2, size/2 + 4, size, size, 0)
						surface.SetDrawColor(color_white)
						surface.DrawTexturedRectRotated(baseX + weaponListX + selectionIndex*sizePad + sizePad/2, size/2, size, size, 0)
					else
						surface.SetDrawColor(jcms.color_bright)
						surface.DrawOutlinedRect(baseX + weaponListX + selectionIndex*sizePad + 4 + sizePad/2 - size/2, 0, size, size)
					end

					if p.gunStats then
						if not p.gunStats[ class ] then
							p.gunStats[ class ] = jcms.gunstats_Get(class)
						end

						local stats = p.gunStats[ class ]
						if stats then
							draw.SimpleTextOutlined(stats.name, "jcms_small", baseX + weaponListX + selectionIndex*sizePad + sizePad/2, 1, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, jcms.color_dark)
						end
					end
				end
			end
		else
			p.rmFraction = math.min( (p.rmFraction or 0) + FrameTime()*3, 1 )
			if p.rmFraction >= 1 then
				p:Remove()
			else
				local f1 = math.ease.InSine(1-p.rmFraction)
				local f2 = math.ease.InOutQuart(1-p.rmFraction)
				local size = 32 * f2

				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				local old = surface.GetAlphaMultiplier()
				surface.SetAlphaMultiplier(f1)
				surface.SetDrawColor(jcms.color_bright)
				jcms.hud_DrawNoiseRect(0, h/2*(1-f1), w, h*f1)
				surface.DrawOutlinedRect(12+16-size/2, h-16-size/2-8, size, size, 1)
				surface.SetAlphaMultiplier(f2)
				surface.SetDrawColor(jcms.color_bright)
				jcms.hud_DrawNoiseRect(0, h/2*(1-f2), w, h*f2)
				jcms.hud_DrawNoiseRect(12+16-size/2, h-16-size/2-8, size, size)
				drawHollowPolyButton(0, 8+(h-8)/2*(1-f2), w, (h-8)*f2)
				surface.SetAlphaMultiplier(old)
				render.OverrideBlend( false )
			end
		end
	end

	function jcms.paint_PlayerLobbyNPC(p, w, h)
		local ply = p.player
		if IsValid(ply) then
			local ready = ply:GetNWBool("jcms_ready")
			p.readyAnim = math.Approach(p.readyAnim or 0, ready and 1 or 0, FrameTime()*8)
			if p.readyAnim > 0 then
				surface.SetAlphaMultiplier(0.5 * (math.ease.OutBack(p.readyAnim)^3))
				surface.SetDrawColor(jcms.color_bright)
				jcms.hud_DrawNoiseRect(0, 1, w-32, h-2, 32)
				surface.SetAlphaMultiplier(1)
				draw.SimpleText("#jcms.ready", "jcms_small", w - 48 + 100*math.ease.InQuart(1-p.readyAnim), h/2-1, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end

			surface.SetDrawColor(jcms.color_bright)
			drawHollowPolyButton(1, 1, w-32, h-2)
			
			if ply == LocalPlayer() then
				drawFilledPolyButton(1, 1, 8, h-2)
			end

			draw.SimpleText(ply:Nick(), "jcms_small_bolder", 38, h/2, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else
			p.rmFraction = math.min( (p.rmFraction or 0) + FrameTime()*3, 1 )
			if p.rmFraction >= 1 then
				p:Remove()
			else
				w = w - 32
				local f1 = math.ease.InSine(1-p.rmFraction)
				local f2 = math.ease.InOutQuart(1-p.rmFraction)
				local size = 16 * f2

				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				local old = surface.GetAlphaMultiplier()
				surface.SetAlphaMultiplier(f1)
				surface.SetDrawColor(jcms.color_bright)
				jcms.hud_DrawNoiseRect(0, h/2*(1-f1), w, h*f1)
				surface.DrawOutlinedRect(16+8-size/2, h-4-size/2-8, size, size, 1)
				surface.SetAlphaMultiplier(f2)
				surface.SetDrawColor(jcms.color_bright)
				jcms.hud_DrawNoiseRect(0, h/2*(1-f2), w, h*f2)
				jcms.hud_DrawNoiseRect(16+8-size/2, h-4-size/2-8, size, size)
				drawHollowPolyButton(0, 8+(h-8)/2*(1-f2), w, (h-8)*f2)
				surface.SetAlphaMultiplier(old)
				render.OverrideBlend( false )
			end
		end
	end
	
	function jcms.paint_Category(p, w, h)
		local hov = p:IsChildHovered()
		local hh = p:GetHeaderHeight()
		local dontSubtractHeight = p.dontSubtractHeight
		local clr = jcms.color_bright
		local clr_dark = jcms.color_dark
		
		if hov then
			surface.SetAlphaMultiplier(0.02)
				surface.SetDrawColor(clr)
				drawFilledPolyButton(0, 0, w, dontSubtractHeight and h or (h - 26), 8)
			surface.SetAlphaMultiplier(1)
			surface.SetDrawColor(clr)
			drawFilledPolyButton(0, 0, w, hh, 8)
		else
			surface.SetDrawColor(clr)
			drawHollowPolyButton(0, 0, w, hh, 8)
		end

		local header = p:GetChild(0)
		if IsValid(header) then
			local text = header:GetText()
			if text ~= "" then
				p.jCat = text
				header:SetText("")
			end
		end
		
		surface.SetDrawColor(clr.r, clr.g, clr.b, 50)
		surface.DrawRect(w-1, hh - (dontSubtractHeight and 0 or 26) - 8, 1, h - hh)
		draw.SimpleText(p.jCat, "Trebuchet18", hh, hh/2, hov and clr_dark or clr, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		return true
	end
	
	function jcms.paint_Gun(p, w, h)
		local canAfford = not p.cantAfford
		
		if not p.createdAt then
			p.createdAt = CurTime()
		end

		local gunMat = jcms.gunstats_GetMat(p.gunClass)
		if gunMat and gunMat:IsError() then
			p.matBad = true
		else
			p.mat = gunMat
		end
		
		local clr = (p.owned and p.owned>0) and jcms.color_bright_alt or jcms.color_bright
		
		if p.mat and not p.matBad then
			surface.SetDrawColor(clr)
			
			local cx, cy = p:LocalCursorPos()
			if not p:IsHovered() then
				cx, cy = w/2, h/2
				p.colorf = ((p.colorf or 0)*4 + 0.5)/5
			else
				p.colorf = ((p.colorf or 0)*4 + 1)/5
			end
			
			p.xoff = ((p.xoff or 0.5)*8 + cx/w)/9
			p.yoff = ((p.yoff or 1)*8 + cy/h)/9
			
			local xoff, yoff = p.xoff-0.5, p.yoff-0.5
			local cf = p.colorf
			
			surface.SetMaterial(p.mat)
			local size = math.max(w*1.4, h*1.4)
			surface.DrawTexturedRectRotated(w/2-2 + xoff*w/4, h/2-2 + yoff*h/4, size, size, 0)
			surface.SetDrawColor(Lerp(cf, clr.r, 255), Lerp(cf, clr.g, 255), Lerp(cf, clr.b, 255))
			surface.DrawTexturedRectRotated(w/2 + xoff*w/3, h/2 + yoff*h/3, size, size, 0)
			
			if not canAfford then
				surface.SetAlphaMultiplier(0.9)
				surface.SetDrawColor(jcms.color_dark)
				drawFilledPolyButton(0, 0, w, h, 4)
				surface.SetAlphaMultiplier(1)
			end
			
			if p.colorf>0.501 then
				surface.SetFont("Default")
				local name = p.gunStats.name
				local tw, th = surface.GetTextSize(name)
				
				surface.SetAlphaMultiplier(p.colorf*2-1)
				if tw > w*0.9 then
					local offset = (CurTime()/4)%1
					local woff = tw + 16
					draw.SimpleTextOutlined(name, "Default", w/2-woff*offset, 4, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, jcms.color_dark)
					draw.SimpleTextOutlined(name, "Default", w/2-woff*(offset-1), 4, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, jcms.color_dark)
				else
					draw.SimpleTextOutlined(name, "Default", w/2, 4, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, jcms.color_dark)
				end
				surface.SetAlphaMultiplier(1)
			end
		else
			draw.SimpleText(p.gunStats.name, "Default", w/2, h/2, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		
		local cost = tonumber(p.cost) or 0
		if p.gunSale then
			if not p.count and p.colorf and p.colorf>0.501 then
				surface.SetAlphaMultiplier( (p.colorf-0.5)*2 )
				surface.SetDrawColor(40, 170, 32)
				drawFilledPolyButton(0, h-12, w/2.5, 12, 4)
				draw.SimpleText(-math.Round( (1-p.gunSale)*100).."%", "HudHintTextSmall", w/2.5/2, h-6, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				surface.SetAlphaMultiplier(1)
			end
		end
		
		surface.SetDrawColor(clr)
		
		if cost > 0 then
			if canAfford then
				drawFilledPolyButton(w/2, h-16, w/2, 16, 4)
			else
				drawHollowPolyButton(w/2, h-16, w/2, 16, 4)
			end
		end
		
		if p.count and p.count > 1 then
			draw.SimpleTextOutlined("+"..(p.count-1), "jcms_medium", 4, h-4, clr, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, jcms.color_dark)
		elseif p.owned and p.owned > 0 then
			draw.SimpleTextOutlined("x"..p.owned, "jcms_medium", w-4, h-(cost>0 and 16 or 4), clr, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, jcms.color_dark)
		end
		
		surface.SetDrawColor(clr.r, clr.g, clr.b, (p.owned and p.owned>0) and 255 or (canAfford and 150 or 25))
		drawHollowPolyButton(0, 0, w, h, 4)
		
		if cost > 0 then
			draw.SimpleText(jcms.util_CashFormat(cost), "Default", w*3/4, h-8, canAfford and jcms.color_dark or clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		if jcms.weapon_favourites[ p.gunClass ] then
			draw.SimpleTextOutlined("*", "jcms_medium", 3, -1, jcms.color_alert, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, jcms.color_dark)
		end

		return true
	end

	function jcms.paint_ScrollGrip(p, w, h)
		surface.SetAlphaMultiplier(p.visibilityAnim or 1)
		local col, colAlt = p.colorMain or jcms.color_bright, p.colorHover or jcms.color_bright_alt
		surface.SetDrawColor(p:IsHovered() and colAlt or col)
		drawFilledPolyButton(w/2-2, 0, 4, h, 2)
		surface.SetAlphaMultiplier(1)
	end
	
	function jcms.paint_ComboBox(p, w, h)
		local text = p.jText
		local fr = p.jFraction or 0.5
		surface.SetDrawColor(p:IsHovered() and jcms.color_bright_alt or jcms.color_bright)
		draw.SimpleText(text, "jcms_small", 8, h/2, surface.GetDrawColor(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		drawHollowPolyButton(w*fr,1,w*(1-fr),h-2, 4)
		draw.SimpleText(p:GetValue(), "jcms_small", w*fr + h/2, h/2, surface.GetDrawColor(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local menu = p:GetChild(1)
		if IsValid(menu) then
			menu:SetPaintBackground(false)
			for i,c in ipairs(menu.pnlCanvas:GetChildren()) do
				c.Paint = p.PaintButtons or jcms.paint_ComboBoxButton
				c.PaintOver = BLANK_DRAW
				c.jFraction = fr
				c.jMissionType = p:GetOptionData(i)
			end
		end

		return true
	end
	
	function jcms.paint_ComboBoxButton(p, w, h)
		local fr = p.jFraction or 0.5
		surface.SetDrawColor(p:IsHovered() and jcms.color_bright_alt or jcms.color_bright)
		drawFilledPolyButton(w*fr,1,w*(1-fr),h-1, 4)
		draw.SimpleText(p:GetText(), "jcms_small_bolder", (w*fr + w)/2, h/2, p:IsHovered() and jcms.color_dark_alt or jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return true
	end

	function jcms.paint_ComboBoxButtonMission(p, w, h)
		local fr = p.jFraction or 0.5
		local menu = p:GetMenu()

		if not menu.factionMats then
			menu.factionMats = {}
		end

		local faction = "any"
		local missionData = jcms.missions[ p.jMissionType ]
		if missionData then
			faction = missionData.faction or "any" 
		end
		
		if not menu.factionMats[ faction ] then
			menu.factionMats[ faction ] = Material("jcms/factions/" .. faction .. ".png")
		end

		surface.SetDrawColor(p:IsHovered() and jcms.color_bright_alt or jcms.color_bright)
		drawFilledPolyButton(w*fr,1,w*(1-fr),h-1, 4)
		surface.SetDrawColor(p:IsHovered() and jcms.color_dark_alt or jcms.color_dark)
		surface.SetMaterial(menu.factionMats[ faction ])
		surface.DrawTexturedRectRotated(w*fr + h/2, h/2, 16, 16, 0)
		draw.SimpleText(p:GetText(), "jcms_small_bolder", w*fr + h/2 + 16, h/2, p:IsHovered() and jcms.color_dark_alt or jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		return true
	end
	
	function jcms.paint_SortCheckBox(p, w, h)
		local reverse = p:GetChecked()
		surface.SetDrawColor(p:IsHovered() and jcms.color_bright_alt or jcms.color_bright)
		drawFilledPolyButton(0, 0, w, h, 4)
		surface.SetDrawColor(p:IsHovered() and jcms.color_dark_alt or jcms.color_dark)
		local bar1, bar2, bar3 = w*0.7, w*0.5, w*0.3
		local barh = h*0.15
		if reverse then
			drawFilledPolyButton(w/2-bar1/2, h/2-barh*2, bar1, barh, 1)
			drawFilledPolyButton(w/2-bar2/2, h/2-barh/2, bar2, barh, 1)
			drawFilledPolyButton(w/2-bar3/2, h/2+barh, bar3, barh, 1)
		else
			drawFilledPolyButton(w/2-bar1/2, h/2+barh, bar1, barh, 1)
			drawFilledPolyButton(w/2-bar2/2, h/2-barh/2, bar2, barh, 1)
			drawFilledPolyButton(w/2-bar3/2, h/2-barh*2, bar3, barh, 1)
		end
	end

	function jcms.paint_OnlinePlayers(p, w, h)
		if not p.avatars then
			p.avatars = {}
		end

		for ply, av in pairs(p.avatars) do
			if not IsValid(ply) then
				av:Remove()
				p.avatars[ply] = nil
			end
		end

		for i, ply in ipairs( player.GetAll() ) do
			if not p.avatars[ ply ] then
				local av = vgui.Create("AvatarImage", p)
				av:SetSize(16, 16)
				av:SetPlayer(ply, 16)
				p.avatars[ ply ] = av
			end

			p.avatars[ ply ]:SetPos( w-i*18, h-16)
		end
	end

	function jcms.paint_MapButton(p, w, h)
		local lowres = p.lowres
		p.hovAnim = ((p.hovAnim or 0) * 6 + (p:IsHovered() and 1 or 0)) / 7
		local anim = p.hovAnim
		local oldState = DisableClipping(true)

		local x, y = p:LocalCursorPos()
		x = x - w/2
		y = y - h/2
		x = x * anim * 0.04
		y = y * anim * 0.04

		local col = p.colorMain or jcms.color_bright
		local colPulsing = ColorAlpha(col, jcms.color_pulsing.a)
		surface.SetDrawColor(colPulsing)
		drawHollowPolyButton(x, y, w, h)

		local winning = p.winning
		if winning then
			surface.SetDrawColor(jcms.color_alert)
		else
			surface.SetDrawColor( jcms.util_ColorLerp(anim, colPulsing, col, true) )
		end
		drawFilledPolyButton(x, y, 16, h, 8)

		local mapname = p.mapname
		if mapname then
			local exists = p.exists
			local mat = (p.mat and not p.mat:IsError()) and p.mat or nil
			local size = math.min(w - 8, h - 8)

			local mapnameFont = size > 72 and "jcms_medium" or "jcms_small_bolder"
			surface.SetFont(mapnameFont)
			local tw = surface.GetTextSize(mapname)

			if tw > (w - 16 - h) then
				mapnameFont = size > 72 and "jcms_small_bolder" or "DefaultVerySmall"
			end
			
			local _, th = draw.SimpleText(mapname, mapnameFont, x + w - 16, y + 8, col, TEXT_ALIGN_RIGHT)
			if mat then
				surface.SetMaterial(mat)
				surface.SetDrawColor( jcms.util_ColorLerp(anim, col, color_white, true) )
				surface.DrawTexturedRect(x + 19, y + 4, size, size)
			else
				local colLerped = jcms.util_ColorLerp(anim, col, color_white, true)
				surface.SetDrawColor( colLerped )
				surface.DrawOutlinedRect(x + 19, y + 4, size, size)
				draw.SimpleText("?", size > 72 and "jcms_hud_big" or (size > 48 and "jcms_hud_medium" or "jcms_hud_small"), x + 19 + size/2, y + 4 + size/2, colLerped, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			if not exists then
				draw.SimpleText("#jcms.mapmissing", size > 72 and "jcms_small" or "DefaultVerySmall", x+ w - 16, y + 12 + th , col, TEXT_ALIGN_RIGHT)
			end

			if jcms.aftergame.vote then
				if not p.avatars then
					p.avatars = {}
				end

				local checkedAvatars = {}
				for ply, vote in pairs(jcms.aftergame.vote.votes) do
					if (vote == mapname) and IsValid(ply) then
						checkedAvatars[ply] = true
					end
				end

				for ply, av in pairs(p.avatars) do
					if not checkedAvatars[ply] then
						av:Remove()
						p.avatars[ply] = nil
					end
				end

				local avatarSize = lowres and 16 or 32
				local avatarSizePad = avatarSize + 2
				local i = 0
				local iForSubtraction = 0
				local levelsOfSubtraction = 0
				for ply in pairs(checkedAvatars) do
					i = i + 1
					if not p.avatars[ply] then
						local av = p:Add("AvatarImage")
						av:SetPlayer(ply, avatarSize)
						av:SetSize(avatarSize, avatarSize)
						p.avatars[ply] = av
					end

					local avx, avy = x + p:GetWide() - (i - iForSubtraction)*avatarSizePad - 12, y + p:GetTall() - avatarSizePad*(levelsOfSubtraction+1) - 12
					if avx < size + 24 then
						iForSubtraction = i - 1
						levelsOfSubtraction = levelsOfSubtraction + 1
						avx, avy = x + p:GetWide() - (i - iForSubtraction)*avatarSizePad - 12, y + p:GetTall() - avatarSizePad*(levelsOfSubtraction+1) - 12
					end
					p.avatars[ply]:SetPos(avx, avy)
				end
			end
		end

		DisableClipping(oldState)
		return true
	end

-- // }}}

-- // Offgame panels {{{

	local function drawScanlines(w,h, r,g,b,a)
		a = a or 3

		local sl_y = CurTime()*64%h
		for i=1,32 do
			surface.SetDrawColor(r, g, b, i%2==0 and a or a*0.66)
			surface.DrawRect(0, (sl_y+i*3)%h, w, 1)
		end
		
		sl_y = CurTime()*100%h
		for i=1,16 do
			surface.SetDrawColor(r, g, b, i%2==0 and a or a*0.66)
			surface.DrawRect(0, (sl_y+i*3)%h, w, 1)
		end
	end

	-- Lobby {{{
		function jcms.offgame_paint_LobbyFrame(p, w, h)
			local lowres = jcms.util_IsLowRes()

			jcms.statistics.mylevel_premission = jcms.statistics.mylevel
			jcms.statistics.myexp_premission = jcms.statistics.myexp

			local r,g,b = jcms.color_dark:Unpack()
			local r2,g2,b2 = jcms.color_bright:Unpack()
			local color_faded = ColorAlpha(jcms.color_bright, 100)
			
			local bx = 32
			local bw = lowres and 120 or 180
			local bh = 32

			surface.SetDrawColor(r2, g2, b2)
			surface.DrawRect(0, bh + 2, w, 1)
			surface.SetDrawColor(r2, g2, b2, 20)
			jcms.hud_DrawNoiseRect(0, bh + 3, w, h, h+w)

			for i, btn in ipairs(p.buttonsPrimary) do
				local selected = i == p.buttonsPrimary.selection
				btn:SetSize(bw, selected and (bh + 8) or (bh - 4))
				btn:SetPos(bx, 2)
				btn.jFont = lowres and "jcms_small_bolder" or "jcms_medium"
				btn.Paint = selected and jcms.paint_ButtonFilled or jcms.paint_Button

				if not selected then
					surface.SetDrawColor(color_faded)
					jcms.hud_DrawStripedRect(bx, bh + 6, bw, 4, 32)
				end

				bx = bx + bw + 4
			end

			bx = bx + 32
			bw = 100

			local shouldClarify = game.IsDedicated()
			local clarifyPos = bx + bw
			for i, btn in ipairs(p.buttonsSecondary) do
				local doClarify = btn.isVanilla and shouldClarify
				btn:SetSize(bw, (doClarify and -14 or 0) + bh + 2)
				btn:SetPos(bx, doClarify and 14 or 0)
				btn.jFont = "jcms_small_bolder"
				bx = bx + bw + 4
			end
			
			if shouldClarify then
				draw.SimpleText(language.GetPhrase("#jcms.for") .. " Octantis Addons:", "jcms_small", clarifyPos, 0, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end

			if game.SinglePlayer() then
				draw.SimpleText( game.GetMap(), "jcms_small_bolder", w - bh/2, bh/2, jcms.color_pulsing, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
			else
				draw.SimpleText( ("%d / %d @ %s"):format( player.GetCount(), game.MaxPlayers(), game.GetMap() ), "jcms_small_bolder", w - 4, 0, jcms.color_pulsing, TEXT_ALIGN_RIGHT )
				p.onlinePlayers:SetSize(200, bh)
				p.onlinePlayers:SetPos(w-p.onlinePlayers:GetWide(), 0)
			end

			-- Game summary {{{
				local missionType = jcms.util_GetMissionType()
				local missionData = jcms.missions[ missionType ]
				local missionNameX = w - 32 - 600
				
				local isPVP = jcms.util_IsPVP()
				local winstreak = jcms.util_GetCurrentWinstreak()
				local difficulty = jcms.util_GetCurrentDifficulty()

				if (missionType ~= "") then
					local name = (isPVP and "PVP " or "") .. language.GetPhrase("#jcms." .. (missionData and missionData.basename or missionType))
					local desc = language.GetPhrase("#jcms." .. (missionData and missionData.basename or missionType).."_desc")
					
					local smallscreen = ScrW() <= 1500
					local font = smallscreen and "jcms_hud_small" or "jcms_hud_medium"
					surface.SetFont(font)
					local tw, th = surface.GetTextSize(name)
					tw = math.max(tw, 210)
					local xpad = 48
					local ypad = 8
					
					local mup = markup.Parse( ("<color=%d,%d,%d><font="..(lowres and "jcms_small" or "jcms_small")..">\"" .. desc .. "\"</font></color>"):format(jcms.color_bright:Unpack()), math.max(lowres and 300 or 520, tw + 48))
					mup:Draw(w - 48, 100 + ypad + th + 36, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 100, TEXT_ALIGN_RIGHT)
					
					surface.SetDrawColor(jcms.color_pulsing)
					jcms.hud_DrawNoiseRect(w-64-tw-xpad/2, 100-ypad/2, tw+xpad, th+ypad)
					surface.SetDrawColor(jcms.color_bright)
					surface.DrawRect(w-64+xpad/2, 100-ypad/2, 4, th+ypad)
					jcms.hud_DrawStripedRect(w-64-tw-xpad/2, 100+th+ypad/2+4, tw+xpad, 4, 32)
					draw.SimpleText(name, font, w - 64, 100, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

					missionNameX = w - 64 - tw - th - ypad - xpad/2
					if missionData then
						local faction = missionData.faction == "any" and jcms.util_GetMissionFaction() or missionData.faction
						local rectSize = th+ypad
						local rectX = w-64-tw-xpad/2-rectSize
						surface.DrawRect(rectX, 100-ypad/2, rectSize, rectSize)

						if (not p.factionMat) or (faction ~= p.factionMatFaction) then
							p.factionMat = Material("jcms/factions/" .. faction .. ".png")
							p.factionMatFaction = faction
						end

						if not p.factionMat:IsError() then
							local iconSize = smallscreen and 32 or 64
							surface.SetMaterial(p.factionMat)
							surface.SetDrawColor(jcms.color_dark)
							surface.DrawTexturedRect(rectX + rectSize/2 - iconSize/2, 100 + th/2 - iconSize/2, iconSize, iconSize)
						end

						draw.SimpleText("#jcms." .. faction, "jcms_small_bolder", rectX+rectSize, 100+th+ypad+6, jcms.color_pulsing)

						local hoveredTag
						local mx, my = input.GetCursorPos()
						local tagy = 100 + th + mup:GetHeight() + 56
						local tagSize = lowres and 16 or 32
						if not p.tagMats then
							p.tagMats = {}
						end

						if istable(missionData.tags) and #missionData.tags > 0 then
							for i, tag in ipairs(missionData.tags) do
								if not p.tagMats[ tag ] then
									p.tagMats[ tag ] = Material("jcms/missiontags/" .. tostring(tag) .. ".png")
								end

								local tagx = w-48-(tagSize+4)*i

								surface.SetDrawColor(jcms.mission_GetTagColor(tag))

								if not hoveredTag and  mx >= tagx and my >= tagy and mx < tagx + 32 and my < tagy + 32 then
									hoveredTag = tag
									drawHollowPolyButton(tagx-3, tagy-3, tagSize+6, tagSize+6, 6)
								end

								drawFilledPolyButton(tagx, tagy, tagSize, tagSize, 4)
								surface.SetMaterial(p.tagMats[tag])
								surface.SetDrawColor(jcms.color_dark_alt)
								surface.DrawTexturedRect(tagx, tagy, tagSize, tagSize)
							end
						end

						local isUnofficial = not jcms.missions_official[ missionType ]
						if isUnofficial then
							local tagx = w-48-(tagSize+4)*(#missionData.tags+1)
							local tag = "unofficial"

							if not p.tagMats[ tag ] then
								p.tagMats[ tag ] = Material("jcms/missiontags/" .. tostring(tag) .. ".png")
							end

							surface.SetDrawColor(jcms.color_bright_alt)

							if not hoveredTag and mx >= tagx and my >= tagy and mx < tagx + 32 and my < tagy + 32 then
								hoveredTag = tag
								surface.DrawCircle(tagx+16, tagy+16, 16)
							end
							
							surface.SetMaterial(p.tagMats[tag])
							surface.DrawTexturedRect(tagx, tagy, tagSize, tagSize)
						end

						if hoveredTag then
							tagy = tagy - 4
							local hoveredTagName = language.GetPhrase("jcms.missiontag_"..hoveredTag)
							local hoveredTagDesc = language.GetPhrase("jcms.missiontag_"..hoveredTag.."_desc")

							local lastTagX = w-48-(tagSize+2)*(#missionData.tags + (isUnofficial and 1 or 0))-32
							local font = lowres and "jcms_small_bolder" or "jcms_medium"
							surface.SetFont(font)
							local tw2, th2 = surface.GetTextSize(hoveredTagName)
							tw2 = tw2 + 32

							local col = jcms.mission_GetTagColor(hoveredTag)
							surface.SetDrawColor(col)
							jcms.hud_DrawNoiseRect(lastTagX-tw2,tagy,tw2,th2)
							surface.DrawRect(lastTagX, tagy, 2, th2)
							surface.DrawRect(lastTagX-tw2-2, tagy, 2, th2)
							draw.SimpleText(hoveredTagName, font, lastTagX-tw2/2, tagy+th2/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
							draw.SimpleText(hoveredTagDesc, lowres and "DefaultSmall" or "jcms_small", lastTagX, tagy+th2+4, ColorAlpha(col, 100), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
						end

						if jcms.util_GetMapGenProgress() <= 0 then
							local showWarningText = difficulty >= 1.6
							local textY = showWarningText and 82 or 92

							if winstreak > 0 then
								local winstreakText = ("%s: x%d"):format(language.GetPhrase("jcms.winstreak"), winstreak)
								local winstreakColour = jcms.color_bright_alt
								if showWarningText then
									winstreakColour = jcms.color_alert
								end

								shakemag = math.max(0, difficulty - 1)^0.5
								if shakemag >= 1.5 then
									shakemag = (shakemag - 1.5)*0.25 + 1.5
								end

								for i=1, math.floor(math.Clamp(difficulty, 1, 10)) do
									local shX = math.Round( math.Rand(-1, 1)*shakemag )
									local shY = math.Round( math.Rand(-1, 1)*shakemag )
									surface.SetAlphaMultiplier( (1/i)^2 )
									draw.SimpleText(winstreakText, "jcms_small_bolder", missionNameX + 4 + shX, textY + shY, winstreakColour, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
								end
								surface.SetAlphaMultiplier(1)
							end

							if showWarningText then
								surface.SetAlphaMultiplier(0.5)
								local fullWidth = w-xpad - missionNameX
								local warningtw = draw.SimpleText(difficulty >= 3 and "#jcms.extremedifficulty" or "#jcms.highdifficulty", "jcms_small_bolder", missionNameX + fullWidth/2, 92, jcms.color_alert, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
								surface.SetDrawColor(jcms.color_alert)
								jcms.hud_DrawStripedRect(missionNameX, 83, fullWidth/2 - warningtw/2 - 8, 2, 32, CurTime()*-32)
								jcms.hud_DrawStripedRect(missionNameX + fullWidth/2 + warningtw/2 + 8, 83, fullWidth/2 - warningtw/2, 2, 32, CurTime()*32)
								surface.SetAlphaMultiplier(1)
							end

							local difficultyText = ("%s: %d%%"):format(language.GetPhrase("jcms.difficulty"), difficulty*100)
							local difficultyColour = jcms.color_pulsing
							if difficulty >= 1.35 then
								difficultyColour = jcms.color_alert
							elseif difficulty >= 0.9 then
								difficultyColour = jcms.color_bright
							end
							draw.SimpleText(difficultyText, "jcms_small_bolder", w - xpad + 4, textY, difficultyColour, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
						end
					end
				end
			-- }}}

			-- Side Panels {{{
				if IsValid(p.tabPnl) then
					p.tabPnl:SetPos(16, 48)
					p.tabPnl:SetSize(900, p:GetTall() - p.tabPnl:GetY() - 16)
				end
			-- }}}

			-- Main Panels {{{
				if jcms.util_IsPVP() then
					local npcPanelY = lowres and 300 or 378
					
					local pw, ph = lowres and 360 or 520, lowres and 38 or 48
					local px, py = w - pw - 16, npcPanelY - ph - 4

					if IsValid(p.plyPnlSweeper) then
						p.plyPnlSweeper:SetSize(lowres and 400 or 550, lowres and ScrH() * 0.25 or ScrH() * 0.35)
						p.plyPnlSweeper:SetPos(w - p.plyPnlSweeper:GetWide() - 16, npcPanelY)
						py = p.plyPnlSweeper:GetY() - ph - 4
					end

					if IsValid(p.plyPnlNPC) then
						p.plyPnlNPC:SetPos(w, h)
					end

					local team1Count, team2Count = 0, 0
					for i, ply in ipairs(player.GetAll()) do
						if ply:GetNWInt("jcms_desiredteam", 0) == 1 then
							local pvpTeam = ply:GetNWInt("jcms_pvpTeam", -1)

							if pvpTeam == 1 then
								team1Count = team1Count + 1
							elseif pvpTeam == 2 then
								team2Count = team2Count + 1
							end
						end
					end

					local balance = 0
					local myTeam = jcms.locPly:GetNWInt("jcms_pvpTeam", -1)
					if myTeam ~= -1 and team1Count ~= team2Count then
						if (myTeam == 1 and team2Count > team1Count) or (myTeam == 2 and team1Count > team2Count) then
							balance = -1
						else
							balance = 1
						end
					end

					local yoff = balance == 0 and ph/2 or ph/3

					local font = lowres and "DefaultSmall" or "jcms_small_bolder"
					local respawns = math.ceil( player.GetCount()/2 )
					local text = ("%dv%d"):format(team1Count, team2Count)
					local tw, th = draw.SimpleText(text, "jcms_hud_small", px, py+yoff, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText(text, "jcms_hud_small", px, py+yoff, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

					if balance ~= 0 then
						draw.SimpleText(balance<0 and "#jcms.pvp_number_disadvantage" or "#jcms.pvp_number_advantage", "DefaultSmall", px + tw/2, py+ph/3 + th/2, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
					end
					
					local icoSize = 32
					surface.SetDrawColor(myTeam == 1 and jcms.color_bright or jcms.color_pulsing)
					surface.SetMaterial( jcms.hud_GetPVPTeamMat(1) )
					surface.DrawTexturedRect(px-icoSize-8, py+yoff-icoSize/2, icoSize, icoSize)
				
					surface.SetDrawColor(myTeam == 2 and jcms.color_bright or jcms.color_pulsing)
					surface.SetMaterial( jcms.hud_GetPVPTeamMat(2) )
					surface.DrawTexturedRect(px+tw+8, py+yoff-icoSize/2, icoSize, icoSize)

					local tw = draw.SimpleText(" " .. language.GetPhrase("jcms.pvp_desc1b"):format(respawns), font, px + pw, py, jcms.color_bright_alt, TEXT_ALIGN_RIGHT)
					draw.SimpleText("#jcms.pvp_desc1a", font, px + pw - tw, py, jcms.color_bright, TEXT_ALIGN_RIGHT)
					draw.SimpleText("#jcms.pvp_desc2", font, px + pw, py + ph/2, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
					draw.SimpleText("#jcms.pvp_desc3", font, px + pw, py + ph, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
				else
					-- PvE player lists

					local npcPanelY = lowres and 260 or 320
					if IsValid(p.plyPnlSweeper) then
						p.plyPnlSweeper:SetSize(lowres and 400 or 550, lowres and ScrH() * 0.15 or ScrH() * 0.25)
						p.plyPnlSweeper:SetPos(w - p.plyPnlSweeper:GetWide() - 16, npcPanelY)

						local canvasHeight = p.plyPnlSweeper:GetCanvas():GetTall()
						local overflow = canvasHeight > p.plyPnlSweeper:GetTall()
						if overflow then
							surface.SetDrawColor(jcms.color_pulsing)
							local x = p.plyPnlSweeper:GetX()
							local y = p.plyPnlSweeper:GetY()
							surface.DrawRect(x - 32, y - 4, p.plyPnlSweeper:GetWide(), 1)
							surface.DrawRect(x - 32, y + p.plyPnlSweeper:GetTall() + 4, p.plyPnlSweeper:GetWide(), 1)
							npcPanelY = p.plyPnlSweeper:GetY() + p.plyPnlSweeper:GetTall() + 16
						else
							npcPanelY = p.plyPnlSweeper:GetY() + canvasHeight + 16
						end
					end

					if IsValid(p.plyPnlNPC) then
						p.plyPnlNPC:SetPos(w - p.plyPnlNPC:GetWide() - 24, npcPanelY)

						local topmostPly = p.plyPnlNPC:GetCanvas():GetChild(0)

						if IsValid(topmostPly) then
							draw.SimpleText("#jcms.npcshud", "jcms_medium", w - 418 + topmostPly:GetX(), p.plyPnlNPC:GetY(), jcms.color_bright)
						end

						local overflow = p.plyPnlNPC:GetCanvas():GetTall() > p.plyPnlNPC:GetTall()
						if overflow then
							surface.SetDrawColor(jcms.color_bright)
							local x = p.plyPnlNPC:GetX()
							local y = p.plyPnlNPC:GetY()
							surface.DrawRect(x - 32, y - 4, p.plyPnlNPC:GetWide(), 1)
							surface.DrawRect(x - 32, y + p.plyPnlNPC:GetTall() + 4, p.plyPnlNPC:GetWide(), 1)
						end
					end

				end

				if IsValid(p.controlPanel) then
					local y = p.controlPanel:GetY()
					local yTarget = (LocalPlayer():GetNWInt("jcms_desiredteam", 0) ~= 0) and (h - p.controlPanel:GetTall() - 4) or h + 32
					p.controlPanel:SetPos(w - p.controlPanel:GetWide() - 4, (y*8 + yTarget)/9)

					if IsValid(p.chatPanel) and IsValid(p.chatEntry) then
						p.chatEntry:SetY( math.min(ScrH(), y) - p.chatEntry:GetTall() - 12 )
						p.chatPanel:SetY( p.chatEntry:GetY() - p.chatPanel:GetTall() - 8 )
					end
				end
			-- }}}

			-- Mission Timer {{{
				local ongoing = jcms.util_IsGameOngoing()
				local missionTime = ongoing and jcms.util_GetMissionTime() or 0
				local isTimerOn = ongoing or jcms.util_IsGameTimerGoing()
				local timeRemains = ongoing and missionTime or jcms.util_GetTimeUntilStart()
				local loadProgress = jcms.util_GetMapGenProgress()
				local isLoading = loadProgress >= 0
				loadProgress = math.Clamp(loadProgress, 0, 1)
				
				if isLoading then
					local tw, th = w - missionNameX - 36, 32
					local tx, ty = missionNameX, 48

					surface.SetAlphaMultiplier(1)
					surface.SetDrawColor(jcms.color_pulsing)
					surface.DrawOutlinedRect(tx, ty-2, tw, th+4)
					
					surface.SetDrawColor(jcms.color_bright)
					surface.DrawRect(tx+4, ty+2, (tw-8)*loadProgress, th-4)
					surface.SetDrawColor(jcms.color_pulsing)
					jcms.hud_DrawStripedRect(tx+4+(tw-8)*loadProgress, ty+2+4, (tw-8)*(1-loadProgress), th-4-8, 32, CurTime()*-32)

					draw.SimpleTextOutlined( ("%s - %.1f%%"):format(language.GetPhrase("#jcms.generatingmap"), loadProgress*100), "jcms_medium", tx+tw/2, ty+th/2, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, jcms.color_dark)
					
				elseif isTimerOn then
					if not p.didTimerBeep then
						p.didTimerBeep = true
						surface.PlaySound("buttons/blip1.wav")
					end

					local timerCol = timeRemains <= 10 and jcms.color_alert or jcms.color_bright_alt
					if ongoing then
						timerCol = jcms.color_bright
					end

					surface.SetAlphaMultiplier(0.3)
					surface.SetDrawColor(timerCol)
					local tw, th = w - missionNameX - 36, difficulty >= 1.6 and 16 or 24
					local tx, ty = missionNameX, 48
					jcms.hud_DrawNoiseRect(tx + 4, ty + 2, tw - 8, th - 4, 32)

					surface.SetAlphaMultiplier(1)
					surface.SetDrawColor(timerCol)
					surface.DrawRect(tx, ty, 1, th)
					surface.DrawRect(tx + tw - 1, ty, 1, th)

					if ongoing then
						local time = string.FormattedTime( missionTime )
						local formatted = string.format("%02i:%02i:%02i", time.h, time.m, time.s)
						draw.SimpleText("#jcms.missioninprogress", "jcms_small", tx + th/2, ty + th/2, timerCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						draw.SimpleText(formatted, "jcms_small_bolder", tx + tw - th/2, ty+th/2, timerCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
					else
						draw.SimpleText(timeRemains < 5 and "#jcms.missionbegins" or "#jcms.countdowntomission", "jcms_small", tx + th/2, ty + th/2, timerCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						draw.SimpleText(string.FormattedTime(timeRemains, "%02i:%02i"), "jcms_small_bolder", tx + tw - th/2, ty+th/2, timerCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
					end
				else
					if p.didTimerBeep then
						p.didTimerBeep = false
						surface.PlaySound("buttons/combine_button_locked.wav")
					end
				end
			-- }}}

			surface.SetAlphaMultiplier(1)
			drawScanlines(w,h,r2,g2,b2)
		end

		function jcms.offgame_paintover_LobbyFrame(p, w, h)
			if type(jcms.offgame.noiseOverlay) == "number" then
				local ov = jcms.offgame.noiseOverlay

				local r, g, b = jcms.color_bright:Unpack()

				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				surface.SetDrawColor(r, g, b, 255*math.ease.InOutCirc(math.min(ov, 1)))
				jcms.hud_DrawNoiseRect(0, 0, w, h, Lerp(ov, w, h))
				render.OverrideBlend( false )

				ov = math.max(0, ov - RealFrameTime()*ov*3.2)
				if ov <= 0 then
					jcms.offgame.noiseOverlay = nil
				else
					jcms.offgame.noiseOverlay = ov
				end
			end
		end

		function jcms.offgame_paint_MissionTab(p, w, h)
			local x1 = IsValid(p.btnHouse) and p.btnHouse:GetX() or 0
			if game.SinglePlayer() then
				draw.SimpleText("#jcms.solo", "jcms_hud_medium", x1 + 200, 128, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				draw.SimpleText("#jcms.pod_text", "jcms_small", x1 + 200, 128 + 6, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			else
				draw.SimpleText(GetHostName(), "jcms_small", x1 + 200, 128 - 38, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				draw.SimpleText("#jcms.pod_text", "jcms_medium", x1 + 200, 128 - 12, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			end

			if IsValid(p.voteHouse) and (p.voteHouse:GetX() > -p.voteHouse:GetWide() + 4) then
				local x2 = p.voteHouse:GetX()
				draw.SimpleText("#jcms.pvpvotetitle", "jcms_medium", x2 + 200, 100, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				
				local plyCount = player.GetCount() --TODO: Needs connecting count to be networked & added
				local buttonSpacing = 2
				local bw = (400 - 48) / plyCount - buttonSpacing
				
				local vote = jcms.pvp_vote

				local time = string.FormattedTime(math.floor(vote.endsAt - CurTime()))
				local formatted = string.format("%02i:%02i", time.m, time.s)
				draw.SimpleText(formatted, "jcms_big", x2 + 200, 100, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

				local yesCount, noCount, anyCount = #vote.yes, #vote.no, #vote.any
				local opinionCount = yesCount + noCount
				
				surface.SetDrawColor(jcms.color_pulsing)
				local by = 200 - 48
				local t = (CurTime() % 1)*32

				jcms.hud_DrawStripedRect(x2 + 8, by - 4 - 4, 400 - 16, 4, 32, t)
				jcms.hud_DrawStripedRect(x2 + 8, by + 24 + 4, 400 - 16, 4, 32, t)

				local useSingleBar = bw <= 13

				if useSingleBar then
					bw = bw + buttonSpacing

					local bx1 = x2 + 24
					local bx2 = bx1 + 400 - 48

					surface.DrawOutlinedRect(x2 + 24 - 2, by, bx2 - bx1 + 4, 24)
					
					if yesCount > 0 then
						surface.SetDrawColor(jcms.color_bright_alt)
						surface.DrawRect(bx1, by + 2, bw*yesCount, 20)
					end

					if anyCount > 0 then
						surface.SetDrawColor(jcms.color_pulsing)
						surface.DrawRect(bx1 + bw*yesCount, by + 2, bw*anyCount, 20)
					end

					if noCount > 0 then
						surface.SetDrawColor(jcms.color_bright)
						surface.DrawRect(bx2 - bw*noCount + 1, by + 2, bw*noCount, 20)
					end
				else
					for i=1, plyCount do
						local bx = plyCount == 1 and (400-bw)/2 or math.Remap(i, 1, plyCount, 24, 400 - 24 - bw)
						jcms.hud_DrawHollowPolyButton(x2 + bx, by, bw, 24, 8)

						if i <= yesCount then
							surface.SetDrawColor(jcms.color_bright_alt)
								jcms.hud_DrawFilledPolyButton(x2 + bx + 2, by + 2, bw - 4, 24 - 4, 6)
							surface.SetDrawColor(jcms.color_pulsing)
							draw.SimpleText("v", "jcms_small_bolder", x2 + bx + bw/2, by + 24/2, jcms.color_dark_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						elseif i >= plyCount - noCount + 1 then
							surface.SetDrawColor(jcms.color_bright)
								jcms.hud_DrawFilledPolyButton(x2 + bx + 2, by + 2, bw - 4, 24 - 4, 6)
							surface.SetDrawColor(jcms.color_pulsing)
							draw.SimpleText("x", "jcms_small_bolder", x2 + bx + bw/2, by + 24/2, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						elseif i <= yesCount + anyCount then
							draw.SimpleText("/", "jcms_small_bolder", x2 + bx + bw/2, by + 24/2, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						end
					end
				end
			end

			surface.SetDrawColor(jcms.color_pulsing)
			jcms.hud_DrawStripedRect(0, 0, 4, h, 32, CurTime()*32)
			jcms.hud_DrawStripedRect(400-4, 0, 4, h, 32, CurTime()*32)
		end

		function jcms.offgame_paint_PersonalTab(p, w, h)
			local lowres = p.lowres
			local avSize = lowres and 64 or 128
			local pad = 3

			surface.SetDrawColor(jcms.color_pulsing)
			jcms.hud_DrawStripedRect(64-pad, 64-pad, avSize+pad*2, avSize+pad*2, 32, CurTime()*8)

			surface.SetDrawColor(jcms.color_bright)
			surface.DrawRect(64-pad, 64-pad, 72, 1)
			surface.DrawRect(64-pad+8, 64-pad-2, lowres and 48 or 96, 1)
			surface.DrawRect(64-pad, 64-pad+1, 1, 48)
			surface.DrawRect(avSize, 64+avSize+pad, 64, 1)

			local profileX = 64 + avSize + 24
			local yOffset = lowres and -16 or 0
			draw.SimpleText(LocalPlayer():Nick(), "jcms_hud_small", profileX, 72+yOffset, jcms.color_bright)

			local level, exp = jcms.statistics_GetLevelAndEXP()
			local nextLevelExp = jcms.statistics_GetEXPForNextLevel(level + 1)

			surface.SetDrawColor(jcms.color_bright)
			drawFilledPolyButton(profileX, 118+yOffset, 64, 24)
			drawHollowPolyButton(profileX + 64 + 8, 118+yOffset, 256, 8, 4)
			drawFilledPolyButton(profileX + 64 + 8, 118+yOffset, 256*math.Clamp(exp/nextLevelExp, 0, 1), 8, 4)

			draw.SimpleText(level, level >= 100000 and "jcms_small_bolder" or "jcms_medium", profileX + 32, 118+yOffset + 24/2, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(("%d / %d"):format(exp, nextLevelExp), "jcms_small", profileX + 64 + 254, 118+yOffset + 12, jcms.color_bright, TEXT_ALIGN_RIGHT)
		end

		function jcms.offgame_paint_ClassPanel(p, w, h)
			surface.SetDrawColor(jcms.color_bright)
			drawHollowPolyButton(0, 0, w, h, 8)

			local myclass = LocalPlayer():GetNWString("jcms_desiredclass", "infantry")
			local classData = jcms.classes[ myclass ]

			if p.lowres then
				local tw1 = draw.SimpleText("#jcms.class_" .. myclass, "jcms_medium", h + 8, 12, jcms.color_bright)
				local tw2 = draw.SimpleText("#jcms.class_" .. myclass .. "_special", "jcms_small", w - 32, 16, jcms.color_bright, TEXT_ALIGN_RIGHT)
			
				local widthMul = (w - h*2 - 64 - 16)/200
				local healthWidth = classData.health*widthMul
				local armorWidth = classData.shield*widthMul

				surface.SetDrawColor(jcms.color_bright)
				drawFilledPolyButton(h + 8, 36, healthWidth, 8, 4)
				surface.SetDrawColor(jcms.color_bright_alt)
				drawFilledPolyButton(h + 8, 36 + 10, armorWidth, 8, 4)
				draw.SimpleText(classData.health, "DefaultVerySmall", h + 4, 36 + 4, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				draw.SimpleText(classData.shield, "DefaultVerySmall", h + 4, 36 + 14, jcms.color_bright_alt, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				surface.SetAlphaMultiplier(0.5)
				draw.SimpleText(language.GetPhrase("jcms.shieldregen"):format(classData.shieldRegen, classData.shieldDelay), "DefaultVerySmall", h, 36+20, jcms.color_bright_alt)
				surface.SetAlphaMultiplier(1)

				local xpos = h + 8 + tw1 + 8
				surface.SetDrawColor(jcms.color_bright)
				jcms.hud_DrawNoiseRect(xpos, 22, w - 32 - tw2 - xpos - 8, 1)
				local mup = markup.Parse( ("<color=%d,%d,%d><font=DefaultVerySmall>• "):format( jcms.color_bright:Unpack() ) .. language.GetPhrase("jcms.class_" .. myclass .. "_desc"):gsub("\n", "\n• "), h + 96)
				mup:Draw(w - h - 64 - 32, 34, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 200, TEXT_ALIGN_LEFT)
			else
				local tw1 = draw.SimpleText("#jcms.class_" .. myclass, "jcms_hud_small", h + 8, 16, jcms.color_bright)
				local tw2 = draw.SimpleText("#jcms.class_" .. myclass .. "_special", "jcms_medium", w - 32, 24, jcms.color_bright, TEXT_ALIGN_RIGHT)

				local widthMul = (w - h*2 - 64 - 16)/200
				local healthWidth = classData.health*widthMul
				local armorWidth = classData.shield*widthMul

				surface.SetDrawColor(jcms.color_bright)
				drawFilledPolyButton(h + 8, 58, healthWidth, 18)
				surface.SetDrawColor(jcms.color_bright_alt)
				drawFilledPolyButton(h + 8, 58 + 20, armorWidth, 18)
				draw.SimpleText(classData.health, "jcms_medium", h + 16, 58 + 9, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(classData.shield, "jcms_medium", h + 16, 58 + 20 + 9, jcms.color_dark_alt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				surface.SetAlphaMultiplier(0.5)
				draw.SimpleText(language.GetPhrase("jcms.shieldregen"):format(classData.shieldRegen, classData.shieldDelay), "jcms_small", h + 16, 58 + 42, jcms.color_bright_alt)
				surface.SetAlphaMultiplier(1)

				local xpos = h + 8 + tw1 + 8
				surface.SetDrawColor(jcms.color_bright)
				jcms.hud_DrawNoiseRect(xpos, 34, w - 32 - tw2 - xpos - 8, 1)
				local mup = markup.Parse( ("<color=%d,%d,%d><font=jcms_small>• "):format( jcms.color_bright:Unpack() ) .. language.GetPhrase("jcms.class_" .. myclass .. "_desc"):gsub("\n", "\n• "), h + 64)
				mup:Draw(w - h - 64 - 32, 54, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 200, TEXT_ALIGN_LEFT)
			end
		end

		function jcms.offgame_paint_LoadoutPanel(p, w, h)
			local lowres = p.lowres
			local y1 = lowres and 128 or 164 + 32 + 8
			surface.SetDrawColor(jcms.color_bright)
			drawHollowPolyButton(0, 0, w, y1-8, 8)
			drawHollowPolyButton(0, y1, w, h - y1, 8)

			draw.SimpleText("#jcms.loadout", lowres and "jcms_medium" or "jcms_hud_small", 24, 8, jcms.color_bright)
			surface.SetAlphaMultiplier(0.5)
			draw.SimpleText("#jcms.loadout_tip", lowres and "DefaultVerySmall" or "jcms_small", 24, lowres and 30 or 42, jcms.color_bright)
			surface.SetAlphaMultiplier(1)

			draw.SimpleText("#jcms.shop", lowres and "jcms_medium" or "jcms_hud_small", 24, y1 + 8, jcms.color_bright)
			surface.SetAlphaMultiplier(0.5)
			draw.SimpleText("#jcms.shop_tip", lowres and "DefaultVerySmall" or "jcms_small", 24, y1 + (lowres and 30 or 42), jcms.color_bright)
			surface.SetAlphaMultiplier(1)
			
			local loadoutCost = LocalPlayer():GetNWInt("jcms_pendingLoadoutCost", 0)

			local font = "jcms_title"
			local cashString = jcms.util_CashFormat(LocalPlayer():GetNWInt("jcms_cash", 0) - loadoutCost) .. " J"
			surface.SetFont(font)
			local tw = surface.GetTextSize(cashString) + 24
			drawFilledPolyButton(w-tw-4, 4, tw, 24, 8)
			draw.SimpleText(cashString, font, w - 16, 16, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			draw.SimpleText("#jcms.cashhud", "jcms_small", w-16-tw, 16, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			if loadoutCost > 0 then
				local loadoutCostString = "( -" .. jcms.util_CashFormat(loadoutCost) .. " J )"
				draw.SimpleText(loadoutCostString, font, w - 16, 32, jcms.color_bright_alt, TEXT_ALIGN_RIGHT)
			end

			local mismatchDetected = ( #LocalPlayer():GetWeapons() ~= #p.weaponButtons )
			if not mismatchDetected then
				for i, wep in ipairs( LocalPlayer():GetWeapons() ) do
					if wep:GetClass() ~= p.weaponButtons[i].gunClass then
						mismatchDetected = true
						break
					end
				end
			end

			if mismatchDetected then
				for i, btn in ipairs(p.weaponButtons) do
					btn:Remove()
					p.weaponButtons[i] = nil
				end

				local function wbtnClick(self)
					surface.PlaySound("physics/metal/weapon_impact_hard" .. math.random(1,3) .. ".wav")
					RunConsoleCommand("jcms_buyweapon", self.gunClass, input.IsKeyDown(KEY_LSHIFT) and -9999999 or -1)
				end

				local myweapons = LocalPlayer():GetWeapons()
				local mini = h <= 600
				local bsize = lowres and 38 or (mini and 64 or 80)
				local fitMul = math.min(1, (w - 48) / #myweapons / (bsize+4))
				for i, wep in ipairs(myweapons) do
					local class = wep:GetClass()

					local wbtn = p:Add("DButton")
					wbtn:SetSize(bsize*fitMul, bsize)
					wbtn:SetPos(24 + (bsize*fitMul+4)*(i-1), lowres and 50 or (64 + (mini and 12 or 4)))
					wbtn.Paint = jcms.paint_Gun
					wbtn.DoClick = wbtnClick
					wbtn.gunSale = jcms.util_GetLobbyWeaponCostMultiplier()
					wbtn.ammoSale = 1
					wbtn.gunClass = class 
					wbtn.gunStats = jcms.gunstats_Get(class)
					wbtn.cost = jcms.weapon_prices[class]
					p.weaponButtons[i] = wbtn
				end
			end

			for i, wbtn in ipairs(p.weaponButtons) do
				local count = jcms.weapon_loadout[wbtn.gunClass] or 0

				if wbtn.gunStats and jcms.weapon_prices[wbtn.gunClass] then
					wbtn.cost = math.ceil(jcms.weapon_prices[wbtn.gunClass]*wbtn.gunSale) + math.ceil(jcms.gunstats_ExtraAmmoCostData(wbtn.gunStats, count-1)*wbtn.ammoSale)
				end

				wbtn.count = count
			end

			local hoveredElement = vgui.GetHoveredPanel()
			if IsValid(hoveredElement) and hoveredElement.gunClass then
				local y = lowres and 188 or 278
				local class = hoveredElement.gunClass
				local stats = hoveredElement.gunStats

				local mini = h - y <= 300
				local twname = draw.SimpleText(stats.name, "jcms_small_bolder", 24, y, jcms.color_bright)
				y = y + 16

				surface.SetAlphaMultiplier(0.35)
				local twbase = draw.SimpleText(stats.base, "jcms_small", 28, y, jcms.color_bright)
				y = y + (mini and 8 or 20)

				local mat = jcms.gunstats_GetMat(class)

				if mat and not mat:IsError() then
					surface.SetMaterial(mat)
					surface.SetDrawColor(255, 255, 255)
					if mini then
						surface.DrawTexturedRect(256 - 64 - 8, y - 24, 64, 64, 0)
						y = y + 16
					else
						surface.DrawTexturedRect(32, y, 96, 96, 0)
						y = y + 112
					end
				else
					y = y + 16
				end

				surface.SetAlphaMultiplier(0.5)
				local tw1 = draw.SimpleText("#jcms.sortmode_damage", "jcms_small", 24, y, jcms.color_bright)
				surface.SetAlphaMultiplier(1)
				local tw1a = draw.SimpleText(stats.numshots>1 and math.Round(stats.damage, 2) .. " (x" .. stats.numshots..")" or math.Round(stats.damage, 2), "jcms_small_bolder", 24 + tw1 + 8, y, jcms.color_bright)
				surface.SetAlphaMultiplier(0.5)

				y = y + (mini and 16 or 24)
				local tw2 = draw.SimpleText("#jcms.sortmode_firerate", "jcms_small", 24, y, jcms.color_bright)
				surface.SetAlphaMultiplier(1)
				local tw2a = draw.SimpleText(math.Round(stats.firerate_rps * 60), "jcms_small_bolder", 24 + tw2 + 8, y, jcms.color_bright)

				local mx = 28 + math.max(tw1 + tw1a, tw2 + tw2a) + 16
				surface.SetAlphaMultiplier(0.5)
				surface.SetDrawColor(jcms.color_bright_alt)
				surface.DrawRect(mx, y - (mini and 16 or 24), 1, mini and 28 or 38)
				draw.SimpleText("#jcms.sortmode_dps", "jcms_small", mx + 8, y - (mini and 16 or 24), jcms.color_bright_alt)
				surface.SetAlphaMultiplier(1)
				if stats.dps > 99999999 then
					draw.SimpleText("∞", "jcms_medium", mx + 8, y - 6, jcms.color_bright_alt)
				else
					draw.SimpleText(math.Round(stats.dps), "jcms_medium", mx + 8, y - 8, jcms.color_bright_alt)
				end

				y = y + (mini and 24 or 35)
				surface.SetAlphaMultiplier(0.5)
				local tw3 = draw.SimpleText("#jcms.gun_spread", "jcms_small", 24, y, jcms.color_bright)
				surface.SetAlphaMultiplier(1)
				draw.SimpleText(math.Round(stats.accuracy, 2) .. "°", "jcms_small_bolder", 24 + tw3 + 8, y, jcms.color_bright)
				y = y + (mini and 16 or 24)
				surface.SetAlphaMultiplier(0.5)
				local tw4 = draw.SimpleText("#jcms.gun_range", "jcms_small", 24, y, jcms.color_bright)
				surface.SetAlphaMultiplier(1)
				if stats.range >= math.huge then
					draw.SimpleText("∞", "jcms_medium", 24 + tw3 + 8, y - 2, jcms.color_bright)
				else
					draw.SimpleText(jcms.util_ToDistance(stats.range, true), "jcms_small_bolder", 24 + tw4 + 8, y, jcms.color_bright)
				end

				if stats.ammotype ~= "none" then
					y = y + (mini and 24 or 35)
					surface.SetAlphaMultiplier(0.5)
					local tw5 = draw.SimpleText("#jcms.sortmode_clipsize", "jcms_small", 24, y, jcms.color_bright_alt)
					surface.SetAlphaMultiplier(1)

					draw.SimpleText(stats.clipsize, "jcms_small_bolder", 24 + tw5 + 8, y, jcms.color_bright_alt)
					draw.SimpleText(language.GetPhrase(stats.ammotype_lkey), "jcms_medium", 28, y + 16, jcms.color_bright_alt)
				end

				if stats.base == "Default" and weapons.GetStored(hoveredElement.gunClass) then
					surface.SetDrawColor(jcms.color_pulsing)
					if mini then
						y = h - 54 - 16
						jcms.hud_DrawStripedRect(16, y, 256 - 32, 8, 32)
						draw.SimpleText("#jcms.unknownbase0", "jcms_small_bolder", 128, y + 27, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
						draw.SimpleText("#jcms.unknownbase1", "jcms_small", 128, y + 27, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
						jcms.hud_DrawStripedRect(16, y + 54 - 8, 256 - 32, 8, 32)
					else
						y = h - 48 - 24 - 16 - 32 - 24 -- Fuck
						y = y + 48
						jcms.hud_DrawStripedRect(16, y, 256 - 32, 8, 32)
						y = y + 24
						draw.SimpleText("#jcms.unknownbase0", "jcms_small_bolder", 128, y, jcms.color_pulsing, TEXT_ALIGN_CENTER)
						y = y + 16
						draw.SimpleText("#jcms.unknownbase1", "jcms_small", 128, y, jcms.color_pulsing, TEXT_ALIGN_CENTER)
						y = y + 32
						jcms.hud_DrawStripedRect(16, y, 256 - 32, 8, 32)
					end
				end

				surface.SetAlphaMultiplier(1)

				if IsValid(p.categoryComboBox) then
					p.categoryComboBox:SetX(-10000)
				end
				if IsValid(p.sortComboBox) then
					p.sortComboBox:SetX(-10000)
				end
				if IsValid(p.reverseSort) then
					p.reverseSort:SetX(-10000)
				end
			else
				surface.SetAlphaMultiplier(0.3)
				surface.SetDrawColor(jcms.color_bright)
				if lowres then
					jcms.hud_DrawNoiseRect(16, 172 + 8, 256 - 24, h - 172 - 8 - 16, 128)
				else
					jcms.hud_DrawNoiseRect(16, 270 + 8, 256 - 24, h - 270 - 8 - 16, 128)
				end
				surface.SetAlphaMultiplier(1)

				if IsValid(p.categoryComboBox) then
					p.categoryComboBox:SetX(16)
				end
				if IsValid(p.sortComboBox) then
					p.sortComboBox:SetX(16)
				end
				if IsValid(p.reverseSort) then
					p.reverseSort:SetX(IsValid(p.sortComboBox) and p.sortComboBox:GetX()+p.sortComboBox:GetWide()+4 or 16)
				end
			end

			if #p.shop.weaponButtons <= 0 then
				y1 = y1 + (lowres and 8 or 24)

				local leftPanelEdge = 248
				local markupPad = lowres and 4 or 24
				local colorTag = ("<color=%d,%d,%d>"):format(jcms.color_bright:Unpack())
				if not p.noWeaponMarkup then
					p.noWeaponMarkup = markup.Parse( ("<font=jcms_small>%s%s\n\n%s\n\n%s</color>"):format( colorTag, language.GetPhrase("jcms.shop_noweapons2"), language.GetPhrase("jcms.shop_noweapons3"), language.GetPhrase("jcms.shop_noweapons4")), w-leftPanelEdge-markupPad*2 )
				end
				local _, th = draw.SimpleText("#jcms.shop_noweapons1", lowres and "jcms_small_bolder" or "jcms_big", (w-leftPanelEdge)*0.5 + leftPanelEdge, y1 + 64, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				p.noWeaponMarkup:Draw(leftPanelEdge + markupPad, y1 + 64 + th + 8)
			end

			p.existsForTime = (p.existsForTime or 0) + RealFrameTime()
			if p.existsForTime > 1.5 and jcms.locPly:GetNWInt("jcms_desiredteam", 0) == 0 then
				local tabPnl = p:GetParent()

				for i, child in ipairs(tabPnl:GetChildren()) do
					child:Remove()
				end
				
				tabPnl.Paint = nil
				jcms.offgame_BuildMissionTab(tabPnl)
			end
		end

		function jcms.offgame_paint_ControlPanel(p, w, h)
			surface.SetDrawColor(jcms.color_pulsing)
			drawHollowPolyButton(0, 32, w, h)
			jcms.hud_DrawStripedRect(0, 32 - 6, w, 4, 32)
			
			if IsValid(p.bReady) then
				p.bReady:SetText( (game.SinglePlayer() or jcms.util_IsGameOngoing()) and "#jcms.deploy" or "#jcms.toggleready")
			end

			if IsValid(p.chatPanel) and IsValid(p.chatEntry) then
				local baseY = (p:GetY() - ScrH())*0.75 + ScrH()
				p.chatEntry:SetY( baseY - p.chatEntry:GetTall() - 8 )
				p.chatPanel:SetY( p.chatEntry:GetY() - p.chatPanel:GetTall() - 8 )
			end
		end

		function jcms.offgame_paint_PersonalPanel(p, w, h)
			surface.SetDrawColor(jcms.color_pulsing)
			drawHollowPolyButton(0, -1, w, h+2)
			draw.SimpleText(p.jText or "", "jcms_medium", 16, 8, jcms.color_bright)

			if IsValid(p.scrollPanel) and IsValid(p.scrollPanel.VBar) then
				p.scrollPanel.VBar.Paint = BLANK_DRAW
				p.scrollPanel.VBar:SetHideButtons(true)
				p.scrollPanel.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
			end
		end

		function jcms.offgame_paint_CreditsPanelDevs(p, w, h)
			surface.SetDrawColor(jcms.color_pulsing)
			drawHollowPolyButton(0, -1, w, 212)
			drawHollowPolyButton(0, 212-1+4, w, h-212-4+2)

			local _, th = draw.SimpleText("MAP SWEEPERS", "jcms_big", w/2, 0, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText("by Octantis Addons", "jcms_medium", w/2, th - 4, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)			
			local devs = {
				{ "MerekiDor", "#jcms.credits_lead", "#jcms.credits_coregameplay", "#jcms.credits_ui", "#jcms.credits_vfx", "#jcms.credits_models" },
				{ "JonahSoldier", "#jcms.credits_gamedesign", "#jcms.credits_missiondesign", "#jcms.credits_classdesign", "#jcms.credits_ai", "#jcms.credits_va" },
			}
			
			for i, dev in ipairs(devs) do
				local x = w/4 + (w/2) * (i-1)
				local y = 66
				draw.SimpleText(dev[1], "jcms_medium", x, y, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				y = y + 28
				for j=2, #dev do
					draw.SimpleText(dev[j], "jcms_small_bolder", x, y, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
					y = y + 18
				end
			end

			draw.SimpleText("★ " .. language.GetPhrase("jcms.credits_github"), "jcms_medium", 24, 218, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			local contributors = {
				"Redox", "thecraftianman", "rtkz_wasa19741"
			}

			draw.SimpleText(table.concat(contributors, ", "), "jcms_small_bolder", 28, 248, jcms.color_pulsing)
		end

		function jcms.offgame_paint_CreditsPanelPeopleList(p, w, h)
			surface.SetDrawColor(jcms.color_pulsing)
			jcms.hud_DrawNoiseRect(8, 0, w - 16, 24)
			drawHollowPolyButton(0, -1, w, h+2)

			draw.SimpleText(p.jText, "jcms_medium", w/2, 0, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			local people = p.peopleList
			
			local columns = p.columnCount or 4
			local rows = math.ceil( #people / columns )
			local col, row = 0, 1

			local font, spacing = "jcms_small_bolder", 16
			if p.lowres then
				font, spacing = "DefaultSmall", 16
			end

			for i, person in ipairs(people) do
				col = col + 1
				if col > columns then
					col = 1
					row = row + 1
				end

				draw.SimpleText(person, font, col * w/(columns+1), 24 + row*spacing, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end
		end

		function jcms.offgame_paint_SocialMediaButton(p, w, h)
			surface.SetDrawColor(p:IsHovered() and jcms.color_bright or jcms.color_pulsing)
			drawHollowPolyButton(0, -1, w, h+2)
			surface.SetDrawColor(p.jColor or color_white)
			drawFilledPolyButton(4, 4, w-8, h-8)
			local text = p.jText
			draw.SimpleTextOutlined(text, "jcms_medium", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
			return true
		end

		function jcms.offgame_paint_Table(p, w, h)
			local columnOffset = p.tableColumnsOffset or 0
			local rows, columnCount = p.tableRows, p.tableColumns + columnOffset
			local y = 0
			if rows and columnCount and columnCount > 0 then
				for i, row in ipairs(rows) do
					local ind = row.indent or 0
					local col = row.color or jcms.color_bright
					local font = ind==0 and "jcms_medium" or (ind==1 and "jcms_small_bolder" or "jcms_small")
					
					if ind == 1 then
						surface.SetDrawColor(col)
						jcms.hud_DrawNoiseRect(ind*8 - 4, y - 2, w, 16, 32)
					end
					
					draw.SimpleText(row.title, font, ind*8, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
					for j=1, columnCount do
						draw.SimpleText(row[j] or "", font, w/columnCount*(j + columnOffset) - ind*4, y, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
					end

					if ind == 2 then
						surface.SetDrawColor(col)
						surface.DrawRect(ind*8 - 4, y - 2, 1, 16)
					end

					local height = (ind == 0 and 28 or 18)
					y = y + height
				end
			end
		end

		function jcms.offgame_paint_PieChart(p, w, h)
			local data = p.chartData
			if data and next(data) then
				local minValue = 0.1
				local sum = 0
				
				for i, d in ipairs(data) do
					sum = sum + (tonumber(d.n) or 0) + minValue
				end

				local a = 0
				local apad = 0.03
				local smul = p.sizeMul or 0.8
				for i, d in ipairs(data) do
					local frac = (d.n + minValue) / sum
					local aLen = frac * math.pi * 2
					
					local a1, a2 = a + apad, a + aLen - apad
					local col = d.color or jcms.color_bright
					surface.SetAlphaMultiplier(0.3)
					surface.SetDrawColor(col)
					jcms.draw_Circle(w/2, h/2, w/2*smul, h/2*smul, 8, 32, a1, a2)
					surface.SetAlphaMultiplier(1)
					
					if frac > 0.1 then
						local title = tostring(d.title or "")
						if #title > 0 then
							local x, y = math.cos( (a1+a2)/2 )*w*0.4*smul+w/2, math.sin( (a1+a2)/2 )*h*0.4*smul+h/2
							if p.displayNumbers then
								draw.SimpleTextOutlined(title, p.jFont or "jcms_small", x, y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, jcms.color_dark)
								draw.SimpleTextOutlined(jcms.util_CashFormat(d.n), p.jFontNum or "jcms_medium", x, y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, jcms.color_dark)
							else
								draw.SimpleTextOutlined(title, p.jFont or "jcms_medium", x, y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, jcms.color_dark)
							end
						end
					end
					
					a = a + aLen
				end
			else
				local smul = p.sizeMul or 0.8
				surface.SetDrawColor(jcms.color_pulsing)
				jcms.draw_Circle(w/2, h/2, w/2*smul, h/2*smul, 8, 32, 0, math.pi*2)
			end
		end

		function jcms.offgame_paint_TBAPanel(p, w, h)
			surface.SetDrawColor(jcms.color_pulsing)
			jcms.hud_DrawNoiseRect(4, 4, w - 8, h - 8)
			draw.SimpleText("#jcms.upcoming", "jcms_big", w/2, h/2, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		function jcms.offgame_paint_CustomizeHUD(p, w, h)
			surface.SetDrawColor(jcms.color_pulsing)
			drawHollowPolyButton(0, -1, w, h+2)

			draw.SimpleText("#jcms.opt_customizehud", "jcms_medium", 16, 4, jcms.color_bright)
		end

		function jcms.offgame_paint_CrosshairPreview(p, w, h)
			surface.SetDrawColor(jcms.color_pulsing)
			jcms.hud_DrawStripedRect(0, 0, w, h, 32, CurTime()%1*8)
			surface.SetDrawColor(jcms.color_dark)
			surface.DrawRect(2, 2, w-4, h-4)

			local x, y = p:LocalToScreen(0, 0)
			local sc = 0.3
			local m = Matrix()

			m:Scale(Vector(sc, sc, 1))
			m:Translate(Vector(-x+x/sc+w/2/sc, -y+y/sc+h/2/sc, 0))

			cam.PushModelMatrix(m, true)
				DisableClipping(true)
				jcms.draw_Crosshair()
				DisableClipping(false)
			cam.PopModelMatrix()
		end

		function jcms.offgame_paint_OnlineToolTip(p, w, h)
			local players = player.GetAll()
			h = #players * 16 + 32

			surface.SetDrawColor(jcms.color_dark)
			surface.DrawRect(0, 24, w, h-24)
			
			local time = CurTime() % 1 * 8
			surface.SetDrawColor(jcms.color_bright)
			jcms.hud_DrawStripedRect(0, 24, 4, h-24, 32, time)
			jcms.hud_DrawStripedRect(w-4, 24, 4, h-24, 32, time)
			surface.DrawRect(8, 24, w-16, 1)
			surface.DrawRect(8, h-1, w-16, 1)

			for i, ply in ipairs(players) do
				draw.SimpleText( ply:Nick(), ply == jcms.locPly and "jcms_small_bolder" or "jcms_small", w/2, 20 + i*16, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			return true
		end

		function jcms.offgame_paint_ChatPanel(p, w, h)
			local anim = p.visibilityAnim
			local r,g,b = jcms.color_bright:Unpack()
			surface.SetDrawColor(r,g,b,anim*255)
			drawHollowPolyButton(0, 0, w, h, 8)

			if IsValid(p.scrollArea) and IsValid(p.scrollArea.VBar) then
				p.scrollArea.VBar.Paint = BLANK_DRAW
				p.scrollArea.VBar:SetHideButtons(true)
				p.scrollArea.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
			end

			return true
		end

		function jcms.offgame_paint_ChatMessage(p, w, h)
			local visAnim = p.visibilityAnim

			surface.SetAlphaMultiplier(visAnim)
			surface.SetDrawColor(jcms.color_pulsing)
			jcms.hud_DrawNoiseRect(0, 0, w, h)
			
			surface.SetDrawColor(jcms.color_bright)
			draw.SimpleText(p.title, "jcms_small_bolder", 4, 2, jcms.color_bright)

			p.markup:Draw(8, 18)
			surface.SetAlphaMultiplier(1)
		end

		function jcms.offgame_paint_ChatEntryOver(p, w, h)
			local cond = p:IsHovered()
			local brightColor = cond and jcms.color_bright_alt or jcms.color_bright
			local altColor = cond and jcms.color_bright or jcms.color_bright_alt
			local pulsingColor = ColorAlpha(brightColor, jcms.hud_pulsingAlpha)

			p:SetCursorColor(brightColor)
			p:SetHighlightColor(altColor)
			p:SetTextColor(brightColor)
			p:SetPlaceholderColor(pulsingColor)

			surface.SetDrawColor(cond and brightColor or pulsingColor)
			if p:IsMultiline() then
				surface.DrawOutlinedRect(0, 0, w, h)
			else
				surface.DrawRect(0, h-1, w, 1)
			end

			if IsValid(p:GetParent()) and IsValid(p:GetParent().label) then
				p:GetParent().label:SetTextColor(cond and brightColor or pulsingColor)
			end
		end

		function jcms.offgame_paint_BestiaryImageArea(p, w, h)
			p.anim = p.anim + RealFrameTime()

			local mat = p.factionMat and not p.factionMat:IsError() and p.factionMat
			local modelPanel = p.modelPanel
			local entry = p.entry
			if IsValid(modelPanel) and type(entry) == "table" then
				local x, y, w, h = modelPanel:GetX(), modelPanel:GetY(), modelPanel:GetWide(), modelPanel:GetTall()
				for i=1, 4 do
					local pad = (1 - i) * (-3 - 32/(p.anim*8+1))
					surface.SetAlphaMultiplier(1 / i^2)
					surface.SetDrawColor(jcms.color_bright)
					drawHollowPolyButton(x + pad, y + pad, w - pad*2, h - pad*2, 8 - pad)
				end

				surface.SetAlphaMultiplier(math.Clamp(math.ease.InBack(1.2 - p.anim*2), 0, 1))
				surface.SetDrawColor(jcms.color_bright)
				jcms.hud_DrawNoiseRect(x + 4, y + 4, w - 8, h - 8)
				surface.SetAlphaMultiplier(1)

				draw.SimpleText(p.entryName, "jcms_medium", 24, 24, jcms.color_bright)

				if mat then
					surface.SetMaterial(mat)
					surface.SetDrawColor(jcms.color_bright)
					surface.DrawTexturedRect(x + w + 8, y, 96, 96)
				end

				local str1 = jcms.util_CashFormat(entry.health)
				local font1 = "jcms_hud_small"
				surface.SetFont(font1)
				local tw1 = surface.GetTextSize(str1)
				if tw1 > 72 then font1 = "jcms_medium" end
				draw.SimpleText("#jcms.bestiaryhealth", "jcms_small_bolder", x + w + 60, 128, jcms.color_bright, TEXT_ALIGN_CENTER)
				draw.SimpleText(str1, font1, x + w + 60, 128 + 12, jcms.color_bright, TEXT_ALIGN_CENTER)

				local str2 = jcms.util_CashFormat(entry.bounty) .. " J"
				local font2 = "jcms_hud_small"
				surface.SetFont(font2)
				local tw2 = surface.GetTextSize(str2)
				if tw2 > 72 then font2 = "jcms_medium" end
				draw.SimpleText("#jcms.bestiarybounty", "jcms_small_bolder", x + w + 60, 128 + 72, jcms.color_bright, TEXT_ALIGN_CENTER)
				draw.SimpleText(str2, font2, x + w + 60, 128 + 72 + 12, jcms.color_bright, TEXT_ALIGN_CENTER)
			end
		end

		function jcms.offgame_paint_BestiaryDescription(p, w, h)
			local lowres = p.lowres

			if p.jText and not p.markup then
				local col = jcms.color_bright
				p.markup = markup.Parse(("<color=%d, %d, %d><font="..(lowres and "DefaultSmall" or "jcms_small_bolder")..">\t"):format(col:Unpack()) .. p.jText, w - 64)
			end

			if p.name then
				surface.SetDrawColor(jcms.color_bright)
				drawFilledPolyButton(10, 0, w - 64, 24)
				draw.SimpleText(p.name, "jcms_medium", 24, 0, jcms.color_dark)
			end

			if p.markup then
				p.markup:Draw(16, 42)
				
				local height = p.markup:GetHeight()
				surface.SetDrawColor(jcms.color_pulsing)
				jcms.hud_DrawStripedRect(0, 8, 4, height + 42, 32, CurTime() % 1 * 8)

				surface.DrawRect(10, height + 58, w - 64, 1)
			end
		end

		function jcms.offgame_paint_CodexButton(p, w, h)
			local unlocked = p:IsEnabled()
			local hovered = p:IsHovered()
			local col = (unlocked and hovered) and jcms.color_bright_alt or jcms.color_bright
			if not unlocked then
				col = ColorAlpha(col, 60)
			end

			surface.SetDrawColor(col)
			if unlocked and hovered then
				jcms.hud_DrawNoiseRect(0, 0, w, h - 4)
			end

			surface.DrawRect(0, h-1, w, 1)

			draw.SimpleText("#"..p.index, "jcms_small_bolder", h/2, h/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(p.cdx.name, "jcms_medium", h*3/2, h/2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if not unlocked then
				draw.SimpleText(language.GetPhrase("jcms.unlocklvl"):format(p.level), "jcms_small_bolder", w - h, h/2, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

				if not p.lock then
					p.lock = p:Add("DImage")
					p.lock:SetPos(w-8-16, 8)
					p.lock:SetSize(16, 16)
					p.lock:SetImage("jcms/lock.png")
				end
				p.lock:SetImageColor(col)
			end

			return true
		end
	-- }}}

	-- Post-mission {{{
		function jcms.offgame_paint_PostMission(p, w, h)
			local lowres = p.lowres
			p.time = (p.time or 0) + FrameTime()
			p.allowSceneRender = p.time <= 3.5
			
			local victory = p.victory
			local lerpingIn = math.ease.OutQuart(math.Clamp(math.TimeFraction(3.5, 4.5, p.time), 0, 1))
			
			if IsValid(p.stats) then
				p.stats.Paint = jcms.offgame_paint_PostMissionStats
				p.stats:SetSize(720, 320)
				p.stats:SetPos(w/2 - p.stats:GetWide()/2 - 16, Lerp(lerpingIn, h+4, h/2 - p.stats:GetTall()))
				p.stats.victory = victory
			end
			
			if IsValid(p.vote) then
				p.vote.Paint = jcms.offgame_paint_PostMissionVote
				p.vote:SetSize(720, 256)
				p.vote:SetPos(w/2 - p.vote:GetWide()/2 + 16, Lerp(lerpingIn, h+4, h/2 + 8))
				p.vote.victory = victory
			end
			
			if jcms.locPly:Team() == 2 then
				-- NPC end screen
				local str
				if jcms.util_IsPVP() then
					str = language.GetPhrase(victory and "jcms.missionvictory_pvp" or "jcms.missiondefeat_pvp")
				else
					str = language.GetPhrase(victory and "jcms.missionvictory_npc" or "jcms.missiondefeat_npc")
				end

				local noiseAlpha = 0

				local color1 = jcms.color_bright
				local color1dark = jcms.color_dark
				local color2 = jcms.color_bright_alt
				
				if victory then
					color2, color1 = color1, color2
					color1dark = jcms.color_dark_alt
				end

				local r,g,b = color1:Unpack()
				local r2,g2,b2 = color2:Unpack()

				if p.time < 3.5 then
					local frac = math.Clamp( math.TimeFraction(0.1, 1.2, p.time), 0, 1 )
					local y = math.ease.InOutBack(frac) * h*2/3 - h/3
					draw.SimpleText(str, "jcms_hud_small", w/2, y + 2, color1dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
						draw.SimpleText(str, "jcms_hud_small", w/2, y, color2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						local frac2 = p.time > 0.6 and math.max(0, 1-(p.time-0.6)) or 0
						surface.SetDrawColor(r2+frac2*70,g2+frac2*70,b2+frac2*70,frac2 * 200)
						jcms.hud_DrawNoiseRect(0, 0, w, h, 24)
						
						frac = math.Clamp( math.TimeFraction(0.6, 1.9, p.time), 0, 1 )
						surface.SetDrawColor(r2+frac2*50,g2+frac2*50,b2+frac2*50,120)
						surface.DrawRect(w/2 - w/2*frac, y - 24, w*frac, 1)
						surface.DrawRect(w/2 - w/2*frac, y + 24, w*frac, 1)
					render.OverrideBlend( false )

					if p.time > 0.6 and not p.didSfx then
						p.didSfx = true

						if victory then
							surface.PlaySound("buttons/blip1.wav")
							surface.PlaySound("npc/scanner/scanner_blip1.wav")
						else
							surface.PlaySound("npc/roller/remote_yes.wav")
							surface.PlaySound("npc/scanner/cbot_servochatter.wav")
						end
					end

					noiseAlpha = math.Remap(p.time, 1.9, 2.35, 0, 255)
				else
					local bottomline
					if jcms.util_IsPVP() then
						bottomline = victory and "#jcms.bottomline_victory_pvp" or "#jcms.bottomline_defeat_pvp"
					else
						bottomline = victory and "#jcms.bottomline_victory_npc" or "#jcms.bottomline_defeat_npc"
					end

					noiseAlpha = math.Remap(p.time, 3.5, 4, 255, 0)

					surface.SetDrawColor(color1dark)
					surface.DrawRect(-2, -2, w+4, h+4)
					
					local f = math.min(p.time-3.5, 1)
					surface.SetAlphaMultiplier(f)
					local tw, th = draw.SimpleText(str, "jcms_big", w/2, 32, color1, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					surface.SetDrawColor(color1)
					jcms.hud_DrawStripedRect(32, 32-th/2+8, w/2-tw/2-64, 16, 24)
					jcms.hud_DrawStripedRect(w/2+tw/2+32, 32-th/2+8, w/2-tw/2-64, 16, 24)
					
					surface.SetAlphaMultiplier(f*0.3)
					draw.SimpleText(bottomline, lowres and "DefaultSmall" or "jcms_small", w/2, h-16, color1, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
					
					surface.SetAlphaMultiplier(1)
					drawScanlines(w,h,r2,g2,b2)
				end

				surface.SetDrawColor(r,g,b,noiseAlpha)
				jcms.hud_DrawNoiseRect(0, 0, w, h, 24)
			else
				local bottomline 
				if jcms.util_IsPVP() then
					bottomline = victory and "#jcms.bottomline_victory_pvp" or "#jcms.bottomline_defeat_pvp"
				else
					bottomline = victory and "#jcms.bottomline_victory" or "#jcms.bottomline_defeat"
				end

				-- Sweeper end screen
				if victory then
					local str = language.GetPhrase("jcms.missionvictory" .. (jcms.util_IsPVP() and "_pvp" or ""))
					local r,g,b = jcms.color_dark_alt:Unpack()
					local r2,g2,b2 = jcms.color_bright_alt:Unpack()
					local color_faded = ColorAlpha(jcms.color_bright, 100)
					
					if p.time < 3.5 then
						local f = math.ease.InOutQuart(math.Clamp(p.time, 0, 1))
						
						if p.time > 1.8 then
							if not p.didSfx then
								p.didSfx = true
								surface.PlaySound("npc/scanner/cbot_servochatter.wav")
							end
							
							render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
							local ff = math.ease.InOutQuart( math.min(1, math.TimeFraction(1.8, 2.5, p.time)) )
							surface.SetDrawColor(r2,g2,b2, 120)
							surface.DrawRect(0, 0, w*ff, h)
							render.OverrideBlend( false )
						end
						local substr = utf8.sub(str, 1, math.floor(Lerp(f, 0, #str+1)))
						
						local barh = 64
						surface.SetDrawColor(r,g,b,f*230)
						surface.DrawRect(0, h/2-barh/2, w, barh)
						draw.SimpleTextOutlined(substr, "jcms_hud_medium", w/2, h/2, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, jcms.color_dark)
						
						render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
						for i=1, 3 do
							local lf = math.Clamp(1 - math.abs(2*math.TimeFraction(0.4+i/3, 0.9+i/3, p.time)-1), 0, 1)
							local col = Color(r2,g2,b2,255*lf)
							local span = 64 + i*72
							draw.SimpleTextOutlined("★", "jcms_hud_medium", w-span, h/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, jcms.color_dark)
							draw.SimpleTextOutlined("★", "jcms_hud_medium", span, h/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, jcms.color_dark)
						end
						render.OverrideBlend( false )
					else
						local f = math.min(p.time-3.5, 1)
						surface.SetDrawColor(r2,g2,b2,32*f)
						jcms.hud_DrawNoiseRect(-2, -2, w+4, h+4, 1024)
						
						surface.SetAlphaMultiplier(f)
						local tw, th = draw.SimpleText(str, "jcms_big", w/2, 32, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						surface.SetDrawColor(jcms.color_bright_alt)
						jcms.hud_DrawStripedRect(32, 32-th/2+8, w/2-tw/2-64, 16, 24)
						jcms.hud_DrawStripedRect(w/2+tw/2+32, 32-th/2+8, w/2-tw/2-64, 16, 24)
						
						surface.SetAlphaMultiplier(f*0.3)
						draw.SimpleText(bottomline, lowres and "DefaultSmall" or "jcms_small", w/2, h-16, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
						
						surface.SetAlphaMultiplier(1)
						drawScanlines(w,h,r2,g2,b2)
					end

					if p.time > 2.5 then
						local alpha = math.max(1 - math.Clamp(p.time - 3.5, 0, 1))
						if alpha > 0 then
							ff = math.ease.InOutQuart( math.min(1, math.TimeFraction(2.5, 3.2, p.time)) )
							surface.SetDrawColor(r,g,b,255*alpha)
							surface.DrawRect(w-w*ff, 0, w*ff+1, h)
						end
					end
				else
					local str = language.GetPhrase("jcms.missiondefeat" .. (jcms.util_IsPVP() and "_pvp" or ""))
					local r,g,b = jcms.color_dark:Unpack()
					local r2,g2,b2 = jcms.color_bright:Unpack()
					local color_faded = ColorAlpha(jcms.color_bright, 100)
					
					if p.time < 3.5 then
						local f = math.ease.InOutQuart(math.Clamp(p.time, 0, 1))
						local substr = utf8.sub(str, 1, math.floor(Lerp(f, 0, #str+1)))
						
						local barh = 64
						surface.SetDrawColor(r,g,b,f*230)
						surface.DrawRect(0, h/2-barh/2, w, barh)
						draw.SimpleTextOutlined(substr, "jcms_hud_medium", w/2, h/2, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, jcms.color_dark)
						
						render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
						local linesf = math.ease.InOutQuart(math.Clamp(math.TimeFraction(0.76, 2.48, p.time), 0, 1))
						if linesf > 0 and linesf < 1 then
							local linew = w/4
							surface.SetDrawColor(r2,g2,b2)
							surface.DrawRect(Lerp(linesf, -linew, w), h/2-barh/2, linew, 1)
							surface.DrawRect(Lerp(linesf, w, -linew), h/2+barh/2, linew, 1)
						end
						render.OverrideBlend( false )

						surface.SetDrawColor(r2,g2,b2,math.Remap(p.time, 2, 2.35, 0, 255))
						jcms.hud_DrawNoiseRect(0, 0, w, h, 24)
						
						render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
						if (p.time > 1.8 and p.time < 2.4) or (p.time > 2.6 and p.time < 2.9) then
							surface.SetDrawColor(color_faded)
							surface.DrawRect(w*0.7, 0, 1, h)
							surface.DrawRect(w*0.7+32, 0, 1, h)
		
							surface.DrawRect(0, h*0.8, w, 1)
							surface.DrawRect(0, h*0.8+32, w, 1)
							
							if not p.didSfx then
								p.didSfx = true
								surface.PlaySound("npc/scanner/scanner_blip1.wav")
							end
						end
						
						if p.time < 3.4 then
							local matrix = Matrix()
							matrix:Scale(Vector(1.25,1.25,0))
							matrix:Translate(Vector(0, p.time*32, 0))
							cam.PushModelMatrix(matrix, true)
							for i=1, 7 do
								local t = "#jcms.ominoustext"..i
								if (p.time-1.2) < i/#t/2 then break end
								draw.SimpleText(t, i==1 and "jcms_small_bolder" or "jcms_small", w*0.12, h*0.12+i*18, jcms.color_bright)
							end
							cam.PopModelMatrix()
						end
							
						render.OverrideBlend( false )
					else
						local f = math.min(p.time-3.5, 1)
						surface.SetDrawColor(r2,g2,b2,math.random(32, 48)*f)
						jcms.hud_DrawNoiseRect(-2, -2, w+4, h+4, 1024)
						
						surface.SetAlphaMultiplier(f)
						local tw, th = draw.SimpleText(str, "jcms_big", w/2, 32, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						surface.SetDrawColor(jcms.color_bright)
						
						local func = math.random() < 0.03 and jcms.hud_DrawStripedRect or jcms.hud_DrawNoiseRect
						func(32, 32-th/2+8, w/2-tw/2-64, 16, 24)
						func = math.random() < 0.08 and jcms.hud_DrawStripedRect or jcms.hud_DrawNoiseRect
						func(w/2+tw/2+32, 32-th/2+8, w/2-tw/2-64, 16, 24)
						
						surface.SetAlphaMultiplier(f*0.3)
						draw.SimpleText(bottomline, lowres and "DefaultSmall" or "jcms_small", w/2, h-16, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
						surface.SetAlphaMultiplier(1)
						drawScanlines(w,h,r2,g2,b2)

						f = (1 - math.min( (p.time-3.5)*3, 1))
						if f > 0 then
							surface.SetDrawColor(r2, g2, b2, 255*f)
							jcms.hud_DrawNoiseRect(-2, -2, w+4, h+4)
						end
					end
				end
			end
			
			local missionType = jcms.util_GetMissionType()
			local missionData = jcms.missions[ missionType ]
			
			if missionData and p.time > 3.5 then
				if missionData.basename then missionType = missionData.basename end
				surface.SetAlphaMultiplier(math.min(1, p.time - 4)*0.4)
				draw.SimpleText(("%s @ %s"):format(language.GetPhrase("jcms."..missionType), game.GetMap()), "jcms_small", w/2, 48, victory and jcms.color_bright_alt or jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				surface.SetAlphaMultiplier(1)
				
				if not p.didSfx2 then
					surface.PlaySound("buttons/combine_button5.wav")
					p.didSfx2 = true
				end
			end
		end

		function jcms.offgame_paint_Header(p, w, h)
			local lowres = p.lowres
			local col = p.victory and jcms.color_bright_alt or jcms.color_bright
			local colPulsing = ColorAlpha(col, jcms.color_pulsing.a)

			local missiontime = p.missiontime
			local time = string.FormattedTime(missiontime)
			local formatted = string.format("%02i:%02i:%02i", time.h, time.m, time.s)
			draw.SimpleText(formatted, lowres and "jcms_medium" or "jcms_big", lowres and w-8 or w-32, lowres and 52 or 64, col, TEXT_ALIGN_RIGHT, nil)

			surface.SetDrawColor(colPulsing)
			drawHollowPolyButton(0, 50, w, h-50)

			local av = p.av
			if IsValid(av) then
				surface.SetDrawColor(col)
				drawFilledPolyButton(av:GetX()-1, av:GetY()-1, av:GetWide()+2, av:GetTall()+2)
			end

			if p.stats then
				draw.SimpleText(p.stats.nickname, lowres and "jcms_medium" or "jcms_big", lowres and 54 or 96, lowres and 52 or 64, col)
				
				local globalX = lowres and 8 or 22
				local iconSize = lowres and 24 or 64
				if p.stats.wasSweeper then
					if IsValid( p.stats.ply ) then
						local tgclass = p.stats.class or p.stats.ply:GetNWString("jcms_class", "infantry")
						local classmat = jcms.mat_GetClassMat(tgclass)
		
						if classmat and not classmat:IsError() then
							surface.SetMaterial(classmat)
							surface.SetDrawColor(col)
							surface.DrawTexturedRect(globalX + 4, lowres and 84 or 114, iconSize, iconSize)
						end
					end

					surface.SetDrawColor(colPulsing)
					if p.stats.wasNPC and not lowres then
						drawHollowPolyButton(globalX, 110, 340, 72)
					end
					local x, y = globalX + (lowres and 24 or 64) + 8, lowres and 75 or 114
					local font = lowres and "DefaultSmall" or "jcms_small"
					local spacing = lowres and 10 or 16
					draw.SimpleText(("%s: %d"):format(language.GetPhrase("#jcms.stats_deaths"), p.stats.deaths_sweeper or 0), font, x, y + spacing, col)
					draw.SimpleText(("%s: %d"):format(language.GetPhrase("#jcms.stats_orders"), p.stats.ordersUsedCounts or 0), font, x, y + spacing*2, col)
					x = x + (lowres and 96 or 132)
					surface.DrawRect(x - 12, y + 4, 1, (lowres and 46 or 64) - 8)
					local totalKills = p.stats.kills_direct + p.stats.kills_defenses + p.stats.kills_explosions
					if p.stats.pvpTeam > 0 then totalKills = p.stats.kills_pvp end
					draw.SimpleText(("%s: %s"):format(language.GetPhrase("#jcms.stats_kills"), jcms.util_CashFormat(totalKills)), font, x, y, col)
					draw.SimpleText(("%s: %s"):format(language.GetPhrase("#jcms.stats_kills_direct"), jcms.util_CashFormat(p.stats.kills_direct)), font, x + 4, y + spacing, colPulsing)
					draw.SimpleText(("%s: %s"):format(language.GetPhrase("#jcms.stats_kills_defenses"), jcms.util_CashFormat(p.stats.kills_defenses)), font, x + 4, y + spacing*2, colPulsing)
					draw.SimpleText(("%s: %s"):format(language.GetPhrase("#jcms.stats_kills_explosions"), jcms.util_CashFormat(p.stats.kills_explosions)), font, x + 4, y + spacing*3, colPulsing)
					globalX = globalX + (lowres and 200 or 340) + 8
				end
				
				if p.stats.wasNPC then
					surface.SetDrawColor(colPulsing)
					if p.stats.wasSweeper and not lowres then
						drawHollowPolyButton(globalX, 110, 304, 72)
					end
					local x, y = globalX + (lowres and 24 or 64) + 8, lowres and 75 or 114

					if not p.factionMat then
						p.factionMat = Material("jcms/factions/" .. jcms.util_GetMissionFaction() .. ".png")
					end

					if p.factionMat and not p.factionMat:IsError() then
						surface.SetMaterial(p.factionMat)
						surface.SetDrawColor(col)
						surface.DrawTexturedRect(globalX + 4, lowres and 84 or 114, iconSize, iconSize)
						local font = lowres and "DefaultSmall" or "jcms_small"
						local spacing = lowres and 10 or 16
						draw.SimpleText(("%s: %d"):format(language.GetPhrase("#jcms.stats_deaths"), p.stats.deaths_npc or 0), font, x, y + spacing*2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						
						x = x + (lowres and 68 or 86)
						surface.DrawRect(x - 12, y + 4, 1, (lowres and 46 or 64) - 8)
						draw.SimpleText(("%s: %d"):format(language.GetPhrase("#jcms.stats_kills_sweepers"), p.stats.kills_sweepers or 0), font, x, y + spacing*0.5, col)
						draw.SimpleText(("%s: %d"):format(language.GetPhrase("#jcms.stats_kills_turrets"), p.stats.kills_turrets or 0), font, x, y + spacing*2.5, col)
					end
				end
			end
		end
		
		function jcms.offgame_paint_LvlUp(p, w, h)
			local lowres = p.lowres
			
			p.time = (p.time or 0) + FrameTime()
			p.colorAnim = (p.colorAnim or 0) * 0.95

			local col = p.victory and jcms.color_bright_alt or jcms.color_bright
			local colAlt = p.victory and jcms.color_alert or jcms.color_bright_alt
			
			local alpha = math.Clamp(p.time - p.showDelay, 0, 1)
			if alpha > 0 then
				surface.SetAlphaMultiplier(alpha)
				local values = p.values
				local frac = math.EaseInOut( math.Clamp((p.time - p.showDelay - 0.25)*0.6, 0, 1), 0.2, 0.5 )

				if values then
					local color = p.colorAnim > 0.32 and colAlt or col

					if not p.lastDisplayedLevel then
						p.lastDisplayedLevel = values.oldLevel
						surface.PlaySound("buttons/lever4.wav")
					end

					local totalExp = Lerp(frac, values.oldExp, values.newExp)
					for level=values.oldLevel + 1, values.newLevel do
						totalExp = totalExp + jcms.statistics_GetEXPForNextLevel(level)
					end

					local animatedExp = math.ceil(totalExp * frac)
					local animatedLevel = values.oldLevel
					local forNextLevel = jcms.statistics_GetEXPForNextLevel(animatedLevel + 1)

					while (animatedExp >= forNextLevel and animatedExp > 0) do
						animatedExp = animatedExp - forNextLevel
						animatedLevel = animatedLevel + 1
						forNextLevel = jcms.statistics_GetEXPForNextLevel(animatedLevel + 1)
					end

					if animatedLevel ~= p.lastDisplayedLevel then
						p.lastDisplayedLevel = animatedLevel
						p.colorAnim = animatedLevel == values.newLevel and 1 or 0.6
						surface.PlaySound("buttons/lever8.wav")
					end

					local levelPlateWidth = h*2
					surface.SetDrawColor(color)
					drawFilledPolyButton(0, 0, levelPlateWidth, h, 8)
					draw.SimpleText(animatedLevel, lowres and "jcms_small_bolder" or "jcms_medium", h, h/2, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					drawFilledPolyButton(levelPlateWidth + 8, h*2/3, (w-levelPlateWidth-8) * (animatedExp / forNextLevel), h/3, 4)
					drawHollowPolyButton(levelPlateWidth + 8, h*2/3, w-levelPlateWidth-8, h/3, 4)
					draw.SimpleText( ("%s / %s EXP"):format(jcms.util_CashFormat(animatedExp), jcms.util_CashFormat(forNextLevel)), lowres and "DefaultSmall" or "jcms_small_bolder", levelPlateWidth + 16, h*2/3 - 6, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
					draw.SimpleText( ("LVL %d ➞ %d"):format(values.oldLevel, values.newLevel), lowres and "DefaultSmall" or "jcms_small", w - 16, h*2/3 - 6, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
				
					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
						DisableClipping(true)
						local pad = p.colorAnim^2 * 32
						surface.SetAlphaMultiplier(p.colorAnim)
						surface.SetDrawColor(color)
						jcms.hud_DrawNoiseRect(-pad, -pad, w+pad*2, h+pad*2, 64)
						surface.SetAlphaMultiplier(1)
						DisableClipping(false)
					render.OverrideBlend( false )
				end
			end
		end

		function jcms.offgame_paint_WinStreakAndCash(p, w, h)
			local lowres = p.lowres
			local col = p.victory and jcms.color_bright_alt or jcms.color_bright
			local colAlt = p.victory and jcms.color_bright or jcms.color_bright_alt
			local colPulsing = ColorAlpha(col, jcms.color_pulsing.a)

			p.time = (p.time or 0) + FrameTime()
			local alpha = math.Clamp(p.time - p.showDelay, 0, 1)

			if not p.didFadeSound then
				p.didFadeSound = true
				EmitSound("friends/friend_join.wav", EyePos(), -2, CHAN_AUTO, 1, 75, 0, 60)
			end

			local winstreakWidth = lowres and 100 or 172
			if alpha > 0 and not jcms.util_IsPVP() then
				surface.SetAlphaMultiplier(alpha)
				surface.SetDrawColor(colPulsing)
				drawHollowPolyButton(-1, 0, w+2, h, 16)
				local plaqueWidth = lowres and 100 or 150
				local plaqueFontOutside = lowres and "DefaultSmall" or "jcms_small_bolder"
				local plaqueFontInside = lowres and "jcms_small_bolder" or "jcms_medium"

				-- Cash {{{
				local stages = jcms.aftergame_bonuses
				if stages and #stages > 0 then
					local startingCash = jcms.aftergame_bonuses.oldCash or 0
					local endingCash = jcms.aftergame_bonuses.newCash or 0
					draw.SimpleText("#jcms.cashhud_old", plaqueFontOutside, winstreakWidth + 24 + plaqueWidth/2, 12, colPulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

					surface.SetDrawColor(col)
					drawHollowPolyButton(winstreakWidth + 24, 32, plaqueWidth, 24)
					draw.SimpleText(jcms.util_CashFormat(startingCash) .. " J", plaqueFontInside, winstreakWidth + 24 + plaqueWidth/2, 32 + 24/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					surface.SetDrawColor(colPulsing)

					local x1, x2 = winstreakWidth + 24 + 32, w - 24 - 32
					surface.DrawRect(x1, 32 + 24 + 4, 1, 12)
					for i, stage in ipairs(stages) do
						local stageAlpha = math.Clamp((p.time - p.showDelay - i*0.3)*2, 0, 1)
						surface.SetAlphaMultiplier(stageAlpha)
						
						surface.SetDrawColor(colPulsing)
						local x = Lerp(i/(#stages+1), x1, x2)
						local x_prev = Lerp((i-1)/(#stages+1), x1, x2)
						surface.DrawRect(x_prev + 12, 32 + 40, x - x_prev - 24, 1)
						if i == #stages then
							surface.DrawRect(x_prev + (x - x_prev + 12), 32 + 40, x - x_prev - 24 + 1, 1)
						end
						
						local str = language.GetPhrase("jcms.reward_" .. stage.name):format(stage.format)
						if lowres then
							draw.SimpleText(str, "DefaultVerySmall", x, 32 + 44, colPulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
							draw.SimpleText(("%s%s J"):format(stage.cash>=0 and "+" or "", jcms.util_CashFormat(stage.cash)), "DefaultSmall", x, 32 + 44 + 10, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
						else
							draw.SimpleText(str, "jcms_small", x, 32 + 40 + 12, colPulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
							draw.SimpleText(("%s%s J"):format(stage.cash>=0 and "+" or "", jcms.util_CashFormat(stage.cash)), "jcms_medium", x, 32 + 40 + 24, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
						end
						surface.SetDrawColor(col)
						jcms.draw_Circle(x, 32 + 40, 4, 4, 4, 12)

						if stageAlpha > 0.03 and (not p.lastStageSound or p.lastStageSound < i) then
							p.lastStageSound = i
							surface.PlaySound("ui/buttonclick.wav")
						end

						if i == #stages then
							local stageAlpha = math.Clamp((p.time - p.showDelay - i*0.3 - 0.3)*2, 0, 1)
							surface.SetAlphaMultiplier(stageAlpha)
							surface.SetDrawColor(colAlt)
							drawFilledPolyButton(w - plaqueWidth - 24, 32, plaqueWidth, 24)
							draw.SimpleText(jcms.util_CashFormat(endingCash) .. " J", plaqueFontInside, w - 24 - plaqueWidth/2, 32 + 24/2, jcms.color_dark_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
							surface.SetDrawColor(colPulsing)
							surface.DrawRect(x2, 32 + 24 + 4, 1, 12)
							draw.SimpleText("#jcms.cashhud_new", plaqueFontOutside, w - 24 - plaqueWidth/2, 12, colAlt, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
						end
					end
				else
					draw.SimpleText("#jcms.cashhud_none", lowres and "jcms_medium" or "jcms_big", (w - winstreakWidth)/2 + winstreakWidth, h/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
				surface.SetAlphaMultiplier(1)
			end
			-- }}}

			-- Winstreak {{{
			if jcms.aftergame then
				if jcms.util_IsPVP() then
					local nukes = jcms.aftergame.nukes or 0
					local nukesAnim = math.Clamp(p.time - (stages and #stages or 1)*0.3 - 1.4, 0, 1)

					surface.SetAlphaMultiplier(nukesAnim)
					local font = lowres and "jcms_medium" or "jcms_hud_small"
					draw.SimpleText(language.GetPhrase("jcms.pvpnukecount"):format(nukes), font, w/2, h/2 + 8 - 16*nukesAnim, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				else
					local winstreak = jcms.aftergame.winstreak or 0
					local winstreakFailed = not jcms.aftergame.victory
					local winstreakAnim = math.Clamp(p.time - (stages and #stages or 1)*0.3 - 1.4, 0, 1)

					if winstreakAnim > 0 then
						surface.SetAlphaMultiplier(winstreakAnim)
						local font1 = lowres and "jcms_hud_medium" or "jcms_hud_big"
						local font2 = lowres and "jcms_hud_small" or "jcms_hud_medium"

						if winstreak >= 100 then
							font1 = "jcms_hud_medium"
							font2 = "jcms_hud_small"
						end

						local col = winstreak > 0 and colAlt or col
						surface.SetDrawColor(col.r, col.g, col.b, jcms.color_pulsing.a)
						drawHollowPolyButton(6, 6, winstreakWidth, h - 12, 12)
						draw.SimpleText("#jcms.winstreak_title", lowres and "DefaultSmall" or "jcms_medium", 6 + winstreakWidth/2, 12, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

						local nx, ny = 6 + winstreakWidth/2, h * 0.6
						surface.SetFont(font1)
						local n_width = surface.GetTextSize(winstreak)
						surface.SetFont(font2)
						local x_width = surface.GetTextSize("x")

						draw.SimpleText(winstreak, font1, nx + x_width/2, ny, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						draw.SimpleText("x", font2, nx - n_width/2, ny, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

						if winstreakFailed and winstreak > 0 then
							draw.NoTexture()
							surface.SetDrawColor(col)
							local barLength = lowres and 90 or 150
							local barWidth = lowres and 2 or 4
							surface.DrawTexturedRectRotated(nx, ny, barLength, barWidth, 30)
							surface.DrawTexturedRectRotated(nx, ny, barLength, barWidth, -30)
						end
					end
					surface.SetAlphaMultiplier(1)
				end
			end
			-- }}}
		end

		function jcms.offgame_paint_Voting(p, w, h)
			local oldState = DisableClipping(true)
			local colBg = p.victory and jcms.color_dark_alt or jcms.color_dark
			local col = p.victory and jcms.color_bright_alt or jcms.color_bright
			local colAlt = p.victory and jcms.color_bright or jcms.color_bright_alt
			local colPulsing = ColorAlpha(col, jcms.color_pulsing.a)

			surface.SetDrawColor(colPulsing)
			drawHollowPolyButton(0, 0, w, h)
			
			local bx, by, bw, bh = 16, 64, w - 32, h - 64 - 16
			local scrx1, scry1 = p:LocalToScreen(bx, by)
			local scrx2, scry2 = p:LocalToScreen(bx + bw, by + bh)
			local cellSize = 64
			local sway = (CurTime() / 30 % 1)
			local swayX = math.cos(sway * math.pi * 2) * cellSize*2/3
			local swayY = math.sin(sway * math.pi * 2) * cellSize*2/3

			draw.SimpleText(game.SinglePlayer() and "#jcms.mapvote_solo" or "#jcms.mapvote_mp", "jcms_big", 32, by/2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			if not game.SinglePlayer() then
				local timeRemains = math.max(0, (jcms.aftergame.voteTime or 0) - CurTime())
				local colTimer = timeRemains <= 10 and jcms.color_alert or col
				draw.SimpleText(string.FormattedTime(timeRemains, "%02i:%02i"), "jcms_big", w - 32, by/2, colTimer, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
			
			render.SetScissorRect( scrx1, scry1, scrx2, scry2, true )
				surface.SetDrawColor(colBg)
				drawFilledPolyButton(bx, by, bw, bh)

				surface.SetAlphaMultiplier(0.23)
				surface.SetDrawColor(colPulsing)
				local offX, offY = gui.MouseX() / ScrW() * 32 + 64, gui.MouseY() / ScrH() * 32 + 64
				for i=1, math.ceil(math.max(bw, bh) / cellSize) + 1 do
					surface.DrawRect(bx + i*64 + swayX - offX, by + swayY - offY, 1, bh*2)
					surface.DrawRect(bx + swayX - offX, by + i*64 + swayY - offY, bw*2, 1)
				end
				surface.SetAlphaMultiplier(1)
			render.SetScissorRect( 0, 0, 0, 0, false)

			surface.SetDrawColor(col)
			drawHollowPolyButton(bx, by, bw, bh)
			DisableClipping(oldState)
		end

		function jcms.offgame_paint_Leaderboard(p, w, h)
			local lowres = p.lowres

			local col = p.victory and jcms.color_bright_alt or jcms.color_bright
			local colAlt = p.victory and jcms.color_bright or jcms.color_bright_alt
			local colBg = p.victory and jcms.color_dark_alt or jcms.color_dark

			surface.SetDrawColor(col)
			drawHollowPolyButton(0, 0, w, h)

			surface.SetAlphaMultiplier(0.03)
				surface.SetDrawColor(col)
				drawFilledPolyButton(0, 0, w, lowres and 24 or 42)

				if p.separatorsThick then
					for i, sep in ipairs(p.separatorsThick) do
						surface.DrawRect(sep, 8, 2, h - 16)
					end
				end

				if p.separators then
					for i, sep in ipairs(p.separators) do
						surface.DrawRect(sep, 12, 1, h - 24)
					end
				end
			surface.SetAlphaMultiplier(1)

			if IsValid(p.scrollArea) then
				if IsValid(p.scrollArea.VBar) then
					p.scrollArea.VBar.Paint = BLANK_DRAW
					p.scrollArea.VBar:SetHideButtons(true)
					p.scrollArea.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
					p.scrollArea.VBar.btnGrip.colorMain = col
					p.scrollArea.VBar.btnGrip.colorHover = colAlt
					for i, child in ipairs(p.scrollArea.VBar:GetChildren()) do
						if child ~= p.scrollArea.VBar.btnGrip then
							child:SetVisible(false)
						end
					end
				end
			end
		end
	-- }}}

	-- Error {{{

		function jcms.offgame_paint_ErrorFrame(p, w, h)
			local lowres = not true or jcms.util_IsLowRes()

			surface.SetAlphaMultiplier(0.2)
			surface.SetDrawColor(jcms.color_bright)
			jcms.hud_DrawNoiseRect(0, 0, w, h, w)
			surface.SetAlphaMultiplier(1)

			local basey = lowres and h*0.3 or h*0.24
			
			local str1 = language.GetPhrase("jcms.nnv_title")
			local str2 = game.GetMap()
			local str3 = language.GetPhrase("jcms.nnv_desc")

			local tw, th = draw.SimpleText(str1, lowres and "jcms_hud_small" or "jcms_hud_medium", w/2, basey, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(str2, lowres and "jcms_medium" or "jcms_big", w/2, basey - th/2 - 16, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local y0 = basey + th/2
			local y1 = basey + th
			tw, th = draw.SimpleText(str3, lowres and "jcms_medium" or "jcms_hud_small", w/2, y1, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			local y2 = y1 + th + (lowres and 24 or 48)

			p.variants = p.variants or {
				{ language.GetPhrase("jcms.nnv_a_title"), language.GetPhrase("jcms.nnv_a_desc") },
				{ language.GetPhrase("jcms.nnv_b_title"), language.GetPhrase("jcms.nnv_b_desc"):format(str2) },
				{ language.GetPhrase("jcms.nnv_c_title"), language.GetPhrase("jcms.nnv_c_desc") }
			}
			
			local vw = lowres and 300 or 500
			local pad = lowres and 10 or 32
			for i,var in ipairs(p.variants) do
				local vx = w/2 - #p.variants/2*(vw+8) + (vw+8)*(i-0.5)
				local vtw, vth = draw.SimpleText(var[1], lowres and "jcms_medium" or "jcms_hud_small", vx, y2, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				jcms.hud_DrawHollowPolyButton(vx-vw/2, y2 - 8, vw, lowres and 300 or 400)

				if not var.mup then
					var.mup = markup.Parse(("<color=%d,%d,%d><font=%s>%s</font></color>"):format(jcms.color_bright.r, jcms.color_bright.g, jcms.color_bright.b, lowres and "jcms_small" or "jcms_medium", var[2]), vw - pad*2)
				end

				var.mup:Draw(vx - vw/2 + pad, y2 + vth + 8, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 100)
			end

			surface.SetAlphaMultiplier(0.1)
			surface.SetDrawColor(jcms.color_pulsing)
			surface.DrawRect(w*0.25, y0, w*0.5, 1)
			surface.DrawRect(w*0.3, y0 + 4, w*0.4, 1)
			surface.DrawCircle(w*0.8, h*0.8, Lerp(math.abs(math.sin(CurTime())), h/2, h))
			surface.DrawCircle(w*0.8, h*0.8, Lerp(math.abs(math.sin(CurTime()+2)), h*0.4, h*0.8))
			surface.SetAlphaMultiplier(1)
		end

	-- }}}
	
-- // }}}
