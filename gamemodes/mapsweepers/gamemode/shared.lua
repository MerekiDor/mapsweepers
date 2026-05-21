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
GM.Name = "Map Sweepers"
GM.Author = "Octantis Addons"

jcms = jcms or {}
jcms.inTutorial = game.GetMap() == "jcms_tutorial"
jcms.vectorOrigin = Vector(0, 0, 0)
jcms.vectorUp = Vector(0, 0, 1)
jcms.vectorOne = Vector(1, 1, 1)
jcms.vectorInvalid = Vector(math.huge, math.huge, math.huge)


local pmt = FindMetaTable("Player")
local emt = FindMetaTable("Entity")
local nmt = FindMetaTable("NPC")

-- Generic {{{

	hook.Add("PlayerSwitchWeapon", "jcms_WepSwitchFOVFix", function(ply, oldWep, newWep)
		timer.Simple(0.1, function() --*Yes, this has an actual purpose.* This might be an m9k issue but fov often gets fucked when switching. This resets it.
			if IsValid(ply) then
				ply:SetFOV(ply:GetFOV())
			end
		end)
	end)

	function jcms.printf(str, ...)
		local args = { ... }

		if #args > 0 then
			for i, arg in ipairs(args) do
				args[i] = tostring(arg)
			end

			print("[ Map Sweepers ] "..tostring(str):format( unpack(args) ))
		else
			print("[ Map Sweepers ] "..tostring(str))
		end
	end

	--Prevent lag spikes during-play when npcs spawn for the first time.
	jcms.precacheModels = {}
	hook.Add("InitPostEntity", "jcms_precache", function()
		for i, modelStr in ipairs(jcms.precacheModels) do
			util.PrecacheModel( modelStr )
		end
	end)

-- }}}

-- // Compatibility {{{
	pmt.CheckLimit = function() return true end --This function only exists in sandbox, but some addons assume it exists always.
-- // }}

-- Enums {{{

	jcms.LOCATOR_GENERIC = 0
	jcms.LOCATOR_SIGNAL = 1
	jcms.LOCATOR_WARNING = 2
	jcms.LOCATOR_TIMED = 3

	jcms.SPAWNCAT_TURRETS = 0
	jcms.SPAWNCAT_UTILITY = 1
	jcms.SPAWNCAT_MINES = 2
	jcms.SPAWNCAT_MOBILITY = 3
	jcms.SPAWNCAT_ORBITALS = 4
	jcms.SPAWNCAT_SUPPLIES = 5
	jcms.SPAWNCAT_MISSION = 6
	jcms.SPAWNCAT_DEFENSIVE = 7

	jcms.NOTIFY_DESTROYED = 1
	jcms.NOTIFY_OBTAINED = 2
	jcms.NOTIFY_LOCATED = 3
	jcms.NOTIFY_LOST = 4
	jcms.NOTIFY_MARKED = 5
	jcms.NOTIFY_BUILT = 6
	jcms.NOTIFY_ORDERED = 7

-- }}}

-- // ConVars {{{

	local FCVAR_JCMS_NOTIFY_AND_SAVE = bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY)
	local FCVAR_JCMS_SHARED_SAVED = bit.bor(FCVAR_REPLICATED, FCVAR_JCMS_NOTIFY_AND_SAVE) --TODO: More of these should probably be replicated, I've just done the obvious ones currently.
	jcms.cvar_ffmul = CreateConVar("jcms_friendlyfire_multiplier", "1", FCVAR_JCMS_SHARED_SAVED, "Friendly fire damage is multiplied by this number. 0 disables friendly fire. This applies to turrets and orbitals!", 0, 100)
	jcms.cvar_softcap = CreateConVar("jcms_npc_softcap", "50", FCVAR_JCMS_SHARED_SAVED, "The game will stop sending new swarms if there's more than X NPCs on the map. The actual sizes of the swarms stay the same, so there may be more NPCs than this number. It only prevents more NPCs from spawning through swarms, which is often good enough.", 1, 250)

	jcms.cvar_map_excludecurrent = CreateConVar("jcms_map_excludecurrent", "0", FCVAR_JCMS_SHARED_SAVED, "Excludes the current server map from the post-mission vote, ensuring that every mission is on a new map. Unless there's no other valid map.")
	jcms.cvar_map_iswhitelist = CreateConVar("jcms_map_iswhitelist", "0", FCVAR_JCMS_SHARED_SAVED, "Alters the behaviour of jcms_map_list. If this is 1, the list of maps will be a 'whitelist' (ONLY those maps will be picked). If this is 0, the list of maps will be a 'blacklist' (those maps will be EXCLUDED)")
	jcms.cvar_map_list = CreateConVar("jcms_map_list", "gm_flatgrass", FCVAR_JCMS_NOTIFY_AND_SAVE, "A comma-separated list of maps. This is either a whitelist or a blacklist, depending on the convar 'jcms_map_iswhitelist'")
	jcms.cvar_map_votecount = CreateConVar("jcms_map_votecount", "6", FCVAR_JCMS_NOTIFY_AND_SAVE, "How many maps will be offered as options in the post-mission vote, provided that the server has this many available. Capped at 15.")

	jcms.cvar_cash_start = CreateConVar("jcms_cash_start", "600", FCVAR_JCMS_NOTIFY_AND_SAVE, "The amount of cash a new sweeper spawns with.", 0, 10000)
	jcms.cvar_cash_evac = CreateConVar("jcms_cash_evac", "75", FCVAR_JCMS_NOTIFY_AND_SAVE, "This amount of cash is given to the sweeper a successful evacuation.", 0, 10000)
	jcms.cvar_cash_victory = CreateConVar("jcms_cash_victory", "75", FCVAR_JCMS_NOTIFY_AND_SAVE, "This much cash is given to players for each consecutive victory.", 0, 10000)
	jcms.cvar_cash_maxclerks = CreateConVar("jcms_cash_maxclerks", "5", FCVAR_JCMS_SHARED_SAVED, "The upper cap on how many clerks (NPCs) can be evacuated for +1 J each.", 0, 10000)

	jcms.cvar_cash_mul_final = CreateConVar("jcms_cash_mul_final", "1", FCVAR_JCMS_NOTIFY_AND_SAVE, "Global cash multiplier for kills, applied after every other bonus.", 0, 10)
	jcms.cvar_cash_mul_base = CreateConVar("jcms_cash_mul_base", "1", FCVAR_JCMS_NOTIFY_AND_SAVE, "NPC bounty cash multiplier before any other bonuses are given.", 0, 10)
	jcms.cvar_cash_mul_stunstick = CreateConVar("jcms_cash_mul_stunstick", "2", FCVAR_JCMS_NOTIFY_AND_SAVE, "Cash multiplier for stunstick kills.", 0, 10)
	jcms.cvar_cash_mul_very_far = CreateConVar("jcms_cash_mul_very_far", "1.25", FCVAR_JCMS_NOTIFY_AND_SAVE, "Cash multiplier for kills over great distances", 0, 10)

	jcms.cvar_cash_bonus_sidearm = CreateConVar("jcms_cash_bonus_sidearm", "10", FCVAR_JCMS_NOTIFY_AND_SAVE, "Extra credits given for pistol & revolver kills.", 0, 10000)
	jcms.cvar_cash_bonus_airborne = CreateConVar("jcms_cash_bonus_airborne", "25", FCVAR_JCMS_NOTIFY_AND_SAVE, "Extra credits given for killing NPCs that are midair.", 0, 10000)
	jcms.cvar_cash_bonus_headshot = CreateConVar("jcms_cash_bonus_headshot", "5", FCVAR_JCMS_NOTIFY_AND_SAVE, "Extra credits if a finishing shot was a headshot, but wasn't an instakill.", 0, 10000)
	jcms.cvar_cash_bonus_headshot_instakill = CreateConVar("jcms_cash_bonus_headshot_instakill", "20", FCVAR_JCMS_NOTIFY_AND_SAVE, "Extra credits for instakilling an NPC with a headshot.", 0, 10000)

	jcms.cvar_distance_headshot = CreateConVar("jcms_distance_headshot", "2000", FCVAR_JCMS_NOTIFY_AND_SAVE, "A minimum distance at which headshots start to give a cash bonus, to prevent easy up-close headshots.", 0, 100000)
	jcms.cvar_distance_headshot_extralengths = CreateConVar("jcms_distance_headshot_extralengths", "200", FCVAR_JCMS_NOTIFY_AND_SAVE, "For every X units (200 by default) starting from 'jcms_distance_headshot', one extra j-credit will be rewarded to the killer. By default, headshot distance is 2000 and 'extra' distance is 200, so, for example, at the distance of 2600 the reward will be: <base headshot bonus> + 3 for the extra 600 units.", 0, 100000)
	jcms.cvar_distance_very_far = CreateConVar("jcms_distance_very_far", "5000", FCVAR_JCMS_NOTIFY_AND_SAVE, "A distance that counts as an impressive sniping distance for a cash multiplier. Ideally, only players with long-range scopes should be able to get kills over this range.", 0, 100000)

	jcms.cvar_npcteam_restrict = CreateConVar("jcms_npcteam_restrict", "0", FCVAR_JCMS_SHARED_SAVED, "Restrictions on NPC Team. 0 = no restrictions, 1 = can only join as NPC post-evac, 2 = can never join as NPCs", 0, 2)
	jcms.cvar_suddendeathtimer = CreateConVar("jcms_suddendeathtimer", "0", FCVAR_JCMS_SHARED_SAVED, "(If set above 0) This is the number of seconds that must pass since the first sweeper evacuates, until J Corp stops giving credits for kills to remaining sweepers, encouraging evacuation. If set to 0, people can take their time with EVAC as long as they want with no penalties.", 0, 600)

	--Damage mul
	jcms.cvar_damage_mul = CreateConVar("jcms_damage_mul", "1", FCVAR_JCMS_NOTIFY_AND_SAVE, "Damage multiplier to Sweepers done by NPCs.", 0, 5)

	--Swarm
	jcms.cvar_swarm_frequency = CreateConVar("jcms_swarm_frequency", "1", FCVAR_JCMS_NOTIFY_AND_SAVE, "Swarm frequency multiplier.", 0, 5)
	jcms.cvar_swarm_size = CreateConVar("jcms_swarm_size", "1", FCVAR_JCMS_NOTIFY_AND_SAVE, "Swarm size multiplier.", 0, 5)
	jcms.cvar_swarm_warning = CreateConVar("jcms_swarm_warning", "1", FCVAR_JCMS_NOTIFY_AND_SAVE, "Extra seconds between a portal opening and enemies coming out of it.", 0, 30)
	
	--PVP
	jcms.cvar_pvpallowed = CreateConVar("jcms_pvpallowed", "1", FCVAR_JCMS_NOTIFY_AND_SAVE, "Dictates how PVP mode works. 0=Disable PVP; 1=Vote-based; 2=PVP Only")
	jcms.cvar_pvpminplayers = CreateConVar("jcms_pvpminplayers", "2", FCVAR_JCMS_NOTIFY_AND_SAVE, "Minimum players to be present on the server before PVP voting can begin")
	jcms.cvar_pvpvoteratio = CreateConVar("jcms_pvpvoteratio", "0.65", FCVAR_JCMS_NOTIFY_AND_SAVE, "Proportion of players needed for a pvp vote to pass, 0-1 (1 = everyone must vote yes, 0.5 = 50% must vote yes)")
	jcms.cvar_pvpautobalance = CreateConVar("jcms_pvpautobalance", game.IsDedicated() and "1" or "0", FCVAR_JCMS_NOTIFY_AND_SAVE, "0=No autobalancing; 1=Restrict joining to the smallest team; 2=Randomize teams before the round")
	jcms.cvar_pvpdebug = CreateConVar("jcms_pvpdebug", "0", FCVAR_JCMS_NOTIFY_AND_SAVE, "Stops PVP mode from ending when only 1 team is present")
	jcms.cvar_pvprespawnmode = CreateConVar("jcms_pvprespawnmode", "0", FCVAR_JCMS_NOTIFY_AND_SAVE, "0=Team-wide, 1=Per-Player")
	jcms.cvar_pvptracers = CreateConVar("jcms_pvptracers", "1", FCVAR_JCMS_NOTIFY_AND_SAVE, "Whether players get given team-coloured tracers") --TODO: Rename to jcms_pvptracers and change default after testing



	jcms.cvar_performanceMode = CreateConVar("jcms_performancemode", "0", FCVAR_JCMS_NOTIFY_AND_SAVE, "Various more aggressive changes to improve performance")
	
	-- Replicated
	jcms.cvar_announcer_type = CreateConVar("jcms_announcer_type", "default", FCVAR_JCMS_SHARED_SAVED, "Selects the current announcer by name.")
	jcms.cvar_noepisodes = CreateConVar("jcms_noepisodes", "0", FCVAR_JCMS_SHARED_SAVED, "If set to 1, Half-Life 2: Episode One & Two content will never appear in-game. Useful if you don't want your poor friends to see errors.")

	if SERVER then
		cvars.AddChangeCallback("jcms_pvpallowed", function(cvar, oldValue, newValue)
			local isPVP = jcms.util_IsPVP()
			newValue = tonumber(newValue)
			if isPVP and newValue == 0 then
				jcms.pvp_SetEnabled(false)
			elseif not isPVP and newValue == 2 then
				jcms.pvp_SetEnabled(true)
			end
		end)
	end

