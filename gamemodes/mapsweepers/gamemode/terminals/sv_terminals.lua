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

jcms.terminal_modeTypes = {}

-- // Terminal Includes {{{
	do 
		local terminalFiles, _ = file.Find( "mapsweepers/gamemode/terminals/types/*.lua", "LUA")
		for i, v in ipairs(terminalFiles) do 
			include("types/" .. v)
			AddCSLuaFile("types/" .. v)
		end
	end
-- // }}}


for modeType, mode in pairs(jcms.terminal_modeTypes) do
	mode.generate = mode.generate or function(ent) return "" end
end

function jcms.terminal_Setup(ent, purposeType, theme)
	ent.jcms_pin = math.random(0,9) .. math.random(0,9) .. math.random(0,9) .. math.random(0,9)
	--print(ent.jcms_pin)
	
	-- Purpose & Hack type {{{
		local purpose = jcms.terminal_modeTypes[ purposeType ]
		if not purpose then 
			purposeType = "pin" 
			purpose = jcms.terminal_modeTypes.pin
		end

		local weighed = {}
		for modeType, mode in pairs(jcms.terminal_modeTypes) do
			if mode.weight then
				weighed[ modeType ] = mode.weight
			end
		end

		local hackType = jcms.util_ChooseByWeight(weighed)

		ent.jcms_purposeType = purposeType
		ent.jcms_hackType = hackType
	-- }}}

	-- NW {{{
		ent:SetNWBool("jcms_terminal_locked", true)
		ent:SetNWString("jcms_terminal_modeType", purposeType) -- Current mode, can be purpose or hack
		ent:SetNWString("jcms_terminal_modeData", purpose.generate(ent))
		ent:SetNWString("jcms_terminal_theme", theme)
	-- }}}
end

function jcms.terminal_Unlock(ent, hacker, intrusive)
	ent:SetNWBool("jcms_terminal_locked", false)
	ent:EmitSound("buttons/lever8.wav", 70, 106, 0.99)

	if intrusive then
		local theme = jcms.util_GetFactionNamePVP(hacker)
		ent:SetNWString("jcms_terminal_theme", theme)
	end
	
	if IsValid(hacker) and hacker:IsPlayer() then
		jcms.statistics_AddOther(hacker, "hacks", 1)
		ent.jcms_hackedBy = hacker
		ent.jcms_manuallyHacked = true
	elseif IsValid(hacker) and IsValid(hacker.jcms_owner) then
		ent.jcms_hackedBy = hacker.jcms_owner
		ent.jcms_manuallyHacked = false
	end

	ent.jcms_hackType = nil
	timer.Simple(math.Rand(0.75, 1.25), function()
		if IsValid(ent) then
			jcms.terminal_ToPurpose(ent)
		end
	end)
end

function jcms.terminal_Punish(ent, ply)
	if IsValid(ent) and IsValid(ply) and ply:Alive() then
		local ed = EffectData()
		ed:SetEntity(ply)
		ed:SetMagnitude(4)
		ed:SetScale(1)
		util.Effect("TeslaHitBoxes", ed)
		
		ent:EmitSound("ambient/energy/zap"..math.random(2, 3)..".wav")
		ply:ScreenFade(SCREENFADE.IN, Color(230, 230, 255, math.random(50, 66)), math.Rand(0.1, 0.3), 0.05)
		
		local dmg = DamageInfo()
		dmg:SetAttacker(ent)
		dmg:SetInflictor(ent)
		dmg:SetDamageType(DMG_SHOCK)
		dmg:SetDamage(math.Rand(1, 7))
		ply:TakeDamageInfo(dmg)
		ply:ViewPunch(AngleRand(-4, 4))
	end
end

function jcms.terminal_ToUnlock(ent)
	-- Pins are obsolete now.
	jcms.terminal_ToHack(ent)

	--[[
	timer.Simple(math.Rand(0.05, 0.15), function()
		if not IsValid(ent) then return end
		ent:SetNWString("jcms_terminal_modeType", "pin")
		local hack = jcms.terminal_modeTypes.pin
		ent:SetNWString("jcms_terminal_modeData", hack.generate(ent))
	end)]]
end

function jcms.terminal_ToHack(ent, instant)
	if instant then
		ent:SetNWString("jcms_terminal_modeType", ent.jcms_hackType)
		local hack = jcms.terminal_modeTypes[ ent.jcms_hackType ]
		ent:SetNWString("jcms_terminal_modeData", hack.generate(ent))
	else
		ent:EmitSound("weapons/stunstick/alyx_stunner" .. math.random(1,2) .. ".wav", 80, 104)
		timer.Simple(math.Rand(0.05, 0.15), function()
			if not IsValid(ent) then return end
			ent:SetNWString("jcms_terminal_modeType", ent.jcms_hackType)
			local hack = jcms.terminal_modeTypes[ ent.jcms_hackType ]
			ent:SetNWString("jcms_terminal_modeData", hack.generate(ent))
		end)
	end
end

function jcms.terminal_ToPurpose(ent)
	ent:EmitSound("weapons/slam/mine_mode.wav", 80, 98)
	timer.Simple(math.Rand(0.05, 0.15), function()
		if not IsValid(ent) then return end
		ent:SetNWString("jcms_terminal_modeType", ent.jcms_purposeType)
		local purpose = jcms.terminal_modeTypes[ ent.jcms_purposeType ]
		ent:SetNWString("jcms_terminal_modeData", purpose.generate(ent))
	end)
end

hook.Add("EntityTakeDamage", "jcms_HackerStunstick", function(ent, dmg)
	if ent.jcms_hackType and dmg:GetInflictor():IsWeapon() and jcms.util_IsStunstick( dmg:GetInflictor() ) and jcms.team_JCorp(dmg:GetAttacker()) then
		local ed = EffectData()
		ed:SetEntity(ent)
		ed:SetMagnitude(4)
		ed:SetScale(1)
		util.Effect("TeslaHitBoxes", ed)

		if ent:GetNWString("jcms_terminal_modeType") == ent.jcms_hackType then
			jcms.terminal_ToPurpose(ent)

			if ent.jcms_hackSoundToStop then
				ent:StopSound(ent.jcms_hackSoundToStop)
			end
		else
			jcms.terminal_ToHack(ent)
		end
	end
end)
