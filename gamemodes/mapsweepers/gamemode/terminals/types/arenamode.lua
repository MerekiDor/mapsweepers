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
	terms.arena_waves = {
		generate = function(ent)
			ent.jcms_nextWaveOptions = { "clear", "press", "15s", "30s", "60s" }
			return ent.jcms_nextWaveOptions[1] .. ",5,0"
		end,

		command = function(ent, cmd, data, ply)
			local split = string.Split(data, ",")
			local nextwave = split[1]
			local waves = split[2]
			local respawns = split[3]

			if cmd == 1 or cmd == 2 then
				-- Switch next wave mode
				local delta = cmd == 2 and 1 or -1
				
				local currentIndex = 1
				for k, v in ipairs(ent.jcms_nextWaveOptions) do
					if v == nextwave then
						currentIndex = k
						break
					end
				end

				local nextIndex = (currentIndex - 1 + delta) % (#ent.jcms_nextWaveOptions) + 1
				return true, ent.jcms_nextWaveOptions[nextIndex] .. "," .. waves .. "," .. respawns
			elseif cmd == 3 or cmd == 4 then
				-- Wave count
				local delta = cmd == 4 and 1 or -1
				local newcount = math.Clamp( math.floor(tonumber(waves) or 0) + delta, 0, 9999 )
				return (tostring(newcount) ~= waves), nextwave .. "," .. newcount .. "," .. respawns
			elseif cmd == 5 then
				-- Endless mode toggle
				if waves == "0" then
					return true, nextwave .. ",5," .. respawns
				else
					return true, nextwave .. ",0," .. respawns
				end
			elseif cmd == 6 or cmd == 7 then
				-- Respawn count
				local delta = cmd == 7 and 1 or -1
				local newcount = math.Clamp( math.floor(tonumber(respawns) or 0) + delta, 0, 10 )
				return (tostring(newcount) ~= respawns), nextwave .. "," .. waves .. "," .. newcount
			end

			return false
		end
	}

	terms.arena_basics = {
		generate = function(ent)
			local sortedFactions = table.GetKeys(jcms.factions)
			table.sort(sortedFactions)
			ent.jcms_sortedFactions = sortedFactions
			ent.jcms_difficultyOptions = { "easy", "normal", "hard", "nightmare", "ohfuck" }
			ent.jcms_difficultyValues = { 0.5, 1, 1.5, 2, 3 }

			return (sortedFactions[1] or "") .. ",normal"
		end,

		command = function(ent, cmd, data, ply)
			local split = string.Split(data, ",")
			local faction = split[1]
			local difficulty = split[2]

			if cmd == 1 or cmd == 2 then
				-- Switch faction
				local delta = cmd == 2 and 1 or -1
				
				local currentIndex = 1
				for k, v in ipairs(ent.jcms_sortedFactions) do
					if v == faction then
						currentIndex = k
						break
					end
				end

				local nextIndex = (currentIndex - 1 + delta) % (#ent.jcms_sortedFactions) + 1
				return true, ent.jcms_sortedFactions[nextIndex] .. "," .. difficulty
			elseif cmd == 3 or cmd == 4 then
				-- Switch difficulty
				local delta = cmd == 4 and 1 or -1
				
				local currentIndex = 1
				for k, v in ipairs(ent.jcms_difficultyOptions) do
					if v == difficulty then
						currentIndex = k
						break
					end
				end

				local nextIndex = (currentIndex - 1 + delta) % (#ent.jcms_difficultyOptions) + 1
				return true, faction .. "," .. ent.jcms_difficultyOptions[nextIndex]
			elseif cmd == 5 then
				-- Start arena

				if jcms.arena_settings then
					return false
				end

				local ent_waves = ent.term_waves
				local ent_bonuses = ent.term_bonuses

				local data_waves = ent_waves:GetNWString("jcms_terminal_modeData", "clear,5,0")
				local data_bonuses = ent_bonuses:GetNWString("jcms_terminal_modeData", "1,0,0,0")

				local split_waves = string.Split(data_waves, ",")
				local split_bonuses = string.Split(data_bonuses, ",")

				local arena_settings = {}
				arena_settings.nextwave = split_waves[1]
				arena_settings.waves = split_waves[2] == "0" and math.huge or math.max(1, math.ceil( tonumber(split_waves[2]) ))
				arena_settings.respawns = math.max(0, math.ceil( tonumber(split_waves[3]) ))
				arena_settings.faction = faction
				arena_settings.difficultyName = difficulty
				for i, v in ipairs(ent.jcms_difficultyOptions) do
					if v == difficulty then
						arena_settings.difficulty = tonumber(ent.jcms_difficultyValues[ i ]) or 1
						break
					end
				end
				arena_settings.bountymul = tonumber(split_bonuses[1]) or 1
				arena_settings.wavebonus = tonumber(split_bonuses[2]) or 0
				arena_settings.supplydrops = tonumber(split_bonuses[3]) or 0
				arena_settings.disablerb = split_bonuses[4] == "1"
				arena_settings.startedBy = ply
				arena_settings.startedBySID64 = ply:SteamID64()
				arena_settings.players = {}
				arena_settings.pos = ent.arena_pos or jcms.specialmap_arenaPos or Vector(0, 0, 0)
				arena_settings.radius = ent.arena_radius or jcms.specialmap_arenaRadius or 250
				arena_settings.spawnpoints = {}

				if jcms.specialmap_BuildArenaSpawnpoints then
					jcms.specialmap_BuildArenaSpawnpoints(arena_settings.spawnpoints, arena_settings)
				else
					table.insert(arena_settings.spawnpoints, arena_settings.pos)
				end
				
				local pivot = ply:WorldSpaceCenter()
				local findInRadius = 512
				local findInRadius2 = findInRadius*findInRadius
				for i, ply in player.Iterator() do
					if ply:WorldSpaceCenter():DistToSqr(pivot) <= findInRadius2 then
						table.insert(arena_settings.players, ply)
					end
				end

				if #arena_settings.players > 0 then
					ent:EmitSound("buttons/lever4.wav")
					jcms.specialmap_StartArena(arena_settings)
					return true, data
				else
					return false
				end
			end

			return false
		end
	}

	terms.arena_bonuses = {
		generate = function(ent)
			ent.jcms_bountyOptions = { 0, 0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 5 }
			ent.jcms_waveBonusOptions = { 0, 50, 100, 250, 500, 1000, 1500, 3000, 5000, 10000 }
			ent.jcms_supplyDropsOptions = { 0, 1, 3, 5 }
			return "0.10,500,0,0"
		end,

		command = function(ent, cmd, data, ply)
			local split = string.Split(data, ",")
			local bountymul = split[1]
			local wavebonus = split[2]
			local supplydrops = split[3]
			local disablerb = split[4]

			local tbls = { ent.jcms_bountyOptions, ent.jcms_waveBonusOptions, ent.jcms_supplyDropsOptions }
			local values = { bountymul, wavebonus, supplydrops }
			if cmd >= 1 and cmd <= 6 then
				local delta = cmd%2==0 and 1 or -1

				local index = math.floor( (cmd-1) / 2 ) + 1
				local tbl = tbls[ index ]
				if type(tbl) ~= "table" then return false end
				local value = tonumber( values[ index ] )

				local currentIndex = 1
				for k, v in ipairs(tbl) do
					if v == value then
						currentIndex = k
						break
					end
				end

				local nextIndex = (currentIndex - 1 + delta) % (#tbl) + 1
				values[ index ] = tbl[ nextIndex ]

				return true, values[1] .. "," .. values[2] .. "," .. values[3] .. "," .. disablerb
			elseif cmd == 7 then
				return true, bountymul .. "," .. wavebonus .. "," .. supplydrops .. "," .. (disablerb == "1" and "0" or "1")
			end

			return false
		end
	}
end

if CLIENT then
	terms.arena_waves = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		local font = "jcms_hud_medium"
		
		local split = string.Split(modedata, ",")
		local nextwave = split[1]
		local waves = split[2]
		local respawns = split[3]

		local str1a = language.GetPhrase("jcms.arenanextwave")
		local str1b = language.GetPhrase("jcms.arenanextwave_" .. nextwave)

		local str2a = language.GetPhrase("jcms.arenawaves")
		local str2b = waves == "0" and "∞" or waves
		local str2c = language.GetPhrase("jcms.arenawaves_inf")

		local str3a = language.GetPhrase("jcms.arenafreerespawns")
		local str3b = respawns

		local y1 = 0
		local _, th1a = draw.SimpleText(str1a, font, -8, y1, color_bg, TEXT_ALIGN_RIGHT)

		local y2 = y1 + th1a + 4
		local _, th2a = draw.SimpleText(str2a, font, -8, y2, color_bg, TEXT_ALIGN_RIGHT)
		
		local y3 = y2 + th2a + 4
		local _, th3a = draw.SimpleText(str3a, font, -8, y3, color_bg, TEXT_ALIGN_RIGHT)
		local btnSize = th1a

		surface.SetDrawColor(color_bg)
		surface.DrawRect(btnSize + 4, y1, w - btnSize*2 - 8, th1a)
		surface.DrawRect(0, y1, btnSize, th1a)
		surface.DrawRect(w-btnSize, y1, btnSize, btnSize)
		surface.DrawRect(btnSize + 4, y2, w/2 - btnSize*2 - 8, btnSize)
		surface.DrawRect(0, y2, btnSize, btnSize)
		surface.DrawRect(w/2-btnSize, y2, btnSize, btnSize)
		surface.DrawRect(w/2+4+8, y2+8, w/2-4-16, btnSize-16)
		surface.DrawRect(btnSize + 4, y3, w/2 - btnSize*2 - 8, th1a)
		surface.DrawRect(0, y3, btnSize, th1a)
		surface.DrawRect(w/2-btnSize, y3, btnSize, btnSize)

		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText(str1a, font, -8, y1, color_fg, TEXT_ALIGN_RIGHT)
				draw.SimpleText(str1b, font, w/2, y1, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText("<", font, btnSize/2, y1, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText(">", font, w-btnSize/2, y1, color_fg, TEXT_ALIGN_CENTER)
				
				draw.SimpleText(str2a, font, -8, y2, color_fg, TEXT_ALIGN_RIGHT)
				draw.SimpleText(str2b, font, w/4, y2, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText(str2c, "jcms_hud_small", w*3/4, y2 + btnSize/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("<", font, btnSize/2, y2, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText(">", font, w/2-btnSize/2, y2, color_fg, TEXT_ALIGN_CENTER)
				
				draw.SimpleText(str3a, font, -8, y3, color_fg, TEXT_ALIGN_RIGHT)
				draw.SimpleText(str3b, font, w/4, y3, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText("<", font, btnSize/2, y3, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText(">", font, w/2-btnSize/2, y3, color_fg, TEXT_ALIGN_CENTER)
			render.OverrideBlend( false )
		cam.PopModelMatrix()

		local buttons = {
			{ 0, y1, btnSize, btnSize },
			{ w - btnSize, y1, btnSize, btnSize },
			{ 0, y2, btnSize, btnSize },
			{ w/2 - btnSize, y2, btnSize, btnSize },
			{ w/2 + 4 + 8, y2 + 8, w/2 - 4 - 16, btnSize - 16 },
			{ 0, y3, btnSize, btnSize },
			{ w/2 - btnSize, y3, btnSize, btnSize },
		}

		for i, btn in ipairs(buttons) do
			local bx, by, bw, bh = unpack(btn)
			if mx > bx and my > by and mx < bx+bw and my < by+bh then
				cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
						surface.SetDrawColor(color_fg)
						surface.DrawOutlinedRect(bx, by, bw, bh, 3)
					render.OverrideBlend( false )
				cam.PopModelMatrix()
				return i
			end
		end
	end

	terms.arena_basics = function(ent, mx, my, w, h, modedata)
		w = w + 64
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		local font = "jcms_hud_score"
		
		local split = string.Split(modedata, ",")
		local faction = split[1]
		local difficulty = split[2]

		local str1a = language.GetPhrase("jcms.enemieshud")
		local str1b = language.GetPhrase("jcms." .. faction)

		local str2a = language.GetPhrase("jcms.arenadifficulty")
		local str2b = language.GetPhrase("jcms.arenadifficulty_" .. difficulty)

		local str3 = language.GetPhrase("jcms.arenastart")

		local y1 = 0
		local _, th1a = draw.SimpleText(str1a, font, -8, y1, color_bg, TEXT_ALIGN_RIGHT)

		local y2 = y1 + th1a + 4
		local _, th2a = draw.SimpleText(str2a, font, -8, y2, color_bg, TEXT_ALIGN_RIGHT)
		
		local y3 = y2 + th2a + 32
		local btnSize = th1a

		surface.SetDrawColor(color_bg)
		surface.DrawRect(btnSize + 4, y1, w - btnSize*2 - 8, th1a)
		surface.DrawRect(0, y1, btnSize, th1a)
		surface.DrawRect(w-btnSize, y1, btnSize, btnSize)
		surface.DrawRect(btnSize + 4, y2, w - btnSize*2 - 8, btnSize)
		surface.DrawRect(0, y2, btnSize, btnSize)
		surface.DrawRect(w-btnSize, y2, btnSize, btnSize)

		surface.DrawRect(24, y3, w - 48, btnSize*1.5)
		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText(str1a, font, -8, y1, color_fg, TEXT_ALIGN_RIGHT)
				draw.SimpleText(str1b, font, w/2, y1, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText("<", font, btnSize/2, y1, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText(">", font, w-btnSize/2, y1, color_fg, TEXT_ALIGN_CENTER)
				
				draw.SimpleText(str2a, font, -8, y2, color_fg, TEXT_ALIGN_RIGHT)
				draw.SimpleText(str2b, font, w/2, y2, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText("<", font, btnSize/2, y2, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText(">", font, w-btnSize/2, y2, color_fg, TEXT_ALIGN_CENTER)
				
				draw.SimpleText(str3, "jcms_hud_score", w/2, y3 + btnSize*0.75, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				local scroll = CurTime()%1*32
				jcms.hud_DrawStripedRect(24, y3, w - 48, 16, 64, scroll)
				jcms.hud_DrawStripedRect(24, y3 + btnSize*1.5 - 16, w - 48, 16, 64, scroll)
			render.OverrideBlend( false )
		cam.PopModelMatrix()

		local buttons = {
			{ 0, y1, btnSize, btnSize },
			{ w - btnSize, y1, btnSize, btnSize },
			{ 0, y2, btnSize, btnSize },
			{ w - btnSize, y2, btnSize, btnSize },
			{ 24, y3, w - 48, btnSize * 1.5 }
		}

		for i, btn in ipairs(buttons) do
			local bx, by, bw, bh = unpack(btn)
			if mx > bx and my > by and mx < bx+bw and my < by+bh then
				cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
						surface.SetDrawColor(color_fg)
						surface.DrawOutlinedRect(bx, by, bw, bh, 3)
					render.OverrideBlend( false )
				cam.PopModelMatrix()
				return i
			end
		end
	end

	terms.arena_bonuses = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		local font = "jcms_hud_medium"
		local split = string.Split(modedata, ",")
		local bountymul = split[1]
		local wavebonus = split[2]
		local supplydrops = split[3]
		local disablerb = split[4]

		local str1a = language.GetPhrase("jcms.arenacashforkills")
		local str1b = string.format("x%.2f", bountymul)

		local str2a = language.GetPhrase("jcms.arenacashforwave")
		local str2b = jcms.util_CashFormat( tonumber(wavebonus) or 0 ) .. " J"

		local str3a = language.GetPhrase("jcms.arenasupplydrops")
		local str3b = language.GetPhrase("jcms.arenasupplydrops_" .. supplydrops)

		local str4 = language.GetPhrase("jcms.arenadisablerb")

		local y1 = 0
		local _, th1a = draw.SimpleText(str1a, font, -8, y1, color_bg, TEXT_ALIGN_RIGHT)

		local y2 = y1 + th1a + 4
		local _, th2a = draw.SimpleText(str2a, font, -8, y2, color_bg, TEXT_ALIGN_RIGHT)
		
		local y3 = y2 + th2a + 4
		local _, th3a = draw.SimpleText(str3a, font, -8, y3, color_bg, TEXT_ALIGN_RIGHT)
		local btnSize = th1a
		
		local y4 = y3 + th3a + 32
		local tw4, th4 = draw.SimpleText(str4, font, w - btnSize - 16, y4, color_bg, TEXT_ALIGN_RIGHT)

		
		surface.SetDrawColor(color_bg)
		surface.DrawRect(btnSize + 4, y1, w - btnSize*2 - 8, th1a)
		surface.DrawRect(0, y1, btnSize, th1a)
		surface.DrawRect(w-btnSize, y1, btnSize, btnSize)
		surface.DrawRect(btnSize + 4, y2, w - btnSize*2 - 8, th1a)
		surface.DrawRect(0, y2, btnSize, th1a)
		surface.DrawRect(w-btnSize, y2, btnSize, btnSize)
		surface.DrawRect(btnSize + 4, y3, w - btnSize*2 - 8, th1a)
		surface.DrawRect(0, y3, btnSize, th1a)
		surface.DrawRect(w-btnSize, y3, btnSize, btnSize)
		surface.DrawRect(w-btnSize, y4, btnSize, btnSize)

		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText(str1a, font, -8, y1, color_fg, TEXT_ALIGN_RIGHT)
				draw.SimpleText(str1b, font, w/2, y1, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText("<", font, btnSize/2, y1, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText(">", font, w-btnSize/2, y1, color_fg, TEXT_ALIGN_CENTER)
				
				draw.SimpleText(str2a, font, -8, y2, color_fg, TEXT_ALIGN_RIGHT)
				draw.SimpleText(str2b, font, w/2, y2, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText("<", font, btnSize/2, y2, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText(">", font, w-btnSize/2, y2, color_fg, TEXT_ALIGN_CENTER)
				
				draw.SimpleText(str3a, font, -8, y3, color_fg, TEXT_ALIGN_RIGHT)
				draw.SimpleText(str3b, font, w/2, y3, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText("<", font, btnSize/2, y3, color_fg, TEXT_ALIGN_CENTER)
				draw.SimpleText(">", font, w-btnSize/2, y3, color_fg, TEXT_ALIGN_CENTER)

				draw.SimpleText(str4, font, w - btnSize - 16, y4, color_fg, TEXT_ALIGN_RIGHT)
				if disablerb == "1" then
					surface.SetDrawColor(color_fg)
					surface.DrawRect(w - btnSize + 8, y4 + 8, btnSize - 16, btnSize - 16)
				end
			render.OverrideBlend( false )
		cam.PopModelMatrix()

		local buttons = {
			{ 0, y1, btnSize, btnSize },
			{ w - btnSize, y1, btnSize, btnSize },
			{ 0, y2, btnSize, btnSize },
			{ w - btnSize, y2, btnSize, btnSize },
			{ 0, y3, btnSize, btnSize },
			{ w - btnSize, y3, btnSize, btnSize },
			{ w - btnSize - tw4 - 24, y4, tw4 + btnSize + 24, btnSize },
		}

		for i, btn in ipairs(buttons) do
			local bx, by, bw, bh = unpack(btn)
			if mx > bx and my > by and mx < bx+bw and my < by+bh then
				cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
						surface.SetDrawColor(color_fg)
						surface.DrawOutlinedRect(bx, by, bw, bh, 3)
					render.OverrideBlend( false )
				cam.PopModelMatrix()
				return i
			end
		end
	end
end