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

-- // Current {{{

	jcms.objective_title = jcms.objective_title or nil
	jcms.objectives = jcms.objectives or {}

-- // }}}

-- // Functions {{{

	function jcms.objective_Localize(obj)
		return type(obj)=="string" and language.GetPhrase("jcms.obj_" .. obj) or "???"
	end

	function jcms.objective_UpdateEverything(dataString)
		local missionType, objectivesString = dataString:match("^(%w+):([%w%d_,-]+)")
		local objectivesList = string.Explode(",%s*", objectivesString, true)
		
		jcms.objective_title = missionType

		table.Empty(jcms.objectives)
		for i, objectiveKeyValue in ipairs(objectivesList) do
			local type, x, n, percent, complete = objectiveKeyValue:match("(%w+)%-(%d+)%-(%d+)%-([10])([10])")
			if complete then
				table.insert(jcms.objectives, { type = type, progress = tonumber(x), n = tonumber(n), percent = percent == "1", completed = complete=="1" })
			end
		end
	end

-- // }}}
