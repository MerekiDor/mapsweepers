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
	terms.spinners = {
		weight = 1,

		generate = function(ent)
			local size = math.random(8, 9)
			local startY = math.random(1, size)
			local goalY = math.random(1, size)

			local map = ""
			for i=1, size*size do
				map = map .. math.random(1, 6)
			end

			return size .. " " .. startY .. " " .. goalY .. " " .. map
		end,

		command = function(ent, cmd, data, ply)
			if not ent:GetNWBool("jcms_terminal_locked") then return end
			local size, startY, goalY, map = data:match("(%d+) (%d+) (%d+) (%w+)")
			size = tonumber(size)

			if size and #map == size^2 and cmd >= 1 and cmd <= size^2 then
				local t = {}
				for i=1, #map do
					t[i] = map:sub(i,i)
					if t[i]:match("%a") == t[i] then
						-- I know I could use string.byte and shit but nah.
						t[i] = ({a="1",b="2",c="3",d="4",e="5",f="6"})[ t[i] ]
					end
				end

				local piece = t[cmd]
				if piece == "1" then
					piece = "2"
				elseif piece == "2" then
					piece = "1"
				elseif piece == "6" then
					piece = "3"
				else
					piece = tostring(tonumber(piece) + 1)
				end
				t[cmd] = piece

				local flow = {
					{ ["10"]="10", ["-10"]="-10" },
					{ ["01"]="01", ["0-1"]="0-1" },
					{ ["-10"]="01", ["0-1"]="10" },
					{ ["10"]="01", ["0-1"]="-10" },
					{ ["10"]="0-1", ["01"]="-10" },
					{ ["-10"]="0-1", ["01"]="10" }
				}

				local x,y = 1, tonumber(startY)
				local dx, dy = 1, 0
				local unlocked = false
				while true do
					local piece = tonumber( t[ (y-1)*size + x ] )

					if piece then
						local nextflow = flow[ piece ][ dx..dy ]
						if nextflow then
							t[ (y-1)*size + x ] = ({"a","b","c","d","e","f"})[piece]

							if nextflow == "10" then
								dx, dy = 1, 0
							elseif nextflow == "-10" then
								dx, dy = -1, 0
							elseif nextflow == "0-1" then
								dx, dy = 0, -1
							elseif nextflow == "01" then
								dx, dy = 0, 1
							end
							x, y = x + dx, y + dy

							if x<1 or x>size or y<1 or y>size then
								if x > size and y==tonumber(goalY) then
									unlocked = true
								end
								break
							end
						else
							break
						end 
					else
						break
					end
				end

				if unlocked then
					jcms.terminal_Unlock(ent, ply, true)
				end

				map = table.concat(t)
				return true, ("%d %d %d %s"):format(size, startY, goalY, map)
			else
				return false					
			end
		end
	}

	terms.circuit = {
		weight = 1,

		generate = function(ent)
			local count = math.random(6, 7)
			local str = math.random(0,9) .. " "
			
			local pieces = {}
			for i = 1, count do
				table.insert(pieces, i)
				table.insert(pieces, i)
			end
			table.Shuffle(pieces)
			
			for i, piece in ipairs(pieces) do
				str = str .. piece
			end
			
			str = str .. " "
			for i = 1, count do
				str = str .. "0"
			end
			
			return str
		end,

		command = function(ent, cmd, data, ply)
			if not ent:GetNWBool("jcms_terminal_locked") then return end

			local split = string.Split(data, " ")
			
			if #split == 4 then
				local clickedId = tonumber(cmd)
				local clickedNumber = tonumber(split[2]:sub(clickedId, clickedId))
				local selectedId = tonumber(split[4])
				local selectedNumber = tonumber(split[2]:sub(selectedId, selectedId))
				
				if clickedNumber == selectedNumber and clickedId ~= selectedId then
					split[3] = split[3]:sub(1, clickedNumber-1) .. "1" .. split[3]:sub(clickedNumber+1, -1)
				elseif (clickedId ~= 0) and (clickedId ~= selectedId) then
					jcms.terminal_Punish(ent, ply)
				end
				
				if split[3]:match("1+") == split[3] then
					jcms.terminal_Unlock(ent, ply, true)
				end
				
				return true, table.concat(split, " ", 1, 3)
			else
				return true, data .. " " .. cmd
			end
			
			return false
		end
	}
	
	terms.codematch = {
		weight = 1,

		generate = function(ent)
			local target = string.format("%x", math.random(16, 16*16-1))
			local str = math.random(5, 6) .. " " .. target
			
			local targetId = math.random(1, 20)
			for i=1, 20 do
				local piece = i == targetId and target or string.format("%x", math.random(16, 16*16-1))
				str = str .. " " .. piece
			end
			
			return str
		end,

		command = function(ent, cmd, data, ply)
			if not ent:GetNWBool("jcms_terminal_locked") then return end
			
			local split = string.Split(data, " ")
			if #split > 2 then
				local totalPieces = tonumber( split[1]:sub(1,1) ) or 0
				local wordSoFar = split[1]:sub(2, -1)
				
				local target = split[2]
				table.remove(split, 1)
				table.remove(split, 1)
				
				if (split[cmd] == target) then
					wordSoFar = wordSoFar .. target
					if #wordSoFar/2 >= totalPieces then
						jcms.terminal_Unlock(ent, ply, true)
					else
						target = string.format("%x", math.random(16, 16*16-1))
					end
				else
					jcms.terminal_Punish(ent, ply)
				end
				
				local str = totalPieces .. wordSoFar .. " " .. target
				
				local targetId = math.random(1, 20)
				for i=1, 20 do
					local piece = i == targetId and target or string.format("%x", math.random(16, 16*16-1))
					str = str .. " " .. piece
				end
				
				return true, str
			else
				return false
			end
			
			return false
		end
	}

	terms.jeechblock = {
		weight = 1,

		generate = function(ent)
			local str = ""

			ent:StopSound("ambient/atmosphere/tone_alley.wav")

			if math.random() < 0.001 then
				str = "ILOVEJCORP"
				if math.random() < 0.1 then
					str = math.random() < 0.5 and "RUN" or "BEHINDYOU"
					ent:EmitSound("ambient/atmosphere/tone_alley.wav", 75, 90, 1, CHAN_STATIC)
				end
			else
				for i=1, 10 do
					str = str .. string.char(math.random() < 0.75 and math.random(0x41, 0x5a) or math.random(0x30, 0x39))
				end
			end
			
			return str .. " "
		end,

		command = function(ent, cmd, data, ply)
			if not ent:GetNWBool("jcms_terminal_locked") then return end
			local sample = "1234567890QWERTYUIOP-ASDFGHJKL+ZXCVBNM_"
			local char = sample:sub(cmd, cmd)

			local parts = data:Split(" ")

			if char then
				if char == "-" then
					local newWord = parts[2]:sub(1, -2)
					return #parts[2]>0, parts[1] .. " " .. newWord
				elseif char == "+" then
					if parts[1] == parts[2] then
						jcms.terminal_Unlock(ent, ply, true)
						ent:StopSound("ambient/atmosphere/tone_alley.wav")
						return true, data
					else
						jcms.terminal_Punish(ent, ply)
						ent:EmitSound("buttons/button8.wav", 75, 110, 1.0)
						return true, parts[1] .. " " .. parts[2]
					end
				elseif char == "_" then
					return (parts[2] and #parts[2]>0), parts[1] .. " "
				else
					if parts[2] and #parts[2] > #parts[1] + 5 then
						jcms.terminal_Punish(ent, ply)
						ent:EmitSound("buttons/button8.wav", 75, 110, 1.0)
						return true, parts[1] .. " "
					else
						return true, data .. char
					end
				end
			else
				return false
			end
		end
	}

	terms.sort = {
		weight = 1,

		generate = function(ent)
			local numbers = {}
			
			local total = math.random(11, 14)
			for i = 1, total do
				local n = math.Remap(i, 1, total, 0, 31) + math.random(0, 2)

				if math.random() < n%1 then
					n = math.ceil(n)
				else
					n = math.floor(n)
				end

				table.insert(numbers, n)
			end
			table.Shuffle(numbers)
			
			return "0 " .. table.concat(numbers, " ")
		end,

		command = function(ent, cmd, data, ply)
			if not ent:GetNWBool("jcms_terminal_locked") then return end
			local parts = string.Split(data, " ")

			local selectedIndex = cmd + 1
			local selectedPart = parts[ selectedIndex ]
			if (selectedIndex <= 1) or (not selectedPart) then return false end

			if parts[1] == "0" then
				table.remove(parts, 1)
				return true, tostring(cmd) .. " " .. table.concat(parts, " ")
			else
				local currentIndex = tonumber( parts[1] ) + 1
				local currentPart = parts[ currentIndex ]

				if (currentIndex <= 1) or (not currentPart) then return false end
				if currentIndex ~= selectedIndex then
					parts[ currentIndex ], parts[ selectedIndex ] = parts[ selectedIndex ], parts[ currentIndex ]

					local isSorted = true
					local sortDelta = 0
					for i=3, #parts do
						local n_curr = tonumber(parts[ i ]) or 0
						local n_prev = tonumber(parts[i-1]) or 0
						if (sortDelta == 0) then
							if n_curr > n_prev then
								sortDelta = 1
							elseif n_curr < n_prev then
								sortDelta = -1
							end
						elseif (sortDelta == -1 and n_curr > n_prev) or (sortDelta == 1 and n_curr < n_prev) then
							isSorted = false
							break
						end
					end

					if isSorted then
						jcms.terminal_Unlock(ent, ply, true)
					end

					table.remove(parts, 1)
					return true, "0 " .. table.concat(parts, " ")
				else
					return false
				end
			end
		end
	}
end

if CLIENT then
	terms.spinners = function(ent, mx, my, w, h, modedata)
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

				cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(5, -0.3), true)
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
	end

	terms.circuit = function(ent, mx, my, w, h, modedata)
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
	end
	
	terms.codematch = function(ent, mx, my, w, h, modedata)
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
	end

	terms.jeechblock = function(ent, mx, my, w, h, modedata)
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

		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(4, 0.05), true)
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

	terms.sort = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		draw.SimpleText([=[Sort these pillars]=], "jcms_hud_small", w/2, 0, color_bg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText([=[Sort these pillars]=], "jcms_hud_small", w/2, -2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		local parts = modedata:Split(" ")
		local currentIndex = tonumber(parts[1])
		local currentI = 0
		if currentIndex > 0 then currentI = currentIndex + 1 end
		local pad = 4

		local total = #parts
		local pillarWidth = math.ceil(w / (total + 3))
		local pillarHeight = math.max(48, math.ceil((h - 48)*0.5))
		local hoverIndex = 0
		for i=2, total do
			local x = math.Remap(i, 2, total, 0, w - pillarWidth)
			local ph = math.Remap(tonumber(parts[i]), 0, 32, 0.05, 0.95)*pillarHeight
			surface.SetDrawColor(color_bg)
			surface.DrawOutlinedRect(x, 48, pillarWidth, pillarHeight, 2)
			surface.DrawRect(x + pad, 48 + (pillarHeight - ph) + pad, pillarWidth - pad*2, ph - pad*2)
			
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(4, 0.05), true)
				surface.SetDrawColor(currentI == i and color_accent or color_fg)
				if hoverIndex == 0 and mx >= x and my >= 48 and mx <= x + pillarWidth and my <= 48 + pillarHeight then
					surface.DrawOutlinedRect(x, 48, pillarWidth, pillarHeight, 3)
					hoverIndex = i - 1
				end
				surface.DrawRect(x + pad, 48 + (pillarHeight - ph) + pad, pillarWidth - pad*2, ph - pad*2)
			cam.PopModelMatrix()
			render.OverrideBlend( false )
		end

		if currentIndex > 0 and hoverIndex ~= 0 and hoverIndex ~= currentIndex then
			local x1 = math.Remap(hoverIndex, 1, total-1, pillarWidth/2, w - pillarWidth*0.5)
			local x2 = math.Remap(currentIndex, 1, total-1, pillarWidth/2, w - pillarWidth*0.5)
			surface.SetDrawColor(color_accent)
			surface.DrawRect(math.min(x1, x2), 72 + pillarHeight, math.abs(x2-x1), 3)

			surface.DrawRect(x1-3, 56 + pillarHeight, 6, 16)
			surface.DrawRect(x2-3, 56 + pillarHeight, 6, 16)
		end

		return hoverIndex
	end
end