-- // }}}

-- Material Overrides {{{
	hook.Add("InitPostEntity", "jcms_loaded", function()
		timer.Simple(0, function() --after all our initPostEnt logic has run too.
			jcms.fullyLoaded = true
		end)
	end)

	hook.Add("InitPostEntity", "jcms_matOverride", function()
		Material("models/humans/male/group03/citizen_sheet"):SetTexture("$basetexture", "models/jcms/rgg_male")
		Material("models/humans/female/group03/citizen_sheet"):SetTexture("$basetexture", "models/jcms/rgg_female")
		Material("models/antlion_grub/antlion_grub"):SetTexture("$basetexture", "models/jcms/antlion_bombgrub")
	end)

-- }}}

-- Gun Stats {{{

	jcms.default_weapons_datas = {
		--HL2
		weapon_stunstick = {
			Slot = 0,
			Spawnable = false,
			ClassName = "weapon_stunstick",
			PrintName = "#weapon_stunstick",
			WorldModel = "models/weapons/c_stunstick.mdl",
			Primary = { Ammo = false, Damage = 47, RPM = 60, ClipSize = -1, Cone = 0 }
		},

		weapon_physcannon = {
			Slot = 0,
			Spawnable = false,
			ClassName = "weapon_physcannon",
			PrintName = "#weapon_physcannon",
			WorldModel = "models/weapons/w_physics.mdl",
			Primary = { Ammo = false, Damage = 1, RPM = 1.5*60, ClipSize = -1, Cone = 0 }
		},

		weapon_pistol = {
			Slot = 1,
			Spawnable = true,
			ClassName = "weapon_pistol",
			PrintName = "#weapon_pistol",
			WorldModel = "models/weapons/w_pistol.mdl",
			Primary = { Ammo = "Pistol", Damage = 11, RPM = 550, ClipSize = 18, Cone = math.rad(0.8) }
		},

		weapon_smg1 = {
			Slot = 2,
			Spawnable = true,
			ClassName = "weapon_smg1",
			PrintName = "#weapon_smg1",
			WorldModel = "models/weapons/w_smg1.mdl",
			Primary = { Ammo = "SMG1", Damage = 9, RPM = 800, ClipSize = 45, Cone = math.rad(1.5) }
		},

		weapon_357 = {
			Slot = 1,
			Spawnable = true,
			ClassName = "weapon_357",
			PrintName = "#weapon_357",
			WorldModel = "models/weapons/w_357.mdl",
			Primary = { Ammo = "357", Damage = 93, RPM = 80, ClipSize = 6, Cone = 0 }
		},

		weapon_ar2 = {
			Slot = 2,
			Spawnable = true,
			ClassName = "weapon_ar2",
			PrintName = "#weapon_ar2",
			WorldModel = "models/weapons/w_irifle.mdl",
			Primary = { Ammo = "AR2", Damage = 18, RPM = 600, ClipSize = 30, Cone = math.rad(0.8) }
		},

		weapon_shotgun = {
			Slot = 3,
			Spawnable = true,
			ClassName = "weapon_shotgun",
			PrintName = "#weapon_shotgun",
			WorldModel = "models/weapons/w_shotgun.mdl",
			Primary = { Ammo = "Buckshot", Damage = 23, RPM = 80, ClipSize = 6, Cone = math.rad(2.5), NumShots = 7 }
		},

		weapon_rpg = {
			Slot = 4,
			Spawnable = true,
			ClassName = "weapon_rpg",
			PrintName = "#weapon_rpg",
			WorldModel = "models/weapons/w_rocket_launcher.mdl",
			Primary = { Ammo = "RPG_Round", Damage = 265, RPM = 34, ClipSize = 1, Cone = 0 }
		},

		weapon_frag = {
			Slot = 4,
			Spawnable = true,
			ClassName = "weapon_frag",
			PrintName = "#weapon_frag",
			WorldModel = "models/weapons/w_grenade.mdl",
			Primary = { Ammo = "Grenade", Damage = 125, RPM = 30, ClipSize = 1, Cone = 0 }
		},

		weapon_crossbow = {
			Slot = 3,
			Spawnable = true,
			ClassName = "weapon_crossbow",
			PrintName = "#weapon_crossbow",
			WorldModel = "models/weapons/w_crossbow.mdl",
			Primary = { Ammo = "XBowBolt", Damage = 187, RPM = 31, ClipSize = 1, Cone = 0 }
		}

		--HL1 Weapons
		--TODO:
	}

	jcms.weapon_HL2Prices = {	--Calculated by agonisingly going through and recording their stats, then putting them through the cost calc.
		weapon_pistol = 475,
		weapon_smg1 = 840,
		weapon_357 = 1320,
		weapon_ar2 = 1230,
		weapon_shotgun = 980,
		weapon_rpg = 2400, 		--Designer value
		weapon_frag = 400, 		--Designer value
		weapon_crossbow = 870	--Cost calc + (1/3) reduction
	}


	jcms.weapon_HL1Prices = {
		--Halflife source yay!!!!
	}

	jcms.weapon_ammoCosts = {
		_DEFAULT = 5.4,

		-- Default
		["ar2"] = 3,
		["ar2altfire"] = 64,
		["pistol"] = 1,
		["smg1"] = 2,
		["357"] = 6,
		["xbowbolt"] = 8,
		["buckshot"] = 6,
		["rpg_round"] = 70,
		["smg1_grenade"] = 65,
		["grenade"] = 47,
		["slam"] = 55,
		["alyxgun"] = 1.6,
		["sniperround"] = 15,
		["sniperpenetratedround"] = 18,
		["thumper"] = 15,
		["gravity"] = 12,
		["battery"] = 8,
		["gaussenergy"] = 13,
		["combinecannon"] = 26,
		["airboatgun"] = 18,
		["striderminigun"] = 7.3,
		["helicoptergun"] = 6.6,
		["9mmround"] = 1.2,
		["357round"] = 7.2,
		["buckshothl1"] = 4.2,
		["xbowbolthl1"] = 20,
		["mp5_grenade"] = 55,
		["rpg_rocket"] = 69,
		["uranium"] = 14,
		["grenadehl1"] = 48,
		["hornet"] = 3.5,
		["snark"] = 10,
		["tripmine"] = 54,
		["satchel"] = 50,
		["12mmround"] = 8.5,
		["striderminigundirect"] = 7.1,
		["combineheavycannon"] = 24,

		-- M9K
		["40mmgrenade"] = 65,
		["improvised_explosive"] = 47,
		["harpoon"] = 27,
		["nitrog"] = 40,
		["nervegas"] = 145, -- That stuff's ridiculously powerful
		["stickygrenade"] = 41,
		["satcannon"] = 185,
		["c4explosive"] = 33,
		["nuclear_warhead"] = 975,
		["proxmine"] = 45.65,

		["m202_rocket"] = 80,
		["matador_rocket"] = 80,
		["rpg_rocket"] = 80,

		-- Hunt Down The Freeman Weapon Pack
		["hdtf_ammo_9mm"] = 1.2,
		["hdtf_ammo_buckshot"] = 6.3,
		["hdtf_ammo_7.62mm"] = 3.6,
		["hdtf_ammo_7.92mm"] = 15.5,
		["hdtf_ammo_5.56mm"] = 2.6,
		["hdtf_ammo_pulse"] = 2.9,
		["hdtf_ammo_claymore"] = 56,
		["hdtf_ammo_molotov"] = 38,
		["hdtf_ammo_.44cal"] = 13.5,
		["hdtf_ammo_flare"] = 3.45,
		["hdtf_ammo_m67"] = 32,
		["hdtf_ammo_pills"] = 285,
		["hdtf_ammo_grenade"] = 48,
		["hdtf_ammo_.45cal"] = 1.65,

		-- HL2 Beta Weapon Pack
		-- (no idea why most of these were necessary, but I guess that's how it was in beta?)
		["bp_small"] = 1.75,
		["bp_medium"] = 2.75,
		["bp_large"] = 3.58,
		["bp_flare"] = 3.25,
		["bp_rocket"] = 70,
		["bp_hopwire"] = 50,
		["bp_molotov"] = 38,
		["bp_guard"] = 85,
		["bp_sniper"] = 19.25,
		["bp_flame"] = 3.3,
		["bp_immolator"] = 0.95,
		["bp_brickbat"] = 1.5,

		-- Serious Sam 1 & 2 Weapon Packs
		["cannonball"] = 79,
		["klodovik"] = 78,
		["napalm"] = 2.31,
		["seriousbomb"] = 1000,

		-- Chuck's Weaponry 2.0
		-- (I fucking hate this)
		["5.56x45mm"] = 3.8,
		["7.62x54mmr"] = 18.1,
		["7.62x39mm"] = 4.5,
		["7.62x51mm"] = 3.6,
		["5.45x39mm"] = 3.7,
		[".338 lapua"] = 20.8,
		[".44 magnum"] = 12.5,
		["9x19mm"] = 2.3,
		[".50 ae"] = 14,
		["smoke grenades"] = 25,
		["frag grenades"] = 49, -- why???
		["flash grenades"] = 30
	}

	jcms.weapon_ammoExplosive = {
		--Vanilla
		["smg1_grenade"] = true,
		["rpg_round"] = true,
		["grenade"] = true,
		["slam"] = true,

		--M9K
		["40mmgrenade"] = true,
		["improvised_explosive"] = true,
		["nitrog"] = true,
		["nervegas"] = true,
		["stickygrenade"] = true,
		["satcannon"] = true,
		["c4explosive"] = true,
		["nuclear_warhead"] = true,
		["proxmine"] = true,
		
		["m202_rocket"] = true,
		["matador_rocket"] = true,
		["rpg_rocket"] = true,

		--HDTF
		["hdtf_ammo_claymore"] = true,
		["hdtf_ammo_molotov"] = true,
		["hdtf_ammo_grenade"] = true,

		-- Serious Sam 1 & 2 Weapon Packs
		["cannonball"] = true,
		["klodovik"] = true,
		["napalm"] = true,
		["seriousbomb"] = true,

		-- Chuck's Weaponry 2.0
		["frag grenades"] = true,
	}

	jcms.weapon_statsCache = jcms.weapon_statsCache or {}

	function jcms.gunstats_GetExpensive(class)
		local gunData = weapons.Get(class) or jcms.default_weapons_datas[class]
		if not gunData then return end
		if not gunData.Primary then
			ErrorNoHalt("Weapon set up incorrectly: '" .. class .. "' from the base '" .. tostring(gunData.Base) .. "' go bother the weapon's dev to fix it")
			return
		end

		local stats = {}
			stats.name = tostring(gunData.PrintName or class)
			stats.baseclass = tostring(gunData.Base) or "weapon_base"
			stats.category = tostring(gunData.Category or "_")
			stats.costOverride = gunData.JCMS_COSTOVERRIDE
			local radAccuracy = true

			if (gunData.SciFiWorldStats) then
				if class == "sfw_custom" then return end
				-- Darken217's SciFi Weapons
				stats.base = "Darken217's SciFi Weapons"

				local ammotype = game.GetAmmoName( game.GetAmmoID(tostring(gunData.Primary.Ammo) or "") or tonumber(gunData.Primary.Ammo)  ) or "none"
				stats.ammotype_lkey = ammotype .. "_ammo"
				stats.ammotype = ammotype:lower()

				stats.clipsize = gunData.SciFiWorldStats.ClipSize or gunData.Primary.ClipSize or 0
				if gunData.SciFiWorldStats.Primary.DamageComposition then
					local comp = gunData.SciFiWorldStats.Primary.DamageComposition
					local _,pellets = tostring(comp):match("%d+ +%* +(%d+)")
					stats.numshots = tonumber(pellets) or 1
				else
					stats.numshots = 1
				end

				stats.damage = gunData.SciFiWorldStats.Primary.DamageAmount or 0
				if not gunData.SciFiWorldStats.Primary.FireRate then
					stats.firerate = 0.25
				else
					stats.firerate = tonumber(gunData.SciFiWorldStats.Primary.FireRate[1].RateDelay) or 0.25
				end
				stats.automatic = gunData.Primary.Automatic
				stats.accuracy = gunData.SciFiACC or 0
				radAccuracy = false
			elseif gunData.Primary.RPM and (gunData.Primary.Recoil or gunData.RecoilAmount) and (gunData.Primary.Spread or gunData.Primary.SpreadHip) then
				-- M9K or TFA
				stats.base = gunData.IsTFAWeapon and "TFA" or "M9K"

				local ammotype = game.GetAmmoName( game.GetAmmoID(tostring(gunData.Primary.Ammo) or "") or tonumber(gunData.Primary.Ammo)  ) or "none"
				stats.ammotype_lkey = ammotype .. "_ammo"
				stats.ammotype = ammotype:lower()

				stats.clipsize = gunData.Primary.ClipSize or 0
				stats.numshots = gunData.Primary.NumShots or 1

				stats.damage = gunData.Primary.Damage or 0
				stats.firerate = 60 / (tonumber(gunData.Primary.RPM) or 1)
				stats.automatic = gunData.Primary.Automatic
				stats.accuracy = gunData.Primary.Spread or gunData.Primary.SpreadHip or 0
				radAccuracy = true
			elseif gunData.ArcCW then
				-- ArcCW
				stats.base = "ArcCW"

				local ammotype = game.GetAmmoName( game.GetAmmoID(tostring(gunData.Primary.Ammo) or "") or tonumber(gunData.Primary.Ammo)  ) or "none"
				stats.ammotype_lkey = ammotype .. "_ammo"
				stats.ammotype = ammotype:lower()

				stats.clipsize = gunData.Primary.ClipSize or 0
				stats.numshots = gunData.Num or 1

				stats.damage = math.Round( (gunData.Damage or 0) / stats.numshots, 1 )
				stats.firerate = gunData.Delay or 0
				stats.automatic = gunData.Primary.Automatic
				stats.accuracy = (gunData.AccuracyMOA or 0)/60
				radAccuracy = false
			elseif gunData.CW20Weapon then
				-- Chuck's Weaponry 2.0
				stats.base = "CW2.0"

				local ammotype = game.GetAmmoName( game.GetAmmoID(tostring(gunData.Primary.Ammo) or "") or tonumber(gunData.Primary.Ammo)  ) or "none"
				stats.ammotype_lkey = ammotype .. "_ammo"
				stats.ammotype = ammotype:lower()

				stats.clipsize = gunData.Primary.ClipSize or 0
				stats.numshots = gunData.Shots or 1

				stats.damage = gunData.Damage or 0
				stats.firerate = gunData.FireDelay or 0
				stats.automatic = gunData.Primary.Automatic
				stats.accuracy = (gunData.AimSpread or 0) + (gunData.SpreadPerShot or 0)
				radAccuracy = true
			elseif stats.baseclass:sub(1, 5) == "fas2_" then
				-- FA:S 2.0 Alpha SWEPs
				stats.base = "FA:S 2.0 Alpha SWEPs"

				local ammotype = game.GetAmmoName( game.GetAmmoID(tostring(gunData.Primary.Ammo) or "") or tonumber(gunData.Primary.Ammo)  ) or "none"
				stats.ammotype_lkey = ammotype .. "_ammo"
				stats.ammotype = ammotype:lower()

				stats.clipsize = gunData.Primary.ClipSize or 0
				stats.numshots = gunData.Shots or 1

				stats.damage = gunData.Damage or 0
				stats.firerate = gunData.FireDelay or 0
				stats.automatic = gunData.Primary.Automatic
				stats.accuracy = gunData.HipCone or 0
				radAccuracy = true
			elseif gunData.ARC9 then
				-- Arc9
				stats.base = "ARC9"

				local ammotype = game.GetAmmoName( game.GetAmmoID(tostring(gunData.Ammo) or "") or tonumber(gunData.Ammo)  ) or "none"
				stats.ammotype_lkey = ammotype .. "_ammo"
				stats.ammotype = ammotype:lower()

				stats.clipsize = gunData.ClipSize
				stats.numshots = gunData.Num or 1

				stats.damage = gunData.DistributeDamage and math.Round( gunData.DamageMax / stats.numshots, 1 ) or gunData.DamageMax
				stats.firerate = 60/gunData.RPM

				stats.accuracy = (tonumber(gunData.Spread) or 0) + (tonumber(gunData.SpreadAddHipFire) or 0)
			elseif gunData.ArcticTacRP then
				stats.base = "Tactical RP"

				local ammotype = game.GetAmmoName( game.GetAmmoID(tostring(gunData.Ammo) or "") or tonumber(gunData.Ammo)  ) or "none"
				stats.ammotype_lkey = ammotype .. "_ammo"
				stats.ammotype = ammotype:lower()

				stats.clipsize = gunData.ClipSize
				stats.numshots = gunData.Num or 1

				stats.damage = gunData.Damage_Max
				stats.firerate = 60/gunData.RPM

				stats.accuracy = (tonumber(gunData.Spread) or 0)
			elseif gunData.Base == "mg_base" then --MW Base --TODO: See if there's a better way to detect this base.
				stats.base = "MW Base"

				local ammotype = game.GetAmmoName( game.GetAmmoID(tostring(gunData.Primary.Ammo) or "") or tonumber(gunData.Primary.Ammo)  ) or "none"
				stats.ammotype_lkey = ammotype .. "_ammo"
				stats.ammotype = ammotype:lower()

				stats.clipsize = gunData.Primary.ClipSize or 0

				stats.numshots = gunData.Bullet.NumBullets or 1

				stats.damage = gunData.Bullet.Damage[1] / stats.numshots
				stats.firerate = 60/gunData.Primary.RPM

				stats.accuracy = (gunData.Cone.Hip) or 0 --Not 100% sure I've done this correctly - j
				radAccuracy = false
			elseif string.StartsWith(gunData.Base or "", "draconic_") then --Draconic Base -- TODO: See if there's a better way to detect this base
				stats.base = "Draconic"

				local ammotype = game.GetAmmoName( game.GetAmmoID(tostring(gunData.Primary.Ammo) or "") or tonumber(gunData.Primary.Ammo)  ) or "none"
				stats.ammotype_lkey = ammotype .. "_ammo"
				stats.ammotype = ammotype:lower()

				stats.clipsize = gunData.Primary.ClipSize or 0
				stats.numshots = gunData.Primary.NumShots or 1

				stats.damage = gunData.Primary.Damage
				stats.firerate = 60/(gunData.Primary.RPM or 60)

				stats.accuracy = (gunData.Primary.Spread or 1) / (gunData.Primary.SpreadDiv or 1)

				stats.automatic = gunData.Primary.Automatic
			else
				-- Fallback
				stats.base = "Default"

				local ammotype = game.GetAmmoName( game.GetAmmoID(tostring(gunData.Primary.Ammo) or "") or tonumber(gunData.Primary.Ammo)  ) or "none"
				stats.ammotype_lkey = ammotype .. "_ammo"
				stats.ammotype = ammotype:lower()

				stats.clipsize = gunData.Primary.ClipSize or 0
				stats.numshots = gunData.Primary.NumShots or gunData.Primary.NumBullets or gunData.Primary.NumberofShots or 1

				stats.damage = gunData.Primary.Damage
				if not stats.damage then
					if gunData.Primary.MinDamage and gunData.Primary.MaxDamage then
						stats.damage = (gunData.Primary.MinDamage + gunData.Primary.MaxDamage)/2
					else
						local ammoId = game.GetAmmoID(stats.ammotype)
						if ammoId >= 0 then
							stats.damage = game.GetAmmoPlayerDamage(ammoId)
						else
							stats.damage = 2
						end
					end
				end

				stats.automatic = gunData.Primary.Automatic
				if gunData.Primary.CurrentSpread then
					stats.accuracy = gunData.Primary.CurrentSpread
					radAccuracy = false
				else
					stats.accuracy = gunData.Primary.Cone or gunData.Primary.Spread or (gunData.Primary.Recoil or 0)/85
					if gunData.Primary.MaxSpread and gunData.Primary.MinSpread then
						stats.accuracy = (gunData.Primary.MinSpread + gunData.Primary.MaxSpread)/2
					end
					radAccuracy = true
				end

				if type(gunData.Tick) == "number" and gunData.Primary.Delay then
					-- DOOM 2 guns use this. Thanks traeesen for helping me figure it out
					stats.firerate = gunData.Primary.Delay * gunData.Tick
				else
					stats.firerate = gunData.Primary.Delay or gunData.Delay or gunData.FireDelay or 1
					if gunData.Primary.RPM then
						stats.firerate = 60 / gunData.Primary.RPM
					end
				end
			end

			if stats.ammotype == "" or
				stats.ammotype == "none" or
				stats.ammotype == false or
				stats.ammotype == "false" then
				stats.ammotype = "none"
			end

			if stats.clipsize < 0 then
				stats.clipsize = tonumber(gunData.Primary.DefaultClip) or 0
			end
			stats.clipsize = math.min(stats.clipsize, 9999) --Infinite clip sizes cause issues.

			if SERVER and gunData.ViewModel and gunData.ViewModel ~= "" then
				--Note: This function gets called in render hooks, so we either need to cache this or only have the data serverside.
				local dur = jcms.gunstats_GetReloadTime( gunData.ViewModel )
				stats.reloadtime = dur
			else
				stats.reloadtime = 0
			end

			stats.accuracy = stats.accuracy or 0
			stats.accuracy = (isvector(stats.accuracy) and 0) or stats.accuracy
			if radAccuracy then
				stats.accuracy = math.Round(math.deg(stats.accuracy), 2)
			end

			stats.firerate_rps = 1 / stats.firerate
			stats.range = (20 + stats.numshots*1.2) / math.tan( math.rad(stats.accuracy) )

			if stats.firerate == 0 then
				stats.dps = stats.damage * stats.numshots
			else
				if stats.clipsize > 0 then
					stats.dps = stats.damage * stats.numshots / math.max(stats.firerate, 1/stats.clipsize)
				else
					stats.dps = stats.damage * stats.numshots / stats.firerate
				end
			end

			stats.slot = gunData.Slot or 5
			stats.icon = gunData.IconOverride

		if not jcms.weapon_statsCache[class] then
			jcms.weapon_statsCache[class] = stats
		end
		
		return stats
	end

	function jcms.gunstats_Get(class)
		local cached = jcms.weapon_statsCache[ class ]

		if cached == nil then
			s, rtn = pcall(jcms.gunstats_GetExpensive, class)

			if s and type(rtn) == "table" then
				cached = rtn
			else
				cached = false
			end

			jcms.weapon_statsCache[ class ] = cached
		end
		
		if cached then 
			return cached -- so that we return 'nil' instead of 'false'
		end
	end

	if CLIENT then
		function jcms.gunstats_GetMat(class)
			if not jcms.gunMats[ class ] then
				local wepstats = jcms.gunstats_Get(class)

				jcms.gunMats[class] = Material(wepstats and wepstats.icon or "vgui/entities/"..class..".png")
				if jcms.gunMats[class]:IsError() then
					jcms.gunMats[class]  = Material("entities/"..class..".png")
				end
			end

			return jcms.gunMats[ class ]
		end
	end

	function jcms.gunstats_GetReloadTime( viewModelName )
		local viewModelEnt = ents.Create("prop_physics")
		viewModelEnt:SetModel(viewModelName)

		local seqId = viewModelEnt:SelectWeightedSequenceSeeded( ACT_VM_RELOAD, 0 ) --If anyone's given their weapons randomised reload speeds they're bastards. - J
		if seqId < 0 then
			for i, sqname in ipairs(viewModelEnt:GetSequenceList()) do
				if sqname:lower():find("reload") == 1 then
					seqId = i
					break
				end
			end
		end

		local dur = viewModelEnt:SequenceDuration(seqId)
		viewModelEnt:Remove()
		return dur
	end

	function jcms.gunstats_CountGivenAmmoFromLoadoutCount(stats, count) -- How much ammo is given for a weapon bought X times.
		if stats.clipsize == 1 then
			return (count + 2) * stats.clipsize
		else
			return (count + 1) * stats.clipsize
		end
	end

	function jcms.gunstats_ExtraAmmoCostData(stats, extra_count) -- Add this cost to base cost
		return math.ceil( math.max(1, stats.clipsize) * (jcms.weapon_ammoCosts[stats.ammotype] or jcms.weapon_ammoCosts._DEFAULT) * (extra_count or 0) )
	end

	function jcms.gunstats_CountMaximumAffordableCount(stats, cash)
		return math.floor( cash / ( (jcms.weapon_ammoCosts[stats.ammotype] or jcms.weapon_ammoCosts._DEFAULT) * math.max(1, stats.clipsize) ) )
	end

	function jcms.gunstats_CalcWeaponPrice(stats, noDivider)
		if type(stats) ~= "table" then return 0 end

		if stats.costOverride then 
			return stats.costOverride
		end

		-- // Calculate our average time between shots, accounting for reload. {{{
			local fullCycle = (stats.firerate * math.max(stats.clipsize, 1)) + stats.reloadtime
			local avgFireRate = fullCycle / math.max(stats.clipsize, 1)
			avgFireRate = 1 / avgFireRate

			if math.max(stats.clipsize, 1) == 1 then --If we only have 1 shot, only one of these values matters.
				avgFireRate = math.min(1/stats.reloadtime, stats.firerate_rps)
			end
		-- // }}}

		--Fallback to 100 if we have no damage stat. Avoids anything *too* broken becoming cheap.
		local dmgShot = (stats.damage == 0 and 100) or stats.damage
		local damagePer = dmgShot * math.max(stats.numshots, 1) --damage per shot / ammo spent
		local ammoCost = jcms.weapon_ammoCosts[stats.ammotype] or jcms.weapon_ammoCosts._DEFAULT

		damagePer = math.max(damagePer, ammoCost) --Not ideal. Used to keep things with projectile weapons in-check. Vaguely.

		local ammoEfficiency = math.max(damagePer / ammoCost, 1)
		local starterClipCost = math.max(stats.clipsize, 1) * ammoCost

		local accuracyFac = math.log(math.max(stats.accuracy, 1) + 2, 2) -- <1 deg inaccuracy ignored (has an exaggerated effect)

		-- // Damage per Second and Kills per Second {{{
			local dpsCost = (avgFireRate * damagePer) / accuracyFac
			local kps = math.min(avgFireRate, dpsCost/50) --Kills per second (approximation)

			if jcms.weapon_ammoExplosive[stats.ammotype] then --If we (probably) have splash damage, KPS should be high.
				dpsCost = dpsCost * accuracyFac --If we're AOE we probably don't care much about accuracy
				kps = dpsCost  --(Yes I know this is ridiculously large).
			end
			kps = math.min(kps, 200) --Beyond a certain point it doesn't really matter any more.
		-- // }}}

		--Stat weighting.
		local scaledDPSCost = ( kps + (dpsCost / 50) ) * 50/2
		local scaledEfficiencyCost = ammoEfficiency^(2/3)

		--Final cost.
		local cost = (scaledDPSCost * scaledEfficiencyCost + starterClipCost) * 2.75

		local divider = 5		-- Never noticed this, but I like it -J.
		if cost >= 2000 then
			divider = 100
		elseif cost >= 400 then
			divider = 50
		elseif cost  >= 150 then
			divider = 20
		elseif cost >= 20 then
			divider = 10
		end

		if noDivider then
			return math.ceil(cost)
		else
			return math.ceil(cost/divider)*divider - 1
		end
	end

-- }}}

-- Teams {{{

	team.SetUp(1, "J Corp", Color(255, 0, 0), false)
	team.SetUp(2, "NPCs", Color(255, 255, 255), false)

	jcms.team_jCorpClasses = jcms.team_jCorpClasses or {
		["jcms_turret"] = true,
		["jcms_turret_smrls"] = true,
		["jcms_landmine"] = true,
		["jcms_sapper"] = true
	}

	jcms.team_invalidNPCs = jcms.team_invalidNPCs or {
		["bullseye_strider_focus"] = true,
		["npc_bullseye"] = true
	}

	jcms.validTargetEnts = jcms.validTargetEnts or { --Extra entities we can shoot.
		["jcms_micromissile"] = true
	}

	jcms.team_flyingEntityClasses = jcms.team_flyingEntityClasses or {
		["npc_strider"] = true,
		["npc_combinegunship"] = true,
		["npc_helicopter"] = true,
		["npc_combinedropship"] = true
	}

	--I am sane and can be trusted to code glua - j
	local emt = FindMetaTable("Entity")
	local pmt = FindMetaTable("Player")
	local nmt = FindMetaTable("NPC")
	local nbmt = FindMetaTable("NextBot")

	-- // {{{ team_JCorp & variants
		function jcms.team_JCorp(ent) --*Still* expensive.
			return IsValid(ent) and ( (getmetatable(ent) == pmt and pmt.Team(ent) == 1) or (ent:GetTable().GetHackedByRebels and not ent:GetTable().GetHackedByRebels(ent)) or not not jcms.team_jCorpClasses[emt.GetClass(ent)] )
		end

		function jcms.team_JCorp_player(ply) --If we already know it's a player
			return IsValid(ply) and pmt.Team(ply) == 1
		end

		function jcms.team_JCorp_ent(ent) --If we already know it isn't a player. (And is valid)
			local entTbl = ent:GetTable()
			return (entTbl.GetHackedByRebels and not entTbl.GetHackedByRebels(ent)) or not not jcms.team_jCorpClasses[emt.GetClass(ent)]
		end
	-- // }}}

	function jcms.team_NPC(ent)
		if IsValid(ent) then
			local mt = getmetatable(ent)
			local entTbl = ent:GetTable()

			return (mt == pmt and ent:Team() == 2) or (entTbl.GetHackedByRebels and entTbl.GetHackedByRebels(ent)) or (( mt == nmt or mt == nbmt ) and not jcms.team_jCorpClasses[ emt.GetClass(ent) ])
			--[[
			if mt == pmt then --player
				return ent:Team() == 2
			elseif ent.GetHackedByRebels then
				return ent:GetHackedByRebels()
			else
				return ( mt == nmt or mt == nbmt ) and not jcms.team_jCorpClasses[ emt.GetClass(ent) ]
			end
			--]]
		end
	end

	function jcms.team_NPC_optimised(ent) --Getting rid of the IsValid check / assuming the target's valid.
		local mt = getmetatable(ent)
		local entTbl = ent:GetTable()

		return (mt == pmt and ent:Team() == 2) or (entTbl.GetHackedByRebels and entTbl.GetHackedByRebels(ent)) or (( mt == nmt or mt == nbmt ) and not jcms.team_jCorpClasses[ emt.GetClass(ent) ])
	end

	function jcms.team_GoodTarget(ent)
		if not IsValid(ent) then return false end

		local mt = getmetatable(ent) --moderately faster than an Is<Type> function call individually, and can be used repeatedly afterwards.

		local npcCheck = (mt == nmt and (not SERVER or nmt.GetNPCState(ent) ~= NPC_STATE_DEAD) and (emt.Health(ent)>0) and not jcms.team_invalidNPCs[emt.GetClass(ent)] and not emt.GetInternalVariable(ent,"startburrowed"))
		local playerCheck = mt == pmt and pmt.Alive(ent) and pmt.GetObserverMode(ent)==OBS_MODE_NONE
		local nextbotCheck = mt == nbmt and emt.Health(ent) > 0
		local entClassCheck = jcms.validTargetEnts[emt.GetClass(ent)] and emt.Health(ent) > 0

		return npcCheck or playerCheck or nextbotCheck or entClassCheck --NOTE: Could be optimised more by turning it into a single massive boolean expression, but idk if that's worth it.
	end

	function jcms.team_pvpSameTeam(e1, e2) --Shared pvp Team?
		local e1Pvp = e1:GetNWInt("jcms_pvpTeam", -1)
		local e2Pvp = e2:GetNWInt("jcms_pvpTeam", -1)
		return e1Pvp == -1 or e2Pvp == -1 or e1Pvp == e2Pvp --If either lacks pvp or both on same team
	end

	function jcms.team_pvpSameTeam_Strict(e1, e2) --Shared pvp team, team -1 is hostile (to self & others)
		local e1Pvp = e1:GetNWInt("jcms_pvpTeam", -1)
		local e2Pvp = e2:GetNWInt("jcms_pvpTeam", -1)
		return e1Pvp == e2Pvp and not (e1Pvp == -1 or e2Pvp == -1)
	end
	
	function jcms.team_pvpSameTeam_optimised(e1Pvp, e2Pvp)
		return e1Pvp == -1 or e2Pvp == -1 or e1Pvp == e2Pvp --If either lacks pvp or both on same team
	end

	function jcms.team_pvpSameTeam_Strict_optimised(e1Pvp, e2Pvp)
		return e1Pvp == e2Pvp and not (e1Pvp == -1 or e2Pvp == -1)
	end


	function jcms.team_SameTeam(e1, e2)
		if (e1 == e2) or ( jcms.team_JCorp(e1) and jcms.team_JCorp(e2) ) then
			return jcms.team_pvpSameTeam(e1, e2)
		else
			local bothNPCs = jcms.team_NPC(e1) and jcms.team_NPC(e2)

			if bothNPCs then
				local director = jcms.director
				if director and director.totalWar then
					return true
				else
					eTbl1 = e1:GetTable()
					eTbl2 = e2:GetTable()

					if eTbl1.jcms_faction and eTbl2.jcms_faction then
						return eTbl1.jcms_faction == eTbl2.jcms_faction
					else
						return bothNPCs
					end
				end
			else
				return jcms.team_pvpSameTeam_Strict(e1, e2) --Friendly if both have a pvp team and both are the same team, hostile otherwise.
			end
		end
	end

-- }}}

-- Other {{{

	function jcms.isPlayerEngineer(ply)
		return IsValid(ply) and (ply:GetNWString("jcms_class") == "engineer")
	end

	function jcms.GetAliveSweepers()
		local players = team.GetPlayers(1)
		for i=#players, 1, -1 do
			local ply = players[i]
			if not(IsValid(ply) and pmt.Alive(ply) and pmt.GetObserverMode(ply) == OBS_MODE_NONE) then
				table.remove(players, i)
			end
		end

		return players
	end

	function jcms.GetLobbySweepers() --used for mapgen, teams aren't set until after.
		local players = player.GetAll()
		for i=#players, 1, -1 do
			local ply = players[i]
			if not(ply:GetNWInt("jcms_desiredteam", -1) == 1) then
				table.remove(players, i)
			end
		end

		return players
	end

	function jcms.PVPGetTeamPlayers( pvpTeam )
		local plys = {}
		for i, ply in player.Iterator() do
			if jcms.team_pvpSameTeam_optimised(pvpTeam, ply:GetNWInt("jcms_pvpTeam", -1)) then
				table.insert(plys, ply) 
			end
		end
		return plys
	end

	function jcms.PVPGetTeamAlivePlayers( pvpTeam ) 
		local plys = jcms.GetAliveSweepers()
		
		for i=#plys, 1, -1 do 
			local ply = plys[i] 
			if not jcms.team_pvpSameTeam_optimised(pvpTeam, ply:GetNWInt("jcms_pvpTeam", -1)) then
				table.remove(plys, i)
			end
		end

		return plys
	end

	jcms.cvar_noepisodes = GetConVar("jcms_noepisodes")
	function jcms.HasEpisodes()
		return not jcms.cvar_noepisodes:GetBool()
	end
-- }}}

-- // PVP & Vote {{{

	jcms.pvp_vote = jcms.pvp_vote or {
		endsAt = 0,
		yes = {},
		no = {},
		any = {}
	}

	function jcms.pvp_vote_IsOngoing()
		return jcms.pvp_vote and CurTime() < jcms.pvp_vote.endsAt
	end

	function jcms.pvp_vote_InsertPlayerByOption(ply, option) --Merekidor Speechbubble
		local vote = jcms.pvp_vote

		local tables = {
			vote.yes,
			vote.no,
			vote.any
		}

		local oc1, oc2, oc3 = #tables[1], #tables[2], #tables[3]

		for i, tab in ipairs(tables) do
			local k = table.RemoveByValue(tab, ply)
		end

		local tab = tables[option + 1]
		
		if tab then
			table.insert(tab, ply)
		end

		local nc1, nc2, nc3 = #tables[1], #tables[2], #tables[3]

		return nc1 ~= oc1 or nc2 ~= oc2 or nc3 ~= oc3
	end

-- // }}}

-- Util {{{

	function jcms.util_ToMeters(len, format)
		local n = math.Round(len * 0.019048295452779)
		if format then
			return n .. " m"
		else
			return n
		end
	end

	function jcms.util_ToFeet(len, format)
		local n = math.Round(len / 16)
		if format then
			return n .. " ft"
		else
			return n
		end
	end

	function jcms.util_ReverseTable(t) -- Doesn't copy the table unlike table.Reverse
		local len = #t
		for i=1, math.floor(#t/2) do
			t[i], t[len-i+1] = t[len-i+1], t[i]
		end
	end

	function jcms.util_ToDistance(len, format)
		if CLIENT and jcms.cvar_imperial:GetBool() then
			return jcms.util_ToFeet(len, format)
		else
			return jcms.util_ToMeters(len, format)
		end
	end

	function jcms.util_ChooseByWeight(t) -- key is entry, value is weight (>0)
		local ks, vs = {}, {}

		local i, sum = 1, 0
		for k,v in pairs(t) do
			if v>0 then
				ks[i], vs[i] = k, v
				sum = sum + v
				i = i + 1
			end
		end

		local r = math.random()*sum
		for i=#ks,1,-1 do
			sum = sum - vs[i]
			if sum<r then
				return ks[i]
			end
		end
	end

	function jcms.util_GetShuffledByWeight(t) -- same as above - key is entry, value is weight (>0)
		local shuffled = {}
		local copy = table.Copy(t)

		while true do
			if not next(copy) then break end
			local entry = jcms.util_ChooseByWeight(copy)
			table.insert(shuffled, entry)
			copy[ entry ] = nil
		end

		return shuffled
	end

	function jcms.util_CashFormat(n)
		local i, j, minus, int, fraction = tostring(n):find('([-]?)(%d+)([.]?%d*)')
		int = int:reverse():gsub("(%d%d%d)", "%1,")
		return minus .. int:reverse():gsub("^,", "") .. fraction
	end

	function jcms.util_GetSky(from)
		local lastpos = from
		local up = Vector(0, 0, 32768)

		for i=1, 48 do
			local trace = util.TraceLine { start = lastpos + jcms.vectorUp, endpos = lastpos + up, mask = MASK_SOLID_BRUSHONLY }

			if trace.HitSky then
				return trace.HitPos, i == 1
			else
				lastpos = trace.HitPos
			end
		end
	end

	local temp_color = Color(0, 0, 0)
	function jcms.util_ColorLerp(f, color1, color2, optimized)
		if optimized then
			temp_color.r = Lerp(f, color1.r, color2.r)
			temp_color.g = Lerp(f, color1.g, color2.g)
			temp_color.b = Lerp(f, color1.b, color2.b)
			temp_color.a = Lerp(f, color1.a, color2.a)
			return temp_color
		else
			return Color(
				Lerp(f, color1.r, color2.r),
				Lerp(f, color1.g, color2.g),
				Lerp(f, color1.b, color2.b),
				Lerp(f, color1.a, color2.a)
			)
		end
	end

	function jcms.util_Percentage(n, total)
		n = tonumber(n) or 0
		total = tonumber(total) or 0

		if total == 0 or n == 0 then
			return "0%"
		else
			local percent = n / total * 100

			local precision = 0
			if math.abs(percent) < 10 then
				precision = 1
			end

			local precisionMul = 10 ^ precision
			return string.format("%."..math.ceil(precision).."f", math.Round(percent * precisionMul) / precisionMul) .. "%"
		end
	end

	jcms.util_compassDirs = {
		[0] = "E",
		[1] = "NE",
		[2] = "N",
		[3] = "NW",
		[4] = "W",
		[5] = "SW",
		[6] = "S",
		[7] = "SE"
	}

	function jcms.util_GetCompassDir(from, to, formatAsString)
		local int = math.floor((to - from):Angle().y / 45 + 0.5)%8

		if formatAsString then
			return jcms.util_compassDirs[int] or "?"
		else
			return int
		end
	end

	function jcms.util_PlaytimeFormat(seconds)
		local minutes = math.floor(seconds / 60)
		seconds = seconds - minutes*60

		local hours = math.floor(minutes / 60)
		minutes = minutes - hours * 60

		local days = math.floor(hours / 24)
		hours = hours - days * 24

		if days > 0 then
			return language.GetPhrase("jcms.stats_playtime_dhms"):format(days, hours, minutes, seconds)
		elseif hours > 0 then
			return language.GetPhrase("jcms.stats_playtime_hms"):format(hours, minutes, seconds)
		else
			return language.GetPhrase("jcms.stats_playtime_ms"):format(minutes, seconds)
		end
	end

	local function MSG_OVERRIDE(...)
		for i, arg in ipairs {...} do
			jcms.__tempstring = jcms.__tempstring .. tostring(arg)
		end
	end

	function jcms.util_Hash(tab)
		if istable(tab) then
			-- quite hacky, but i need a recursive table print function that also has alphabetical order for keys
			jcms.__tempstring = ""
			local MsgOriginal = Msg
			Msg = MSG_OVERRIDE
			PrintTable(tab)
			Msg = MsgOriginal
			local str = jcms.__tempstring
			jcms.__tempstring = nil
			return util.SHA256(str)
		else
			return util.SHA256(tostring(tab))
		end
	end

	function jcms.util_ColorIntegerFast(r,g,b)
		-- 24-bit color to 8 bit
		local red3 = math.floor(r/32)
		local green3 = math.floor(g/32)
		local blue2 = math.floor(b/64)
		return red3 + bit.lshift(green3, 3) + bit.lshift(blue2, 6)
	end

	function jcms.util_ColorInteger(col)
		return jcms.util_ColorIntegerFast(col.r, col.g, col.b)
	end

	function jcms.util_ColorFromInteger(int)
		-- 8 bit to 24 bit RGB.
		local b = bit.rshift(int, 6) % 4
		local g = bit.rshift(int, 3) % 8
		local r = int % 8
		return Color(r * (8/7) * 32, g * (8/7) * 32, b * (4/3) * 64)
	end

	function jcms.util_ColorFromIntegerUnpacked(int) --Optimisation, we don't always need the colour object.
		local b = bit.rshift(int, 6) % 4
		local g = bit.rshift(int, 3) % 8
		local r = int % 8
		return r * (8/7) * 32, g * (8/7) * 32, b * (4/3) * 64
	end

	function jcms.util_GetColorIntegerPvP(ent)
		if IsValid(ent) and ent:GetNWInt("jcms_pvpTeam", -1) == 2 then
			return jcms.util_colorIntegerMafia
		else
			return jcms.util_colorIntegerJCorp
		end
	end

	function jcms.pvp_IsGoodTeamId(teamId)
		return teamId == 1 or teamId == 2
	end

	function jcms.util_GetFactionNameFromTeamId(id)
		if id == 2 then
			return "mafia"
		else
			return "jcorp"
		end
	end

	function jcms.util_GetFactionNamePVP(ent)
		local id = IsValid(ent) and ent:GetNWInt("jcms_pvpTeam", -1) or 1
		return jcms.util_GetFactionNameFromTeamId(id)
	end

	function jcms.util_GetPVPVectorColor(ent)
		if IsValid(ent) and ent:GetNWInt("jcms_pvpTeam", -1) == 2 then
			return Vector(1, 0.8, 0)
		else
			return Vector(1, 0, 0)
		end
	end

	function jcms.util_GetPVPColorScoreboard(teamId, bright)
		if teamId == 2 then
			return Color(255, 233, 107, bright and 255 or 16)
		else
			return Color(255, 63, 63, bright and 255 or 16)
		end
	end

	function jcms.util_GetPVPColor(ent)
		if IsValid(ent) and ent:GetNWInt("jcms_pvpTeam", -1) == 2 then
			return Color(255, 217, 0)
		else
			return Color(255, 0, 0)
		end
	end

	function jcms.util_TryUpdateForPVP(ent)
		if IsValid(ent) and ent.UpdateForFaction then
			ent:UpdateForFaction( jcms.util_GetFactionNamePVP(ent) )
		end
	end

	jcms.util_colorIntegerJCorp = jcms.util_ColorInteger( Color(255, 0, 0) )
	jcms.util_colorIntegerMafia = jcms.util_ColorInteger( Color(255, 217, 0) )
	jcms.util_colorIntegerSweeperShield = jcms.util_ColorInteger( Color(32, 200, 255) )

	jcms.util_dmgTypesCompression = { DMG_ACID, DMG_FALL, DMG_DROWN, DMG_NERVEGAS, DMG_RADIATION, DMG_BURN, DMG_POISON }
	function jcms.util_dmgTypeCompress(dmgType)
		local compressed = 0
		for i, n in ipairs(jcms.util_dmgTypesCompression) do
			if bit.band(dmgType, n) > 0 then
				compressed = compressed + 2^(i-1)
			end
		end
		return compressed
	end

	function jcms.util_dmgTypeDecompress(compressedDmgType)
		local decompressed = 0
		for i, n in ipairs(jcms.util_dmgTypesCompression) do
			if bit.band(2^(i-1), compressedDmgType) > 0 then
				decompressed = decompressed + n
			end
		end
		return decompressed
	end

	function jcms.util_ChunkFunctions(size)
		local chunks = {}
		local chunksize = math.max(1, tonumber(size) or 0)

		local function getChunkId(x, y, z)
			return math.floor(x/chunksize) .. " " .. math.floor(y / chunksize) .. " " .. math.floor(z / chunksize)
		end

		local function getChunkTable(x, y, z)
			local id = getChunkId(x, y, z)

			if not chunks[id] then
				chunks[id] = {}
			end

			return chunks[id]
		end

		local function getAllNearbyNodes(x, y, z)
			local nodes = {}

			table.Add(nodes, getChunkTable(x, y, z))
			for ox=-1,1,2 do
				for oy=-1,1,2 do
					for oz=-1,1,2 do
						table.Add(nodes, getChunkTable(x+ox*chunksize*0.9, y+oy*chunksize/2, z+oz*chunksize/2))
					end
				end
			end

			return nodes
		end

		return chunks, chunksize, getChunkId, getChunkTable, getAllNearbyNodes
	end

	function jcms.util_IsStunstick(ent)
		return not not (IsValid(ent) and ent:IsWeapon() and ent:GetClass():lower():find("stun_?stick"))
	end

	function jcms.util_GetThresholdTimer() -- How many players need to be ready to start mission countdown
		return math.min(#player.GetHumans(), game.MaxPlayers()/2)
	end

	function jcms.util_GetThresholdAutostart() -- How many players need to be ready to instantly start the mission
		return math.max(#player.GetHumans(), game.MaxPlayers()/2)
	end

	function jcms.util_GetLobbyWeaponCostMultiplier()
		return game.GetWorld():GetNWFloat("jcms_lobbyWeaponSale", 0.25)
	end

	function jcms.util_GetMissionStartTime()
		return game.GetWorld():GetNWFloat("jcms_missionStartTime", 0)
	end

	function jcms.util_GetMissionTime()
		return CurTime() - game.GetWorld():GetNWFloat("jcms_missionStartTime", 0)
	end

	function jcms.util_GetTimeUntilStart()
		return math.max(0, game.GetWorld():GetNWFloat("jcms_missionStartTime", 0) - CurTime())
	end

	function jcms.util_GetMapGenProgress() -- -1: not generating, 0-1: generating
		return math.Clamp(game.GetWorld():GetNWFloat("jcms_mapgen_progress", -1), -1, 1)
	end

	function jcms.util_IsGameTimerGoing()
		local startTime = game.GetWorld():GetNWFloat("jcms_missionStartTime", 0)
		return startTime > 0.25 and startTime + 2 > CurTime()
	end

	function jcms.util_IsGameOngoing()
		return game.GetWorld():GetNWBool("jcms_ongoing", false)
	end

	function jcms.util_GetRespawnCount(teamId, ply)
		local count = game.GetWorld():GetNWInt("jcms_respawncount_" .. tostring(not(teamId==-1) and teamId or 1), 0)
		return count + (IsValid(ply) and ply:GetNWInt("jcms_playerRespawns", 0) or 0)
	end

	function jcms.util_GetMissionType()
		return game.GetWorld():GetNWString("jcms_missiontype", "hell")
	end

	function jcms.util_GetMissionFaction()
		return game.GetWorld():GetNWString("jcms_missionfaction", "antlion")
	end

	function jcms.util_GetCurrentWinstreak() --NOTE: Only the *displayed* winstreak is returned by this, not stored. I.e. currently it's always 0 in pvp
		return game.GetWorld():GetNWInt("jcms_winstreak", 0)
	end

	function jcms.util_GetCurrentDifficulty() --NOTE: Ditto
		return game.GetWorld():GetNWFloat("jcms_difficulty", 0)
	end

	function jcms.util_IsPVP()
		return game.GetWorld():GetNWBool("jcms_pvpmode", false)
	end

	function jcms.util_IsPVPAllowed()
		return (jcms.cvar_pvpallowed:GetInt() ~= 0) and (player.GetCount() >= jcms.cvar_pvpminplayers:GetInt())
	end

	function jcms.util_AddAngles(ang1, ang2) --TODO: Not super efficient as it creates 2 matrix objects.
		local mat = Matrix()
		mat:SetAngles(ang1)
		
		local mat2 = Matrix()
		mat2:SetAngles(ang2)

		mat:Mul(mat2)
		return mat:GetAngles()
	end

	function jcms.util_GetLargestPvpTeamCount()
		local teamCounts = {}

		for i, ply in player.Iterator() do
			local teamId = ply:GetNWInt("jcms_pvpTeam", -1)
			teamCounts[teamId] = (teamCounts[teamId] or 0) + 1
		end

		local largest = 0
		for teamId, count in pairs(teamCounts) do 
			largest = math.max(count, largest)
		end

		return largest
	end

	
	function jcms.util_GetLargestAlivePvpTeamCount()
		local teamCounts = {}

		for i, ply in ipairs(jcms.GetAliveSweepers()) do
			local teamId = ply:GetNWInt("jcms_pvpTeam", -1)
			teamCounts[teamId] = (teamCounts[teamId] or 0) + 1
		end

		local largest = 0
		for teamId, count in pairs(teamCounts) do 
			largest = math.max(count, largest)
		end

		return largest
	end
-- }}}

-- Licenses {{{

-- im in a rush bros...
jcms.gnugplv3_license = [[                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

                            Preamble

  The GNU General Public License is a free, copyleft license for
software and other kinds of works.

  The licenses for most software and other practical works are designed
to take away your freedom to share and change the works.  By contrast,
the GNU General Public License is intended to guarantee your freedom to
share and change all versions of a program--to make sure it remains free
software for all its users.  We, the Free Software Foundation, use the
GNU General Public License for most of our software; it applies also to
any other work released this way by its authors.  You can apply it to
your programs, too.

  When we speak of free software, we are referring to freedom, not
price.  Our General Public Licenses are designed to make sure that you
have the freedom to distribute copies of free software (and charge for
them if you wish), that you receive source code or can get it if you
want it, that you can change the software or use pieces of it in new
free programs, and that you know you can do these things.

  To protect your rights, we need to prevent others from denying you
these rights or asking you to surrender the rights.  Therefore, you have
certain responsibilities if you distribute copies of the software, or if
you modify it: responsibilities to respect the freedom of others.

  For example, if you distribute copies of such a program, whether
gratis or for a fee, you must pass on to the recipients the same
freedoms that you received.  You must make sure that they, too, receive
or can get the source code.  And you must show them these terms so they
know their rights.

  Developers that use the GNU GPL protect your rights with two steps:
(1) assert copyright on the software, and (2) offer you this License
giving you legal permission to copy, distribute and/or modify it.

  For the developers' and authors' protection, the GPL clearly explains
that there is no warranty for this free software.  For both users' and
authors' sake, the GPL requires that modified versions be marked as
changed, so that their problems will not be attributed erroneously to
authors of previous versions.

  Some devices are designed to deny users access to install or run
modified versions of the software inside them, although the manufacturer
can do so.  This is fundamentally incompatible with the aim of
protecting users' freedom to change the software.  The systematic
pattern of such abuse occurs in the area of products for individuals to
use, which is precisely where it is most unacceptable.  Therefore, we
have designed this version of the GPL to prohibit the practice for those
products.  If such problems arise substantially in other domains, we
stand ready to extend this provision to those domains in future versions
of the GPL, as needed to protect the freedom of users.

  Finally, every program is threatened constantly by software patents.
States should not allow patents to restrict development and use of
software on general-purpose computers, but in those that do, we wish to
avoid the special danger that patents applied to a free program could
make it effectively proprietary.  To prevent this, the GPL assures that
patents cannot be used to render the program non-free.

  The precise terms and conditions for copying, distribution and
modification follow.

                       TERMS AND CONDITIONS

  0. Definitions.

  "This License" refers to version 3 of the GNU General Public License.

  "Copyright" also means copyright-like laws that apply to other kinds of
works, such as semiconductor masks.

  "The Program" refers to any copyrightable work licensed under this
License.  Each licensee is addressed as "you".  "Licensees" and
"recipients" may be individuals or organizations.

  To "modify" a work means to copy from or adapt all or part of the work
in a fashion requiring copyright permission, other than the making of an
exact copy.  The resulting work is called a "modified version" of the
earlier work or a work "based on" the earlier work.

  A "covered work" means either the unmodified Program or a work based
on the Program.

  To "propagate" a work means to do anything with it that, without
permission, would make you directly or secondarily liable for
infringement under applicable copyright law, except executing it on a
computer or modifying a private copy.  Propagation includes copying,
distribution (with or without modification), making available to the
public, and in some countries other activities as well.

  To "convey" a work means any kind of propagation that enables other
parties to make or receive copies.  Mere interaction with a user through
a computer network, with no transfer of a copy, is not conveying.

  An interactive user interface displays "Appropriate Legal Notices"
to the extent that it includes a convenient and prominently visible
feature that (1) displays an appropriate copyright notice, and (2)
tells the user that there is no warranty for the work (except to the
extent that warranties are provided), that licensees may convey the
work under this License, and how to view a copy of this License.  If
the interface presents a list of user commands or options, such as a
menu, a prominent item in the list meets this criterion.

  1. Source Code.

  The "source code" for a work means the preferred form of the work
for making modifications to it.  "Object code" means any non-source
form of a work.

  A "Standard Interface" means an interface that either is an official
standard defined by a recognized standards body, or, in the case of
interfaces specified for a particular programming language, one that
is widely used among developers working in that language.

  The "System Libraries" of an executable work include anything, other
than the work as a whole, that (a) is included in the normal form of
packaging a Major Component, but which is not part of that Major
Component, and (b) serves only to enable use of the work with that
Major Component, or to implement a Standard Interface for which an
implementation is available to the public in source code form.  A
"Major Component", in this context, means a major essential component
(kernel, window system, and so on) of the specific operating system
(if any) on which the executable work runs, or a compiler used to
produce the work, or an object code interpreter used to run it.

  The "Corresponding Source" for a work in object code form means all
the source code needed to generate, install, and (for an executable
work) run the object code and to modify the work, including scripts to
control those activities.  However, it does not include the work's
System Libraries, or general-purpose tools or generally available free
programs which are used unmodified in performing those activities but
which are not part of the work.  For example, Corresponding Source
includes interface definition files associated with source files for
the work, and the source code for shared libraries and dynamically
linked subprograms that the work is specifically designed to require,
such as by intimate data communication or control flow between those
subprograms and other parts of the work.

  The Corresponding Source need not include anything that users
can regenerate automatically from other parts of the Corresponding
Source.

  The Corresponding Source for a work in source code form is that
same work.

  2. Basic Permissions.

  All rights granted under this License are granted for the term of
copyright on the Program, and are irrevocable provided the stated
conditions are met.  This License explicitly affirms your unlimited
permission to run the unmodified Program.  The output from running a
covered work is covered by this License only if the output, given its
content, constitutes a covered work.  This License acknowledges your
rights of fair use or other equivalent, as provided by copyright law.

  You may make, run and propagate covered works that you do not
convey, without conditions so long as your license otherwise remains
in force.  You may convey covered works to others for the sole purpose
of having them make modifications exclusively for you, or provide you
with facilities for running those works, provided that you comply with
the terms of this License in conveying all material for which you do
not control copyright.  Those thus making or running the covered works
for you must do so exclusively on your behalf, under your direction
and control, on terms that prohibit them from making any copies of
your copyrighted material outside their relationship with you.

  Conveying under any other circumstances is permitted solely under
the conditions stated below.  Sublicensing is not allowed; section 10
makes it unnecessary.

  3. Protecting Users' Legal Rights From Anti-Circumvention Law.

  No covered work shall be deemed part of an effective technological
measure under any applicable law fulfilling obligations under article
11 of the WIPO copyright treaty adopted on 20 December 1996, or
similar laws prohibiting or restricting circumvention of such
measures.

  When you convey a covered work, you waive any legal power to forbid
circumvention of technological measures to the extent such circumvention
is effected by exercising rights under this License with respect to
the covered work, and you disclaim any intention to limit operation or
modification of the work as a means of enforcing, against the work's
users, your or third parties' legal rights to forbid circumvention of
technological measures.

  4. Conveying Verbatim Copies.

  You may convey verbatim copies of the Program's source code as you
receive it, in any medium, provided that you conspicuously and
appropriately publish on each copy an appropriate copyright notice;
keep intact all notices stating that this License and any
non-permissive terms added in accord with section 7 apply to the code;
keep intact all notices of the absence of any warranty; and give all
recipients a copy of this License along with the Program.

  You may charge any price or no price for each copy that you convey,
and you may offer support or warranty protection for a fee.

  5. Conveying Modified Source Versions.

  You may convey a work based on the Program, or the modifications to
produce it from the Program, in the form of source code under the
terms of section 4, provided that you also meet all of these conditions:

    a) The work must carry prominent notices stating that you modified
    it, and giving a relevant date.

    b) The work must carry prominent notices stating that it is
    released under this License and any conditions added under section
    7.  This requirement modifies the requirement in section 4 to
    "keep intact all notices".

    c) You must license the entire work, as a whole, under this
    License to anyone who comes into possession of a copy.  This
    License will therefore apply, along with any applicable section 7
    additional terms, to the whole of the work, and all its parts,
    regardless of how they are packaged.  This License gives no
    permission to license the work in any other way, but it does not
    invalidate such permission if you have separately received it.

    d) If the work has interactive user interfaces, each must display
    Appropriate Legal Notices; however, if the Program has interactive
    interfaces that do not display Appropriate Legal Notices, your
    work need not make them do so.

  A compilation of a covered work with other separate and independent
works, which are not by their nature extensions of the covered work,
and which are not combined with it such as to form a larger program,
in or on a volume of a storage or distribution medium, is called an
"aggregate" if the compilation and its resulting copyright are not
used to limit the access or legal rights of the compilation's users
beyond what the individual works permit.  Inclusion of a covered work
in an aggregate does not cause this License to apply to the other
parts of the aggregate.

  6. Conveying Non-Source Forms.

  You may convey a covered work in object code form under the terms
of sections 4 and 5, provided that you also convey the
machine-readable Corresponding Source under the terms of this License,
in one of these ways:

    a) Convey the object code in, or embodied in, a physical product
    (including a physical distribution medium), accompanied by the
    Corresponding Source fixed on a durable physical medium
    customarily used for software interchange.

    b) Convey the object code in, or embodied in, a physical product
    (including a physical distribution medium), accompanied by a
    written offer, valid for at least three years and valid for as
    long as you offer spare parts or customer support for that product
    model, to give anyone who possesses the object code either (1) a
    copy of the Corresponding Source for all the software in the
    product that is covered by this License, on a durable physical
    medium customarily used for software interchange, for a price no
    more than your reasonable cost of physically performing this
    conveying of source, or (2) access to copy the
    Corresponding Source from a network server at no charge.

    c) Convey individual copies of the object code with a copy of the
    written offer to provide the Corresponding Source.  This
    alternative is allowed only occasionally and noncommercially, and
    only if you received the object code with such an offer, in accord
    with subsection 6b.

    d) Convey the object code by offering access from a designated
    place (gratis or for a charge), and offer equivalent access to the
    Corresponding Source in the same way through the same place at no
    further charge.  You need not require recipients to copy the
    Corresponding Source along with the object code.  If the place to
    copy the object code is a network server, the Corresponding Source
    may be on a different server (operated by you or a third party)
    that supports equivalent copying facilities, provided you maintain
    clear directions next to the object code saying where to find the
    Corresponding Source.  Regardless of what server hosts the
    Corresponding Source, you remain obligated to ensure that it is
    available for as long as needed to satisfy these requirements.

    e) Convey the object code using peer-to-peer transmission, provided
    you inform other peers where the object code and Corresponding
    Source of the work are being offered to the general public at no
    charge under subsection 6d.

  A separable portion of the object code, whose source code is excluded
