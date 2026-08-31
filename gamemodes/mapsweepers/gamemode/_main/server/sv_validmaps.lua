
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

jcms.mapBlacklist = { --CSS and TF2 maps have navmeshes, but they're incompatible with gmod.
	--Map Sweepers
		["jcms_firingrange"] = true,
	--CSS
		["cs_assault"] = true,
		["cs_compound"] = true,
		["cs_havana"] = true,
		["cs_italy"] = true,
		["cs_militia"] = true,
		["cs_office"] = true,

		["de_aztec"] = true,
		["de_cbble"] = true,
		["de_chateau"] = true,
		["de_dust"] = true,
		["de_dust2"] = true,
		["de_inferno"] = true,
		["de_nuke"] = true,
		["de_piranesi"] = true,
		["de_port"] = true,
		["de_prodigy"] = true,
		["de_tides"] = true,
		["de_train"] = true,

	--TF2
		["arena_badlands"] = true,
		["arena_byre"] = true,
		["arena_granary"] = true,
		["arena_lumberyard"] = true,
		["arena_lumberyard_event"] = true,
		["arena_nucleus"] = true,
		["arena_offblast_final"] = true,
		["arena_arena_perks"] = true,
		["arena_ravine"] = true,
		["arena_sawmill"] = true, --10
		["arena_watchtower"] = true,
		["arena_well"] = true,

		["cp_5gorge"] = true,
		["cp_altitude"] = true,
		["cp_ambush_event"] = true,
		["cp_badlands"] = true,
		["cp_brew"] = true,
		["cp_burghausen"] = true,
		["cp_canaveral_5cp"] = true,
		["cp_carrier"] = true,
		["cp_cloak"] = true,
		["cp_coldfront"] = true, --10
		["cp_darkmarsh"] = true,
		["cp_degrootkeep"] = true,
		["cp_degrootkeep_rats"] = true,
		["cp_dustbowl"] = true,
		["cp_egypt_final"] = true,
		["cp_fastlane"] = true,
		["cp_fortezza"] = true,
		["cp_foundry"] = true,
		["cp_freaky_fair"] = true,
		["cp_freight_final1"] = true, -- 20
		["cp_frostwatch"] = true,
		["cp_gorge"] = true,
		["cp_gorge_event"] = true,
		["cp_granary"] = true,
		["cp_gravelpit"] = true,
		["cp_gravelpit_snowy"] = true,
		["cp_gullywash_final1"] = true,
		["cp_hadal"] = true,
		["cp_hardwood_final"] = true,
		["cp_junction_final"] = true, --30
		["cp_lavapit_final"] = true, 
		["cp_manor_event"] = true,
		["cp_mercenarypark"] = true,
		["cp_metalworks"] = true,
		["cp_mossrock"] = true,
		["cp_mountainlab"] = true,
		["cp_overgrown"] = true,
		["cp_powerhouse"] = true,
		["cp_process_final"] = true,
		["cp_reckoner"] = true, --40
		["cp_snakewater_final1"] = true,
		["cp_snowplow"] = true,
		["cp_spookeyridge"] = true,
		["cp_standin_final"] = true,
		["cp_steel"] = true,
		["cp_sulfur"] = true,
		["cp_sunshine"] = true,
		["cp_sunshine_event"] = true,
		["cp_vanguard"] = true,
		["cp_well"] = true, -- 50
		["cp_yukon_final"] = true,

		["ctf_2fort"] = true,
		["ctf_2fort_invasion"] = true,
		["ctf_applejack"] = true,
		["ctf_crasher"] = true,
		["ctf_doublecross"] = true,
		["ctf_doublecross_snowy"] = true,
		["ctf_foundry"] = true,
		["ctf_frosty"] = true,
		["ctf_gorge"] = true,
		["ctf_haarp"] = true, --10 
		["ctf_hellfire"] = true,
		["ctf_helltrain_event"] = true,
		["ctf_landfall"] = true,
		["ctf_pelican_peak"] = true,
		["ctf_penguin_peak"] = true,
		["ctf_sawmill"] = true,
		["ctf_snowfall_final"] = true,
		["ctf_thundermountain"] = true,
		["ctf_turbine"] = true,
		["ctf_turbine_winter"] = true, --20 
		["ctf_well"] = true,

		["koth_badlands"] = true,
		["koth_bagel_event"] = true,
		["koth_brazil"] = true,
		["koth_cachoeria"] = true,
		["koth_cascade"] = true,
		["koth_harvest_event"] = true,
		["koth_harvest_final"] = true,
		["koth_highpass"] = true,
		["koth_king"] = true,
		["koth_krampus"] = true, --10
		["koth_lakeside_event"] = true,
		["koth_lakeside_final"] = true,
		["koth_lazarus"] = true,
		["koth_los_muertos"] = true,
		["koth_maple_ridge_event"] = true,
		["koth_megalo"] = true,
		["koth_megaton"] = true,
		["koth_moonshine_event"] = true,
		["koth_nucleus"] = true,
		["koth_overcast_final"] = true, --20
		["koth_probed"] = true,
		["koth_rotunda"] = true,
		["koth_sawmill"] = true,
		["koth_sawmill_event"] = true,
		["koth_sharkbay"] = true,
		["koth_slasher"] = true,
		["koth_slaughter_event"] = true,
		["koth_slime"] = true,
		["koth_snowtower"] = true,
		["koth_suijin"] = true, --30
		["koth_synthetic_event"] = true,
		["koth_toxic"] = true,
		["koth_undergrove_event"] = true,
		["koth_viaduct"] = true,
		["koth_viaduct_event"] = true,

		["mvm_bigrock"] = true,
		["mvm_coaltown"] = true,
		["mvm_decoy"] = true,
		["mvm_ghost_town"] = true,
		["mvm_manhattan"] = true,
		["mvm_mannworks"] = true,
		["mvm_rottenburg"] = true,

		["pass_brickyard"] = true,
		["pass_district"] = true,
		["pass_timbertown"] = true,

		["pd_atom_smash"] = true,
		["pd_circus"] = true,
		["pd_cursed_cove_event"] = true,
		["pd_farmaggedon"] = true,
		["pd_galleria"] = true,
		["pd_mannsylvania"] = true,
		["pd_monster_bash"] = true,
		["pd_pit_of_death_event"] = true,
		["pd_selbyen"] = true,
		["pd_snowville_event"] = true, --10
		["pd_watergate"] = true,
		
		["pl_badwater"] = true,
		["pl_barnblitz"] = true,
		["pl_bloodwater"] = true,
		["pl_borneo"] = true,
		["pl_breadspace"] = true,
		["pl_cactuscanyon"] = true,
		["pl_camber"] = true,
		["pl_cashworks"] = true,
		["pl_chilly"] = true,
		["pl_coal_event"] = true, --10
		["pl_corruption"] = true,
		["pl_embargo"] = true,
		["pl_emerge"] = true,
		["pl_enclosure_final"] = true,
		["pl_fifthcurve_event"] = true,
		["pl_frontier_final"] = true,
		["pl_frostcliff"] = true,
		["pl_goldrush"] = true,
		["pl_hasslecastle"] = true,
		["pl_hoodoo_final"] = true, --20
		["pl_millstone_event"] = true,
		["pl_odyssey"] = true,
		["pl_patagonia"] = true,
		["pl_phoenix"] = true,
		["pl_pier"] = true,
		["pl_precipice_event_final"] = true,
		["pl_rubmle_event"] = true,
		["pl_rumford_event"] = true,
		["pl_sludgepit_event"] = true,
		["pl_snowycoast"] = true, --30
		["pl_spineyard"] = true,
		["pl_swiftwater_final1"] = true,
		["pl_terror_event"] = true,
		["pl_thundermountain"] = true,
		["pl_upward"] = true,
		["pl_venice"] = true,
		["pl_wutville_event"] = true,
		
		["plr_barnabay"] = true,
		["plr_cutter"] = true,
		["plr_hacksaw"] = true,
		["plr_hacksaw_event"] = true,
		["plr_hightower"] = true,
		["plr_hightower_event"] = true,
		["plr_nightfall_final"] = true,
		["plr_pipeline"] = true,
		
		["rd_asteroid"] = true,
		
		["sd_doomsday"] = true,
		["sd_doomsday_event"] = true,
		
		["tc_hydro"] = true,

		["tow_dynamite"] = true,
		
		["tr_dustbowl"] = true,
		["tr_target"] = true,
		
		["vsh_distillery"] = true,
		["vsh_maul"] = true,
		["vsh_nucleus"] = true,
		["vsh_outburst"] = true,
		["vsh_skirmish"] = true,
		["vsh_tinyrock"] = true,
		
		["zi_atoll"] = true,
		["zi_blazehattan"] = true,
		["zi_devastation_final1"] = true,
		["zi_murky"] = true,
		["zi_sanitarium"] = true,
		["zi_woods"] = true,
}

