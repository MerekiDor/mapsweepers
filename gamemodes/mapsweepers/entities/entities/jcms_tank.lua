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

--todo: Vehicle system issue, player's view will be flipped when leaving a vehicle if the vehicle is flipped.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "J Corp LHT-6"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false

if SERVER then
	sound.Add( {
		name = "jcms_tankshoot",
		channel = CHAN_STATIC,
		volume = 1.0,
		level = 140,
		pitch = 120,
		sound = {
			"weapons/mortar/mortar_explode1.wav",
			"weapons/mortar/mortar_explode3.wav"
		}
	} )

	ENT.vectorOffsets = {
		{ -100, -50 },
		{ 10, -50 },
		{ 95, -50 },

		{ -100, 0 },
		{ 10, 0 },
		{ 95, 0 },

		{ -100, 50 },
		{ 10, 50 },
		{ 95, 50 }
	}
end

function ENT:Initialize()
	self:SetCollisionGroup(COLLISION_GROUP_VEHICLE)
	
	if IsValid(self:GetTankOtherPart()) then
		if SERVER then
			self:SetModel("models/jcms/jcorp_tank_tower.mdl")
			self:PhysicsInit(SOLID_VPHYSICS)
			self:SetTankIsTower(true)
			
			self:SetMaxHealth(700)
			self:SetHealth(700)
			
			self.soundTower = CreateSound(self, "vehicles/tank_turret_loop1.wav")
			self.soundTower:Play()
			self.soundTower:ChangePitch(0)
			
			self:SetUseType(SIMPLE_USE)
		end
	else
		if SERVER then
			self:SetModel("models/jcms/jcorp_tank_body.mdl")
			self:PhysicsInit(SOLID_VPHYSICS)
			self:GetPhysicsObject():Wake()
			self:StartMotionController()
			
			self:SetTankIsTower(false)
			self.soundEngine = CreateSound(self, "vehicles/crane/crane_idle_loop3.wav")
			self.soundEngine:Play()
			self.soundEngine:ChangePitch(0)
			self.soundWater = CreateSound(self, "vehicles/airboat/pontoon_fast_water_loop1.wav")

			constraint.Keepupright( self, angle_zero, 0, 5 )
			
			self:SetMaxHealth(2000)
			self:SetHealth(2000)
			
			timer.Simple(0.1, function()
				if not IsValid(self) then return end 

				self:SetPos(self:GetPos() + Vector(0, 0, 64))
				local tower = ents.Create("jcms_tank")
				tower:SetTankOtherPart(self)
				tower:SetPos(self:GetPos())
				tower:SetAngles(self:GetAngles())
				tower:SetNWInt("jcms_pvpTeam", self:GetNWInt("jcms_pvpTeam", -1))
				tower:Spawn()
				jcms.util_TryUpdateForPVP(tower)
				
				local axis = constraint.Axis(self, tower, 0, 0, Vector(0, 0, 1), Vector(0, 0, -1), 0, 0, 50, 1)
				self:SetTankOtherPart(tower)
				self.tankTower = tower
				self.tankAxis = axis
				tower.tankAxis = axis
				
				local ed = EffectData()
				ed:SetColor(jcms.util_GetColorIntegerPvP(self))
				ed:SetFlags(0)
				ed:SetEntity(tower)
				util.Effect("jcms_spawneffect", ed)

				if CPPI then
					local owner = tank:CPPIGetOwner()
					if IsValid(owner) or (owner == game.GetWorld()) then
						tower:CPPISetOwner(owner)
					end
				end
			end)
			
			self.nextInteract = 0
			self:SetUseType(SIMPLE_USE)

			self.delayedForces = { 0, 0, 0, 0, 0, 0, 0, 0, 0 } -- From Marum's Hoverballs
		end
	end
	
	if SERVER then
		self:AddEFlags(EFL_DONTBLOCKLOS)
		--self:AddFlags(FL_NOTARGET)
	end
end