from the Corresponding Source as a System Library, need not be
included in conveying the object code work.

  A "User Product" is either (1) a "consumer product", which means any
tangible personal property which is normally used for personal, family,
or household purposes, or (2) anything designed or sold for incorporation
into a dwelling.  In determining whether a product is a consumer product,
doubtful cases shall be resolved in favor of coverage.  For a particular
product received by a particular user, "normally used" refers to a
typical or common use of that class of product, regardless of the status
of the particular user or of the way in which the particular user
actually uses, or expects or is expected to use, the product.  A product
is a consumer product regardless of whether the product has substantial
commercial, industrial or non-consumer uses, unless such uses represent
the only significant mode of use of the product.

  "Installation Information" for a User Product means any methods,
procedures, authorization keys, or other information required to install
and execute modified versions of a covered work in that User Product from
a modified version of its Corresponding Source.  The information must
suffice to ensure that the continued functioning of the modified object
code is in no case prevented or interfered with solely because
modification has been made.

  If you convey an object code work under this section in, or with, or
specifically for use in, a User Product, and the conveying occurs as
part of a transaction in which the right of possession and use of the
User Product is transferred to the recipient in perpetuity or for a
fixed term (regardless of how the transaction is characterized), the
Corresponding Source conveyed under this section must be accompanied
by the Installation Information.  But this requirement does not apply
if neither you nor any third party retains the ability to install
modified object code on the User Product (for example, the work has
been installed in ROM).

  The requirement to provide Installation Information does not include a