--[[
	Detecting navmeshes / Nodegraphs is unfortunately highly unreliable.
	As a bandaid I've created a system for bypassing these checks, which can
	be set up manually, or automatically on loading a map.

	This seems to sometimes happen even with default maps sometimes, so I'm just including everything.
--]]
jcms.validMaps = {
	--Pre-made list to save people some trouble.
	--Vanilla
	["gm_construct"] = true,
	["jcms_jcorpdistrict"] = true,
	["jcms_mafiadistrict"] = true,
	["jcms_rggdistrict"] = true,
	
	--Recommended collection
	["gm_voidtown"] = true,
	["gm_citygateway"] = true,
	["gm_diprip_refinery"] = true,
	["gm_lair"] = true,
	["gm_born"] = true,				--This one has packed content which means it just outright doesn't show up at all.
	["gm_shattered_reality"] = true,
	["gm_hillfoot_construct"] = true,
	["gm_coast_bridge_prewar"] = true,
	["gm_lockdown"] = true,
	["gm_haven"] = true
}

jcms.mapWeights = { --Let people weight towards certain maps showing up in the end-of-mission vote.
	--Defaults
	["gm_construct"] = 1.5,
	["jcms_jcorpdistrict"] = 3,
	["jcms_mafiadistrict"] = 3,
	["jcms_rggdistrict"] = 3,
}

