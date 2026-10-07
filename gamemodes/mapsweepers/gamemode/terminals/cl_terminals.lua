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

-- Local stuff {{{

	function jcms.terminal_getGlitchMatrix(div, baseAddition)
		baseAddition = baseAddition or 0
		local matrix = Matrix()
		matrix:Translate(Vector(0,0, baseAddition + (2 + (math.random() < 0.023 and math.random() or 0))/(div or 8)))
		return matrix
	end

	jcms.terminal_random_data = { 
		'4d', '61', '6e', '20', '73', '74', '61', '6e', '64', '73', '20', '66', '61',
		'63', '65', '20', '74', '6f', '20', '66', '61', '63', '65', '20', '77', '69',
		'74', '68', '20', '74', '68', '65', '20', '69', '72', '72', '61', '74', '69',
		'6f', '6e', '61', '6c', '2e', '20', '48', '65', '20', '66', '65', '65', '6c',
		'73', '20', '77', '69', '74', '68', '69', '6e', '20', '68', '69', '6d', '20',
		'68', '69', '73', '20', '6c', '6f', '6e', '67', '69', '6e', '67', '20', '66',
		'6f', '72', '20', '68', '61', '70', '70', '69', '6e', '65', '73', '73', '20',
		'61', '6e', '64', '20', '66', '6f', '72', '20', '72', '65', '61', '73', '6f',
		'6e', '2e', '20', '54', '68', '65', '20', '61', '62', '73', '75', '72', '64',
		'20', '69', '73', '20', '62', '6f', '72', '6e', '20', '6f', '66', '20', '74',
		'68', '69', '73', '20', '63', '6f', '6e', '66', '72', '6f', '6e', '74', '61',
		'74', '69', '6f', '6e', '20', '62', '65', '74', '77', '65', '65', '6e', '20',
		'74', '68', '65', '20', '68', '75', '6d', '61', '6e', '20', '6e', '65', '65',
		'64', '20', '61', '6e', '64', '20', '74', '68', '65', '20', '75', '6e', '72',
		'65', '61', '73', '6f', '6e', '61', '62', '6c', '65', '20', '73', '69', '6c',
		'65', '6e', '63', '65', '20', '6f', '66', '20', '74', '68', '65', '20', '77',
		'6f', '72', '6c', '64', '2e', '20'
	}

-- }}}


jcms.terminal_themes = {
	jcorp = { Color(64, 0, 0, 200), Color(230, 0, 0), Color(31, 114, 147) },
	mafia = { Color(200, 136, 17, 55), Color(255, 255, 0), Color(255, 124, 36) },

	antlion = { Color(200, 23, 17, 55), Color(255, 255, 0), Color(255, 124, 36) },
	combine = { Color(0, 242, 255, 55), Color(0, 168, 229, 210), Color(215, 38, 42) },
	rebel = { Color(32, 20, 255, 54), Color(143, 67, 229), Color(21, 224, 21) },
	zombie = { Color(58, 12, 0, 200), Color(204, 50, 50), Color(65, 207, 65) }
}

jcms.terminal_modeTypes = {}

-- // Terminal Includes {{{
	do 
		local terminalFiles, _ = file.Find( "mapsweepers/gamemode/terminals/types/*.lua", "LUA")
		for i, v in ipairs(terminalFiles) do 
			include("types/" .. v)
		end
	end
-- // }}}


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
