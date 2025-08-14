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

-- // Metatables for optimisation {{{
	local emt = FindMetaTable("Entity")
	local pmt = FindMetaTable("Player")
--// }}}

-- // Mats {{{

	jcms.mat_tpeye = Material "jcms/jeyefx"
	jcms.mat_evac = Material "jcms/landmarks/evac.png"
	jcms.mat_boss = Material "jcms/factions/everyone.png"
	jcms.mat_lock = Material "jcms/lock.png"
	jcms.mat_maze = Material "jcms/maze.png"

-- // }}}

-- // Colors {{{

	if not jcms.color_bright then
		jcms.color_bright = Color(255, 0, 0)
		jcms.color_pulsing = Color(255, 0, 0)
		jcms.color_dark = Color(30, 12, 12)
		
		jcms.color_bright_alt = Color(64, 180, 255)
		jcms.color_dark_alt = Color(3, 12, 30)

		jcms.color_alert1 = Color(255, 255, 0)
		jcms.color_alert2 = Color(255, 120, 0)
		jcms.color_alert = Color(0, 0, 0)

		jcms.hudThemeName = "jcorp"

		timer.Simple(10, function()
			if IsValid(LocalPlayer()) and LocalPlayer().SteamID64 then
				local hashed = util.SHA256( LocalPlayer():SteamID64() )
				
				if jcms.playerfactions_players[ hashed ] then
					jcms.hud_SetTheme(jcms.playerfactions_players[ hashed ])
				end
			end
		end)
	end

-- // }}}

-- // Color ConVars {{{

	jcms.color_themes = {
		-- Factions
		jcorp = {
			color_bright = Color(255, 0, 0),
			color_dark = Color(30, 12, 12),
			color_bright_alt = Color(64, 180, 255),
			color_dark_alt = Color(3, 12, 30),
			color_alert1 = Color(255, 255, 0),
			color_alert2 = Color(255, 120, 0),
		},

		rgg  = {
			color_bright = Color(96, 0, 202),
			color_dark = Color(22, 0, 45),
			color_bright_alt = Color(218, 38, 255),
			color_dark_alt = Color(50, 0, 50),
			color_alert1 = Color(0, 255, 0),
			color_alert2 = Color(141, 0, 202),
		},

		mafia = {
			color_bright = Color(255, 120, 19),
			color_dark = Color(50, 25, 7),
			color_bright_alt = Color(241, 212, 14),
			color_dark_alt = Color(49, 41, 9),
			color_alert1 = Color(255, 255, 255),
			color_alert2 = Color(31, 31, 20),
		},

		-- Bonus
		bluecorp = { --THIS IS NOT REAL! - j
			color_bright = Color(130, 124, 255),
			color_dark = Color(12, 12, 30),
			color_bright_alt = Color(79, 255, 139),
			color_dark_alt = Color(12, 30, 12),
			color_alert1 = Color(255, 200, 0),
			color_alert2 = Color(169, 0, 0),
		}
	}

	jcms.color_convars = jcms.color_convars or {
		jcms_hud_color_bright = CreateClientConVar("jcms_hud_color_bright", "255 0 0", true, false, "RGB value of the primary HUD color (red by default)"),
		jcms_hud_color_dark = CreateClientConVar("jcms_hud_color_dark", "30 12 12", true, false, "RGB value of the background HUD color (dark red by default)"),
		jcms_hud_color_bright_alt = CreateClientConVar("jcms_hud_color_bright_alt", "64 180 255", true, false, "RGB value of the alternate HUD color, used for shields and completed objectives (sky blue by default)"),
		jcms_hud_color_dark_alt = CreateClientConVar("jcms_hud_color_dark_alt", "3 12 30", true, false, "RGB value of the alternate HUD background color (dark blue by default)"),
		jcms_hud_color_alert1 = CreateClientConVar("jcms_hud_color_alert1", "255 255 0", true, false, "RGB value of alert color that flickers. This one's brighter than alert2. (yellow by default)"),
		jcms_hud_color_alert2 = CreateClientConVar("jcms_hud_color_alert2", "255 120 0", true, false, "RGB value of alert color that flickers. This one's darker than alert1. (gold by default)")
	}

	do
		local function callback(name, old, new)
			local r,g,b = new:match("(%d%d?%d?),? ?(%d%d?%d?),? ?(%d%d?%d?)")

			if not (r and g and b) then
				local cvar = jcms.color_convars[ name ]
				r,g,b = cvar:GetDefault():match("(%d%d?%d?),? ?(%d%d?%d?),? ?(%d%d?%d?)")
			end

			r = tonumber(r)
			g = tonumber(g)
			b = tonumber(b)

			local color_name = name:match("jcms_hud_color_([%w_]+)")
			if jcms[ "color_".. color_name ] then
				local color = jcms[ "color_".. color_name ]
				color:SetUnpacked(r,g,b)
			end
		end

		for name, cvar in pairs(jcms.color_convars) do
			callback(name, nil, cvar:GetString())
			cvars.AddChangeCallback(name, callback)
		end
	end

	function jcms.hud_SetTheme(themeName)
		local themeData = jcms.color_themes[ themeName ]

		if themeData then
			jcms.hudThemeName = themeName

			for cname, color in pairs(themeData) do
				local cvar = jcms.color_convars["jcms_hud_"..cname]
				if not cvar then continue end
				cvar:SetString( ("%d %d %d"):format(color.r, color.g, color.b) )
			end
		end
	end

	concommand.Add("jcms_sethudtheme", function(ply, cmd, args)
		if jcms.color_themes[ args[1] ] then
			print("Set theme to '"..args[1].."'")
			jcms.hud_SetTheme(args[1])
		else
			print("Invalid color theme! Here are the available ones: " .. table.concat(table.GetKeys(jcms.color_themes), ", ")) 
		end
	end)

-- // }}}

-- // HUD and Animations {{{

	jcms.hud_pulsingAlpha = 100

	jcms.hud_scoreboardOpen = false
	jcms.hud_scoreboard = 0

	jcms.hud_target = NULL 
	jcms.hud_targetLast = NULL 
	jcms.hud_targetAnim = 0
	jcms.hud_dead = 0
	jcms.hud_ammofracLast = 0
	jcms.hud_ammofracAnim = 1

	jcms.hud_spawnmenuAnim = 0
	jcms.hud_spawnmenuAnimScrollTip = 0
	
	jcms.hud_beginsequencet = 999
	jcms.hud_beginsequenceLen = 7
	jcms.hud_beginsequenceLast = 999
	
	jcms.hud_playedBoostSound = false
	jcms.hud_npcConfirmation = 0

	function jcms.hud_Get3D2DScale() --todo: Could maybe be calculated once instead of repeated, but I've had some minor issues with caching so haven't done that yet -j
		return Lerp(jcms.hud_spawnmenuAnim, 1, 0.8) / ( 6500 / jcms.util_GetRealFOV() ) * jcms.cachedValues.hudScale
	end
	
	function jcms.hud_UpdateColors()
		local sin = ( (math.sin(CurTime() * 5.23) + 1)/2 )^2
		jcms.hud_pulsingAlpha = Lerp(sin, math.random(47,60), math.random(125, 137))
		jcms.color_pulsing:SetUnpacked( jcms.color_bright:Unpack() )
		jcms.color_pulsing.a = jcms.hud_pulsingAlpha

		local alertColor = jcms.color_alert1
		if CurTime() % 0.25 < 0.125 then alertColor = jcms.color_alert2 end
		jcms.color_alert:SetUnpacked(alertColor:Unpack())
	end
	
	hook.Add("Think", "jcms_Colors", jcms.hud_UpdateColors)
	
	function jcms.hud_Update()
		local me = jcms.locPly
		if not IsValid(me) then return end

		if me:Alive() then
			if me:GetObserverMode() == OBS_MODE_CHASE then
				jcms.hud_dead = math.min(1, math.max(jcms.hud_dead - FrameTime(), 0))
			else
				jcms.hud_dead = 0
			end
		else
			jcms.hud_dead = math.max(0, jcms.hud_dead) + FrameTime()
		end

		jcms.hud_scoreboard = (jcms.hud_scoreboard * 8 + (jcms.hud_scoreboardOpen and 1 or 0)) / 9

		if jcms.hud_targetAnim > 1 and not IsValid(jcms.hud_target) then
			jcms.hud_targetAnim = jcms.hud_targetAnim - FrameTime()
		else
			jcms.hud_targetAnim = (jcms.hud_targetAnim * 8 + (IsValid(jcms.hud_target) and 1.5 or 0)) / 9
		end

		jcms.hud_spawnmenuAnim = (jcms.hud_spawnmenuAnim * 6 + (jcms.spawnmenu_isOpen and 1 or 0)) / 7

		if jcms.spawnmenu_scrolled then
			jcms.hud_spawnmenuAnimScrollTip = math.max(0, jcms.hud_spawnmenuAnimScrollTip - FrameTime() * 4)
		else
			jcms.hud_spawnmenuAnimScrollTip = (jcms.spawnmenu_selectedOption and jcms.hud_spawnmenuAnim > 0.99) and (jcms.hud_spawnmenuAnimScrollTip*6 + 1)/7 or math.min(jcms.hud_spawnmenuAnim, jcms.hud_spawnmenuAnimScrollTip)
		end
		
		jcms.hud_UpdateNotifs()
		jcms.hud_UpdateLocators()

		if jcms.locPly:KeyDown(IN_RELOAD) and jcms.locPly:GetObserverMode() == OBS_MODE_CHASE and jcms.locPly:GetNWInt("jcms_desiredteam", 0) < 2 then
			jcms.hud_npcConfirmation = math.Clamp( jcms.hud_npcConfirmation + FrameTime(), 0, 1 )

			if not jcms.hud_npcConfirmed and jcms.hud_npcConfirmation >= 1 then
				jcms.hud_npcConfirmed = true
				surface.PlaySound("weapons/pinpull.wav")
				RunConsoleCommand("jcms_jointeam", "npc")
			end
		else
			jcms.hud_npcConfirmation = 0
			jcms.hud_npcConfirmed = false
		end
	end

	local mat_stripes = Material("jcms/stripes.png", "noclamp")
	function jcms.hud_DrawStripedRect(x,y,w,h,sc,uvOff)
		surface.SetMaterial(mat_stripes)
		sc = sc or 100
		uvOff = uvOff or 0
		surface.DrawTexturedRectUV(x,y,w,h,(x+uvOff)/sc,y/sc,(x+w+uvOff)/sc,(y+h)/sc)
	end
	
	local mat_noise = Material("jcms/noise.png", "noclamp")
	function jcms.hud_DrawNoiseRect(x,y,w,h,sc)
		surface.SetMaterial(mat_noise)
		sc = sc or 100
		local nx, ny = x + math.random()*512, y + math.random()*512
		surface.DrawTexturedRectUV(x,y,w,h,nx/sc,ny/sc,(nx+w)/sc,(ny+h)/sc)
	end
	
	function jcms.hud_GetCrosshairGap(me, wep)
		if IsValid(wep) then
			if wep.ARC9 then
				return math.max(8, math.deg( wep:GetProcessedValue("Spread") ) * 42)
			elseif wep.ArcCW then
				local gA, gD = wep:GetFOVAcc( wep:GetBuff("AccuracyMOA"), wep:GetDispersion() )
				return math.max(8, (gA + gD)*3.5) + math.Clamp(wep.RecoilAmount, 0, 1) * 200
			elseif wep.ArcticTacRP then
				return wep:GetSpread() * 5000
			elseif wep.GetBaseSpread and wep.SpreadRatio then
				return wep.SpreadRatio * math.deg( wep:GetBaseSpread() ) * 42
			elseif wep.Primary and wep.Primary.RPM and wep.Primary.Spread then
				local spread = math.deg(wep.Primary.Spread) * 48
				return math.max(8,spread)
			end
		end
		
		return (100 - 72/(me:GetVelocity():Length()/200+1)) -- default
	end

-- // }}}

-- // Aux functions {{{

	local motionTouchupData = {}
	local function motionTouchup(pos, ang, id)
		if jcms.cachedValues.motionSickness then return end
		local eyePos = EyePos()

		if not motionTouchupData[id] then
			motionTouchupData[id] = {}
		end
		
		local mtd = motionTouchupData[id]
		if mtd.delta then
			local W = 75
			local npos = eyePos + mtd.delta
			local ndelta = pos - eyePos
			local deltaDiff = (ndelta:Distance(mtd.delta)*1.2)^2 + 35
			mtd.delta = Lerp(1 - W/(deltaDiff + W), mtd.delta, ndelta)
			pos:Set(npos)
		else
			mtd.delta = pos - eyePos
		end
	end

	local swayVec = Vector(0,0,0)
	local function setup3d2dDiagonal(top, left)
		local pos = EyePos()
		local angles = EyeAngles()
		local time = CurTime() * 0.56
		
		local pad = 100
		local off, sv = 12 + 0.13 * math.sin(time), gui.ScreenToVector(left and pad*1.2 or jcms.scrW-pad*1.2, top and pad or jcms.scrH-pad)

		swayVec:SetUnpacked(math.sin(time) * 0.1, math.cos(time) * 0.1, math.sin(time*2) * 0.04)
		sv:Mul(32)
		pos:Add(sv)
		pos:Add(swayVec)
		--pos = pos + sv * 32 + swayVec

		angles:RotateAroundAxis(angles:Up(), -90 - off*(left and -1 or 1))
		angles:RotateAroundAxis(angles:Forward(), 90 - (top and -off or off)/4)

		local idx = "x" .. ( (top and 1 or 3) + (left and 0 or 1) )
		motionTouchup(pos, angles, idx)
		cam.Start3D2D(pos, angles, jcms.hud_Get3D2DScale())
		return pos, angles
	end

	local function setup3d2dCentral(dir)
		local pos = EyePos()
		local angles = EyeAngles()
		local time = CurTime() * 0.56 + 0.2
		
		local sv
		local pad = 64
		local offX, offY = 0, 0

		if dir == "top" then 
			sv = gui.ScreenToVector(jcms.scrW/2, pad)
			offY = 24 + 1.13 * math.sin(time)
		elseif dir == "bottom" then 
			sv = gui.ScreenToVector(jcms.scrW/2, jcms.scrH - pad)
			offY = -24 - 1.13 * math.sin(time)
		elseif dir == "left" then 
			sv = gui.ScreenToVector(pad*1.25, jcms.scrH/2)
			offX = 24 + 1.13 * math.sin(time)
		elseif dir == "right" then 
			sv = gui.ScreenToVector(jcms.scrW - pad*1.25, jcms.scrH/2)
			offX = -24 - 1.13 * math.sin(time)
		elseif dir == "center" then
			sv = gui.ScreenToVector(jcms.scrW/2, jcms.scrH/2)
		else
			error("invalid direction") 
		end

		swayVec:SetUnpacked(math.sin(time) * 0.1, math.cos(time) * 0.1, math.sin(time*2) * 0.04)
		sv:Mul(39)
		pos:Add(sv)
		pos:Add(swayVec)
		--pos = pos + sv * 39 + swayVec

		local up = angles:Up()
		angles:RotateAroundAxis(angles:Right(), 90 + offY)
		angles:RotateAroundAxis(angles:Up(), -90)
		angles:RotateAroundAxis(up, offX)

		local idx = "c" .. dir
		motionTouchup(pos, angles, idx)
		cam.Start3D2D(pos, angles, jcms.hud_Get3D2DScale())
		return pos, angles
	end

	local function hudShift( themeTo )
		 --[[
		 	This is a really bad/hacky way of shifting hud-themes for a single draw. 
			I use this for hacked turrets because I wasn't really sure how-else to structure it.
			hudUnshift needs to be called after this or it'll fuck up the values.

			-J
			--PLACEHOLDER(?) - Mainly using this as a "I want you to look at this and tell me if I'm stupid", here.
		--]]
		local themeData = jcms.color_themes[themeTo]

		--Store old theme so we can reset
		jcms.og_color_bright = jcms.color_bright
		jcms.og_color_dark = jcms.color_dark
		jcms.og_color_bright_alt = jcms.color_bright_alt
		jcms.og_color_dark_alt = jcms.color_dark_alt
		jcms.og_color_alert1 = jcms.color_alert1
		jcms.og_color_alert2 = jcms.color_alert2

		--Set new temporary theme.
		jcms.color_bright = themeData.color_bright
		jcms.color_dark = themeData.color_dark
		jcms.color_bright_alt = themeData.color_bright_alt
		jcms.color_dark_alt = themeData.color_dark_alt
		jcms.color_alert1 = themeData.color_alert1
		jcms.color_alert2 = themeData.color_alert2
	end

	local function hudUnshift()
		--Reset to our old theme
		jcms.color_bright = jcms.og_color_bright
		jcms.color_dark = jcms.og_color_dark
		jcms.color_bright_alt = jcms.og_color_bright_alt
		jcms.color_dark_alt = jcms.og_color_dark_alt
		jcms.color_alert1 = jcms.og_color_alert1
		jcms.color_alert2 = jcms.og_color_alert2

		--We don't need these any more.
		jcms.og_color_bright = nil
		jcms.og_color_dark = nil
		jcms.og_color_bright_alt = nil
		jcms.og_color_dark_alt = nil
		jcms.og_color_alert1 = nil
		jcms.og_color_alert2 = nil
	end