requirement to continue to provide support service, warranty, or updates
for a work that has been modified or installed by the recipient, or for
the User Product in which it has been modified or installed.  Access to a
network may be denied when the modification itself materially and
adversely affects the operation of the network or violates the rules and
protocols for communication across the network.

  Corresponding Source conveyed, and Installation Information provided,
in accord with this section must be in a format that is publicly
documented (and with an implementation available to the public in
source code form), and must require no special password or key for
unpacking, reading or copying.

  7. Additional Terms.

  "Additional permissions" are terms that supplement the terms of this
License by making exceptions from one or more of its conditions.
Additional permissions that are applicable to the entire Program shall
be treated as though they were included in this License, to the extent
that they are valid under applicable law.  If additional permissions
apply only to part of the Program, that part may be used separately
under those permissions, but the entire Program remains governed by
this License without regard to the additional permissions.

  When you convey a copy of a covered work, you may at your option
remove any additional permissions from that copy, or from any part of
it.  (Additional permissions may be written to require their own
removal in certain cases when you modify the work.)  You may place
additional permissions on material, added by you to a covered work,
for which you have or can give appropriate copyright permission.

  Notwithstanding any other provision of this License, for material you
add to a covered work, you may (if authorized by the copyright holders of
that material) supplement the terms of this License with terms:

    a) Disclaiming warranty or limiting liability differently from the
    terms of sections 15 and 16 of this License; or

    b) Requiring preservation of specified reasonable legal notices or
    author attributions in that material or in the Appropriate Legal
    Notices displayed by works containing it; or

    c) Prohibiting misrepresentation of the origin of that material, or
    requiring that modified versions of such material be marked in
    reasonable ways as different from the original version; or

    d) Limiting the use for publicity purposes of names of licensors or
    authors of the material; or

    e) Declining to grant rights under trademark law for use of some
    trade names, trademarks, or service marks; or

    f) Requiring indemnification of licensors and authors of that
    material by anyone who conveys the material (or modified versions of
    it) with contractual assumptions of liability to the recipient, for
    any liability that these contractual assumptions directly impose on
    those licensors and authors.

  All other non-permissive additional terms are considered "further