function jcms.setMapWeight(map, weight) 
	jcms.mapWeights[map] = weight
end

concommand.Add("jcms_setMapWeight", function(ply, cmd, args)
	if not(not ply:IsPlayer() or ply:IsAdmin()) then return end
	
	local map = tostring(args[1]) or ""
	jcms.setMapWeight(map, (tonumber(args[2]) or 1))
end, nil, "Set a weight-value to make a map show up more often in the end-of-round-vote")


function jcms.blacklistMap(map)
	jcms.mapBlacklist[map] = true
	jcms.validMaps[map] = false
end

concommand.Add("jcms_blacklistMap", function(ply, cmd, args)
	if not(not ply:IsPlayer() or ply:IsAdmin()) then return end
	
	local map = tostring(args[1]) or ""
	jcms.blacklistMap(map)
end, nil, "Manually blacklist an unplayable or broken map")


concommand.Add("jcms_addValidMap", function(ply, cmd, args)
	if not(not ply:IsPlayer() or ply:IsAdmin()) then return end
	
	local map = tostring(args[1]) or ""
	jcms.addValidMap(map)
end, nil, "Manually mark a map as compatible (for maps with packed navmeshes/nodegraphs).")

function jcms.addValidMap(map)
	jcms.validMaps[map] = true
	jcms.mapBlacklist[map] = false
end

function jcms.generateValidMapOptions()
	local validMaps = {}
	
	local maps = file.Find("maps/*.bsp", "GAME")
	table.Shuffle(maps)
	
	for i, map in ipairs(maps) do
		map = map:gsub("%.bsp", "")
		if
			not jcms.mapBlacklist[map] and
			(jcms.validMaps[map] or --Known as valid
			((map ~= game.GetMap()) --or detected as valid (unreliable)
			and file.Exists("maps/" .. map .. ".nav", "GAME")
			and file.Exists("maps/graphs/" .. map .. ".ain", "GAME")))
		then
			table.insert(validMaps, map)
		end
	end
	
	return validMaps
end


-- // Filesystem {{{
	file.CreateDir("mapsweepers")
	file.CreateDir("mapsweepers/server")

	do
		local validMapsFile = "mapsweepers/server/validMaps.json"
		hook.Add("InitPostEntity", "jcms_RestoreValidMaps", function()
			if file.Exists(validMapsFile, "DATA") then
				local dataTxt = file.Read(validMapsFile, "DATA")
				local dataTbl = util.JSONToTable(dataTxt)

				table.Merge(jcms.validMaps, dataTbl, true)
			end
		end)

		hook.Add("ShutDown", "jcms_SaveValidMaps", function()
			if not jcms.fullyLoaded then return end

			local dataStr = util.TableToJSON(jcms.validMaps)
			file.Write(validMapsFile, dataStr)
		end)
	end
-- // }}}