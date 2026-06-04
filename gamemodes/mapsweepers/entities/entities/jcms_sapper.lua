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

ENT.Type = "ai"
ENT.Base = "base_anim"
ENT.PrintName = "J Corp. Device"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

if SERVER then
	jcms.devices = {
		autohacker = {
			setup = function(self, ent, boosted)
				self:SetTimeToComplete( CurTime() + (boosted and 80 or 90) )
			end,
			
			think = function(self, ent)
				local completeTime = self:GetTimeToComplete()
				if IsValid(ent) and ent:GetNWBool("jcms_terminal_locked") and completeTime and not self:GetHackedByRebels() then
					local effectdata = EffectData()
					effectdata:SetOrigin(self:GetPos())
					effectdata:SetMagnitude(2)
					effectdata:SetNormal(vector_up)
					effectdata:SetScale(5)
					effectdata:SetEntity(self)
					util.Effect("TeslaHitboxes", effectdata)
					
					if CurTime() >= completeTime then
						jcms.terminal_Unlock(ent, self, true)
						return true
					end
				else
					return true
				end
			end
		},
		
		sapper = {
			setup = function(self, ent, boosted)
				self:SetModel("models/props_combine/combine_smallmonitor001.mdl")
				self:SetMaxHealth(25)
				self:SetHealth(self:GetMaxHealth())
			end,
			
			think = function(self, ent)
				if IsValid(ent) and ent:Health() > 0 then

					ent.nextEffect = ent.nextEffect or CurTime()
					
					if ent.nextEffect < CurTime() then
						local selfPos = self:GetPos()

						local effectdata = EffectData()
						effectdata:SetOrigin(selfPos)
						effectdata:SetMagnitude(2)
						effectdata:SetNormal(vector_up)
						effectdata:SetScale(5)
						effectdata:SetEntity(self)
						util.Effect("TeslaHitboxes", effectdata)

						ent:EmitSound("NPC_RollerMine.JoltVehicle")

						local dmgInfo = DamageInfo()
						dmgInfo:SetAttacker(self)
						dmgInfo:SetInflictor(self)
						dmgInfo:SetDamage(20)
						dmgInfo:SetDamageType( DMG_SHOCK )
						dmgInfo:SetReportedPosition(selfPos)
						dmgInfo:SetDamagePosition(selfPos)

						ent:TakeDamageInfo(dmgInfo)

						ent.nextEffect = CurTime() + 1
					end
				else
					--NPC_RollerMine.Hurt
					return true 
				end
			end
		},

		locator = {
			setup = function(self, ent)
				self:SetModel("models/maxofs2d/hover_plate.mdl")
				self:SetMaxHealth(25)
				self:SetHealth(self:GetMaxHealth())

				local adjustedAng = self:GetAngles()
				adjustedAng:RotateAroundAxis(adjustedAng:Right(), -89)
				self:SetAngles(adjustedAng)

				self:AddFlags(FL_NOTARGET) --the new model causes enemies to get stuck unable to hit us.

				self:SetTimeToComplete( CurTime() + 10 )
			end,

			think = function(self, ent)
				if not self.locatorDoneWorking and CurTime() >= self:GetTimeToComplete() then
					local d = jcms.director
					if not d then return end

					local data = jcms.missions[ d.missionType ]
					if not data then return end
					
					if data.tagEntities then
						local tagEnts = {}
						data.tagEntities(d, d.missionData, tagEnts)

						local selfPos = self:GetPos()

						local closestEnt, closestInfo
						local closestDist = math.huge
						local closestZDiff = math.huge
						
						if not(jcms.util_IsPVP() and jcms.director.missionData.evacuating) then
							for ent, tagInfo in pairs(tagEnts) do 
								if tagInfo.active and not tagInfo.locatorIgnore then 
									local entPos = ent:GetPos()
									local dist = entPos:Distance(selfPos)
									if dist < closestDist then 
										closestDist = dist
										closestEnt = ent
										closestInfo = tagInfo
										closestZDiff = entPos.z - selfPos.z
									end
								end
							end
						else 
							local ourTeam = self:GetNWInt("jcms_pvpTeam", -1)

							for i, ply in ipairs(team.GetPlayers(1)) do 
								if not jcms.team_pvpSameTeam_optimised(ourTeam, ply:GetNWInt("jcms_pvpTeam", -1)) then
									local plyPos = ply:GetPos()
									local dist = plyPos:Distance(selfPos)
									if dist < closestDist then 
										closestDist = dist
										closestEnt = ply
										closestZDiff = plyPos.z - selfPos.z
									end
								end
							end

						end

						if IsValid(closestEnt) then 
							self:SetNWInt("jcms_locator_distance", math.floor(closestDist) )
							self:SetNWInt("jcms_locator_zdiff", math.floor(closestZDiff) )
							self:SetNWString("jcms_locator_target", (closestInfo and closestInfo.name) or closestEnt:Nick())
							self:SetNWInt("jcms_locator_direction", jcms.util_GetCompassDir(selfPos, closestEnt:GetPos()))
							self:EmitSound("buttons/combine_button5.wav", 100, 110, 1)
						else
							self:EmitSound("buttons/combine_button_locked.wav", 100, 80, 1)
						end

					end

					self.locatorDoneWorking = true
				end

				return false 
			end
		}
	}
