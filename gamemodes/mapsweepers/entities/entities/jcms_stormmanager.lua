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
ENT.PrintName = "Storm Manager"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OTHER

ENT.rainStage = 0

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Enabled")
end

function ENT:IncrRain()
	local incr = (self:GetEnabled() and 0.05)  or -0.1						--Fade us in and out.
	incr = incr * ((CLIENT and FrameTime()) or 1)

	self.rainStage = math.Clamp(self.rainStage + incr, 0, 1)
end

if SERVER then 
	function ENT:Initialize()
		self.fogController = ents.FindByClass("env_fog_controller")[1]
		if not IsValid(self.fogController) then 
			self.fogController = ents.Create( ("env_fog_controller") )
		end
		self.fogDefaultZ = self.fogController:GetInternalVariable("farz")
	end

	function ENT:OnRemove() 
		self.fogController:SetKeyValue("farz", self.fogDefaultZ)
		jcms.rangeCap_SetSource(self, nil)
	end

	function ENT:Think()
		self:IncrRain()

		if self.rainStage >= 0.99 then --TODO: Not hugely efficient
			self.fogController:SetKeyValue("farz", 2500)
			jcms.rangeCap_SetSource(self, 2500)
		else
			self.fogController:SetKeyValue("farz", self.fogDefaultZ)
			jcms.rangeCap_SetSource(self, nil)
		end

		if self.rainStage <= 0.5 then return end 


		for i, ply in ipairs(jcms.GetAliveSweepers()) do 
			local plyPos = ply:GetPos()
			local tr = util.TraceLine({
				start = plyPos,
				endpos = plyPos + Vector(0,0,32000),
				mask = MASK_SOLID,
				filter = ply
			})

			if tr.HitSky then 
				local damageinfo = DamageInfo()
				damageinfo:SetAttacker(game.GetWorld())
				damageinfo:SetInflictor(game.GetWorld())
				damageinfo:SetDamage(3 * self.rainStage)
				damageinfo:SetDamageType( bit.bor(DMG_NERVEGAS) )
				damageinfo:SetReportedPosition(plyPos)
				damageinfo:SetDamagePosition(plyPos)

				ply:TakeDamageInfo(damageinfo)
			end
		end

		self:NextThink(CurTime() + 1)
		return true 
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end
end

