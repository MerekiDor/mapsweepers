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

-- // Current {{{

	jcms.objective_title = jcms.objective_title or nil
	jcms.objectives = jcms.objectives or {}

-- // }}}

-- // Functions {{{

	function jcms.objective_Localize(obj)
		if type(obj) == "string" then
			local key1 = "jcms.obj_" .. obj
			local loc = language.GetPhrase(key1)
			if loc == key1 then
				loc = language.GetPhrase(obj)
			end
			return loc
		else
			return "???"
		end
	end

	function jcms.objective_UpdateEverything(missionType, newObjectives)
		jcms.objective_title = tostring(missionType)
		table.Empty(jcms.objectives)
		table.Add(jcms.objectives, newObjectives)
	end

-- // }}}

-- // Drawing {{{

	jcms.objective_drawStyles = {
		[0] = function(i, objective) -- Default
			local off = 2

			local color, colorDark = jcms.color_bright, jcms.color_dark
			if objective.completed then
				color, colorDark = jcms.color_bright_alt, jcms.color_dark_alt
			end
	
			local str = jcms.objective_Localize(objective.type)
			local x = objective.progress
			local n = objective.n
	
			if x and n>0 then
				local progress = math.Clamp(x / n, 0, 1)
				objective.fProgress = progress
				objective.anim_fProgress = ((objective.anim_fProgress or progress)*8 + progress)/9
	
				local barw = 200
				local progressString
				if objective.percent then
					progressString = string.format("%d%%  ", progress*100)
				else
					progressString = string.format("%d/%d  ", x, n)
				end
				surface.SetFont("jcms_hud_small")
				local tw = surface.GetTextSize(progressString)
				if barw - tw <= 32 then
					barw = math.max(barw + 64, barw - tw + 48)
				end
	
				local f = objective.anim_fProgress
				draw.SimpleText(progressString, "jcms_hud_small", 24, 16, colorDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(str, "jcms_hud_small", 32, 2, colorDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					draw.SimpleText(progressString, "jcms_hud_small", 24 + off, 16 + off, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText(str, "jcms_hud_small", 32 + off, 2 + off, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				render.OverrideBlend( false )   

				if objective.percent or (barw-tw-2)/n < 2 then
					surface.SetDrawColor(colorDark)
					surface.DrawRect(24 + tw, 16, barw - tw, 6)
					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					surface.SetDrawColor(color)
					surface.DrawRect(24 + off + tw, 16 + off, (barw - tw)*f, 4)
				else
					surface.SetDrawColor(colorDark)
					local subBarW = (barw-tw-2)/n
					for i=1, n do
						surface.DrawRect(24 + tw + (subBarW+6)*(i-1), 16, subBarW, 6)
					end
					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					surface.SetDrawColor(color)
					for i=1, math.min(n, x) do
						surface.DrawRect(24 + tw + (subBarW+6)*(i-1) + off, 16 + off, subBarW, 8)
					end
				end
				render.OverrideBlend( false )  
			else
				draw.SimpleText(str, "jcms_hud_small", 32, -2, colorDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					draw.SimpleText(str, "jcms_hud_small", 32 + off, -2 + off, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				render.OverrideBlend( false ) 
			end
	
			return true, 70
		end,

		[1] = function(i, objective) -- Timer
			local color, colorDark = jcms.color_bright, jcms.color_dark
			local doDiamond = objective.completed
			local xOff = doDiamond and 24 or 0

			local off = 2
			local str = jcms.objective_Localize(objective.type)
			local x = objective.progress
			local n = objective.n

			draw.SimpleText(str, "jcms_hud_small", xOff, -2, colorDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			
			x = math.min(x, 60*60 - 1) --Max 1h
			local timestr = string.FormattedTime(x, "%02i:%02i")
			draw.SimpleText(timestr, "jcms_hud_medium", xOff+16, -2+48, colorDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			
			if x <= 10 or timestr:sub(-1, -1) == "0" then
				color = jcms.color_alert
			end

			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText(str, "jcms_hud_small", xOff+off, -2+off, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(timestr, "jcms_hud_medium", xOff+16+off, -2+48+off, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			render.OverrideBlend( false ) 

			return doDiamond, 120, color
		end,

		[2] = function(i, objective) -- Healthbar
			local x = objective.progress
			local n = objective.n

			local off = 2
			local frac = math.Clamp(x/n, 0, 1)
			local color, colorDark = objective.completed and jcms.color_alert or jcms.color_bright_alt, frac <= 0.5 and jcms.color_dark or jcms.color_dark_alt

			surface.SetDrawColor(colorDark)
			surface.DrawRect(0, -32, 200, 24)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				surface.SetDrawColor(color)
				surface.DrawOutlinedRect(off, -32+off, 200, 24, 2)
				surface.DrawRect(4+off, -32+4+off, (200-8)*frac, 24-8)
			render.OverrideBlend( false ) 

			return false, 48
		end
	}

	function jcms.objective_Draw(i, objective)
		local f = jcms.objective_drawStyles[ objective.style ] or jcms.objective_drawStyles[0]
		local s, rtn1, rtn2, rtn3 = pcall(f, i, objective)
		if s then
			return rtn1, rtn2, rtn3
		else
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				surface.SetDrawColor(jcms.color_bright)
				jcms.hud_DrawNoiseRect(0, 0, 300, 48, 1000)
			render.OverrideBlend( false ) 

			draw.SimpleText("#jcms.error", "jcms_hud_small", 24, 4, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(rtn1, "jcms_big", 24, 24, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			return false, 50
		end
	end

-- // }}}