restrictions" within the meaning of section 10.  If the Program as you
received it, or any part of it, contains a notice stating that it is
governed by this License along with a term that is a further
restriction, you may remove that term.  If a license document contains
a further restriction but permits relicensing or conveying under this
License, you may add to a covered work material governed by the terms
of that license document, provided that the further restriction does
not survive such relicensing or conveying.

  If you add terms to a covered work in accord with this section, you
must place, in the relevant source files, a statement of the
additional terms that apply to those files, or a notice indicating
where to find the applicable terms.

  Additional terms, permissive or non-permissive, may be stated in the
form of a separately written license, or stated as exceptions;
the above requirements apply either way.

  8. Termination.

  You may not propagate or modify a covered work except as expressly
provided under this License.  Any attempt otherwise to propagate or
modify it is void, and will automatically terminate your rights under
this License (including any patent licenses granted under the third
paragraph of section 11).

  However, if you cease all violation of this License, then your
license from a particular copyright holder is reinstated (a)
provisionally, unless and until the copyright holder explicitly and
finally terminates your license, and (b) permanently, if the copyright
holder fails to notify you of the violation by some reasonable means
prior to 60 days after the cessation.

  Moreover, your license from a particular copyright holder is
reinstated permanently if the copyright holder notifies you of the
violation by some reasonable means, this is the first time you have
received notice of violation of this License (for any work) from that
copyright holder, and you cure the violation prior to 30 days after
your receipt of the notice.

  Termination of your rights under this section does not terminate the
