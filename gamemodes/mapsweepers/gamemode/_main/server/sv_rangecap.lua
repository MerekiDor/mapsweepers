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
	Description:

	Systems for capping the range of turrets and NPCs. Intended to be used alongside fog.
--]]

jcms.rangeCapSources = jcms.rangeCapSources or {} --[key] = cap
jcms.rangeCap = jcms.rangeCap or math.huge

hook.Add("jcms_RangeCapUpdated", "jcms_onRangeCapUpdated", function() 
	jcms.rangeCap = math.huge
	for k, cap in pairs(jcms.rangeCapSources) do
		if not IsValid(k) then 
			jcms.rangeCapSources[k] = nil
			continue
		end

		jcms.rangeCap = math.min(cap, jcms.rangeCap)
	end
end)

function jcms.rangeCap_SetSource(key, cap)
	jcms.rangeCapSources[key] = cap
	hook.Call("jcms_RangeCapUpdated")
end


-- // Re-routes {{{
	--TODO: Need to make NPCs also respect the range-cap. Although I've left this out for the prototype since I'm using it for zombies rn.

-- // }}}