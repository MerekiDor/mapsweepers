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
ENT.PrintName = "Zombie Polyp"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "CloudRange")
	self:NetworkVar("Bool", 0, "IsDying")

	if SERVER then 
		--todo: This calculation is duplicate in this file and others, should be brought into a generic mapgen function
		local areaMult, volMult, densityMult, avgSizeMult = jcms.mapgen_GetMapSizeMultiplier()
		local sizeMult = math.min(areaMult, volMult)
		local densityMult = avgSizeMult / densityMult
		self:SetCloudRange( 1150 * (sizeMult * densityMult) ^ 0.75 )
	end
end

if SERVER then 
	function ENT:Initialize()
		self:SetModel("models/barnacle.mdl")
		self:SetSubMaterial(0, "models/jcms/zombiepolyp/polyp_base")
		self:SetAngles( Angle(0, 0, 180) )
		
		local areaMult, volMult, densityMult, avgSizeMult = jcms.mapgen_GetMapSizeMultiplier()
		local sizeMult = math.min(areaMult, volMult)
		local densityMult = avgSizeMult / densityMult

		self:SetModelScale(math.max(2 * math.sqrt(sizeMult * densityMult), 0.25), 0)

		self:PhysicsInitBox( Vector(-12,-12,0),Vector(12,12,32) )
		self:SetMoveType(MOVETYPE_NONE)

		local selfCentre = self:WorldSpaceCenter()
		for i=13, 20, 1 do 
			self:ManipulateBoneScale( i, vector_origin )
			self:ManipulateBonePosition( i, selfCentre)
		end

		self.jcms_flinchProgress = 0
		timer.Simple(0, function()
			if not IsValid(self) then return end
			self:SetSequence("chew_humanoid")
		end)

		self:SetMaxHealth(250)
		self:SetHealth(250)

		self.jcms_ignoreStraggling = true

		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		self:SetCloudRange(1250 * sizeMult * densityMult)
		self:SetBloodColor(BLOOD_COLOR_RED)

		self.jcms_dontScaleDmg = true

		self.nextThink = CurTime() + 6.5 -- Don't immediately start damaging on spawn, give our cloud time to form.
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:OnTakeDamage(dmgInfo)
		-- // Scaling {{{
			if bit.band( dmgInfo:GetDamageType(), DMG_BLAST ) > 0 then
				dmgInfo:ScaleDamage(2)
			end

			local inflictor = dmgInfo:GetInflictor()
			if IsValid(inflictor) and jcms.util_IsStunstick(inflictor) then 
				dmgInfo:ScaleDamage(3)
			end
		-- // }}}

		--Health deduction & Animation
		local dmg = dmgInfo:GetDamage()
		if dmg > 0 then
			self.jcms_flinchProgress = self.jcms_flinchProgress + dmg 
			self:SetHealth(self:Health() - dmg)
			
			if self.jcms_flinchProgress > 10 then 
				self:SetSequence( (math.random() > 0.5 and "flinch2") or "flinch1" )
				local dur = self:SequenceDuration()
				timer.Simple(dur, function()
					if IsValid(self) then 
						self:SetSequence("chew_humanoid")
					end
				end)
				self.jcms_flinchProgress = 0
			end
		end

		if self:Health() <= 0 and not self:GetIsDying() then 
			self:SetIsDying(true)
			self:SetModelScale(self:GetModelScale()*1.13 + 0.1, 0.15)
			hook.Call("OnNPCKilled", GAMEMODE, self, dmgInfo:GetAttacker(), dmgInfo:GetInflictor())
			
			timer.Simple(0.15, function()
				if IsValid(self) then
					self:Remove()
				end
			end)
		end
	end

	function ENT:Think()
		if self:GetIsDying() or self.nextThink > CurTime() then return end 
		self.nextThink = CurTime() + 1 --NextThink breaks animations for god knows what reason. This is a workaround.

		if jcms.smokeScreens then
			table.insert(jcms.smokeScreens, { pos = self:WorldSpaceCenter(), rad = self:GetCloudRange() * 0.5, expires = CurTime() + 1.5 }) 
		end

		local selfPos = self:WorldSpaceCenter()

		local dmg = DamageInfo()
		dmg:SetAttacker(self)
		dmg:SetInflictor(self)
		dmg:SetReportedPosition(selfPos)
		dmg:SetDamageType( bit.bor(DMG_NERVEGAS) )

		local cloudRange = self:GetCloudRange() 
		for i, ent in ipairs(ents.FindInSphere(selfPos , cloudRange)) do 
			if self:Disposition(ent) == D_HT and not(ent:GetClass() == "jcms_bullseye") then
				local entPos = ent:GetPos()
				local dist = selfPos:Distance(entPos)
				
				if ent:IsPlayer() then
					jcms.director_TryShowTip(ent, jcms.HINT_POLYP)
					if IsValid(ent:GetNWEntity("jcms_vehicle", NULL)) then 
						continue --Stop us from damaging people in vehicles, because that breaks things.
					end
				end
				
				dmg:SetDamage( math.ceil(Lerp( dist/cloudRange , 10, 1)) )
				dmg:SetDamagePosition(entPos)
				ent:TakeDamageInfo(dmg)
			end
		end
	end