licenses of parties who have received copies or rights from you under
this License.  If your rights have been terminated and not permanently
reinstated, you do not qualify to receive new licenses for the same
material under section 10.

  9. Acceptance Not Required for Having Copies.

  You are not required to accept this License in order to receive or
run a copy of the Program.  Ancillary propagation of a covered work
occurring solely as a consequence of using peer-to-peer transmission
to receive a copy likewise does not require acceptance.  However,
nothing other than this License grants you permission to propagate or
modify any covered work.  These actions infringe copyright if you do
not accept this License.  Therefore, by modifying or propagating a
covered work, you indicate your acceptance of this License to do so.

  10. Automatic Licensing of Downstream Recipients.

  Each time you convey a covered work, the recipient automatically
receives a license from the original licensors, to run, modify and
propagate that work, subject to this License.  You are not responsible
for enforcing compliance by third parties with this License.

  An "entity transaction" is a transaction transferring control of an
organization, or substantially all assets of one, or subdividing an
organization, or merging organizations.  If propagation of a covered
work results from an entity transaction, each party to that
transaction who receives a copy of the work also receives whatever
licenses to the work the party's predecessor in interest had or could
give under the previous paragraph, plus a right to possession of the
Corresponding Source of the work from the predecessor in interest, if
the predecessor has it or can get it with reasonable efforts.

  You may not impose any further restrictions on the exercise of the
