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
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "RGG Mainframe"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.ShieldRadius = 2400
ENT.ChargePerSecond = 3
ENT.ChargeInterval = 0.5

ENT.JammingRadius = 1500


ENT.BombardmentInterval = 30
ENT.BombardmentIntervalRGG = 60
ENT.SupplyDropInterval = 90
ENT.JammerSwitchInterval = 120

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "ShieldJCorp")
end

if SERVER then 
	function ENT:Initialize()
		self:SetModel("models/jcms/rgg_mainframe.mdl")
		self:PhysicsInitStatic(SOLID_VPHYSICS)
		self:SetSubMaterial(3, "phoenix_storms/scrnspace")
		
		self.bombardmentActive = false
		self.nextBombardment = CurTime() + 50
		self.nextSupplyDrop = CurTime() + 90
		self.nextJammerSwitch = CurTime() + 120
	
		self.jammers = {{}, {}} --Set by mainframe mission gen
		self.jammerIndex = 1
		self.supplyDrops = {}
	end

	function ENT:Think()
		-- Shield charging behaviour
		if self:GetShieldJCorp() then 
			for i, ply in ipairs(jcms.GetAliveSweepers()) do
				if (ply:Armor() < ply:GetMaxArmor()) and (ply:WorldSpaceCenter():DistToSqr(self:WorldSpaceCenter()) <= self.ShieldRadius^2) then
					self:ChargeShield(ply)
				end
			end
		else
			if self.nextJammerSwitch < CurTime() then 
				self.nextJammerSwitch = CurTime() + self.JammerSwitchInterval

				self.jammerIndex = (self.jammerIndex % #self.jammers) + 1

				for i, subTbl in ipairs(self.jammers) do 
					local relativeIndex = (i - self.jammerIndex + #self.jammers) % #self.jammers 
					for _, jammer in ipairs(subTbl) do 
						jammer:SetIsActive(false)
						jammer:SetNextStateSwitch(CurTime() + (relativeIndex * self.JammerSwitchInterval))
					end
				end

				for i, jammer in ipairs(self.jammers[self.jammerIndex]) do 
					local timerName = "jcms_"..tostring(jammer).."beep"
					local function ping()
						if not IsValid(jammer) then
							timer.Remove(timerName)
							return
						end
				
						jammer:EmitSound("buttons/button3.wav", 100, 80)
					end
	
					timer.Create(timerName, 1, 3, ping) --3s

					timer.Simple(4, function()
						if not IsValid(jammer) or self:GetShieldJCorp() then return end
						jammer:SetIsActive(true)
						jammer:SetNextStateSwitch(self.nextJammerSwitch)
					end)
				end
			end
		end

		-- // {{{ Supply drops
			for i=#self.supplyDrops, 1, -1 do
				local ent = self.supplyDrops[i] 
				if not IsValid(ent) then 
					table.remove(self.supplyDrops, i)
				end
			end
			if self.nextSupplyDrop < CurTime() and #self.supplyDrops < 10 then
				local largestZone = jcms.mapgen_MainZone()
				local targetArea = largestZone[math.random(#largestZone)] --TODO: Would be better weighted
				local pos = targetArea:GetCenter()

				local classTypes = {
					["jcms_tank"] = 0.01,
					["jcms_restock_ammo"] = 1,
					["jcms_restock_heal"] = 1,
				}
				local classChoice = jcms.util_ChooseByWeight(classTypes)

				--Awful.
				local spawnedEnt
				if classChoice == "jcms_tank" then 
					local spawnedEnt, flare = jcms.spawnmenu_Airdrop(pos, "jcms_tank", 10, "#jcms.tank", Color(143, 67, 229))
				elseif classChoice == "jcms_restock_ammo" then
					local crate, flare = jcms.spawnmenu_Airdrop(pos, "jcms_restock", 10, "#jcms.restock", Color(143, 67, 229))
					crate:SetAmmoCashInside( 300 )
					crate:SetHealthInside( 0 )
					crate:SetLocalAngularVelocity( AngleRand(48, 128) )
					crate:SetMaterial("models/jcms/".."jcorp".."_crate_ammo")
					spawnedEnt = crate
				elseif classChoice == "jcms_restock_heal" then 
					local crate, flare = jcms.spawnmenu_Airdrop(pos, "jcms_restock", 10, "#jcms.firstaid", Color(143, 67, 229))
					crate:SetAmmoCashInside( 0 )
					crate:SetHealthInside( 100 )
					crate:SetLocalAngularVelocity( AngleRand(48, 128) )
					crate:SetMaterial("models/jcms/".."jcorp".."_crate_heal")
					spawnedEnt = crate
				end

				table.insert(self.supplyDrops, spawnedEnt)
				self.nextSupplyDrop = CurTime() + self.SupplyDropInterval
			end
		-- // }}}

		-- // Death rays {{{
			if (self.nextBombardment < CurTime()) and not (jcms.director and jcms.director.debug) then
				for i=1, not self.bombardmentActive and 6 or 3, 1 do
					local targetArea = jcms.mapgen_UseRandomArea() --Convenient way of targeting some-place valid.

					local beam = ents.Create("jcms_deathraycontroller")
					local rad = 32
					local prep = 4.5

					beam.Speed = 185
					beam.beamRadius = rad
					beam:SetPos(targetArea:GetCenter())
					beam:Spawn()
					beam.beamPrepTime = prep
					beam.beamLifeTime = not self.bombardmentActive and 17.5 or 20
					beam.jcms_owner = self
					
					beam.deathRay.DPS = 60
					beam.deathRay.DPS_DIRECT = 60
					beam.deathRay:SetBeamRadius(rad)
					beam.deathRay:SetBeamPrepTime(prep)
					beam.deathRay.jcms_owner = self
					beam.deathRay:SetBeamLifeTime(20)

					if not self.bombardmentActive then 
						beam.deathRay:SetBeamColour( Vector(0.7, 0.1, 1) )
						beam.IsNPCTeam = true
					else
						if jcms.util_IsPVP() then
							beam.deathRay:SetBeamColour(Vector(0, 1, 1))
						else
							beam.deathRay:SetBeamColour( Vector(1, 0.1, 0.1) )
						end
					end

					beam.IsIdleUntilActive = true --Don't track until we're actually fully formed.
				end

				self.nextBombardment = CurTime() + (not self.bombardmentActive and self.BombardmentIntervalRGG or self.BombardmentInterval)
			end
		-- // }}}

		self:NextThink(CurTime() + self.ChargeInterval)
		return true
	end

	function ENT:ChargeShield(ent)
		if ent:IsPlayer() then
			local plyArmour = ent:Armor()
			local chargeAmount = math.Clamp(ent:GetMaxArmor() - plyArmour, 0, self.ChargePerSecond*self.ChargeInterval)

			ent:SetArmor(plyArmour + chargeAmount)
		else
			local armour = ent:GetNWInt("jcms_sweeperShield", 0)
			local maxArmour = ent:GetNWInt("jcms_sweeperShield_max", 0)
			local chargeAmount = math.Clamp(maxArmour - armour, 0, self.ChargePerSecond*self.ChargeInterval * 3)
			ent:SetNWInt("jcms_sweeperShield", armour + chargeAmount)
		end
	end
end

if CLIENT then
	local mat_rggscreensaver = Material("jcms/rggscreensaver.png")
	mat_rggscreensaver:SetInt("$flags", bit.bor( mat_rggscreensaver:GetInt( "$flags" ), 32768 ))

	local mat_screenspace = Material("models/screenspace")

	ENT.ScreenSubmatIDs = { 3, 5, 6 }

	ENT.ScreenSubmatNames_RGG = {}
	ENT.ScreenRT_RGG = {}
	ENT.ScreenRTMats_RGG = {}

	ENT.ScreenSubmatNames_JCorp = {}
	ENT.ScreenRT_JCorp = {}
	ENT.ScreenRTMats_JCorp = {}
	
	for i=1, 3 do
		ENT.ScreenSubmatNames_RGG[i] = "!jcms_mainframescreen_rgg" .. i
		ENT.ScreenRT_RGG[i] = GetRenderTarget("jcms_mainframescreen_rgg"..i.."_rt", 300, 200)
		ENT.ScreenRTMats_RGG[i] = CreateMaterial("jcms_mainframescreen_rgg" .. i, "VertexLitGeneric", {
			["$basetexture"] = ENT.ScreenRT_RGG[i]:GetName(),
			["$pointsamplemagfilter"] = 1,
			["$selfillum"] = 1
		})

		ENT.ScreenSubmatNames_JCorp[i] = "!jcms_mainframescreen_jcorp" .. i
		ENT.ScreenRT_JCorp[i] = GetRenderTarget("jcms_mainframescreen_jcorp"..i.."_rt", 300, 200)
		ENT.ScreenRTMats_JCorp[i] = CreateMaterial("jcms_mainframescreen_jcorp" .. i, "VertexLitGeneric", {
			["$basetexture"] = ENT.ScreenRT_JCorp[i]:GetName(),
			["$pointsamplemagfilter"] = 1,
			["$selfillum"] = 1
		})
	end
	
	function ENT:Initialize()
		self.chargeEffectX = 0
		self:SetRenderBounds(jcms.vectorOrigin, jcms.vectorOrigin, Vector(self.JammingRadius, self.JammingRadius, self.JammingRadius) )
	end

	function ENT:OnRemove()
		if self.soundCharge then
			self.soundCharge:Stop()
		end
	end

	function ENT:RenderScreens(red1, red2, red3)
		-- RGG Screen 1: "Idiot Gameplay" {{{
		if not red1 then
			render.PushRenderTarget(self.ScreenRT_RGG[1])
			cam.Start2D()
				surface.SetDrawColor(255, 0, 255)
				surface.DrawRect(0, 0, 300, 200)
				local flags = mat_screenspace:GetInt("$flags")
				mat_screenspace:SetInt("$flags", bit.bor(flags, 32768))
				surface.SetMaterial(mat_screenspace)
				surface.DrawTexturedRect(4, 4, 300-8, 200 - 8)
				mat_screenspace:SetInt("$flags", flags)
				draw.SimpleText("#jcms.mainframe_idiotpov", "jcms_medium", 16, 16, surface.GetDrawColor())
			cam.End2D()
			render.PopRenderTarget()
		end
		-- }}}

		-- RGG Screen 2: Screensaver {{{
		if not red2 then
			if not self.Screen_screensaverData then
				self.Screen_screensaverData = { x = 300/2 - 16, y = 200/2 - 12, vx = math.random()<0.5 and -8 or 8, vy = math.random()<0.5 and -6 or 6 }
			else
				local ssd = self.Screen_screensaverData
				ssd.x = ssd.x + ssd.vx
				ssd.y = ssd.y + ssd.vy

				local hits = 0
				if (ssd.x + 32 >= 300) or (ssd.x <= 0) then
					ssd.vx = -ssd.vx
					ssd.x = math.Clamp(ssd.x, 0, 300 - 32)
					hits = hits + 1
				end

				if (ssd.y + 24 >= 200) or (ssd.y <= 0) then
					ssd.vy = -ssd.vy
					ssd.y = math.Clamp(ssd.y, 0, 200 - 24)
					hits = hits + 1
				end

				render.PushRenderTarget(self.ScreenRT_RGG[2])
				cam.Start2D()
				draw.NoTexture()
				if hits == 2 then
					surface.SetDrawColor(0, 255, 0, 84)
					surface.DrawRect(0, 0, 300, 200)
					surface.SetDrawColor(0, 255, 0)
					surface.SetMaterial(mat_rggscreensaver)
					surface.DrawTexturedRectUV(self.Screen_screensaverData.x, self.Screen_screensaverData.y, 32, 24, 0, 0, 1, 1)
				else
					surface.SetDrawColor(24, 0, 90, 84)
					surface.DrawRect(0, 0, 300, 200)
					surface.SetDrawColor(255, 0, 255)
					surface.DrawOutlinedRect(2, 2, 300-4, 200-4, 1)
					
					if hits > 0 then
						draw.SimpleText("#jcms.terminal_gambling"..math.random(1,4), "jcms_big", 300/2, 200/2, Color(255, 0, 255, 64), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end

					surface.SetMaterial(mat_rggscreensaver)
					surface.DrawTexturedRectUV(self.Screen_screensaverData.x, self.Screen_screensaverData.y, 32, 24, 0, 0, 1, 1)
				end
				cam.End2D()
				render.PopRenderTarget()
			end
		end
		-- }}}

		-- RGG Screen 3: Slot Machine {{{
		if not red3 then
			if not self.Screen_slotsData then
				self.Screen_slotsData = { cycle = 0, n1 = math.random(0, 9), n2 = math.random(0, 9), n3 = math.random(0, 9) }
			end
			
			self.Screen_slotsData.cycle = (self.Screen_slotsData.cycle + 1)%16
			local shaking = self.Screen_slotsData.cycle < 8
			if shaking then
				self.Screen_slotsData.n1 = math.random(0, 9)
				self.Screen_slotsData.n2 = math.random(0, 9)
				self.Screen_slotsData.n3 = math.random(0, 9)
			end
			
			local c = (self.Screen_slotsData.n1 == self.Screen_slotsData.n2 and self.Screen_slotsData.n2 == self.Screen_slotsData.n3) and Color(0, 255, 0) or Color(255, 0, 255)
			
			render.PushRenderTarget(self.ScreenRT_RGG[3])
			cam.Start2D()
				surface.SetDrawColor(c.r/7, c.g/8, c.b/4, shaking and 150 or 200)
				surface.DrawRect(0, 0, 300, 200)

				surface.SetDrawColor(c.r/2, c.g/3, c.b/1.5)
				local sh1 = shaking and math.Rand(-4, 4) or 0
				local sh2 = shaking and math.Rand(-4, 4) or 0
				local sh3 = shaking and math.Rand(-4, 4) or 0

				surface.DrawOutlinedRect(300/2-32+sh1, 200/2-48+16-sh2, 64, 96, 3)
				surface.DrawOutlinedRect(300/2-32-64-8+6+sh2, 200/2-48+16+8-sh3, 58, 80, 3)
				surface.DrawOutlinedRect(300/2-32+64+8+sh3, 200/2-48+16+8-sh1, 58, 80, 3)
				
				draw.SimpleText(self.Screen_slotsData.n2, "jcms_hud_medium", 300/2+sh1, 200/2+16-sh2, c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(self.Screen_slotsData.n1, "jcms_hud_medium", 300/2-68+sh2, 200/2+16-sh3, c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(self.Screen_slotsData.n3, "jcms_hud_medium", 300/2+68+sh3, 200/2+16-sh1, c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			
				surface.SetDrawColor(c)
				surface.DrawOutlinedRect(2, 2, 300-4, 200-4, 1)
				surface.DrawRect(300/2-96, 200/2-48-16, 96*2, 16)
			cam.End2D()
			render.PopRenderTarget()
		end
		-- }}}

		if jcms.util_IsPVP() then
			local conds = { red1, red2, red3 }
			for i=1, 3 do
				if not conds[i] then continue end
				render.PushRenderTarget(self.ScreenRT_JCorp[i])
				cam.Start2D()
					surface.SetDrawColor(14, 14, 14)
					surface.DrawRect(0, 0, 300, 200)
				cam.End2D()
				render.PopRenderTarget()
			end
		else
			-- JCorp Screen 1: J Corp {{{
			if red1 then
				render.PushRenderTarget(self.ScreenRT_JCorp[1])
				cam.Start2D()
					draw.NoTexture()
					local sin = (math.sin(CurTime())+1)/2
					surface.SetDrawColor(sin*255, 0, 0, 180)
					surface.DrawRect(0, 0, 300, 200)
					local c2 = Color((1-sin)*255, 0, 0)
					draw.SimpleText(string.rep("J ", 16), "jcms_hud_huge", 300/2 - 256*sin, 200/2, c2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					surface.SetDrawColor(c2)
					surface.DrawRect(0, 8, 300, 8)
					surface.DrawRect(0, 200-16, 300, 8)
				cam.End2D()
				render.PopRenderTarget()
			end
			-- }}}

			-- JCorp Screen 2: Digits {{{
			if red2 then
				render.PushRenderTarget(self.ScreenRT_JCorp[2])
				cam.Start2D()
					draw.NoTexture()
					surface.SetDrawColor(32, 0, 0, 128)
					surface.DrawRect(0, 0, 300, 200)
					
					surface.SetDrawColor(255, 0, 0)
					local pad = math.floor( (math.sin(CurTime()*4)+1)*4+2 )
					surface.DrawOutlinedRect(pad, pad, 300-pad*2, 200-pad*2, 1)

					surface.SetFont("jcms_big")
					surface.SetTextColor(255, 0, 0, 170)
					local time = CurTime()
					for x=1, 9 do
						for y = 1, 6 do
							local rn = math.floor( (time+x/4+y/6)%2 )
							surface.SetTextPos(x*30-24+15, y*28-20+6)
							surface.DrawText(rn)
						end
					end
				cam.End2D()
				render.PopRenderTarget()
			end
			-- }}}

			-- JCorp Screen 3: BusinessOS {{{
			if red3 then
				render.PushRenderTarget(self.ScreenRT_JCorp[3])
				cam.Start2D()
					surface.SetDrawColor(255, 0, 0)
					render.DepthRange(0, 0)
					jcms.hud_DrawNoiseRect(0, 0, 300, 200, 16)
					jcms.hud_DrawStripedRect(0, 8, 300, 4, 32, CurTime()*32)
					jcms.hud_DrawStripedRect(0, 200-8-4, 300, 4, 32, CurTime()*-32)
					render.DepthRange(0, 1)

					draw.SimpleText("#jcms.terminal_mainframe_hacked", "jcms_medium", 300/2, 16, Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
					draw.SimpleText("v.523", "jcms_hud_big", 300/2, 200/2, Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				cam.End2D()
				render.PopRenderTarget()
			end
			-- }}}
		end
	end

	function ENT:UpdateScreens()
		local objs = jcms.objectives
		
		local doRender = FrameNumber()%5==0
		local reds

		if doRender then
			reds = {}
		end

		for i, submatId in ipairs(self.ScreenSubmatIDs) do
			local isRed = objs and (objs[i] and objs[i].type == "mainframeterminals"..i and objs[i].completed) or (objs[1] and objs[1].type:sub(1, 4) == "evac")

			if doRender then
				reds[i] = isRed
			end

			if isRed then
				self:SetSubMaterial(submatId, self.ScreenSubmatNames_JCorp[i])
			else
				self:SetSubMaterial(submatId, self.ScreenSubmatNames_RGG[i])
			end
		end

		if doRender then
			self:RenderScreens(unpack(reds))
		end
	end

	function ENT:Think()
		local selfTbl = self:GetTable()

		-- // FX {{{
			if FrameTime() > 0 then
				selfTbl.chargeEffectX = (selfTbl.chargeEffectX + 1) % 3

				if selfTbl.chargeEffectX == 0 then
					selfTbl.isCharging = false

					local foundEnts = {}
					if self:GetShieldJCorp() then 
						for i, ply in ipairs(jcms.GetAliveSweepers()) do
							if ply:Health() > 0 and (ply:Armor() < ply:GetMaxArmor()) and (ply:WorldSpaceCenter():DistToSqr(self:WorldSpaceCenter()) <= selfTbl.ShieldRadius^2) then
								table.insert(foundEnts, ply)
							end
						end
					else
						for i, ent in ipairs(ents.FindInSphere(self:WorldSpaceCenter(), selfTbl.ShieldRadius)) do 
							if ent:IsNPC() then 
								local maxShield = ent:GetNWInt("jcms_sweeperShield_max", -1)
								if not(maxShield == -1) and (ent:GetNWInt("jcms_sweeperShield", -1) < maxShield) then
									table.insert(foundEnts, ent)
								end
							end
						end
					end

					for i, ent in ipairs(foundEnts) do 
						selfTbl.isCharging = true
						local ed = EffectData()
						ed:SetFlags(0)
						ed:SetOrigin(self:WorldSpaceCenter())
						ed:SetEntity(ent)
						util.Effect("jcms_chargebeam", ed)
					end
				end
			end
		-- // }}}
		
		-- // Audio {{{
			if selfTbl.soundCharge and not selfTbl.soundCharge:IsPlaying() then
				selfTbl.soundCharge:Stop()
				selfTbl.soundCharge = nil
			end

			if not selfTbl.soundCharge and selfTbl.isCharging then
				selfTbl.soundCharge = CreateSound(self, "ambient/machines/combine_shield_touch_loop1.wav")
			end

			if selfTbl.soundCharge then
				if selfTbl.isCharging then
					local chargePitch = 84
					
					if not selfTbl.soundCharge:IsPlaying() then
						selfTbl.soundCharge:PlayEx(1, chargePitch)
					else
						selfTbl.soundCharge:ChangePitch(chargePitch)
					end
				else
					if selfTbl.soundCharge:IsPlaying() and selfTbl.soundCharge:GetVolume() <= 0 then
						selfTbl.soundCharge:Stop()
					else
						selfTbl.soundCharge:ChangeVolume(0, 0.25)
						selfTbl.soundCharge:ChangePitch(1, 0.25)
					end
				end
			end
		-- // }}}

		-- // Screens {{{
			self:UpdateScreens()
		-- // }}}
	end
end