-- // }}}

-- // Drawing functions {{{

	function jcms.draw_Vignette()
		if not jcms.mat_vignette or jcms.mat_vignette:IsError() then
			return
		end

		local shouldDrawVignette = not jcms.cvar_hud_novignette:GetBool()

		cam.Start2D()
			surface.SetMaterial(jcms.mat_vignette)
			if jcms.hud_shieldRestoredAnim then
				jcms.hud_shieldRestoredAnim = math.Clamp(jcms.hud_shieldRestoredAnim + FrameTime()*1.6, 0, 1)

				local anim = math.sin(math.pi * (jcms.hud_shieldRestoredAnim^0.5))
				local anim2 = math.sin(math.pi * (jcms.hud_shieldRestoredAnim^0.6))

				surface.SetAlphaMultiplier(anim*0.2)
				render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					surface.SetDrawColor(0, 200*anim2, 255)
					surface.DrawTexturedRect(0, 0, jcms.scrW, jcms.scrH)
				render.OverrideBlend(false)

				if shouldDrawVignette then
					surface.SetAlphaMultiplier(1-anim2)
					surface.SetDrawColor(jcms.color_dark)
					surface.DrawTexturedRect(0, 0, jcms.scrW, jcms.scrH)
				end

				if jcms.hud_shieldRestoredAnim >= 1 then
					jcms.hud_shieldRestoredAnim = nil
				end
			elseif shouldDrawVignette then
				surface.SetDrawColor(jcms.color_dark)
				surface.DrawTexturedRect(0, 0, jcms.scrW, jcms.scrH)
			end
		cam.End2D()
	end

	do 
		local healthbar_decor_rt = GetRenderTarget( "jcms_healthbar_decor_rt", 512+24+128, 128+16)

		render.PushRenderTarget( healthbar_decor_rt )
			cam.Start2D()
				render.Clear( 0,0,0,0) --give us alpha, we start black.
				surface.SetDrawColor(255, 255, 255, 255 )
			
				--+24, +128
				surface.DrawRect(-24+24, -128+16+128, 6, 128)
				surface.DrawRect(-4+24, -128+128, 4, 128)
				surface.DrawRect(0+24, -4+128, 512, 4)
				surface.DrawRect(128+24, 8+128, 512, 2)
			cam.End2D()
		render.PopRenderTarget()
		
		local healthbar_decor_mat = CreateMaterial( "jcms_healthbar_decor_mat", "UnlitGeneric", {
			["$basetexture"] = healthbar_decor_rt:GetName(),
			["$translucent"] = 1,
			["$vertexcolor"] = 1,
			["$vertexalpha"] = 1
		} )

		function jcms.draw_HUDHealthbar_Decor() --Fewer draw operations/more optimised.
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				surface.SetDrawColor(jcms.color_pulsing) --todo: We lose the alpha with this optimisation

				surface.SetMaterial(healthbar_decor_mat)
				surface.DrawTexturedRect(-24, -128, 512+24+128, 128+16)
			render.OverrideBlend( false )
		end
	end

	function jcms.draw_HUDHealthbar()
		local me = jcms.locPly
		if not IsValid(me) then return end 

		local myclass = jcms.cachedValues.playerClass or me:GetNWString("jcms_class", "infantry")
		if myclass ~= jcms.hud_myclass then
			jcms.hud_myclass = myclass
			jcms.hud_myclassMat = Material("jcms/classes/"..myclass..".png")
		end

		jcms.draw_HUDHealthbar_Decor()

		if me:Alive() then
			surface.SetAlphaMultiplier(1)

			local bubbleshields = me:GetNWInt("jcms_shield", 0)
			local healthWidth = ( me:GetMaxHealth() * 4 )
			local armorWidth = ( me:GetMaxArmor() * 4 )
			local addX = 64
			local respawns = jcms.util_GetRespawnCount()
			local deadteammates = 0
			for i, ply in ipairs(player.GetAll()) do
				if ply:GetNWInt("jcms_desiredteam") == 1 and (not ply:GetNWBool("jcms_evacuated")) and (ply:GetObserverMode() == OBS_MODE_CHASE or ply:GetObserverMode() == OBS_MODE_NONE and not ply:Alive()) then
					deadteammates = deadteammates + 1
				end
			end

			surface.SetDrawColor(jcms.color_dark)
			surface.SetMaterial(jcms.hud_myclassMat)
			surface.DrawTexturedRectRotated(42, -64, 72, 72, 0)

			if deadteammates > 0 then
				local str = language.GetPhrase("jcms.deadteammates_hud"):format(deadteammates)
				draw.SimpleText(str, "jcms_hud_small", 64 - 8, 34, jcms.color_dark_alt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			if respawns > 0 then
				local str = language.GetPhrase("jcms.respawns_hud"):format(respawns)
				draw.SimpleText(str, "jcms_hud_small", 64 + 8, deadteammates > 0 and 64 or 34, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			surface.DrawRect(24 + addX, -48, healthWidth, 32)
			draw.SimpleText(me:Health(), "jcms_hud_big", 24+addX, -38, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			surface.SetDrawColor(jcms.color_dark_alt)
			draw.SimpleText(me:Armor(), "jcms_hud_medium", 158+addX, -54 - 12, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			surface.DrawRect(128 + addX, -48 - 12, armorWidth, 16)

			local fracHealth = math.Clamp(me:Health() / me:GetMaxHealth(), 0, 1)
			local fracArmor = math.Clamp(me:Armor() / me:GetMaxArmor(), 0, 1)
			local fracArmorOvercharge = math.Clamp(math.TimeFraction(me:GetMaxArmor(), me:GetMaxArmor() + 100, me:Armor()), 0, 1)

			if not jcms.hud_fracHealth then
				jcms.hud_fracHealth = fracHealth
				jcms.hud_fracArmor = fracArmor
				jcms.hud_hurtTime = 0
				jcms.hud_fracArmorRegen = 0
			else
				if fracHealth < jcms.hud_fracHealth or fracArmor < jcms.hud_fracArmor then
					jcms.hud_hurtTime = (jcms.hud_hurtTime or 0) + FrameTime()
				else
					jcms.hud_hurtTime = 0
				end

				local speed = 1 - 1/(math.max(0, jcms.hud_hurtTime-1)+1)
				jcms.hud_fracHealth = math.max(fracHealth, jcms.hud_fracHealth - FrameTime()*speed)
				jcms.hud_fracArmor = math.max(fracArmor, jcms.hud_fracArmor - FrameTime()*speed)
			end

			local offsetHealth = 6
			local offsetArmor = 6
			local offsetIcon = 4

			local data = jcms.class_GetLocPlyData()
			local shieldDamageElapsed = CurTime() - jcms.hud_damageTimeLast
			local shieldDamageDelay = data and data.shieldDelay or 0

			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				surface.SetDrawColor(jcms.color_bright)
				surface.SetMaterial(jcms.hud_myclassMat)
				surface.DrawTexturedRectRotated(42 + offsetIcon, -64 - offsetIcon, 72, 72, 0)
				if deadteammates > 0 then
					local str = language.GetPhrase("jcms.deadteammates_hud"):format(deadteammates)
					local color = jcms.color_bright_alt
					if CurTime() % 5 < 1 then
						color = jcms.color_alert
					end
					draw.SimpleText(str, "jcms_hud_small", 64 - 8 + offsetIcon, 34 - offsetIcon, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
				if respawns > 0 then
					local str = language.GetPhrase("jcms.respawns_hud"):format(respawns)
					draw.SimpleText(str, "jcms_hud_small", 64 + 8 + offsetIcon, (deadteammates > 0 and 64 or 34) - offsetIcon, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
				surface.DrawRect(24 + offsetHealth + addX, -48 - offsetHealth, healthWidth * fracHealth, 32)
				jcms.hud_DrawStripedRect(24 + addX + offsetHealth/2 + healthWidth*fracHealth, -48 - offsetHealth/2 + 2, healthWidth*(1-fracHealth), 32-4)
				draw.SimpleText(me:Health(), "jcms_hud_big", 24 + addX + offsetHealth/2, -38 - offsetHealth/2, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				
				surface.SetDrawColor(jcms.color_bright_alt)
				surface.DrawRect(128 + addX + offsetArmor, -48 - 12 - offsetArmor, armorWidth * fracArmor, 16)
				jcms.hud_DrawStripedRect(128 + addX + offsetArmor/2 + armorWidth*fracArmor, -48 - 12 - offsetArmor/2 + 2, armorWidth*(1-fracArmor), 16-4, 75)
				draw.SimpleText(me:Armor(), "jcms_hud_medium", 158 + addX + offsetArmor/3, -54 - 12 - offsetArmor/3, jcms.color_bright_alt, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

				if fracArmorOvercharge > 0 then
					local pad = 4 + fracArmorOvercharge*3 + math.random()*4
					surface.SetDrawColor(jcms.color_bright_alt)
					surface.DrawRect(128 + addX + offsetArmor - pad, -48 - 12 - offsetArmor - pad, armorWidth * math.Clamp(fracArmorOvercharge, 0, 1) + pad*2, 16 + pad*2)
					draw.SimpleText(me:Armor(), "jcms_hud_medium", 158 + addX + offsetArmor/3 + math.random(-4, 4), -54 - 12 - offsetArmor/3 + math.random(-4, 4), jcms.color_bright_alt, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				end

				jcms.hud_fracArmorRegen = ((jcms.hud_fracArmorRegen or 0)*12 + (shieldDamageElapsed < shieldDamageDelay and 1 or 0))/13
				if jcms.hud_fracArmorRegen > 0.01 then
					surface.SetAlphaMultiplier(jcms.hud_fracArmorRegen^0.5)
					local shh = 32*jcms.hud_fracArmorRegen
					local shx = 128 + addX + offsetArmor/2 + armorWidth*fracArmor
					local shy = -48 - 12 - offsetArmor/2 + 2 - shh
					local shw = armorWidth*(1-fracArmor)*math.Clamp(shieldDamageElapsed/shieldDamageDelay, 0, 1)
					jcms.hud_DrawNoiseRect(shx, shy, shw, 16-4+shh, 75)
					jcms.hud_DrawNoiseRect(shx, shy, shw, 16-4, 75)
					surface.DrawRect(shx + shw, shy, 2, 16-4+shh)
					surface.DrawRect(shx, shy, 2, 16-4+shh)
					surface.SetAlphaMultiplier(1)
				end
			
				surface.SetDrawColor(jcms.color_alert)
				if jcms.hud_fracHealth > fracHealth then
					local fromX, widthFrac = fracHealth, jcms.hud_fracHealth - fracHealth
					surface.DrawRect(24 + addX + offsetHealth + fromX*healthWidth, -48 - offsetHealth, widthFrac*healthWidth, 32)
				end

				if jcms.hud_fracArmor > fracArmor then
					local fromX, widthFrac = fracArmor, jcms.hud_fracArmor - fracArmor
					surface.DrawRect(128 + addX + offsetArmor + fromX*armorWidth, -48 - 12 - offsetArmor, widthFrac*armorWidth, 16)
				end
			render.OverrideBlend( false )

			if bubbleshields > 0 then
				for i=1, bubbleshields do
					draw.SimpleText("⛊", "jcms_hud_medium", 124 + addX + armorWidth - 34*(i-1), -48 - 12, jcms.color_dark_alt, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
				end

				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					for i=1, bubbleshields do
						draw.SimpleText("⛊", "jcms_hud_medium", 124 + addX + offsetArmor + armorWidth - 34*(i-1), -48 - 12 - offsetArmor, jcms.color_bright_alt, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
					end
				render.OverrideBlend( false )
			end
		else
			local offset = 6
			draw.SimpleText("#jcms.userdead", "jcms_hud_big", 24, -38, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			draw.SimpleText("#jcms.userdead_err", "jcms_hud_medium", 48, -38, jcms.color_dark)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText("#jcms.userdead", "jcms_hud_big", 24+offset, -38-offset, jcms.color_alert, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText("#jcms.userdead_err", "jcms_hud_medium", 48+offset, -38-offset, jcms.color_alert)
			render.OverrideBlend( false )
		end
	end

	do 
		local ammo_decor_rt = GetRenderTarget( "jcms_ammo_decor_rt", 512+128+128, 128+16 )

		render.PushRenderTarget( ammo_decor_rt )
			cam.Start2D()
				render.Clear( 0,0,0,0) --give us alpha, we start black.
				surface.SetDrawColor(255, 255, 255, 255 )
			
				--+128+512, +128
				surface.DrawRect(24-6+128+512, 16, 6, 128)
				surface.DrawRect(128+512, 0, 4, 128)
				surface.DrawRect(128, -4+128, 512, 4)
				surface.DrawRect(0, 8+128, 512, 2)
			cam.End2D()
		render.PopRenderTarget()
		
		local ammo_decor_mat = CreateMaterial( "jcms_ammo_decor_mat", "UnlitGeneric", {
			["$basetexture"] = ammo_decor_rt:GetName(),
			["$translucent"] = 1,
			["$vertexcolor"] = 1,
			["$vertexalpha"] = 1
		} )

		function jcms.draw_HUDAmmo_Decor() --Fewer draw operations/more optimised.
			surface.SetMaterial(ammo_decor_mat)
			surface.DrawTexturedRect(-24-128-512, -128, 512+128+128, 128+16)
		end
	end

	function jcms.draw_HUDAmmo()
		local me = jcms.locPly 
		if not(IsValid(me) and me:Alive()) then return end 

		local wep = me:GetActiveWeapon()
		
		if IsValid(wep) then
			local ammo1 = wep:Clip1()
			local ammoMax1 = wep:GetMaxClip1()
			local frac1 = ammo1 and ammo1/ammoMax1 or 0
			local type1 = wep:GetPrimaryAmmoType()
			local ammoOff1 = me:GetAmmoCount( type1 )

			local ammo2 = wep:Clip2()
			local ammoMax2 = wep:GetMaxClip1()
			local frac2 = ammo2 and ammo2/ammoMax2 or 0
			local type2 = wep:GetSecondaryAmmoType()
			local ammoOff2 = me:GetAmmoCount( type2 )

			local offset1 = 4
			local offset2 = 3

			local tw1 = 0
			local primaryColor = ammoOff1 == 0 and jcms.color_alert or jcms.color_bright

			if type1 ~= -1 or type2 ~= -1 then
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					surface.SetDrawColor(ammoOff1 == 0 and jcms.color_alert or jcms.color_pulsing)
					jcms.draw_HUDAmmo_Decor() --todo: We lose the alpha with this optimisation
				render.OverrideBlend( false )
			end
			
			if type1 ~= -1 then
				if ammoMax1 > -1 then
					tw1 = draw.SimpleText(ammo1, "jcms_hud_huge", -32, -8, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM) + 16
					draw.SimpleText(ammoOff1, "jcms_hud_medium", -32-tw1, -16, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)

					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					draw.SimpleText(ammo1, "jcms_hud_huge", -32 - offset1, -8 - offset1, primaryColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
					draw.SimpleText(ammoOff1, "jcms_hud_medium", -32-tw1 - offset1, -16 - offset1, primaryColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
					render.OverrideBlend( false )
				else
					tw1 = draw.SimpleText(ammoOff1, "jcms_hud_huge", -32, -8, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM) + 16

					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					draw.SimpleText(ammoOff1, "jcms_hud_huge", -32 - offset1, -8 - offset1, primaryColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
					render.OverrideBlend( false )
				end
			end

			if type2 ~= -1 then
				local tw2 = 0
				if ammoMax2 > -1 then
					tw2 = draw.SimpleText(ammo2, "jcms_hud_big", -32-tw1, -96, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM) + 16
				end
				draw.SimpleText(ammoOff2, "jcms_hud_small", -32-tw1-tw2, -88, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)

				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				if ammoMax2 > -1 then
					draw.SimpleText(ammo2, "jcms_hud_big", -32-tw1 - offset2, -96, jcms.color_bright_alt, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
				end
				draw.SimpleText(ammoOff2, "jcms_hud_small", -32-tw1-tw2 - offset2, -88, jcms.color_bright_alt, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
				render.OverrideBlend( false )
			end
		else
			local offset = 4

			draw.SimpleText("#jcms.findweapon", "jcms_hud_medium", -48, -16, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
			draw.SimpleText("#jcms.findweapon_err", "jcms_hud_small", 16, -16, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			draw.SimpleText("#jcms.findweapon", "jcms_hud_medium", -48 - offset, -16 - offset, jcms.color_alert, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
			draw.SimpleText("#jcms.findweapon_err", "jcms_hud_small", 16 - offset, -16 - offset, jcms.color_alert, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			render.OverrideBlend( false )
		end
	end

	do 
		local compass_decor_rt = GetRenderTarget( "jcms_compass_decor_rt", 2048, 16 )

		render.PushRenderTarget( compass_decor_rt )
			cam.Start2D()
				render.Clear( 0,0,0,0) --give us alpha, we start black.
				surface.SetDrawColor(255, 255, 255, 255 )
			
				--+800, +8
				surface.DrawRect(-512+800, 0+8, 1024, 6)
				surface.DrawRect(-800+800, -8+8, 512, 4)
				surface.DrawRect(800-512+800, -8+8, 512, 4)
			cam.End2D()
		render.PopRenderTarget()
		
		local compass_decor_mat = CreateMaterial( "jcms_compass_decor_mat", "UnlitGeneric", {
			["$basetexture"] = compass_decor_rt:GetName(),
			["$translucent"] = 1,
			["$vertexcolor"] = 1,
			["$vertexalpha"] = 1
		} )

		function jcms.draw_HUDCompass_Decor() --Fewer draw operations/more optimised.
			surface.SetMaterial(compass_decor_mat)
			surface.DrawTexturedRect(-800, -8, 2048, 16)
		end
	end

	local jcms_dc_dirCol = Color(0,0,0)
	local jcms_dc_letters = {"E", "N", "W", "S"}
	local jcms_dc_alpha = {0,0,0,0}
	local jcms_dc_ang = {0,0,0,0}
	function jcms.draw_Compass()
		local eyeAngles = EyeAngles()
		local eyePos = EyePos()
		local yaw = math.rad( eyeAngles.yaw )
		local span = 800

		jcms_dc_alpha[1] = math.cos(yaw)					--East
		jcms_dc_alpha[2] = math.cos(yaw - math.pi/2)		--North
		jcms_dc_alpha[3] = math.cos(yaw + math.pi)			--West
		jcms_dc_alpha[4] = math.cos(yaw + math.pi/2)		--South

		jcms_dc_ang[1] = math.sin(yaw)/2+0.5				--East
		jcms_dc_ang[2] = math.sin(yaw - math.pi/2)/2+0.5	--North
		jcms_dc_ang[3] = math.sin(yaw + math.pi)/2+0.5		--West
		jcms_dc_ang[4] = math.sin(yaw + math.pi/2)/2+0.5	--South

		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			surface.SetDrawColor(jcms.color_bright)
			jcms.draw_HUDCompass_Decor()
			
			local date = os.date("*t", os.time())
			local time = string.FormattedTime(jcms.util_GetMissionTime())
			local year = date.year + 900
			local formatted = string.format("%s/%02i/%02i %02i:%02i:%02i", year, date.month, date.day, time.h, time.m, time.s)
			draw.SimpleText(formatted, "jcms_hud_small", -800+8, -16, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

			--Reduces line count if we're low performance. Having fewer thresholds was actually less noticeable - j
			local perfReduce = (jcms.performanceEstimate < 35 and 16) or (jcms.performanceEstimate < 15 and 32) or 0
			local N = 32 - perfReduce
			for k=1, N do --NOTE: Most expensive part of this function.
				if k%(N/4)~=0 then
					local i = k + math.Remap(yaw, 0, math.pi*2, 0, N)
					local x, alpha = math.sin(i/N*math.pi*2)/2+0.5, math.cos(i/N*math.pi*2)
					if alpha > 0 then
						draw.SimpleText("|", "jcms_hud_medium", Lerp(x, -span, span), 42, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
					end
				end
			end

			local br,bg,bb = jcms.color_bright:Unpack()
			for i=1,4 do
				local alpha = jcms_dc_alpha[i]
				if alpha > 0 then 
					local x = jcms_dc_ang[i]
					local letter = jcms_dc_letters[i]
					jcms_dc_dirCol:SetUnpacked(br,bg,bb, alpha*255)

					draw.SimpleText(letter, "jcms_hud_big", Lerp(x, -span, span), 32, jcms_dc_dirCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				end
			end

			for i, locator in ipairs(jcms.hud_locators) do
				if locator.icon then
					local pos = locator.at
					if isentity(pos) and IsValid(pos) then
						pos = pos:WorldSpaceCenter()
					end

					if IsValid(pos) or isvector(pos) then
						local angleTowards = (pos - eyePos):Angle()
						angleTowards:Sub(eyeAngles)
						angleTowards = angleTowards.y
						local yaw = -angleTowards / 180 * math.pi
		
						local x, alpha = math.sin(yaw)/2 + 0.5, math.cos(yaw)
						if alpha > 0 then
							local icon = jcms.hud_locator_icons[ locator.icon ]

							if not icon then
								icon = Material("jcms/landmarks/" .. tostring(locator.icon) .. ".png")
								jcms.hud_locator_icons[ locator.icon ] = icon
							end

							surface.SetMaterial(icon)
							surface.SetDrawColor( jcms.hud_GetLocatorColor(locator) )
							surface.DrawTexturedRectRotated(Lerp(x, -span, span), 82, 64, 64, 0)
						end
					end
				end
			end
		render.OverrideBlend( false )
	end

	function jcms.draw_ScoreboardSweeper(ply, x, y)
		local alphamul = surface.GetAlphaMultiplier()
		local color, colorDark = jcms.color_bright, jcms.color_dark
		if ply == jcms.locPly then
			color, colorDark = jcms.color_bright_alt, jcms.color_dark_alt
		end

		local dead = ply:GetObserverMode() == OBS_MODE_CHASE or not ply:Alive()
		local evacuated = ply:GetNWBool("jcms_evacuated", false)
		local w, h = 1500, 134

		if not jcms.classmats then
			jcms.classmats = {}
		end
		
		local class = ply:GetNWString("jcms_class", "infantry")
		if not jcms.classmats[ class ] then
			jcms.classmats[ class ] = Material("jcms/classes/"..class..".png")
		end

		if dead then
			surface.SetAlphaMultiplier(alphamul*0.75)
		end

		surface.SetDrawColor(colorDark)
		jcms.hud_DrawFilledPolyButton(x-w/2, y-h/2, w, h, 32)

		local healthWidth = ply:GetMaxHealth()*3
		local healthFrac = math.Clamp(ply:Health() / ply:GetMaxHealth(), 0, 1)
		local armorWidth = ply:GetMaxArmor()*3
		local armorFrac = math.Clamp(ply:Armor() / ply:GetMaxArmor(), 0, 1)
		local pingString = ply:IsBot() and "BOT" or ply:Ping() .. "ms"
		local cashString = jcms.util_CashFormat( ply:GetNWInt("jcms_cash", 0) )
		local nick = ply:Nick()

		if dead and not evacuated then
			x = x + math.Rand(-5, 5)
			y = y + math.Rand(-5, 5)
		end

		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			if dead then
				surface.SetAlphaMultiplier(alphamul*0.33)
			end
			surface.SetDrawColor(color)

			if dead and evacuated then
				surface.SetMaterial(jcms.mat_evac)
				surface.DrawTexturedRectRotated(x-w/2+h/2+4, y, 96, 96, 0)
			else
				local cmat = jcms.classmats[ class ]
				surface.SetMaterial(cmat)
				surface.DrawTexturedRectRotated(x-w/2+h/2+4, y, 96, 96, 0)
			end

			draw.SimpleText(nick, "jcms_hud_medium", x - w/2 + h, y, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			
			local cashLineX = x + w/2 - h + 26
			draw.SimpleText(cashString, #cashString >= 8 and "jcms_hud_small" or "jcms_hud_medium", cashLineX, y-26, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			jcms.draw_IconCash_optimised(cashLineX+38, y-26, 16, 16, color)
			draw.SimpleText(pingString, "jcms_hud_medium", cashLineX+8, y+26, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			surface.SetAlphaMultiplier(alphamul)

			if not dead then
				surface.SetDrawColor(jcms.color_bright)
				surface.DrawRect(x - 48, y-32, healthWidth*healthFrac, 24)
				jcms.hud_DrawStripedRect(x - 48 + healthWidth*healthFrac, y-32, healthWidth*(1-healthFrac), 24, 100)

				surface.SetDrawColor(jcms.color_bright_alt)
				surface.DrawRect(x - 48, y, armorWidth*armorFrac, 24)
				jcms.hud_DrawStripedRect(x - 48 + armorWidth*armorFrac, y, armorWidth*(1-armorFrac), 24, 100)
			end
		render.OverrideBlend( false )
	end

	function jcms.draw_ScoreboardEnemy(ply, x, y, isNPC)
		local alphamul = surface.GetAlphaMultiplier()
		local color, colorDark = jcms.color_bright, jcms.color_dark
		if ply == jcms.locPly then
			color, colorDark = jcms.color_bright_alt, jcms.color_dark_alt
		end

		local w, h = 800, 72
		local pingString = ply:IsBot() and "BOT" or ply:Ping()
		local nick = ply:Nick()

		if isNPC then
			local evacuated = ply:GetNWBool("jcms_evacuated", false)
			surface.SetDrawColor(colorDark)
			jcms.hud_DrawFilledPolyButton(x-w/2, y-h/2, w, h, 32)

			if evacuated then
				surface.SetMaterial(jcms.mat_evac)
				surface.SetDrawColor(jcms.color_bright)
				surface.DrawTexturedRectRotated(x + w/2 - h, y, 48, 48, 0)
			end
		else
			draw.SimpleText(nick, "jcms_hud_medium", x - w/2 + h, y + 4, colorDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(pingString, "jcms_hud_medium", x + w/2 - h - 32, y + 4, colorDark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			surface.SetAlphaMultiplier(0.33*alphamul)
		end

		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			draw.SimpleText(nick, "jcms_hud_medium", x - w/2 + h, y, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(pingString, "jcms_hud_medium", x + w/2 - h - 32, y, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		render.OverrideBlend( false )

		surface.SetAlphaMultiplier(alphamul)
	end

	function jcms.draw_Scoreboard()
		local me = jcms.locPly
		if not(IsValid(me) and me:Alive()) then return end

		local level, exp = jcms.statistics_GetLevelAndEXP()
		local nextLevelExp = jcms.statistics_GetEXPForNextLevel(level + 1)

		local blend = jcms.hud_scoreboard
		local matrix = Matrix()
		matrix:Translate(Vector(0, -400 + (1-blend)*-400 - 4*player.GetCount(), -8+blend*8))
		cam.PushModelMatrix(matrix, true)
			local R,G,B = jcms.color_bright:Unpack()

			local time = string.FormattedTime( jcms.util_GetMissionTime() )
			local formatted = string.format("%02i:%02i:%02i", time.h, time.m, time.s)
			local levelX, levelY = -640, -404

			surface.SetAlphaMultiplier(blend)
			draw.SimpleText(game.GetMap(), "jcms_hud_huge", 0, -472, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			draw.SimpleText(GetHostName(), "jcms_hud_medium", 0, -460 - 128, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			draw.SimpleText(formatted, "jcms_hud_big", 0, -460 - 324, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

			local expString = string.format("%s / %s EXP", jcms.util_CashFormat(exp), jcms.util_CashFormat(nextLevelExp))
			surface.SetDrawColor(jcms.color_dark)
			surface.DrawRect(levelX, levelY + 8, 200, 128)
			surface.DrawRect(levelX + 200 + 16, levelY + 128 - 24 + 8, -levelX + 416, 24)
			draw.SimpleText(expString, "jcms_hud_medium", levelX + 200 + 16, levelY + 128 - 32, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

			surface.SetDrawColor(R*blend, G*blend, B*blend)
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				surface.DrawRect(-400,-420-24,800,8)
				surface.DrawRect(-800,-420-8,600,4)
				surface.DrawRect(200,-420-8,600,4)
				surface.DrawRect(-800+100,-250,600,4)
				surface.DrawRect(200-100,-250,600,4)
				surface.DrawRect(-250,-460-324,500,8)

				local expFraction = jcms.statistics_GetEXP()
				surface.DrawRect(levelX, levelY, 200, 128)
				surface.DrawRect(levelX + 200 + 16, levelY + 128 - 24, (-levelX + 416) * (exp / nextLevelExp) * blend, 24)

				draw.SimpleText(game.GetMap(), "jcms_hud_huge", 0, -472 - 4, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(GetHostName(), "jcms_hud_medium", 0, -460 - 128 - 3, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(formatted, "jcms_hud_big", 0, -460 - 324 - 4, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(expString, "jcms_hud_medium", levelX + 200 + 16, levelY + 128 - 32 - 4, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			render.OverrideBlend( false )

			draw.SimpleText(level, level >= 1000 and "jcms_hud_medium" or "jcms_hud_big", levelX + 100, levelY + 64, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local i_sweepers = 0
			local i_npcs = 0
			for i, ply in ipairs( player.GetAll() ) do
				local desiredTeam = ply:GetNWInt("jcms_desiredteam")

				if desiredTeam == 1 then
					jcms.draw_ScoreboardSweeper(ply, -500, i_sweepers*144 - 96)
					i_sweepers = i_sweepers + 1
				elseif desiredTeam == 2 then
					jcms.draw_ScoreboardEnemy(ply, 700, i_npcs*96 - 84, true)
					i_npcs = i_npcs + 1
				end
			end

			for i, ply in ipairs( player.GetAll() ) do
				if ply:GetNWInt("jcms_desiredteam") == 0 then
					jcms.draw_ScoreboardEnemy(ply, 760, i_npcs*96 - 48, false)
					i_npcs = i_npcs + 1
				end
			end

			surface.SetAlphaMultiplier(1)
		cam.PopModelMatrix()
	end

	jcms.draw_crosshairStyleFuncs = {
		-- T-shaped
		[1] = function(off, wide, long, down, blend, r, g, b)
			surface.DrawRect(off, -wide + down, long, wide*2)
			surface.DrawRect(-long-off, -wide + down, long, wide*2)
			surface.DrawRect(-wide, off + down, wide*2, long)
		end,

		-- Triangle
		[2] = function(off, wide, long, down, blend, r, g, b)
			local a = 30
			
			draw.NoTexture()
			for i=1, 3 do
				a = a + 120

				local cos, sin = math.cos(math.rad(a)), math.sin(math.rad(a))
				surface.DrawTexturedRectRotated(cos*(off+long/2), sin*(off+long/2)+down, long, wide*2, -a)
			end
		end,

		-- Plus-shaped
		[3] = function(off, wide, long, down, blend, r, g, b)
			surface.DrawRect(off, -wide + down, long, wide*2)
			surface.DrawRect(-long-off, -wide + down, long, wide*2)
			surface.DrawRect(-wide, off + down, wide*2, long)
			surface.DrawRect(-wide, -off-long + down, wide*2, long)
		end,

		-- Circle
		[4] = function(off, wide, long, down, blend, r, g, b)
			jcms.draw_Circle(0, down, off, off, wide*2, 16)
		end,

		-- Spinning Triangle (MerekiDor's crosshair)
		[-1] = function(off, wide, long, down, blend, r, g, b)
			local a = 30 + CurTime() % 3 * 120
			
			draw.NoTexture()
			for i=1, 3 do
				a = a + 120

				local cos, sin = math.cos(math.rad(a)), math.sin(math.rad(a))
				surface.DrawTexturedRectRotated(cos*(off+long/2), sin*(off+long/2)+down, long, wide*2, -a)
			end
		end,
	}

	function jcms.draw_Crosshair()
		local me = jcms.locPly
		if not(IsValid(me) and me:Alive()) then return end
		
		local shouldBe3D = me:ShouldDrawLocalPlayer()

		if shouldBe3D then
			local tr = me:GetEyeTrace()
			local trLen = tr.HitPos:Distance( tr.StartPos )

			local ang = tr.Normal:Angle()
			ang:RotateAroundAxis(ang:Up(), -90)
			ang:RotateAroundAxis(ang:Forward(), 90)

			cam.Start3D2D( tr.HitPos, ang, math.max( trLen / 3000, 0.03 ) )
		end

		local classData = jcms.class_GetLocPlyData()

		if classData and classData.disallowSprintAttacking and classData.boostedRunSpeed and me:IsSprinting() then
			local frac = math.TimeFraction(classData.runSpeed, classData.boostedRunSpeed, me:GetRunSpeed())
			
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				if frac <= 0 then
					jcms.hud_playedBoostSound = false
					surface.SetDrawColor(jcms.color_bright_alt)
					jcms.draw_Circle(0, 0, 64, 64, 12, 16)

					surface.SetAlphaMultiplier(0.5)
					surface.SetDrawColor(jcms.color_bright_alt)
					
					local n = 4
					local a = (CurTime() % 1) * math.pi*2
					local aSpan = math.pi*2 / n
					for i=1, n do
						jcms.draw_Circle(0, 0, 96, 96, 12, 16, a+aSpan*(i-1), a+aSpan*i-0.5)
					end
				else
					if not jcms.hud_playedBoostSound then
						surface.PlaySound("player/suit_sprint.wav")
						jcms.hud_playedBoostSound = true
					end

					local aSpan = frac * math.pi / 2
					if frac >= 1 then
						surface.SetAlphaMultiplier(1 - CurTime() % 0.5)
					else
						surface.SetAlphaMultiplier(0.5 + frac*0.5)
					end

					surface.SetDrawColor(jcms.color_bright_alt)
					jcms.draw_Circle(0, 0, 96, 96, 12, 16, math.pi/2 + aSpan/2, math.pi*5/2 - aSpan/2)
					
					surface.SetAlphaMultiplier(0.3)
					surface.SetDrawColor(jcms.color_bright_alt)
					jcms.draw_Circle(0, 0, 128, 128, 24, 16, 0, math.pi)

					surface.SetAlphaMultiplier(1)
					surface.SetDrawColor(jcms.color_bright_alt)
					jcms.draw_Circle(0, 0, 128, 128, 20, 16, math.pi/2 - aSpan, math.pi/2 + aSpan)
				end
			render.OverrideBlend( false )
		else
			jcms.hud_playedBoostSound = false

			local blend_sb = 1-jcms.hud_scoreboard
			local blend_fov = math.Clamp(1-(75-jcms.util_GetRealFOV())/5,0,1)
			local blend = math.min(blend_sb, blend_fov)

			local ammofrac = 1
			local clip1 = 0
			local wep = me:GetActiveWeapon()
			if IsValid(wep) and wep:GetMaxClip1() > 0 then
				clip1 = wep:Clip1()
				ammofrac = math.Clamp(clip1 / wep:GetMaxClip1(), 0, 1)
			end

			if jcms.hud_ammofracLast ~= ammofrac then
				jcms.hud_ammofracLast = ammofrac
				jcms.hud_ammofracAnim = 1
			else
				jcms.hud_ammofracAnim = math.max(0, jcms.hud_ammofracAnim - FrameTime())
			end

			local ammofracAnim = jcms.hud_ammofracAnim
			
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				local crosshairGap = jcms.hud_GetCrosshairGap(me, wep) + jcms.cachedValues.crosshair_gap*2
				local off, wide, long = crosshairGap + 32*(1-blend), math.max(1, jcms.cachedValues.crosshair_width)*2*blend, math.max(1, jcms.cachedValues.crosshair_length)*2
				local down = (1-blend_sb) * 128
				local R,G,B = (ammofrac <= 0.33 and jcms.color_alert or jcms.color_bright):Unpack()
				
				surface.SetDrawColor(R*blend, G*blend, B*blend)
				local style = jcms.cachedValues.crosshair_style
				local styleFunc = jcms.draw_crosshairStyleFuncs[ style ]
				if styleFunc then
					styleFunc(off, wide, long, down, blend, R, G, B)
				end

				if jcms.locPly:GetObserverMode() == OBS_MODE_FIXED then
					local ti = CurTime()
					clip1 = 5 - math.floor( ti * 2 % 4 + 1 )
					ammofrac = clip1 / 4
					ammofracAnim = 1 - (ti * 2) % 1
				end
			
				local styleAmmo = jcms.cachedValues.crosshair_ammo
				local ammoIsPermanent = styleAmmo % 2 == 0
				if ammoIsPermanent then
					ammofracAnim = math.max(ammofracAnim, 0.5)
				end

				if ammofracAnim > 0 and styleAmmo == 1 or styleAmmo == 2 then
					local size = crosshairGap - wide*2
					if size <= 16 then
						size = crosshairGap + wide * 2 + 4
					end
					surface.SetDrawColor(R*ammofracAnim, G*ammofracAnim, B*ammofracAnim, 128)

					--NOTE: Very expensive.
					jcms.draw_Circle(0, 0, size, size, wide*2, 6, -math.pi/2*ammofrac, math.pi/2*ammofrac)
					jcms.draw_Circle(0, 0, size, size, wide*2, 6, -math.pi/2*ammofrac + math.pi, math.pi/2*ammofrac + math.pi)
				elseif ammofracAnim > 0 and styleAmmo == 3 or styleAmmo == 4 and clip1 > 0 then
					surface.SetFont("jcms_hud_medium")
					surface.SetTextColor(R*ammofracAnim, G*ammofracAnim, B*ammofracAnim, 128)
					surface.SetTextPos(off, off)
					surface.DrawText(clip1)
				end
				
				local dotMode = jcms.cachedValues.crosshair_dot
				local blend2 = 0

				if dotMode == 1 then -- always
					blend2 = 1
				elseif dotMode == 2 then
					blend2 = 1-blend_fov
				end
				surface.SetDrawColor(R*blend2, G*blend2, B*blend2)
				wide = Lerp(1-blend_fov, wide, 4)
				surface.DrawRect(-wide, -wide, wide*2, wide*2)

			render.OverrideBlend( false )
		end

		if shouldBe3D then
			cam.End3D2D()
		end
	end

	function jcms.draw_Notifs()
		local notifs = jcms.hud_notifs

		for i, notif in ipairs(notifs) do
			local font = "jcms_hud_small"
			surface.SetFont(font)
			local msg = tostring(notif.message)
			local tw, th = surface.GetTextSize(msg)
			tw = tw * 1.06 + 24

			local color, colorDark = jcms.color_bright, jcms.color_dark
			if notif.good then
				color, colorDark = jcms.color_bright_alt, jcms.color_dark_alt
			end

			local f = math.ease.OutBack(notif.a)
			local matrix = Matrix()
			matrix:Translate(Vector(64 - f*64, 0, f * 0.25))

			local fs = 0.66 + f*0.34
			matrix:Scale(Vector(fs, fs, fs))

			local y = notif.y + 128
			cam.PushModelMatrix(matrix, true)
				surface.SetAlphaMultiplier(f / 4)
				surface.SetDrawColor(colorDark)
				surface.DrawRect(-tw - 64 - y * 0.013, -32 + y, tw + 48, 64)

				surface.SetAlphaMultiplier(f)
				surface.SetDrawColor(colorDark)
				surface.DrawRect(-notif.y * 0.013 - 16, -32 + y, 8, 64)

				local off = 2
				draw.SimpleText(msg, font, -tw - 32, y, colorDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					draw.SimpleText(msg, font, -tw - 32 - off, y + off, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					surface.SetDrawColor(color)
					surface.DrawRect(-notif.y * 0.013 - 16 - off, -32 + y + off, 8, 64)
				render.OverrideBlend( false )
				surface.SetAlphaMultiplier(1)
			cam.PopModelMatrix()
		end
	end

	function jcms.draw_NotifsAmmo()
		local notifs = jcms.hud_notifs_ammo

		for i, notif in ipairs(notifs) do
			local isWeapon = notif.amount == 0

			local font1 = isWeapon and "jcms_hud_medium" or "jcms_big"
			local font2 = "jcms_hud_small"
			surface.SetFont(font1)
			local msg = tostring(notif.message)
			local tw, th = surface.GetTextSize(msg)
			tw = tw * 1.06 + (isWeapon and 16 or 64)

			local f = math.ease.OutQuart(notif.a)
			local matrix = Matrix()
			matrix:Translate(Vector(64 - f*64, 0, f * 0.25))

			local fs = 0.66 + f*0.34
			matrix:Scale(Vector(fs, fs, fs))

			local y = -230 - notif.y
			cam.PushModelMatrix(matrix, true)
				surface.SetAlphaMultiplier(f)

				local brightCond = notif.a < 1 and notif.t < notif.tout*0.9
				local clr = brightCond and jcms.color_bright_alt or jcms.color_bright
				local clrDark = brightCond and jcms.color_dark_alt or jcms.color_dark

				if isWeapon then
					surface.SetDrawColor(clrDark)
					local bw = tw + 72
					local bx = -bw

					surface.DrawRect(bx, -32 + y, bw, 64)
					surface.SetDrawColor(clr)
					jcms.hud_DrawStripedRect(bx - 8, -32 + y, 6, 64, 64, notif.t * 64)
					jcms.hud_DrawStripedRect(bx + bw + 2, -32 + y, 6, 64, 64, notif.t * 64)
					draw.SimpleText(msg, font1, bx + bw/2, -32 + y + 32, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				else
					local amount = notif.amount
					surface.SetDrawColor(clrDark)
					surface.DrawRect(-tw - 64, -32 + y, tw + 48, 64)
					surface.SetDrawColor(clr)
					surface.DrawRect(-tw - 64, -32 + y + 60, tw + 48, 4)
					draw.SimpleText(msg, font1, -32, -32 + y + 54, clr, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
					draw.SimpleText((amount<0 and "-" or "+") .. amount, font2, -tw - 64 + 8, -32 + y + 4, clr)
				end

				surface.SetAlphaMultiplier(1)
			cam.PopModelMatrix()
		end
	end

	function jcms.hud_GetLocatorColor(loc)
		--is a warning, or timed and remaining time < 10s
		if (loc.type == jcms.LOCATOR_WARNING) or (loc.type == jcms.LOCATOR_TIMED and math.max(math.ceil(loc.tout - loc.t), 0) < 10) then
			return jcms.color_alert
		elseif loc.type == jcms.LOCATOR_SIGNAL then
			return jcms.color_bright_alt
		end

		return jcms.color_bright
	end
	
	local jcms_dl_mOff = Matrix()
	jcms_dl_mOff:Translate(Vector(1.5, 1.5, 0))
	local jcms_dl_m = Matrix()
	local jcms_dl_transformVec = Vector(0,0,0) --Re-usable vector object since we need them for arbitrary transformations

	local arrow = {
		{ x = 0, y = 0 },
		{ x = -3, y = -6 },
		{ x = 8, y = 0 },
		{ x = -3, y = 6 }
	}

	function jcms.draw_Locators() --todo: this is 1/3 of the (lua) perf cost of regular hud supposedly
		local sw, sh = jcms.scrW, jcms.scrH
		local pad = 64
		local eyePos = EyePos()
		
		for i, loc in ipairs(jcms.hud_locators) do
			local pos = loc.at
			
			if isentity(loc.at) then
				if IsValid(loc.at) then
					pos = loc.at:WorldSpaceCenter()
				else
					loc.at = loc._lastVector
					pos = loc.at

					if loc.tout and loc.t < loc.tout-1 then
						loc.t = 9
						loc.tout = 10
					end
				end
			elseif not isvector(loc.at) then
				loc.t = 999
				loc.tout = 0
				loc.a = 0
				continue
			end

			if not pos then continue end

			if loc._lastVector then
				loc._lastVector:SetUnpacked( pos:Unpack() )
			else
				loc._lastVector = Vector(pos)
			end

			surface.SetAlphaMultiplier(loc.a)

			local spos = pos:ToScreen()
			local x, y = spos.x, spos.y
			
			if x > pad and y > pad and x < sw-pad and y < sh-pad then
				local dist = eyePos:Distance(pos)
				local distStr = jcms.util_ToDistance(dist, true)
				local distToScreenCenter = math.Distance(sw/2, sh/2, x, y)
				local dsc = math.max(math.min(1, (150 - distToScreenCenter)/100), (3000/(dist*(loc.type == jcms.LOCATOR_GENERIC and 1 or 0.1)+3000)))
				
				jcms_dl_m:Identity()
				jcms_dl_transformVec:SetUnpacked(x, y, 0)
				jcms_dl_m:Translate(jcms_dl_transformVec)
				x, y = 0, 0

				jcms_dl_transformVec:SetUnpacked(dsc,dsc,dsc)
				jcms_dl_m:Scale(jcms_dl_transformVec)

				local size = Lerp(math.ease.OutBack(loc.a), 14, 24)

				cam.PushModelMatrix(jcms_dl_m, true)
					local remaining = 0
					if loc.tout then
						remaining = math.max(math.ceil(loc.tout - loc.t), 0)
					end

					if loc.type == jcms.LOCATOR_SIGNAL then
						size = size + math.abs( math.sin(loc.t*5) )*6
					elseif loc.type == jcms.LOCATOR_TIMED then
						size = size + math.abs( math.sin(loc.t + 8*loc.t*loc.t/loc.tout) )*6
					end
					
					local distToCenter = math.sqrt( (x-sw/2)^2 + (y-sh/2)^2 )/(sh/3)
					size = size * 1/(distToCenter+1)

					local landmarkDistanceAlphaMul = loc.icon and math.Clamp( (dist - 512)/128, 0, 1 ) or 1
					surface.SetAlphaMultiplier( landmarkDistanceAlphaMul * (loc.directlyVisible and 1 or 0.35) * math.Clamp(distToCenter*3, 0.25, 1) )
					
					local clr = jcms.hud_GetLocatorColor(loc)

					if loc.type == jcms.LOCATOR_TIMED then
						draw.SimpleTextOutlined(distStr, "jcms_small", x, y + 12, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, jcms.color_dark)
						draw.SimpleTextOutlined(loc.name, "TargetID", x, y - 12, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, jcms.color_dark)
						draw.SimpleTextOutlined(string.FormattedTime(remaining, "%02i:%02i"), "jcms_medium", x, y-2, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, jcms.color_dark)
					elseif loc.type == jcms.LOCATOR_SIGNAL then
						draw.SimpleTextOutlined(distStr, "jcms_small", x, y + 6, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, jcms.color_dark)
						draw.SimpleTextOutlined(loc.name, "jcms_medium", x, y - 6, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, jcms.color_dark)
					else
						draw.SimpleTextOutlined(distStr, "jcms_small", x, y + 6, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, jcms.color_dark)
						draw.SimpleTextOutlined(loc.name, "TargetID", x, y - 2, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, jcms.color_dark)
					end

					if loc.new then
						loc.new = false
					end
				cam.PopModelMatrix()
			elseif (not loc.icon or loc.type == jcms.LOCATOR_WARNING) then
				local frac = loc.new and math.abs( math.sin(CurTime()*4 + i) ) or 0
				local dir = math.atan2(y-sh/2, x-sw/2)
				local cos, sin = math.cos(dir), math.sin(dir)
				draw.NoTexture()
				
				jcms_dl_m:Identity()
				local xScrOff, yScrOff = sw*Lerp(frac, 0.35, 0.3), sh*Lerp(frac, 0.35, 0.3)
				jcms_dl_transformVec:SetUnpacked(sw/2 + cos*xScrOff, sh/2 + sin*yScrOff, 0)
				jcms_dl_m:Translate(jcms_dl_transformVec)
				jcms_dl_m:Rotate(Angle(0, math.deg(dir), 0))
				if loc.new then
					local bop = frac*2 + 1
					jcms_dl_transformVec:SetUnpacked(bop, bop, 1)
					jcms_dl_m:Scale(jcms_dl_transformVec)
				end
				
				local clr = loc.new and jcms.color_bright_alt or jcms.color_bright
				local clr_dark = loc.new and jcms.color_dark_alt or jcms.color_dark
				
				if loc.type == jcms.LOCATOR_WARNING or loc.type == jcms.LOCATOR_TIMED then
					clr = jcms.color_alert
				elseif loc.type == jcms.LOCATOR_SIGNAL then
					clr = jcms.color_bright_alt
				end

				local xAlign = cos < -0.33 and TEXT_ALIGN_LEFT or cos < 0.33 and TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT
				local yAlign = sin < -0.33 and TEXT_ALIGN_TOP or sin < 0.33 and TEXT_ALIGN_CENTER or TEXT_ALIGN_BOTTOM

				surface.SetDrawColor(clr_dark)
				cam.PushModelMatrix(jcms_dl_m, true)
					surface.DrawPoly(arrow)
				cam.PopModelMatrix()
				local xScr, yScr = sw/2+cos*(xScrOff-12), sh/2+sin*(yScrOff-12)
				draw.SimpleText(loc.name, "jcms_small", xScr, yScr, clr_dark, xAlign, yAlign)

				cam.PushModelMatrix(jcms_dl_mOff, true)
				render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)

					surface.SetDrawColor(clr)
					cam.PushModelMatrix(jcms_dl_m, true)
						surface.DrawPoly(arrow)
					cam.PopModelMatrix()

					draw.SimpleText(loc.name, "jcms_small", xScr, yScr, clr, xAlign, yAlign)

				render.OverrideBlend(false)
				cam.PopModelMatrix()
			end
		end

		surface.SetAlphaMultiplier(1)
	end

	function jcms.draw_Tips()
		local time = CurTime()

		if time > jcms.hud_tip_gameplay_time and time < jcms.hud_tip_gameplay_time + jcms.hud_tip_gameplay_duration then
			local fadein = math.Clamp( (time - jcms.hud_tip_gameplay_time)/jcms.hud_tip_gameplay_fadetime, 0, 1)
			local fadeout = math.Clamp( (time - jcms.hud_tip_gameplay_time - jcms.hud_tip_gameplay_duration + jcms.hud_tip_gameplay_fadetime)/jcms.hud_tip_gameplay_fadetime, 0, 1)

			surface.SetFont("jcms_hud_score")
			local tw, th = surface.GetTextSize(jcms.hud_tip_gameplay)
			local w, h = tw + 200, 120
			local y = -500

			if fadein >= 1 then
				surface.SetAlphaMultiplier(1-fadeout)
				surface.SetDrawColor(jcms.color_dark)
				surface.DrawRect(-w/2, y, w, h)

				local off = 8
				render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					surface.SetDrawColor(jcms.color_bright)
					surface.DrawRect(-w/2, y - off, h, h)

					surface.DrawRect(-w/2 + h + 12, y - off + h - 6, w - h - 12, 6)
					draw.SimpleText(jcms.hud_tip_gameplay, "jcms_hud_score", -w/2 + h + 32, y - off + h/2 - 6, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				render.OverrideBlend(false)

				draw.SimpleText("?", "jcms_hud_huge", -w/2 + h/2, y - off + h/2 - 6, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				surface.SetAlphaMultiplier(1)
			else
				w = w * math.ease.OutQuart(fadein)
				surface.SetDrawColor(Lerp(fadein, 255, jcms.color_bright.r), Lerp(fadein, 255, jcms.color_bright.g), Lerp(fadein, 255, jcms.color_bright.b))
				surface.DrawRect(-w/2, y, w, h)
			end
		end

		if time > jcms.hud_tip_mission_time and time < jcms.hud_tip_mission_time + jcms.hud_tip_mission_duration then
			local fadein = math.Clamp( (time - jcms.hud_tip_mission_time)/jcms.hud_tip_mission_fadetime, 0, 1)
			local fadeout = math.Clamp( (time - jcms.hud_tip_mission_time - jcms.hud_tip_mission_duration + jcms.hud_tip_mission_fadetime)/jcms.hud_tip_mission_fadetime, 0, 1)

			surface.SetFont("jcms_hud_huge")
			local tw, th = surface.GetTextSize(jcms.hud_tip_mission)
			local frac = math.min(fadein, 1-fadeout)
			local w, h = 24 + (tw + 280)*math.ease.OutBack(frac), 160
			local col = Color(Lerp(frac, 255, jcms.color_bright_alt.r), Lerp(frac, 255, jcms.color_bright_alt.g), Lerp(frac, 255, jcms.color_bright_alt.b))

			local y = -800

			surface.SetDrawColor(Lerp(frac, jcms.color_bright_alt.r, jcms.color_dark_alt.r), Lerp(frac, jcms.color_bright_alt.g, jcms.color_dark_alt.g), Lerp(frac, jcms.color_bright_alt.b, jcms.color_dark_alt.b))
			surface.DrawRect(-w/2, y, w, h)
			surface.DrawRect(-w/2-48, y, 24, h)
			surface.DrawRect(w/2+24, y, 24, h)
			local off = 12

			render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				local completed = jcms.hud_tip_mission_progress >= 1
				if completed then
					surface.SetAlphaMultiplier( (1-fadeout) * (1 - (time%0.5))^2 )
					surface.SetDrawColor(col)
					surface.DrawRect(-w/2, y-off, w, h)
					surface.DrawRect(-w/2-48, y-off, 24, h)
					surface.DrawRect(w/2+24, y-off, 24, h)
					surface.SetAlphaMultiplier(1-fadeout)
				else
					surface.SetAlphaMultiplier(0.1 * (1-fadeout))
					surface.SetDrawColor(col)
					jcms.hud_DrawStripedRect(-w/2, y-off, w, h, 128, time*100)
					surface.DrawRect(-w/2-48, y-off, 24, h)
					surface.DrawRect(w/2+24, y-off, 24, h)

					surface.SetAlphaMultiplier(1-fadeout)
					surface.SetDrawColor(col)
					jcms.hud_DrawNoiseRect(-w/2, y-off, w*jcms.hud_tip_mission_progress, h, 128)
					surface.DrawRect(-w/2, y + h - 12, w*jcms.hud_tip_mission_progress, 12)
				end
			render.OverrideBlend(false)

			draw.SimpleText(jcms.hud_tip_mission, "jcms_hud_huge", 0, y - off + h/2 - 8, completed and jcms.color_dark_alt or col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			surface.SetAlphaMultiplier(1)
		end
	end

	function jcms.draw_SentinelAnchor()
		if jcms.hud_myclass == "sentinel" then
			local anchoredBy
			for i, ent in ipairs(ents.FindInSphere(jcms.locPly:WorldSpaceCenter(), 200)) do
				if ent.SentinelAnchor and (not ent.GetHackedByRebels or not ent:GetHackedByRebels()) then 
					anchoredBy = ent
					break
				end
			end

			local W = 5
			jcms.hud_sentinelAnchorAnim = ((jcms.hud_sentinelAnchorAnim or 0)*W + (anchoredBy and 1 or 0))/(W+1)
			local anim = jcms.hud_sentinelAnchorAnim

			if anim > 0.001 then
				local off = 6
				local str1 = language.GetPhrase("jcms.sentinelanchored_title")
				local str2 = language.GetPhrase("jcms.sentinelanchored_desc1")
				local str3 = anchoredBy and language.GetPhrase("jcms.sentinelanchored_desc2"):format(anchoredBy.PrintName or anchoredBy:GetClass()) or jcms.hud_sentinelAnchorLastString or ""
				jcms.hud_sentinelAnchorLastString = str3
				
				surface.SetAlphaMultiplier(anim)
				draw.SimpleText(str1, "jcms_hud_big", 0, -24, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(str2, "jcms_hud_medium", 0, -24, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				draw.SimpleText(str3, "jcms_hud_medium", 0, 36, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				
				render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					draw.SimpleText(str1, "jcms_hud_big", 0, -24-off, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
					draw.SimpleText(str2, "jcms_hud_medium", 0, -24-off, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
					draw.SimpleText(str3, "jcms_hud_medium", 0, 36-off, jcms.color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				render.OverrideBlend(false)
				surface.SetAlphaMultiplier(1)
			end
		else
			jcms.hud_sentinelAnchorAnim = 0
			jcms.hud_sentinelAnchorLastString = nil
		end
	end

	do
		local shiftMatrix = Matrix()
		local objShift = Vector(-16, 164, 0)
		local objShiftDown = Vector(0, 84, -0.02)
		
		local rotationMatrix = Matrix()
		rotationMatrix:Rotate(Angle(0, 45, 0))

		function jcms.draw_Information()
			local off = 3

			-- Cash
			local cashColor, cashColorDark = jcms.color_bright, jcms.color_dark
			if #jcms.hud_cashHistory > 0 then
				cashColor, cashColorDark = jcms.color_bright_alt, jcms.color_dark_alt
			end

			local cash = jcms.util_CashFormat( jcms.locPly:GetNWInt("jcms_cash", 0) )
			local tw = draw.SimpleText(cash, "jcms_hud_medium", 0, 0, cashColorDark)
			surface.SetDrawColor(cashColorDark)

			jcms.draw_IconCash_optimised(tw + 32, 35, 4)

			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText(cash, "jcms_hud_medium", off, off, cashColor)
				surface.SetDrawColor(cashColor)
				jcms.draw_IconCash_optimised(tw + 32 + off, 35 + off, 4)
			render.OverrideBlend( false )

			-- Objective
			if not jcms.objective_title then
				off = 2
				local time = CurTime()*4

				surface.SetDrawColor(jcms.color_dark)
				local text = language.GetPhrase("jcms.awaitingorders") .. string.rep(".", math.floor(time)%3 + 1)
				draw.SimpleText(text, "jcms_hud_small", -32, 96, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				do -- Loading cubes
					local matrix = Matrix()
					local dist = math.abs(math.sin(time))*4
					local distVector = Vector(dist, dist, 0)

					matrix:Translate(Vector(-64, 98, 0))
					surface.SetDrawColor(jcms.color_dark)
					cam.PushModelMatrix(matrix, true)
						for i=1,4 do
							local matrix2 = Matrix()
							matrix2:Rotate(Angle(0,90*i + math.ease.InOutQuint((time/(math.pi))%1)*90,0))
							matrix2:Translate(distVector)
							cam.PushModelMatrix(matrix2, true)
								surface.DrawRect(0, 0, 12, 12)
							cam.PopModelMatrix()
						end
					cam.PopModelMatrix()

					matrix:Translate(Vector(off, off, 0))
					surface.SetDrawColor(jcms.color_pulsing)
					cam.PushModelMatrix(matrix, true)
						for i=1,4 do
							local matrix2 = Matrix()
							matrix2:Rotate(Angle(0,90*i + math.ease.InOutQuint((time/(math.pi))%1)*90,0))
							matrix2:Translate(distVector)
							cam.PushModelMatrix(matrix2, true)
								surface.DrawOutlinedRect(0, 0, 12, 12, 2)
							cam.PopModelMatrix()
						end
					cam.PopModelMatrix()
				end

				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					draw.SimpleText(text, "jcms_hud_small", off - 32, 96 + off, jcms.color_pulsing, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				render.OverrideBlend( false )
			else
				off = 1.25
				surface.SetDrawColor(jcms.color_dark)

				local missionType = jcms.objective_title
				local missionData = jcms.missions[ missionType ]
				if missionData and missionData.basename then missionType = missionData.basename end

				local tw = draw.SimpleText("#jcms.missionhud", "jcms_hud_small", 0, 96, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				local missionName = "#jcms." .. missionType
				draw.SimpleText(missionName, "jcms_hud_small", tw + 16, 96, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					surface.SetAlphaMultiplier(0.5)
					draw.SimpleText("#jcms.missionhud", "jcms_hud_small", off, 96 + off, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					surface.SetAlphaMultiplier(1)
					draw.SimpleText(missionName, "jcms_hud_small", tw + 16 + off, 96 + off, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				render.OverrideBlend( false )

				shiftMatrix:Identity()
				shiftMatrix:Translate(objShift)
				
				local y = 0
				for i, objective in ipairs(jcms.objectives) do
					cam.PushModelMatrix(shiftMatrix, true)
						local doDrawDiamond, yShift, diamondColor = jcms.objective_Draw(i, objective)
					cam.PopModelMatrix()

					if doDrawDiamond then
						local color, colorDark = diamondColor or jcms.color_bright, jcms.color_dark
						if objective.completed then
							color, colorDark = diamondColor or jcms.color_bright_alt, jcms.color_dark_alt
						end

						off = 2
						cam.PushModelMatrix(shiftMatrix, true)
							cam.PushModelMatrix(rotationMatrix, true)
								surface.SetDrawColor(colorDark)
								surface.DrawOutlinedRect(-12, -12, 24, 24, 3)
								if objective.completed then
									surface.DrawRect(-6, -6, 12, 12)
								end
								render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
								surface.SetDrawColor(color)
								surface.DrawOutlinedRect(-12 + off, -12, 24, 24, 3)
								if objective.completed then
									surface.DrawRect(-6 + off, -6, 12, 12)
								end
								render.OverrideBlend( false )
							cam.PopModelMatrix()
						cam.PopModelMatrix()
					end
					
					yShift = tonumber(yShift) or 84
					objShiftDown.y = yShift
					shiftMatrix:Translate(objShiftDown)
				end
			end
		end
	end

	function jcms.draw_InfoTargetHackable(blend, x, y) --PLACEHOLDER
		surface.SetAlphaMultiplier(blend)

		local text = language.GetPhrase("jcms.unhack_tip")
		draw.SimpleText(text, "jcms_hud_big", x, y, jcms.color_alert2, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		
		render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			local off = 2
			draw.SimpleText(text, "jcms_hud_big", x+off, y-off, jcms.color_alert, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		render.OverrideBlend(false)
		
		surface.SetAlphaMultiplier(1)
	end

-- // }}}

-- // Rendering {{{

	local show = {
		["CHudGeiger"] = true,
		["CHudChat"] = true,
		["CHudGMod"] = true,
		["CHudMessage"] = true,
		["NetGraph"] = true,
		["CHudWeaponSelection"] = true
	}

	hook.Add("HUDShouldDraw", "jcms_HideHUD", function(name)
		if name == "CHudWeaponSelection" and (jcms.mousewheelOccupied or (IsValid(jcms.locPly) and IsValid(jcms.locPly:GetNWEntity("jcms_vehicle")))) then
			return false
		end
		
		if not show[name] then return false end
	end)

	hook.Add("HUDDrawTargetID", "jcms_NoTargetID", function()
		return false
	end)

	jcms.mat_vignette = Material("jcms/vignette.png")

	hook.Add("PreDrawEffects", "jcms_HUD", function()
		if render.GetRenderTarget() then return end

		draw.NoTexture()
		render.OverrideBlend(false)
		surface.SetAlphaMultiplier(1)
		jcms.hud_Update()
		
		cam.IgnoreZ(true)
		jcms.draw_Vignette()
		
		local ply = jcms.locPly
		if not IsValid(ply) then
			ply = LocalPlayer()
			jcms.locPly = ply
		end
		
		local obs = ply:GetObserverMode()

		if jcms.hud_beginsequencet <= jcms.hud_beginsequenceLen then
			jcms.hud_BeginningSequenceDraw()
		else
			if obs == OBS_MODE_NONE then
				local classData = jcms.class_GetLocPlyData()
				
				if classData and classData.HUDOverride then
					classData.HUDOverride(ply, classData)
				else
					jcms.hud_RegularDraw()
				end
				
				jcms.hud_DrawDeathBlackout()
			elseif obs == OBS_MODE_FIXED then
				if not IsValid(jcms.offgame) then
					jcms.offgame_ShowPreMission()
				end
			elseif obs == OBS_MODE_CHASE then
				local classData = jcms.class_GetLocPlyData()

				if classData and classData.faction then
					cam.Start2D()
						jcms.hud_npc_SpectatorDraw(classData.color or jcms.color_bright, classData.colorAlt or jcms.color_bright_alt)
					cam.End2D()
				else
					jcms.hud_SpectatorDraw()
				end
			elseif obs == OBS_MODE_ROAMING then
				if jcms.vm_evacd > 0 then
					local f = math.ease.InOutCubic(math.Clamp((jcms.vm_evacd-3.5)/1.5, 0, 1))
					cam.Start2D()
						surface.SetDrawColor(0, 0, 0, 255*f)
						surface.DrawRect(-2,-2,jcms.scrW+4,jcms.scrH+4)
					cam.End2D()
				end
			end
		end

		cam.IgnoreZ(false)
	end)

-- // }}}

-- // Notifications {{{

	jcms.hud_notifs = jcms.hud_notifs or {}
	jcms.hud_notifs_ammo = jcms.hud_notifs_ammo or {}

	function jcms.hud_AddNotif(message, good)
		table.insert(jcms.hud_notifs, { y = 0, a = 0, t = 0, tout = 5, good = good, message = message })
		jcms.printf(message)
	end

	function jcms.hud_AddNotifAmmo(message, amount)
		for i, notif in ipairs(jcms.hud_notifs_ammo) do
			if notif.message == message and amount > 0 and notif.t < notif.tout*0.9 then
				notif.t = math.min(notif.t, notif.tout/2)
				notif.a = math.min(notif.a, 0.5)
				notif.amount = notif.amount + amount
				return
			end
		end

		table.insert(jcms.hud_notifs_ammo, { y = 0, a = 0, t = 0, tout = 3, amount = amount, message = message })
	end

	function jcms.hud_UpdateNotifs()
		local dt = FrameTime()

		for i=#jcms.hud_notifs, 1, -1 do
			local notif = jcms.hud_notifs[i]
			
			notif.y = (notif.y * 9 + (i-1)*85) / 10
			notif.t = notif.t + dt
			notif.a = math.Approach(notif.a, (notif.t>notif.tout and 0 or 1), dt * 2)

			if notif.a <= 0 and notif.t > notif.tout then
				table.remove(jcms.hud_notifs, i)
			end
		end

		for i=#jcms.hud_notifs_ammo, 1, -1 do
			local notif = jcms.hud_notifs_ammo[i]
			
			notif.y = (notif.y * 5 + (i-1)*72) / 6
			notif.t = notif.t + dt
			notif.a = math.Approach(notif.a, (notif.t>notif.tout and 0 or 1), dt * 2)

			if notif.a <= 0 and notif.t > notif.tout then
				table.remove(jcms.hud_notifs_ammo, i)
			end
		end
	end

-- // }}}

-- // Tips {{{

	jcms.hud_tip_gameplay = ""
	jcms.hud_tip_gameplay_time = -64
	jcms.hud_tip_gameplay_duration = 6.6
	jcms.hud_tip_gameplay_fadetime = 0.35

	jcms.hud_tip_mission = ""
	jcms.hud_tip_mission_time = -64
	jcms.hud_tip_mission_duration = 3.4
	jcms.hud_tip_mission_fadetime = 0.35
	jcms.hud_tip_mission_progress = 0

	function jcms.hud_UpdateTip(isMission, text, missionProgress)
		local time = CurTime()
		text = language.GetPhrase( tostring(text) )

		if isMission then
			jcms.hud_tip_mission_progress = math.Clamp( tonumber(missionProgress) or 0, 0, 1 )
			jcms.hud_tip_mission = string.format(text, jcms.hud_tip_mission_progress * 100 )

			if time > jcms.hud_tip_mission_time and time < jcms.hud_tip_mission_time + jcms.hud_tip_mission_duration then
				jcms.hud_tip_mission_time = time
			else
				jcms.hud_tip_mission_time = time + jcms.hud_tip_mission_fadetime
			end

			if jcms.hud_tip_mission_progress >= 1 then
				EmitSound("npc/roller/remote_yes.wav", vector_origin, 0, CHAN_STATIC, 1, 0, 0, 150, 0)
			else
				EmitSound("npc/turret_floor/ping.wav", vector_origin, 0, CHAN_STATIC, 1, 0, 0, 200, 0)
			end
		else
			jcms.hud_tip_gameplay = text

			if time > jcms.hud_tip_gameplay_time and time < jcms.hud_tip_gameplay_time + jcms.hud_tip_gameplay_duration then
				jcms.hud_tip_gameplay_time = math.max(jcms.hud_tip_gameplay_time, time - jcms.hud_tip_gameplay_fadetime)
			else
				jcms.hud_tip_gameplay_time = time
			end

			EmitSound("npc/dog/dogphrase10.wav", vector_origin, 0, CHAN_STATIC, 1, 0, 0, 150, 0)
		end
	end

-- // }}}

-- // Locators {{{

	jcms.hud_locators = jcms.hud_locators or {}
	jcms.hud_locator_icons = {}
	
	function jcms.hud_AddLocator(id, name, at, type, timeout, icon)
		local totallyNew = true
		
		if id then
			for i, loc in ipairs(jcms.hud_locators) do
				if loc.id == id then
					table.remove(jcms.hud_locators, i)
					totallyNew = false
					break
				end
			end
		end

		if totallyNew then
			surface.PlaySound("ui/buttonrollover.wav")
		end
		
		table.insert(jcms.hud_locators, { 
			id = id, 
			name = name, 
			type = type, 
			at = at, 
			t = 0, 
			tout = timeout, 
			a = totallyNew and 0 or 1,
			icon = icon,
			new = totallyNew 
		})
	end
	
	function jcms.hud_UpdateLocators()
		local dt = FrameTime()
		local mypos = EyePos()

		local W = 7
		for i=#jcms.hud_locators, 1, -1 do
			local loc = jcms.hud_locators[i]
			loc.t = loc.t + dt

			if loc._lastVector then
				local trace = util.TraceLine {
					start = mypos,
					endpos = loc._lastVector,
					mask = MASK_SOLID_BRUSHONLY
				}

				loc.directlyVisible = not trace.Hit
			else
				loc.directlyVisible = false
			end

			if loc.tout and loc.t > loc.tout then
				loc.a = (loc.a*W + 0)/(W+1) - FrameTime()/2
				if loc.a < 0 then
					table.remove(jcms.hud_locators, i)
				end
			else
				loc.a = (loc.a*W + 1)/(W+1)
			end
		end
	end

-- // }}}

-- // InfoTarget {{{

	jcms.hud_infoTargetFuncs_boss = function(ent, blend, bossType)
		local colDark, colBright = jcms.color_dark, jcms.color_bright
		surface.SetAlphaMultiplier(blend)
		if bossType then
			local bossName = language.GetPhrase("jcms.bestiary_" .. bossType)
			local tw = draw.SimpleText(bossName, "jcms_hud_small", 12, 64, colDark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			surface.SetMaterial(jcms.mat_boss)
			surface.SetDrawColor(colDark)
			surface.DrawTexturedRectRotated(-tw/2-12, 64, 32*blend, 32*blend, 0)

			local hpw = math.max(96, tw*2.5)*blend
			local hph = math.max(8, hpw/32)
			local hpFrac = ent:GetNWFloat("HealthFraction", -1)
			if hpFrac == -1 then
				hpFrac = ent:Health() / ent:GetMaxHealth()
			end
			hpFrac = math.Clamp(hpFrac, 0, 1)

			surface.DrawRect(-hpw/2, 100, hpw, hph)

			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText(bossName, "jcms_hud_small", 12, 60, colBright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				surface.SetDrawColor(colBright)
				surface.DrawTexturedRectRotated(-tw/2-12, 60, 32*blend, 32*blend, 0)
				
				surface.DrawRect(-hpw/2, 96, hpw*hpFrac, hph)
				if hpFrac < 1 then
					jcms.hud_DrawStripedRect(-hpw/2+hpw*hpFrac, 96+hph/4, hpw*(1-hpFrac), hph/2, 64, CurTime()*64)
				end
			render.OverrideBlend( false )
		end
	end

	jcms.hud_infoTargetFuncs = {
		["player"] = function(ply, blend)
			if ply:Team() == 1 then
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					local R,G,B = jcms.color_bright:Unpack()
					surface.SetDrawColor(R*0.25*blend, G*0.25*blend, B*0.25*blend)
					surface.DrawRect(0, -256, 512*blend, 32)
				render.OverrideBlend( false )

				surface.SetAlphaMultiplier(blend)

				local healthFrac = math.Clamp(ply:Health()/ply:GetMaxHealth(), 0, 1)
				local armorFrac = math.Clamp(ply:Armor()/ply:GetMaxArmor(), 0, 1)
				
				local classString = language.GetPhrase("jcms.class_" .. ply:GetNWString("jcms_class", "infantry"))
				draw.SimpleText(ply:Nick(), "jcms_hud_big", 16, -256, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(classString, "jcms_hud_medium", 32, -256 - 24, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				
				local healthWidth = ( ply:GetMaxHealth() * 4 )*blend
				local armorWidth = ( ply:GetMaxArmor() * 4 )*blend

				surface.SetDrawColor(jcms.color_dark)
				surface.DrawRect(16, -190, healthWidth, 24)
				surface.SetDrawColor(jcms.color_dark_alt)
				surface.DrawRect(64, -190 - 10, armorWidth, 16)
				
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				draw.SimpleText(ply:Nick(), "jcms_hud_big", 16 + 4, -256 - 1, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(classString, "jcms_hud_medium", 32 + 3, -256 - 24 - 1, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				surface.SetDrawColor(jcms.color_bright)
				surface.DrawRect(16 + 4, -190 - 2, healthWidth*healthFrac, 24)
				jcms.hud_DrawStripedRect(16 + 4 + healthWidth*healthFrac, -190 + 2, healthWidth*(1-healthFrac), 24-4)
				surface.SetDrawColor(jcms.color_bright_alt)
				surface.DrawRect(64 + 4, -190 - 10 - 2, armorWidth*armorFrac, 16)
				jcms.hud_DrawStripedRect(64 + 4 + armorWidth*armorFrac, -190 - 10 + 2, armorWidth*(1-armorFrac), 16-4, 75)
				render.OverrideBlend(false)
			end
		end,

		["jcms_turret"] = function(ent, blend)
			if ent:GetHackedByRebels() then
				hudShift( (jcms.hudThemeName == "rgg" and "jcorp") or "rgg" )
				jcms.draw_InfoTargetHackable(blend, 0, -620)
			end

			surface.SetAlphaMultiplier(blend)
			local x1 = Lerp(blend, 255, 300)
			local x2 = Lerp(blend, 270, 357)
			local name = "#jcms.turret_"..ent:GetTurretKind()
			draw.SimpleText(name, "jcms_hud_big", x1, -256, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

			local isPushable = ent:GetMoveType() ~= MOVETYPE_NONE
			local useText = ""
			if isPushable then
				useText = string.format(language.GetPhrase("jcms.pushtip"), string.upper(input.LookupBinding( "USE" )))
				draw.SimpleText(useText, "jcms_hud_small", x1, -256, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			local healthWidth = 228*blend
			local healthFrac = ent:GetTurretHealthFraction()

			draw.SimpleText("⚒", "jcms_hud_big", x2-8, -230 + 12, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			surface.SetDrawColor(jcms.color_dark)
			surface.DrawRect(x2, -230, healthWidth, 24)
			local tw = draw.SimpleText("#jcms.ammohud", "jcms_hud_small", x2, -200, jcms.color_dark)

			local clipstr = ent:GetTurretClip() .. " / " .. ent:GetTurretMaxClip()
			draw.SimpleText(clipstr, "jcms_hud_small", x2 + tw, -200, jcms.color_dark_alt)

			render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				local off = 2
				draw.SimpleText(name, "jcms_hud_big", x1+off, -256-off, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				if isPushable then
					draw.SimpleText(useText, "jcms_hud_small", x1+off, -256-off, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
				draw.SimpleText("⚒", "jcms_hud_big", x2-8+off, -230+12-off, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				surface.SetDrawColor(jcms.color_bright)
				surface.DrawRect(x2 + off, -230 - off, healthWidth*healthFrac, 24)
				jcms.hud_DrawStripedRect(x2 + healthWidth*healthFrac, -230, healthWidth*(1-healthFrac), 24-4)

				draw.SimpleText("#jcms.ammohud", "jcms_hud_small", x2+off, -200-off, jcms.color_bright_alt)
				draw.SimpleText(clipstr, "jcms_hud_small", x2+tw+off, -200-off, jcms.color_bright_alt)
			render.OverrideBlend(false)

			surface.SetAlphaMultiplier(1)

			if ent:GetHackedByRebels() then 
				hudUnshift()
			end
		end,

		["jcms_cache"] = function(ent)
		end,

		["jcms_terminal"] = function(ent)
		end,
		
		["jcms_shieldcharger"] = function(ent, blend)

			if ent:GetHackedByRebels() then 
				hudShift( (jcms.hudThemeName == "rgg" and "jcorp") or "rgg" )
				jcms.draw_InfoTargetHackable(blend, 0, -512)
			end

			surface.SetAlphaMultiplier(blend)
			local healthFrac = ent:GetHealthFraction()
			local title = "#jcms.shieldcharger"
			local desc = language.GetPhrase("jcms.chargepercent"):format(healthFrac*100)
			local x1 = Lerp(blend, 255, 300)
			local x2 = Lerp(blend, 270, 357)
			draw.SimpleText(title, "jcms_hud_big", x1, -256, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			draw.SimpleText(desc, "jcms_hud_medium", x1, -200, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			local healthWidth = 300*blend
			
			surface.SetDrawColor(jcms.color_dark_alt)
			surface.DrawRect(x2, -190, healthWidth, 24)

			render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				local off = 2
				draw.SimpleText(title, "jcms_hud_big", x1+off, -256-off, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(desc, "jcms_hud_medium", x1+off, -200-off, jcms.color_bright_alt, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

				surface.SetDrawColor(jcms.color_bright_alt)
				surface.DrawRect(x2 + off, -190 - off, healthWidth*healthFrac, 24)
				jcms.hud_DrawStripedRect(x2 + healthWidth*healthFrac, -190, healthWidth*(1-healthFrac), 24-4)
			render.OverrideBlend(false)

			surface.SetAlphaMultiplier(1)

			if ent:GetHackedByRebels() then 
				hudUnshift()
			end
		end,

		["jcms_tesla"] = function(ent, blend)
			if ent:GetHackedByRebels() then 
				hudShift( (jcms.hudThemeName == "rgg" and "jcorp") or "rgg" )
				jcms.draw_InfoTargetHackable(blend, 0, -512)
			end

			surface.SetAlphaMultiplier(blend)
			local healthFrac = ent:GetHealthFraction()
			local x1 = Lerp(blend, 255, 300)
			local x2 = Lerp(blend, 270, 357)
			local title = "#jcms.tesla"
			local desc = language.GetPhrase("jcms.chargepercent"):format(healthFrac*100)
			draw.SimpleText(title, "jcms_hud_big", x1, -256, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			draw.SimpleText(desc, "jcms_hud_medium", x1, -200, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			local healthWidth = 300*blend
			
			surface.SetDrawColor(jcms.color_dark_alt)
			surface.DrawRect(x2, -190, healthWidth, 24)

			render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				local off = 2
				draw.SimpleText(title, "jcms_hud_big", x1+off, -256-off, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(desc, "jcms_hud_medium", x1+off, -200-off, jcms.color_bright_alt, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

				surface.SetDrawColor(jcms.color_bright_alt)
				surface.DrawRect(x2 + off, -190 - off, healthWidth*healthFrac, 24)
				jcms.hud_DrawStripedRect(x2 + healthWidth*healthFrac, -190, healthWidth*(1-healthFrac), 24-4)
			render.OverrideBlend(false)

			surface.SetAlphaMultiplier(1)

			if ent:GetHackedByRebels() then 
				hudUnshift()
			end
		end,
		
		["prop_thumper"] = function(ent, blend)
			if ent:Health() > 0 then
				local str1 = "#jcms.thumpersabotagecaption"
				local str2 = "#jcms.thumpersabotagedesc1"
				local str3 = "#jcms.thumpersabotagedesc2"
				surface.SetAlphaMultiplier(blend)
				local x1 = Lerp(blend, 255, 300)
				local x2 = Lerp(blend, 225, 340)
				draw.SimpleText(str1, "jcms_hud_big", x1, 800, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(str2, "jcms_hud_medium", x2, 870, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(str3, "jcms_hud_medium", x2, 930, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				
				local healthFrac = ent:GetNWFloat("HealthFraction", 1)
				local healthWidth = 1000*blend

				surface.SetDrawColor(jcms.color_dark)
				surface.DrawRect(x2, 1000, healthWidth, 24)

				render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					local off = 2
					draw.SimpleText(str1, "jcms_hud_big", x1+off, 800-off, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
					draw.SimpleText(str2, "jcms_hud_medium", x2+off, 870-off, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
					draw.SimpleText(str3, "jcms_hud_medium", x2+off, 930-off, jcms.color_alert, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
					
					surface.SetDrawColor(jcms.color_bright)
					surface.DrawRect(x2 + off, 1000 - off, healthWidth*healthFrac, 24)
					jcms.hud_DrawStripedRect(x2 + healthWidth*healthFrac, 1000, healthWidth*(1-healthFrac), 24-4)
				render.OverrideBlend(false)

				surface.SetAlphaMultiplier(1)
			end
		end,

		["jcms_zombiebeacon"] = function(ent, blend)
			if ent:Health() > 0 and not ent:GetIsComplete() then
				local charging = ent:GetActive()
				
				surface.SetAlphaMultiplier(blend)
				
				local off = 4
				local x1 = Lerp(blend, 800, 1100)
				local x2 = Lerp(blend, 850, 1200)

				if charging then
					draw.SimpleText("#jcms.terminal_nukearmingtip", "jcms_hud_big", x1, -300, jcms.color_dark)
					local charge = ent:GetCharge()
					surface.SetDrawColor(jcms.color_dark_alt)
					surface.DrawRect(x2, -170, 700, 48)
					surface.SetDrawColor(jcms.color_dark)
					surface.DrawRect(x2 + 32, -112, 500, 48)

					render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
						surface.SetDrawColor(jcms.color_bright_alt)
						surface.DrawOutlinedRect(x2+off, -170-off, 700, 48, 4)
						jcms.hud_DrawStripedRect(x2+off, -170-off, 700, 48, 128, CurTime() * -64)
						surface.DrawRect(x2+off, -170-off, 700*charge, 48, 4)

						surface.SetDrawColor(jcms.color_bright)
						surface.DrawRect(x2 + 32 + off, -112 - off, 500*ent:GetHealthFraction(), 48)

						draw.SimpleText("#jcms.terminal_nukearmingtip", "jcms_hud_big", x1+off, -300-off, jcms.color_alert)
					render.OverrideBlend(false)
				else
					draw.SimpleText("#jcms.terminal_nukehelp", "jcms_hud_medium", x1, -300, jcms.color_dark)

					render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
						draw.SimpleText("#jcms.terminal_nukehelp", "jcms_hud_medium", x1+off, -300-off, jcms.color_bright)
					render.OverrideBlend(false)
				end

				surface.SetAlphaMultiplier(1)
			end
		end,
		
		["jcms_zombieumbrella"] = function(ent, blend)
			surface.SetAlphaMultiplier(blend)
			local x1 = Lerp(blend, 255, 300)
			local x2 = Lerp(blend, 270, 357)
			local name = "#jcms.umbrellatitle"
			draw.SimpleText(name, "jcms_hud_big", x1, -256, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			
			local healthWidth = 228*blend
			local healthFrac = ent:GetHealthFraction()

			draw.SimpleText("⚒", "jcms_hud_big", x2-8, -230 + 12, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			surface.SetDrawColor(jcms.color_dark)
			surface.DrawRect(x2, -230, healthWidth, 24)

			render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				local off = 2
				draw.SimpleText(name, "jcms_hud_big", x1+off, -256-off, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText("⚒", "jcms_hud_big", x2-8+off, -230+12-off, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				surface.SetDrawColor(jcms.color_bright)
				surface.DrawRect(x2 + off, -230 - off, healthWidth*healthFrac, 24)
				jcms.hud_DrawStripedRect(x2 + healthWidth*healthFrac, -230, healthWidth*(1-healthFrac), 24-4)
			render.OverrideBlend(false)

			surface.SetAlphaMultiplier(1)
		end
	}
	jcms.hud_infoTargetFuncs.jcms_turret_smrls = jcms.hud_infoTargetFuncs.jcms_turret

	function jcms.render_TargetInfo(ent)
		local origin = ent:WorldSpaceCenter()
		local blend = math.min(jcms.hud_targetAnim, 1)

		local pos = ent:WorldSpaceCenter()
		local angle = ent:EyeAngles()

		local bossType = ent:GetNWString("jcms_boss", "")
		if bossType == "" then bossType = nil end
		
		local eyeAngles = EyeAngles()
		if bossType then
			angle.p = 0
			angle:RotateAroundAxis(angle:Forward(), 90)
			angle.y = eyeAngles.y - 90
	
			local sc = EyePos():Distance(origin) / 1500
			if sc < 0.5 then
				sc = (sc*2 + 0.5)/3
			end
			cam.Start3D2D(pos, angle, sc)
				jcms.hud_infoTargetFuncs_boss(ent, blend, bossType)
			cam.End3D2D()
		else
			angle.p = 0
			angle:RotateAroundAxis(angle:Forward(), 90)
			angle.y = ( math.Round(eyeAngles.y/45)*45 - 90 )
	
			cam.Start3D2D(pos, angle, 1 / 16)
				jcms.hud_infoTargetFuncs[ ent:GetClass() ](ent, blend)
			cam.End3D2D()
		end

		render.OverrideBlend( false )
		surface.SetAlphaMultiplier(1)
	end

	function jcms.hud_GetInfoTargetData(ent)
		local f = jcms.hud_infoTargetFuncs[ ent:GetClass() ]
		local isBoss = ent:GetNWString("jcms_boss", "") ~= ""
		return not not (f or isBoss), isBoss
	end

-- // }}}

-- // Regular HUD {{{

	function jcms.hud_RegularDraw()
		if jcms.disableHUD then return end
		
		local locPly = jcms.locPly

		render.ClearDepth()
		cam.IgnoreZ(true)

		local trace = locPly:GetEyeTrace()

		if IsValid(trace.Entity) then
			local isInfoTarget, longRange = jcms.hud_GetInfoTargetData(trace.Entity)
			if isInfoTarget and trace.StartPos:DistToSqr(trace.HitPos) < (longRange and 25000000 or 90000) then -- 300 HU for short-range, 5000 HU for long range
				jcms.hud_target = trace.Entity
				jcms.hud_targetLast = trace.Entity
			else
				jcms.hud_target = nil
			end
		else
			jcms.hud_target = nil
		end
		
		if jcms.hud_dead > 0 then
			local f = math.ease.InOutCubic(math.Clamp((jcms.hud_dead-0.6)/3, 0, 1))
			cam.Start2D()
				surface.SetDrawColor(0, 0, 0, 255*f)
				surface.DrawRect(-2,-2,jcms.scrW+4,jcms.scrH+4)
			cam.End2D()
		end
		
		if jcms.hud_targetAnim > 0.01 and IsValid(jcms.hud_targetLast) then
			jcms.render_TargetInfo(jcms.hud_targetLast)
		end
		
		if jcms.hud_spawnmenuAnim <= 0.05 then
			cam.Start2D()
				jcms.draw_Locators()
			cam.End2D()
		end

		local vehicle = locPly:GetNWEntity("jcms_vehicle")
		if IsValid(vehicle) then
			if vehicle.DrawHUDBottom then
				setup3d2dCentral("bottom")
					vehicle:DrawHUDBottom()
					jcms.draw_Tips()
				cam.End3D2D()
			end
			
			if vehicle.DrawHUDCenter then
				setup3d2dCentral("center")
					vehicle:DrawHUDCenter()
				cam.End3D2D()
			end
			
			if vehicle.DrawHUD then
				vehicle:DrawHUD()
			end
		else
			setup3d2dDiagonal(false, true)
				jcms.draw_HUDHealthbar()
				jcms.draw_DamageIndicators()
			cam.End3D2D()

			setup3d2dDiagonal(false, false)
				jcms.draw_HUDAmmo()
				jcms.draw_NotifsAmmo()
			cam.End3D2D()
			
			setup3d2dCentral("bottom")
				jcms.draw_Tips()
				jcms.draw_SentinelAnchor()
			cam.End3D2D()
		end

		setup3d2dCentral("top")
			jcms.draw_Compass()
		cam.End3D2D()

		setup3d2dDiagonal(true, true)
			jcms.draw_Information()
		cam.End3D2D()
		
		setup3d2dDiagonal(true, false)
			jcms.draw_Notifs()
		cam.End3D2D()

		setup3d2dCentral("center")
			if jcms.hud_scoreboard > 0.01 then
				jcms.draw_Scoreboard()
			end

			if jcms.hud_scoreboard < 0.99 and jcms.hud_spawnmenuAnim < 0.05 then
				if not IsValid(vehicle) then
					jcms.draw_Crosshair()
				end
				
				jcms.draw_CashHistory()
				jcms.draw_OrderMessage()
			end
		cam.End3D2D()

		local s, rtn = pcall(hook.Run, "MapSweepersDrawHUD", setup3d2dCentral, setup3d2dDiagonal)
		if not s then
			ErrorNoHalt(rtn)
		end

		jcms.spawnmenu_Update()
		jcms.spawnmenu_Draw()
	end

	function jcms.hud_SpectatorDraw()
		local tg = jcms.locPly:GetObserverTarget()

		if IsValid(tg) and tg:IsPlayer() then
			local tgclass = tg:GetNWString("jcms_class", "infantry")
			if tgclass ~= jcms.hud_myclass then
				jcms.hud_myclass = tgclass
				jcms.hud_myclassMat = Material("jcms/classes/"..tgclass..".png")
			end
			
			setup3d2dCentral("bottom")
				draw.SimpleText("#jcms.spectating", "jcms_hud_medium", 0, -256, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				local nickwidth = draw.SimpleText(tg:Nick(), "jcms_hud_huge", 32, -256, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				surface.SetDrawColor(jcms.color_dark)
				surface.SetMaterial(jcms.hud_myclassMat)
				surface.DrawTexturedRectRotated(-24 - nickwidth/2, -256+64, 96, 96, 0)
				
				local off = 4
				draw.SimpleText("#jcms.spectating", "jcms_hud_medium", 0, -256-off, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
				draw.SimpleText(tg:Nick(), "jcms_hud_huge", 32, -256-off, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				surface.SetDrawColor(jcms.color_bright)
				surface.SetMaterial(jcms.hud_myclassMat)
				surface.DrawTexturedRectRotated(-24 - nickwidth/2, -256+64-off, 96, 96, 0)
				
				local sw = jcms.scrW
				local healthWidth = math.min( sw, tg:GetMaxHealth() * 4 )
				local armorWidth = math.min( sw, tg:GetMaxArmor() * 4 )

				local healthFrac = math.Clamp(tg:Health() / tg:GetMaxHealth(), 0, 1)
				local armorFrac = math.Clamp(tg:Armor() / tg:GetMaxArmor(), 0, 1)

				surface.SetDrawColor(jcms.color_dark)
				surface.DrawRect(-healthWidth/2, -114, healthWidth, 24)
				surface.SetDrawColor(jcms.color_bright)
				jcms.hud_DrawStripedRect(-healthWidth/2, -114-off+2, healthWidth, 24-4)
				surface.DrawRect(-healthWidth/2, -114-off, healthWidth*healthFrac, 24)

				surface.SetDrawColor(jcms.color_dark_alt)
				surface.DrawRect(-armorWidth/2, -114+32, armorWidth, 24)
				surface.SetDrawColor(jcms.color_bright_alt)
				jcms.hud_DrawStripedRect(-armorWidth/2, -114-off+32+2, armorWidth, 24-4, 75)
				surface.DrawRect(-armorWidth/2, -114-off+32, armorWidth*armorFrac, 24)

				local respawns = jcms.util_GetRespawnCount()
				if respawns > 0 then
					local str = language.GetPhrase("jcms.respawns_hud"):format(respawns)
					draw.SimpleText(str, "jcms_hud_medium", 0, 0, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
					draw.SimpleText(str, "jcms_hud_medium", 0, -off, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				end
			cam.End3D2D()

			if not game.SinglePlayer() and jcms.locPly:GetNWInt("jcms_desiredteam", 0) < 2 then
				local restriction = jcms.cvar_npcteam_restrict:GetInt()
				local evacuated = jcms.vm_evacd > 0.5
				local canSwitch = (restriction == 0) or (restriction == 1 and evacuated)

				if canSwitch then
					setup3d2dDiagonal(false, true)
					local binding = input.LookupBinding("+reload", true)
					if binding then
						binding = binding:upper()
						local anim = jcms.hud_npcConfirmation
						local str = language.GetPhrase(evacuated and "#jcms.switchsides_evac" or "#jcms.switchsides")

						surface.SetDrawColor(jcms.color_dark)
						jcms.draw_Circle(0, -200, 38*1.5, 38*1.5, 5*1.5, 12*1.5)
						draw.SimpleText(binding, "jcms_hud_big", 0, -200, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						
						surface.SetDrawColor(jcms.color_bright)
						jcms.draw_Circle(0, -200-off, 38*1.5, 38*1.5, 5*1.5, 12*1.5)
						draw.SimpleText(binding, "jcms_hud_big", x, -200-off, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						
						local angleoff = math.pi/3 - anim*0.3
						surface.SetDrawColor(jcms.color_dark_alt)
						jcms.draw_Circle(0, -200, 48, 48, 8, 16, -angleoff, math.pi*2*anim-angleoff)

						surface.SetDrawColor(jcms.color_bright_alt)
						jcms.draw_Circle(0, -200-off, 48, 48, 8, 16, -angleoff, math.pi*2*anim-angleoff)

						draw.SimpleText(str, "jcms_hud_medium", 64*1.5, -200, jcms.color_dark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						draw.SimpleText(str, "jcms_hud_medium", 64*1.5, -200-off, jcms.color_bright, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

						if anim <= 0 then
							draw.SimpleText("#jcms.switchsides_tip", "jcms_hud_medium", 0, -200+48*1.5, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
							draw.SimpleText("#jcms.switchsides_tip", "jcms_hud_medium", 0, -200+48*1.5-off, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
						end
					end
					cam.End3D2D()
				end
			end

			if jcms.locPly:GetNWInt("jcms_desiredteam", 0) == 1 and jcms.vm_evacd <= 0 then
				setup3d2dDiagonal(false, false)
				local binding = input.LookupBinding("+jump", true)
				if binding then
					binding = binding:upper()
					local font = #binding >= 3 and "jcms_hud_medium" or "jcms_hud_big"
					local str = language.GetPhrase("jcms.changeclass")

					surface.SetFont(font)
					local tw = surface.GetTextSize(binding)

					surface.SetDrawColor(jcms.color_dark)
					surface.DrawRect(-tw, -200, tw, 6)
					draw.SimpleText(binding, font, 0, -200, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
					draw.SimpleText(str, "jcms_hud_small", -24, -172, jcms.color_dark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

					surface.SetDrawColor(jcms.color_bright)
					surface.DrawRect(-tw, -200-off, tw, 6)
					draw.SimpleText(binding, font, 0, -200-off, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
					draw.SimpleText(str, "jcms_hud_small", -24, -172-off, jcms.color_bright, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
					
					if jcms.locPly:KeyPressed(IN_JUMP) or jcms.locPly:KeyDown(IN_JUMP) and not jcms.modal_classChange_open then
						jcms.offgame_ModalChangeClass()
						jcms.modal_classChange_open = true
					end
				end
				cam.End3D2D()
			end
		end
		
		setup3d2dDiagonal(true, true)
			jcms.draw_Information()
		cam.End3D2D()
		
		setup3d2dDiagonal(true, false)
			jcms.draw_Notifs()
		cam.End3D2D()

		setup3d2dCentral("center")
			if jcms.hud_scoreboard > 0.01 then
				jcms.draw_Scoreboard()
			end
		cam.End3D2D()

		local f2 = math.ease.InOutCubic(jcms.hud_dead)
		cam.Start2D()
			surface.SetDrawColor(0, 0, 0, 255*f2)
			surface.DrawRect(-2,-2,jcms.scrW+4,jcms.scrH+4)
		cam.End2D()
	end

	function jcms.hud_DrawDeathBlackout()
		if jcms.hud_dead > 0 then
			local f = math.ease.InCirc(math.max(1-jcms.hud_dead, 0))
			local f2 = math.ease.InOutCubic(math.Clamp(jcms.hud_dead/5, 0, 1))
			cam.Start2D()
				render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					surface.SetDrawColor(255, 255*f, 255*f, 255*f)
					surface.DrawRect(-2,-2,jcms.scrW+4,jcms.scrH+4)
				render.OverrideBlend( false )

				surface.SetDrawColor(0, 0, 0, 255*f2)
				surface.DrawRect(-2,-2,jcms.scrW+4,jcms.scrH+4)
			cam.End2D()
		end
	end

-- // }}}

-- // Beginning Sequence {{{

	function jcms.hud_BeginningSequence()
		jcms.hud_beginsequencet = 0
		jcms.hud_beginsequenceLast = 0
		table.Empty(jcms.weapon_loadout)
		table.Empty(jcms.hud_notifs)
		table.Empty(jcms.hud_notifs_ammo)
		jcms.vm_evacd = 0
	end
	
	function jcms.hud_BeginningSequenceDraw()
		local inPod = IsValid( jcms.locPly:GetVehicle() )
		
		local t = jcms.hud_beginsequencet
		local last = jcms.hud_beginsequenceLast
		
		local matrix = Matrix()
		local function drawSeq(i, from, to, sound, func)
			local a = math.ease.OutCirc( math.Clamp(math.Remap(t, from, to, 0, 1), 0, 1) )
			if a>0 and last < i then
				last = i
				if sound then 
					surface.PlaySound(sound)
				end
			end
			
			matrix:Identity()
			matrix:Scale(Vector(a^2,a,a))
			cam.PushModelMatrix(matrix, true)
				func()
			cam.PopModelMatrix(matrix)
		end
		
		if not inPod then
			if jcms.hud_beginsequencet <= 3.5 then
				jcms.hud_beginsequencet = math.min(jcms.hud_beginsequencet + FrameTime(), 3.5)
				if jcms.hud_beginsequencet >= 3.5 then
					jcms.hud_beginsequencet = jcms.hud_beginsequenceLen + 1
				end
				
				cam.Start2D()
					if t < 0.3 then
						local f = t/0.3
						surface.SetDrawColor(255*f, 255*f, 255*f, 255)
					else
						local f = 1-math.Clamp(t-0.3, 0, 1)
						surface.SetDrawColor(255*f, 255*f*f*f, 255*f*f*f, 255*f*f)
					end
					surface.DrawRect(-4, -4, jcms.scrW + 8, jcms.scrH + 8)
					
					local clr = math.Remap(t, 0.3, 3.5, 255, 0)
					surface.SetMaterial(jcms.mat_tpeye)
					surface.SetDrawColor(clr, 0, clr, clr)
					surface.DrawTexturedRect(0, 0, jcms.scrW, jcms.scrH)
				cam.End2D()
				
				render.ClearDepth()
				cam.IgnoreZ(true)
				
				setup3d2dCentral("center")
					drawSeq(1, 0.5, 1.2, "npc/scanner/combat_scan5.wav", jcms.draw_Crosshair)
				cam.End3D2D()
				
				setup3d2dCentral("top")
					drawSeq(2, 0.7, 1.4, nil, jcms.draw_Compass)
				cam.End3D2D()
				
				setup3d2dDiagonal(false, true)
					drawSeq(3, 1.1, 1.6, "npc/scanner/scanner_scan2.wav", jcms.draw_HUDHealthbar)
				cam.End3D2D()

				setup3d2dDiagonal(false, false)
					drawSeq(4, 1.2, 1.6, nil, jcms.draw_HUDAmmo)
					drawSeq(4, 1.3, 1.7, nil, jcms.draw_NotifsAmmo)
				cam.End3D2D()
				
				local pos1, ang1 = setup3d2dCentral("center") cam.End3D2D()
				local pos2, ang2 = setup3d2dDiagonal(true, true) cam.End3D2D()
				local a = math.ease.InOutQuint( math.Clamp(math.Remap(t, 1.7, 3.5, 0, 1), 0, 1) )
				
				cam.Start3D2D(LerpVector(a,pos1,pos2), LerpAngle(a,ang1,ang2), Lerp(a, 1/20, 1/64))
					drawSeq(5, 1.7, 3.5, "npc/scanner/combat_scan3.wav", jcms.draw_Information)
				cam.End3D2D()

				setup3d2dCentral("bottom")
					drawSeq(6, 1.8, 2.4, nil, jcms.draw_Tips)
				cam.End3D2D()

				local s, rtn = pcall(hook.Run, "MapSweepersDrawHUD", setup3d2dCentral, setup3d2dDiagonal)
				if not s then
					ErrorNoHalt(rtn)
				end

				jcms.spawnmenu_Update()
				jcms.spawnmenu_Draw()
				
				cam.IgnoreZ(false)
			else
				jcms.hud_beginsequencet = jcms.hud_beginsequenceLen + 1
			end
		else
			if jcms.hud_beginsequencet <= jcms.hud_beginsequenceLen then
				jcms.hud_beginsequencet = math.min(jcms.hud_beginsequencet + FrameTime(), jcms.hud_beginsequenceLen)
				
				if jcms.hud_beginsequencet > jcms.hud_beginsequenceLen*0.8 and not IsValid(jcms.locPly:GetVehicle()) then
					jcms.hud_beginsequencet = jcms.hud_beginsequenceLen + 1
				end
				
				cam.Start2D()
					if t < 4.3 then
						surface.SetDrawColor(0, 0, 0, 255)
					else
						surface.SetDrawColor(0, 0, 0, 255 * math.max(0, 1-(t-4.3)/5 ))
					end
					surface.DrawRect(-4, -4, jcms.scrW + 8, jcms.scrH + 8)
				cam.End2D()
				
				render.ClearDepth()
				cam.IgnoreZ(true)

				if (t > 0.9 and t < 2.5) or (t < 3.4 and CurTime()%(1/4)<(1/8)) then
					setup3d2dCentral("center")
						local n1, n2 = 0.9, 1.5
						drawSeq(1, n1, n2, "npc/scanner/combat_scan5.wav", jcms.draw_Crosshair)
					cam.End3D2D()
				end
				
				setup3d2dCentral("top")
					drawSeq(2, 1.7, 2.3, "npc/scanner/scanner_alert1.wav", jcms.draw_Compass)
				cam.End3D2D()
				
				setup3d2dDiagonal(false, true)
					drawSeq(3, 2.4, 2.7, "npc/scanner/scanner_scan2.wav", jcms.draw_HUDHealthbar)
				cam.End3D2D()

				setup3d2dDiagonal(false, false)
					drawSeq(4, 2.8, 3.1, "npc/scanner/scanner_scan4.wav", jcms.draw_HUDAmmo)
				cam.End3D2D()
				
				local pos1, ang1 = setup3d2dCentral("center") cam.End3D2D()
				local pos2, ang2 = setup3d2dDiagonal(true, true) cam.End3D2D()
				local a = math.ease.InOutQuint( math.Clamp(math.Remap(t, 3.4, 5.5, 0, 1), 0, 1) )
				
				cam.Start3D2D(LerpVector(a,pos1,pos2), LerpAngle(a,ang1,ang2), Lerp(a, 1/20, 1/64))
					drawSeq(5, 3.4, 3.8, "npc/scanner/combat_scan3.wav", jcms.draw_Information)
				cam.End3D2D()
				
				if jcms.hud_beginsequencet == jcms.hud_beginsequenceLen and CurTime()%1 < 0.66 then
					if not jcms.hud_beginsequenceBlip then
						surface.PlaySound("npc/scanner/combat_scan2.wav")
						jcms.hud_beginsequenceBlip = true
					end
					
					local off = 16
					setup3d2dCentral("center")
						local w, h = 1100, 180
						surface.SetDrawColor(jcms.color_dark_alt)
						surface.DrawRect(-w/2, -h/3, w, h)
						surface.DrawRect(-128, h, 256, 256)
						render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
							surface.SetDrawColor(jcms.color_bright_alt)
							surface.DrawRect(-w/2, -h/3 - off, w, h)
							surface.DrawRect(-128, h - off, 256, 256)
						render.OverrideBlend( false )
						
						local bind = input.LookupBinding("+use")
						draw.SimpleText("#jcms.exitdroppod", "jcms_hud_big", 0, -off + h/2 - h/3, jcms.color_dark_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						draw.SimpleText("["..bind.."]", "jcms_hud_huge", 0, h + 128 - off, jcms.color_dark_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					cam.End3D2D()
				else
					jcms.hud_beginsequenceBlip = false
				end

				local s, rtn = pcall(hook.Run, "MapSweepersDrawHUD", setup3d2dCentral, setup3d2dDiagonal)
				if not s then
					ErrorNoHalt(rtn)
				end
				
				cam.IgnoreZ(false)
			end
		end
		
		jcms.hud_beginsequenceLast = last
	end

-- // }}}

-- // Ending sequence {{{

	function jcms.hud_EndingSequence(victory)
		if CustomChat then --Integration, stops drawing over the lobby.
			CustomChat:Disable()
		end

		jcms.offgame_ShowPostMission(victory)
		table.Empty(jcms.hud_locators)
		
		jcms.spawnmenu_isOpen = false
		jcms.spawnmenu_selectedOption = nil
		
		if IsValid(jcms.spawnmenu_mouseCapturePanel) then
			jcms.spawnmenu_mouseCapturePanel:Remove()
		end

		if jcms.locPly:Team() == 2 then
			if victory then
				EmitSound("music/hl2_song25_teleporter.mp3", EyePos(), -2, CHAN_AUTO, 1, 75)
			else
				EmitSound("music/hl2_song17.mp3", EyePos(), -2, CHAN_AUTO, 1, 75)
			end
		else
			if victory then
				EmitSound("music/hl2_song6.mp3", EyePos(), -2, CHAN_AUTO, 1, 75)
			else
				EmitSound("music/hl2_song28.mp3", EyePos(), -2, CHAN_AUTO, 1, 75)
			end
		end
	end

-- // }}}

-- // Order Messages (warnings) {{{

	jcms.hud_orderMessage = ""
	jcms.hud_orderMessageTime = 0
	jcms.hud_orderMessageDuration = 2
	jcms.hud_orderMessages = {
		[0] = "#jcms.ordermsg_failed",
		[1] = "#jcms.ordermsg_j",
		[2] = "#jcms.ordermsg_far",
		[3] = "#jcms.ordermsg_obstructed",
		[4] = "#jcms.ordermsg_invalidtarget",
		[5] = "#jcms.ordermsg_badplacement",
		[6] = "#jcms.ordermsg_cooldown"
	}

	function jcms.hud_ShowOrderMessage(type, format)
		jcms.hud_orderMessage = language.GetPhrase(jcms.hud_orderMessages[type] or jcms.hud_orderMessages[0]):format(format or "")
		jcms.hud_orderMessageTime = CurTime()
		surface.PlaySound("buttons/button8.wav")
	end

	function jcms.draw_OrderMessage()
		local time = CurTime() - jcms.hud_orderMessageTime
		local anim = math.max(0, math.min(1, time*10, (jcms.hud_orderMessageDuration - time)*10))
		if anim > 0 then
			surface.SetAlphaMultiplier(anim)
			local str = jcms.hud_orderMessage
			draw.SimpleText(str, "jcms_hud_medium", 0, -128 - 32*anim, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				draw.SimpleText(str, "jcms_hud_medium", 0, -128-2-32*anim, time<0.5 and jcms.color_alert or jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			render.OverrideBlend(false)
			surface.SetAlphaMultiplier(anim)
		end
	end

-- // }}}

-- // Cash Counting {{{

	jcms.hud_cashHistory = {}
	jcms.hud_cashHistoryDuration = 2.5
	jcms.hud_cashHistoryComboWindow = 1

	function jcms.hud_AddCash(count)
		local last = jcms.hud_cashHistory[#jcms.hud_cashHistory]
		if (not last) or (last.t > jcms.hud_cashHistoryComboWindow) then
			last = { t = 0, count = count, y = 0 }
			table.insert(jcms.hud_cashHistory, last)
		else
			last.t = jcms.hud_cashHistoryComboWindow/2
			last.count = last.count + count
		end
	end

	function jcms.draw_CashHistory()
		local duration = jcms.hud_cashHistoryDuration
		local baseY = 128
		for i=#jcms.hud_cashHistory, 1, -1 do
			local entry = jcms.hud_cashHistory[i]
			if entry.t > duration then
				table.remove(jcms.hud_cashHistory, i)
			else
				local addedY = baseY + entry.t*8
				surface.SetAlphaMultiplier(math.ease.OutCirc(1 - math.abs(2*entry.t/duration-1)))
				local tw = draw.SimpleText("+"..entry.count, "jcms_hud_huge", -24, entry.y+addedY, jcms.color_dark_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				surface.SetDrawColor(jcms.color_dark_alt)
				jcms.draw_IconCash("jcms_hud_medium", tw/2-24+64, entry.y+addedY+7, 8)

				render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					local off = 4
					draw.SimpleText("+"..entry.count, "jcms_hud_huge", -24, entry.y+addedY-off, jcms.color_bright_alt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					surface.SetDrawColor(jcms.color_bright_alt)
					jcms.draw_IconCash("jcms_hud_medium", tw/2-24+64, entry.y+addedY-off+7, 8)
				render.OverrideBlend(false)

				entry.y = (entry.y*4 + i*104)/5
				entry.t = entry.t + FrameTime()
			end
		end
		surface.SetAlphaMultiplier(1)
	end

-- // }}}

-- // Taking Damage {{{
	jcms.hud_damageTimeLast = -5
	
	jcms.hud_damageIndicators = {
		{ dmgType = DMG_RADIATION, icon = Material "jcms/radiation.png", time = -5, alpha = 0, negated = false },
		{ dmgType = DMG_NERVEGAS, icon = Material "jcms/biohazard.png", time = -5, alpha = 0, negated = false },
		{ dmgType = DMG_DROWN, icon = Material "jcms/oxygen.png", time = -5, alpha = 0, negated = false },
		{ dmgType = DMG_FALL, icon = Material "jcms/fracture.png", time = -5, alpha = 0, negated = false }
	}

	function jcms.hud_DispatchDamage(dmgType, negated)
		local ct = CurTime()
		if not negated then
			jcms.hud_damageTimeLast = ct
		end

		for i, indicator in ipairs(jcms.hud_damageIndicators) do
			if bit.band(dmgType, indicator.dmgType) > 0 then
				indicator.time =  ct
				indicator.negated = not not negated
			end
		end
	end

	function jcms.draw_DamageIndicators()
		local x, y = 30, -256 + 32
		
		local ct = CurTime()
		for i, indicator in ipairs(jcms.hud_damageIndicators) do
			local elapsed = ct - indicator.time

			if elapsed > 3 then
				indicator.alpha = indicator.alpha * 0.95
			else
				indicator.alpha = (indicator.alpha*6 + 1)/7
			end
			
			local f = indicator.alpha
			local size = 64
			local space = (size + 16) * (f^0.5)
			local off = 3

			if not indicator.negated and elapsed < 0.75 then
				surface.SetAlphaMultiplier(f)
				surface.SetDrawColor(jcms.color_dark)
				surface.DrawRect(x, y, size, size)
				
				render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
				surface.SetDrawColor(jcms.color_alert)
				surface.DrawRect(x + off, y - off, size, size)
				render.OverrideBlend(false)
				
				surface.SetDrawColor(jcms.color_dark)
				surface.SetMaterial(indicator.icon)
				surface.DrawTexturedRect(x + off, y - off, size, size)
			else
				surface.SetAlphaMultiplier(f)
				surface.SetMaterial(indicator.icon)
				surface.SetDrawColor(indicator.negated and jcms.color_dark_alt or jcms.color_dark)
				surface.DrawTexturedRect(x, y, size, size)
				
				render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
					surface.SetDrawColor(indicator.negated and jcms.color_bright_alt or jcms.color_bright)
					surface.DrawTexturedRect(x + off, y - off, size, size)
				render.OverrideBlend(false)
			end

			x = x + space
		end
		surface.SetAlphaMultiplier(1)
	end
-- // }}}

-- // Hook Overrides {{{

	function GM:HUDAmmoPickedUp(itemName, amount)
		jcms.hud_AddNotifAmmo( language.GetPhrase( tostring(itemName) .. "_ammo" ), tonumber(amount) or 0)
		return true
	end

	function GM:HUDWeaponPickedUp(weapon)
		jcms.hud_AddNotifAmmo( tostring(weapon.PrintName or language.GetPhrase(weapon:GetClass())), 0 )
		return true
	end

	function GM:ScoreboardShow()
		jcms.hud_scoreboardOpen = jcms.hud_beginsequencet >= 8
	end

	function GM:ScoreboardHide()
		jcms.hud_scoreboardOpen = false
	end

-- // }}}