rights granted or affirmed under this License.  For example, you may
not impose a license fee, royalty, or other charge for exercise of
rights granted under this License, and you may not initiate litigation
(including a cross-claim or counterclaim in a lawsuit) alleging that
any patent claim is infringed by making, using, selling, offering for
sale, or importing the Program or any portion of it.

  11. Patents.

  A "contributor" is a copyright holder who authorizes use under this
License of the Program or a work on which the Program is based.  The
work thus licensed is called the contributor's "contributor version".

  A contributor's "essential patent claims" are all patent claims
owned or controlled by the contributor, whether already acquired or
hereafter acquired, that would be infringed by some manner, permitted
by this License, of making, using, or selling its contributor version,
but do not include claims that would be infringed only as a
consequence of further modification of the contributor version.  For
purposes of this definition, "control" includes the right to grant
patent sublicenses in a manner consistent with the requirements of
this License.

  Each contributor grants you a non-exclusive, worldwide, royalty-free
patent license under the contributor's essential patent claims, to
make, use, sell, offer for sale, import and otherwise run, modify and
propagate the contents of its contributor version.

  In the following three paragraphs, a "patent license" is any express
agreement or commitment, however denominated, not to enforce a patent
(such as an express permission to practice a patent or covenant not to
sue for patent infringement).  To "grant" such a patent license to a
party means to make such an agreement or commitment not to enforce a
patent against the party.

  If you convey a covered work, knowingly relying on a patent license,
