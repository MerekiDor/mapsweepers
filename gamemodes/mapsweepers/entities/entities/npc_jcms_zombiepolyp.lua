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

		self:SetMaxHealth(300)
		self:SetHealth(300)

		self.jcms_ignoreStraggling = true

		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		self:SetCloudRange(1250 * sizeMult * densityMult)
		
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		self:SetBloodColor(BLOOD_COLOR_RED)
		
		self.jcms_dontScaleDmg = true
		self.jcms_ignoreStraggling = true
		--self.nextThink = CurTime() + 6.5 -- Don't immediately start damaging on spawn, give our cloud time to form.

		-- TESTING - remove this in case I forgot
		self.nextThink = CurTime() + 0.1
	end

	function ENT:DoCloudFill(range)
		local chunkSize = math.ceil( math.Clamp(range*0.1, 64, 196) )

		self.cloudChunks = {}
		self.cloudChunkSize = chunkSize
		self.cloudOriginPos = self:WorldSpaceCenter()
		self.cloudMins = Vector(self.cloudOriginPos)
		self.cloudMaxs = Vector(self.cloudOriginPos)
		self.cloudVectors = {}

		local areas = navmesh.Find(self.cloudOriginPos, range + chunkSize, chunkSize*2, chunkSize*2)
		local connections, chunks = jcms.mapgen_VectorGrid(areas, chunkSize/2, nil, chunkSize)

		for chunkId, vectors in pairs(chunks) do
			if #vectors > 0 then
				local split = string.Split(chunkId, " ")
				local cx = tonumber(split[1]) 
				local cy = tonumber(split[2])
				local cz = tonumber(split[3])
				
				local minx, miny, minz = self.cloudMins:Unpack()
				local maxx, maxy, maxz = self.cloudMaxs:Unpack()

				self.cloudMins:SetUnpacked(
					math.min(minx, cx * chunkSize),
					math.min(miny, cy * chunkSize),
					math.min(minz, cz * chunkSize)
				)

				self.cloudMaxs:SetUnpacked(
					math.max(maxx, (cx + 1) * chunkSize),
					math.max(maxy, (cy + 1) * chunkSize),
					math.max(maxz, (cz + 1) * chunkSize)
				)
				
				-- extend gas to nearby chunks
				for ox=-1,1 do
					for oy=-1,1 do
						for oz=-1,1 do
							local adjChunkId = string.format("%d %d %d", cx + ox, cy + oy, cz + oz)
							if not self.cloudChunks[ adjChunkId ] then
								table.insert(self.cloudVectors, Vector( (cx+0.5)*chunkSize, (cy+0.5)*chunkSize, (cz+0.5)*chunkSize))
							end
							self.cloudChunks[ adjChunkId ] = true
						end
					end
				end
			end
		end
	end

	function ENT:GetTargetsInsideCloud()
		-- TODO selfTbl optimisation
		if self:ShouldUseOldGas() then
			-- pre v1.2 logic
			return ents.FindInSphere( self:WorldSpaceCenter(), self:GetCloudRange() )
		end
		
		local targets = {}
		if type(self.cloudChunks) ~= "table" or not self.cloudOriginPos then return targets end
		
		local chunkSize = self.cloudChunkSize
		local mins, maxs = self.cloudMins, self.cloudMaxs
		--for _, ent in ents.Iterator() do
		for _, ent in player.Iterator() do
			if IsValid(ent) then
				local pos = ent:EyePos()
				if pos:WithinAABox( mins, maxs ) then
					local x, y, z = pos:Unpack()
					local chunkId = string.format(
						"%d %d %d", 
						math.floor(x/chunkSize), 
						math.floor(y/chunkSize), 
						math.floor(z/chunkSize)
					)
					
					if self.cloudChunks[ chunkId ] then
						table.insert(targets, ent)
					end
				end
			end
		end

		-- Show the chunks
		-- for ch in pairs(self.cloudChunks) do
		-- 	local split = string.Split(ch, " ")
		-- 	local x, y, z = tonumber(split[1])*chunkSize, tonumber(split[2])*chunkSize, tonumber(split[3])*chunkSize
		-- 	local v = Vector(x, y, z)
		-- 	debugoverlay.SweptBox(v, v, Vector(0, 0, 0), Vector(chunkSize, chunkSize, chunkSize), angle_zero, 0.5, Color(255, 128,0))
		-- end

		return targets
	end
	
	function ENT:ShouldUseOldGas()
		return false
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:OnTakeDamage(dmgInfo)
		-- // Scaling {{{
			local inflictor = dmgInfo:GetInflictor()
			if IsValid(inflictor) and jcms.util_IsStunstick(inflictor) then 
				dmgInfo:ScaleDamage(4)
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

		if (not self.cloudOriginPos) or (selfPos:DistToSqr( self.cloudOriginPos ) >= 256) then
			-- We generate clouds around us in case we moved.
			-- We don't call this in Initialize because we don't have a pos there yet.
			self:DoCloudFill( self:GetCloudRange() )
		end
		
		local dmg = DamageInfo()
		dmg:SetAttacker(self)
		dmg:SetInflictor(self)
		dmg:SetReportedPosition(selfPos)
		dmg:SetDamageType( bit.bor(DMG_NERVEGAS) )

		local cloudRange = self:GetCloudRange() 
		for i, ent in ipairs( self:GetTargetsInsideCloud() ) do 
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

		self.emitter = ParticleEmitter(selfPos)
		if self.emitter then
			for i, cv in ipairs(self.cloudVectors) do
				local p = self.emitter:Add("effects/blood", self.pos)
				if p then
					p:SetPos(cv)
					p:SetVelocity(VectorRand(-64, 64))
					p:SetRoll(math.random()*360)
					p:SetRollDelta(math.random()*2)

					p:SetStartSize(32)
					p:SetEndSize(64)
					p:SetDieTime(0.5)
					p:SetColor(32, 12, 12)
				end
			end

			self.emitter:Finish()
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

		self.nextGurgle = CurTime()
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
	end

	function ENT:Think()
		local selfTbl = self:GetTable()
		local selfPos = self:GetPos()
		local selfCentre = self:WorldSpaceCenter()
		local eyePos = EyePos()
		local range = selfTbl:GetCloudRange()

		local dist = selfCentre:DistToSqr(eyePos)

		-- // Innards pulsing {{{
			-- because they're otherwise static in the eating anim.
			if jcms.performanceEstimate > 25 then 
				local scale = 0.75 + math.sin(CurTime() * 2) / 4 
				local vScale = Vector(scale, scale, scale)
				for i=10, 12, 1 do 
					self:ManipulateBoneScale( i, vScale )
				end
			end
		-- // }}}

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