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

-- Locals {{{

	local BLANK_DRAW = function() return true end
	
-- }}}

jcms.offgame = jcms.offgame or NULL

-- // Panels {{{

	local function makeBasePanel(paintfunc)
		if IsValid(jcms.offgame) then
			for k,v in pairs(jcms.offgame:GetChildren()) do
				v:Remove()
			end

			jcms.offgame.Paint = paintfunc
			
			return jcms.offgame
		else
			local pnl = vgui.Create("EditablePanel", GetHUDPanel())
			jcms.offgame = pnl
			
			pnl:SetSize(ScrW(), ScrH())
			pnl:Center()
			pnl:MakePopup()
			pnl.Paint = paintfunc
			
			return pnl
		end
	end

	function jcms.offgame_CreateChatAsChild(parentPanel, x, y, w, h)
		parentPanel.chatPanel = parentPanel:Add("DPanel")
		parentPanel.chatPanel:SetSize(w, h - 24 - 4)
		parentPanel.chatPanel:SetPos(x, y)
		parentPanel.chatPanel.Paint = jcms.offgame_paint_ChatPanel
		parentPanel.chatPanel.scrollArea = parentPanel.chatPanel:Add("DScrollPanel")
		parentPanel.chatPanel.scrollArea:SetSize(parentPanel.chatPanel:GetWide() - 32, parentPanel.chatPanel:GetTall() - 24)
		parentPanel.chatPanel.scrollArea:SetPos(16, 12)
		parentPanel.chatPanel.messageElements = {}
		parentPanel.chatPanel.visibilityAnim = 0

		function parentPanel.chatPanel:Think()
			local els = self.messageElements
			local canvas = self.scrollArea:GetCanvas()
			local vbar = self.scrollArea:GetVBar()

			local isScrolledDown = IsValid(canvas) and IsValid(vbar) and vbar:GetScroll() >= canvas:GetTall() - self.scrollArea:GetTall() - 12
			local hasNewElement = false

			-- TODO Old messages arent being disposed of
			local sumY = 0
			local time = CurTime()
			for i, ri, msg in jcms.chatHistory_Iterator() do
				local el = els[ri]
				local needsNewElement = true
				if IsValid(el) then

					local isVisible = time - el.createdAt < 5 or self.visibilityAnim > 0.1
					el.visibilityAnim = ((el.visibilityAnim*3) + (isVisible and 1 or 0))/4
					if el.msg ~= msg then
						el:Remove()
					else
						needsNewElement = false
						el:SetPos(2, sumY)
						sumY = sumY + el:GetTall() + 2
					end
				end

				if needsNewElement then
					el = self.scrollArea:Add("DPanel")
					el.createdAt = time
					el.visibilityAnim = 1
					el.msg = msg
					els[ri] = el
					el.Paint = jcms.offgame_paint_ChatMessage
					el.title = tostring(msg[1])

					el.markup = markup.Parse(msg[2], self:GetWide() - 64)
					el:SetPos(2, sumY)
					el:SetSize(self:GetWide() - 4, el.markup:GetHeight() + 24)

					sumY = sumY + el:GetTall() + 2
					hasNewElement = true
				end
			end

			if hasNewElement then
				canvas:InvalidateChildren(true)
			end

			if (hasNewElement and isScrolledDown) or (self.visibilityAnim <= 0.01) then
				vbar:SetScroll(sumY)
			end

			
			local isVisible = parentPanel.chatEntry:HasFocus()
			if not isVisible then
				local mx, my = input.GetCursorPos()
				local x1, y1 = parentPanel.chatPanel:LocalToScreen(0, 0)
				local x2, y2 = parentPanel.chatPanel:LocalToScreen( parentPanel.chatPanel:GetSize() )
				
				if mx >= x1 and my >= y1 and mx <= x2 and my <= y2 then
					isVisible = true
				end
			end
			self.visibilityAnim = (self.visibilityAnim*7 + (isVisible and 1 or 0))/8
			vbar.btnGrip.visibilityAnim = self.visibilityAnim
		end

		parentPanel.chatEntry = parentPanel:Add("DTextEntry")
		parentPanel.chatEntry:SetPos(parentPanel.chatPanel:GetX(), parentPanel.chatPanel:GetY() + parentPanel.chatPanel:GetTall() + 4)
		parentPanel.chatEntry:SetSize(parentPanel.chatPanel:GetWide(), 24)
		parentPanel.chatEntry:SetCursorColor(jcms.color_bright)
		parentPanel.chatEntry:SetHighlightColor(jcms.color_bright_alt)
		parentPanel.chatEntry:SetTextColor(jcms.color_bright)
		parentPanel.chatEntry:SetPlaceholderColor(jcms.color_pulsing)
		parentPanel.chatEntry:SetPlaceholderText("Say something...")
		parentPanel.chatEntry:SetPaintBackground(false)
		parentPanel.chatEntry.PaintOver = jcms.offgame_paint_ChatEntryOver

		function parentPanel.chatEntry:OnEnter()
			RunConsoleCommand("say", self:GetText())

			self:SetText("")
			self:RequestFocus()

			local canvas = parentPanel.chatPanel.scrollArea:GetCanvas()
			local vbar = parentPanel.chatPanel.scrollArea:GetVBar()
			if IsValid(vbar) and IsValid(canvas) then
				vbar:SetScroll(canvas:GetTall())
			end
		end

		function jcms.offgame:OnKeyCodePressed(kc)
			local binding = input.LookupBinding("impulse 201") -- Chat binding
			if binding then
				local chatKeyCode = input.GetKeyCode(binding)
				if kc == chatKeyCode then
					parentPanel.chatEntry:RequestFocus()
				end
			end
		end
	end

	function jcms.offgame_CreateTextElement(parentPanel, x, y, w, h, text, cvar, ratio)
		ratio = math.Clamp(tonumber(ratio) or 0.25, 0, 1)
		local p = parentPanel:Add("DPanel")
		p:SetPos(x, y)
		p:SetSize(w, h)
		p:SetBackgroundColor( ColorAlpha(jcms.color_dark, 50) )

		if ratio == 1 then
			-- Multiline
			local label = p:Add("DLabel")
			label:SetPos(0, 0)
			label:SetSize(w, 24)
			label:SetFont("jcms_small_bolder")
			label:SetTextColor(jcms.color_bright)
			label:SetText(tostring(text))

			local entry = p:Add("DTextEntry")
			entry:SetPos(0, 24)
			entry:SetSize(w, h-24)
			entry:SetMultiline(true)
			entry:SetPaintBackground(false)
			entry.PaintOver = jcms.offgame_paint_ChatEntryOver
			
			if type(cvar) == "string" then
				entry:SetConVar(cvar)
			end

			p.label = label
			p.entry = entry
		else
			-- Single-line
			local label = p:Add("DLabel")
			label:SetPos(8, 0)
			label:SetSize(w*(1-ratio), h)
			label:SetFont("jcms_small_bolder")
			label:SetTextColor(jcms.color_bright)
			label:SetText(tostring(text))
			
			local entry = p:Add("DTextEntry")
			entry:SetPos(w*(1-ratio) - 8, 2)
			entry:SetSize(w*ratio-4, h-8)
			entry:SetPaintBackground(false)
			entry.PaintOver = jcms.offgame_paint_ChatEntryOver
			
			if type(cvar) == "string" then
				entry:SetConVar(cvar)
			end

			p.label = label
			p.entry = entry
		end

		return p
	end

	-- Lobby {{{
		function jcms.offgame_ShowPreMission()
			local pnl = makeBasePanel(jcms.offgame_paint_LobbyFrame)

			-- Primary {{{
				pnl.buttonsPrimary = { selection = 1 }
				
				local bMis = pnl:Add("DButton")
				bMis:SetText("#jcms.mission")
				bMis.BuildFunc = function(tab)
					local myDesiredTeam = LocalPlayer():GetNWInt("jcms_desiredteam", 0)
					if myDesiredTeam == 1 then
						-- Sweeper tab
						jcms.offgame_BuildMissionPrepTab(tab)
					elseif myDesiredTeam == 2 then
						-- NPC tab
						-- TODO
					else
						jcms.offgame_BuildMissionTab(tab)
					end
				end
				table.insert(pnl.buttonsPrimary, bMis)
				
				local bPersonal = pnl:Add("DButton")
				bPersonal:SetText("#jcms.mystats")
				bPersonal.BuildFunc = function(tab) 
					jcms.offgame_BuildPersonalTab(tab)
				end
				table.insert(pnl.buttonsPrimary, bPersonal)
				
				local bInfo = pnl:Add("DButton")
				bInfo:SetText("#jcms.information")
				bInfo.BuildFunc = function(tab) 
					jcms.offgame_BuildInfoTab(tab)
				end
				table.insert(pnl.buttonsPrimary, bInfo)

				local bOpts = pnl:Add("DButton")
				bOpts:SetText("#jcms.options")
				bOpts.BuildFunc = function(tab) 
					jcms.offgame_BuildOptionsTab(tab)
				end
				table.insert(pnl.buttonsPrimary, bOpts)

				pnl.tabPnl = pnl:Add("DPanel")
				pnl.tabPnl:SetPos(16, 48)
				pnl.tabPnl:SetSize(900, pnl:GetTall() - pnl.tabPnl:GetY() - 16)
				pnl.tabPnl:SetPaintBackground(false)

				local function primaryButtonClick(b)
					if pnl.buttonsPrimary.selection ~= b.listIndex then
						surface.PlaySound("buttons/button15.wav")
						pnl.buttonsPrimary.selection = b.listIndex

						for i, child in ipairs(pnl.tabPnl:GetChildren()) do
							child:Remove()
						end

						if b.BuildFunc then
							pnl.tabPnl.Paint = nil
							b.BuildFunc(pnl.tabPnl, pnl, b)
						end
					else
						surface.PlaySound("buttons/button16.wav")
					end
				end
				
				for i, btn in ipairs(pnl.buttonsPrimary) do
					btn.listIndex = i
					btn.paint = jcms.paint_Button
					btn.DoClick = primaryButtonClick
					btn:SetPos(-128, -128)
				end
			-- }}}

			-- Secondary {{{
				pnl.buttonsSecondary = {}

				local bDiscord = pnl:Add("DButton")
				bDiscord:SetText("#jcms.ourdiscord")
				bDiscord.isVanilla = true
				function bDiscord:DoClick()
					local menu = DermaMenu()
					menu:AddOption("#jcms.ourdiscord_specify", function() gui.OpenURL("https://discord.gg/m5DBJrXjUf") end)
					menu:AddOption("#jcms.ourgame", function() gui.OpenURL("https://discord.gg/ThqwGkkZPz") end)
					menu:Open()
				end
				table.insert(pnl.buttonsSecondary, bDiscord)

				local bDonate = pnl:Add("DButton")
				bDonate:SetText("#jcms.supportus")
				bDonate.isVanilla = true
				function bDonate:DoClick()
					local menu = DermaMenu()
					menu:AddOption("Boosty", function() gui.OpenURL("https://boosty.to/octantisaddons") end)
					menu:AddOption("Patreon", function() gui.OpenURL("https://www.patreon.com/octantisaddons") end)
					menu:AddOption("VK Donut", function() gui.OpenURL("https://vk.com/octantisaddons?source=description&w=donut_payment-187515083") end)
					menu:Open()
				end
				table.insert(pnl.buttonsSecondary, bDonate)
				
				for i, btn in ipairs(pnl.buttonsSecondary) do
					btn.listIndex = i
					btn.Paint = jcms.paint_ButtonSmall
					btn.jFont = "jcms_small"
					btn:SetPos(-128, -128)
				end
				
			-- }}}

			-- Players list {{{
				pnl.plyPnlSweeper = pnl:Add("DScrollPanel")
				pnl.plyPnlSweeper:SetSize(500, ScrH() * 0.25)
				pnl.plyPnlSweeper:SetPos(-1000, -1000)
				pnl.plyPnlSweeper:SetPaintBackground(false)
				pnl.plyPnlSweeper.list = {}
				pnl.plyPnlSweeper.elementDict = {}
				pnl.plyPnlSweeper.classMats = {}
				pnl.plyPnlSweeper.gunStats = {}
				for class, data in pairs(jcms.classes) do
					if data.jcorp then
						pnl.plyPnlSweeper.classMats[ class ] = Material("jcms/classes/" .. class .. ".png")
					end
				end
				function pnl.plyPnlSweeper:Think()
					local index = 0
					local mismatchDetected = false

					local fullPlyList = player.GetAll()
					for i, ply in ipairs(fullPlyList) do
						if ply:GetNWInt("jcms_desiredteam", 0) == 1 then
							index = index + 1

							if mismatchDetected then
								self.list[ index ] = ply
							elseif self.list[ index ] ~= ply then
								mismatchDetected = true
								for j=index, #fullPlyList do
									self.list[j] = nil
								end
								self.list[ index ] = ply
							end
						elseif IsValid(self.elementDict[ ply ]) then
							local elem = self.elementDict[ ply ]
							elem.player = nil
							if IsValid(elem.av) then
								elem.av:Remove()
							end
							surface.PlaySound("buttons/button6.wav")
							table.RemoveByValue(self.list, ply)
							self.elementDict[ ply ] = nil
						end
					end

					for i=#self.list, 1, -1 do
						local ply = self.list[i]

						if not IsValid(ply) then
							table.remove(self.list, i)
						else
							local elem = self.elementDict[ ply ]
							if not IsValid(elem) then
								elem = self:Add("DPanel")
								elem:SetPos(self:GetWide(), 48 * (i-1))
								elem:SetSize(self:GetWide(), 48)
								elem.Paint = jcms.paint_PlayerLobby
								elem.player = ply
								elem.classMats = self.classMats
								elem.gunStats = self.gunStats
								self.elementDict[ ply ] = elem

								local av = elem:Add("AvatarImage")
								av:SetPlayer( ply, 32 )
								av:SetSize(32, 32)
								av:SetPos(12, elem:GetTall() - 32 - 8)
								elem.av = av

								surface.PlaySound("buttons/button4.wav")
							end

							local x, y = elem:GetPos()
							elem:SetPos(x * 0.9, ((48 * (i-1)) + y*6)/7)
						end
					end

					if IsValid(self.VBar) then
						self.VBar.Paint = BLANK_DRAW
						self.VBar:SetHideButtons(true)
						self.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
					end
				end

				pnl.plyPnlNPC = pnl:Add("DScrollPanel")
				pnl.plyPnlNPC:SetSize(320, ScrH() * 0.15)
				pnl.plyPnlNPC:SetPos(-1000, -1000)
				pnl.plyPnlNPC:SetPaintBackground(false)
				pnl.plyPnlNPC.list = {}
				pnl.plyPnlNPC.elementDict = {}
				function pnl.plyPnlNPC:Think()
					local index = 0
					local mismatchDetected = false

					local fullPlyList = player.GetAll()
					for i, ply in ipairs(fullPlyList) do
						if ply:GetNWInt("jcms_desiredteam", 0) == 2 then
							index = index + 1

							if mismatchDetected then
								self.list[ index ] = ply
							elseif self.list[ index ] ~= ply then
								mismatchDetected = true
								for j=index, #fullPlyList do
									self.list[j] = nil
								end
								self.list[ index ] = ply
							end
						elseif IsValid(self.elementDict[ ply ]) then
							local elem = self.elementDict[ ply ]
							elem.player = nil
							if IsValid(elem.av) then
								elem.av:Remove()
							end
							surface.PlaySound("buttons/button6.wav")
							table.RemoveByValue(self.list, ply)
							self.elementDict[ ply ] = nil
						end
					end

					for i=#self.list, 1, -1 do
						local ply = self.list[i]

						if not IsValid(ply) then
							table.remove(self.list, i)
						else
							local elem = self.elementDict[ ply ]
							if not IsValid(elem) then
								elem = self:Add("DPanel")
								elem:SetPos(self:GetWide(), 24 * (i-1))
								elem:SetSize(self:GetWide(), 24)
								elem.Paint = jcms.paint_PlayerLobbyNPC
								elem.player = ply
								elem.classMats = self.classMats
								elem.gunStats = self.gunStats
								self.elementDict[ ply ] = elem

								local av = elem:Add("AvatarImage")
								av:SetPlayer( ply, 16 )
								av:SetSize(16, 16)
								av:SetPos(16, 4)
								elem.av = av

								surface.PlaySound("buttons/button4.wav")
							end

							local x, y = elem:GetPos()
							elem:SetPos(x * 0.9, ((24 * (i-1)) + y*4)/5)
						end
					end

					if IsValid(self.VBar) then
						self.VBar.Paint = BLANK_DRAW
						self.VBar:SetHideButtons(true)
						self.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
					end
				end

				pnl.controlPanel = pnl:Add("DPanel")
				pnl.controlPanel:SetSize(650, 64)
				pnl.controlPanel:SetPos(-1000, ScrH())
				pnl.controlPanel.Paint = jcms.offgame_paint_ControlPanel

				pnl.controlPanel.bReady = pnl.controlPanel:Add("DButton")
				pnl.controlPanel.bReady:SetText("")
				pnl.controlPanel.bReady:SetPos(4, 32+4)
				pnl.controlPanel.bReady:SetSize(200, 24)
				pnl.controlPanel.bReady.Paint = jcms.paint_ButtonFilled
				pnl.controlPanel.bReady.jFont = "jcms_medium"
				function pnl.controlPanel.bReady:DoClick()
					RunConsoleCommand("jcms_ready")
				end

				pnl.controlPanel.bLeave = pnl.controlPanel:Add("DButton")
				pnl.controlPanel.bLeave:SetText("#jcms.leavelobby")
				pnl.controlPanel.bLeave:SetPos(200 + 8, 32+4)
				pnl.controlPanel.bLeave:SetSize(200, 24)
				pnl.controlPanel.bLeave.Paint = jcms.paint_ButtonFilled
				pnl.controlPanel.bLeave.jFont = "jcms_medium"
				function pnl.controlPanel.bLeave:DoClick()
					RunConsoleCommand("jcms_jointeam", 0)
					
					for i, child in ipairs(pnl.tabPnl:GetChildren()) do
						child:Remove()
					end
					
					pnl.tabPnl.Paint = nil
					jcms.offgame_BuildMissionTab(pnl.tabPnl)
				end
				
				if LocalPlayer():IsAdmin() and not game.SinglePlayer() then
					pnl.controlPanel.bForceStart = pnl.controlPanel:Add("DButton")
					pnl.controlPanel.bForceStart:SetText("#jcms.forcestart")
					pnl.controlPanel.bForceStart:SetPos(400 + 12, 32 + 4)
					pnl.controlPanel.bForceStart:SetSize(200, 24)
					pnl.controlPanel.bForceStart.Paint = jcms.paint_Button
					pnl.controlPanel.bForceStart.jFont = "jcms_small"
					function pnl.controlPanel.bForceStart:DoClick()
						RunConsoleCommand("jcms_forcestart")
					end
				end

				jcms.offgame_CreateChatAsChild(pnl, pnl:GetWide() - 600 - 32, pnl:GetTall() - 200 - 64, 600, 200)
			-- }}}

			local onlineTooltip = pnl:Add("DPanel")
			onlineTooltip:SetVisible(false)
			onlineTooltip:SetPos(-512, -512)
			onlineTooltip:SetSize(200, 512)
			onlineTooltip:SetPaintBackground(false)
			onlineTooltip.Paint = jcms.offgame_paint_OnlineToolTip
			function onlineTooltip:Think()
				if IsValid( self:GetParent() ) then
					self:GetParent().Paint = BLANK_DRAW
				end
			end

			pnl.onlinePlayers = pnl:Add("DPanel")
			pnl.onlinePlayers.Paint = jcms.paint_OnlinePlayers
			pnl.onlinePlayers:SetPos(-128, -128)
			pnl.onlinePlayers:SetTooltipDelay(0.05)
			pnl.onlinePlayers:SetTooltipPanel(onlineTooltip)

			bMis.BuildFunc(pnl.tabPnl)
		end

		function jcms.offgame_BuildMissionTab(tab)
			tab.Paint = jcms.offgame_paint_MissionTab

			local favclass = jcms.cvar_favclass:GetString()
			if jcms.classes[ favclass ] then
				timer.Simple(0.1, function()
					RunConsoleCommand("jcms_setclass", favclass)
				end)
			end

			if game.SinglePlayer() then
				local y = 220

				local bBegin = tab:Add("DButton")
				bBegin:SetText("#jcms.startmission")
				bBegin:SetPos(32, y)
				bBegin:SetSize(400-64-24, 32)
				bBegin.Paint = jcms.paint_ButtonFilled
				bBegin.jFont = "jcms_big"
				function bBegin:DoClick()
					tab.Paint = jcms.offgame_paint_MissionPrepTab

					for i, child in ipairs( tab:GetChildren() ) do
						child:Remove()
					end

					surface.PlaySound("buttons/button14.wav")
					jcms.offgame_BuildMissionPrepTab(tab)
					RunConsoleCommand("jcms_jointeam", "1")
				end
				y = y + 32 + 8

				local bChangeMission = tab:Add("DButton")
				bChangeMission:SetText("#jcms.changemission_sp")
				bChangeMission:SetPos(32+24, y)
				bChangeMission:SetSize(400-64-24, 32)
				bChangeMission.Paint = jcms.paint_Button
				bChangeMission.jFont = "jcms_medium"
				function bChangeMission:DoClick()
					jcms.offgame_ModalChangeMission()
				end
			else
				y = 128

				local bJoinSweeper = tab:Add("DButton")
				bJoinSweeper:SetText("#jcms.joinas_sweeper")
				bJoinSweeper:SetPos(32, y)
				bJoinSweeper:SetSize(300, 32)
				bJoinSweeper.Paint = jcms.paint_ButtonFilled
				bJoinSweeper.jFont = "jcms_medium"
				function bJoinSweeper:DoClick()
					tab.Paint = jcms.offgame_paint_MissionPrepTab

					for i, child in ipairs( tab:GetChildren() ) do
						child:Remove()
					end

					surface.PlaySound("buttons/button14.wav")
					jcms.offgame_BuildMissionPrepTab(tab)
					RunConsoleCommand("jcms_jointeam", "1")
				end
				y = y + 32 + 8

				local bJoinNPC = tab:Add("DButton")
				bJoinNPC:SetText("#jcms.joinas_npc")
				bJoinNPC:SetPos(48, y)
				bJoinNPC:SetSize(300, 32)
				bJoinNPC.Paint = jcms.paint_ButtonFilled
				bJoinNPC.jFont = "jcms_medium"
				function bJoinNPC:DoClick()
					tab.Paint = jcms.offgame_paint_MissionPrepTab

					for i, child in ipairs( tab:GetChildren() ) do
						child:Remove()
					end

					surface.PlaySound("buttons/button14.wav")
					--jcms.offgame_BuildMissionPrepTab(tab) -- TODO
					RunConsoleCommand("jcms_jointeam", "2")
				end
				y = y + 64 + 8

				if LocalPlayer():IsAdmin() then
					local bChangeMission = tab:Add("DButton")
					bChangeMission:SetText("#jcms.changemission_sp")
					bChangeMission:SetPos(32, y)
					bChangeMission:SetSize(400-64-24, 32)
					bChangeMission.Paint = jcms.paint_Button
					bChangeMission.jFont = "jcms_medium"
					function bChangeMission:DoClick()
						jcms.offgame_ModalChangeMission()
					end
				end

				-- TODO Mission vote
			end

			if not jcms.statistics.playedTutorial then
				local tutor = tab:Add("DPanel")
				tutor:SetPos(72, 380)
				tutor:SetSize(256, 300)
				tutor.Paint = jcms.paint_Panel
				tutor.jText = "#jcms.menututor_title"

				local tutorImg = tutor:Add("DImage")
				tutorImg:SetImage("jcms/tutorialicon.png")
				tutorImg:SetSize(128, 128)
				tutorImg:Center()
				tutorImg:SetY( tutorImg:GetY() - 32)

				if game.SinglePlayer() then
					local l1 = tutor:Add("DLabel")
					l1:SetTextColor(jcms.color_bright)
					l1:SetText("#jcms.menututor_desc_sp1")
					l1:SetPos(32, tutorImg:GetY() + tutorImg:GetTall() + 16)
					l1:SizeToContents()

					local l2 = tutor:Add("DLabel")
					l2:SetTextColor(jcms.color_bright)
					l2:SetText("#jcms.menututor_desc_sp2")
					l2:SetPos(32, l1:GetY() + l1:GetTall())
					l2:SizeToContents()

					local tutorBtn = tutor:Add("DButton")
					tutorBtn:SetText("#jcms.menututor_btn")
					tutorBtn:SetSize(tutor:GetWide() - 16, 24)
					tutorBtn:SetPos(8, tutor:GetTall() - tutorBtn:GetTall() - 8)
					tutorBtn.Paint = jcms.paint_ButtonFilled
					function tutorBtn:DoClick()
						RunConsoleCommand("changelevel", "jcms_tutorial")
					end

					local maxWidth = math.max(l1:GetWide(), l2:GetWide())
					local x = (tutor:GetWide() - maxWidth)/2
					l1:SetX(x)
					l2:SetX(x)
				else
					local lines = {}
					local lastLine
					local maxWidth = 0
					for i, n in ipairs { "sp1", "sp2", "mp1", "mp2", "mp3" } do
						local y = lastLine and lastLine:GetY() + lastLine:GetTall() or tutorImg:GetY() + tutorImg:GetTall() + 16
						lastLine = tutor:Add("DLabel")
						lastLine:SetTextColor(jcms.color_bright)
						lastLine:SetText("#jcms.menututor_desc_" .. n)
						lastLine:SetPos(24, y)
						lastLine:SizeToContents()
						maxWidth = math.max( lastLine:GetWide(), maxWidth )
						table.insert(lines, lastLine)
					end

					local x = (tutor:GetWide() - maxWidth)/2
					for i, l in ipairs(lines) do
						l:SetX(x)
					end
				end
			end
		end

		function jcms.offgame_BuildMissionPrepTab(tab)
			-- Class {{{
				tab.classPnl = tab:Add("DPanel")
				tab.classPnl:SetPos(32, 32)
				tab.classPnl:SetSize(800, 200)
				tab.classPnl.Paint = jcms.offgame_paint_ClassPanel

				tab.classPnl.mdl = tab.classPnl:Add("DModelPanel")
				tab.classPnl.mdl:SetSize(tab.classPnl:GetTall()-2, tab.classPnl:GetTall()-2)
				tab.classPnl.mdl:SetPos(1, 1)

				function tab.classPnl.mdl:DoClick()
					local ent = tab.classPnl.mdl:GetEntity()
					if IsValid(ent) then
						ent.dancing = not ent.dancing
					end
				end

				function tab.classPnl.mdl:LayoutEntity(ent)
					self:SetFOV(24)
					self:SetCamPos( Vector(64, -32, 64) )
					self:SetLookAng( Angle(0, 180-27, 0) )
					self:SetAmbientLight(jcms.color_dark)

					self:SetDirectionalLight(BOX_BOTTOM, jcms.color_bright)
					self:SetDirectionalLight(BOX_LEFT, jcms.color_bright)
					self:SetDirectionalLight(BOX_BACK, jcms.color_bright)
					self:SetDirectionalLight(BOX_TOP, jcms.color_dark)
					self:SetDirectionalLight(BOX_RIGHT, jcms.color_dark)
					self:SetDirectionalLight(BOX_FRONT, jcms.color_dark)

					local sequenceId = ent:LookupSequence(ent.dancing and "taunt_dance_base" or "pose_standing_02")

					local classData = jcms.classes[ LocalPlayer():GetNWString("jcms_desiredclass", "infantry") ]
					local oldCycle = 0

					if classData and classData.mdl and ent:GetModel() ~= classData.mdl then
						oldCycle = ent:GetCycle()
						ent:SetModel( classData.mdl )
					end
					
					if ent:GetSequence() ~= sequenceId then
						ent:SetSequence(sequenceId)
						ent:SetCycle(oldCycle or 0)
					end

					ent:SetCycle((ent:GetCycle() + (ent.dancing and 0.2 or 1)*FrameTime() ) % 1)
				end

				local function cbtnClick(self)
					RunConsoleCommand("jcms_setclass", self.classname)
					surface.PlaySound("weapons/slam/mine_mode.wav")
					jcms.cvar_favclass:SetString(self.classname)
				end

				local minimizeButtons = #jcms.classesOrder > 4

				for i, classname in ipairs( jcms.classesOrder ) do
					local size = minimizeButtons and 32 or 64
					local cbtn = tab.classPnl:Add("DImageButton")
					if minimizeButtons then
						cbtn:SetPos(tab.classPnl.mdl:GetWide() + size*math.floor( (i-1)/2 ), tab.classPnl:GetTall() - 64 - 8 + (i%2==0 and 32 or 0))
					else
						cbtn:SetPos(tab.classPnl.mdl:GetWide() + size*(i-1), tab.classPnl:GetTall() - 64 - 8)
					end
					cbtn:SetSize(size, size)
					cbtn:SetImage("jcms/classes/" .. classname .. ".png")
					cbtn.classname = classname
					cbtn.Paint = jcms.paint_ClassButton
					cbtn.DoClick = cbtnClick
				end
			-- }}}

			-- Loadout {{{
				tab.loadoutPnl = tab:Add("DPanel")
				tab.loadoutPnl:SetPos(64, tab.classPnl:GetY() + tab.classPnl:GetTall() + 8)
				tab.loadoutPnl:SetSize(800, tab:GetTall() - tab.loadoutPnl:GetY() - tab.loadoutPnl:GetTall())
				tab.loadoutPnl.Paint = jcms.offgame_paint_LoadoutPanel
				tab.loadoutPnl.gunStats = {}
				tab.loadoutPnl.weaponButtons = {}

				tab.loadoutPnl.randomLoadout = tab.loadoutPnl:Add("DImageButton")
				tab.loadoutPnl.randomLoadout:SetSize(24, 24)
				tab.loadoutPnl.randomLoadout:SetImage("jcms/random.png")
				tab.loadoutPnl.randomLoadout:SetPos(tab.loadoutPnl:GetWide()-24-8, 188 - 24)
				tab.loadoutPnl.randomLoadout:SetStretchToFit(false)
				function tab.loadoutPnl.randomLoadout:DoClick()
					local weaponPool = {}
					
					local myCash = LocalPlayer():GetNWInt("jcms_cash", 0) - LocalPlayer():GetNWInt("jcms_pendingLoadoutCost", 0)
					for weapon, cost in pairs(jcms.weapon_prices) do
						if cost > 0 and math.ceil(cost * jcms.util_GetLobbyWeaponCostMultiplier()) <= myCash and not LocalPlayer():HasWeapon(weapon) then
							weaponPool[ weapon ] = 5 + cost ^ 0.8
						end
					end

					local weaponChosen = jcms.util_ChooseByWeight(weaponPool)
					RunConsoleCommand("jcms_buyweapon", weaponChosen)
					surface.PlaySound("physics/metal/weapon_footstep"..math.random(1,2)..".wav")
				end
				tab.loadoutPnl.randomLoadout.Paint = jcms.paint_ImageButton
				tab.loadoutPnl.randomLoadout:SetTooltip( language.GetPhrase("jcms.randomweapon") )

				tab.loadoutPnl.clearLoadout = tab.loadoutPnl:Add("DButton")
				tab.loadoutPnl.clearLoadout:SetSize(128, 24)
				tab.loadoutPnl.clearLoadout:SetText("#jcms.clearloadout")
				tab.loadoutPnl.clearLoadout:SetPos(tab.loadoutPnl.randomLoadout:GetX() - tab.loadoutPnl.clearLoadout:GetWide() - 8, 188 - 24)
				tab.loadoutPnl.clearLoadout.Paint = jcms.paint_ButtonFilled
				function tab.loadoutPnl.clearLoadout:DoClick()
					surface.PlaySound("items/ammocrate_close.wav")
					surface.PlaySound("physics/metal/weapon_impact_hard1.wav")
					for i, weapon in ipairs( LocalPlayer():GetWeapons() ) do
						RunConsoleCommand("jcms_buyweapon", weapon:GetClass(), -9999999)
					end
				end

				tab.loadoutPnl.getExtraAmmo = tab.loadoutPnl:Add("DButton")
				tab.loadoutPnl.getExtraAmmo:SetSize(128, 24)
				tab.loadoutPnl.getExtraAmmo:SetText("#jcms.getextraammo")
				tab.loadoutPnl.getExtraAmmo:SetPos(tab.loadoutPnl.clearLoadout:GetX() - tab.loadoutPnl.getExtraAmmo:GetWide() - 8, 188 - 24)
				tab.loadoutPnl.getExtraAmmo.Paint = jcms.paint_ButtonFilled
				function tab.loadoutPnl.getExtraAmmo:DoClick()
					surface.PlaySound("items/ammo_pickup.wav")
					--todo: Check we actually have the J to do this before making the sound. If we don't use a negative sound.

					if input.IsKeyDown(KEY_LSHIFT) then
						RunConsoleCommand("jcms_buyweapon", "allammo")
					else
						for i, weapon in ipairs( LocalPlayer():GetWeapons() ) do
							RunConsoleCommand("jcms_buyweapon", weapon:GetClass(), 1)
						end
					end
				end

				tab.loadoutPnl.shopScroller = tab.loadoutPnl:Add("DScrollPanel")
				tab.loadoutPnl.shopScroller:SetPos(256, 270)
				tab.loadoutPnl.shopScroller:SetSize(tab.loadoutPnl:GetWide() - 16 - tab.loadoutPnl.shopScroller:GetX(), tab.loadoutPnl:GetTall() - 16 - tab.loadoutPnl.shopScroller:GetY())
				tab.loadoutPnl.shop = tab.loadoutPnl.shopScroller:Add("DListLayout")
				tab.loadoutPnl.shop:SetPos(0, 0)
				tab.loadoutPnl.shop:SetSize(tab.loadoutPnl.shopScroller:GetSize())
				tab.loadoutPnl.shop.catMode = 1
				tab.loadoutPnl.shop.sortMode = 1
				tab.loadoutPnl.shop.sortReverse = false
				tab.loadoutPnl.shop.weaponButtons = {}
				function tab.loadoutPnl.shop:CategorizeGun(class)
					local mode = self.catMode

					if not tab.loadoutPnl.gunStats[ class ] then
						tab.loadoutPnl.gunStats[ class ] = jcms.gunstats_GetExpensive(class)
					end
					local stats = tab.loadoutPnl.gunStats[ class ]

					if mode == 1 then
						return stats.category
					elseif mode == 2 then
						return language.GetPhrase(stats.ammotype_lkey)
					elseif mode == 3 then
						return stats.base
					elseif mode == 4 then
						return language.GetPhrase("jcms.weaponcat" .. math.Clamp(stats.slot or 5, 0, 5))
					else
						return "_"
					end
				end
				function tab.loadoutPnl.shop:GetSortFunc()
					local mode = self.sortMode
					local allstats = tab.loadoutPnl.gunStats

					local sortfunc
					if mode == 1 then -- HELL YEAAAAAHHHHHHHH ELSEIFS
						sortfunc = function(first, last) return allstats[first].name < allstats[last].name end
					elseif mode == 2 then
						sortfunc = function(first, last) return jcms.weapon_prices[first] < jcms.weapon_prices[last] end
					elseif mode == 3 then
						sortfunc = function(first, last) return allstats[first].damage < allstats[last].damage end
					elseif mode == 4 then
						sortfunc = function(first, last) return allstats[first].firerate_rps < allstats[last].firerate_rps end
					elseif mode == 5 then
						sortfunc = function(first, last) return allstats[first].dps < allstats[last].dps end
					elseif mode == 6 then
						sortfunc = function(first, last) return allstats[first].clipsize < allstats[last].clipsize end
					elseif mode == 7 then
						sortfunc = function(first, last) return allstats[first].accuracy < allstats[last].accuracy end
					else
						sortfunc = function(first, last) return first < last end
					end

					return sortfunc
				end
				function tab.loadoutPnl.shop:Think()
					local newHash = jcms.util_Hash( jcms.weapon_prices )
					if self.previousHash ~= newHash then
						self.previousHash = newHash
						self:RebuildLayout()
					end

					local ply = LocalPlayer()
					for i, wbtn in ipairs(self.weaponButtons) do
						local mycash = ply:GetNWInt("jcms_cash", 0) - ply:GetNWInt("jcms_pendingLoadoutCost", 0)
						local count = jcms.weapon_loadout[wbtn.gunClass] or 0

						if count > 0 then
							wbtn.cost = math.ceil(jcms.gunstats_ExtraAmmoCostData(wbtn.gunStats, 1)*wbtn.ammoSale)
						else
							wbtn.cost = math.ceil(jcms.weapon_prices[wbtn.gunClass]*wbtn.gunSale)
						end

						wbtn.owned = count
						wbtn.cantAfford = not (wbtn.cost <= mycash)
					end
				end
				function tab.loadoutPnl.shop:RebuildLayout()
					local categorizedGuns = { _ = {} }
					local favs = {}

					table.Empty(tab.loadoutPnl.shop.weaponButtons)
					for i, child in ipairs( self:GetChildren() ) do
						child:Remove()
					end

					for weapon, cost in pairs(jcms.weapon_prices) do
						local category = self:CategorizeGun(weapon)
						if not categorizedGuns[ category ] then
							categorizedGuns[ category ] = { weapon }
						else
							table.insert(categorizedGuns[ category ], weapon)
						end

						if jcms.weapon_favourites[ weapon ] then
							table.insert(favs, weapon)
						end
					end

					categorizedGuns.favs = favs
					local sortfunc = self:GetSortFunc()
					for category, list in pairs(categorizedGuns) do
						table.sort(list, sortfunc)

						if self.sortReverse then
							for i=1, math.floor(#list/2) do
								list[i], list[#list-i+1] = list[#list-i+1], list[i]
							end
						end
					end

					local topmostCategory = categorizedGuns["_"]
					categorizedGuns["_"] = nil
					categorizedGuns.favs = nil

					local categoriesSorted = table.GetKeys(categorizedGuns)
					table.sort(categoriesSorted, function(first, last)
						return #categorizedGuns[ first ] > #categorizedGuns[ last ]
					end)

					if #topmostCategory > 0 then
						table.insert(categoriesSorted, 1, "_")
						categorizedGuns["_"] = topmostCategory
					end

					if #favs > 0 then
						local str = language.GetPhrase("jcms.favourites")
						table.insert(categoriesSorted, 1, str)
						categorizedGuns[str] = favs
					end

					local function wbtnClick(self)
						if not self.cantAfford then
							RunConsoleCommand("jcms_buyweapon", self.gunClass, input.IsKeyDown(KEY_LSHIFT) and 9999999 or 1)
							surface.PlaySound("physics/metal/weapon_footstep"..math.random(1,2)..".wav")
						end
					end

					local function wbtnRightClick(self)
						local value = not jcms.weapon_favourites[ self.gunClass ]
						jcms.weapon_favourites[ self.gunClass ] = value

						if value then
							surface.PlaySound("buttons/combine_button5.wav")
						else
							surface.PlaySound("buttons/combine_button7.wav")
						end

						tab.loadoutPnl.shop:RebuildLayout()
					end

					local mini = tab.loadoutPnl:GetTall() <= 600
					for i, category in ipairs(categoriesSorted) do
						local bar = self:Add("DCollapsibleCategory")
						bar:SetLabel("")
						bar:DockMargin(4, 4, 4, 4)
						bar.jCat = category
						bar.Paint = jcms.paint_Category

						local gunicos = self:Add("DIconLayout")
						gunicos:SetSpaceX(4)
						gunicos:SetSpaceY(4)
						gunicos:DockMargin(4, 4, 4, 32)
						gunicos:DockPadding(0, 0, 0, 32)
						bar:SetContents(gunicos)

						local bsize = mini and 64 or 80
						for i, class in ipairs(categorizedGuns[ category ]) do
							local wbtn = gunicos:Add("DButton")
							wbtn:SetSize(bsize, bsize)
							wbtn.Paint = jcms.paint_Gun
							wbtn.gunStats = tab.loadoutPnl.gunStats[class]
							wbtn.gunClass = class 
							wbtn.DoClick = wbtnClick
							wbtn.DoRightClick = wbtnRightClick
							wbtn.gunSale = jcms.util_GetLobbyWeaponCostMultiplier()
							wbtn.ammoSale = 1
							wbtn.cost = math.ceil( jcms.weapon_prices[class] * wbtn.gunSale )
							table.insert(tab.loadoutPnl.shop.weaponButtons, wbtn)
						end
					end

					self:GetParent():InvalidateChildren(true)
					if IsValid(tab.loadoutPnl.shopScroller.VBar) then
						tab.loadoutPnl.shopScroller.VBar.Paint = BLANK_DRAW
						tab.loadoutPnl.shopScroller.VBar:SetHideButtons(true)
						tab.loadoutPnl.shopScroller.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
					end
				end

				tab.loadoutPnl.sortComboBox = tab.loadoutPnl:Add("DComboBox")
				tab.loadoutPnl.sortComboBox:SetSize(224 - 24 - 4, 24)
				tab.loadoutPnl.sortComboBox:SetPos(16, 286 + 32)
				tab.loadoutPnl.sortComboBox:SetSortItems(false)
				tab.loadoutPnl.sortComboBox:SetValue("#jcms.sortmode_name")
				tab.loadoutPnl.sortComboBox:AddChoice("#jcms.sortmode_name", 1)
				tab.loadoutPnl.sortComboBox:AddChoice("#jcms.sortmode_price", 2)
				tab.loadoutPnl.sortComboBox:AddChoice("#jcms.sortmode_damage", 3)
				tab.loadoutPnl.sortComboBox:AddChoice("#jcms.sortmode_firerate", 4)
				tab.loadoutPnl.sortComboBox:AddChoice("#jcms.sortmode_dps", 5)
				tab.loadoutPnl.sortComboBox:AddChoice("#jcms.sortmode_clipsize", 6)
				tab.loadoutPnl.sortComboBox:AddChoice("#jcms.gun_spread", 7)
				tab.loadoutPnl.sortComboBox.Paint = jcms.paint_ComboBox
				tab.loadoutPnl.sortComboBox.PaintOver = BLANK_DRAW
				tab.loadoutPnl.sortComboBox.jText = "#jcms.sortby"
				function tab.loadoutPnl.sortComboBox:OnSelect(i, text, data)
					tab.loadoutPnl.shop.sortMode = data
					tab.loadoutPnl.shop:RebuildLayout()
				end
				function tab.loadoutPnl.sortComboBox:OnMenuOpened(m)
					m.Paint = function(mm)
						for i, child in ipairs(mm.pnlCanvas:GetChildren()) do
							child.Paint = jcms.paint_ComboBoxButton
							child.PaintOver = BLANK_DRAW
						end
					end
				end

				tab.loadoutPnl.categoryComboBox = tab.loadoutPnl:Add("DComboBox")
				tab.loadoutPnl.categoryComboBox:SetSize(224, 24)
				tab.loadoutPnl.categoryComboBox:SetPos(16, 286)
				tab.loadoutPnl.categoryComboBox:SetSortItems(false)
				tab.loadoutPnl.categoryComboBox:SetValue("#jcms.catmode_default")
				tab.loadoutPnl.categoryComboBox:AddChoice("#jcms.catmode_none", 0)
				tab.loadoutPnl.categoryComboBox:AddChoice("#jcms.catmode_default", 1)
				tab.loadoutPnl.categoryComboBox:AddChoice("#jcms.catmode_ammo", 2)
				tab.loadoutPnl.categoryComboBox:AddChoice("#jcms.catmode_base", 3)
				tab.loadoutPnl.categoryComboBox:AddChoice("#jcms.catmode_slot", 4)
				tab.loadoutPnl.categoryComboBox.Paint = jcms.paint_ComboBox
				tab.loadoutPnl.categoryComboBox.PaintOver = BLANK_DRAW
				tab.loadoutPnl.categoryComboBox.jText = "#jcms.catsby"
				function tab.loadoutPnl.categoryComboBox:OnSelect(i, text, data)
					tab.loadoutPnl.shop.catMode = data
					tab.loadoutPnl.shop:RebuildLayout()
				end

				tab.loadoutPnl.reverseSort = tab.loadoutPnl:Add("DCheckBox")
				tab.loadoutPnl.reverseSort:SetPos(tab.loadoutPnl.sortComboBox:GetX() + tab.loadoutPnl.sortComboBox:GetWide() + 4, tab.loadoutPnl.sortComboBox:GetY())
				tab.loadoutPnl.reverseSort:SetSize(24, 24)
				tab.loadoutPnl.reverseSort.Paint = jcms.paint_SortCheckBox
				function tab.loadoutPnl.reverseSort:OnChange(v)
					tab.loadoutPnl.shop.sortReverse = v
					tab.loadoutPnl.shop:RebuildLayout()
				end
			-- }}}

			-- Other {{{
				local classData = jcms.classes[ jcms.cachedValues.playerClass ]
				if classData and classData.mdl then
					tab.classPnl.mdl:SetModel( classData.mdl )
				else
					tab.classPnl.mdl:SetModel("models/player/kleiner.mdl")
				end
			-- }}}
		end

		function jcms.offgame_BuildPersonalTab(tab)
			tab.Paint = jcms.offgame_paint_PersonalTab

			local av = tab:Add("AvatarImage")
			av:SetPlayer( LocalPlayer(), 128 )
			av:SetSize(128, 128)
			av:SetPos(64, 64)

			-- Stats {{{
				local stats = tab:Add("DPanel")
				stats:SetPos(64, 208)
				stats:SetSize(600, 340)
				stats.Paint = jcms.offgame_paint_PersonalPanel
				stats.jText = "#jcms.stats"
				stats.classFilter = nil

				local filter = stats:Add("DComboBox")
				filter:SetSize(256, 24)
				filter:SetPos(stats:GetWide() - filter:GetWide() - 16, 8)
				filter:SetSortItems(false)
				filter:AddChoice("#jcms.stats_filter_total", nil, true)
				for i, class in ipairs(jcms.classesOrder) do
					filter:AddChoice("#jcms.class_" .. class, class, false)
				end
				function filter:OnSelect(i, str, data)
					surface.PlaySound("buttons/button15.wav")
					stats.classFilter = data
					stats:Rebuild()	
				end
				filter.Paint = jcms.paint_ComboBox
				filter.PaintOver = BLANK_DRAW
				filter.jText = "#jcms.stats_filter"

				stats.scrollPanel = stats:Add("DScrollPanel")
				stats.scrollPanel:SetSize(stats:GetWide() - 32, stats:GetTall() - 48)
				stats.scrollPanel:SetPos(16, 48)

				function stats:Rebuild()
					if IsValid(self.scrollPanel) then
						self.scrollPanel:Clear()
					end
					
					local sepKills = stats.scrollPanel:Add("DPanel")
					sepKills.Paint = jcms.paint_Separator
					sepKills.jText = "#jcms.stats_kills"
					sepKills:SetSize(stats.scrollPanel:GetWide(), 24)

					local tableKills = stats.scrollPanel:Add("DPanel")
					tableKills:SetPos(16, 48)
					tableKills:SetSize(300, 500)
					tableKills.Paint = jcms.offgame_paint_Table
					tableKills.tableRows = {}
					tableKills.tableColumns = 1
					tableKills.sumKills = 0

					local pieKills = stats.scrollPanel:Add("DPanel")
					pieKills:SetSize(172, 172)
					pieKills:SetPos(stats.scrollPanel:GetWide() - pieKills:GetWide() - 16, 32)
					pieKills.Paint = jcms.offgame_paint_PieChart
					pieKills.chartData = {}
					pieKills.jFont = "jcms_small"
					pieKills.displayNumbers = true

					local killSectionHeight = 172
					local killTableHeight = 28
					
					for i, factionName in ipairs(jcms.factions_GetOrder()) do
						local cnt = jcms.statistics_GetKillCount(factionName, stats.classFilter)
						tableKills.sumKills = tableKills.sumKills + cnt

						table.insert(tableKills.tableRows, { 
							color = jcms.factions_GetColor(factionName), 
							title = "#jcms." .. factionName, 
							[1] = cnt,
							indent = 1
						})

						killTableHeight = killTableHeight + 18
						killSectionHeight = math.max(killSectionHeight, killTableHeight)

						if cnt > 0 then
							table.insert(pieKills.chartData, { 
								color = jcms.factions_GetColor(factionName), 
								title = "#jcms." .. factionName, 
								n = cnt 
							})
						end
					end

					table.insert(tableKills.tableRows, 1, {
						title = "#jcms.stats_total", 
						[1] = tableKills.sumKills,
						indent = 0
					})

					tableKills:SetHeight(killSectionHeight)

					local sepMissions = stats.scrollPanel:Add("DPanel")
					sepMissions.Paint = jcms.paint_Separator
					sepMissions.jText = "#jcms.stats_missions"
					sepMissions:SetSize(stats.scrollPanel:GetWide(), 24)
					sepMissions:SetPos(0, tableKills:GetY() + tableKills:GetTall())

					local tableMissions = stats.scrollPanel:Add("DPanel")
					tableMissions:SetPos(16, sepMissions:GetY() + 32)
					tableMissions:SetSize(stats.scrollPanel:GetWide() - 64, 500)
					tableMissions.Paint = jcms.offgame_paint_Table
					tableMissions.tableRows = {}
					tableMissions.tableColumns = 3
					tableMissions.tableColumnsOffset = 2
					tableMissions.sum1 = 0
					tableMissions.sum2 = 0

					local factionOrder = jcms.factions_GetOrder()
					for i=0, #factionOrder do
						local factionName = i==0 and "everyone" or factionOrder[i]
						local color = i==0 and jcms.color_bright or jcms.factions_GetColor(factionName)
						local currentIndex = #tableMissions.tableRows + 1
						local sum1, sum2 = 0, 0
						
						for iter=1, 2 do
							for j, misType in ipairs( jcms.mission_GetTypesByFaction(iter==2 and "any" or factionName) ) do
								local misTypeAdjusted = iter == 2 and misType .. ":" .. factionName or misType
								local n1 = jcms.statistics_GetMissionCount(misTypeAdjusted, stats.classFilter, false)
								local n2 = jcms.statistics_GetMissionCount(misTypeAdjusted, stats.classFilter, true)

								if n1 > 0  then
									table.insert(tableMissions.tableRows, { 
										color = color,
										title = "#jcms." .. misType, 
										[1] = n1,
										[2] = n2,
										[3] = jcms.util_Percentage(n2, n1),
										indent = i==0 and 1 or 2
									} )

									sum1 = sum1 + n1
									sum2 = sum2 + n2
								end
							end
						end

						if i > 0 and sum1 > 0 then
							table.insert(tableMissions.tableRows, currentIndex, { 
								color = color,
								title = "#jcms." .. factionName, 
								[1] = sum1,
								[2] = sum2,
								[3] = jcms.util_Percentage(sum2, sum1),
								indent = 1
							} )
						end

						tableMissions.sum1 = tableMissions.sum1 + sum1
						tableMissions.sum2 = tableMissions.sum2 + sum2
					end

					table.insert(tableMissions.tableRows, 1, {
						title = "#jcms.stats_total", 
						[1] = tableMissions.sum1,
						[2] = tableMissions.sum2,
						[3] = jcms.util_Percentage(tableMissions.sum2, tableMissions.sum1),
						indent = 0
					} )

					table.insert(tableMissions.tableRows, 1, { 
						title = "", 
						[1] = "#jcms.stats_missions_started",
						[2] = "#jcms.stats_missions_completed",
						[3] = "#jcms.stats_missions_winrate",
						indent = 0
					} )

					tableMissions:SetTall( 28 + #tableMissions.tableRows * 18 + 16 )

					local sepOther = stats.scrollPanel:Add("DPanel")
					sepOther.Paint = jcms.paint_Separator
					sepOther.jText = "#jcms.stats_other"
					sepOther:SetSize(stats.scrollPanel:GetWide(), 24)
					sepOther:SetPos(0, tableMissions:GetY() + tableMissions:GetTall())

					local tableOther = stats.scrollPanel:Add("DPanel")
					tableOther:SetPos(16, sepOther:GetY() + 32)
					tableOther:SetSize(stats.scrollPanel:GetWide() - 64, 256)
					tableOther.Paint = jcms.offgame_paint_Table
					tableOther.tableRows = {
						{ title = "#jcms.stats_playtime", [1] = jcms.util_PlaytimeFormat(jcms.statistics_GetPlaytime(stats.classFilter)), indent = 0 },
						{ title = "#jcms.stats_deaths", [1] = jcms.statistics_GetOther("deaths", stats.classFilter), indent = 1 },
						{ title = "#jcms.stats_ffire", [1] = jcms.statistics_GetOther("ffire", stats.classFilter), indent = 1 },
						{ title = "#jcms.stats_orders", [1] = jcms.statistics_GetOther("orders", stats.classFilter), indent = 1 },
						{ title = "#jcms.stats_hacks", [1] = jcms.statistics_GetOther("hacks", stats.classFilter), indent = 1 }
					}
					tableOther.tableColumns = 1
					tableOther.tableColumnsOffset = 1
					tableOther:SetTall( 28 + #tableOther.tableRows * 18 + 16 )
				end
				
				stats:Rebuild()

			-- }}}

			-- Achievements {{{
				local achievs = tab:Add("DPanel")
				achievs:SetPos(80, stats:GetY() + stats:GetTall() + 32)
				achievs:SetSize(500, tab:GetTall() - achievs:GetY() - 32)
				achievs.Paint = jcms.offgame_paint_PersonalPanel
				achievs.jText = "#jcms.achievements"
				local inner = achievs:Add("DPanel")
				inner:SetPos(8, 32)
				inner:SetSize(achievs:GetWide() - 16, achievs:GetTall() - 40)
				inner.Paint = jcms.offgame_paint_TBAPanel
			-- }}}
		end

		function jcms.offgame_CreateSocialPanel(parent, x, y, w, h)
			local socialmedia = parent:Add("DPanel")
			socialmedia:SetSize(w, h)
			socialmedia:SetPos(x, y)
			socialmedia.Paint = jcms.paint_Panel
			socialmedia.jText = "#jcms.oursocialmedia"

			local bsize = (w - 24 - 64) / 3
			local discord = socialmedia:Add("DButton")
			function discord:DoClick()
				gui.OpenURL("https://discord.gg/m5DBJrXjUf")
			end
			discord:SetSize(bsize, 32)
			discord:SetPos(32, 32)
			discord.jText = "Discord"
			discord.jColor = Color(114,137,218)
			discord.Paint = jcms.offgame_paint_SocialMediaButton

			local youtube = socialmedia:Add("DButton")
			function youtube:DoClick()
				gui.OpenURL("https://www.youtube.com/@octantisaddons")
			end
			youtube:SetSize(bsize, 32)
			youtube:SetPos(discord:GetX() + discord:GetWide() + 8, discord:GetY())
			youtube.jText = "YouTube"
			youtube.jColor = Color(255,0,51)
			youtube.Paint = jcms.offgame_paint_SocialMediaButton

			local vk = socialmedia:Add("DButton")
			function vk:DoClick()
				gui.OpenURL("https://vk.com/octantisaddons")
			end
			vk:SetSize(bsize, 32)
			vk:SetPos(youtube:GetX() + youtube:GetWide() + 8, youtube:GetY())
			vk.jText = "VK Group [RU]"
			vk.jColor = Color(0,119,255)
			vk.Paint = jcms.offgame_paint_SocialMediaButton

			local fetter = socialmedia:Add("DButton")
			function fetter:DoClick()
				gui.OpenURL("https://discord.gg/ThqwGkkZPz")
			end
			fetter:SetPos(discord:GetX() + discord:GetWide() / 2 - 18, discord:GetY() + discord:GetTall() + 8)
			fetter:SetSize(vk:GetX() - fetter:GetX() + vk:GetWide() / 2, 32)
			fetter.jText = language.GetPhrase("jcms.ourgame")
			fetter.jColor = Color(150, 150, 150)
			fetter.Paint = jcms.offgame_paint_SocialMediaButton

			return socialmedia
		end

		function jcms.offgame_BuildInfoTab(tab)
			-- Credits {{{
				local creditsContainer = tab:Add("DPanel")
				creditsContainer:SetPos(64, 32)
				creditsContainer:SetSize(700, 284)
				creditsContainer:SetPaintBackground(false)
				creditsContainer.switchTime = 1
				creditsContainer.switchInterval = 5
				creditsContainer.switchAnim = 0
				creditsContainer.switchIsTesters = false
				function creditsContainer:Think()
					local dt = RealFrameTime()

					self.switchTime = self.switchTime + dt
					if self.switchTime > self.switchInterval then
						self.switchTime = self.switchTime - self.switchInterval
						self.switchIsTesters = not self.switchIsTesters
					end

					self.switchAnim = math.Approach(self.switchAnim, self.switchIsTesters and 1 or 0, dt * 1.41)
					for i, child in ipairs(creditsContainer:GetChildren()) do
						if child.baseX then
							child:SetX( child.baseX - math.ease.InOutCubic(self.switchAnim)*(creditsContainer:GetWide() + 8) )
						end
					end
				end

				local clickSwitch = function(pnl)
					if IsValid(pnl) and (pnl == creditsContainer or pnl:GetParent() == creditsContainer) then
						creditsContainer.switchIsTesters = not creditsContainer.switchIsTesters
						creditsContainer.switchTime = -20
					end
				end

				creditsContainer.OnMousePressed = clickSwitch

				local devs = creditsContainer:Add("DPanel")
				devs.Paint = jcms.offgame_paint_CreditsPanelDevs
				devs:SetPos(0, 0)
				devs:SetSize(700, creditsContainer:GetTall())
				devs.baseX = devs:GetX()
				devs.OnMousePressed = clickSwitch
				
				local testers = creditsContainer:Add("DPanel")
				testers.Paint = jcms.offgame_paint_CreditsPanelPeopleList
				testers.jText = "#jcms.credits_testers"
				testers.peopleList = { "AlexTTP", "traeesen", "baggieman", "Doorsday", "Beaver Eater", "Rajack", "Xelerax", "LeSeiL", "Stasya Gubo", "ak3misan", "Marum", "kazzigum1", "D-BOI-9341", "Commander \"Andrew\" Kettle", "thecraftianman" }
				table.sort(testers.peopleList)
				testers.columnCount = 1
				testers:SetPos(devs:GetWide() + 8, 0)
				testers:SetSize(256, creditsContainer:GetTall())
				testers.baseX = testers:GetX()
				testers.OnMousePressed = clickSwitch

				local thanks = creditsContainer:Add("DPanel")
				thanks.jText = "#jcms.credits_thanks"
				thanks.peopleList = { "UberJ", "Acheron Panda", "Ady", "Basto3456", "bonsto", "CadetTrev", "lordpatek", "luigikart87", "Malyko", "mr.murdersalot", "oreiboon", "sgt_sas1905", "TalonSolid/Redline", "TH3LOAD3R", "TheOfficialJaydee", "Triaki", "nonsensicalhumanoid", "Szabi", "emnil", "paulchartres", "Endy0396", "Marum", "Pushnidze", "thecraftianman", "Redox", "boblikut" }
				table.sort(thanks.peopleList)
				thanks.Paint = jcms.offgame_paint_CreditsPanelPeopleList
				thanks.columnCount = 2
				thanks:SetPos(testers:GetX() + testers:GetWide() + 8, 0)
				thanks:SetSize(devs:GetWide() - testers:GetWide() - 8, testers:GetTall())
				thanks.baseX = thanks:GetX()
				thanks.OnMousePressed = clickSwitch
			-- }}}

			-- Social Media {{{
				local socialmedia = jcms.offgame_CreateSocialPanel(tab, 64, tab:GetTall() - 128, 700, 128)
			-- }}}

			-- Other content {{{
				local other = tab:Add("DPanel")
				other:SetPos(72, creditsContainer:GetY() + creditsContainer:GetTall() + 8)
				other:SetSize(700, socialmedia:GetY() - other:GetY() - 16)
				other.Paint = jcms.paint_Panel
				other.jText = "#jcms.othercontent"
				other.jFont = "jcms_big"

				local scroller = other:Add("DScrollPanel")
				scroller:SetPos(24, 48)
				scroller:SetSize(other:GetWide() - 48, other:GetTall() - 48 - 24)
				function scroller:Think()
					if IsValid(self.VBar) then
						self.VBar.Paint = BLANK_DRAW
						self.VBar:SetHideButtons(true)
						self.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
					end
				end

				if GetConVar("gmod_language"):GetString():lower() == "ru" then
					-- TODO Codex & bestiary translations are coming in future versions
					local disclaimer = scroller:Add("DLabel")
					disclaimer:SetText("ВНИМАНИЕ: перевод Кодекса и Бестиария на русский пока отложены. Прошу потерпеть! -MerekiDor")
					disclaimer:SetPos(24, 8)
					disclaimer:SizeToContents()
					disclaimer:SetTextColor(jcms.color_bright)
				end

				local bCodex = scroller:Add("DButton")
				bCodex:SetPos(24, 24)
				bCodex:SetSize(scroller:GetWide() - 48, 32)
				bCodex:SetText("#jcms.codex")
				bCodex.jFont = "jcms_medium"
				bCodex.Paint = jcms.paint_ButtonSmall
				function bCodex:DoClick()
					surface.PlaySound("buttons/button15.wav")

					for i, c in ipairs(tab:GetChildren()) do
						c:Remove()
					end

					jcms.offgame_BuildCodexTab(tab)
				end

				local bBestiary = scroller:Add("DButton")
				bBestiary:SetPos(24, bCodex:GetY() + bCodex:GetTall() + 4)
				bBestiary:SetSize(scroller:GetWide() - 48, 32)
				bBestiary:SetText("#jcms.bestiary")
				bBestiary.jFont = "jcms_medium"
				bBestiary.Paint = jcms.paint_ButtonSmall
				function bBestiary:DoClick()
					surface.PlaySound("buttons/button15.wav")

					for i, c in ipairs(tab:GetChildren()) do
						c:Remove()
					end

					jcms.offgame_BuildBestiaryTab(tab)
				end

				local bOctantisAddons = scroller:Add("DButton")
				bOctantisAddons:SetPos(24, bBestiary:GetY() + bBestiary:GetTall() + 24)
				bOctantisAddons:SetSize(scroller:GetWide() - 48, 32)
				bOctantisAddons:SetText("#jcms.extra_othermods")
				bOctantisAddons.jFont = "jcms_medium"
				bOctantisAddons.Paint = jcms.paint_ButtonSmall
				function bOctantisAddons:DoClick()
					gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3522266760")
				end

				local bRecMaps = scroller:Add("DButton")
				bRecMaps:SetPos(24, bOctantisAddons:GetY() + bOctantisAddons:GetTall() + 4)
				bRecMaps:SetSize(scroller:GetWide() - 48, 32)
				bRecMaps:SetText("#jcms.extra_maps")
				bRecMaps.jFont = "jcms_medium"
				bRecMaps.Paint = jcms.paint_ButtonSmall
				function bRecMaps:DoClick()
					gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3522258079")
				end

				local bExpansions = scroller:Add("DButton")
				bExpansions:SetPos(24, bRecMaps:GetY() + bRecMaps:GetTall() + 4)
				bExpansions:SetSize(scroller:GetWide() - 48, 32)
				bExpansions:SetText("#jcms.extra_expansions")
				bExpansions.jFont = "jcms_medium"
				bExpansions.Paint = jcms.paint_ButtonSmall
				function bExpansions:DoClick()
					gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3522259761")
				end

				local bCompAddons = scroller:Add("DButton")
				bCompAddons:SetPos(24, bExpansions:GetY() + bExpansions:GetTall() + 4)
				bCompAddons:SetSize(scroller:GetWide() - 48, 32)
				bCompAddons:SetText("#jcms.extra_compatibles")
				bCompAddons.jFont = "jcms_medium"
				bCompAddons.Paint = jcms.paint_ButtonSmall
				function bCompAddons:DoClick()
					gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3522262227")
				end

				local bLegal1 = scroller:Add("DButton")
				bLegal1:SetPos(24, bCompAddons:GetY() + bCompAddons:GetTall() + 4 + 24)
				bLegal1:SetSize((scroller:GetWide() - 48)/2 - 2, 32)
				bLegal1:SetText("#jcms.extra_legal1")
				bLegal1.jFont = "jcms_medium"
				bLegal1.Paint = jcms.paint_ButtonSmall
				function bLegal1:DoClick()
					surface.PlaySound("buttons/button15.wav")

					for i, c in ipairs(tab:GetChildren()) do
						c:Remove()
					end

					jcms.offgame_BuildLegalTab(tab, 1)
				end

				local bLegal2 = scroller:Add("DButton")
				bLegal2:SetPos(bLegal1:GetX() + bLegal1:GetWide() + 4, bLegal1:GetY())
				bLegal2:SetSize(bLegal1:GetSize())
				bLegal2:SetText("#jcms.extra_legal2")
				bLegal2.jFont = "jcms_medium"
				bLegal2.Paint = jcms.paint_ButtonSmall
				function bLegal2:DoClick()
					surface.PlaySound("buttons/button15.wav")

					for i, c in ipairs(tab:GetChildren()) do
						c:Remove()
					end

					jcms.offgame_BuildLegalTab(tab, 2)
				end

				local bGit = scroller:Add("DButton")
				bGit:SetPos(24, bLegal2:GetY() + bLegal2:GetTall() + 4)
				bGit:SetSize(scroller:GetWide() - 48, 32)
				bGit:SetText("#jcms.extra_github")
				bGit.jFont = "jcms_medium"
				bGit.Paint = jcms.paint_ButtonSmall
				function bGit:DoClick()
					gui.OpenURL("https://github.com/MerekiDor/mapsweepers")
				end
			-- }}}
		end

		function jcms.offgame_BuildCodexTab(tab)
			local listPanel = tab:Add("DPanel")
			listPanel:SetSize(700, tab:GetTall() / 2.5 - 32)
			listPanel:SetPos(32, tab:GetTall() - listPanel:GetTall() - 32)
			listPanel.Paint = jcms.paint_Panel
			listPanel.jText = "#jcms.codex"
			local scrollArea = listPanel:Add("DScrollPanel")
			scrollArea:SetPos(8, 32)
			scrollArea:SetSize(listPanel:GetWide() - 16, listPanel:GetTall() - 32 - 8)

			local textArea = tab:Add("DPanel")
			textArea:SetPos(64, 48)
			textArea:SetWide(700)
			textArea:SetTall(listPanel:GetY() - textArea:GetY() - 24)
			textArea.Paint = jcms.paint_Panel
			textArea.jText = "#jcms.codex"
			local scrollAreaText = textArea:Add("DScrollPanel")
			scrollAreaText:SetPos(16, 48)
			scrollAreaText:SetSize(textArea:GetWide() - 32, textArea:GetTall() - 48 - 8)

			local mylevel = jcms.statistics_GetLevel()
			local function cdxBtnFunc(btn)
				textArea.jText = btn.cdx.name
				surface.PlaySound("buttons/button1.wav")

				local entry = btn.cdx.entry
				for i, child in ipairs(scrollAreaText:GetCanvas():GetChildren()) do
					if child.isEntry then
						child:Remove()
					end
				end

				for i,v in ipairs(entry) do
					local elem

					if v.type == "title" then
						elem = scrollAreaText:Add("DLabel")
						elem:SetFont("jcms_hud_small")
						elem:SetText(v.text)
						elem:SetTextColor(jcms.color_bright)
						elem:DockMargin(0, i==1 and 2 or 12, 0, 6)
						elem:SetTall(32)
					elseif v.type == "caption" then
						elem = scrollAreaText:Add("DLabel")
						elem:SetFont("jcms_medium")
						elem:SetText(v.text)
						elem:SetTextColor(ColorAlpha(jcms.color_bright, 100))
						elem:DockMargin(0, 2, 0, 4)
					elseif v.type == "text" then
						elem = scrollAreaText:Add("DTextEntry")
						elem:SetFont("jcms_small_bolder")
						elem:SetTextColor(jcms.color_bright)
						elem:SetMultiline(true)
						elem:DockMargin(8, 4, 64, 4)
						
						local text = "  " .. tostring(v.text)
						elem:SetText(text)
						elem:SetEditable(false)
						elem:SetPaintBackground(false)
						surface.SetFont("jcms_small_bolder")
						local tw, th = surface.GetTextSize(text)
						elem:SetTall(th * math.ceil( tw/(listPanel:GetWide()-128) ) + 8)
					elseif v.type == "list_numbered" then
						for j,e in ipairs(v.entries) do
							local subelem = scrollAreaText:Add("DLabel")
							subelem:SetFont("jcms_small_bolder")
							subelem:SetText(j .. ".  " .. tostring(e))
							subelem:SetTextColor(jcms.color_bright)
							subelem:DockMargin(24, 0, 0, 0)
							subelem:Dock(TOP)
							subelem:SetZPos(i*30+j)
							subelem.isEntry = true
						end
					elseif v.type == "list_points" then
						for j,e in ipairs(v.entries) do
							subelem = scrollAreaText:Add("DTextEntry")
							subelem:SetFont("jcms_small_bolder")
							subelem:SetTextColor(jcms.color_bright)
							subelem:SetMultiline(true)
							subelem:DockMargin(8, 4, 64, 4)
							
							local text = "* " .. tostring(e)
							subelem:SetText(text)
							subelem:SetEditable(false)
							subelem:SetPaintBackground(false)
							surface.SetFont("jcms_small_bolder")
							local tw, th = surface.GetTextSize(text)
							subelem:SetTall(th * math.ceil( tw/(listPanel:GetWide()-96) ) + 8)

							subelem:DockMargin(24, 0, 0, 0)
							subelem:Dock(TOP)
							subelem:SetZPos(i*30+j)
							subelem.isEntry = true
						end
					end

					if elem then
						elem:Dock(TOP)
						elem:SetZPos(i*30)
						elem.isEntry = true
					end

					if IsValid(scrollAreaText.VBar) then
						scrollAreaText.VBar.Paint = BLANK_DRAW
						scrollAreaText.VBar:SetHideButtons(true)
						scrollAreaText.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
					end
				end
			end

			for i, cdx in ipairs( jcms.codex ) do
				local btn = scrollArea:Add("DButton")
				btn:Dock(TOP)
				btn:DockMargin(0, 0, 0, 4)
				btn:SetTall(32)
				btn:SetEnabled(mylevel >= cdx.level)
				btn.index = i
				btn.level = cdx.level
				btn.cdx = cdx
				btn.Paint = jcms.offgame_paint_CodexButton
				btn.DoClick = cdxBtnFunc
			end

			local tba = scrollArea:Add("DPanel")
			tba:Dock(TOP)
			tba:DockMargin(0, 0, 0, 4)
			tba:SetTall(48)
			tba.Paint = jcms.offgame_paint_TBAPanel
		end

		function jcms.offgame_BuildBestiaryTab(tab)
			local listPanel = tab:Add("DPanel")
			listPanel:SetSize(220, tab:GetTall() - 64)
			listPanel:SetPos(32, 32)
			listPanel.Paint = jcms.paint_Panel
			listPanel.jText = "#jcms.bestiary"
			local scrollArea = listPanel:Add("DScrollPanel")
			scrollArea:SetPos(8, 32)
			scrollArea:SetSize(listPanel:GetWide() - 16, listPanel:GetTall() - 32 - 8)
			
			local imageArea = tab:Add("DPanel")
			imageArea:SetPos(220 + 32 + 16, 48)
			imageArea:SetSize(500, 300)
			imageArea.Paint = BLANK_DRAW
			imageArea.PaintOver = jcms.offgame_paint_BestiaryImageArea
			imageArea.jText = "#jcms.bestiaryselectnpc"
			imageArea.jFont = "jcms_big"
			imageArea.factionMat = Material("jcms/factions/any.png")
			imageArea.anim = 0
			local model = imageArea:Add("DModelPanel")
			model:SetPos(8, 8)
			model:SetSize(380, imageArea:GetTall() - 16)
			model:SetCamPos( Vector(180, 180, 72) )
			model:SetFOV(38)
			function model:LayoutEntity(ent)
				ent:SetAngles( Angle(0, 360 / (imageArea.anim*3 + 1) + 60, 0) )
				local amplifiedColor = Color(jcms.color_bright:Unpack())
				local amp = Lerp(math.Clamp(imageArea.anim, 0, 1), 2, 1.3)
				amplifiedColor.r = amplifiedColor.r^amp
				amplifiedColor.g = amplifiedColor.g^amp
				amplifiedColor.b = amplifiedColor.b^amp
				self:SetDirectionalLight(BOX_BOTTOM, amplifiedColor)
			end

			imageArea.modelPanel = model
			local descArea = tab:Add("DPanel")
			descArea:SetPos(imageArea:GetX() + 24, imageArea:GetY() + imageArea:GetTall() + 24)
			descArea:SetSize(530, tab:GetTall() - descArea:GetTall() - descArea:GetY() - 32)
			descArea.Paint = jcms.offgame_paint_BestiaryDescription

			local factions = {}
			local bestiaryData = {}
			for name, entry in pairs(jcms.bestiary) do
				if bestiaryData[ entry.faction ] then
					table.insert(bestiaryData[ entry.faction ], name)
				else
					table.insert(factions, entry.faction)
					bestiaryData[ entry.faction ] = { name }
				end
			end

			table.sort(factions)
			for faction, entryNames in pairs(bestiaryData) do
				table.sort(entryNames, function(firstName, lastName)
					local e1, e2 = jcms.bestiary[ firstName ], jcms.bestiary[ lastName ]
					return e1.bounty < e2.bounty
				end)
			end

			local function entryBtnFunc(b)
				surface.PlaySound("buttons/combine_button2.wav")
				local entry = jcms.bestiary[ b.entryName ]
				imageArea.entry = entry
				imageArea.entryName = language.GetPhrase("#jcms.bestiary_" .. b.entryName)
				imageArea.factionMat = Material("jcms/factions/" .. tostring(entry.faction) .. ".png")
				imageArea.anim = 0
				
				descArea.name = language.GetPhrase("jcms.bestiary_" .. b.entryName)
				descArea.jText = language.GetPhrase("jcms.bestiary_" .. b.entryName .. "_desc")
				descArea.markup = nil

				if type(entry.doModel) == "function" then
					entry.doModel(model)
				else
					local entity = model:GetEntity()
					if not IsValid(entity) then
						model:SetModel(entry.mdl)
						entity = model:GetEntity()
					else
						entity:SetModel(entry.mdl)
					end
					entity:SetModelScale(entry.scale or 1)
					entity:SetSkin(entry.skin or 0)
					if entry.matrix then
						entity:EnableMatrix("RenderMultiply", entry.matrix)
					else
						entity:DisableMatrix("RenderMultiply")
					end
					model:SetColor(entry.color or color_white)

					local idleSeq = entry.seq or 0
					if idleSeq == 0 then
						for i, sq in ipairs(entity:GetSequenceList()) do
							if sq:lower():find("idle") then
								idleSeq = i
								break
							end
						end
					end
					entity:SetSequence(idleSeq)

					for i=0, 31 do
						local mat = entry.mats and entry.mats[i + 1] or ""
						entity:SetSubMaterial(i, mat)
					end
					
					entity:SetBodyGroups( string.rep("0", 32) )
					if entry.bodygroups then
						for bodygroupId, submodelId in pairs(entry.bodygroups) do
							entity:SetBodygroup(bodygroupId, submodelId)
						end
					end
				end

				model.PreDrawModel = function() if entry.preDrawModel then entry.preDrawModel(model:GetEntity()) end end
				model.PostDrawModel = function() if entry.postDrawModel then entry.postDrawModel(model:GetEntity()) end end

				model:SetFOV( entry.camfov or 38 )
				model:SetLookAt(entry.camlookvector or model:GetEntity():WorldSpaceCenter())
			end

			for i, faction in ipairs(factions) do
				local b = scrollArea:Add("DButton")
				b:SetText("#jcms." .. faction)
				b:Dock(TOP)
				b:DockMargin(0, 12, 0, 4)
				b:SetEnabled(false)
				b.jFont = "jcms_medium"
				b.Paint = jcms.paint_ButtonFilled

				local entryNames = bestiaryData[ faction ]
				for j, entryName in ipairs(entryNames) do
					local entry = jcms.bestiary[ entryName ]
					local b = scrollArea:Add("DButton")
					b:SetText(language.GetPhrase("jcms.bestiary_"..entryName))
					b:Dock(TOP)
					b:DockMargin(0, 0, 0, 4)
					b.entryName = entryName
					b.DoClick = entryBtnFunc
					b.Paint = jcms.paint_ButtonSmall
				end
			end

			if IsValid(scrollArea.VBar) then
				scrollArea.VBar.Paint = BLANK_DRAW
				scrollArea.VBar:SetHideButtons(true)
				scrollArea.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
			end
		end

		function jcms.offgame_BuildLegalTab(tab, id)
			-- id 1: Map Sweepers
			-- id 2: Font

			local text = tab:Add("DTextEntry")
			text:SetMultiline(true)
			text:SetSize(500, id == 2 and 72 or 250)
			text:SetPos(32, 48)
			text:SetEditable(false)
			text:SetPaintBackground(false)
			text:SetTextColor(jcms.color_bright)
			text:SetText(id == 1 and language.GetPhrase("jcms.license_notice") or language.GetPhrase("jcms.license_notice_font"))

			local contents = id == 1 and jcms.gnugplv3_license or jcms.ofl_license
			local licensetext = tab:Add("DTextEntry")
			licensetext:SetMultiline(true)
			licensetext:SetPos(48, text:GetY() + text:GetTall() + 8)
			licensetext:SetSize(id ==2 and 510 or 460, tab:GetTall() - licensetext:GetY())
			licensetext:SetText(contents)
			licensetext:SetVerticalScrollbarEnabled(true)
			function licensetext:OnChange()
				self:SetText(contents)
			end
		end

		function jcms.offgame_BuildOptionsTab(tab)
			local hasButtons = LocalPlayer():IsAdmin()
			local bClient, bServer

			if hasButtons then
				bClient = tab:Add("DButton")
				bClient:SetPos(32, 24)
				bClient:SetSize(300, 32)
				bClient:SetText("#jcms.opt_tab_client")
				bClient.jFont = "jcms_medium"
				bClient.Paint = jcms.paint_ButtonFilled

				bServer = tab:Add("DButton")
				bServer:SetPos(bClient:GetX() + bClient:GetWide() + 4, bClient:GetY())
				bServer:SetSize(300, 24)
				bServer:SetText("#jcms.opt_tab_server")
				bServer.jFont = "jcms_medium"
				bServer.Paint = jcms.paint_Button
			end

			-- Client {{{
				local tabClient = tab:Add("DPanel")
				tabClient:SetPos(48, hasButtons and 72 or 24)
				tabClient:SetSize(512, tab:GetTall() - 24 - tabClient:GetY())
				tabClient:SetPaintBackground(false)

				local catList = tabClient:Add("DCategoryList")
				catList:SetSize(tabClient:GetSize())
				catList:SetBackgroundColor( Color(0, 0, 0, 0) )
				function catList:Think()
					if IsValid(self.VBar) then
						self.VBar.Paint = BLANK_DRAW
						self.VBar:SetHideButtons(true)
						self.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
					end
				end

				local contentSize = catList:GetWide()
				-- Preferences {{{
				do
					local bar = catList:Add("#jcms.opt_preferences")
					bar.Paint = jcms.paint_Category
					bar.dontSubtractHeight = true
					local content = vgui.Create("DPanel", bar)
					content:SetPaintBackground(false)
					content:DockPadding(0, 0, 0, 16)
					bar:SetContents(content)

					local checkboxes = { 
						{ loc = "announcer", cvar = "announcer" },
						{ loc = "imperial", cvar = "imperial" },
						{ loc = "motionsickness", cvar = "motionsickness" },
						{ loc = "nomusic", cvar = "nomusic" },
						{ loc = "novignette", cvar = "hud_novignette" },
						{ loc = "nocolourfilter", cvar = "hud_nocolourfilter" },
						{ loc = "noneardeathfilter", cvar = "hud_noneardeathfilter" }
					}
					
					for i, cbdata in ipairs(checkboxes) do
						local cb = content:Add("DCheckBoxLabel")
						cb:SetPos(24, 16 + 24 * (i-1))
						cb:SetText("#jcms.opt_" .. cbdata.loc)
						cb:SetWide(400)
						cb:SetConVar("jcms_" .. cbdata.cvar)
						cb.Paint = jcms.paint_CheckBoxLabel
					end
				end
				-- }}}

				-- HUD {{{
					do
						local bar = catList:Add("#jcms.opt_customizehud")
						bar.Paint = jcms.paint_Category
						bar.dontSubtractHeight = true
						local content = vgui.Create("DPanel", bar)
						content:SetPaintBackground(false)
						content:DockPadding(0, 0, 0, 16)
						content.selectedColor = "bright"
						bar:SetContents(content)
		
						local scale = content:Add("DNumSlider")
						scale:SetText("#jcms.opt_hudscale")
						scale:SetSize(contentSize - 48, 24)
						scale:SetPos(24, 24)
						scale:SetMinMax(0.5, 2)
						scale:SetConVar("jcms_hud_scale")
						scale.Paint = jcms.paint_NumSlider

						local mixer = content:Add("DColorMixer")

						local function clrBtnFunc(b)
							content.selectedColor = b.colorName
							local clr = jcms["color_" .. b.colorName]
			
							if clr then
								surface.PlaySound("buttons/button15.wav")
								mixer:SetColor(clr)
							end
						end

						for i, clrName in ipairs { "bright", "bright_alt", "alert1", "dark", "dark_alt", "alert2" } do
							local x = (i - 1) % 3
							local y = math.floor( (i - 1) / 3 )

							local btn = content:Add("DButton")
							btn:SetSize(72, 24)
							btn:SetPos(24 + x * (btn:GetWide() + 4) + y * 8, 64 + y * (btn:GetTall() + 4))
							btn.Paint = jcms.paint_ButtonColor
							btn.colorName = clrName
							btn.DoClick = clrBtnFunc
						end

						mixer:SetWangs(false)
						mixer:SetPalette(false)
						mixer:SetAlphaBar(false)
						mixer:SetColor(jcms.color_bright)
						mixer:SetPos(400 - 48, 64)
						mixer:SetSize(128 + 12, 128 - 12)
						function mixer:ValueChanged(col)
							local id = tostring(content.selectedColor)
							local cvar = jcms.color_convars["jcms_hud_color_" .. id]

							if cvar and jcms["color_" .. id] then
								cvar:SetString( ("%d %d %d"):format( col:Unpack() ) )
							end
						end

						local rng = content:Add("DButton")
						rng:SetText("#jcms.opt_color_randomize")
						rng:SetSize(230, 18)
						rng:SetPos(32, 128)
						rng.Paint = jcms.paint_ButtonFilled
						function rng:DoClick()
							local cvar_bright = jcms.color_convars["jcms_hud_color_bright"]
							local cvar_dark = jcms.color_convars["jcms_hud_color_dark"]
							
							if cvar_bright and cvar_dark then
								local bright = HSVToColor( math.random() * 360, 0.5 + math.random() * 0.5, 0.8 + math.random() * 0.2 )
								local dark = Color( bright.r * math.Rand(0.15, 0.25), bright.g * math.Rand(0.15, 0.25), bright.b * math.Rand(0.15, 0.25) )

								cvar_bright:SetString( ("%d %d %d"):format( bright:Unpack() ) )
								cvar_dark:SetString( ("%d %d %d"):format( dark:Unpack() ) )
							end

							local cvar_bright_alt = jcms.color_convars["jcms_hud_color_bright_alt"]
							local cvar_dark_alt = jcms.color_convars["jcms_hud_color_dark_alt"]
							
							if cvar_bright_alt and cvar_dark_alt then
								local bright_alt = HSVToColor( math.random() * 360, 0.5 + math.random() * 0.5, 0.8 + math.random() * 0.2 )
								local dark_alt = Color( bright_alt.r * math.Rand(0.15, 0.25), bright_alt.g * math.Rand(0.15, 0.25), bright_alt.b * math.Rand(0.15, 0.25) )

								cvar_bright_alt:SetString( ("%d %d %d"):format( bright_alt:Unpack() ) )
								cvar_dark_alt:SetString( ("%d %d %d"):format( dark_alt:Unpack() ) )
							end

							local cvar_alert1 = jcms.color_convars["jcms_hud_color_alert1"]
							local cvar_alert2 = jcms.color_convars["jcms_hud_color_alert2"]
							
							if cvar_alert1 and cvar_alert2 then
								local hue = math.random() * 360
								local alert1 = HSVToColor( hue, 0.5 + math.random() * 0.5, 0.8 + math.random() * 0.2 )
								local alert2 = HSVToColor( hue + math.Rand(-30, 30), 0.5 + math.random() * 0.5, 0.8 + math.random() * 0.2 )

								cvar_alert1:SetString( ("%d %d %d"):format( alert1:Unpack() ) )
								cvar_alert2:SetString( ("%d %d %d"):format( alert2:Unpack() ) )
							end
							
							surface.PlaySound("npc/dog/dog_servo7.wav")
						end

						local adj = content:Add("DButton")
						adj:SetText("#jcms.opt_color_adjust")
						adj:SetSize(230, 18)
						adj:SetPos(48, rng:GetY() + rng:GetTall() + 4)
						adj.Paint = jcms.paint_ButtonFilled
						function adj:DoClick()
							local cvar1 = jcms.color_convars["jcms_hud_color_dark"]
							if cvar1 then
								local r,g,b = jcms.color_bright:Unpack()
								cvar1:SetString( ("%d %d %d"):format( r * 0.15, g * 0.15, b * 0.15 ) )
							end

							local cvar2 = jcms.color_convars["jcms_hud_color_dark_alt"]
							if cvar2 then
								local r,g,b = jcms.color_bright_alt:Unpack()
								cvar2:SetString( ("%d %d %d"):format( r * 0.2, g * 0.2, b * 0.2 ) )
							end

							surface.PlaySound("npc/dog/dog_servo7.wav")
						end

						local res = content:Add("DButton")
						res:SetText("#jcms.opt_color_reset")
						res:SetSize(230, 18)
						res:SetPos(32, adj:GetY() + adj:GetTall() + 4)
						res.Paint = jcms.paint_ButtonFilled
						function res:DoClick()
							jcms.hud_SetTheme(jcms.playerfactions_players[ LocalPlayer().__s64hash ] or "jcorp")
							surface.PlaySound("npc/scanner/cbot_servoscared.wav")
						end
					end
				-- }}}

				-- Crosshair {{{
					do
						local bar = catList:Add("#jcms.opt_crosshair")
						bar.Paint = jcms.paint_Category
						bar.dontSubtractHeight = true
						local content = vgui.Create("DPanel", bar)
						content:SetPaintBackground(false)
						content:DockPadding(0, 0, 0, 16)
						bar:SetContents(content)
						
						local preview = content:Add("DPanel")
						preview:SetSize(72, 72)
						preview:SetPos(contentSize - 72 - 32, 16)
						preview.Paint = jcms.offgame_paint_CrosshairPreview

						local style = content:Add("DNumSlider")
						style:SetText("#jcms.opt_crosshair_style")
						style:SetSize(contentSize - 48 - preview:GetWide() - 16, 24)
						style:SetPos(24, 24)
						style:SetMinMax(0, 4)
						style:SetDecimals(0)
						style:SetConVar("jcms_crosshair_style")
						style.Paint = jcms.paint_NumSlider

						local ammo = content:Add("DNumSlider")
						ammo:SetText("#jcms.opt_crosshair_showammo")
						ammo:SetSize(contentSize - 48 - preview:GetWide() - 16, 24)
						ammo:SetPos(24, 24 + 24)
						ammo:SetMinMax(0, 4)
						ammo:SetDecimals(0)
						ammo:SetConVar("jcms_crosshair_ammo")
						ammo.Paint = jcms.paint_NumSlider

						local ammodesc = content:Add("DLabel")
						ammodesc:SetTextColor(jcms.color_bright)
						ammodesc:SetPos(ammo:GetX() + 164, ammo:GetY() + 8)
						ammodesc:SetSize(ammo:GetWide() - 164, 48)
						function ammodesc:Think()
							self:SetText(language.GetPhrase("#jcms.opt_crosshair_showammo" .. math.floor(ammo:GetValue())))
						end

						local dot = content:Add("DCheckBoxLabel")
						dot:SetPos(24, ammo:GetY() + ammo:GetTall() + 24)
						dot:SetText("#jcms.opt_crosshair_dot")
						dot:SetWide(400)
						dot:SetConVar("jcms_crosshair_dot")
						dot.Paint = jcms.paint_CheckBoxLabel

						for i, var in ipairs { "length", "width", "gap" } do
							local slider = content:Add("DNumSlider")
							slider:SetText("#jcms.opt_crosshair_" .. var)
							slider:SetSize(400, 24)
							slider:SetPos(24, dot:GetY() + dot:GetTall() + 8 + 24*(i-1))
							slider:SetMinMax(1, i==1 and 64 or 8)
							slider:SetDecimals(0)
							slider:SetConVar("jcms_crosshair_" .. var)
							slider.Paint = jcms.paint_NumSlider
						end
					end
				-- }}}
			-- }}

			if hasButtons then
				-- Server {{{
					local tabServer = tab:Add("DPanel")
					tabServer:SetPos(48, 72)
					tabServer:SetSize(512, tab:GetTall() - 24 - tabServer:GetY())
					tabServer:SetPaintBackground(false)
					tabServer:SetVisible(false)

					local catList = tabServer:Add("DCategoryList")
					catList:SetSize(tabServer:GetSize())
					catList:SetBackgroundColor( Color(0, 0, 0, 0) )
					function catList:Think()
						if IsValid(self.VBar) then
							self.VBar.Paint = BLANK_DRAW
							self.VBar:SetHideButtons(true)
							self.VBar.btnGrip.Paint = jcms.paint_ScrollGrip
						end
					end

					local contentSize = catList:GetWide()
					-- Common settings {{{
						do
							local bar = catList:Add("#jcms.opt_commonsettings")
							bar.Paint = jcms.paint_Category
							bar.dontSubtractHeight = true
							local content = vgui.Create("DPanel", bar)
							content:SetPaintBackground(false)
							content:DockPadding(0, 0, 0, 16)
							bar:SetContents(content)
		
							local cb
							cb = content:Add("DCheckBoxLabel")
							cb:SetPos(24, 16)
							cb:SetText("#jcms.opt_noepisodes")
							cb:SetWide(400)
							cb:SetConVar("jcms_noepisodes")
							cb.Paint = jcms.paint_CheckBoxLabel

							local scale = content:Add("DNumSlider")
							scale:SetText("#jcms.opt_ffmul")
							scale:SetSize(contentSize - 48, 24)
							scale:SetPos(24, 24 + 16)
							scale:SetMinMax(0, 2)
							scale:SetConVar("jcms_friendlyfire_multiplier")
							scale.Paint = jcms.paint_NumSlider

							local softcap = content:Add("DNumSlider")
							softcap:SetText("#jcms.opt_softcap")
							softcap:SetSize(contentSize - 48, 24)
							softcap:SetPos(24, 24*2 + 32)
							softcap:SetMinMax(1, 100)
							softcap:SetDecimals(0)
							softcap:SetConVar("jcms_npc_softcap")
							softcap.Paint = jcms.paint_NumSlider
							local softcap_clarify = content:Add("DTextEntry")
							softcap_clarify:SetPos(softcap:GetX() + 16, softcap:GetY() + softcap:GetTall() + 4)
							softcap_clarify:SetSize(contentSize - 32 - softcap_clarify:GetX(), 84)
							softcap_clarify:SetMultiline(true)
							softcap_clarify:SetEditable(false)
							softcap_clarify:SetFont("jcms_small")
							softcap_clarify:SetPaintBackground(false)
							softcap_clarify:SetTextColor(jcms.color_pulsing)
							softcap_clarify.PaintOver = jcms.paintover_PanelClarify
							softcap_clarify:SetText(language.GetPhrase("jcms.opt_softcap_desc1") .. "\n" .. language.GetPhrase("jcms.opt_softcap_desc2"))
						end
					-- }}}

					-- Map Rotation {{{
						do
							local bar = catList:Add("#jcms.opt_maps")
							bar.Paint = jcms.paint_Category
							bar.dontSubtractHeight = true
							local content = vgui.Create("DPanel", bar)
							content:SetPaintBackground(false)
							content:DockPadding(0, 0, 0, 16)
							bar:SetContents(content)

							local p = jcms.offgame_CreateTextElement(content, 16, 16, contentSize - 32, 72, "", "jcms_map_list", 1)
							function p:Think()
								if not self.cachedCVar then
									self.cachedCVar = GetConVar("jcms_map_iswhitelist")
								end
								p.label:SetText("#jcms.opt_maplist_" .. (self.cachedCVar:GetBool() and "white" or "black"))
							end

							local cb
							cb = content:Add("DCheckBoxLabel")
							cb:SetPos(24, p:GetY() + p:GetTall() + 8)
							cb:SetText("#jcms.opt_maplist_iswhite")
							cb:SetWide(400)
							cb:SetConVar("jcms_map_iswhitelist")
							cb.Paint = jcms.paint_CheckBoxLabel

							cb = content:Add("DCheckBoxLabel")
							cb:SetPos(24, p:GetY() + p:GetTall() + 8 + 24)
							cb:SetText("#jcms.opt_mapexclude")
							cb:SetWide(400)
							cb:SetConVar("jcms_map_excludecurrent")
							cb.Paint = jcms.paint_CheckBoxLabel
						end
					-- }}}

					-- Cash Settings {{{
						do
							local bar = catList:Add("#jcms.opt_cashsettings")
							bar.Paint = jcms.paint_Category
							bar.dontSubtractHeight = true
							local content = vgui.Create("DPanel", bar)
							content:SetPaintBackground(false)
							content:DockPadding(0, 0, 0, 16)
							bar:SetContents(content)

							for i, n in ipairs { "start", "evac", "victory", "maxclerks" } do
								jcms.offgame_CreateTextElement(content, 24, 12+(i-1)*28, contentSize - 48, 28, "#jcms.opt_cash_"..n, "jcms_cash_"..n)
							end
								
							for i, n in ipairs { "mul_final", "mul_base", "mul_stunstick", "mul_very_far" } do
								jcms.offgame_CreateTextElement(content, 24, 12+(i-1+5)*28, contentSize - 48, 28, "#jcms.opt_cash_"..n, "jcms_cash_"..n)
							end

							for i, n in ipairs { "bonus_sidearm", "bonus_airborne", "bonus_headshot", "bonus_headshot_instakill" } do
								jcms.offgame_CreateTextElement(content, 24, 12+(i-1+10)*28, contentSize - 48, 28, "#jcms.opt_cash_"..n, "jcms_cash_"..n)
							end
						end
					-- }}}

					-- Weapon Prices {{{
						do
							local bar = catList:Add("#jcms.opt_weaponprices")
							bar.Paint = jcms.paint_Category
							bar.dontSubtractHeight = true
							local content = vgui.Create("DPanel", bar)
							content:SetPaintBackground(false)
							content:DockPadding(0, 0, 0, 16)
							bar:SetContents(content)

							local note = content:Add("DLabel")
							note:Dock(TOP)
							note:SetText("#jcms.opt_weaponprices_note")
							note:DockMargin(16, 16, 16, 4)
							note:SetTextColor(jcms.color_bright_alt)

							local listview = content:Add("DListView")
							listview:Dock(TOP)
							listview:DockMargin(8, 8, 8, 8)
							listview:SetTall(300)
							listview:AddColumn("#jcms.opt_weaponprices_class")
							listview:AddColumn("#jcms.opt_weaponprices_name")
							listview:AddColumn("#jcms.opt_weaponprices_base")
							listview:AddColumn("#jcms.opt_weaponprices_price")
							listview:AddColumn("#jcms.opt_weaponprices_shopprice")
							
							local wlist = weapons.GetList()
							for defclass, data in pairs(jcms.default_weapons_datas) do
								table.insert(wlist, data)
							end

							for i, gunData in ipairs(wlist) do
								if gunData.Spawnable then
									local class = gunData.ClassName
									local price = jcms.weapon_prices[class] or 0
									local success, gunStats = pcall(jcms.gunstats_GetExpensive, class)
									if success and gunStats then
										local l = listview:AddLine(class, gunStats.name, gunStats.base, price, math.ceil(price * jcms.util_GetLobbyWeaponCostMultiplier()))
										l.class = class
										l.price = price
										l.gunData = gunData
										l.gunStats = gunStats
									end
								end
							end

							listview:SortByColumn(1, false)
							function listview:OnRowRightClick()
								local selection = listview:GetSelected()

								local menu = DermaMenu()
								
								local title = menu:Add("DLabel")
								title:SetText(string.rep(" ", 4) .. language.GetPhrase("jcms.opt_weaponprices_selected"):format(#selection))
								title:SetWide(230)
								title:SetTextColor(color_black)
								title:SetFont("HudSelectionText")
								menu:AddPanel(title)
								menu:AddSpacer()

								menu:AddOption("#jcms.opt_weaponprices_disable", function()
									surface.PlaySound("buttons/button9.wav")
									for i,l in ipairs(selection) do
										local class = ""..l.class
										timer.Simple(i/50, function()
											RunConsoleCommand("jcms_setweaponprice", class, 0)

											if IsValid(l) and (l.class == class) then
												l:SetValue(4, 0)
												l:SetValue(5, 0)
											end
										end)
									end
								end):SetImage("icon16/cross.png")

								menu:AddOption("#jcms.opt_weaponprices_restore", function()
									surface.PlaySound("buttons/button9.wav")
									for i,l in ipairs(selection) do
										local class = ""..l.class
										timer.Simple(i/50, function()
											RunConsoleCommand("jcms_setweaponprice", class, -1)
										end)

										local mul = jcms.util_GetLobbyWeaponCostMultiplier()
										timer.Simple(i/50+0.65, function()
											if IsValid(l) and (l.class == class) then
												l.price = jcms.weapon_prices[class]
												l:SetValue(4, l.price or 0)
												l:SetValue(5, math.ceil(mul*(l.price or 0)))
											end
										end)
									end
								end):SetImage("icon16/arrow_undo.png")
								
								menu:AddSpacer()

								menu:AddOption("#jcms.opt_weaponprices_setmissionprice", function()
									surface.PlaySound("buttons/combine_button1.wav")

									Derma_StringRequest("#jcms.opt_weaponprices_setmissionprice", ("#jcms.opt_weaponprices_setmissionprice_desc"):format(#selection), "0", 
										function(v)
											local mul = jcms.util_GetLobbyWeaponCostMultiplier()
											v = tonumber(v:gsub("[%s%,]", ""), 10)
											surface.PlaySound("buttons/button9.wav")
											for i,l in ipairs(selection) do
												local class = ""..l.class
												timer.Simple(i/50, function()
													RunConsoleCommand("jcms_setweaponprice", class, v)
												end)

												timer.Simple(i/50+0.75, function()
													if IsValid(l) and (l.class == class) then
														l.price = jcms.weapon_prices[class]
														l:SetValue(4, l.price or 0)
														l:SetValue(5, math.ceil(mul*(l.price or 0)))
													end
												end)
											end
										end,
										function()
											surface.PlaySound("buttons/button16.wav")
										end,
										"#jcms.confirm",
										"#jcms.cancel"
									)
								end):SetImage("icon16/money.png")

								menu:AddOption("#jcms.opt_weaponprices_setlobbyprice", function()
									surface.PlaySound("buttons/combine_button1.wav")

									Derma_StringRequest("#jcms.opt_weaponprices_setlobbyprice", ("#jcms.opt_weaponprices_setlobbyprice_desc"):format(#selection), "0", 
										function(v)
											local mul = jcms.util_GetLobbyWeaponCostMultiplier()
											v = (tonumber(v:gsub("[%s%,]", ""), 10) / mul)
											if v>=10 and tostring(v):sub(-1,-1) == "0" then
												v = v - 1
											end

											surface.PlaySound("buttons/button9.wav")
											for i,l in ipairs(selection) do
												local class = ""..l.class
												timer.Simple(i/50, function()
													RunConsoleCommand("jcms_setweaponprice", class, v)
												end)

												timer.Simple(i/50+0.75, function()
													if IsValid(l) and (l.class == class) then
														l.price = jcms.weapon_prices[class]
														l:SetValue(4, l.price or 0)
														l:SetValue(5, math.ceil(mul*(l.price or 0)))
													end
												end)
											end
										end,
										function()
											surface.PlaySound("buttons/button16.wav")
										end,
										"#jcms.confirm",
										"#jcms.cancel"
									)
								end):SetImage("icon16/cart.png")

								menu:Open()
								surface.PlaySound("buttons/button15.wav")
							end
						end
					-- }}}

					-- Order Settings {{{
						do
							local bar = catList:Add("#jcms.opt_orders")
							bar.Paint = jcms.paint_Category
							bar.dontSubtractHeight = true
							local content = vgui.Create("DPanel", bar)
							content:SetPaintBackground(false)
							content:DockPadding(0, 0, 0, 16)
							bar:SetContents(content)

							local note = content:Add("DLabel")
							note:Dock(TOP)
							note:SetText("#jcms.opt_orders_note")
							note:DockMargin(16, 16, 16, 4)
							note:SetTextColor(jcms.color_bright_alt)

							local sortedOrders = table.GetKeys(jcms.orders)
							table.sort(sortedOrders, function(first, last)
								local firstData, lastData = jcms.orders[first], jcms.orders[last]
								if (firstData.category == lastData.category) then
									return (firstData.slotPos or 0) < (lastData.slotPos or 0)
								else
									return firstData.category < lastData.category
								end
							end)

							for i, orderId in ipairs(sortedOrders) do
								local orderData = jcms.orders[orderId]

								local pnl = content:Add("DPanel")
								pnl:Dock(TOP)
								pnl:DockMargin(4, 4, 4, 0)
								pnl:SetBackgroundColor(jcms.color_dark)
								pnl:SetTall(96)

								local label = pnl:Add("DLabel")
								label:SetText("#jcms." .. orderId)
								label:SetPos(6, 4)
								label:SetSize(400, 16)
								label:SetFont("jcms_small_bolder")
								label:SetTextColor(jcms.color_bright)

								local mat = jcms.orders_categoryMats[ orderData.category + 1 ]
								if mat then
									local img = pnl:Add("DImage")
									img:SetImage(mat:GetName() .. ".png")
									img:SetSize(32, 32)
									img:SetPos(6, 24)
									img:SetImageColor(jcms.color_bright)
								end

								local cost = jcms.offgame_CreateTextElement(pnl, 208, 4, 280, 32, "#jcms.opt_orders_cost")
								cost.entry:SetValue(orderData.cost)
								
								local cooldown = jcms.offgame_CreateTextElement(pnl, 208, 32+4, 280, 32, "#jcms.opt_orders_cooldown")
								cooldown.entry:SetValue(orderData.cooldown)

								local bApply = pnl:Add("DButton")
								bApply:SetPos(8, 96 - 24)
								bApply:SetSize(128, 16)
								bApply:SetText("#jcms.apply")
								bApply.Paint = jcms.paint_ButtonFilled
								function bApply:DoClick()
									surface.PlaySound("buttons/button9.wav")
									RunConsoleCommand("jcms_setorderdetails", orderId, cost.entry:GetValue(), cooldown.entry:GetValue())
								end

								local bReset = pnl:Add("DButton")
								bReset:SetPos(128+16, 96 - 24)
								bReset:SetSize(200, 16)
								bReset:SetText("#jcms.opt_orders_reset")
								bReset.Paint = jcms.paint_Button
								function bReset:DoClick()
									surface.PlaySound("buttons/button9.wav")
									RunConsoleCommand("jcms_setorderdetails", orderId, "reset", "reset")
									timer.Simple(0.5, function()
										if IsValid(cost) and IsValid(cooldown) and jcms.orders[orderId] then
											cost.entry:SetValue(jcms.orders[orderId].cost)
											cooldown.entry:SetValue(jcms.orders[orderId].cooldown)
										end
									end)
								end
							end
						end
					-- }}}
				-- }}}
				
				function bClient:DoClick()
					tabClient:SetVisible(true)
					tabServer:SetVisible(false)
					bClient.Paint = jcms.paint_ButtonFilled
					bClient:SetTall(32)
					bServer.Paint = jcms.paint_Button
					bServer:SetTall(24)
					surface.PlaySound("buttons/combine_button1.wav")
				end

				function bServer:DoClick()
					tabClient:SetVisible(false)
					tabServer:SetVisible(true)
					bClient.Paint = jcms.paint_Button
					bClient:SetTall(24)
					bServer.Paint = jcms.paint_ButtonFilled
					bServer:SetTall(32)
					surface.PlaySound("buttons/combine_button1.wav")
				end
			end
		end

		function jcms.offgame_ModalChangeMission()
			local frame = jcms.offgame:Add("DFrame")
			frame:SetSize(500, 172)
			frame:Center()
			frame:SetDraggable(false)
			frame:SetBackgroundBlur(true)
			frame:SetDrawOnTop(true)
			frame:ShowCloseButton(false)
			frame:SetTitle("")
			frame.Paint = jcms.paint_ModalChangeMission

			local close = frame:Add("DButton")
			close:SetText("x")
			close:SetSize(64, 24)
			close:SetPos(frame:GetWide() - close:GetWide() - 8, 8)
			function close:DoClick()
				frame:Remove()
			end
			close.Paint = jcms.paint_ButtonFilled

			local missionsFactions, missionsGeneric = jcms.mission_GetOrder(true)
			local allFactions = jcms.factions_GetOrder()

			local currentMission = jcms.util_GetMissionType()
			local currentMissionData = jcms.missions[ currentMission ]

			local mistype = frame:Add("DComboBox")
			mistype:SetPos(24, 64)
			mistype:SetWide(frame:GetWide() - 48, 24)
			mistype:SetSortItems(false)
			mistype.Paint = jcms.paint_ComboBox
			mistype.PaintOver = BLANK_DRAW
			mistype.jText = "#jcms.missionhud"
			mistype.jFraction = 0.25
			mistype.PaintButtons = jcms.paint_ComboBoxButtonMission

			for i,m in ipairs(missionsFactions) do
				mistype:AddChoice("#jcms."..m, m, currentMission == m)
			end
			for i,m in ipairs(missionsGeneric) do
				mistype:AddChoice("#jcms."..m, m, currentMission == m)
			end

			local factiontype = frame:Add("DComboBox")
			factiontype:SetPos(24, mistype:GetY() + mistype:GetTall() + 8)
			factiontype:SetWide(frame:GetWide() - 48, 24)
			factiontype:SetSortItems(false)
			factiontype.Paint = jcms.paint_ComboBox
			factiontype.PaintOver = BLANK_DRAW
			factiontype.jText = "#jcms.enemieshud"
			factiontype.jFraction = 0.25

			function mistype:OnSelect(index, text, missionName)
				factiontype:Clear()
				local missionData = assert(jcms.missions[ missionName ], "that's an unknown mission type")

				if missionData.faction ~= "any" then
					factiontype:AddChoice("#jcms." .. missionData.faction, "", true)
				else
					for i, faction in ipairs(allFactions) do
						factiontype:AddChoice("#jcms." .. faction, faction, currentMissionData and self.preselect and faction == jcms.util_GetMissionFaction())
					end
				end
			end

			mistype.preselect = true
			mistype:OnSelect(mistype:GetSelectedID(), mistype:GetSelected())
			mistype.preselect = nil

			local confirm = frame:Add("DButton")
			confirm:SetText("#jcms.confirm")
			confirm:SetSize(200, 24)
			confirm:SetY( frame:GetTall() - confirm:GetTall() - 12 )
			confirm:CenterHorizontal(0.5)
			confirm.Paint = jcms.paint_Button
			function confirm:DoClick()
				local _, missionName = mistype:GetSelected()
				local _, factionName = factiontype:GetSelected()

				if missionName and factionName then
					local data = jcms.missions[ missionName ]

					if data then
						surface.PlaySound("buttons/button14.wav")
						
						if data.faction == "any" then
							RunConsoleCommand("jcms_mission", missionName, factionName)
						else
							RunConsoleCommand("jcms_mission", missionName)
						end

						frame:Remove()
					else
						surface.PlaySound("buttons/button16.wav")
					end
				else
					surface.PlaySound("buttons/button16.wav")
				end
			end
		end
	-- }}}

	-- Post-mission screen {{{
		function jcms.offgame_ShowPostMission(victory)
			local pnl = makeBasePanel(jcms.offgame_paint_PostMission)
			pnl.victory = victory
			pnl.allowSceneRender = true

			pnl.statsPnl = pnl:Add("DPanel")
			pnl.statsPnl:SetPos(48, ScrH())
			pnl.statsPnl:SetSize(800, ScrH() - 72 - 48)

			-- Header (Personal achievements) {{{
				pnl.statsPnl.header = pnl.statsPnl:Add("DPanel")
				for i, pd in ipairs( jcms.aftergame.statistics ) do
					if (pd.ply and jcms.locPly == pd.ply) or (jcms.locPly:SteamID64() == pd.sid64) then
						pnl.statsPnl.header.stats = pd
					end
				end
				pnl.statsPnl.header.victory = victory
				pnl.statsPnl.header.missiontime = tonumber(jcms.aftergame.missionTime) or 0
				pnl.statsPnl.header.Paint = jcms.offgame_paint_Header
				pnl.statsPnl.header:SetSize(700, 238)
				pnl.statsPnl.header:CenterHorizontal(0.5)

				pnl.statsPnl.header.av = pnl.statsPnl.header:Add("AvatarImage")
				pnl.statsPnl.header.av:SetPlayer(jcms.locPly, 64)
				pnl.statsPnl.header.av:SetPos(16, 38)
				pnl.statsPnl.header.av:SetSize(64, 64)
			-- }}}

			-- Level & EXP {{{
				pnl.statsPnl.level = pnl.statsPnl:Add("DPanel")
				pnl.statsPnl.level.victory = victory
				pnl.statsPnl.level.Paint = jcms.offgame_paint_LvlUp
				pnl.statsPnl.level:SetSize(672, 32)
				pnl.statsPnl.level:SetY( pnl.statsPnl.header:GetY() + pnl.statsPnl.header:GetTall() + 16 - 64 )
				pnl.statsPnl.level:CenterHorizontal(0.5)
				pnl.statsPnl.level.showDelay = 0.5
				pnl.statsPnl.level.values = {
					oldLevel = jcms.statistics.mylevel_premission,
					oldExp = jcms.statistics.myexp_premission,
					newLevel = jcms.statistics.mylevel,
					newExp = jcms.statistics.myexp
				}
			-- }}}

			-- Level & EXP {{{
				pnl.statsPnl.wincash = pnl.statsPnl:Add("DPanel")
				pnl.statsPnl.wincash.victory = victory
				pnl.statsPnl.wincash.Paint = jcms.offgame_paint_WinStreakAndCash
				pnl.statsPnl.wincash:SetSize(800, 128)
				pnl.statsPnl.wincash:SetY( pnl.statsPnl.header:GetY() + pnl.statsPnl.header:GetTall() + 16 )
				pnl.statsPnl.wincash:CenterHorizontal(0.5)
				pnl.statsPnl.wincash.showDelay = 2.1
			-- }}}
			
			-- Map Voting {{{
				pnl.statsPnl.voting = pnl.statsPnl:Add("DPanel")
				pnl.statsPnl.voting.victory = victory
				pnl.statsPnl.voting.Paint = jcms.offgame_paint_Voting
				pnl.statsPnl.voting:SetWide(760)
				pnl.statsPnl.voting:CenterHorizontal(0.5)
				pnl.statsPnl.voting:SetY(pnl.statsPnl.wincash:GetY() + pnl.statsPnl.wincash:GetTall() + 16)
				pnl.statsPnl.voting:SetTall( pnl.statsPnl:GetTall() - pnl.statsPnl.voting:GetY() )
				pnl.statsPnl.voting.mapButtons = {}
				pnl.statsPnl.voting.time = 0

				local voteFunc = function(btn)
					jcms.net_SendVote(btn.mapname or game.GetMap())
				end

				for mapChoice, wsid in pairs(jcms.aftergame.vote.choices) do
					local mapname = tostring(mapChoice)
					local mapButton = pnl.statsPnl.voting:Add("DButton")

					mapButton.mapname = mapname
					mapButton.exists = file.Exists("maps/" .. mapname .. ".bsp", "GAME")
					mapButton.mat = Material("maps/thumb/" .. mapname .. ".png")

					if wsid and not mapButton.exists then
						steamworks.FileInfo( wsid, function( result )
							steamworks.Download( result.previewid, true, function( path )
								mapButton.mat = AddonMaterial( path )
							end)
						end)
					end

					mapButton.colorMain = victory and jcms.color_bright_alt
					mapButton.DoClick = voteFunc
					mapButton.Paint = jcms.paint_MapButton
					table.insert(pnl.statsPnl.voting.mapButtons, mapButton)
				end
			-- }}}

			function pnl.statsPnl:Think()
				self.voting.time = self.voting.time + FrameTime()

				self:SetSize(800, ScrH() - 72 - 48)
				self:SetY( ( ( (pnl.time or 0) > 3.6 and 72 or ScrH() ) + self:GetY()*5 ) / 6 )

				self:CenterHorizontal(0.5)
				if not game.SinglePlayer() then
					self:SetX( math.max(0, self:GetX() - self:GetWide()/2 ) )
				end
				
				local intendedVotingY = self.wincash:GetY() + self.wincash:GetTall() + 16
				self.voting:SetTall( self:GetTall() - intendedVotingY )
				local voteShowUp = math.ease.OutQuint( math.Clamp(self.voting.time - 2.5, 0, 1) )
				self.voting:SetY( Lerp(voteShowUp, ScrH(), intendedVotingY) )

				local columns = math.floor( math.sqrt(#self.voting.mapButtons) )
				local rows = math.ceil( #self.voting.mapButtons / columns ) 
				local i = 0

				local bx, by = 16, 64
				local bw, bh = self.voting:GetWide() - bx*2, self.voting:GetTall() - by - 16
				local buttonWidth = bw / columns
				local buttonHeight = bh / rows
				if buttonWidth < buttonHeight*2.1 and columns > 1 then
					columns = columns - 1
					rows = math.ceil( #self.voting.mapButtons / columns )

					buttonWidth = bw / columns
					buttonHeight = bh / rows
				end

				for x=1, columns do
					for y=1, rows do
						i = i + 1
						local mapButton = self.voting.mapButtons[i]

						if mapButton then
							local pad = 8
							mapButton:SetPos(bx + (buttonWidth-pad)*(x-1) + pad, by + (buttonHeight-pad)*(y-1) + pad)
							mapButton:SetSize(buttonWidth-pad, buttonHeight-pad)

							mapButton:SetPos(mapButton:GetX() + pad, mapButton:GetY() + pad)
							mapButton:SetSize(mapButton:GetWide() - pad*2, mapButton:GetTall() - pad*2)
						else
							break
						end
					end
				end

				if not game.SinglePlayer() and jcms.aftergame.vote then
					local mapVotes = {}
					for ply, mapname in pairs( jcms.aftergame.vote.votes ) do
						mapVotes[ mapname ] = (mapVotes[ mapname ] or 0) + 1
					end

					local winningVoteCount, winningMap = -1, nil
					for mapChoice, wsid in pairs(jcms.aftergame.vote.choices) do
						if (mapVotes[ mapChoice ] or 0) > winningVoteCount then
							winningVoteCount = mapVotes[ mapChoice ] or 0
							winningMap = mapChoice
						end
					end

					for i, btn in ipairs(self.voting.mapButtons) do
						btn.winning = winningMap == btn.mapname
					end
				end
			end

			pnl.statsPnl.Paint = BLANK_DRAW
			
			if not game.SinglePlayer() then
				pnl.multiPnl = pnl:Add("DPanel")
				pnl.multiPnl:SetPos(848, ScrH())
				pnl.multiPnl:SetSize(700, ScrH() - 72 - 48)

				-- Leaderboards {{{
					pnl.multiPnl.leaderboardSweeper = pnl.multiPnl:Add("DPanel")
					pnl.multiPnl.leaderboardSweeper.victory = victory
					pnl.multiPnl.leaderboardSweeper.Paint = jcms.offgame_paint_Leaderboard
					pnl.multiPnl.leaderboardSweeper:SetSize(32, 32)
					pnl.multiPnl.leaderboardSweeper.entries = {}
					pnl.multiPnl.leaderboardSweeper.scrollArea = pnl.multiPnl.leaderboardSweeper:Add("DScrollPanel")
					pnl.multiPnl.leaderboardSweeper.scrollArea:SetPos( 16, 48 )

					pnl.multiPnl.leaderboardNPC = pnl.multiPnl:Add("DPanel")
					pnl.multiPnl.leaderboardNPC.victory = not victory
					pnl.multiPnl.leaderboardNPC.Paint = jcms.offgame_paint_Leaderboard
					pnl.multiPnl.leaderboardNPC:SetSize(32, 32)
					pnl.multiPnl.leaderboardNPC.entries = {}
					pnl.multiPnl.leaderboardNPC.scrollArea = pnl.multiPnl.leaderboardNPC:Add("DScrollPanel")
					pnl.multiPnl.leaderboardNPC.scrollArea:SetPos( 16, 48 )

					for i, pd in ipairs(jcms.aftergame.statistics) do
						if pd.wasSweeper then
							table.insert(pnl.multiPnl.leaderboardSweeper.entries, pd)
						end

						if pd.wasNPC then
							table.insert(pnl.multiPnl.leaderboardNPC.entries, pd)
						end
					end

					table.sort(pnl.multiPnl.leaderboardSweeper.entries, function(first, last)
						local totalFirst = (first.kills_direct or 0) + (first.kills_defenses or 0) + (first.kills_explosions or 0)
						local totalLast = (last.kills_direct or 0) + (last.kills_defenses or 0) + (last.kills_explosions or 0)
						return totalFirst > totalLast
					end)

					table.sort(pnl.multiPnl.leaderboardNPC.entries, function(first, last)
						local totalFirst = (first.kills_sweepers or 0) + (first.kills_turrets or 0)
						local totalLast = (last.kills_sweepers or 0) + (last.kills_turrets or 0)
						return totalFirst > totalLast
					end)
					
					do -- Sweepers
						local col = victory and jcms.color_bright_alt or jcms.color_bright
						local colTransparent = ColorAlpha(col, 128)
						local colBg = ColorAlpha(victory and jcms.color_dark_alt or jcms.color_dark, 100)

						local label = pnl.multiPnl.leaderboardSweeper:Add("DLabel")
						label:SetText("#jcms.as_sweeper")
						label:SetWide(512)
						label:SetTall(24)
						label:SetPos(24, 12)
						label:SetFont("jcms_medium")
						label:SetTextColor(col)

						local spac = 58 -- space between kill subcategories
						pnl.multiPnl.leaderboardSweeper.separatorsThick = { 160, 420, 540, (420+540)/2 }
						pnl.multiPnl.leaderboardSweeper.separators = { 184 + spac, 184 + spac*2, 184 + spac*3 }
						local ico_kills = pnl.multiPnl.leaderboardSweeper:Add("DImage")
						ico_kills:SetSize(24, 24)
						ico_kills:SetImage("jcms/kills.png")
						ico_kills:SetImageColor(col)
						ico_kills:SetPos(176, 16)
						for i, category in ipairs { "direct", "defenses", "explosions" } do
							local ico_c_kills = pnl.multiPnl.leaderboardSweeper:Add("DImage")
							ico_c_kills:SetSize(24, 24)
							ico_c_kills:SetImage("jcms/kills_" .. category .. ".png")
							ico_c_kills:SetImageColor(colTransparent)
							ico_c_kills:SetPos(184 + 18 + spac*i, 16)
						end

						local ico_deaths = pnl.multiPnl.leaderboardSweeper:Add("DImage")
						ico_deaths:SetSize(24, 24)
						ico_deaths:SetImage("jcms/deaths.png")
						ico_deaths:SetImageColor(col)
						ico_deaths:SetPos(436, 16)

						local ico_ff = pnl.multiPnl.leaderboardSweeper:Add("DImage")
						ico_ff:SetSize(24, 24)
						ico_ff:SetImage("jcms/friendlyfire.png")
						ico_ff:SetImageColor(colTransparent)
						ico_ff:SetPos((420+540)/2 + 16, 16)

						local ico_orders = pnl.multiPnl.leaderboardSweeper:Add("DImage")
						ico_orders:SetSize(24, 24)
						ico_orders:SetImage("jcms/orders.png")
						ico_orders:SetImageColor(colTransparent)
						ico_orders:SetPos(564, 16)

						for i, pd in ipairs(pnl.multiPnl.leaderboardSweeper.entries) do
							local entry = pnl.multiPnl.leaderboardSweeper.scrollArea:Add("DPanel")
							entry:SetTall(24)
							entry:Dock(TOP)
							entry:SetBackgroundColor(colBg)
							entry:DockMargin(0, 0, 0, 2)

							if pd.evacuated then
								local evac = entry:Add("DImage")
								evac:Dock(RIGHT)
								evac:DockMargin(2, 4, 2, 4)
								evac:SetSize(16)
								evac:SetImage("jcms/landmarks/evac.png")
								evac:SetImageColor(col)
							end

							local av = entry:Add("AvatarImage", 16)
							av:SetSize(16, 16)
							av:SetPos(4, 4)
							if IsValid(pd.ply) then
								av:SetPlayer(pd.ply)
							end

							local class = entry:Add("DImage")
							class:SetPos(24, 4)
							class:SetSize(16, 16)
							class:SetImage("jcms/classes/" .. (pd.class or "infantry") .. ".png")
							class:SetImageColor(col)

							local name = entry:Add("DLabel")
							name:SetText(pd.nickname)
							name:SetPos(44, 0)
							name:SetTall(24)
							name:SetWide(120)
							name:SetFont("jcms_small")
							name:SetTextColor(colTransparent)

							local totalKils = pd.kills_direct + pd.kills_defenses + pd.kills_explosions
							local kills = entry:Add("DLabel")
							kills:SetText(jcms.util_CashFormat(totalKils))
							kills:SetPos(160, 0)
							kills:SetTall(24)
							kills:SetFont("jcms_small_bolder")
							kills:SetTextColor(col)
							for i, count in ipairs { pd.kills_direct, pd.kills_defenses, pd.kills_explosions } do
								local c_kills = entry:Add("DLabel")
								c_kills:SetText(jcms.util_CashFormat(count))
								c_kills:SetPos(160 + 18 + spac*i, 0)
								c_kills:SetTall(24)
								c_kills:SetFont("jcms_small")
								c_kills:SetTextColor(colTransparent)
							end

							local deaths = entry:Add("DLabel")
							deaths:SetText(pd.deaths_sweeper)
							deaths:SetPos(420, 0)
							deaths:SetTall(24)
							deaths:SetFont("jcms_small_bolder")
							deaths:SetTextColor(col)

							local friendlyfires = entry:Add("DLabel")
							friendlyfires:SetText(pd.kills_friendly or 0)
							friendlyfires:SetPos((420+540)/2, 0)
							friendlyfires:SetTall(24)
							friendlyfires:SetFont("jcms_small_bolder")
							friendlyfires:SetTextColor(colTransparent)

							local orders_used = entry:Add("DLabel")
							orders_used:SetText(pd.ordersUsedCounts)
							orders_used:SetPos(540, 0)
							orders_used:SetTall(24)
							orders_used:SetFont("jcms_small_bolder")
							orders_used:SetTextColor(colTransparent)
						end
					end

					local areNpcsVisible = #pnl.multiPnl.leaderboardNPC.entries > 0
					pnl.multiPnl.leaderboardNPC:SetVisible(areNpcsVisible)
					if areNpcsVisible then -- NPCs
						local col = victory and jcms.color_bright or jcms.color_bright_alt
						local colTransparent = ColorAlpha(col, 128)
						local colBg = ColorAlpha(victory and jcms.color_dark or jcms.color_dark_alt, 100)

						local label = pnl.multiPnl.leaderboardNPC:Add("DLabel")
						label:SetText("#jcms.as_npc")
						label:SetWide(512)
						label:SetTall(24)
						label:SetPos(24, 12)
						label:SetFont("jcms_medium")
						label:SetTextColor(col)

						local ico_kills = pnl.multiPnl.leaderboardNPC:Add("DImage")
						ico_kills:SetSize(24, 24)
						ico_kills:SetImage("jcms/kills.png")
						ico_kills:SetImageColor(col)
						ico_kills:SetPos(216, 16)
						local label_deaths = pnl.multiPnl.leaderboardNPC:Add("DLabel")
						label_deaths:SetText("#jcms.stats_kills_sweepers")
						label_deaths:SetWide(512)
						label_deaths:SetTall(24)
						label_deaths:SetPos(216 + 32, 16)
						label_deaths:SetTextColor(colTransparent)

						local ico_turrets = pnl.multiPnl.leaderboardNPC:Add("DImage")
						ico_turrets:SetSize(24, 24)
						ico_turrets:SetImage("jcms/kills_defenses.png")
						ico_turrets:SetImageColor(col)
						ico_turrets:SetPos(346, 16)
						local label_turrets = pnl.multiPnl.leaderboardNPC:Add("DLabel")
						label_turrets:SetText("#jcms.stats_kills_turrets")
						label_turrets:SetWide(512)
						label_turrets:SetTall(24)
						label_turrets:SetPos(346 + 32, 16)
						label_turrets:SetTextColor(colTransparent)

						local ico_deaths = pnl.multiPnl.leaderboardNPC:Add("DImage")
						ico_deaths:SetSize(24, 24)
						ico_deaths:SetImage("jcms/deaths.png")
						ico_deaths:SetImageColor(col)
						ico_deaths:SetPos(506, 16)
						local label_deaths = pnl.multiPnl.leaderboardNPC:Add("DLabel")
						label_deaths:SetText("#jcms.stats_deaths")
						label_deaths:SetWide(512)
						label_deaths:SetTall(24)
						label_deaths:SetPos(506 + 32, 16)
						label_deaths:SetTextColor(colTransparent)

						pnl.multiPnl.leaderboardNPC.separatorsThick = { 200, 330, 490 }

						for i, pd in ipairs(pnl.multiPnl.leaderboardNPC.entries) do
							local entry = pnl.multiPnl.leaderboardNPC.scrollArea:Add("DPanel")
							entry:SetTall(24)
							entry:Dock(TOP)
							entry:SetBackgroundColor(colBg)
							entry:DockMargin(0, 0, 0, 2)

							local av = entry:Add("AvatarImage", 16)
							av:SetSize(16, 16)
							av:SetPos(4, 4)
							if IsValid(pd.ply) then
								av:SetPlayer(pd.ply)
							end

							local class = entry:Add("DImage")
							class:SetPos(24, 4)
							class:SetSize(16, 16)
							class:SetImage("jcms/classes/" .. (pd.class or "infantry") .. ".png")
							class:SetImageColor(col)

							local name = entry:Add("DLabel")
							name:SetText(pd.nickname)
							name:SetPos(44, 0)
							name:SetTall(24)
							name:SetWide(120)
							name:SetFont("jcms_small")
							name:SetTextColor(colTransparent)

							local kills = entry:Add("DLabel")
							kills:SetText(jcms.util_CashFormat(pd.kills_sweepers))
							kills:SetPos(200, 0)
							kills:SetTall(24)
							kills:SetFont("jcms_small_bolder")
							kills:SetTextColor(col)

							local turrets = entry:Add("DLabel")
							turrets:SetText(jcms.util_CashFormat(pd.kills_turrets))
							turrets:SetPos(330, 0)
							turrets:SetTall(24)
							turrets:SetFont("jcms_small_bolder")
							turrets:SetTextColor(col)

							local deaths = entry:Add("DLabel")
							deaths:SetText(pd.deaths_npc)
							deaths:SetPos(490, 0)
							deaths:SetTall(24)
							deaths:SetFont("jcms_small_bolder")
							deaths:SetTextColor(col)
						end
					end
				-- }}}

				-- Chat {{{
					jcms.offgame_CreateChatAsChild(pnl.multiPnl, 24, pnl.multiPnl:GetTall() - 260 - 24, pnl.multiPnl:GetWide() - 48, 260)
				-- }}}

				function pnl.multiPnl:Think()
					self:SetSize(700, ScrH() - 72 - 48)
					self:SetX( pnl.statsPnl:GetX() + pnl.statsPnl:GetWide() + 32 )
					self:SetY( ( ( (pnl.time or 0) > 3.6 and 72 or ScrH() ) + self:GetY()*5 ) / 6 )

					self.chatEntry:SetY(self:GetTall() - self.chatEntry:GetTall() - 24)
					self.chatPanel:SetY(self.chatEntry:GetY() - self.chatPanel:GetTall() - 4)

					local leaderboardsHeight = self:GetTall() - 76 - self.chatPanel:GetTall()
					local entries1, entries2 = #self.leaderboardSweeper.entries, #self.leaderboardNPC.entries
					local ratio = entries2 == 0 and 1 or (entries1 + 0.5) / (entries1 + entries2 + 1)
					self.leaderboardSweeper:SetPos(32, 24)
					self.leaderboardSweeper:SetSize(self:GetWide() - 48, leaderboardsHeight*ratio - 4)
					self.leaderboardSweeper.scrollArea:SetSize(self.leaderboardSweeper:GetWide() - 32, self.leaderboardSweeper:GetTall() - self.leaderboardSweeper.scrollArea:GetY() - 16)

					self.leaderboardNPC:SetPos(24, self.leaderboardSweeper:GetY() + self.leaderboardSweeper:GetTall() + 4)
					self.leaderboardNPC:SetSize(self:GetWide() - 48, leaderboardsHeight*(1-ratio) - 4)
					self.leaderboardNPC.scrollArea:SetSize(self.leaderboardNPC:GetWide() - 32, self.leaderboardNPC:GetTall() - self.leaderboardNPC.scrollArea:GetY() - 16)
				end

				pnl.multiPnl.Paint = BLANK_DRAW
			end
		end
	-- }}}

	-- Other {{{

		function jcms.offgame_ModalChangeClass()
			local frame = GetHUDPanel():Add("DFrame")
			frame:SetSize(500, 168)
			frame:SetDraggable(false)
			frame:SetBackgroundBlur(true)
			frame:SetDrawOnTop(true)
			frame:ShowCloseButton(false)
			frame:SetTitle("")
			frame:MakePopup()
			frame.Paint = jcms.paint_ModalChangeClass

			local function cbtnClick(self)
				RunConsoleCommand("jcms_setclass", self.classname)
				surface.PlaySound("weapons/slam/mine_mode.wav")
				--jcms.cvar_favclass:SetString(self.classname)
				-- Technically could set fav class here as well, but I doubt people who change class mid-game want to reset their fav class
			end

			local bWidth = 0
			local minimizeButtons = #jcms.classesOrder >= 8
			for i, classname in ipairs( jcms.classesOrder ) do
				local size = minimizeButtons and 32 or 64
				local cbtn = frame:Add("DImageButton")
				if minimizeButtons then
					cbtn:SetPos(96 + size*math.floor( (i-1)/2 ) + size*1.5, 64 - 8 + (i%2==0 and 32 or 0))
				else
					cbtn:SetPos(48 + size*(i-1), frame:GetTall() - size - 32)
				end
				cbtn:SetSize(size, size)
				cbtn:SetImage("jcms/classes/" .. classname .. ".png")
				cbtn.classname = classname
				cbtn.Paint = jcms.paint_ClassButton
				cbtn.DoClick = cbtnClick
				bWidth = math.max(bWidth, cbtn:GetX() + size - 48)
			end

			frame:SetWide(bWidth + (minimizeButtons and 96 or 48)*2)
			frame:Center()

			local close = frame:Add("DButton")
			close:SetText("x")
			close:SetSize(64, 24)
			close:SetPos(frame:GetWide() - close:GetWide() - 8, 8)
			function close:DoClick()
				frame:Remove()
			end
			close.Paint = jcms.paint_ButtonFilled

			function frame:Think()
				if jcms.locPly:GetObserverMode() ~= OBS_MODE_CHASE then
					self:Remove()
				end
			end
		end

	-- }}}
	
-- }}}