if CLIENT then
	function ENT:Initialize()
		-- // Audio {{{ 
			self.sound_rain1 = CreateSound(LocalPlayer(), "ambient/water/water_flow_loop1.wav")
			self.sound_rain2 = CreateSound(LocalPlayer(), "npc/headcrab/headcrab_burning_loop2.wav")

			self.sound_rain3 = CreateSound(LocalPlayer(), "ambient/water/water_run1.wav")
			--Would be better if 3 was a duplicate of 1, but we only get 1 instance of a sound per entity.

			self.sound_rain1:PlayEx(0, 60)
			self.sound_rain2:PlayEx(0, 45)
			self.sound_rain3:PlayEx(0, 120)
			self.sound_rain3:SetDSP(14) --Suboptimal, but my attempts at work-arounds didn't work.

			self.sound_wind = CreateSound(LocalPlayer(), "ambient/ambience/wind_light02_loop.wav")
			self.sound_evil = CreateSound(LocalPlayer(), "ambient/atmosphere/ambience6.wav")

			self.sound_wind:PlayEx(0, 75)
			self.sound_evil:PlayEx(0, 90)
		-- // }}}

		self.indoorFade = 0
		self.emitter = ParticleEmitter( EyePos(), false )

		self.nextThunder = 0

		hook.Add("PreDrawSkyBox", tostring(self), function()
			if self.rainStage <= 0 then return end 

			local data = {}
			data.fogCol = Color(100, 0, 0)
			data.fogMaxDensity = 1 * self.rainStage
			data.fogMode = MATERIAL_FOG_LINEAR
			data.fogStart = 0
			data.fogEnd = 1500
			
			jcms.fogStack_push(data)
		end)
	end

	function ENT:OnRemove()
		self.emitter:Finish()
		hook.Remove("PreDrawSkyBox", tostring(self))
	end

	function ENT:Think()
		if FrameTime() == 0 then return end --Stop us from thinking when paused
		--SetNextClientThink causes think to *stop being called entirely* after a few calls, for some reason.
		--And Think runs in the menu/when the game is paused, which causes rain effects to pile up, which is really bad.

		if not IsValid(self.emitter) then 
			self.emitter = ParticleEmitter( EyePos(), false )
		end

		self:IncrRain()
		if self.rainStage <= 0 then return end 

		local locPly = LocalPlayer()
		local eyePos = EyePos()

		-- // Particle FX {{{
			self.emitter:SetPos( eyePos )
			local chance = math.sqrt(self.rainStage)
			for i=1, math.ceil(self.rainStage * 5) do --Rain streaks.
				if math.random() > chance then continue end 

				local hDist = 750 / chance 
				local offs = Vector(math.Rand(-hDist, hDist), math.Rand(-hDist, hDist), math.Rand(-150,150))
				local point = eyePos + offs 
				if not(bit.band(util.PointContents( point ), CONTENTS_SOLID ) == 0) then continue end

				local ed = EffectData()
				ed:SetOrigin(point) 
				util.Effect("jcms_rain", ed)
			end
			
			for i=1, math.max(math.ceil(self.rainStage) * 15 - 5, 0) do --Cloud/Fog effect
				local offs = Vector(math.Rand(-2000, 2000), math.Rand(-2000, 2000), math.Rand(-500,1500))
				local dist = offs:Length()
				if dist > 2500 then continue end

				local point = eyePos + offs

				if not(bit.band(util.PointContents( point ), CONTENTS_SOLID ) == 0) then continue end

				local tr = util.TraceLine({
					start = point,
					endpos = point + Vector(0,0,32000),
					mask = MASK_NPCSOLID_BRUSHONLY
				})

				if not tr.HitSky then return end

				local part = self.emitter:Add( "particle/particle_noisesphere", point )

				part:SetStartAlpha(200)
				part:SetEndAlpha(0)
				part:SetColor( 100 + math.random(0,10), 0, 0 )

				part:SetStartSize(0)
				part:SetEndSize(500 + dist/5)
				part:SetDieTime( 4 )

				part:SetRoll(360)
				--part:SetVelocity( vel )
			end
		-- // }}}

		--Indoor fade.
		local tr = util.TraceLine({
			start = eyePos,
			endpos = eyePos + Vector(0,0,32000),
			mask = MASK_NPCSOLID_BRUSHONLY
		})

		local incr = (not tr.HitSky and 1) or -2
		self.indoorFade = math.Clamp(self.indoorFade + incr * FrameTime(), 0, 1)

		local rFac = self.rainStage

		-- // Audio {{{
			self.sound_rain1:ChangeVolume( rFac * 0.75 * (1 - self.indoorFade), 0 )
			self.sound_rain2:ChangeVolume( (rFac/3) * (1 - self.indoorFade), 0 )
			self.sound_rain3:ChangeVolume( rFac * self.indoorFade, 0 )

			--Windsound stops if we don't change its volume for a while. No idea why.
			self.sound_wind:ChangeVolume( rFac * (1 - self.indoorFade/2) + math.Rand(-0.01,0), 0)
			self.sound_evil:ChangeVolume( rFac, 0)
		-- // }}}

		-- // Red colormod {{{
			jcms.colormod_Hold("toxicrain", Color(64, 0, 0), rFac * (1 - self.indoorFade*0.6), 1, 2)
		-- // }}}

		if self.nextThunder < CurTime() then 
			locPly:EmitSound( "ambient/atmosphere/thunder" .. tostring(math.random(1,4)) .. ".wav" )
			self.nextThunder = CurTime() + math.random(5, 8)
			--ambient/atmosphere/thunder1.wav -- 1-4
		end
	end
end