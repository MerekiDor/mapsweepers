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

-- See sv_missions.lua if you want to make an addon that adds a custom mission type.

-- // Missions {{{

	-- Mission tags: 'altincome', 'bossmission', 'extraorders', 'hacking', 'infighting', 'killsrequired', 'naturalhazard', 'nobounty', 'rarebosses', 'timer'

	jcms.missions = {
		thumperreactivation = {
			faction = "antlion",
			tags = { "hacking" }
		},

		miningoperations = {
			faction = "antlion",
			tags = { "extraorders", "altincome" }
		},

		thumpersabotage = {
			faction = "combine",
			tags = { "infighting", "extraorders" }
		},

		datadownload = {
			faction = "combine",
			tags = { "nobounty", "altincome" }
		},

		mainframe = {
			faction = "rebel",
			tags = { "hacking", "infighting" }
		},
		
		infestation = {
			faction = "zombie",
			tags = { "naturalhazard", "extraorders" }
		},
		
		hell = {
			faction = "everyone",
			tags = { "rarebosses" }
		},

		violenceflashpoints = {
			faction = "any",
			tags = { "rarebosses", "killsrequired" }
		},

		payload = {
			faction = "any",
			tags = { "hacking" }
		},

		eschaton = {
			faction = "everyone",
			tags = { "bossmission", "rarebosses" }
		}
	}

	-- A lot of people tend to report issues with custom-made missions to Octantis Addons.
	-- We created this list to mark a mission as "official". Missions added by extensions
	-- get a special tag that lets people know that they are fanmade, so that issues are reported
	-- directly to extension dev rather than Octantis Addons. This happened way too many times.
	jcms.missions_official = {
		["thumperreactivation"] = true,
		["violenceflashpoints"] = true,
		["miningoperations"] = true,
		["thumpersabotage"] = true,
		["datadownload"] = true,
		["infestation"] = true,
		["mainframe"] = true,
		["eschaton"] = true,
		["payload"] = true,
		["hell"] = true
	}

-- // }}}

-- // Other {{{

	function jcms.mission_GetTypesByFaction(faction)
		local t = {}

		for misType, data in pairs(jcms.missions) do
			if data.faction == faction then
				table.insert(t, misType)
			end
		end

		table.sort(t)
		return t
	end

	function jcms.mission_GetOrder(split)
		local sorted = {}
		local missionsGeneric = {}

		for name, missionData in pairs(jcms.missions) do
			if missionData.faction == "any" then
				table.insert(missionsGeneric, name)
			else
				table.insert(sorted, name)
			end
		end

		table.sort(sorted, function(first, last)
			local data1, data2 = jcms.missions[ first ], jcms.missions[ last ]
			if data1.faction == data2.faction then
				return first < last
			else
				return data1.faction < data2.faction
			end
		end)

		table.sort(missionsGeneric)

		if split then
			return sorted, missionsGeneric
		else
			for i, name in ipairs(missionsGeneric) do
				missionsGeneric[i] = nil
				sorted[#sorted + 1] = name 
			end

			return sorted
		end
	end

	function jcms.mission_GetTagColor(tag)
		return tag == "bossmission" and jcms.color_alert or jcms.color_bright_alt
	end

-- // }}}