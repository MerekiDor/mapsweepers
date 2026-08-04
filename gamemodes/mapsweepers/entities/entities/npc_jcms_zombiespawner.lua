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
ENT.PrintName = "Spawner"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsUpgrading")

	if SERVER then
		self:SetIsUpgrading(false)
	end
end

if SERVER then 
	function ENT:Initialize()
		self:SetModel("models/jcms/zombiespawner.mdl")

		self:PhysicsInitBox( Vector(-50,-50,0),Vector(50,50,180) )
		self:SetMoveType(MOVETYPE_NONE)

		self:SetMaxHealth(900)
		self:SetHealth(900)
		self.nextSpawn = CurTime() + 5
		self.spawnedNPCs = {}

		self.jcms_flinchProgress = 0
		self.jcms_ignoreStraggling = true

		self:SetSequence("idle")
		self:SetCycle(math.random())
		self:SetBloodColor(BLOOD_COLOR_ANTLION)

		self:SetAngles( Angle(math.Rand(-2, 2), math.random()*360, math.Rand(-2, 2)) )
		
		self:SetNWString("jcms_boss", "zombie_spawner")

		self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)

		--Upgrade
		self.jcms_upgradeLevel = 0
		self.jcms_nextUpgrade = CurTime() + 80

		self.nextSlowThink = CurTime() + 1 --Work-around for broken anims
	end

	function ENT:OnTakeDamage(dmgInfo)
		local dmg = dmgInfo:GetDamage()

		if self.dying then
			return
		end

		if dmg > 0 then
			if bit.band( dmgInfo:GetDamageType(), bit.bor(DMG_BLAST,DMG_BLAST_SURFACE) ) > 0 then
				dmgInfo:ScaleDamage(1.75)
			end

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

	function ENT:Think()
		local selfTbl = self:GetTable()
		local cTime = CurTime()
		if selfTbl.nextSlowThink > cTime then return end
		
		--Spawning logic
		local selfPos = self:GetPos()
		if selfTbl.nextSpawn < CurTime() and not self.dying then
			for i=#selfTbl.spawnedNPCs, 1, -1 do 
				local npc = selfTbl.spawnedNPCs[i]
				if not IsValid(npc) then
					table.remove(selfTbl.spawnedNPCs, i)
				end
			end

			local count = 6 - #selfTbl.spawnedNPCs
			if count > 0 then 
				local fTime = math.floor( CurTime() / 20 ) * 20 -- Sync all spawners
				selfTbl.nextSpawn = fTime + 20

				local filter = RecipientFilter()
				filter:AddAllPlayers()

				local pitch = 80 - self.jcms_upgradeLevel * 20
				self:EmitSound("npc/fast_zombie/fz_alert_far1.wav", 140, pitch, 0.75, CHAN_STATIC, 0, 25, filter)
				self:EmitSound("npc/headcrab_poison/ph_rattle" .. tostring(math.random(1,3)) .. ".wav", 140, pitch, 1, CHAN_STATIC, 0, 25, filter)
				self:EmitSound("npc/zombie_poison/pz_pain1.wav", 140, pitch, 1, CHAN_STATIC, 0, 25, filter) --lvl, pitch, vol

				self:SetSequence("spew")
				self:SetCycle(0)
				local dur = self:SequenceDuration()
				
				local firePos = nil
				local enemy = jcms.GetNearestSweeper( self:GetPos() )

				if IsValid(enemy) then
					firePos = enemy:WorldSpaceCenter()
				end

				timer.Simple(dur * math.Rand(0.6, 0.65), function()
					if IsValid(self) then
						local ball = ents.Create("jcms_charpleball")
						constraint.NoCollide(ball, self, 0, 0)
						ball:SetPos(self:GetBonePosition(self:LookupBone("spine")))
						ball.jcms_upgradeLevel = self.jcms_upgradeLevel
						ball:Spawn()
						ball.Spawner = self

						if firePos then
							-- // Random Offset
							if IsValid(enemy) and not IsValid(enemy:GetNWEntity("jcms_vehicle")) and not IsValid(enemy:GetGroundEntity()) then --No offset if in a vehicle or standing on one
								local maxOffset = 650

								local offsX, offsY = math.random(), math.random() 	--Random 0-1
								offsX, offsY = math.sqrt(offsX), math.sqrt(offsY) 	--Bias us towards 1
								offsX, offsY = offsX * maxOffset, offsY * maxOffset --Range to 0-maxOffset
								offsX = offsX * (math.random() < 0.5 and 1 or -1)	--Random sign
								offsY = offsY * (math.random() < 0.5 and 1 or -1)	--Random sign

								firePos:Add(Vector(offsX, offsY, 0)) 
							elseif IsValid(enemy) then --We do still have an enemy but it's something we want to hit accurately
								
								local curPos = enemy:WorldSpaceCenter()
								local posDelta = curPos - firePos --More reliable than :GetVelocity() (and we don't need to care if we're in a vehicle or not)
								firePos = curPos --Update our position to match their current for better accuracy

								--This could be done way more accurately, but I'm not too concerned about that yet.
								firePos:Add(posDelta * 2)
							end

							-- Velocity Calc
								local selfPos = self:GetPos()
								local g = physenv.GetGravity().z

								local dir = firePos - selfPos
								dir.z = 0
								local groundLen = dir:Length()

								dir:Normalize()
								local height = firePos.z - selfPos.z
								
								local vertVel = 1000 + math.sqrt(groundLen) + height/2
								
								local groundVel = (groundLen * g) / ( -vertVel - math.sqrt( vertVel^2 + (2 * g * height)) )
							-- // }}}
							
							local final = (dir * groundVel) + Vector(0,0,vertVel) 
							ball:GetPhysicsObject():SetVelocity(final)
						else
							local a = math.random() * math.pi * 2
							local cos, sin = math.cos(a), math.sin(a)
							local mag = math.random(300, 500)

							ball:GetPhysicsObject():SetVelocity(Vector(cos*mag, sin*mag, math.Rand(2500, 3500)))
						end

						self:EmitSound("weapons/stinger_fire1.wav", 140, 75)
					end
				end)

				timer.Simple(dur, function()
					if IsValid(self) and self:GetSequenceName( self:GetSequence() ) == "spew" then
						self:SetSequence("idle")
						self:SetCycle(0)
					end
				end)
			end
		end

		--Upgrading logic
		local upgradeLvl = self.jcms_upgradeLevel
		if self.jcms_nextUpgrade < CurTime() and not self:GetIsUpgrading() and upgradeLvl < 2 then 
			self:SetIsUpgrading(true)
			self:EmitSound("npc/barnacle/barnacle_bark"..tostring(math.random(1,2))..".wav", 100, math.random(60, 80))
			
			local upgradeDur = 30
			self:SetModelScale( 1 + (upgradeLvl+1)/2, upgradeDur)
			self:SetCollisionGroup(COLLISION_GROUP_DEBRIS) --Our Collisions get messed up while scaling, this is the best I can do to fix that.
			timer.Simple(upgradeDur, function()
				if not IsValid(self) then return end

				self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)

				self:SetHealth(self:Health() * 1.25)
				self:SetMaxHealth(self:GetMaxHealth() * 1.25)

				self.jcms_upgradeLevel = self.jcms_upgradeLevel + 1
				self.jcms_nextUpgrade = CurTime() + 80
				self:SetIsUpgrading(false)
			end)
		end
		
		--Our collisions get messed up when changing scale.
		local scale = self:GetModelScale()
		self:SetCollisionBounds(Vector(-50,-50,0)*scale,Vector(50,50,180)*scale)
		
		
		self.nextSlowThink = cTime + 1 --Work-around for broken anims

		--self:NextThink(CurTime() + 1)
		--return true
	end
