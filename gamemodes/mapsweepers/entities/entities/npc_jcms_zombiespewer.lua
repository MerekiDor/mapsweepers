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
ENT.PrintName = "Fog Spewer"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.AutomaticFrameAdvance = true

jcms.zombieSpewer_FogDistValues = {
	[0] = 4000, --For smoothing, this one doesn't actually show up/effect rangecap
	[1] = 3000,
	[2] = 1750,
	[3] = 1000
}

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_wasteland/antlionhill.mdl")
		self:SetMaterial("models/jcms/zombiespewer/body")

		self:SetModelScale(0.5)

		self:PhysicsInitBox( Vector(-56,-56,0),Vector(56,56,512) ) --NOTE: This is also set in Think as a bandaid fix for the below comment.
		self:SetMoveType(MOVETYPE_NONE)

		--[[timer.Simple(0.1, function() --We get reset to (-3.250000 -3.250000 0.000000)	(3.250000 3.250000 18.000000) sometimes during missions somehow?
			self:SetCollisionBounds(Vector(-56,-56,0),Vector(56,56,512))
		end)--]]

		self:SetMaxHealth(1150)
		self:SetHealth(1150)

		self.jcms_flinchProgress = 0
		self.jcms_ignoreStraggling = true

		self:SetBloodColor(BLOOD_COLOR_ANTLION)

		self:SetAngles( Angle(math.Rand(-2, 2), math.random()*360, math.Rand(-2, 2)) )

		self:SetNWString("jcms_boss", "zombie_spewer")
		self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)

		self.jcms_DontCollideWithNPCs = true
		self:SetCustomCollisionCheck(true)

		--Tell every spewer to update their cap
		hook.Call("jcms_Spewer_UpdateRangeCap")

		--SFX
		--npc/stalker/go_alert2.wav 	--alert2a
		self:EmitSound("npc/stalker/go_alert2a.wav", 140, 55 + math.Rand(0,15), 1, CHAN_STATIC, 0, 25, filter)

		self.nextSpeak = CurTime() + 20 + math.Rand(0, 20)
		--self.nextSpeak = CurTime() + 10
		self:SetPos(self:GetPos() + Vector(0,0,1)) 
	end

	function ENT:Think()
		if self.nextSpeak < CurTime() then
			--npc/stalker/stalker_scream4.wav

			self:EmitSound("npc/stalker/stalker_scream" .. tostring(math.random(1,4)) .. ".wav", 100, 60 + math.Rand(0,20), 1, CHAN_STATIC, 0, 25, filter)
			self.nextSpeak = CurTime() + 20 + math.Rand(0, 20)
			--self.nextSpeak = CurTime() + 10
		end

		--Bandaid fix. Our collisions get messed up under unknown circumstances, this ensures they're corrected eventually if they do.
		self:SetCollisionBounds(Vector(-56,-56,0),Vector(56,56,512))

		self:NextThink(CurTime() + 5)
		return true
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:UpdateRangeCap()
		local spewCount = #ents.FindByClass("npc_jcms_zombiespewer")

		local dist = jcms.zombieSpewer_FogDistValues[spewCount] or math.huge

		--TODO: Delay?
		jcms.rangeCap_SetSource(self, dist)
	end

	function ENT:OnTakeDamage(dmgInfo)
		local dmg = dmgInfo:GetDamage()

		if self.dying then
			return
		end

		if dmg > 0 then
			if bit.band( dmgInfo:GetDamageType(), bit.bor(DMG_BLAST,DMG_BLAST_SURFACE) ) > 0 then
				dmgInfo:ScaleDamage(2)
			end

			--TODO: SFX

			self.jcms_flinchProgress = self.jcms_flinchProgress + dmg 
			self:SetHealth(self:Health() - dmg)
			
			if self.jcms_flinchProgress > 25 then

				self:SetSequence( math.random() < 0.5 and "flinch02" or "flinch01" )
				local dur = self:SequenceDuration()
				timer.Simple(dur, function()
					if IsValid(self) and self:GetSequenceName( self:GetSequence() ):match("flinch") then
						self:SetSequence("idle")
						self:SetCycle(0)
					end
				end)

				self.jcms_flinchProgress = 0
			end
		end

		if self:Health() <= 0 then
			self.dying = true
			self:SetSequence("death")
			self:SetCycle(0)
			hook.Call("OnNPCKilled", GAMEMODE, self, dmgInfo:GetAttacker(), dmgInfo:GetInflictor())

			timer.Simple(1, function()
				if IsValid(self) then
					self:Remove()
				end
			end)
		end

		timer.Simple(0, function()
			if IsValid(self) then
				self:SetNWFloat("HealthFraction", self:Health() / self:GetMaxHealth())
			end
		end)
	end

	function ENT:OnRemove()
		--Tell every spewer to update their cap
		hook.Call("jcms_Spewer_UpdateRangeCap")
		jcms.rangeCap_SetSource(self, nil)
	end
