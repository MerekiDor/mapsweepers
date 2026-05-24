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

-- The following code adds compatibility with various 3rd-party addons (with Steam Workshop links attached) to Map Sweepers.
hook.Add("InitPostEntity", "jcms_addonCompatibility", function()
	
	-- // DOOM Dynamic Music System {{{
		-- https://steamcommunity.com/sharedfiles/filedetails/?id=3371358666
		if MUSIC_SYSTEM then
			jcms.cvar_doomdms_randomize = CreateClientConVar("doom_music_mapsweepers_randomize_song", "1", true, false, "If set to 1, the track will automatically get randomized at the start of each mission")

			local function chooseRandomSong()
				if not jcms.cvar_doomdms_randomize:GetBool() then
					return
				end

				local me = LocalPlayer()
				if IsValid(me) and type(me.DOOM_PackTable) == "table" then
					local newSongName

					local chosen = me.DOOM_PackTable[ math.random(1, #me.DOOM_PackTable) ]
					if type(chosen) == "table" and type(chosen[1]) == "string" then
						newSongName = chosen[1]
					end					

					if newSongName then
						jcms.printf("DOOM Dynamic Music System: changed song to '%s'", newSongName)
						RunConsoleCommand("doom_music_name", newSongName)
					end
				end
			end

			hook.Add("PostCleanupMap", "jcms_DOOMDMSChooseRandomSong", chooseRandomSong)
			chooseRandomSong()
		end
	-- // }}}

	-- ARC9 {{{
		-- https://steamcommunity.com/sharedfiles/filedetails/?id=2910505837
		-- Gets rid of that invasive & unnecessary HUD. Also put in a timer just to be sure.
		hook.Remove("HUDPaint", "ARC9_DrawHud")
		timer.Simple(3, function()
			hook.Remove("HUDPaint", "ARC9_DrawHud")
		end)
	-- }}}

	-- TACRP {{{
		-- https://steamcommunity.com/sharedfiles/filedetails/?id=2588031232&searchtext=tacrp
		-- Ditto, disables hud
		timer.Create("jcms_TacRPHudRemove", 2, 10, function()
			if TacRP then
				hook.Add("MapSweepersDrawHUD", "jcms_TacRPHUD", function(setup3d2dCentral, setup3d2dDiagonal)
					local w = jcms.locPly:GetActiveWeapon()

					if w.ArcticTacRP then
						w.DrawHUDBackground = function(w) 
							w:DoScope()
							
    						w:DrawLockOnHUD()
							w:DrawCustomizeHUD()
							w:DrawGrenadeHUD()
						end
					end
				end)
			end
		end)
	-- }}}

	-- ArcCW {{{
		-- https://steamcommunity.com/sharedfiles/filedetails/?id=2131057232
		-- Replaces Firemode HUD
		-- GetFiremodeBars, --GetFiremodeName
		timer.Simple(1, function()
			if ArcCW then
				hook.Add("MapSweepersDrawHUD", "jcms_ArcCWHud", function(setup3d2dCentral, setup3d2dDiagonal)
					local w = jcms.locPly:GetActiveWeapon()

					if w.ArcCW then
						w.DrawHUD = nil

						local name = w:GetFiremodeName()
						local bars = w:GetFiremodeBars()
						setup3d2dCentral("bottom")
							surface.SetDrawColor(jcms.color_dark)
							draw.SimpleText(name, "jcms_hud_big", 0, -72, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
							for i=1, #bars do
								surface.DrawRect((i-1-#bars/2)*72, -72, 64, 24)
							end

							render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
								surface.SetDrawColor(jcms.color_bright)
								draw.SimpleText(name, "jcms_hud_big", 0, -72-8, jcms.color_bright, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
								for i=1, #bars do
									if bars:sub(i, i) == "-" then
										surface.DrawRect((i-1-#bars/2)*72, -80, 64, 24)
									else
										surface.DrawOutlinedRect((i-1-#bars/2)*72, -80, 64, 24, 6)
									end
								end
							render.OverrideBlend(false)
						cam.End3D2D()
					end
				end)
			end
		end)
	-- }}}
end)