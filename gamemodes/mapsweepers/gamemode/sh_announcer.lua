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

jcms.ANNOUNCER_FAILED = 1
jcms.ANNOUNCER_VICTORY = 2
jcms.ANNOUNCER_EXITPOD1 = 3
jcms.ANNOUNCER_EXITPOD2 = 4
jcms.ANNOUNCER_SWARM = 5
jcms.ANNOUNCER_SWARM_BIG = 6
jcms.ANNOUNCER_SUPPLIES = 7
jcms.ANNOUNCER_SUPPLIES_AMMO = 8
jcms.ANNOUNCER_IDLE = 9
jcms.ANNOUNCER_AMMO_WASTE = 10
jcms.ANNOUNCER_FRIENDLYFIRE = 11
jcms.ANNOUNCER_FRIENDLYFIRE_KILL = 12
jcms.ANNOUNCER_DEAD = 13
jcms.ANNOUNCER_SHELLING = 14
jcms.ANNOUNCER_ORBITALBEAM = 15
jcms.ANNOUNCER_DONTTOUCH = 16
jcms.ANNOUNCER_JOIN = 17
jcms.ANNOUNCER_HA = 18

jcms.announcer_vo = {}
jcms.announcer_vo_weights = {}
jcms.announcer_vo_types = {["default"] = {["vo"] = jcms.announcer_vo, ["voW"] = jcms.announcer_vo_weights}}
local vo = jcms.announcer_vo
local voW = jcms.announcer_vo_weights

cvars.AddChangeCallback("jcms_announcer_type", function(_, _, new)
	local voType = jcms.announcer_vo_types[new]

	if not voType then
		voType = jcms.announcer_vo_types["default"]
	end

	vo = voType["vo"]
	voW = voType["voW"]
end)

-- {{{
	vo[jcms.ANNOUNCER_FAILED] = {
		"youareawasteofmoney",
		"youareworthless1",
		"pleasestopwastingourresources1",
		"pleasestopwastingourresources2",
		"pleasestopwastingmymoney",
		"canyoubeuseful",
		"gah1",
		"gah2",
		"gah3",
		"endofyearbonus",
		"fuckallofyou",
		"howcouldyoudietonpcs",
		"ivegotbetterthingstodo",
		"wtfamipayingyoufor"
	}
-- }}}

-- {{{
	vo[jcms.ANNOUNCER_VICTORY] = {
		"yeaah",
		"destroyeverything",
		"allsweepersfuck",
		--yippe1 / yippe2 ?
	}

	voW["destroyeverything"] = 0.5
	voW["allsweepersfuck"] = 0.01
-- }}}

-- {{{
	vo[jcms.ANNOUNCER_EXITPOD1] = {
		"exitthepod",
		"go_standingthere",
		"idontpayyoutostandstill",
		"ifyoudontstartmovingperformancereview",
		"move_canyou"
	}

	vo[jcms.ANNOUNCER_EXITPOD2] = {
		"illkillyouifyoudontstartmoving",
		"iwillcomedownthereifyoudontstartmoving",
		"microchipkillsifyoustandstill",
		"move1",
		"move3",
		"go"
	}
-- }}}

-- {{{
	vo[jcms.ANNOUNCER_SWARM] = {
		"anotherwave",
		"morearecoming1",
		"morearecoming2",
		"morearecoming3",
		"morearecoming4",
		"morearecoming_appearnexttoyou",
		"morearecoming_bunchofthingstoshoot",
		"morearecoming_dontwasteammoyet",
		"morearecoming_ranoutofwater"
	}

	voW["anotherwave"] = 2.5
	voW["morearecoming2"] = 2.5
	voW["morearecoming_appearnexttoyou"] = 0.75
	voW["morearecoming_bunchofthingstoshoot"] = 0.75
	voW["morearecoming_dontwasteammoyet"] = 0.75
	voW["morearecoming_ranoutofwater"] = 0.1
-- }}}

-- {{{
	vo[jcms.ANNOUNCER_SWARM_BIG] = {
		"lotofthem",
		"lotsofthemcoming",
		"ohwowbignumber",
		"somanyofthem",
		"theyrecoming1",
		"theyrecoming2",
		"thatsalothavefun"
	}

	voW["theyrecoming1"] = 0.5
	voW["theyrecoming2"] = 0.25
	voW["lotsofthemcoming"] = 2
	voW["somanyofthem"] = 0.15
-- }}}

