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
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "J Corp Evac Transmitter"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
	self:SetModel("models/jcms/jcorp_evac.mdl")

	if SERVER then
		self.nextSlowCharge = CurTime()
		self:SetMoveType(MOVETYPE_NONE)
		self:PhysicsInitStatic(SOLID_VPHYSICS)
	end

	if CLIENT then
		local ed = EffectData()
		ed:SetColor(jcms.util_colorIntegerJCorp)
		ed:SetFlags(0)
		ed:SetEntity(self)
		util.Effect("jcms_spawneffect", ed)	
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Charge")
	self:NetworkVar("Int", 1, "MaxCharge")
	self:NetworkVar("Int", 2, "ClerksRecruited")
	self:NetworkVar("Bool", 0, "CanCharge")
	self:NetworkVar("Bool", 1, "SlowCharge")
	self:NetworkVar("Bool", 2, "AllSwpNear")
	
	if SERVER then
		self:SetCharge(0)
		self:SetMaxCharge(45) -- takes 45s to charge up (previously (1:30)
		self:SetClerksRecruited(0)
	end
end

function ENT:IsBeamActive()
	return self:GetCharge() >= self:GetMaxCharge()
end

if SERVER then
	ENT.SafeFromNPCsDistance = 450

	function ENT:BeamUp(ply)
		ply:EmitSound("ambient/machines/teleport4.wav")

		local ed = EffectData()
		ed:SetOrigin(ply:GetPos())
		ed:SetFlags(0)
		util.Effect("jcms_evacbeam", ed)
		
		jcms.mission_PlayerEvac(ply)
		
		timer.Simple(6, function()
			if jcms.director and not jcms.director.gameover and IsValid(ply) then
				jcms.playerspawn_RespawnAs(ply, "spectator")
			end
		end)
	end
	
	function ENT:BeamUpFake(ent)
		ent:EmitSound("ambient/machines/teleport4.wav")

		local ed = EffectData()
		ed:SetOrigin(ent:GetPos())
		ed:SetFlags(0)
		util.Effect("jcms_evacbeam", ed)
		
		if ent:IsPlayer() then
			ent:KillSilent()
		else
			if jcms.director then
				jcms.director.npcrecruits = jcms.director.npcrecruits + 1
			end
			
			ent:Remove()
		end

		self:SetClerksRecruited( math.min(self:GetClerksRecruited() + 1, jcms.cvar_cash_maxclerks:GetInt()) )
	end

	function ENT:IsSafe()
		local pos = self:WorldSpaceCenter()
		if jcms.director then
			local rad2 = self.SafeFromNPCsDistance^2
			for i, npc in ipairs(jcms.director.npcs) do
				if IsValid(npc) and npc:Health()>0 and math.min(npc:GetPos():DistToSqr(pos), npc:WorldSpaceCenter():DistToSqr(pos)) < rad2 then
					return false
				end
			end

			for i, pnpc in ipairs(team.GetPlayers(2)) do
				if IsValid(pnpc) and pnpc:Health()>0 and math.min(pnpc:GetPos():DistToSqr(pos), pnpc:WorldSpaceCenter():DistToSqr(pos)) < rad2 then
					return false
				end
			end
		end

		return true
	end
	
	function ENT:Think()
		local selfTbl = self:GetTable()
		if jcms.director or selfTbl.forceCharging then
			local charge, maxcharge = selfTbl:GetCharge(), selfTbl:GetMaxCharge()
			local safe = self:IsSafe()
			local swpsInRange = jcms.GetSweepersInRange(self:WorldSpaceCenter(), 1000)
			local swpNearby = #swpsInRange > 0
			
			if swpNearby ~= selfTbl:GetCanCharge() then
				selfTbl:SetCanCharge(swpNearby)
			end

			if not(safe) ~= selfTbl:GetSlowCharge() then 
				selfTbl:SetSlowCharge(not safe)
			end
			
			if selfTbl:IsBeamActive() then
				if #swpsInRange == #jcms.GetAliveSweepers() then 
					self:SetAllSwpNear(true)
				end

				for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 64)) do
					if jcms.team_GoodTarget(ent) then
						if ent:IsPlayer() and jcms.team_JCorp_player(ent) then
							self:BeamUp(ent)
							break
						else
							self:BeamUpFake(ent)
						end
					end
				end
			end

			if swpNearby and charge < maxcharge then
				local cTime = CurTime()
				if safe or selfTbl.nextSlowCharge < cTime then 
					selfTbl:SetCharge(charge + 1)
					selfTbl.nextSlowCharge = cTime + 10
				end

				if selfTbl:GetCharge() > maxcharge then 
					self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
				end
			end
		end
		
		self:NextThink( CurTime() + (selfTbl:IsBeamActive() and 0.25 or 1) )
		return true
	end

	function ENT:UpdateTransmitState()
		return (self:GetCharge() < self:GetMaxCharge() and TRANSMIT_PVS) or TRANSMIT_ALWAYS
	end
