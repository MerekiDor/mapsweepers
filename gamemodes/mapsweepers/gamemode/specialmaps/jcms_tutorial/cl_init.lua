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

--[[
	{
		v = Vector(""),
		a = Angle(0, 0, 0),
		width = 1024,
		box1 = Vector(""),
		box2 = Vector(""),
		
		content = {
			{ "Title", "Text" },
		}
	}
--]]

jcms.tutorPoints = {
	{
		v = Vector(2211, -1311, -141),
		a = Angle(90, 180, 0),

		box1 = Vector(2182, -1439, -382),
		box2 = Vector(2318, -1183, -231),
		width = 1024,
		scale = 3,
		content = {
			{ "#jcms.t_1a_title", "" }
		}
	},

	{
		v = Vector(1761, -1373, -319),
		a = Angle(0, 90, 0),

		box1 = Vector(1951, -929, -378),
		box2 = Vector(1587, -1311, -239),
		width = 1024,
		scale = 3,
		content = {
			{ "#jcms.t_2a_title", "#jcms.t_2a_desc" }
		}
	},

	{
		v = Vector(1567, -1435, -321),
		a = Angle(0, 90, 0),

		box1 = Vector(1602, -1301, -289),
		box2 = Vector(1531, -1445, -346),
		width = 700,
		scale = 0.6,
		content = {
			{ "#jcms.t_3a_title", "#jcms.t_3a_desc" }
		}
	},

	{
		v = Vector(2027, -1310, -339),
		a = Angle(-24, 180, 0),

		box1 = Vector(1874, -1187, -243),
		box2 = Vector(2053, -1442, -388),
		width = 1024,
		content = {
			{ "#jcms.t_4a_title", "#jcms.t_4a_desc" },
			{ "#jcms.t_4b_title", "#jcms.t_4b_desc" }
		}
	},

	{
		v = Vector(2007, -1380, -339),
		a = Angle(-24, 150, 0),

		box1 = Vector(1874, -1187, -243),
		box2 = Vector(2053, -1442, -388),
		width = 1024,
		
		color = jcms.color_alert,
		content = {
			{ "#jcms.t_nosw_title", "#jcms.t_nosw_desc", color = jcms.color_alert },
		},
		cond = function()
			local wep = LocalPlayer():GetActiveWeapon()

			return not IsValid(wep)
		end
	},

	{
		v = Vector(2288, -1243, -305),
		a = Angle(0, 220, 0),

		box1 = Vector(2084, -1190, -255),
		box2 = Vector(2328, -1440, -383),
		width = 1200,
		scale = 0.8,
		content = {
			{ "#jcms.t_5a_title", "#jcms.t_5a_desc" }
		}
	},

	{
		v = Vector(2288, -1243, -330),
		a = Angle(0, 220, 0),

		box1 = Vector(2084, -1190, -255),
		box2 = Vector(2328, -1440, -383),
		width = 1200,

		bgcol = jcms.color_bright_alt,
		bga = 0.3,
		content = {
			{ "#jcms.t_6a_title", "#jcms.t_6a_desc", color = jcms.color_bright_alt	 }
		}
	},

	{
		v = Vector(2287, -1382, -320),
		a = Angle(0, 140, 0),

		box1 = Vector(2084, -1190, -255),
		box2 = Vector(2328, -1440, -383),
		width = 1200,
		content = {
			{ "#jcms.t_7a_title", "#jcms.t_7a_desc" }
		},
		cond = function()
			for i, ent in ipairs(ents.FindByClass "jcms_terminal") do
				if ent:GetNWString("jcms_terminal_modeType") == "circuit" then
					return true
				end
			end
		end
	},

	{
		v = Vector(2665, -1398, -298),
		a = Angle(0, 160, 0),

		box1 = Vector(2426, -1153, -387),
		box2 = Vector(2808, -1575, -160),
		width = 900,
		scale = 1.25,

		bgcol = jcms.color_bright_alt,
		bga = 0.3,
		content = {
			{ "#jcms.t_8a_title", "#jcms.t_8a_desc", color = jcms.color_bright_alt }
		}
	},

	{
		v = Vector(2660, -1410, -324),
		a = Angle(0, 160, 0),

		box1 = Vector(2426, -1153, -387),
		box2 = Vector(2808, -1575, -160),
		width = 900,
		scale = 0.9,
		content = {
			{ "#jcms.t_9a_title", "#jcms.t_9a_desc" }
		}
	},

	{
		v = Vector(3098, -1413, -319),
		a = Angle(0, 150, 0),

		box1 = Vector(2878, -1563, -385),
		box2 = Vector(3334, -1098, -184),
		width = 1100,

		bgcol = jcms.color_bright_alt,
		bga = 0.6,
		content = {
			{ "#jcms.t_10a_title", "#jcms.t_10a_desc", color = jcms.color_bright_alt }
		}
	},

	{
		v = Vector(3090, -1430, -338),
		a = Angle(0, 150, 0),

		box1 = Vector(2878, -1563, -385),
		box2 = Vector(3334, -1098, -184),
		width = 1100,
		content = {
			{ "#jcms.t_11a_title", "#jcms.t_11a_desc" }
		}
	},

	{
		v = Vector(3396, -1265, -254),
		a = Angle(0, 180, 0),

		box1 = Vector(2878, -1563, -385),
		box2 = Vector(3418, -1045, -232),
		width = 900,
		scale = 2,

		bgcol = jcms.color_bright_alt,
		bga = 0.6,
		content = {
			{ "#jcms.t_12a_title", "#jcms.t_12a_desc", color = jcms.color_bright_alt }
		}
	},

	{
		v = Vector(3190, -969, -304),
		a = Angle(0, 270, 0),

		box1 = Vector(2957, -1321, -269),
		box2 = Vector(3479, -952, -385),
		width = 1660,
		scale = 1.5,

		bgcol = jcms.color_bright_alt,
		bga = 0.3,
		content = {
			{ "#jcms.t_13a_title", "#jcms.t_13a_desc", color = jcms.color_bright_alt }
		}
	},

	{
		v = Vector(3166, -969, -335),
		a = Angle(0, 270, 0),

		box1 = Vector(2957, -1321, -269),
		box2 = Vector(3479, -952, -385),
		width = 1200,
		content = {
			{ "#jcms.t_14a_title", "#jcms.t_14a_desc" }
		}
	},

	{
		v = Vector(3145, -759, -317),
		a = Angle(0, 270, 0),

		box1 = Vector(3327, -942, -271),
		box2 = Vector(3019, -745, -410),
		width = 1024,
		content = {
			{ "#jcms.t_15a_title", "#jcms.t_15a_desc" }
		}
	},

	{
		v = Vector(3460, -825, -302),
		a = Angle(0, 180, 0),

		box1 = Vector(3261, -706, -416),
		box2 = Vector(3488, -950, -122),
		width = 1024,
		scale = 2,

		bgcol = jcms.color_bright_alt,
		bga = 0.5,
		content = {
			{ "#jcms.t_16a_title", "#jcms.t_16a_desc", color = jcms.color_bright_alt }
		}
	},

	{
		v = Vector(3466, -825, -332),
		a = Angle(0, 180, 0),

		box1 = Vector(3261, -706, -416),
		box2 = Vector(3488, -950, -122),
		width = 1300,
		bga = 0.4,
		content = {
			{ "#jcms.t_17a_title", "#jcms.t_17a_desc" }
		}
	},

	{
		v = Vector(2270, -468, -186),
		a = Angle(0, 270, 0),

		box1 = Vector(2140, -447, -106),
		box2 = Vector(2401, -703, -258),
		width = 1000,
		scale = 2.3,
		content = {
			{ "#jcms.t_18a_title", "#jcms.t_18a_desc" }
		},
		cond = function()
			return not not jcms.orders.turret_gatling
		end
	},

	{
		v = Vector(2622, -892, -180),
		a = Angle(0, 30, 0),

		box1 = Vector(2947, -696, -106),
		box2 = Vector(2542, -976, -265),
		width = 1200,
		scale = 1.2,
		content = {
			{ "#jcms.t_19a_title", "#jcms.t_19a_desc" }
		}
	},

	{
		v = Vector(2622, -892, -211),
		a = Angle(0, 30, 0),

		box1 = Vector(2947, -696, -106),
		box2 = Vector(2542, -976, -265),
		width = 1200,
		scale = 1.2,

		bgcol = jcms.color_bright_alt,
		bga = 0.5,
		content = {
			{ "#jcms.t_20a_title", "#jcms.t_20a_desc", color = jcms.color_bright_alt },
			{ "#jcms.t_20b_title", "#jcms.t_20b_desc", color = jcms.color_bright_alt }
		}
	},

	{
		v = Vector(2163, -833, -194),
		a = Angle(0, 0, 0),

		box1 = Vector(2456, -976, -116),
		box2 = Vector(2103, -693, -251),
		width = 1324,
		scale = 1.3,
		content = {
			{ "#jcms.t_21a_title", "#jcms.t_21a_desc" }
		}
	},

	{
		v = Vector(2132, -170, -175),
		a = Angle(0, 270, 0),

		box1 = Vector(2399, -417, -97),
		box2 = Vector(1826, -126, -281),
		width = 1224,
		content = {
			{ "#jcms.t_22a_title", "#jcms.t_22a_desc" }
		}
	},

	{
		v = Vector(2162, -170, -205),
		a = Angle(0, 270, 0),

		box1 = Vector(2399, -417, -97),
		box2 = Vector(1826, -126, -281),
		width = 1224,
		scale = 1.5,

		bgcol = jcms.color_bright_alt,
		bga = 0.3,
		content = {
			{ "#jcms.t_23a_title", "#jcms.t_23a_desc", color = jcms.color_bright_alt }
		}
	},

	{
		v = Vector(1792, -170, -185),
		a = Angle(0, 270, 0),

		box1 = Vector(2087, -160, -128),
		box2 = Vector(1559, -419, -258),
		width = 1224,
		scale = 1.5,
		content = {
			{ "#jcms.t_24a_title", "#jcms.t_24a_desc" },
			{ "#jcms.t_24b_title", "#jcms.t_24b_desc" }
		}
	},

	{
		v = Vector(280, -167, 73),
		a = Angle(0, 270, 0),

		box1 = Vector(196, -157, 126),
		box2 = Vector(449, -425, -4),
		width = 850,
		scale = 1.5,

		bgcol = jcms.color_bright_alt,
		bga = 0.5,
		content = {
			{ "#jcms.t_25a_title", "#jcms.t_25a_desc", color = jcms.color_bright_alt }
		}
	},

	{
		v = Vector(315, -167, 46),
		a = Angle(0, 270, 0),

		box1 = Vector(196, -157, 126),
		box2 = Vector(449, -425, -4),
		width = 850,
		scale = 1.3,
		bga = 0.5,
		content = {
			{ "#jcms.t_26a_title", "#jcms.t_26a_desc" }
		}
	},

	{
		v = Vector(0, -146, 32),
		a = Angle(0, 270, 0),

		box1 = Vector(-117, -23, 144),
		box2 = Vector(228, -458, -28),
		width = 850,
		bga = 0.8,
		content = {
			{ "#jcms.t_27a_title", "#jcms.t_27a_desc" }
		},
		cond = function()
			return not not jcms.orders.carpetbombing and not jcms.orders.orbitalbeam
		end
	},

	{
		v = Vector(80, -146, 32),
		a = Angle(0, 270, 0),

		box1 = Vector(-117, -23, 144),
		box2 = Vector(228, -458, -28),
		width = 850,

		bgcol = jcms.color_bright_alt,
		bga = 0.8,
		content = {
			{ "#jcms.t_28a_title", "#jcms.t_28a_desc", color = jcms.color_bright_alt }
		},
		cond = function()
			return not not jcms.orders.carpetbombing and not jcms.orders.orbitalbeam
		end
	},

	{
		v = Vector(-51, -64, 64),
		a = Angle(0, 300, 0),

		box1 = Vector(-117, -23, 144),
		box2 = Vector(228, -458, -28),
		width = 700,
		scale = 2,
		bga = 0.4,
		content = {
			{ "#jcms.t_29a_title", "#jcms.t_29a_desc" }
		},
		cond = function()
			return not not jcms.orders.orbitalbeam
		end
	},

	{
		v = Vector(48, -48, 64),
		a = Angle(0, 270, 0),

		box1 = Vector(-117, -23, 144),
		box2 = Vector(228, -458, -28),
		width = 700,
		scale = 2,

		bgcol = jcms.color_bright_alt,
		bga = 0.5,
		content = {
			{ "#jcms.t_30a_title", "#jcms.t_30a_desc", color = jcms.color_bright_alt }
		},
		cond = function()
			return not not (jcms.orders.restock and jcms.orders.firstaid)
		end
	},

	{
		v = Vector(-96, -730, 66),
		a = Angle(0, 90, 0),

		box1 = Vector(-50, -281, -7),
		box2 = Vector(-214, -739, 223),
		width = 1000,
		scale = 1.5,

		bgcol = jcms.color_bright_alt,
		bga = 0.5,
		content = {
			{ "#jcms.t_31a_title", "#jcms.t_31a_desc", color = jcms.color_bright_alt }
		}
	},

	{
		v = Vector(-106, -728, 43),
		a = Angle(0, 90, 0),

		box1 = Vector(-50, -281, -7),
		box2 = Vector(-214, -739, 223),
		width = 1000,
		scale = 1.5,

		bgcol = jcms.color_bright_alt,
		bga = 0.5,
		content = {
			{ "#jcms.t_32a_title", "#jcms.t_32a_desc", color = jcms.color_bright_alt }
		}
	},

	{
		v = Vector(9, -657, 63),
		a = Angle(0, 128, 0),

		box1 = Vector(58, -730, 214),
		box2 = Vector(-202, -469, -12),
		width = 900,
		scale = 1.5,
		bga = 0.5,
		content = {
			{ "#jcms.t_33a_title", "#jcms.t_33a_desc" }
		}
	},

	{
		v = Vector(1110, -1282, 63),
		a = Angle(0, 180, 0),

		box1 = Vector(1140, -1409, 0),
		box2 = Vector(697, -1150, 257),
		scale = 2,

		bgcol = jcms.color_bright_alt,
		bga = 0.5,
		content = {
			{ "#jcms.t_34a_title", "#jcms.t_34a_desc", color = jcms.color_bright_alt }
		}
	},

	{
		v = Vector(1725, -1522, 128),
		a = Angle(15, 90, 0),

		box1 = Vector(1857, -1634, 258),
		box2 = Vector(1406, -1152, 0),
		width = 1200,
		scale = 3,
		bga = 0.5,
		content = {
			{ "#jcms.t_35a_title", "#jcms.t_35a_desc" }
		}
	},

	{
		v = Vector(1558, -1402, 80),
		a = Angle(0, 90, 0),

		box1 = Vector(1706, -1408, 134),
		box2 = Vector(1142, -1149, -1),
		width = 1000,
		scale = 1.5,

		bgcol = jcms.color_bright_alt,
		bga = 0.9,
		content = {
			{ "#jcms.t_36a_title", "#jcms.t_36a_desc", color = jcms.color_bright_alt }
		}
	},

	{
		v = Vector(1548, -1404, 52),
		a = Angle(0, 90, 0),

		box1 = Vector(1706, -1408, 134),
		box2 = Vector(1142, -1149, -1),
		width = 1200,
		bga = 0.5,
		content = {
			{ "#jcms.t_37a_title", "#jcms.t_37a_desc" }
		}
	},

	{
		v = Vector(1475, -1804, 64),
		a = Angle(0, 90, 0),

		box1 = Vector(1603, -1507, 0),
		box2 = Vector(1343, -1869, 156),
		width = 1200,

		bgcol = jcms.color_bright_alt,
		bga = 0.8,
		content = {
			{ "#jcms.t_38a_title", "#jcms.t_38a_desc", color = jcms.color_bright_alt }
		}
	}
}