-- {{{
	vo[jcms.ANNOUNCER_SUPPLIES] = {
		"dontwastethese1",
		"dontwastethese2",
		"dontwastethese3",
		"dontwastethese4",
		"supplies1",
		"supplies2",
		"supplies_droppedaccidentally",
		"supplies_funnycrate",
		"supplies_looksomewhere",
		"supplies_techniciansmistake",
		"supplies_weresending"
	}

	voW["supplies_weresending"] = 2
	voW["dontwastethese1"] = 0.5
	voW["dontwastethese2"] = 0.5
	voW["dontwastethese3"] = 0.5
	voW["dontwastethese4"] = 0.5

	vo[jcms.ANNOUNCER_SUPPLIES_AMMO] = {
		"idroppedweapons",
		"ifyoukeepwastingammo",
		"ilikeammunitionandweapons",
		"youlikeammunitionright"
	}
-- }}}

-- {{{
	vo[jcms.ANNOUNCER_IDLE] = {
		"go_standingthere",
		"doyourjob1",
		"doyourjob2",
		"idontpayyoutostandstill",
		"ihavethisbuttononmydesk",
		"illkillyouifyoudontstartmoving",
		"iwillcomedownthereifyoudontstartmoving",
		"microchipkillsifyoustandstill",
		"taking1dollraforstandingthere",
		"stopnotbeingproductive",
		"startmoving_killswitch",
		"move_canyou",
		"move1",
		"move2",
		"move3"
	}

	voW["move1"] = 0.2
	voW["move2"] = 0.2
	voW["move3"] = 0.2

	--Don't like these ones because it's very obvious I'm just making shit up as I go along - j
	voW["startmoving_killswitch"] = 0.15
	voW["ihavethisbuttononmydesk"] = 0.15
-- }}}

-- {{{
	vo[jcms.ANNOUNCER_AMMO_WASTE] = {
		"dontwasteammo1",
		"dontwasteammo2",
		"stopshootingthings",
		"stopwastingammo",
		"wallsarenotpartof",
		"ihadtopaymoneyforthatammo"
	}
-- }}}

-- {{{
	vo[jcms.ANNOUNCER_FRIENDLYFIRE] = {
		"wrongone1",
		"wrongone2",
		"wrongone3",
		"wrongone4",
		"wrongtarget",
		"whyareyoufighting",
		"notsupposedtoshooteachother"
	}

	vo[jcms.ANNOUNCER_FRIENDLYFIRE_KILL] = {
		"whatareyoudoing1",
		"whatareyoudoing2",
		"whatiswrongwithyou",
		"whatwasthatsupposedtoachieve",
		"whywouldyoudothat1",
		"whywouldyoudothat2",
		"whywouldyoudothat3",
		"whywouldyoudothat4",
		"whywouldyoudothat5",
		"whywouldyoudothat6",
		"donotkilleachother",
		"ifyoukeepkillingeachother",
		"ifyoukillmo_what_fuck",
		"onlyiamallowedtokilljcorp",
		"stopfuckingkillingeachother",
		"youdontkillpeople"
	}
	voW["ifyoukillmo_what_fuck"] = 0.15
	for i = 1, 6 do
		voW["whywouldyoudothat" .. i] = 1 / 6
	end
-- }}}

-- {{{
	vo[jcms.ANNOUNCER_DEAD] = {
		"appearsoneofyouisdead",
		"attachedtoadeadsweeper",
		"attentiondeadbody",
		"expensivemistake",
		"onedown",
		"oneofyoudied",
		"oneofyouisdead",
		"payforanotherrespawn",
		"watcheverytimeyoudie",
		"theywerefuckinguseless"
	}
	voW["watcheverytimeyoudie"] = 0.1
	voW["attachedtoadeadsweeper"] = 0.1
	voW["attentiondeadbody"] = 0.1
	voW["expensivemistake"] = 0.1
	voW["theywerefuckinguseless"] = 0.3
-- }}}