and the Corresponding Source of the work is not available for anyone
to copy, free of charge and under the terms of this License, through a
publicly available network server or other readily accessible means,
then you must either (1) cause the Corresponding Source to be so
available, or (2) arrange to deprive yourself of the benefit of the
patent license for this particular work, or (3) arrange, in a manner
consistent with the requirements of this License, to extend the patent
license to downstream recipients.  "Knowingly relying" means you have
actual knowledge that, but for the patent license, your conveying the
covered work in a country, or your recipient's use of the covered work
in a country, would infringe one or more identifiable patents in that
country that you have reason to believe are valid.

  If, pursuant to or in connection with a single transaction or
arrangement, you convey, or propagate by procuring conveyance of, a
covered work, and grant a patent license to some of the parties
receiving the covered work authorizing them to use, propagate, modify
or convey a specific copy of the covered work, then the patent license
you grant is automatically extended to all recipients of the covered
work and works based on it.

  A patent license is "discriminatory" if it does not include within
the scope of its coverage, prohibits the exercise of, or is
conditioned on the non-exercise of one or more of the rights that are
specifically granted under this License.  You may not convey a covered
work if you are a party to an arrangement with a third party that is
in the business of distributing software, under which you make payment
to the third party based on the extent of your activity of conveying
the work, and under which the third party grants, to any of the
parties who would receive the covered work from you, a discriminatory
patent license (a) in connection with copies of the covered work
conveyed by you (or copies made from those copies), or (b) primarily
for and in connection with specific products or compilations that
contain the covered work, unless you entered into that arrangement,
or that patent license was granted, prior to 28 March 2007.

  Nothing in this License shall be construed as excluding or limiting
any implied license or other defenses to infringement that may
otherwise be available to you under applicable patent law.

  12. No Surrender of Others' Freedom.

  If conditions are imposed on you (whether by court order, agreement or
otherwise) that contradict the conditions of this License, they do not
excuse you from the conditions of this License.  If you cannot convey a
covered work so as to satisfy simultaneously your obligations under this
License and any other pertinent obligations, then as a consequence you may
not convey it at all.  For example, if you agree to terms that obligate you
to collect a royalty for further conveying from those to whom you convey
the Program, the only way you could satisfy both those terms and this
License would be to refrain entirely from conveying the Program.

  13. Use with the GNU Affero General Public License.

  Notwithstanding any other provision of this License, you have
permission to link or combine any covered work with a work licensed
under version 3 of the GNU Affero General Public License into a single
combined work, and to convey the resulting work.  The terms of this
License will continue to apply to the part which is the covered work,
but the special requirements of the GNU Affero General Public License,
section 13, concerning interaction through a network will apply to the
combination as such.

  14. Revised Versions of this License.

  The Free Software Foundation may publish revised and/or new versions of
the GNU General Public License from time to time.  Such new versions will
be similar in spirit to the present version, but may differ in detail to
address new problems or concerns.

  Each version is given a distinguishing version number.  If the
Program specifies that a certain numbered version of the GNU General
Public License "or any later version" applies to it, you have the
option of following the terms and conditions either of that numbered
version or of any later version published by the Free Software
Foundation.  If the Program does not specify a version number of the
GNU General Public License, you may choose any version ever published
by the Free Software Foundation.

  If the Program specifies that a proxy can decide which future
versions of the GNU General Public License can be used, that proxy's
public statement of acceptance of a version permanently authorizes you
to choose that version for the Program.

  Later license versions may give you additional or different
permissions.  However, no additional obligations are imposed on any
author or copyright holder as a result of your choosing to follow a
later version.

  15. Disclaimer of Warranty.

  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
APPLICABLE LAW.  EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT
HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY
OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM
IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF
ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

  16. Limitation of Liability.

  IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS
THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY
GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE
USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF
DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD
PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS),
EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

  17. Interpretation of Sections 15 and 16.

  If the disclaimer of warranty and limitation of liability provided
above cannot be given local legal effect according to their terms,
reviewing courts shall apply local law that most closely approximates
an absolute waiver of all civil liability in connection with the
Program, unless a warranty or assumption of liability accompanies a
copy of the Program in return for a fee.

                     END OF TERMS AND CONDITIONS

            How to Apply These Terms to Your New Programs

  If you develop a new program, and you want it to be of the greatest
possible use to the public, the best way to achieve this is to make it
free software which everyone can redistribute and change under these terms.

  To do so, attach the following notices to the program.  It is safest
to attach them to the start of each source file to most effectively
state the exclusion of warranty; and each file should have at least
the "copyright" line and a pointer to where the full notice is found.

    <one line to give the program's name and a brief idea of what it does.>
    Copyright (C) <year>  <name of author>

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

Also add information on how to contact you by electronic and paper mail.

  If the program does terminal interaction, make it output a short
notice like this when it starts in an interactive mode:

    <program>  Copyright (C) <year>  <name of author>
    This program comes with ABSOLUTELY NO WARRANTY; for details type `show w'.
    This is free software, and you are welcome to redistribute it
    under certain conditions; type `show c' for details.

The hypothetical commands `show w' and `show c' should show the appropriate
parts of the General Public License.  Of course, your program's commands
might be different; for a GUI interface, you would use an "about box".

  You should also get your employer (if you work as a programmer) or school,
if any, to sign a "copyright disclaimer" for the program, if necessary.
For more information on this, and how to apply and follow the GNU GPL, see
<https://www.gnu.org/licenses/>.

  The GNU General Public License does not permit incorporating your program
into proprietary programs.  If your program is a subroutine library, you
may consider it more useful to permit linking proprietary applications with
the library.  If this is what you want to do, use the GNU Lesser General
Public License instead of this License.  But first, please read
<https://www.gnu.org/licenses/why-not-lgpl.html>.]]

jcms.ofl_license = [[Copyright © 2017 IBM Corp. with Reserved Font Name "Plex"

This Font Software is licensed under the SIL Open Font License, Version 1.1.
This license is copied below, and is also available with a FAQ at:
https://openfontlicense.org


-----------------------------------------------------------
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007
-----------------------------------------------------------

PREAMBLE
The goals of the Open Font License (OFL) are to stimulate worldwide
development of collaborative font projects, to support the font creation
efforts of academic and linguistic communities, and to provide a free and
open framework in which fonts may be shared and improved in partnership
with others.

The OFL allows the licensed fonts to be used, studied, modified and
redistributed freely as long as they are not sold by themselves. The
fonts, including any derivative works, can be bundled, embedded,
redistributed and/or sold with any software provided that any reserved
names are not used by derivative works. The fonts and derivatives,
however, cannot be released under any other type of license. The
requirement for fonts to remain under this license does not apply
to any document created using the fonts or their derivatives.

DEFINITIONS
"Font Software" refers to the set of files released by the Copyright
Holder(s) under this license and clearly marked as such. This may
include source files, build scripts and documentation.

"Reserved Font Name" refers to any names specified as such after the
copyright statement(s).

"Original Version" refers to the collection of Font Software components as
distributed by the Copyright Holder(s).

"Modified Version" refers to any derivative made by adding to, deleting,
or substituting -- in part or in whole -- any of the components of the
Original Version, by changing formats or by porting the Font Software to a
new environment.

"Author" refers to any designer, engineer, programmer, technical
writer or other person who contributed to the Font Software.

PERMISSION & CONDITIONS
Permission is hereby granted, free of charge, to any person obtaining
a copy of the Font Software, to use, study, copy, merge, embed, modify,
redistribute, and sell modified and unmodified copies of the Font
Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components,
in Original or Modified Versions, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled,
redistributed and/or sold with any software, provided that each copy
contains the above copyright notice and this license. These can be
included either as stand-alone text files, human-readable headers or
in the appropriate machine-readable metadata fields within text or
binary files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font
Name(s) unless explicit written permission is granted by the corresponding
Copyright Holder. This restriction only applies to the primary font name as
presented to the users.

4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
Software shall not be used to promote, endorse or advertise any
Modified Version, except to acknowledge the contribution(s) of the
Copyright Holder(s) and the Author(s) or with their explicit written
permission.

5) The Font Software, modified or unmodified, in part or in whole,
must be distributed entirely under this license, and must not be
distributed under any other license. The requirement for fonts to
remain under this license does not apply to any document created
using the Font Software.

TERMINATION
This license becomes null and void if any of the above conditions are
not met.

DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM
OTHER DEALINGS IN THE FONT SOFTWARE.]]

-- }}}