hook.Add("Think", "jcms_TutorialSpeedrunStart", function()
	if not (jcms.statistics and jcms.statistics.playedTutorial) then return end

	local ply = LocalPlayer()
	if not jcms.tutorial_speedrunTime then
		local pos = ply:GetPos()
		if pos.y <= -1184 then
			jcms.tutorial_speedrunTime = CurTime()
			surface.PlaySound("buttons/blip1.wav")
		end
	elseif ply:GetObserverMode() ~= OBS_MODE_NONE and not jcms.tutorial_speedrunTimeEnd then
		jcms.tutorial_speedrunTimeEnd = CurTime()
	end
end)

hook.Add("PreDrawEffects", "jcms_TutorialSpeedrunHUD", function()
	if jcms.tutorial_speedrunTime then
		local elapsed = (jcms.tutorial_speedrunTimeEnd or CurTime()) - jcms.tutorial_speedrunTime
		local time = string.FormattedTime(elapsed)

		local formatted = string.format("%02i:%02i:%02i .%02i", time.h, time.m, time.s, time.ms)
		cam.Start2D()
			draw.SimpleText("#jcms.tutorial_speedrun", "jcms_medium", ScrW() - 84, 84, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
			draw.SimpleText(formatted, "jcms_big", ScrW() - 84, 84, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText("#jcms.tutorial_speedrun", "jcms_medium", ScrW() - 84 - 1, 84 - 1, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(formatted, "jcms_big", ScrW() - 84 - 2, 84 + 2, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			render.OverrideBlend( false )
		cam.End2D()
	end
end)

hook.Add("PostDrawTranslucentRenderables", "jcms_Tutorial", function(bDepth, bSkybox)
	local W = 7
	local ep = EyePos()
	
	for i, tp in ipairs(jcms.tutorPoints) do
		local inRange = ep:WithinAABox(tp.box1, tp.box2)
		local cond = not tp.cond or tp.cond()
		
		if not bDepth and not bSkybox then
			tp.f = ((tp.f or 0)*W + ((inRange and cond) and 1 or 0))/(W+1)
		else
			tp.f = tp.f or 0
		end
		
		local scale = tp.scale or 1
		
		if tp.f > 0.01 then
			local ang = Angle(tp.a)
			ang:RotateAroundAxis(ang:Forward(), 90)
			ang:RotateAroundAxis(ang:Right(), -90)
			
			if not tp.markup then
				local markupString = ""
				
				for j, data in ipairs(tp.content) do
					local col = data.color or jcms.color_bright
					local phrase1 = language.GetPhrase( data[1]:sub(2, -1) )
					local phrase2 = language.GetPhrase( data[2]:sub(2, -1) )
					markupString = markupString .. ("<color=%d,%d,%d><font=%s>%s</font>\n\t<font=%s>%s</font>\n\n"):format(col.r, col.g, col.b, "jcms_hud_big", phrase1, "jcms_hud_medium", phrase2)
				end
				
				tp.markup = markup.Parse(markupString, tp.width)
			end
			
			local offv = tp.v + ang:Up() * Lerp(tp.f*tp.f, -2, 0)
			
			cam.Start3D2D(offv, ang, scale/16)
				surface.SetAlphaMultiplier((tp.bga or 0.156)*tp.f)
				surface.SetDrawColor(tp.bgcol or jcms.color_bright)
				
				local mw, mh = (tp.markup:GetWidth())*tp.f, (tp.markup:GetHeight())
				jcms.hud_DrawNoiseRect(-mw/2, -mh/2, mw, mh, 1500)
				jcms.hud_DrawStripedRect(-mw/2 - 32, -mh/2, 16, mh, 64)
				jcms.hud_DrawStripedRect(mw/2 + 16, -mh/2, 16, mh, 64)
				surface.SetAlphaMultiplier(1)
				tp.markup:Draw(0, 0, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, tp.f*32)
			cam.End3D2D()
			
			offv:Add(ang:Up() * (0.8*tp.f))
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				cam.Start3D2D(offv, ang, scale/16)
					tp.markup:Draw(0, 0, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, tp.f*255)
				cam.End3D2D()
			render.OverrideBlend( false )
		end
	end
end)

function jcms.offgame_paint_PostMissionTutorial(p, w, h)
	p.time = p.time + FrameTime()

	if p.time <= 4.5 then
		local f1 = math.ease.InOutCirc( math.Clamp(math.TimeFraction(0.9, 1.5, p.time), 0, 1) )
		local f2 = math.Clamp(1-math.TimeFraction(2.9, 3.5, p.time), 0, 1)
		local f3 = 1 / ( p.time + 1 )
		local f4 = math.ease.InOutCirc( math.Clamp(math.TimeFraction(0.7, 1.3, p.time), 0, 1) )
		local f5 = math.ease.InQuint( math.Clamp(math.TimeFraction(3, 4, p.time), 0, 1) )

		surface.SetAlphaMultiplier(f3)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			surface.SetDrawColor(jcms.color_bright)
			jcms.hud_DrawNoiseRect(0, 0, w, h, h)
			render.OverrideBlend( false )
		surface.SetAlphaMultiplier(1)

		if f1 > 0 then
			if not p.didSfx then
				p.didSfx = true
				surface.PlaySound("buttons/combine_button1.wav")
				surface.PlaySound("npc/scanner/cbot_servochatter.wav")
			end
			local size = f4 * Lerp(f5, 72, h)
			surface.SetAlphaMultiplier(f4 * 0.6)
				surface.SetDrawColor(jcms.color_dark)
				surface.DrawRect(0, h/2 - size/2, w, size)
			surface.SetAlphaMultiplier(1)

			local col = Color(255, 255, 255, 255 * f2)
			col.r = Lerp(f1, col.r, jcms.color_bright.r)
			col.g = Lerp(f1, col.g, jcms.color_bright.g)
			col.b = Lerp(f1, col.b, jcms.color_bright.b)
			draw.SimpleText("#jcms.tutorialcomplete", "jcms_hud_medium", w/2, h/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			col.r = Lerp(f3, col.r, jcms.color_bright.r)
			col.g = Lerp(f3, col.g, jcms.color_bright.g)
			col.b = Lerp(f3, col.b, jcms.color_bright.b)
			col.a = 255 * (1 - f1)
			surface.SetDrawColor(col)
			surface.DrawRect(16, h/2 - size/2, w - 32, 1)
			surface.DrawRect(16, h/2 + size/2 - 1, w - 32, 1)
		end
	else
		local f1 = 1 - 1 / ( (p.time - 4.5)/10 + 1 )
		local f2 = math.ease.OutCirc( math.Clamp(math.TimeFraction(4.54, 5.34, p.time), 0, 1) )
		local f3 = math.ease.OutCirc( math.Clamp(math.TimeFraction(5.7, 6.5, p.time), 0, 1) )

		surface.SetAlphaMultiplier(f1)
			surface.SetDrawColor(jcms.color_bright)
			jcms.hud_DrawNoiseRect(0, 0, w, h, Lerp(f1, h, 128))

			if IsValid(p.p1) then
				p.p1:SetPos(w/2 - p.p1:GetWide() / 2 - 32, Lerp(f2, h, h*0.32))

				if IsValid(p.p2) then
					p.p2:SetPos(w/2 - p.p2:GetWide() / 2 + 32, Lerp(f2, h, h*0.32 + p.p1:GetTall() + 32))
				end

				if jcms.tutorial_speedrunTime then
					surface.SetAlphaMultiplier(f3)
					local elapsed = (jcms.tutorial_speedrunTimeEnd or CurTime()) - jcms.tutorial_speedrunTime
					if elapsed >= 5 then
						local time = string.FormattedTime(elapsed)
						local formatted = language.GetPhrase("jcms.tutorial_speedrun") .. ": " .. string.format("%02i:%02i:%02i .%02i", time.h, time.m, time.s, time.ms)
						draw.SimpleText(formatted, "jcms_medium", p.p1:GetX() + 16, p.p1:GetY() - 16, jcms.color_bright_alt, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
						surface.SetAlphaMultiplier(f1)
					end
				end
			end

			if IsValid(p.p3) then
				p.p3:SetPos(w/2 - p.p3:GetWide()/2,  -p.p3:GetTall() * (1-f3))
			end

		surface.SetAlphaMultiplier(1)
	end
end

function jcms.offgame_paint_TutorialCongratulations(p, w, h)
	surface.SetDrawColor(jcms.color_dark)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(jcms.color_bright)
	jcms.hud_DrawStripedRect(14, 46, 132, 132, 32, CurTime() % 1 * 8)
	surface.SetDrawColor(jcms.color_pulsing)
	surface.DrawRect(0, 8, 1, h - 16)
	surface.DrawRect(w - 1, 8, 1, h - 16)
	draw.SimpleText("#jcms.tutorialpost_title", "jcms_hud_small", 24, 4, jcms.color_bright)
	draw.SimpleText("#jcms.tutorialpost_desc1", "jcms_medium", 172, 64, jcms.color_pulsing)
	draw.SimpleText("#jcms.tutorialpost_desc2", "jcms_medium", 176, 64 + 24, jcms.color_pulsing)
end

function jcms.offgame_paint_TutorialExtras(p, w, h)
	surface.SetDrawColor(jcms.color_dark)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(jcms.color_pulsing)
	surface.DrawRect(0, 8, 1, h - 16)
	surface.DrawRect(w - 1, 8, 1, h - 16)
	jcms.hud_DrawStripedRect(4, h - 4, w-8, 4, 32, CurTime() % 1 * 8)

	draw.SimpleText("#jcms.tutorialpost_maps", "jcms_medium", w - 24, 8, jcms.color_bright, TEXT_ALIGN_RIGHT)
	draw.SimpleText("#jcms.tutorialpost_desc3", "jcms_medium", 24, 48, jcms.color_pulsing)
	draw.SimpleText("#jcms.tutorialpost_desc4", "jcms_medium", 28, 48 + 24, jcms.color_pulsing)
end

jcms.tutorialFinished = false
hook.Add("Think", "jcms_Tutorial", function()
	if LocalPlayer():GetObserverMode() == OBS_MODE_ROAMING and not jcms.tutorialFinished then
		jcms.tutorialFinished = true
		EmitSound("music/hl2_song20_submix0.mp3", EyePos(), -2, CHAN_AUTO, 1, 75)

		if IsValid(jcms.offgame) then
			jcms.offgame:Remove()
		end
		
		local pnl = vgui.Create("DPanel", GetHUDPanel())
		jcms.offgame = pnl

		pnl:SetSize(ScrW(), ScrH())
		pnl:Center()
		pnl:MakePopup()

		pnl.p1 = pnl:Add("DPanel")
		pnl.p1:SetPos(-1024, -1024)
		pnl.p1:SetSize(700, 192)
		pnl.p1.av = pnl.p1:Add("AvatarImage")
		pnl.p1.av:SetPos(16, 48)
		pnl.p1.av:SetSize(128, 128)
		pnl.p1.av:SetPlayer(LocalPlayer(), 128)
		pnl.p1.Paint = jcms.offgame_paint_TutorialCongratulations

		pnl.p1.leave = pnl.p1:Add("DButton")
		pnl.p1.leave:SetSize(230, 32)
		pnl.p1.leave:SetPos(pnl.p1:GetWide() - 230 - 32, pnl.p1:GetTall() - 32 - 16)
		pnl.p1.leave:SetText("#jcms.tutorialpost_disconnect")
		pnl.p1.leave.Paint = jcms.paint_ButtonFilled
		pnl.p1.leave.jFont = "jcms_medium"
		function pnl.p1.leave:DoClick()
			RunConsoleCommand("disconnect")
		end

		pnl.p2 = pnl:Add("DPanel")
		pnl.p2:SetPos(-1024, -1024)
		pnl.p2:SetSize(700, 192)
		pnl.p2.Paint = jcms.offgame_paint_TutorialExtras
		pnl.p2.bRecMaps = pnl.p2:Add("DButton")
		pnl.p2.bRecMaps:SetPos(32, 114)
		pnl.p2.bRecMaps:SetSize(pnl.p2:GetWide() - 64, 32)
		pnl.p2.bRecMaps:SetText("#jcms.extra_maps")
		pnl.p2.bRecMaps.jFont = "jcms_medium"
		pnl.p2.bRecMaps.Paint = jcms.paint_ButtonFilled
		function pnl.p2.bRecMaps:DoClick()
			gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3522258079")
		end

		pnl.p3 = jcms.offgame_CreateSocialPanel(pnl, -1024, -1024, 600, 128)

		pnl.Paint = jcms.offgame_paint_PostMissionTutorial
		pnl.allowSceneRender = true
		pnl.time = 0
		
		file.Write("mapsweepers/client/tutorial_complete.dat", "")
	end
end)