end

hook.Add("jcms_Spewer_UpdateRangeCap", "jcms_Spewer_UpdateRangeCap", function()
	for i, ent in ipairs(ents.FindByClass("npc_jcms_zombiespewer")) do 
		ent:UpdateRangeCap()
	end
end)

if CLIENT then
	--ENT.FogChangeRate = 10
	local fogDistChangeRate = 500
	local fogDensityChangeRate = 0.5
	
	jcms.zombieSpewer_currentFogDist = jcms.zombieSpewer_currentFogDist or jcms.zombieSpewer_FogDistValues[0]
	jcms.zombieSpewer_currentFogDensity = jcms.zombieSpewer_currentFogDensity or 0

	hook.Add("RenderScene", "jcms_ZombieSpewer_Fog", function()
		local dt = FrameTime()

		--NOTE: This ONLY (probably) works because we have transmit-always on.
		local spewCount = #ents.FindByClass("npc_jcms_zombiespewer")

		local desiredDensity = math.min(spewCount, 1) --0 if there aren't any.
		local desiredDist = jcms.zombieSpewer_FogDistValues[spewCount] or jcms.zombieSpewer_FogDistValues[#jcms.zombieSpewer_FogDistValues]


		do --Smooth movement towards desired dist
			local diff = desiredDist - jcms.zombieSpewer_currentFogDist
			local change = math.Clamp(diff, -fogDistChangeRate * dt, fogDistChangeRate * dt)
			jcms.zombieSpewer_currentFogDist = jcms.zombieSpewer_currentFogDist + change
		end 

		do	--Smooth movement towards desired density
			local diff = desiredDensity - jcms.zombieSpewer_currentFogDensity
			local change = math.Clamp(diff, -fogDensityChangeRate * dt, fogDensityChangeRate * dt)
			jcms.zombieSpewer_currentFogDensity = jcms.zombieSpewer_currentFogDensity + change

		end

		if jcms.zombieSpewer_currentFogDensity > 0 then
			local data = {}
			data.fogCol = Color(50, 0, 0)
			data.fogMaxDensity = jcms.zombieSpewer_currentFogDensity
			data.fogMode = MATERIAL_FOG_LINEAR
			data.fogStart = -2500
			data.fogEnd = jcms.zombieSpewer_currentFogDist
			
			jcms.fogStack_push(data)
		end
	end)


	function ENT:Initialize()
		jcms.colormod_Add(Color(50,0,0), 0.6, 0, 0.1, 0, 1)
		util.ScreenShake(EyePos(), 10, 40, 1.75, 100)
		
		hook.Add("PostDrawTranslucentRenderables", "jcms_ZombieSpewerEyes", jcms.zombieSpewer_DrawEyes)

		--ambient/atmosphere/captain_room.wav   --60 pitch
		--ambient/levels/citadel/citadel_ambient_voices1.wav
		--ambient/levels/citadel/citadel_drone_loop3.wav --60-80 (but it's really quiet)
		self:EmitSound("ambient/atmosphere/captain_room.wav", 90, 70)

		self.emitter = ParticleEmitter( self:WorldSpaceCenter(), false )

		self:SetRenderBounds(Vector(-96,-96,0),Vector(96,96,512+64))
	end

	function ENT:Think()
		-- Burst into bloody particles.
		if FrameTime() > 0 and math.random() < 0.23 and self:GetSequenceName( self:GetSequence() ) == "death" then
			local boneIndex = math.random(1, self:GetBoneCount()) -- 0 not included intentionally
			local boneMatrix = self:GetBoneMatrix(boneIndex)
			if boneMatrix then
				local ed = EffectData()
				ed:SetRadius(math.random(48, 96))
				ed:SetOrigin(boneMatrix:GetTranslation())
				ed:SetMagnitude(math.Rand(0.1, 0.3))
				ed:SetFlags(0)
				util.Effect("jcms_bigblast", ed)
			end
		end

		local selfPos = self:GetPos()
		local distToPly = jcms.EyePos_lowAccuracy:Distance(selfPos)

		-- // ScreenShake {{{
			if distToPly < 1000 then
				local intensity = Lerp(math.sqrt(distToPly/1000), 8, 0.5)
				util.ScreenShake(selfPos, intensity, 40, 0.1, 0)
			end
		-- // }}}

		-- // Particles {{{
			if IsValid(self.emitter) then
				--TODO: Move vectors out of this think if it's notably expensive. Idk yet because it doesn't run *that* often, but still somewhat often.
				--local part = self.emitter:Add( "particle/particle_noisesphere", self:WorldSpaceCenter() + VectorRand(-10, 10) + Vector(-0,-5,50))
				local part = self.emitter:Add( "particle/particle_noisesphere", self:WorldSpaceCenter())
				part:SetStartSize(60)
				part:SetEndSize(100)
				part:SetDieTime(4)

				part:SetStartAlpha(175)
				part:SetEndAlpha(0)

				part:SetColor( 70 + math.random(0,10), 0, 0 )

				part:SetVelocity(Vector(0,0,175) + VectorRand(-40,40))

				part:SetGravity(Vector(0,50, 0)) --"Wind" effect
			end
		-- // }}}

		self:SetNextClientThink(CurTime() + 0.05)
		return true
	end

	function ENT:OnRemove()
		if #ents.FindByClass("npc_jcms_zombiespewer") <= 1 then
			hook.Remove("PostDrawTranslucentRenderables", "jcms_ZombieSpewerEyes")
		end

		self.emitter:Finish()
		self:StopSound("ambient/atmosphere/captain_room.wav")

		-- // FX {{{
			local ed = EffectData()
			ed:SetRadius(250)
			ed:SetOrigin(self:WorldSpaceCenter())
			ed:SetScale(1)
			ed:SetMagnitude(0.5)
			ed:SetFlags(0)
			util.Effect("jcms_bigblast", ed)

			for i=1, 6 do
				local boneIndex = math.random(1, self:GetBoneCount()) -- 0 not included intentionally
				local boneMatrix = self:GetBoneMatrix(boneIndex)
				if boneMatrix then
					local ed = EffectData()
					ed:SetRadius(math.random(65, 128))
					ed:SetOrigin(boneMatrix:GetTranslation())
					ed:SetMagnitude(math.Rand(0.3, 0.5))
					ed:SetScale(2)
					ed:SetFlags(0)
					util.Effect("jcms_bigblast", ed)
				end
			end

			util.ScreenShake(self:GetPos(), 4, 60, 2, 500, false)
			self:EmitSound("Explo.ww2bomb")
		-- // }}}
	end

	local scaleVec = Vector(1,1,1)
	function ENT:Draw()
		local sin = math.sin(CurTime() * 0.85)
		scaleVec.z = (1 + sin/8)^0.5

		self:ManipulateBoneScale(0, scaleVec)
		self:DrawModel()
	end

	--TODO: Needs to be adjusted when visual pass is done
	function jcms.zombieSpewer_DrawEyes(bDrawingDepth, bDrawingSkybox, isDraw3DSkybox)
		render.MaterialOverride(jcms.zombieSpawnerEyeMat)
			for i, ent in ipairs(ents.FindByClass("npc_jcms_zombiespewer")) do 
				ent:DrawModel()
			end
		render.MaterialOverride()
	end
end