-- {{{
	vo[jcms.ANNOUNCER_SHELLING] = {
		"ilikedestroying",
		"destroyeverything",
		"wearegonnabombeverything"
	}

	vo[jcms.ANNOUNCER_ORBITALBEAM] = {
		"usingbrandnewsatellitetechnology",
		"bigfuckingexplosion",
		"orbitalstrike"
	}
-- }}}

-- {{{
	vo[jcms.ANNOUNCER_DONTTOUCH] = {
		"donttouchthat"
	}

	vo[jcms.ANNOUNCER_HA] = {
		"laugh1",
		"laugh2",
		"ha1",
		"ha2",
		"ha3",
		"ha4",
	}
-- }}}

-- {{{
	vo[jcms.ANNOUNCER_JOIN] = {
		"newsquadmate",
		"anotherguyjoining",
		"babysitthisguy",
		"hopefullythisguydoesabetterjob",
		"iguesstheresmoresweepersnow",
		"killingpeopleperson",
		"reinforcements",
		"thisguyiskindaslow",
		"weactuallydidntsendanyone"
	}
-- }}}

table.Add(vo[jcms.ANNOUNCER_SUPPLIES_AMMO], vo[jcms.ANNOUNCER_SUPPLIES])

if CLIENT then
	jcms.announcer_nextSpeak = 0
	function jcms.announcer_Speak(id, index)
		local voTable = vo[id]
		local chosenLine = voTable[index or math.random(#voTable)]

		local soundDur = SoundDuration("vo/jcms/" .. chosenLine .. ".mp3")
		local cTime = CurTime()

		local timeToSpeak = math.max( jcms.announcer_nextSpeak - cTime ,0)
		jcms.announcer_nextSpeak = math.max(cTime, jcms.announcer_nextSpeak)
		jcms.announcer_nextSpeak = jcms.announcer_nextSpeak + soundDur

		timer.Simple(timeToSpeak, function() --Don't speak until the previous line is over.
			-- todo Make actual HUD element
			chat.AddText(Color(255, 0, 0), "[ MISSION ] ", Color(255, 128, 128), language.GetPhrase("#jcms.vo_" .. chosenLine))

			--Tracking number of uses on both client and server sounds like a pain, so I'm not going to do that.

			if jcms.cvar_announcer:GetBool() then
				EmitSound("vo/jcms/" .. chosenLine .. ".mp3", vector_origin, 0, CHAN_VOICE2, 1, 0, 0, 100, 0)
			end
		end)
	end
end

if SERVER then
	--jcms.announcer_vo_useCounts = {}
	jcms.announcer_vo_history = {} --queue of most recently used lines
	jcms.announcer_vo_historyWeights = { --Weights based on how recent a line was
		[1] = 0.00001, --Can't be 0 because we might have only 1 line.
		[2] = 0.1,
		[3] = 0.25,
		[4] = 0.5,
		[5] = 0.75
		--1 after this
	}

	function jcms.announcer_getHistoryWeight(line)
		for i, histLine in ipairs(jcms.announcer_vo_history) do
			if histLine == line then
				return jcms.announcer_vo_historyWeights[i]
			end
		end
		return 1
	end

	function jcms.announcer_Speak(id, ply)
		local voTable = vo[id]

		local weightedTable = {}
		for i, line in ipairs(voTable) do
			weightedTable[i] = (jcms.announcer_vo_weights[line] or 1) * jcms.announcer_getHistoryWeight(line)
		end

		local chosenIndex = jcms.util_ChooseByWeight(weightedTable)

		if not IsValid(ply) then --Only do history weighting if we're global
			table.insert(jcms.announcer_vo_history, voTable[chosenIndex])
			if #jcms.announcer_vo_history > #jcms.announcer_vo_historyWeights then
				table.remove(jcms.announcer_vo_history, 1)
			end
		end

		--Tell client to play it.
		--if ply is nil, play for everyone. Otherwise only for that person.
		jcms.net_SendAnnouncerSpeak(id, chosenIndex, ply)
	end

	function jcms.announcer_SpeakChance(ch, id, ply)
		if math.random() < ch then
			jcms.announcer_Speak(id, ply)
		end
	end
end