end

if CLIENT then
	jcms.zombiePolypEyeMat = Material("models/jcms/zombiepolyp/polyp_eyes")

	function ENT:Initialize()
		self.jcms_polypEat = CreateSound(self, "ambient/creatures/leech_bites_loop1.wav")
		self.jcms_polypEat:SetSoundLevel( 140 )

		self.jcms_polypStorm = CreateSound(self, "ambient/wind/wind1.wav")
		self.jcms_polypStorm:SetSoundLevel( 140 )

		self.nextEffect = CurTime()
		self.nextGurgle = CurTime()

		--Split into 5 separate emitters for LOD
		self.emitter = ParticleEmitter( self:WorldSpaceCenter(), false )
		self.emitter2 = ParticleEmitter( self:WorldSpaceCenter(), false )
		self.emitter3 = ParticleEmitter( self:WorldSpaceCenter(), false )
		self.emitter4 = ParticleEmitter( self:WorldSpaceCenter(), false )
		self.emitter5 = ParticleEmitter( self:WorldSpaceCenter(), false )
		self.nextPart = 0

		self.pixVis = util.GetPixelVisibleHandle()

		hook.Add("PreDrawSkyBox", tostring(self), function()
			local selfCentre = self:WorldSpaceCenter()
			
			local range = self:GetCloudRange()
			local dist = selfCentre:Distance(EyePos())

			if dist < range then
				local data = {}
				data.fogCol = Color(100, 0, 0)
				data.fogMaxDensity = Lerp((dist/range)^2, 1, 0)
				data.fogMode = MATERIAL_FOG_LINEAR
				data.fogStart = Lerp(dist/range, -1500, 1000)
				data.fogEnd = Lerp(dist/range, 500, 5000)
				
				jcms.fogStack_push(data)
			end
		end)
	end

	function ENT:OnRemove()
		self.jcms_polypEat:Stop()
		self.jcms_polypStorm:Stop()

		local ed = EffectData()
		ed:SetRadius(75)
		ed:SetOrigin(self:WorldSpaceCenter())
		ed:SetMagnitude(0.3)
		ed:SetFlags(0)
		util.Effect("jcms_bigblast", ed)

		hook.Remove("PreDrawSkyBox", tostring(self))
		self.emitter:Finish()
		self.emitter2:Finish()
		self.emitter3:Finish()
		self.emitter4:Finish()
		self.emitter5:Finish()
	end

	function ENT:Think()
		local selfTbl = self:GetTable()
		local selfPos = self:GetPos()
		local selfCentre = self:WorldSpaceCenter()
		local eyePos = EyePos()
		local range = selfTbl:GetCloudRange()

		local dist = selfCentre:DistToSqr(eyePos)
		
		if not IsValid(selfTbl.emitter) then 
			selfTbl.emitter = ParticleEmitter( selfCentre, false )
			selfTbl.emitter:SetNoDraw( true ) 
		end
		if not IsValid(selfTbl.emitter2) then 
			selfTbl.emitter2 = ParticleEmitter( selfCentre, false )
			selfTbl.emitter2:SetNoDraw( true  ) 
		end
		if not IsValid(selfTbl.emitter3) then 
			selfTbl.emitter3 = ParticleEmitter( selfCentre, false )
			selfTbl.emitter3:SetNoDraw( true  ) 
		end
		if not IsValid(selfTbl.emitter4) then 
			selfTbl.emitter4 = ParticleEmitter( selfCentre, false )
			selfTbl.emitter4:SetNoDraw( true  ) 
		end
		if not IsValid(selfTbl.emitter5) then 
			selfTbl.emitter5 = ParticleEmitter( selfCentre, false )
			selfTbl.emitter5:SetNoDraw( true  ) 
		end

		selfTbl.emitter2:SetNoDraw( dist > (range * 3.25)^2) 
		selfTbl.emitter3:SetNoDraw( dist > (range * 2.5)^2 ) 
		selfTbl.emitter4:SetNoDraw( dist > (range * 2.0)^2 ) 
		selfTbl.emitter5:SetNoDraw( dist > (range * 1.75)^2 )

		if selfTbl.nextPart < CurTime() then 
			selfTbl.nextPart = CurTime() + 0.5*1.5

			local function sharedPartStats(part)
				part:SetStartAlpha(165)
				part:SetEndAlpha(0)

				part:SetColor( 105 + math.random(0,10), 35, 0 )
			end

			--todo: lua cost is actually starting to become significant so maybe I should reconsider this \/ -j
			--NOTE: we're using an inefficient method of getting spherical points,
			--This isn't super important though, as the lua impact of this code is low.
			--Polyps do cause lag due to the quantity of particles they produce, though. Which is a separate issue.

			-- // Group1 / far {{{
				local part = selfTbl.emitter:Add( "particle/particle_noisesphere", selfPos + VectorRand(-range * 0.35, range * 0.35) )
				part:SetStartSize(0)
				part:SetEndSize(range*3)
				part:SetDieTime( 10 * 1.5 )

				sharedPartStats(part)

				for i=1, 1 do -- uses LOD
					local rPos = selfPos + VectorRand(-range * 0.6, range * 0.6)

					if rPos:DistToSqr(selfPos) < range^2 then 
						local part = selfTbl.emitter2:Add( "particle/particle_noisesphere", rPos )
						part:SetStartSize(0)
						part:SetEndSize(range * 1 * 1.5)
						part:SetDieTime( 10*1.5 )
			
						sharedPartStats(part)
					end
				end

				for i=1, 2 do -- uses LOD
					local rPos = selfPos + VectorRand(-range * 0.6, range * 0.6)

					if rPos:DistToSqr(selfPos) < range^2 then 
						local part = selfTbl.emitter3:Add( "particle/particle_noisesphere", rPos )
						part:SetStartSize(0)
						part:SetEndSize(range * 1 * 1.25)
						part:SetDieTime( 10*1.5 )
			
						sharedPartStats(part)
					end
				end

			-- // }}}

			-- // Group2 / close {{{
				local toEyes = (selfPos - eyePos):GetNormalized()
				--todo: Bias us towards the outer edges. We don't need stuff in the centre.

				for i=1, 8 do --uses LOD
					local rVec = VectorRand(-range, range)
					--local rAng = rVec:Angle()
					local rPos = selfPos + rVec

					rVec:Normalize()
					local dot = rVec:Dot(-toEyes)
					local angDiff = math.acos(dot)

					if rPos:DistToSqr(selfPos) < range^2 and angDiff < math.pi/2 then 
						local part = selfTbl.emitter4:Add( "particle/particle_noisesphere", rPos )
						part:SetStartSize(0)
						part:SetEndSize(range * 0.6 * 1.75)
						part:SetDieTime( 5*1.5 )
			
						sharedPartStats(part)

						part:SetStartAlpha(200)
					end
				end

				for i=1, 18 do --uses LOD
					local rVec = VectorRand(-range, range)
					--local rAng = rVec:Angle()
					local rPos = selfPos + rVec

					rVec:Normalize()
					local dot = rVec:Dot(-toEyes)
					local angDiff = math.acos(dot)

					if rPos:DistToSqr(selfPos) < range^2 and angDiff < math.pi/2 then
						local part = selfTbl.emitter5:Add( "particle/particle_noisesphere", rPos )
						part:SetStartSize(0)
						part:SetEndSize(range * 0.6 * 1.9)
						part:SetDieTime( 3.5*1.5 )
			
						sharedPartStats(part)

						part:SetStartAlpha(255)
					end
				end
			-- // }}}
		end

		--Pulse our innards, because they're otherwise static in the eating anim.
		if jcms.performanceEstimate > 25 then 
			local scale = 0.75 + math.sin(CurTime() * 2) / 4 
			local vScale = Vector(scale, scale, scale)
			for i=10, 12, 1 do 
				self:ManipulateBoneScale( i, vScale )
			end
		end

		-- // Audio {{{
			if CurTime() > selfTbl.nextGurgle then 
				self:EmitSound("npc/barnacle/barnacle_digesting" .. tostring(math.random(1,2)) .. ".wav", 75, 90 )
				selfTbl.nextGurgle = CurTime() + 4
			end

			local dist = eyePos:Distance(selfPos)

			if dist <= range then 
				if not selfTbl.jcms_polypEat:IsPlaying() then 
					selfTbl.jcms_polypEat:Play()
				end
				if not selfTbl.jcms_polypStorm:IsPlaying() then 
					selfTbl.jcms_polypStorm:PlayEx(1, 80)
				end

				local distFrac = dist / range


				local eatVol = Lerp(distFrac - 0.25, 1, 0)
				local eatPitch = Lerp(distFrac, 60, 40)
				selfTbl.jcms_polypEat:ChangeVolume( eatVol, 0.1 )
				selfTbl.jcms_polypEat:ChangePitch( eatPitch, 0.1 )

				local stormFac = range - dist 
				local stormVol = Lerp(1 - stormFac/150, 1, 0)
				selfTbl.jcms_polypStorm:ChangeVolume( stormVol, 0.1 )

			else
				selfTbl.jcms_polypEat:Stop()
				selfTbl.jcms_polypStorm:Stop()
			end
		-- // }}}

		-- // Bursting (death) {{{
			if selfTbl:GetIsDying() and FrameTime() > 0 and math.random() < 0.6 then
				local ed = EffectData()
				local vec = self:WorldSpaceCenter()
				vec:Add( AngleRand():Forward()*(math.random()*64) )
				ed:SetRadius(math.random(48, 96))
				ed:SetOrigin(vec)
				ed:SetMagnitude(math.Rand(0.1, 0.3))
				ed:SetFlags(0)
				util.Effect("jcms_bigblast", ed)
			end
		-- // }}}
	end

	function ENT:Draw()
		self:DrawModel()
	end

	hook.Add("PostDrawTranslucentRenderables", "jcms_ZombiePolypEyes", function(bDrawingDepth, bDrawingSkybox, isDraw3DSkybox)
		render.MaterialOverride(jcms.zombiePolypEyeMat)
			for i, ent in ipairs(ents.FindByClass("npc_jcms_zombiepolyp")) do 
				ent:DrawModel()
			end
		render.MaterialOverride()
	end)
end