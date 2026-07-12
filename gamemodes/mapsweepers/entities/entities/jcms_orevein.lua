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
ENT.PrintName = "Ore Vein"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

if SERVER then
	ENT.ModelsWithHealth = {
		-- big:
		["models/props_wasteland/rockgranite01c.mdl"] = 300,
		--["models/props_foliage/forestrock_cluster02.mdl"] = 450,
		["models/props_wasteland/rockgranite04a.mdl"] = 580,
		--["models/props_wasteland/rockcliff05a.mdl"] = 770,
		--["models/props_wasteland/rockcliff05b.mdl"] = 720,
		--["models/props_wasteland/rockcliff_cluster03c.mdl"] = 650,
		
		-- small:
		["models/props_foliage/rock_forest01.mdl"] = 75,
		["models/props_wasteland/rockgranite02c.mdl"] = 115,
		["models/props_mining/caverocks_cluster02.mdl"] = 178,
		["models/props_wasteland/rockcliff01j.mdl"] = 160,
		["models/props_wasteland/rockgranite01a.mdl"] = 230,
		["models/cliffs/rocks_medium01.mdl"] = 140
	}

	function jcms.ore_GetValue(type, mass)
		return (math.ceil((tonumber(mass) or 0) * jcms.oreTypes[type].value)  / math.sqrt(jcms.util_IsPVP() and jcms.util_GetLargestPvpTeamCount() or #team.GetPlayers(1)))
	end

	jcms.oreTypes = {
		-- // Main 3 {{{
			["mafium"] = {
				color = Color(207, 183, 45),
				material = "models/jcms/ore/mafium",
				value = 2,

				proxMin = 150,
				proxMax = 1850,

				-- // Chunk {{{
					chunkTakeDamage = function(ent, dmgInfo) --Immune to explosives
						if bit.band(dmgInfo:GetDamageType(), bit.bor(DMG_BLAST,DMG_BLAST_SURFACE)) ~= 0 then
							dmgInfo:ScaleDamage(0)
						end
					end,
				-- // }}}

				-- // Vein {{{
					veinTakeDamage = function(ent, dmgInfo, takenDmg, damageAmount) --Damage Resistance
						dmgInfo:ScaleDamage(0.25)
						return takenDmg * 0.25, damageAmount * 0.25 --Awful naming
					end,
				-- // }}}
			},

			["argegeum"] = {
				color = Color(214, 61, 245),
				material = "models/jcms/ore/argegeum",
				value = 4,
				
				proxMin = 1500,
				proxMax = 4000,

				-- // Chunk {{{
					chunkSetup = function(ent)
						--PLACEHOLDER, purple particles emitting from the chunk would be preferred.

						local ed = EffectData()
						ed:SetEntity(ent)
						ed:SetScale(0) --Activation time (Infinite)
						ed:SetMagnitude(5)
						ed:SetColor( jcms.util_ColorIntegerFast(230, 32, 255) )
						ed:SetMaterialIndex(1)
						util.Effect("jcms_electricarcs", ed)
					end,

					chunkThink = function(ent) --Decay
						local wth = ent:GetWorth() - 1
						ent:SetWorth(wth)
						ent:NextThink(CurTime() + 2)

						if wth <= 0 then 
							ent:Remove()
						end

						return true
					end
				-- // }}}
			},

			["jaycorpium"] = {
				color = Color(145, 22, 49),
				material = "models/jcms/ore/jaycorpium",
				value = 6,

				proxMin = 4000,
				proxMax = 64000,
				
				-- // Vein {{{
					veinTakeDamage = function(ent, dmgInfo, takenDmg) --Spark when hit
						ent:EmitSound("npc/sniper/sniper1.wav", 100, 160 + math.Rand(-40,40))
					end,
				-- // }}}

				-- // Chunk {{{
					chunkPhysCollide = function(ent, colData, collider) --Spark on impact, explode if velocity's too high.
						if CurTime() - (ent.jcms_lastPickedUpTime or 0) < 0.5 then
							return --Forgiveness for the first 0.25s after pickup, we can often get jammed into things in a way that isn't really the player's fault.
						end

						local velSqr = colData.HitSpeed:LengthSqr()
						if velSqr > 175^2 then
							ent:GetPhysicsObject():ApplyForceOffset(colData.HitNormal * -650, colData.HitPos)
							ent:EmitSound("npc/sniper/sniper1.wav", 100, 160 + math.Rand(-40,40))

							local effectdata = EffectData()
							effectdata:SetStart(colData.HitPos)
							effectdata:SetScale(math.random(6500, 9000))
							effectdata:SetMagnitude(15)
							effectdata:SetAngles(colData.HitNormal:Angle())
							effectdata:SetOrigin(ent:WorldSpaceCenter())
							effectdata:SetFlags(5)
							util.Effect("jcms_bolt", effectdata)

							if velSqr > 1000^2 then
								ent:TakeDamage(1000)
							end
						end
					end,

					chunkTakeDamage = function(ent, dmgInfo) --Track last attacker
						local attacker = dmgInfo:GetAttacker()
						if IsValid(attacker) then
							ent.lastTookDamageFrom = attacker
						end
					end,

					chunkDestroyed = function(ent)
						local damage = (ent.jcms_oreMass or 1) * 5
						local radius = (ent.jcms_oreMass or 1) * 6

						local ed = EffectData()
						ed:SetMagnitude(1)
						ed:SetOrigin(ent:WorldSpaceCenter())
						ed:SetRadius(radius)
						ed:SetNormal(ent:GetAngles():Up())
						ed:SetFlags(1)
						util.Effect("jcms_blast", ed)
						util.Effect("Explosion", ed)

						--Priority order: last picked up, last attacked, miner, ent
						local attacker = (IsValid(ent.jcms_lastPickedUp) and ent.jcms_lastPickedUp) or (IsValid(ent.lastTookDamageFrom) and ent.lastTookDamageFrom) or (IsValid(ent.jcms_miner) and ent.jcms_miner) or ent

						util.BlastDamage(ent, attacker, ent:WorldSpaceCenter(), radius, damage )
					end,
				-- // }}}
			},
		-- // }}}

		-- // On-Relase Rare ores {{{
			["ectoplasm"] = {
				color = Color(0, 255, 234),
				material = "models/props_combine/stasisshield_sheet",
				value = 15,

				proxMin = 3000,
				proxMax = 64000,
				weight = 0.01,

				-- // Vein {{{
					veinSetup = function(ent)
						ent.loopingSound = "d3_citadel.combine_ball_field_loop" .. tostring(math.random(1,3))
						ent:EmitSound(ent.loopingSound)
					end,

					veinDestroyed = function(ent)
						ent:StopSound(ent.loopingSound)
					end,
				-- // }}}

				-- // Chunk {{{
					chunkSetup = function(ent) --Zero G
						timer.Simple(0, function()
							if not IsValid(ent) then return end
							
							local phys = ent:GetPhysicsObject()
							phys:EnableGravity(false)
							phys:SetDragCoefficient( 0.75 )
						end)
					end,

					chunkTakeDamage = function(ent, dmgInfo) --More resistant, 
						dmgInfo:ScaleDamage(0.25)
					end,

					chunkThink = function(ent) --Give us *some* downward force so we don't float infinitely.
						ent:GetPhysicsObject():ApplyForceCenter( Vector(0,0,-150) )
					end
				-- // }}}
			},

			["cat"] = {
				color = Color(187, 187, 187),
				material = "matsys_regressiontest/background",
				value = 20,

				proxMin = 1000,
				proxMax = 2000,
				weight = 0.0001
			},
		-- // }}}

		-- // Post-Release Rare Ores {{{
			["flesh"] = {
				color = Color(150, 0, 0),
				material = "models/flesh",
				value = 10,

				proxMin = 1750,
				proxMax = 64000,

				weight = 0.02,

				-- // Vein {{{
					veinSetup = function(ent)
						ent:EmitSound("ambient/levels/citadel/citadel_ambient_scream_loop1.wav")
					end,

					veinDestroyed = function(ent)
						ent:StopSound("ambient/levels/citadel/citadel_ambient_scream_loop1.wav")
					end,

					veinTakeDamage = function(ent, dmgInfo, takenDmg) --Thorns
						local inflictor = dmgInfo:GetInflictor()
						local attacker = dmgInfo:GetAttacker()

						if IsValid(attacker) and attacker:IsPlayer() and jcms.util_IsStunstick(inflictor) then
							local rtnDmgInfo = DamageInfo()	
							rtnDmgInfo:SetAttacker(ent)
							rtnDmgInfo:SetInflictor(ent)
							rtnDmgInfo:SetReportedPosition(ent:WorldSpaceCenter())
							rtnDmgInfo:SetDamageType(DMG_ACID)
							rtnDmgInfo:SetDamage(takenDmg)
							rtnDmgInfo:SetDamagePosition(dmgInfo:GetReportedPosition())

							attacker:TakeDamageInfo(rtnDmgInfo)

							ent:EmitSound("NPC_PoisonZombie.Throw")
						else
							ent:EmitSound("NPC_PoisonZombie.Pain")
						end
					end,
				-- // }}}

				-- // Chunk {{{
					chunkTakeDamage = function(ent, dmgInfo) --Flesh sounds
						dmgInfo:ScaleDamage(0.25)
						ent:EmitSound("Flesh.BulletImpact")
					end,

					chunkPhysCollide = function(ent, colData, collider) --Flesh sounds
						if colData.HitSpeed:LengthSqr() > 100^2 then
							ent:EmitSound("Flesh.BulletImpact")
						end
					end,
				-- // }}}
			},

			["healthium"] = {
				color = Color(96, 255, 124),
				material = "models/jcms/ore/healthium",
				value = 7,

				proxMin = 4000,
				proxMax = 64000,

				weight = 0.02,

				-- // Chunk {{{
					chunkTakeDamage = function(ent, dmgInfo) --Track last attacker
						local attacker = dmgInfo:GetAttacker()
						if IsValid(attacker) then
							ent.lastTookDamageFrom = attacker
						end
					end,

					chunkDestroyed = function(ent) --Heal nearby players
						ent:EmitSound("items/medshot4.wav", 75, 90, 1)

						local function heal(target, amnt)
							local ed = EffectData()
							ed:SetEntity(target)
							ed:SetOrigin(ent:WorldSpaceCenter())
							ed:SetMagnitude(1)
							ed:SetScale(5)
							ed:SetFlags(5)
							util.Effect("jcms_chargebeam", ed)
							
							amnt = math.min(target:GetMaxHealth() - target:Health(), amnt)
							target:SetHealth( target:Health() + amnt )
						end

						--Give a bunch of HP to whoever broke us (if they're close enough)
						if IsValid(ent.lastTookDamageFrom) and ent.lastTookDamageFrom:IsPlayer() and ent.lastTookDamageFrom:GetPos():DistToSqr(ent:WorldSpaceCenter()) < 500^2 then
							heal(ent.lastTookDamageFrom, (ent.jcms_oreMass or 5) * 4)
						end
						
						--Give a bit less to everyone else nearby
						for i, ply in ipairs(jcms.GetSweepersInRange(ent:WorldSpaceCenter(), 500)) do
							if ply == ent.lastTookDamageFrom then continue end
							
							heal(ent.lastTookDamageFrom, (ent.jcms_oreMass or 5))
						end
					end
				-- // }}}
			},

			["thumpium"] = {
				color = Color(50, 50, 200),
				material = "models/props_combine/combinethumper002",
				value = 7,

				proxMin = 4000,
				proxMax = 64000,

				weight = 0.02,

				-- // Vein {{{
					veinSetup = function(ent)
						ent.nextThump = 0

						ent:EmitSound("ambient/machines/thumper_amb.wav")

						--Stops ants from jumping in
						local rep = ents.Create("point_antlion_repellant")
						rep:SetKeyValue("repelradius", 750)
						rep:SetPos(ent:WorldSpaceCenter())
						rep:Spawn()
						rep:SetParent(ent)
						rep:Fire("Enable")
						ent.jcms_antlionRepellant = rep

						--Scares off ants
						local aiSnd = ents.Create("ai_sound")
						aiSnd:SetKeyValue("volume", 750)
						aiSnd:SetKeyValue("duration", 1)
						aiSnd:SetKeyValue("soundtype", 256) --Thumper sound

						aiSnd:SetPos(ent:WorldSpaceCenter())
						aiSnd:Spawn()
						aiSnd:SetParent(ent)
						ent.jcms_aiSound = aiSnd
					end,

					veinDestroyed = function(ent)
						ent:StopSound("ambient/machines/thumper_amb.wav")
					end,

					veinTakeDamage = function(ent, dmgInfo, takenDmg)
						--TODO: SFX
					end,

					veinThink = function(ent)
						if ent.nextThump > CurTime() then return end

						ent:EmitSound("coast.thumper_top")
						timer.Simple(0.3, function()
							if not IsValid(ent) then return end

							ent:EmitSound("coast.thumper_hit")
							ent:EmitSound("coast.thumper_dust")
							ent.jcms_aiSound:Fire("EmitAISound")
		
							local ed = EffectData()
								ed:SetScale(1000)
								ed:SetOrigin(ent:GetPos())
								ed:SetEntity(ent)
							util.Effect("ThumperDust", ed)
						end)

						ent.nextThump = CurTime() + 3
					end
				-- // }}}

			},
		-- // }}}

		-- // v1.2 Rare Ores {{{
			["sturdium"] = {
				color = Color(75, 75, 75),
				material = "phoenix_storms/metalfloor_2-3",
				value = 10,

				proxMin = 1750,
				proxMax = 64000,

				weight = 0.025,

				-- // Chunk {{{
					chunkTakeDamage = function(ent, dmgInfo) --Immune to explosives, resistant
						if bit.band(dmgInfo:GetDamageType(), bit.bor(DMG_BLAST,DMG_BLAST_SURFACE)) ~= 0 then
							dmgInfo:ScaleDamage(0)
						else
							dmgInfo:ScaleDamage(0.1)
						end
					end,
				-- // }}}

				-- // Vein {{{
					veinTakeDamage = function(ent, dmgInfo, takenDmg, damageAmount) --Damage Resistance
						--0.1 = 20 stunstick hits
						dmgInfo:ScaleDamage(0.1)
						return takenDmg * 0.1, damageAmount * 0.1 --Awful naming
					end,
				-- // }}}
			},
			
			["magnetite"] = {
				color = Color(25, 25, 25),
				material = "phoenix_storms/metalset_1-2",
				value = 7,

				proxMin = 1750,
				proxMax = 64000,
				
				weight = 0.02,

				-- // Chunk {{{
					chunkThink = function(ent) --Magnetism
						--ent:GetPhysicsObject():ApplyForceCenter( Vector(0,0,-150) )
						local metalMats = {
							--[[
							[MAT_VENT] = true,
							[MAT_WARPSHIELD] = true,
							[MAT_GLASS] = true,
							[MAT_COMPUTER] = true,
							[MAT_METAL] = true,
							[MAT_GRATE] = true,
							[MAT_CONCRETE] = true,--]]
							["rock"] = true,
							["metal"] = true
						}

						local selfPos = ent:WorldSpaceCenter()
						for i, otherEnt in ipairs(ents.FindInSphere(selfPos, 350)) do
							local physObj = otherEnt:GetPhysicsObject() 
							if IsValid(physObj) and metalMats[physObj:GetMaterial()] then 
								local entPos = otherEnt:WorldSpaceCenter()
								local force = (selfPos - entPos)
								force:Normalize()
								force:Mul(physObj:GetMass() * 50)
								physObj:ApplyForceCenter( force )
							end
						end
					end,

					chunkTakeDamage = function(ent, dmgInfo) --More resistant (but only a little) 
						dmgInfo:ScaleDamage(0.25)
					end,

					chunkPhysCollide = function(ent, colData, collider) --Arcs on impact.
						local velSqr = colData.HitSpeed:LengthSqr()
						if velSqr > 175^2 then
							local ed = EffectData()
							ed:SetEntity(ent)
							ed:SetMagnitude(4)
							ed:SetScale(1)
							util.Effect("TeslaHitBoxes", ed)
						end
					end,

				-- // }}}

				-- // Vein {{{
					veinTakeDamage = function(ent, dmgInfo, takenDmg, damageAmount) --Damage Resistance
						dmgInfo:ScaleDamage(0.75)
						return takenDmg * 0.75, damageAmount * 0.75 --Awful naming
					end,
				-- // }}}
			},

			["thestone"] = {
				color = Color(200, 124, 124),
				material = "models/props_c17/furniturefabric002a",
				value = 30,

				proxMin = 3250,
				proxMax = 64000,
				
				weight = 0.005, --Half as common as ectoplasm

				-- // Chunk {{{
					chunkSetup = function(ent)
						ent.jcms_isReflecting = false
						ent.jcms_physAte = true --this is NOT the correct way to set this up but I'm being lazy. Stops us from entering orecrates.

						ent.jcms_nextStoneSound = CurTime() + math.Rand(0, 15)

						--Scares off ants
						local aiSnd = ents.Create("ai_sound")
						aiSnd:SetKeyValue("volume", 450)
						aiSnd:SetKeyValue("duration", 1)
						aiSnd:SetKeyValue("soundtype", 256) --Thumper sound

						aiSnd:SetPos(ent:WorldSpaceCenter())
						aiSnd:Spawn()
						aiSnd:SetParent(ent)
						ent.jcms_aiSound = aiSnd
					end,

					chunkThink = function(ent)
						local selfPos = ent:WorldSpaceCenter()
						for i, target in ipairs(ents.FindInSphere(ent:WorldSpaceCenter(), 350)) do

							--Jam nearby defenses (Quietly)
							if target.JCMS_Stunnable then
								if not target.jcms_stunEnd or target.jcms_stunEnd < CurTime() then
									target:EmitSound("NPC_Turret.Die")
								end

								--[[
								local ed = EffectData()
								ed:SetScale(3.5)
								ed:SetMagnitude( 0.2 * 512)
								ed:SetEntity(target)
								util.Effect("jcms_teslahitboxes_dur", ed)--]]

								target.jcms_stunEnd = CurTime() + 3
							end

							--Ignite wood
							local physObj = target:GetPhysicsObject()
							if IsValid(physObj) and physObj:GetMaterial() == "wood" then 
								target:Ignite(5)
							end

							--Push away OreChunks
							if IsValid(physObj) and target:GetClass() == "jcms_orechunk" then 
								local entPos = ent:WorldSpaceCenter()
								local force = (entPos - selfPos)
								force:Normalize()
								force:Mul(500)
								ent:GetPhysicsObject():ApplyForceCenter( force )
							end
						end

						--Sound
						if ent.jcms_nextStoneSound < CurTime() then 
							local soundChoices = {
								"ambient/creatures/town_scared_sob2.wav",
								"ambient/creatures/town_scared_breathing1.wav",
								"ambient/levels/canals/windchime2.wav",
								"ambient/levels/canals/windchime2.wav",
								--"ambient/levels/canals/windchime2.wav", --Probably too quiet to be heard
								"ambient/levels/canals/windchine1.wav",
								--"ambient/levels/citadel/citadel_5sirens3.wav",
								"ambient/levels/citadel/citadel_flyer1.wav",
								"ambient/atmosphere/cave_hit6.wav",
								"ambient/atmosphere/tone_alley.wav",
							}
							ent:EmitSound(soundChoices[math.random(#soundChoices)])

							ent.jcms_nextStoneSound = CurTime() + 20 + math.random(0,15)
						end

						--Scare off ants
						ent.jcms_aiSound:Fire("EmitAISound")
					end,

					chunkTakeDamage = function(ent, dmgInfo) --Indestructible
						dmgInfo:ScaleDamage(0)

						if ent.jcms_isReflecting then return end --Infinite loop safety

						--Kill attackers (if they aren't a player)
						local attacker = dmgInfo:GetAttacker()
						if IsValid(attacker) and not attacker:IsPlayer() then
							ent.jcms_isReflecting = true
							attacker:TakeDamage(99999999, ent, ent)
							ent.jcms_isReflecting = false

							attacker:EmitSound("player/pl_drown1.wav", 75, math.random(70, 120))
						end
					end,
				-- // }}}

				-- // Vein {{{
					veinSetup = function(ent)
						ent:SetHealth(1)
						ent:SetMaxHealth(1)
					end,

					veinTakeDamage = function(ent, dmgInfo, takenDmg, damageAmount) --Instant destruction
						local hp = ent:Health() 
						dmgInfo:SetDamage(hp)

						return hp, hp 
					end,
				-- // }}}
			}
		-- // }}}
		--TODO: Charple ore
	}

	function ENT:SetOreType(oretype)
		local data = assert(jcms.oreTypes[oretype], "unknown ore type '"..tostring(oretype).."'")
		self.OreValue = data.value
		self.OreColInt = jcms.util_ColorInteger(data.color)
		self.OreName = oretype
		self:SetMaterial(data.material)

		if data.veinSetup then 
			data.veinSetup(self)
		end

		self.VeinThink = data.veinThink
		self.VeinDestroyed = data.veinDestroyed
		self.VeinTakeDamage = data.veinTakeDamage
	end
	
	function ENT:Initialize()
		self:DrawShadow(false)

		local keys = table.GetKeys(self.ModelsWithHealth)
		local mdl = keys[ math.random(1, #keys) ]
		local health = self.ModelsWithHealth[mdl]

		self:SetModel(mdl)
		self:SetHealth(health)
		self:SetMaxHealth(health)
		self:PhysicsInitStatic(SOLID_VPHYSICS)

		self.OreValue = tonumber(self.OreValue) or 1
		self.OreColInt = tonumber(self.OreColInt) or 0
		self.OreDamageAccum = 0
	end

	function ENT:OnRemove()
		if self.VeinDestroyed then
			self:VeinDestroyed()
		end

		local r = self:BoundingRadius()
		for i=1, math.random(6, 8) do
			local low, high = self:WorldSpaceAABB()
			local v = Vector( math.Rand( low.x, high.x ), math.Rand( low.y, high.y ), math.Rand( low.z, high.z ) )

			local ed = EffectData()
			ed:SetOrigin(v)
			ed:SetColor(self.OreColInt or 0)
			ed:SetRadius(math.Rand(0.6, 1.1)*r + i*30)
			util.Effect("jcms_oremine", ed)
		end
	end

	function ENT:OnTakeDamage(dmg)
		if self.jcms_died or self.spawningOre then return end --Safety

		local attacker = dmg:GetAttacker()
		local inflictor = dmg:GetInflictor()

		if IsValid(attacker) and IsValid(inflictor) and attacker:IsPlayer() and jcms.team_JCorp_player(attacker) then			
			local damageTaken = 0
			local damageAmount = dmg:GetDamage()
			local doPickSound = false

			if jcms.util_IsStunstick(inflictor) then
				damageTaken = damageAmount
				doPickSound = true
			elseif bit.band(dmg:GetDamageType(), DMG_BLAST) > 0 then
				damageTaken = damageAmount + 5
			end
			
			if self.VeinTakeDamage then 
				local dmgTakenOverride, dmgAmountOverride = self:VeinTakeDamage(dmg, damageTaken, damageAmount)
				damageTaken = dmgTakenOverride or damageTaken
				damageAmount = dmgAmountOverride or damageAmount
			end

			if jcms.util_IsStunstick(inflictor) then
				self.OreDamageAccum = self.OreDamageAccum + damageAmount
			elseif bit.band(dmg:GetDamageType(), DMG_BLAST) > 0 then 
				self.OreDamageAccum = self.OreDamageAccum + damageAmount^0.9 + 37
			end


			local didBreakSound = false
			self:SetHealth( math.min( self:Health() - damageTaken, self:Health() ) ) 

			if self:Health() <= 0 then
				self:EmitSound("ambient/levels/outland/ol01_rock_crash.wav", 120, 110)
				self.OreDamageAccum = self.OreDamageAccum + 110
				self:Remove()
				self.jcms_died = true
				didBreakSound = true
			end

			local threshold = 50
			local pos = dmg:GetDamagePosition()
			if self.OreDamageAccum >= threshold then
				self.spawningOre = true --I have no idea if this will work/is needed but it seems vaguely like we're getting triggered *while* creating new entities somehow.
				local reps = 0
				repeat
					local chunk = ents.Create("jcms_orechunk")
					chunk.jcms_miner = attacker
					chunk:SetPos(pos)
					chunk:SetAngles(AngleRand())

					chunk:SetOreType(self.OreName)
					chunk:Spawn()

					local phys = chunk:GetPhysicsObject()
					phys:Wake()
					phys:AddVelocity(VectorRand(-32, 32))

					self.OreDamageAccum = self.OreDamageAccum - threshold
					reps = reps + 1
				until (self.OreDamageAccum < threshold or reps > 20) --reps >20 is for safety, Zmod got stuck in an infinite loop here and I'm not sure how.
				self.spawningOre = false

				local ed = EffectData()
				ed:SetOrigin(pos)
				ed:SetColor(self.OreColInt or 0)
				ed:SetRadius(math.Rand(50, 64 + reps*2) + math.sqrt(reps)*10 + damageTaken)
				util.Effect("jcms_oremine", ed)

				if not didBreakSound then
					if doPickSound then
						self:EmitSound("weapons/crowbar/crowbar_impact1.wav", 75, math.Rand(120, 125))
					end
					self:EmitSound("Breakable.Concrete")
				end
			else
				if doPickSound or (damageAmount >= 4 and math.random()<0.333) then
					local ed = EffectData()
					ed:SetOrigin(pos)
					ed:SetColor(self.OreColInt or 0)
					ed:SetRadius(doPickSound and (math.Rand(25, 30) + damageTaken) or damageAmount+2)
					util.Effect("jcms_oremine", ed)
				end

				if doPickSound and not didBreakSound then
					self:EmitSound("weapons/crowbar/crowbar_impact1.wav", 100, math.Rand(150, 170))
				end
			end
		end
	end

	function ENT:Think()
		self:SetSaveValue("m_vecAbsVelocity", Vector(0,0,0))

		if self.VeinThink then 
			self:VeinThink()
		end

		self:NextThink(CurTime() + 1)
		return true
	end
end

if CLIENT then
	function ENT:Initialize()
		self:DrawShadow(false)
	end
end