end

if CLIENT then
	jcms.device_colors = {
		[1] = {
			bright1 = Color(255, 32, 32, 200),
			bright2 = Color(255, 32, 32),
			brightDim = Color(255, 0, 0, 32),
			dark1 = Color(64, 0, 0),
		},

		[2] = {
			bright1 = Color(255, 233, 32, 200),
			bright2 = Color(255, 233, 32),
			brightDim = Color(255, 233, 0, 32),
			dark1 = Color(64, 48, 0),
		}
	}

	function jcms.device_GetColor(name, team)
		team = team or 1
		local teamTable = jcms.device_colors[ team ] or jcms.device_colors[1]

		return teamTable[ name ] or color_white
	end

	jcms.device_render = {
		autohacker = function(self)
			local pvpTeam = self:GetNWInt("jcms_pvpTeam", -1)

			local v = self:WorldSpaceCenter()
			local a = self:GetAngles()
			a:RotateAroundAxis(a:Right(), -90)
			a:RotateAroundAxis(a:Up(), 90)
			
			local time = CurTime()
			local progress = math.TimeFraction(self:GetTimeStart(), self:GetTimeToComplete(), time)
			local progress2 = (progress*32)%1
			local offset = time % (math.pi*2)
			
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			cam.Start3D2D(v, a, 1/32)
				local size1 = 230
				surface.SetDrawColor(jcms.device_GetColor("bright1", pvpTeam))
				jcms.draw_Circle(0, 0, size1, size1, 24, math.ceil(progress*32), offset, offset+math.pi*2*progress)
			cam.End3D2D()
			
			v = v + a:Up()
			cam.Start3D2D(v, a, 1/32)
				local size2 = size1 + 24
				surface.SetDrawColor(jcms.device_GetColor("brightDim", pvpTeam))
				jcms.draw_Circle(0, 0, size2, size2, 12, math.ceil(progress2*32), -offset, math.pi*2*progress2-offset)
			cam.End3D2D()
			render.OverrideBlend( false, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			
			v = v + a:Up()*8
			local col = jcms.device_GetColor("bright2", pvpTeam)
			local colDark = jcms.device_GetColor("dark1", pvpTeam)
			cam.Start3D2D(v, a, 1/24)
				draw.SimpleText(math.Round(progress*100).."%", "jcms_hud_big", 0, 0, colDark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText(math.Round(progress*100).."%", "jcms_hud_big", -2, -2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.End3D2D()
		end,

		locator = function(self)
			local v = self:WorldSpaceCenter()
			local a = self:GetAngles()
			a:RotateAroundAxis(a:Up(), 90)
			v:Add(a:Up() * 4)

			local time = CurTime()
			local progress = math.TimeFraction(self:GetTimeStart(), self:GetTimeToComplete(), time)
			
			local color = jcms.device_GetColor("bright2", pvpTeam)
			local color_pulsing = jcms.device_GetColor("bright1", pvpTeam)
			local color_dark = jcms.device_GetColor("dark1", pvpTeam)

			if progress < 1 then
				local cellCount = 6
				local midCell = cellCount/2 + 0.5
				cam.Start3D2D(v, a, 1/32)
					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
					for y=1,cellCount do
						for x=1,cellCount do
							local a = math.Distance(x, y, midCell, midCell) + (-time*8)%(math.pi*2)
							local osc = (math.sin(a) / 2 + 0.5)^2
							
							surface.SetDrawColor(color.r, color.g, color.b, osc*100)
							local rs = 48
							local rx, ry = (x-midCell-0.5)*rs, (y-midCell-0.5)*rs
							jcms.hud_DrawNoiseRect(rx, ry, rs, rs, 1024*osc)
							surface.SetDrawColor(color.r, color.g, color.b, 50 + osc*50)
							surface.DrawOutlinedRect(rx+2, ry+2, rs-4, rs-4, 1+osc)
						end
					end
					render.OverrideBlend( false )

					draw.SimpleText("#jcms.locator_scanning", "jcms_hud_small", 0, -24, color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
					surface.SetDrawColor(color_dark)
					surface.DrawRect(-128, 0, 256, 48)
				cam.End3D2D()

				v:Add(a:Up()*0.2)

				cam.Start3D2D(v, a, 1/32)
					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
						draw.SimpleText("#jcms.locator_scanning", "jcms_hud_small", 0, -24, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
						surface.SetDrawColor(color)
						surface.DrawOutlinedRect(-128, 0, 256, 48, 2)
						surface.DrawRect(-128+8, 8, (256-16)*progress, 48-16)
					render.OverrideBlend( false )
				cam.End3D2D()
			else

				local dist = self:GetNWInt("jcms_locator_distance", 0)
				local distFormatted = jcms.util_ToDistance(dist, true)

				local zdiff = self:GetNWInt("jcms_locator_zdiff", 0)
				local zdiffFormatted = "#jcms.compasszdiff_same"
				if zdiff <= -100 then
					zdiffFormatted = language.GetPhrase("jcms.compasszdiff_below"):format( jcms.util_ToDistance(-zdiff, true) )
				elseif zdiff >= 300 then
					zdiffFormatted = language.GetPhrase("jcms.compasszdiff_above"):format( jcms.util_ToDistance(zdiff, true) )
				end

				local targetName = self:GetNWString("jcms_locator_target", "ERR_UNKNOWN_TARGET")

				local dir = self:GetNWInt("jcms_locator_direction")
				local dirFormatted = jcms.util_compassDirs[ dir ] or "???"

				cam.Start3D2D(v, a, 1/32)
					local tw, th = draw.SimpleText(distFormatted .. " " .. dirFormatted, "jcms_hud_big", 0, -4, color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					draw.SimpleText(targetName, "jcms_hud_medium", 0, -th/2 + 4, color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
					draw.SimpleText(zdiffFormatted, "jcms_hud_medium", 0, th/2 - 12, color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				cam.End3D2D()

				v:Add(a:Up()*0.2)

				cam.Start3D2D(v, a, 1/32)
					render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
						draw.SimpleText(distFormatted .. " " .. dirFormatted, "jcms_hud_big", 0, -4, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						draw.SimpleText(targetName, "jcms_hud_medium", 0, -th/2 + 4, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
						draw.SimpleText(zdiffFormatted, "jcms_hud_medium", 0, th/2 - 12, color_pulsing, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
					render.OverrideBlend( false )
				cam.End3D2D()
			end
		end
	}
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "DeviceType")
	self:NetworkVar("Entity", 0, "AttachedEnt")
	self:NetworkVar("Float", 0, "HealthFraction")
	self:NetworkVar("Float", 1, "TimeStart")
	self:NetworkVar("Float", 2, "TimeToComplete")
	self:NetworkVar("Bool", 0, "HackedByRebels")
	
	self:SetHealthFraction(1)
end

function ENT:UpdateForFaction(faction)
	if faction == "mafia" then
		self:SetColor(Color(241, 212, 14))
	else
		self:SetColor(Color(255, 64, 64))
	end
end

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/props_lab/tpplug.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMaxHealth(65)
		self:SetHealth(self:GetMaxHealth())
	end
	
	if CLIENT then
		self:EmitSound("npc/roller/blade_cut.wav", 75, 120)
	end
	
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
end

if SERVER then
	function ENT:OnTakeDamage(dmg)
		if self.isDestroyed then return end
		
		if dmg:GetDamage() > 0.5 then
			self:TakePhysicsDamage(dmg)
			self:EmitSound("Metal_Barrel.BulletImpact")
			self:SetHealth( self:Health() - math.max(0.5, dmg:GetDamage()) )
			self:SetHealthFraction( math.Clamp(self:Health() / self:GetMaxHealth(), 0, 1) )
			
			if self:Health() <= 0 then
				self.isDestroyed = true
				self:EmitSound("npc/turret_floor/die.wav", 100, 135, 1)
				constraint.RemoveAll(self)
				
				local ed = EffectData()
				ed:SetOrigin(self:WorldSpaceCenter())
				ed:SetMagnitude(2)
				ed:SetScale(2)
				ed:SetRadius(10)
				ed:SetNormal(self:GetAngles():Forward())
				util.Effect("Sparks", ed)
				
				timer.Simple(math.Rand(0.6, 1.5), function()
					if IsValid(self) then
						self:Remove()
						self:EmitSound("Metal_Barrel.BulletImpact")
						
						local ed = EffectData()
						ed:SetMagnitude(0.7)
						ed:SetOrigin(self:GetPos())
						ed:SetRadius(26)
						ed:SetNormal(Vector(0, 0, 1))
						ed:SetFlags(self:GetNWInt("jcms_pvpTeam", -1) == 2 and 7 or 2)
						util.Effect("jcms_blast", ed)
					end
				end)
			end
		end
	end
	
	function ENT:Think()
		local data = self:GetDeviceData()
		if not self.isDestroyed then
			local timeToDie = true
			if data and data.think then
				timeToDie = data.think(self, self:GetAttachedEnt())
			end
			
			if timeToDie then
				self.isDestroyed = true
				self:EmitSound("garrysmod/save_load4.wav", 100, 75, 1)
				constraint.RemoveAll(self)
				
				timer.Simple(math.Rand(0.6, 1.5), function()
					if IsValid(self) then
						self:Remove()
						self:EmitSound("Metal_Barrel.BulletImpact")
						
						local ed = EffectData()
						ed:SetMagnitude(0.7)
						ed:SetOrigin(self:GetPos())
						ed:SetRadius(26)
						ed:SetNormal(Vector(0, 0, 1))
						ed:SetFlags(self:GetNWInt("jcms_pvpTeam", -1) == 2 and 7 or 2)
						util.Effect("jcms_blast", ed)
					end
				end)
				
				if data and data.finished then
					data.finished(self, self:GetAttachedEnt())
				end
			end
		end
	end
	
	function ENT:SetupDevice(deviceName, attachedEnt, ...)
		local data = assert(jcms.devices[ deviceName ], "unknown jcorp device name '"..tostring(deviceName).."'")
		self:SetDeviceType(deviceName)
		self:SetAttachedEnt(attachedEnt)
		self:SetTimeStart(CurTime())
		
		if data.setup then
			data.setup(self, attachedEnt, ...)
		end
	end
	
	function ENT:GetDeviceData()
		return jcms.devices[ self:GetDeviceType() ]
	end
end

if CLIENT then
	function ENT:DrawTranslucent()
		local renderfunc = jcms.device_render[ self:GetDeviceType() ]
		
		if self:GetHealthFraction() > 0 and renderfunc then
			renderfunc(self)
		end
		
		if self:GetHackedByRebels() then
			jcms.render_HackedByRebels(self)
		end
	end
end
