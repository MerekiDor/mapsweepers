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
	terms.cheat_changeclass = {
		generate = function(ent)
			return ""
		end,

		command = function(ent, cmd, data, ply)
			local desiredClass = jcms.classesOrder[ cmd ]
			local currentClass = ply:GetNWString("jcms_class", "infantry")

			if desiredClass ~= currentClass then
				jcms.class_Apply(ply, desiredClass)
				ply:EmitSound("items/ammopickup.wav")
				return true
			else
				return false
			end
		end
	}

	terms.cheat_givecash = {
		generate = function(ent)
			return ""
		end,

		command = function(ent, cmd, data, ply)
			local plyCash = ply:GetNWInt("jcms_cash", 0)
			
			local options = { 100, 1000, 10000, -plyCash }
			if options[ cmd ] then
				jcms.giveCash(ply, options[ cmd ])
				return true
			else
				return false
			end
		end
	}

	terms.cheat_giveguns = {
		generate = function(ent)
			return ""
		end,

		command = function(ent, cmd, data, ply)
			if cmd == 1 then
				-- Edit  Loadout
				ply:SendLua("jcms.offgame_ModalLoadoutSelector()")
			elseif cmd == 2 then
				-- Remove Weapon
				local weapon = ply:GetActiveWeapon()

				if IsValid(weapon) and not jcms.util_IsStunstick(weapon) then
					ply:StripWeapon( weapon:GetClass() )
					return true
				else
					return false
				end
			elseif cmd == 3 then
				-- Get Ammo
				return jcms.util_TryGiveAmmo(ply, 100)
			elseif cmd == 4 then
				-- Remove all Ammo
				ply:RemoveAllAmmo()
				return true
			end

			return false
		end
	}
end

if CLIENT then
	terms.cheat_changeclass = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		
		local classes = jcms.classesOrder
		local count = #classes

		if count <= 0 then return end

		local offset = 48
		local cols, rows = 1, 1
		rows = math.max(1, math.floor(math.sqrt(count)))
		cols = math.ceil(count / rows)

		local cellw = w/cols
		local cellh = (h-offset)/rows

		local hoveredIndex, hoveredClass
		for _, class in ipairs(classes) do
			local i = _-1
			local col = math.floor(i / cols)
			local row = i % cols
			
			local classmat = jcms.mat_GetClassMat(class)
			surface.SetMaterial(classmat)
			
			local cellx, celly = (row+0.5)*cellw, (col+0.5)*cellh + offset
			local size = math.max(math.min(cellw, cellh)*0.8, 16)

			if not hoveredClass and mx > cellx-size/2 and my > celly-size/2 and mx < cellx+size/2 and my < celly+size/2 then
				hoveredIndex = _
				hoveredClass = class
			end

			local sel = hoveredClass == class
			if sel then size = size * 1.25 end

			surface.SetDrawColor(color_bg)
			surface.DrawTexturedRectRotated(cellx, celly, size, size, 0)
			surface.SetDrawColor(sel and color_accent or color_fg)
			cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					surface.DrawTexturedRectRotated(cellx, celly, size, size, 0)
				render.OverrideBlend( false )
			cam.PopModelMatrix()
		end

		local str1 = language.GetPhrase("jcms.changeclass")
		local str2 = hoveredClass and language.GetPhrase("jcms.class_" .. hoveredClass) or ""
		draw.SimpleText(str1, "jcms_hud_small", 0, 0, color_bg)
		draw.SimpleText(str2, "jcms_hud_small", w, 0, color_bg, TEXT_ALIGN_RIGHT)
		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText(str1, "jcms_hud_small", 0, 0, color_fg)
				draw.SimpleText(str2, "jcms_hud_small", w, 0, color_accent, TEXT_ALIGN_RIGHT)
			render.OverrideBlend( false )
		cam.PopModelMatrix()

		return hoveredIndex
	end

	terms.cheat_givecash = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		
		local str1 = language.GetPhrase("jcms.cashcheat")
		local _, th = draw.SimpleText(str1, "jcms_hud_score", w/2, 0, color_bg, TEXT_ALIGN_CENTER)
		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText(str1, "jcms_hud_score", w/2, 0, color_fg, TEXT_ALIGN_CENTER)
			render.OverrideBlend( false )
		cam.PopModelMatrix()

		th = th + 16

		local options = {
			"+100 J",
			"+1,000 J",
			"+10,000 J",
			"#jcms.reset"
		}

		local hoveredOption
		local cellpad = 12
		local cellh = (h - th - 8 - cellpad) / #options
		for i, opt in ipairs(options) do
			local y = th + (i-1)*(cellh+cellpad)

			if not hoveredOption and mx > 0 and my > y and mx < w and my < y + cellh then
				hoveredOption = i
			end

			surface.SetDrawColor(color_bg)
			surface.DrawRect(0, y, w, cellh)

			cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					draw.SimpleText(opt, "jcms_hud_medium", w/2, y + cellh/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					if hoveredOption == i then
						surface.SetDrawColor(color_fg)
						surface.DrawOutlinedRect(0, y, w, cellh, 4)
					end
				render.OverrideBlend( false )
			cam.PopModelMatrix()
		end

		return hoveredOption
	end

	terms.cheat_giveguns = function(ent, mx, my, w, h, modedata)
		local color_bg, color_fg, color_accent = jcms.terminal_GetColors(ent)
		
		local str1 = language.GetPhrase("jcms.terminal_weapons")
		local _, th = draw.SimpleText(str1, "jcms_hud_score", w/2, 0, color_bg, TEXT_ALIGN_CENTER)
		cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText(str1, "jcms_hud_score", w/2, 0, color_fg, TEXT_ALIGN_CENTER)
			render.OverrideBlend( false )
		cam.PopModelMatrix()

		th = th + 16

		local options = {
			"#jcms.editloadout",
			"#jcms.removeweapon",
			"#jcms.getammo",
			"#jcms.removeammo",
		}

		local hoveredOption
		local cellpad = 12
		local cellh = math.min( (h - th - 8 - cellpad) / #options, 128 )
		for i, opt in ipairs(options) do
			local y = th + (i-1)*(cellh+cellpad)

			if not hoveredOption and mx > 0 and my > y and mx < w and my < y + cellh then
				hoveredOption = i
			end

			surface.SetDrawColor(color_bg)
			surface.DrawRect(0, y, w, cellh)

			cam.PushModelMatrix(jcms.terminal_getGlitchMatrix(), true)
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					draw.SimpleText(opt, "jcms_hud_medium", w/2, y + cellh/2, color_fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					if hoveredOption == i then
						surface.SetDrawColor(color_fg)
						surface.DrawOutlinedRect(0, y, w, cellh, 4)
					end
				render.OverrideBlend( false )
			cam.PopModelMatrix()
		end

		return hoveredOption
	end
end