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

-- Entries {{{
	-- entries
	jcms.codex = {
		{
			level = 1,
			name = "#jcms.codex_jcms_name",
			text = "#jcms.codex_jcms"
		},

		{
			level = 4,
			ooc = true,
			name = "#jcms.codex_ourmission_name",
			text = "#jcms.codex_ourmission"
		},
		
		{
			level = 7,
			ooc = true,
			name = "#jcms.codex_factions_name",
			pages = { 
				"#jcms.codex_factions1", 
				"#jcms.codex_factions2", 
				"#jcms.codex_factions3", 
				"#jcms.codex_factions4"
			}
		},

		{
			level = 10,
			name = "#jcms.codex_gambling_name",
			text = "#jcms.codex_gambling"
		},

		{
			level = 12,
			name = "#jcms.codex_metals_name",
			pages = { 
				"#jcms.codex_metals1", 
				"#jcms.codex_metals2", 
				"#jcms.codex_metals3", 
				"#jcms.codex_metals4"
			}
		},

		{
			level = 16,
			name = "#jcms.codex_sweepers_name",
			text = "#jcms.codex_sweepers"
		},

		{
			level = 21,
			name = "#jcms.codex_jcorparmy_name",
			text = "#jcms.codex_jcorparmy"
		},

		{
			level = 23,
			name = "#jcms.codex_clerks_name",
			text = "#jcms.codex_clerks"
		},

		{
			level = 25,
			ooc = true,
			name = "#jcms.codex_respawnsystem_name",
			text = "#jcms.codex_respawnsystem"
		},

		{
			level = 27,
			ooc = true,
			name = "#jcms.codex_thenarrative_name",
			text = "#jcms.codex_thenarrative"
		},

		{
			level = 34,
			name = "#jcms.codex_jenergy_name",
			text = "#jcms.codex_jenergy"
		},

		{
			level = 40,
			name = "#jcms.codex_theevent_name",
			text = "#jcms.codex_theevent"
		}
	}

	-- logs
	jcms.codex_logsUnlocked = jcms.codex_logsUnlocked or {} -- key: id, value: true
	-- TODO save unlocked logs
	jcms.codex_logs = {
		{
			unlock_id = "test",
			name = " Test Unlock ",
			text = " Text of the test unlockable log "
		},
	}

	-- outdated (pre-v1.2) entries
	jcms.codex_legacy = {
		{ 
			level = 1,
			name = "#jcms.codexlegacy_jcms_name",
			text = "#jcms.codexlegacy_jcms"
		},

		{
			level = 4,
			ooc = true,
			name = "#jcms.codexlegacy_world_name",
			text = "#jcms.codexlegacy_world"
		},
		
		{
			level = 7,
			ooc = true,
			name = "#jcms.codexlegacy_factions_name",
			pages = { 
				"#jcms.codexlegacy_factions1", 
				"#jcms.codexlegacy_factions2", 
				"#jcms.codexlegacy_factions3", 
				"#jcms.codexlegacy_factions4"
			}
		}
	}
-- }}}

-- Unlocking logs {{{

	function jcms.codex_UnlockLog(id)
		jcms.codex_logsUnlocked[ id ] = true
	end

	function jcms.codex_GetUnlockedLogs()
		local unlocked = {}

		for i, cdx in ipairs(jcms.codex_logs) do
			if jcms.codex_logsUnlocked[ cdx.unlock_id ] then
				table.insert(unlocked, cdx)
			end
		end

		return unlocked
	end

	function jcms.codex_UnlockRandomLog()
		local locked = {}

		for i, cdx in ipairs(jcms.codex_logs) do
			if not jcms.codex_logsUnlocked[ cdx.unlock_id ] then
				table.insert(locked, cdx)
			end
		end

		if #locked > 0 then
			local cdx = locked[ math.random(1, #locked) ]
			local unlock_id = cdx.unlock_id
			
			jcms.codex_UnlockLog(unlock_id)
			jcms.printf("Unlocked a log: '%s'", unlock_id)

			local totalCount = #jcms.codex_logs
			local unlockedCount = totalCount - #locked + 1
			local str = language.GetPhrase("jcms.codex_logdownloaded"):format( language.GetPhrase(cdx.name), unlockedCount, totalCount )
			jcms.hud_AddNotif(str, true)

			return true, unlock_id
		else
			jcms.printf("Can't unlock a log: all logs are unlocked already")
			return false
		end
	end
-- }}}