function ENT:UpdateForFaction(faction)
	if self:Health() <= 0 then
		self:SetMaterial("models/jcms/"..faction.."_tank_destroyed")
	else
		for i, matname in ipairs(self:GetMaterials()) do
			self:SetSubMaterial(i-1, matname:gsub("jcorp_", tostring(faction) .. "_"))
		end
	end
end

function ENT:TowerAngles()
	local tower = self:GetTankIsTower() and self or self:GetTankOtherPart()
	
	if IsValid(tower) then
		local driver = CLIENT and LocalPlayer() or self:GetDriver()
		local ang = tower:GetAngles()
		
		if IsValid(driver) then
			local diff = math.Clamp(math.AngleDifference(ang.p, driver:EyeAngles().p), -25, 54)
			ang.p = ang.p - diff
			return ang
		else
			return ang
		end
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "TankOtherPart")
	self:NetworkVar("Bool", 0, "TankIsTower")
	self:NetworkVar("Float", 0, "HealthFraction")
	self:NetworkVar("Float", 1, "NextAttack1")
	self:NetworkVar("Float", 2, "NextAttack2")
	self:NetworkVar("Float", 3, "Firerate1")
	self:NetworkVar("Float", 4, "Firerate2")
	if SERVER then
		self:SetHealthFraction(1)
		self:SetFirerate1(2.5)
		self:SetFirerate2(0.4)
	end
end