end

if CLIENT then
	ENT.mat = Material "sprites/physbeama.vmt"
	ENT.mat_beam = Material "effects/lamp_beam.vmt"
	ENT.mat_ring = Material "trails/electric.vmt"

	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnRemove()
		if self.soundCharge then
			self.soundCharge:Stop()
		end
		
		if self.soundAlarm then
			self.soundAlarm:Stop()
		end

		if self.soundWhine then
			self.soundWhine:Stop()
		end
	end

	function ENT:Think()
		if IsValid(jcms.offgame) then
			if self.soundAlarm then
				self.soundAlarm:ChangeVolume(0, 3)
				self.soundAlarm = nil
			end
			
			if self.soundWhine then
				self.soundWhine:ChangeVolume(0, 2)
			end

			if self.soundCharge then
				self.soundCharge:ChangeVolume(0, 1)
			end
		else
			if self:IsBeamActive() then
				if not self.hasPlayedMusic then
					if jcms.shouldPlayMusic() and player.GetCount() > 1 then 
						jcms.playRandomCombatSong()
					end
					
					self.hasPlayedMusic = true 
				end

				if not self.soundAlarm or not self.soundAlarm:IsPlaying() then
					if self.soundAlarm then self.soundAlarm:Stop() end
					self.soundAlarm = CreateSound(self, "ambient/alarms/combine_bank_alarm_loop4.wav")
					self.soundAlarm:PlayEx(1, 180)
					self.soundAlarm:SetSoundLevel(130)
					
					self:EmitSound("weapons/physcannon/physcannon_claws_open.wav", 100, 120)
					
					local ed = EffectData()
					ed:SetScale(5)
					ed:SetEntity(self)
					util.Effect("TeslaHitboxes", ed)
				end

				if self:GetAllSwpNear() and not game.SinglePlayer() then --TODO: Needs some visuals but I'll do that later.
					self.soundAlarm:ChangePitch(200)
				else
					self.soundAlarm:ChangePitch(180)
				end

				if not self.soundWhine or not self.soundWhine:IsPlaying() then
					if self.soundWhine then self.soundWhine:Stop() end
					self.soundWhine = CreateSound(self, "weapons/physcannon/superphys_hold_loop.wav")
					self.soundWhine:PlayEx(1, 130)
					self.soundWhine:SetSoundLevel(90)
				end

				if self.soundCharge then
					self.soundCharge:ChangePitch(10, 2)
					self.soundCharge:ChangeVolume(0, 2)

					self.soundCharge = nil
				end
			else
				local charge = self:GetCharge()
				local maxcharge = self:GetMaxCharge()
				local safe = self:GetCanCharge()
				local slow = self:GetSlowCharge()

				if (not self.soundCharge) and (charge < maxcharge) and ( self:GetCanCharge() ) then
					self.soundCharge = CreateSound(self, "ambient/levels/citadel/zapper_loop1.wav")
					self.soundCharge:ChangePitch(130, 0)
				end
				
				if self.soundCharge and charge < maxcharge then
					if not self.soundCharge:IsPlaying() and safe then
						self.soundCharge:Play()
					elseif self.soundCharge:GetVolume() <= 0.01 then
						self.soundCharge:Stop()
					end
					
					if safe and not slow then
						self.soundCharge:ChangePitch(Lerp(charge/maxcharge, 80, 200), 1)
						self.soundCharge:ChangeVolume(1, 0.1)
					elseif slow then
						self.soundCharge:ChangePitch(Lerp(charge/maxcharge, 40, 100), 1)
						self.soundCharge:ChangeVolume(1, 0.1)
					else
						self.soundCharge:ChangePitch(10, 1)
						self.soundCharge:ChangeVolume(0, 1)
					end
				end
				
				if slow and charge < maxcharge then
					if self:GetCharge() >= maxcharge then
						self.soundCharge:ChangePitch(10, 5)
						self.soundCharge:ChangeVolume(0, 5)
					end
				end
			end
		end
	end
	
	function ENT:DrawTranslucent()
		if self:IsBeamActive() then
			local vUp = self:GetAngles():Up()
			local pos = self:WorldSpaceCenter()
			pos:Sub(vUp*24)
			local time = CurTime()
			
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
				for i=1, 5 do
					local frac = (time/2 + i/5)%1
					local frac2 = 1 - (1-frac)^3
					
					local size = 82 - frac*4
					render.SetMaterial(self.mat_ring)
					
					local color = Color(Lerp(frac2, 255, 0), Lerp(frac2, 255, 100), 255, frac<0.15 and frac/0.15*255 or Lerp(frac*frac, 255, 0))
					local ringSegments = 24

					render.StartBeam(ringSegments)
					for j=1, ringSegments do
						local a = (j-1) / (ringSegments - 1) * math.pi * 2
						local ringoffset = Vector( math.cos(a) * size, math.sin(a) * size, frac*64 )
						render.AddBeam(pos + ringoffset, 12, a / (math.pi * 2) + time - i * 0.3, color)
					end
					render.EndBeam()
				end
				

				local clerks = self:GetClerksRecruited()
				if clerks > 0 then --Only display if we've recruited at least one already.
					local pos2 = self:WorldSpaceCenter()
					local ang = self:GetAngles()
					local sine = (math.sin(CurTime()*2 + self:EntIndex())+1)/2
					pos2:Add(ang:Up()*Lerp(sine, 24, 32))
					ang:RotateAroundAxis(ang:Forward(), 90)
					ang.y = (EyePos() - pos2):Angle().y + 90

					local n =  math.random(3, 5)

					local maxClerks = jcms.cvar_cash_maxclerks:GetInt()
					cam.Start3D2D(pos2, ang, 1/4)
						for i=1, n do
							local frac = (i-1)/(n-1)
							local color
							if clerks >= maxClerks then
								color = Color(Lerp(frac, 255, 100), Lerp(frac*frac, Lerp(sine, 32, 128), 0), Lerp(frac*frac, 64, 0), 255/n)
							else
								color = Color(Lerp(frac, 64, 0), Lerp(frac, 180, 0), 255, Lerp(frac*frac, 255, 0), 255/n)
							end
							
							draw.SimpleText("#jcms.evacClerks", "jcms_hud_medium", math.Rand(-4, 4), math.Rand(-1, 1), color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
							draw.SimpleText(string.format("%d / %d", clerks, maxClerks), "jcms_hud_small", math.Rand(-4, 4), math.Rand(-1, 1) + 48, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						end
					cam.End3D2D()
				end

			render.OverrideBlend( false )
		else
			render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			
			local pos = self:WorldSpaceCenter()
			local ang = self:GetAngles()
			local sine = (math.sin(CurTime()*2 + self:EntIndex())+1)/2
			pos:Add(ang:Up()*Lerp(sine, 24, 32))
			ang:RotateAroundAxis(ang:Forward(), 90)
			ang.y = (EyePos() - pos):Angle().y + 90
			
			cam.Start3D2D(pos, ang, 1/4)
				local n =  math.random(3, 5)
				local color
				
				if self:GetCanCharge() then
					if self:GetSlowCharge() then
						local str1 = language.GetPhrase("jcms.evac_title3"):format( math.Round(self:GetCharge() / self:GetMaxCharge() * 100) )
						local str2 = language.GetPhrase("jcms.evac_text2")
						
						for i=1, n do
							local frac = (i-1)/(n-1)
							color = Color(Lerp(frac, 255, 100), Lerp(frac*frac, Lerp(sine, 32, 128), 0), Lerp(frac*frac, 64, 0), 255/n)
							draw.SimpleText(str1, "jcms_hud_medium", math.Rand(-4, 4), math.Rand(-1, 1), color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
							draw.SimpleText(str2, "jcms_hud_small", math.Rand(-4, 4), math.Rand(-1, 1) + 48, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						end
					else
						local str1 = language.GetPhrase("jcms.evac_title1"):format( math.Round(self:GetCharge() / self:GetMaxCharge() * 100) )
						local str2 = language.GetPhrase("jcms.evac_text1")
						for i=1, n do
							local frac = (i-1)/(n-1)
							color = Color(Lerp(frac, 64, 0), Lerp(frac, 180, 0), 255, Lerp(frac*frac, 255, 0), 255/n)
							draw.SimpleText(str1, "jcms_hud_medium", math.Rand(-4, 4), math.Rand(-1, 1), color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
							draw.SimpleText(str2, "jcms_hud_small", math.Rand(-4, 4), math.Rand(-1, 1) + 48, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						end
					end
				else
					local str1 = language.GetPhrase("jcms.evac_title2")
					--local str2 = language.GetPhrase("jcms.evac_text2")
					
					for i=1, n do
						local frac = (i-1)/(n-1)
						color = Color(Lerp(frac, 255, 100), Lerp(frac*frac, Lerp(sine, 32, 128), 0), Lerp(frac*frac, 64, 0), 255/n)
						draw.SimpleText(str1, "jcms_hud_medium", math.Rand(-4, 4), math.Rand(-1, 1), color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						--draw.SimpleText(str2, "jcms_hud_small", math.Rand(-4, 4), math.Rand(-1, 1) + 48, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end
				end
			cam.End3D2D()
			
			color.a = 160
			local origin = self:WorldSpaceCenter()
			local span1, span2 = 45, 58
			origin.z = origin.z + Lerp(sine, 0, (span2-span1)/2)
			render.SetMaterial(self.mat_beam)
			
			for i=1, 2 do
				render.DrawQuadEasy(origin + ang:Forward()*(i==1 and -1 or 1)*17, ang:Up(), 24, Lerp(sine, span1, span2), color, 0)
			end
			render.OverrideBlend( false )
		end
	end
end
