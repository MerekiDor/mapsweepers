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

jcms.render_matShieldRing = Material("effects/select_ring")

jcms.render_matShield = Material("models/effects/vortshield")
if jcms.render_matShield:IsError() then -- If we don't have EP2 for the vort shield, use a fallback material
	jcms.render_matShield = Material("effects/tvscreen_noise002a")
end

jcms.render_matShield_Decay = Material("models/props_combine/cit_beacon")
--models/alyx/emptool_glow
--models/effects/portalfunnel_sheet

local emt = FindMetaTable("Entity")
local nmt = FindMetaTable("NPC")

-- // NPC BubbleShield data {{{
	jcms.bubbleShield_EntList = jcms.bubbleShield_EntList or {}
	jcms.bubbleShield_EntDict = jcms.bubbleShield_EntDict or {}

	function jcms.bubbleShield_MarkShielded(ent)
		if not jcms.bubbleShield_EntDict[ent] then
			table.insert(jcms.bubbleShield_EntList, ent)
		end
		jcms.bubbleShield_EntDict[ent] = true

		--Caching
		local entTbl = ent:GetTable()
		entTbl.jcms_shieldDamageAnim = 0
		entTbl.jcms_shieldLastCount = emt.GetNWInt(ent, "jcms_shield", 0)
		entTbl.jcms_shieldColor = Color(0, 0, 0, 0)
		entTbl.jcms_shieldJCorp = ent:IsPlayer() and ent:Team() == 1 
	end

	function jcms.bubbleShield_UnmarkShielded(ent)
		if jcms.bubbleShield_EntDict[ent] then
			--Un-tracking
			table.RemoveByValue(jcms.bubbleShield_EntList, ent)
			jcms.bubbleShield_EntDict[ent] = nil

			--Un-caching
			local entTbl = ent:GetTable()
			entTbl.jcms_shieldDamageAnim = nil
			entTbl.jcms_shieldLastCount = nil
			entTbl.jcms_shieldColor = nil
			entTbl.jcms_shieldJCorp = nil
		end
	end
-- // }}}