if SERVER then
	ENT.HoverDistance = 64
	ENT.Speed = 400
	ENT.TurnSpeed = 80
	ENT.SpeedLooseMul = 0.645
	ENT.MoveTurnSpeedMul = 0.5
	ENT.MaxDampForce = 1000
	
	function ENT:Think()
		if self.jcms_destroyed then
			if self.soundTower then
				self.soundTower:Stop()
				self.soundTower = nil
			end
			
			if self.soundEngine then
				self.soundEngine:Stop()
				self.soundEngine = nil
			end
			
			if self.soundWater then
				self.soundWater:Stop()
				self.soundWater = nil
			end
		else
			if not self:GetTankIsTower() then
				self:GetPhysicsObject():Wake()
				local speed = self:GetVelocity():Length()
				if self.soundEngine then
					self.soundEngine:ChangePitch(75 + speed/300*100, 0.1)
				end
				
				if self.soundWater then
					if self.onWater then
						if not self.soundWater:IsPlaying() then
							self.soundWater:Play()
							self.soundWater:ChangeVolume(0)
						end
						
						self.soundWater:ChangeVolume(1, 0.1)
					else
						if self.soundWater:IsPlaying() and self.soundWater:GetVolume() <= 0 then
							self.soundWater:Stop()
						else
							self.soundWater:ChangeVolume(0, 0.1)
						end
					end
					
					self.soundWater:ChangePitch(math.Clamp(speed/300*90 + 90, 0, 125), 0.1)
				end
				
				local driver = self:GetDriver()
				if IsValid(driver) then
					driver:SetPos(self:GetPos())
					
					local wep = driver:GetActiveWeapon()
					if IsValid(wep) then
						wep:SetNextPrimaryFire( CurTime() + 1 )
						wep:SetNextSecondaryFire( CurTime() + 1 )
					end
				end
			end
			
			if self:GetTankIsTower() then
				local phys = self:GetPhysicsObject()
				local speed = phys:GetAngleVelocity():Length()
				if self.soundTower then
					self.soundTower:ChangePitch(Lerp(math.Clamp(speed/300, 0, 1), 95, 105), 0.1)
					self.soundTower:ChangeVolume(math.sqrt(math.Clamp(speed/300, 0, 1)), 0.1)
				end
			end
		end
	end
	
	function ENT:OnRemove()
		if not self:GetTankIsTower() then
			self:SetDriver()
			self:StopMotionController()
			
			if self.soundEngine then
				self.soundEngine:Stop()
			end
			
			if self.soundWater then
				self.soundWater:Stop()
			end
		end
		
		if self:GetTankIsTower() then
			if self.soundTower then
				self.soundTower:Stop()
			end
		end
	end
	
	function ENT:PhysicsCollide(data, phys)
		if not self:GetTankIsTower() and data.HitEntity:Health() > 0 then
			local speed = data.OurOldVelocity:Length()
			
			if data.HitEntity:IsNPC() then
				local dmgInfo = DamageInfo()
				dmgInfo:SetDamage(speed/5 + (IsValid(self:GetDriver()) and 15 or 0))
				dmgInfo:SetAttacker(self:GetDriver() or self)
				dmgInfo:SetInflictor(self)
				dmgInfo:SetDamageType(bit.bor(DMG_CRUSH, DMG_VEHICLE))
				dmgInfo:SetReportedPosition(self:GetPos())
				dmgInfo:SetDamagePosition(data.HitPos)
				data.HitEntity:TakeDamageInfo(dmgInfo)
			end
			
			if speed > 700 then
				self:EmitSound("ATV_rollover")
			elseif speed > 300 then
				self:EmitSound("ATV_impact_heavy")
			else
				self:EmitSound("ATV_impact_medium")
			end
		end
	end

	function ENT:PhysicsSimulate(phys, dt)
		if self.jcms_destroyed then
			if IsValid(self:GetDriver()) then
				self:SetDriver()
			end
			return
		end
		
		if not self:GetTankIsTower() then
			local mass = phys:GetMass()
			local mypos = self:WorldSpaceCenter()
			local myang = phys:GetAngles()

			local myfwd = myang:Forward()
			local myright = myang:Right()
			local myup = myang:Up()
			
			local hoverDistance = self.HoverDistance
			local mins, maxs = Vector(-16, -16, -6), Vector(16, 16, 4)
			
			local driver = self:GetDriver()
			local trFilter = { self }
			if IsValid(self.tankTower) then
				trFilter[2] = self.tankTower
			end
			if IsValid(driver) then 
				table.insert(trFilter, driver)
			end

			phys:Wake()

			-- Traces {{{
				self.onWater = false

				local vecAngularSum = Vector(0, 0, 0)
				local vecLinearSum = Vector(0, 0, 0)

				local vectorNumber = #self.vectorOffsets
				for i=1, vectorNumber do
					local tr1pos = mypos + myang:Forward() * self.vectorOffsets[i][1] + myang:Right() * self.vectorOffsets[i][2]
					local tr1 = util.TraceHull {
						start = tr1pos, endpos = tr1pos + myup*(-hoverDistance),
						mins = mins, maxs = maxs, mask = bit.bor(MASK_WATER, MASK_DEADSOLID),
						filter = trFilter
					}

					self.onWater = self.onWater or tr1.MatType == MAT_SLOSH
					
					local force = 0
					if tr1.Fraction < 1 then
						force = (1 - tr1.Fraction^0.5) * mass * 5
					end

					if force > self.delayedForces[i] then
						self.delayedForces[i] = ( self.delayedForces[i] * 2 + force ) / 3
					else
						self.delayedForces[i] = self.delayedForces[i] * 0.3
					end

					debugoverlay.SweptBox(tr1pos, tr1.HitPos, mins, maxs, Angle(0,0,0), 0.1, Color(255, 0, 0))

					if self.delayedForces[i] > 0 then
						local lImp, aImp = phys:CalculateForceOffset(myup * ( self.delayedForces[i] / vectorNumber ) , tr1pos)

						vecAngularSum:Add(aImp)
						vecLinearSum:Add(lImp)
					end
				end
			-- }}}

			-- Damp {{{
				local myvel = phys:GetVelocity()
				local xyDamp = Vector( -myvel:Dot(myfwd), myvel:Dot(myright) * 1.5, 0 )
				
				local myangvel = phys:GetAngleVelocity()

				myangvel:Negate()
				myangvel:Mul(2)
				myangvel.x = myangvel.x * 2
				local angDamp = myangvel
			-- }}}

			-- Controls {{{
				local ctrlFwd = 0
				local ctrlSpin = 0
				
				if driver then
					if driver:KeyDown(IN_USE) and CurTime() > self.nextInteract then
						self:SetDriver()
						self.nextInteract = CurTime() + 1
					else
						if driver:KeyDown(IN_FORWARD) then
							ctrlFwd = 1
						elseif driver:KeyDown(IN_BACK) then
							ctrlFwd = -1
						end
						
						if driver:KeyDown(IN_MOVELEFT) then
							ctrlSpin = -1
							ctrlFwd = ctrlFwd * self.MoveTurnSpeedMul
						elseif driver:KeyDown(IN_MOVERIGHT) then
							ctrlSpin = 1
							ctrlFwd = ctrlFwd * self.MoveTurnSpeedMul
						end

						if self.attacking1 then
							self:TankShoot(driver)
							self.attacking1 = nil
						elseif self.attacking2 then
							self:TankShootAlt(driver)
							self.attacking2 = nil
						end
					end
					
					if IsValid(self.tankTower) and not self.tankTower.jcms_destroyed then
						local physTower = self.tankTower:GetPhysicsObject()
						local angTower = self.tankTower:GetAngles()
						local upTower = angTower:Up()
						local intendedAngle = driver:EyeAngles()
						
						local diff = math.AngleDifference(intendedAngle.y, angTower.y) - physTower:GetAngleVelocity():Dot(upTower) * 0.23
						diff = math.Clamp(diff, -10, 10)
						physTower:ApplyTorqueCenter(upTower * diff * physTower:GetMass())
					end
					
					if looseTraction then
						ctrlFwd = ctrlFwd * self.SpeedLooseMul
					end
				end

				if math.abs(ctrlFwd) < 0.1 then
					xyDamp.x = xyDamp.x * 6
					xyDamp.y = xyDamp.y * 1.2
				end

				xyDamp.x = math.Clamp(xyDamp.x, -500, 500)
				xyDamp.y = math.Clamp(xyDamp.y, -500, 500)
			-- }}}	

			-- Final {{{
				local vecAngular = Vector(0, 0, 0)
				vecAngular:Add(vecAngularSum)
				vecAngular:Add(angDamp)
				vecAngular.z = vecAngular.z - ctrlSpin * self.TurnSpeed

				local vecLinear = Vector(0, 0, 0)
				vecLinear:Add(vecLinearSum)
				vecLinear:Add(xyDamp)
				vecLinear.x = vecLinear.x + ctrlFwd * self.Speed

				return vecAngular, vecLinear, SIM_LOCAL_ACCELERATION
			-- }}}
		end
	end
	
	function ENT:Use(activator)
		if IsValid(activator) and activator:IsPlayer() and (not jcms.team_JCorp_player(activator)) then return end
		
		if (not self:GetTankIsTower()) and (not self.jcms_destroyed) and (CurTime() > self.nextInteract) and (not (IsValid(self.driver) and self.driver:IsPlayer())) then
			self:SetDriver(activator)
			self.nextInteract = CurTime() + 1
		end
	end

	function ENT:GetExitPos()
		-- Hull traces
		local filter = { self, self.tankTower, self.driver }
		local angle = self:GetAngles()
		local pos = self:WorldSpaceCenter()
		for i=0, 3 do
			local a = math.pi/2*i
			local cos, sin = math.cos(a), math.sin(a)
			
			local v = pos + angle:Right()*(cos*120) + angle:Forward()*(sin*150)
			local tr = util.TraceHull {
				start = pos, endpos = v, filter = filter, mins = self.driver:OBBMins(), maxs = self.driver:OBBMaxs()
			}

			if tr.Fraction > 0.85 then
				return tr.HitPos
			end
		end

		local uptrace = util.TraceHull {
			start = pos, endpos = pos + Vector(0, 0, 62), filter = filter, mins = self.driver:OBBMins(), maxs = self.driver:OBBMaxs()
		}

		if uptrace.Fraction > 0.5 then
			return uptrace.HitPos
		else
			uptrace = util.TraceHull {
				start = pos, endpos = pos + Vector(0, 0, -100), filter = filter, mins = self.driver:OBBMins(), maxs = self.driver:OBBMaxs()
			}
			if uptrace.Fraction > 0.5 then
				return uptrace.HitPos
			end
		end

		local area = navmesh.GetNearestNavArea(pos)
		if IsValid(area) then
			return area:GetCenter()
		end

		return pos
	end
	
	function ENT:SetDriver(ply)
		-- Carjacking
		if IsValid(self.driver) and self.driver:IsPlayer() then
			self.driver:SetMoveType(MOVETYPE_WALK)
			self.driver:DrawViewModel(true)
			self.driver:DrawWorldModel(true)
			self.driver:SetNoDraw(false)
			self.driver:SetNWEntity("jcms_vehicle", NULL)
			
			if ply == nil then
				self.driver:SetPos(self:GetExitPos())
			end

			local ea = self.driver:EyeAngles()
			ea.r = 0
			self.driver:SetEyeAngles(ea)

			self.driver = nil
		end
		
		if IsValid(ply) and ply:IsPlayer() and ply:GetNWEntity("jcms_vehicle") == NULL then
			self.driver = ply
			ply:SetMoveType( MOVETYPE_NOCLIP )
			ply:DrawViewModel(false)
			ply:DrawWorldModel(false)
			ply:SetNoDraw(true)
			ply:SetNWEntity("jcms_vehicle", self)
			ply:SetEyeAngles((IsValid(self.tankTower) and not self.tankTower.jcms_destroyed) and self.tankTower:GetAngles() or self:GetAngles())
		end
	end
	
	function ENT:GetDriver()
		if IsValid(self.driver) then
			return self.driver
		else
			self.driver = nil
		end
	end
	
	function ENT:TankShoot(ply)
		if IsValid(self.tankTower) and not self.tankTower.jcms_destroyed then
			local tower = self.tankTower
			if (not tower.nextShot or CurTime() - tower.nextShot > 0) then
				local driver = self:GetDriver() or NULL
				local angles = self:TowerAngles()
				local isMafia = ply:GetNWInt("jcms_pvpTeam", -1) == 2

				local bullet = ents.Create("prop_physics")
				local shootPos = tower:GetPos() + angles:Forward()*64 + angles:Right()*(self.altBarrel and 1 or -1)*12 + angles:Up()*75 
				bullet:SetPos(shootPos)
				bullet:SetOwner(tower)
				bullet:SetAngles(angles)
				bullet:SetModel("models/props_phx/ww2bomb.mdl")
				bullet:SetModelScale(0.5)
				bullet:SetHealth(1)
				bullet:Spawn()
				bullet:SetKeyValue("ExplodeDamage", 450)
				bullet:SetKeyValue("ExplodeRadius", 450)
				bullet:AddCallback("PhysicsCollide", self.TankBulletPhysicsCollide)
				bullet.jcms_owner = ply
				bullet.jcms_customBreakBlastEffect = true
				
				local physBullet = bullet:GetPhysicsObject()
				physBullet:SetVelocity(angles:Forward() * 50000)
				physBullet:SetDamping(0, 0)
				physBullet:EnableGravity(false)
				physBullet:Wake()
				util.SpriteTrail(bullet, 0, isMafia and Color(255, 180, 100) or Color(255, 110, 130), true, 64, 0, 0.25, 1, "sprites/physbeama")
				
				local physTower = tower:GetPhysicsObject()
				physTower:ApplyForceOffset(angles:Forward() * physTower:GetMass() * -75, shootPos)
				tower:EmitSound("jcms_tankshoot")
				tower:EmitSound("weapons/underwater_explode3.wav")
				--tower:EmitSound("vehicles/tank_readyfire1.wav", 100, 80)
				self.altBarrel = not self.altBarrel
				
				timer.Simple(0.5, function()
					if not IsValid(tower) then return end
					--tower:EmitSound("npc/sniper/reload1.wav", 100, 100, 0.5)
					tower:EmitSound("buttons/button6.wav", 100, 100, 1)
				end)
				timer.Simple(0.7, function()
					if not IsValid(tower) then return end
					tower:EmitSound("npc/dog/dog_pneumatic1.wav", 100, 100, 1)
				end)

				tower.nextShot = CurTime() + self:GetFirerate1()
				self:SetNextAttack1(tower.nextShot)
				
				local ed = EffectData()
				ed:SetEntity(tower)
				ed:SetScale(6)
				ed:SetFlags(isMafia and 1 or 2)
				ed:SetStart(shootPos)
				ed:SetNormal(angles:Forward())
				util.Effect("jcms_muzzleflash", ed)
			end
		end
	end
	
	function ENT:TankShootAlt(ply)
		if IsValid(self.tankTower) and not self.tankTower.jcms_destroyed then
			local tower = self.tankTower
			if (not tower.nextShotAlt or CurTime() - tower.nextShotAlt > 0) then
				local driver = self:GetDriver() or NULL
				local angles = self:TowerAngles()
				
				local midPos = tower:GetPos() + angles:Forward()*-8 + angles:Up()*75
				local shootPos = midPos + angles:Right()*(self.altBarrelAlt and 1 or -1)*64
				
				local pushAway = angles:Right()*(self.altBarrelAlt and 1 or -1)*math.random(64, 128) + angles:Up()*math.random(128, 200)
				local missile = ents.Create("jcms_micromissile")
				missile:SetPos(shootPos)
				missile:SetAngles(angles)
				missile:SetOwner(tower)
				missile.Damage = 30
				missile.Radius = 150
				missile.Proximity = 40
				missile.ActivationTime = CurTime() + 0.35
				missile.jcms_owner = ply
				missile:SetBlinkColor(jcms.util_GetPVPVectorColor(ply))
				missile:Spawn()
				missile:GetPhysicsObject():SetVelocity(angles:Forward()*32 + pushAway)
				
				local trace = util.TraceLine {
					start = midPos, endpos = midPos + angles:Forward() * 20000, 
					filter = { tower, ply, missile, self }, mask = MASK_SHOT
				}
				
				debugoverlay.Line(shootPos, trace.HitPos, 2, Color(0, 0, 255), true)
				
				if not IsValid(trace.Entity) then
					local variants = ents.FindInSphere(trace.HitPos, missile.Radius*2)
					table.Shuffle(variants)
					for i, var in ipairs(variants) do
						if var:Health() > 0 and jcms.team_NPC(var) then
							trace.Entity = var
							break
						end
					end
				end
				
				missile.Target = IsValid(trace.Entity) and trace.Entity or trace.HitPos
				missile.Damping = math.Rand(0.8, 1.0)
				missile.NeverLoseTarget = true
				
				tower.nextShotAlt = CurTime() + self:GetFirerate2()
				self:SetNextAttack2(tower.nextShotAlt)
				
				local ed = EffectData()
				ed:SetEntity(tower)
				ed:SetScale(4)
				ed:SetFlags(1)
				ed:SetStart(shootPos)
				ed:SetNormal(angles:Forward())
				util.Effect("jcms_muzzleflash", ed)
				
				local physTower = tower:GetPhysicsObject()
				physTower:ApplyForceOffset(angles:Forward() * physTower:GetMass() * -20, shootPos)
				tower:EmitSound("weapons/stinger_fire1.wav", 90, 120 + math.random() * 20)
				self.altBarrelAlt = not self.altBarrelAlt
			end
		end
	end
	
	function ENT:OnTakeDamage(dmg)
		self:TakePhysicsDamage(dmg)
		if self.jcms_destroyed then return end

		if self:Health() > 0 then
			local inflictor, attacker = dmg:GetInflictor(), dmg:GetAttacker()
			if IsValid(inflictor) and jcms.util_IsStunstick(inflictor) and jcms.team_JCorp(attacker) then
				jcms.util_PerformRepairs(self, attacker, 20)
				self:SetHealthFraction(self:Health()/self:GetMaxHealth())
				return 0
			end
		end
		
		local dmgAmount = dmg:GetDamage()
		local difficultyMultiplier = (1 / (math.max(jcms.runprogress_GetDifficulty(), 1)^0.85))
		dmgAmount = dmgAmount * difficultyMultiplier

		if bit.band(dmg:GetDamageType(), bit.bor(DMG_BULLET, DMG_SLASH, DMG_CLUB, DMG_BUCKSHOT)) > 0 then
			dmgAmount = math.max(dmgAmount*0.9 - 4, 0)
		elseif bit.band(dmg:GetDamageType(), DMG_ACID, DMG_BLAST) > 0 then
			dmgAmount = dmgAmount + 2
		end
		
		self:SetHealth( self:Health() - dmgAmount )
		self:SetHealthFraction(math.max(0, self:Health() / self:GetMaxHealth()))
		dmg:SetDamage(dmgAmount)
		
		if self:Health() <= 0 then
			self.jcms_destroyed = true
			if not self:GetTankIsTower() then
				jcms.util_TryUpdateForPVP(self)
				self:Ignite(math.Rand(15, 45))
				
				timer.Simple(math.Rand(0.5, 2.5), function()
					if IsValid(self) and IsValid(self.tankTower) and not self.tankTower.jcms_destroyed then
						self.tankTower:SetHealth(1)
						self.tankTower:TakeDamage(100)
					end
				end)
				
				local ed = EffectData()
				ed:SetMagnitude(1.5)
				ed:SetOrigin(self:WorldSpaceCenter())
				ed:SetRadius(230)
				ed:SetNormal(self:GetAngles():Up())
				ed:SetFlags(1)
				util.Effect("jcms_blast", ed)
				util.Effect("Explosion", ed)
			elseif self:GetTankIsTower() then
				jcms.util_TryUpdateForPVP(self)
				self:Ignite(math.Rand(10, 30))
				
				if IsValid(self.tankAxis) then
					self.tankAxis:Remove()
					self:EmitSound("Missile.ShotDown")
					local phys = self:GetPhysicsObject()
					local up = self:GetAngles():Up()
					phys:ApplyForceCenter(up*math.random(350, 490)*phys:GetMass())
					phys:ApplyTorqueCenter(up*math.random(-1000, 1000)*phys:GetMass())
					
					local ed = EffectData()
					ed:SetMagnitude(1)
					ed:SetOrigin(self:GetPos())
					ed:SetRadius(180)
					ed:SetNormal(self:GetAngles():Up())
					ed:SetFlags(1)
					util.Effect("jcms_blast", ed)
					util.Effect("Explosion", ed)
				end
			end
		end
	end
	
	function ENT:RedirectDamage(driver, dmg)
		dmg:ScaleDamage(0.5)
		self:TakeDamageInfo(dmg)
		dmg:SetDamage(0)
	end
	
	function ENT.TankBulletPhysicsCollide(bullet, data, phys)
		bullet:TakeDamage(100)
	end