end

if CLIENT then
	ENT.decal_blood = Material("decals/bloodstain_002")
	jcms.zombieSpawnerEyeMat = Material("models/jcms/zombiespawner/eyes")

	function ENT:Initialize()
		hook.Add("PostDrawTranslucentRenderables", "jcms_ZombieSpawnerEyes", jcms.zombieSpawner_DrawEyes)

		self.nextDigestSound = 0
		self.nextEffect = 0
		self.nextFleshSound = 0
	end

	function ENT:Think()
		-- Burst in bloody particles.
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

		--Upgrade Visuals
		if FrameTime() > 0 and self:GetIsUpgrading() then
			local cTime = CurTime()

			--Blood effects
			if self.nextEffect < cTime then
				-- // Get a point around the edges {{{
					local mdlScale = self:GetModelScale()
					local dir = Vector(math.Rand(-1,1), math.Rand(-1,1), 0)
					dir:Normalize()
					dir:Mul(mdlScale * 50)
				-- }}}

				local effPos = self:GetPos()
				effPos:Add(dir)

				local ed = EffectData()
				ed:SetColor(0)
				ed:SetNormal(VectorRand(-1,1):GetNormalized())
				ed:SetOrigin(effPos)
				ed:SetScale(10)
				util.Effect("bloodImpact", ed)
				
				self.nextEffect = cTime + 0.05
			end

			--Flesh SFX & decals
			if self.nextFleshSound < cTime then
				self:EmitSound("physics/flesh/flesh_squishy_impact_hard"..math.random(1,4)..".wav", 75, math.random(80, 90), 1)
				self.nextFleshSound = cTime + 0.1 + math.Rand(0, 0.2)
				
				-- // Get a point around the edges {{{
					local mdlScale = self:GetModelScale()
					local dir = Vector(math.Rand(-1,1), math.Rand(-1,1), 0)
					dir:Normalize()
					dir:Mul(mdlScale * 60)
					dir.z = -100
				-- }}}

				-- // Decal code I stole from bigblast {{{
					local selfPos = self:WorldSpaceCenter()
					local tr = util.TraceLine {
						start = selfPos,
						endpos = selfPos + dir,
						mask = MASK_PLAYERSOLID_BRUSHONLY
					}

					if (tr.Hit) and (IsValid(tr.Entity) or tr.Entity == game.GetWorld()) and IsValid(self) then
						local scale = math.Rand(0.5, 1)
						util.DecalEx(self.decal_blood, tr.Entity, tr.HitPos, tr.Normal, color_white, scale, scale)
					end
				-- // }}}
			end

			--Play digesting sounds while we're upgrading
			if self.nextDigestSound < cTime then 
				local digestSounds = {
					"npc/barnacle/barnacle_digesting1.wav",
					"npc/barnacle/barnacle_digesting2.wav"
				}
				local sndChoice = digestSounds[math.random(#digestSounds)]

				self:EmitSound(sndChoice, 90, 90)
				self.nextDigestSound = cTime + SoundDuration(sndChoice)/0.9
			end
		end
	end

	function ENT:OnRemove()
		--Clean up render hooks if we're no longer present
		if #ents.FindByClass("npc_jcms_zombiespawner") <= 1 then
			hook.Remove("PostDrawTranslucentRenderables", "jcms_ZombieSpawnerEyes")
		end

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
	end
	
	function ENT:DrawTranslucent()
		self:DrawModel()
	end

	function jcms.zombieSpawner_DrawEyes(bDrawingDepth, bDrawingSkybox, isDraw3DSkybox)
		if bDrawingDepth or bDrawingSkybox or isDraw3DSkybox then return end
		
		render.MaterialOverride(jcms.zombieSpawnerEyeMat)
			for i, ent in ipairs(ents.FindByClass("npc_jcms_zombiespawner")) do 
				ent:DrawModel()
			end
		render.MaterialOverride()
	end
end