-- // NPC SweeperShield data {{{
	jcms.sweeperShield_EntList = jcms.bubbleShield_EntList or {}
	jcms.sweeperShield_EntDict = jcms.sweeperShield_EntDict or {}

	--Neither of these should ever change without additional MarkShielded calls, so we can store them to save perf.
	jcms.sweeperShield_EntColourCache = jcms.sweeperShield_EntColourCache or {}
	jcms.sweeperShield_EntMaxCache = jcms.sweeperShield_EntMaxCache or {}
	
	function jcms.sweeperShield_MarkShielded(ent, maxOverride, colOverride) --Overrides (so that we don't always rely on unreliable NWVar networking, especially when initially created).
		if not jcms.sweeperShield_EntDict[ent] then --No double entries
			table.insert(jcms.sweeperShield_EntList, ent)
		end

		--Caching
		local r, g, b = jcms.util_ColorFromIntegerUnpacked( colOverride or emt.GetNWInt(ent, "jcms_sweeperShield_colour", 255) )
		jcms.sweeperShield_EntColourCache[ent] = {r,g,b}
		jcms.sweeperShield_EntMaxCache[ent] = maxOverride or emt.GetNWInt(ent, "jcms_sweeperShield_max", -1)
		jcms.sweeperShield_EntDict[ent] = true
	end

	function jcms.sweeperShield_UnmarkShielded(ent)
		if jcms.sweeperShield_EntDict[ent] then
			--Un-tracking
			table.RemoveByValue(jcms.sweeperShield_EntList, ent)
			jcms.sweeperShield_EntDict[ent] = nil

			--Un-caching
			jcms.sweeperShield_EntColourCache[ent] = nil
			jcms.sweeperShield_EntMaxCache[ent] = nil
		end
	end
-- // }}}


-- // Tracking {{{
	--NOTE: These hooks only handle entities entering/exiting the PVS! Within PVS entities are marked via net messages.

	--Check shields when we see an entity for the first time.
	hook.Add("NetworkEntityCreated", "jcms_shieldTtracker", function( ent )
		if emt.GetNWInt(ent, "jcms_sweeperShield_max", -1) > 0 then
			jcms.sweeperShield_MarkShielded(ent)
		end

		if emt.GetNWInt(ent, "jcms_shield", 0) > 0 then 
			jcms.bubbleShield_MarkShielded(ent)
		end
	end)

	hook.Add("EntityRemoved", "jcms_shieldTtracker", function( ent, isFullUpdate )
		--Shields can potentially be removed by decaying to 0 or being manually deleted, but I can't be bothered to track that because the performance gains for excluding it would be minimal
		jcms.sweeperShield_UnmarkShielded(ent) --(Also checks if we have a shield in the first-place)
		jcms.bubbleShield_UnmarkShielded(ent) --(Ditto)
	end)
-- // }}}

--TODO: There are too many different variants packed into this one function. We realistically shouldn't be checking if every entity on the map is the local player,
--that's very wasteful of performance. Ideally this should be split into a generalised function and several variants passing different data into that, but duplicates would still be more performant (albeit messy). 
local function drawBubbleShield(ent, i) --Renamed from bulletshield, as the old one was a bit confusing.
	local shield = emt.GetNWInt(ent, "jcms_shield", 0)
	if shield <= 0 then return end

	--Re-used values
	local entTbl = ent:GetTable()
	local pos = ent:WorldSpaceCenter()
	local rad = ent:BoundingRadius() --TODO: Maybe cache this
	local jcorp = entTbl.jcms_shieldJCorp
	local color = entTbl.jcms_shieldColor
	
	local time = jcorp and CurTime()*(shield+2) or CurTime()*8
	local imInside = ent == jcms.locPly and not ent:ShouldDrawLocalPlayer()


	--Shield damage flash animation
	if entTbl.jcms_shieldLastCount ~= shield then
		if entTbl.jcms_shieldLastCount or 0 > shield then
			entTbl.jcms_shieldDamageAnim = 1
		end
		entTbl.jcms_shieldLastCount = shield
	else
		entTbl.jcms_shieldDamageAnim = math.max(0, entTbl.jcms_shieldDamageAnim - FrameTime() * (imInside and 1 or 4))
	end
	local damageAnim = entTbl.jcms_shieldDamageAnim --Not changef beyond this point

	--Local Player shield render
	if imInside then
		rad = -rad
		
		if damageAnim <= 0.01 then
			return
		end
	end

	-- // Drawing {{{
		local osc = jcorp and (time+0.6)%2-1 or math.sin(time+i)
		local size = rad*2.4*(1-osc^2) + damageAnim * 50
		render.SetColorMaterial()

		-- // Shield Bubble {{{
			if jcorp then
				local alpha = shield*16
				color:SetUnpacked(24 + 100*damageAnim, shield*32 + 200*damageAnim, 230, alpha+150*damageAnim)
			else
				local alpha = shield * 8
				color:SetUnpacked(255, 200, 100*damageAnim, alpha+150*damageAnim)
			end
			if imInside then
				color.a = color.a*damageAnim*0.2
			end
			render.DrawSphere(pos, rad - math.random()*4, 6, 6, color )
		-- // }}}

		-- // Ring 1 {{{
			local vUp = jcms.vectorUp
			render.SetMaterial(jcms.render_matShieldRing)
			if jcorp then
				color:SetUnpacked(64+damageAnim*255, math.Remap(shield, 1, 3, 164, 0), 255, 255)
			else
				color:SetUnpacked(255, 255, damageAnim*255, 255)
			end
			if imInside then
				color.a = color.a*damageAnim
			end
			render.DrawQuadEasy(pos + osc*rad*1.1*vUp, vUp, size, size, color, 0)
		-- // }}}
		
		-- // Ring 2 {{{
			if jcorp then
				color:SetUnpacked(255, 0, shield*8+175*damageAnim, 150)
			else
				color:SetUnpacked(255, 140+150*damageAnim, 175*damageAnim, 150)
			end
			if imInside then
				color.a = color.a*damageAnim
			end
			osc = jcorp and time%2-1 or math.sin(time+i+0.6)
			size = rad*2.7*(1-osc^2)
			render.DrawQuadEasy(pos + osc*rad*1.2*vUp, vUp, size, size, color, 0)
		-- // }}}
	-- // }}
end

local function drawSweeperShield(ent)
	local swpShield = emt.GetNWInt(ent, "jcms_sweeperShield", -1)
	if swpShield <= 0 then return end

	local maxShield = jcms.sweeperShield_EntMaxCache[ent] or 0 --TODO: Why does this very briefly get nilled sometimes?
	local rgb = jcms.sweeperShield_EntColourCache[ent] or {0,0,0} --r,g,b as a 3 value table
	
	local isDecayShield = swpShield > maxShield
	local alpha = (isDecayShield and 1) or math.Clamp(swpShield/maxShield, 0, 1) --TODO: Why did I do (isDecayShield and 1) again? Double check if that's needed (clamp seems like it should handle it?)
	local mFac = alpha/200 --Alpha scaled 0-1(ish)

	--Draw the model
	render.SetColorModulation(rgb[1] * mFac, rgb[2] * mFac, rgb[3] * mFac)
	render.MaterialOverride(isDecayShield and jcms.render_matShield_Decay or jcms.render_matShield)
		emt.DrawModel(ent)
	--colourmod and matoverride are reset after the loop!
end


hook.Add("PostDrawTranslucentRenderables", "jcms_BulletShields", function(bDrawingDepth, bDrawingSkybox, isDraw3DSkybox)
	if bDrawingDepth or bDrawingSkybox or isDraw3DSkybox or render.GetRenderTarget() then return end --All of these cases are unnecessary (render.GetRenderTarget() checks if we're in a reflection).

	--Render bubble shields
	render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
		for i, ent in ipairs(jcms.bubbleShield_EntList) do 
			if not emt.GetNoDraw(ent) and not emt.IsDormant(ent) then
				drawBubbleShield(ent, i)
			end
		end
	render.OverrideBlend( false )

	--Render Sweeper Shields
	for i, ent in ipairs(jcms.sweeperShield_EntList) do
		if not emt.GetNoDraw(ent) and not emt.IsDormant(ent) then
			drawSweeperShield(ent)
		end
	end
	render.MaterialOverride()
	render.SetColorModulation(1, 1, 1)
end)