end

if CLIENT then
	ENT.mat_pointer = Material "effects/spark"
	ENT.mat_ring = Material "jcms/ring"
	
	function ENT:DrawHUDBottom()
		local healthWidth = 1200
		local healthFrac = math.Clamp(self:GetHealthFraction(), 0, 1)
		local off = 6
		
		local tower = self:GetTankOtherPart()
		local health2Width = 800
		local health2Frac = math.Clamp(IsValid(tower) and tower:GetHealthFraction() or 0, 0, 1)
		local ammoX = health2Width + 100

		local hasTower = health2Frac > 0
		
		surface.SetDrawColor(jcms.color_dark)
		surface.DrawRect(-healthWidth/2, -114, healthWidth, 32)
		surface.DrawRect(-health2Width/2, -114-48, health2Width, 24)

		local a1, a2 = -math.pi*1.2, 0
		local b1, b2 = -math.pi, math.pi*0.2

		if hasTower then
			draw.SimpleText("∞", "jcms_hud_superhuge", -ammoX, -72, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText("∞", "jcms_hud_superhuge", ammoX, -72, jcms.color_dark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			jcms.draw_Circle(-ammoX, -72, 100, 100, 16, 9, a1, a2)
			jcms.draw_Circle(ammoX, -72, 100, 100, 16, 9, b1, b2)
		end
		
		local time = CurTime()
		render.OverrideBlend( true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD )
			local frac1 = 1 - math.Clamp( (self:GetNextAttack1()-time)/self:GetFirerate1(), 0, 1 )
			local frac2 = 1 - math.Clamp( (self:GetNextAttack2()-time)/self:GetFirerate2(), 0, 1 )
			surface.SetDrawColor(jcms.color_pulsing)
			surface.DrawRect(-256, -64, 512, 6)
			surface.DrawRect(-400, -64+16, 800, 4)
			
			surface.SetDrawColor(healthFrac < 0.4 and jcms.color_alert or jcms.color_bright)
			jcms.hud_DrawStripedRect(-healthWidth/2, -114-off+2, healthWidth, 32-4)
			surface.DrawRect(-healthWidth/2, -114-off, healthWidth*healthFrac, 32)
			
			surface.SetDrawColor(health2Frac < 0.4 and jcms.color_alert or jcms.color_bright)
			jcms.hud_DrawStripedRect(-health2Width/2, -114-48-off+2, health2Width, 24-4)
			surface.DrawRect(-health2Width/2, -114-48-off, health2Width*health2Frac, 24)

			if hasTower then
				local dim = ColorAlpha(jcms.color_bright, 20)
				local col1 = frac1 >= 1 and jcms.color_bright or dim
				local col2 = frac2 >= 0.9 and jcms.color_bright or dim
				draw.SimpleText("∞", "jcms_hud_superhuge", -ammoX-4, -76, col1, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("∞", "jcms_hud_superhuge", ammoX+4, -76, col2, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("#jcms.tank_attack1", "jcms_hud_medium", -ammoX-4, 0, col1, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				draw.SimpleText("#jcms.tank_attack2", "jcms_hud_medium", ammoX+4, 0, col2, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				surface.SetDrawColor(col1)
				jcms.draw_Circle(-ammoX-4, -76, 98, 100, 16, 9, a2, Lerp(frac1, a2, a1))
				surface.SetDrawColor(col2)
				jcms.draw_Circle(ammoX+4, -76, 98, 100, 16, 9, Lerp(frac2, b1, b2), b1)
			end
		render.OverrideBlend( false )
	end
	
	function ENT:DrawHUD()
		local tower = self:GetTankOtherPart()
		
		if IsValid(tower) and tower:GetHealthFraction() > 0 then
			local angles = self:TowerAngles()
			local shootPos = tower:GetPos() + angles:Forward()*64 + angles:Up()*75
			
			local tr = util.TraceLine { start = shootPos, endpos = shootPos + angles:Forward()*2000, filter = tower, mask = MASK_SOLID }
			
			cam.Start3D()
				local t = CurTime()
				render.SetMaterial(self.mat_pointer)
				render.DrawBeam(tr.StartPos, tr.HitPos, 24, 0, 1, jcms.color_bright)
				
				render.SetMaterial(self.mat_ring)
				render.DrawSprite(tr.HitPos, 220, 220, jcms.color_bright)
				tr.HitPos:Add(tr.HitNormal)
				render.DrawQuadEasy(tr.HitPos, tr.HitNormal, 180, 180, jcms.color_bright)
			cam.End3D()
		end
	end
	
	function ENT:CalcViewDriver(ply, origin, angles, fov, znear, zfar)
		local mypos = self:GetPos()
		local myang = self:GetAngles()
		local speed = self:GetVelocity():Length()
		
		local frac = math.Clamp(math.Remap(angles.pitch, 0, -89, 0, 1), 0, 1)
		local up1 = Lerp(frac, 30, 150)
		local up2 = Lerp(frac, 72, 92)
		local fwd = Lerp(frac, -200, -150)
		local right = 0

		origin = mypos + myang:Up()*up1 + angles:Forward()*fwd + angles:Up()*up2 + angles:Right()*right
		angles.roll = math.AngleDifference(angles.roll, -myang.roll)*0.25
		
		return {
			origin = origin,
			angles = angles,
			fov = fov,
			
			znear = znear,
			zfar = zfar,
			
			drawviewer = false
		}
	end
end
